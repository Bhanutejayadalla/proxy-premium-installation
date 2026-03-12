import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../ble_service.dart';
import '../models.dart';
import 'mesh_db_service.dart';
import 'mesh_encryption_service.dart';
import 'wifi_direct_service.dart';

/// Maximum number of relay hops before a packet is discarded.
const int kMaxHops = 5;

/// A peer currently connected via Wi-Fi Direct socket.
class MeshPeer {
  final String uid;
  final String endpointId; // Wi-Fi Direct MAC address or socket address
  MeshPeer({required this.uid, required this.endpointId});
}

/// ──────────────────────────────────────────────────────────────────────────
/// MeshService — BLE Discovery + Wi-Fi Direct Data Transfer
///
/// Architecture:
///   1. BLE scans for nearby Proxi devices (broadcasts uid, username, capability)
///   2. When a BLE peer is detected, initiate Wi-Fi Direct peer discovery
///   3. Connect to the Wi-Fi Direct peer
///   4. Open TCP socket (port 8888) for bidirectional messaging
///   5. Messages relay through connected peers to form a mesh
/// ──────────────────────────────────────────────────────────────────────────
class MeshService extends ChangeNotifier {
  final MeshDbService _db = MeshDbService();
  final MeshEncryptionService _crypto = MeshEncryptionService();
  final WifiDirectService _wifiDirect = WifiDirectService();
  final _uuid = const Uuid();

  String? _myUid;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Connected peers: uid → socket address (from Wi-Fi Direct)
  final Map<String, String> _connectedPeers = {};

  /// BLE-discovered peers waiting for Wi-Fi Direct connection: uid → BleDiscoveredUser
  final Map<String, BleDiscoveredUser> _bleDiscoveredPeers = {};

  /// Wi-Fi Direct peer address → uid mapping (built from handshake)
  final Map<String, String> _addressToUid = {};

  /// Peers we're in the process of connecting to via Wi-Fi Direct
  final Set<String> _pendingWifiConnections = {};

  /// Socket-connected peer addresses
  final Set<String> _socketConnectedPeers = {};

  /// Recently seen message IDs — prevents processing the same relayed message twice.
  /// Uses a Queue for proper FIFO eviction when the limit is exceeded.
  final Set<String> _seenMessageIds = {};
  final Queue<String> _seenIdsQueue = Queue<String>();
  static const int _maxSeenMessages = 500;

  /// Wi-Fi Direct connection state
  bool _isWifiDirectConnected = false;
  bool _isGroupOwner = false;
  String _groupOwnerAddress = '';
  bool get isWifiDirectConnected => _isWifiDirectConnected;
  bool get isGroupOwner => _isGroupOwner;

  // Health-check timer — restarts discovery if peers drop.
  Timer? _healthTimer;
  // Wi-Fi Direct discovery refresh timer
  Timer? _wifiDiscoveryTimer;

  StreamSubscription? _wifiEventSub;
  StreamSubscription<Map<String, BleDiscoveredUser>>? _bleScanSub;

  List<MeshPeer> get peers => _connectedPeers.entries
      .map((e) => MeshPeer(uid: e.key, endpointId: e.value))
      .toList();

  /// Number of BLE-discovered devices (even if not yet Wi-Fi connected)
  int get bleDiscoveredCount => _bleDiscoveredPeers.length;

  /// Number of socket-connected peers (fully connected for messaging)
  int get socketConnectedCount => _socketConnectedPeers.length;

  final _incomingCtrl = StreamController<MeshMessage>.broadcast();
  Stream<MeshMessage> get incomingMessages => _incomingCtrl.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Init & Permissions
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> init(String myUid) async {
    _myUid = myUid;
    final ok = await _requestPermissions();
    if (!ok) {
      _log('init uid=$myUid permissions=DENIED');
      return false;
    }

    // Wi-Fi Direct requires Location/GPS to be ON (Android).
    try {
      final locStatus = await Permission.location.serviceStatus;
      if (!locStatus.isEnabled) {
        _log('Location/GPS is OFF — mesh will not work');
        return false;
      }
    } catch (e) {
      _log('Location service check error (non-fatal): $e');
    }

    // Initialize native Wi-Fi Direct
    final wifiOk = await _wifiDirect.initialize();
    if (!wifiOk) {
      _log('Wi-Fi Direct initialization FAILED');
      return false;
    }

    _log('init uid=$myUid permissions=OK location=ON wifiDirect=OK');
    return true;
  }

  Future<bool> _requestPermissions() async {
    // Core BLE permissions (Android 12+ requires explicit runtime grants).
    final bleResults = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    final bleOk = bleResults.values.every((s) => s.isGranted);

    // Wi-Fi Direct permissions: NEARBY_WIFI_DEVICES (Android 13+)
    final wifiResults = await [Permission.nearbyWifiDevices].request();
    final wifiOk = wifiResults[Permission.nearbyWifiDevices]?.isGranted == true;
    _log('BLE permissions ok=$bleOk, NEARBY_WIFI_DEVICES ok=$wifiOk');

    // Both BLE and Wi-Fi are required for mesh.
    return bleOk;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Start / Stop
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> start() async {
    if (_isRunning || _myUid == null) return;
    _isRunning = true;
    notifyListeners();
    _log('══════ Starting mesh for $_myUid ══════');

    // Listen to Wi-Fi Direct events from native layer
    _wifiEventSub?.cancel();
    _wifiEventSub = _wifiDirect.events.listen(_onWifiDirectEvent);

    // Start Wi-Fi Direct peer discovery
    await _startWifiDirectDiscovery();

    // Periodically refresh Wi-Fi Direct discovery (it times out)
    _wifiDiscoveryTimer?.cancel();
    _wifiDiscoveryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isRunning) _refreshWifiDiscovery();
    });

    // Health-check: restart discovery if no peers
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isRunning) return;
      _log('Health-check: ${_connectedPeers.length} peers, '
          '${_socketConnectedPeers.length} sockets, '
          'wifi=${_isWifiDirectConnected}');
      if (_connectedPeers.isEmpty && _isRunning) {
        _log('Health-check: no peers — restarting discovery');
        _startWifiDirectDiscovery();
      }
    });
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _log('══════ Stopping mesh ══════');
    _healthTimer?.cancel();
    _healthTimer = null;
    _wifiDiscoveryTimer?.cancel();
    _wifiDiscoveryTimer = null;
    _wifiEventSub?.cancel();
    _wifiEventSub = null;
    _bleScanSub?.cancel();
    _bleScanSub = null;

    await _wifiDirect.stopDiscovery();
    await _wifiDirect.disconnect();

    _isRunning = false;
    _isWifiDirectConnected = false;
    _isGroupOwner = false;
    _groupOwnerAddress = '';
    _connectedPeers.clear();
    _bleDiscoveredPeers.clear();
    _seenIdsQueue.clear();
    _addressToUid.clear();
    _pendingWifiConnections.clear();
    _socketConnectedPeers.clear();
    _seenMessageIds.clear();
    notifyListeners();
    _log('Mesh stopped');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Wi-Fi Direct Discovery & Connection
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startWifiDirectDiscovery() async {
    _log('Starting Wi-Fi Direct peer discovery');
    await _wifiDirect.startDiscovery();
  }

  Future<void> _refreshWifiDiscovery() async {
    if (!_isRunning) return;
    _log('Refreshing Wi-Fi Direct discovery');
    await _wifiDirect.stopDiscovery();
    await Future.delayed(const Duration(milliseconds: 300));
    if (_isRunning) await _wifiDirect.startDiscovery();
  }

  /// Called when BLE discovers a nearby Proxi user → trigger Wi-Fi Direct connection.
  void onBleDeviceDiscovered(BleDiscoveredUser bleUser) {
    if (bleUser.uid == _myUid) return; // Skip self
    if (!_isRunning) return;

    final existed = _bleDiscoveredPeers.containsKey(bleUser.uid);
    _bleDiscoveredPeers[bleUser.uid] = bleUser;

    if (!existed) {
      _log('BLE discovered new peer: ${bleUser.uid} (${bleUser.username}) '
          'rssi=${bleUser.rssi} dist=${bleUser.distanceM.toStringAsFixed(1)}m');
      notifyListeners();
    }
  }

  /// Attempt to Wi-Fi Direct connect to a discovered peer by MAC address.
  Future<void> connectToWifiPeer(String address) async {
    if (_pendingWifiConnections.contains(address)) return;
    _pendingWifiConnections.add(address);
    _log('Initiating Wi-Fi Direct connection to $address');
    final ok = await _wifiDirect.connectToPeer(address);
    if (!ok) {
      _pendingWifiConnections.remove(address);
      _log('Wi-Fi Direct connect request FAILED for $address');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Wi-Fi Direct Event Handler
  // ═══════════════════════════════════════════════════════════════════════════

  void _onWifiDirectEvent(WifiDirectEvent event) {
    _log('WFD event: ${event.type} ${event.data}');

    switch (event.type) {
      case 'stateChanged':
        final enabled = event.data['enabled'] == true;
        _log('Wi-Fi P2P ${enabled ? "ENABLED" : "DISABLED"}');
        break;

      case 'peersChanged':
        _onWifiPeersChanged(event.data);
        break;

      case 'connectionChanged':
        _onWifiConnectionChanged(event.data);
        break;

      case 'disconnected':
        _log('Wi-Fi Direct disconnected');
        _isWifiDirectConnected = false;
        _isGroupOwner = false;
        _groupOwnerAddress = '';
        _socketConnectedPeers.clear();
        _connectedPeers.clear();
        _addressToUid.clear();
        notifyListeners();
        // Restart discovery to reconnect
        if (_isRunning) {
          Future.delayed(const Duration(seconds: 2), () {
            if (_isRunning) _startWifiDirectDiscovery();
          });
        }
        break;

      case 'peerSocketConnected':
        final addr = event.data['address'] as String? ?? '';
        _log('Socket connected to $addr');
        _socketConnectedPeers.add(addr);
        // Send handshake with our UID so the other side can map address→uid
        _sendHandshake(addr);
        notifyListeners();
        break;

      case 'peerSocketDisconnected':
        final addr = event.data['address'] as String? ?? '';
        _log('Socket disconnected from $addr');
        _socketConnectedPeers.remove(addr);
        final uid = _addressToUid.remove(addr);
        if (uid != null) {
          _connectedPeers.remove(uid);
          _log('Peer $uid removed (socket disconnected)');
        }
        notifyListeners();
        break;

      case 'messageReceived':
        _onMessageReceived(event.data);
        break;

      case 'socketError':
        _log('Socket error: ${event.data['error']}');
        break;

      case 'thisDeviceChanged':
        _log('This device: ${event.data['name']} (${event.data['address']})');
        break;

      case 'socketServerStarted':
        _log('Socket server started on port ${event.data['port']}');
        break;

      case 'channelDisconnected':
        _log('Wi-Fi P2P channel disconnected — reinitializing');
        if (_isRunning) {
          _wifiDirect.initialize().then((_) => _startWifiDirectDiscovery());
        }
        break;
    }
  }

  void _onWifiPeersChanged(Map<String, dynamic> data) {
    final peersList = data['peers'] as List? ?? [];
    _log('Wi-Fi Direct peers: ${peersList.length}');

    for (final p in peersList) {
      final peer = Map<String, dynamic>.from(p as Map);
      final name = peer['name'] as String? ?? '';
      final address = peer['address'] as String? ?? '';
      final status = peer['status'] as String? ?? '';
      _log('  WFD Peer: $name ($address) status=$status');

      // Auto-connect to available peers that we haven't connected or pending yet.
      if (status == 'available' &&
          !_pendingWifiConnections.contains(address) &&
          !_socketConnectedPeers.contains(address)) {
        _log('Auto-connecting to available Wi-Fi peer: $address');
        connectToWifiPeer(address);
      }
    }
    notifyListeners();
  }

  void _onWifiConnectionChanged(Map<String, dynamic> data) {
    _isWifiDirectConnected = data['connected'] == true;
    _isGroupOwner = data['isGroupOwner'] == true;
    _groupOwnerAddress = data['groupOwnerAddress'] as String? ?? '';
    _pendingWifiConnections.clear();

    _log('Wi-Fi Direct: connected=$_isWifiDirectConnected, '
        'GO=$_isGroupOwner, GOAddr=$_groupOwnerAddress');
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Handshake Protocol (identify UID over socket)
  // ═══════════════════════════════════════════════════════════════════════════

  void _sendHandshake(String peerAddress) {
    if (_myUid == null) return;
    final handshake = jsonEncode({
      'type': 'handshake',
      'uid': _myUid,
    });
    _wifiDirect.sendMessage(handshake, targetAddress: peerAddress);
    _log('Sent handshake to $peerAddress');
  }

  void _handleHandshake(String fromAddress, Map<String, dynamic> data) {
    final uid = data['uid'] as String?;
    if (uid == null || uid == _myUid) return;
    _addressToUid[fromAddress] = uid;
    _connectedPeers[uid] = fromAddress;
    _log('Handshake complete: $uid ↔ $fromAddress '
        '(${_connectedPeers.length} peers total)');
    notifyListeners();

    // Deliver any pending messages for this peer
    _deliverPendingTo(uid, fromAddress);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Message Receive / Process
  // ═══════════════════════════════════════════════════════════════════════════

  void _onMessageReceived(Map<String, dynamic> data) {
    final rawMessage = data['message'] as String? ?? '';
    final fromAddress = data['fromAddress'] as String? ?? '';

    if (rawMessage.isEmpty) return;

    try {
      final parsed = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = parsed['type'] as String? ?? '';

      if (type == 'handshake') {
        _handleHandshake(fromAddress, parsed);
        return;
      }

      // It's a mesh packet
      final packet = MeshWirePacket.fromJson(rawMessage);
      _log('Packet received from $fromAddress: ${packet.messageId}');
      _onPacketReceived(packet);
    } catch (e) {
      _log('Message parse error from $fromAddress: $e');
    }
  }

  Future<void> _onPacketReceived(MeshWirePacket packet) async {
    final myUid = _myUid;
    if (myUid == null) return;

    // Deduplicate
    if (_seenMessageIds.contains(packet.messageId)) {
      _log('Duplicate packet ${packet.messageId} — dropping');
      return;
    }
    _seenMessageIds.add(packet.messageId);
    _seenIdsQueue.add(packet.messageId);
    if (_seenMessageIds.length > _maxSeenMessages) {
      final oldest = _seenIdsQueue.removeFirst();
      _seenMessageIds.remove(oldest);
    }

    if (packet.receiverId == myUid) {
      // Message is for us — decrypt and store
      try {
        final plaintext =
            _crypto.decrypt(packet.encryptedPayload, packet.senderId, myUid);
        final msg = MeshMessage(
          messageId: packet.messageId,
          senderId: packet.senderId,
          receiverId: myUid,
          messageText: plaintext,
          timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
          deliveryStatus: MeshDeliveryStatus.delivered,
          hopCount: packet.hopCount,
          encryptedPayload: packet.encryptedPayload,
        );
        await _db.insertMessage(msg);
        _incomingCtrl.add(msg);
        _log('Message delivered: ${packet.messageId} from ${packet.senderId}');
      } catch (e) {
        _log('Decrypt error for ${packet.messageId}: $e');
      }
    } else if (packet.hopCount < kMaxHops) {
      // Relay to all connected peers
      _log('Relaying ${packet.messageId} (hop ${packet.hopCount})');
      await _relayPacket(packet);
    } else {
      _log('Dropping ${packet.messageId}: exceeded max hops');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Send / Relay Messages
  // ═══════════════════════════════════════════════════════════════════════════

  Future<MeshMessage> sendMessage(
      {required String receiverUid, required String text}) async {
    final myUid = _myUid;
    if (myUid == null) throw StateError('MeshService.sendMessage called before init()');
    final msg = MeshMessage(
      messageId: _uuid.v4(),
      senderId: myUid,
      receiverId: receiverUid,
      messageText: text,
      timestamp: DateTime.now(),
      deliveryStatus: MeshDeliveryStatus.pending,
    );
    msg.encryptedPayload = _crypto.encrypt(text, myUid, receiverUid);
    await _db.insertMessage(msg);

    final peerAddress = _connectedPeers[receiverUid];
    if (peerAddress != null) {
      // Direct delivery
      final ok = await _sendToAddress(peerAddress, msg);
      if (ok) {
        msg.deliveryStatus = MeshDeliveryStatus.delivered;
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
        _log('Message sent directly to $receiverUid');
      }
    } else {
      // Broadcast relay to all peers
      _log('Receiver $receiverUid not directly connected — broadcasting relay');
      await _broadcastRelay(msg);
    }
    notifyListeners();
    return msg;
  }

  Future<bool> _sendToAddress(String address, MeshMessage msg) async {
    try {
      final packet = MeshWirePacket(
        messageId: msg.messageId,
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        encryptedPayload: msg.encryptedPayload,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
        hopCount: msg.hopCount,
      );
      final ok = await _wifiDirect.sendMessage(
        packet.toJson(),
        targetAddress: address,
      );
      _log('Send to $address: ${ok ? "OK" : "FAILED"}');
      return ok;
    } catch (e) {
      _log('Send error to $address: $e');
      return false;
    }
  }

  Future<void> _broadcastRelay(MeshMessage msg) async {
    if (msg.hopCount >= kMaxHops) return;
    bool anyOk = false;
    for (final entry in _connectedPeers.entries) {
      if (entry.key == msg.senderId) continue;
      final ok = await _sendToAddress(entry.value, msg);
      if (ok) anyOk = true;
    }
    if (anyOk) {
      await _db.updateStatus(msg.messageId, MeshDeliveryStatus.relayed);
    }
  }

  Future<void> _relayPacket(MeshWirePacket packet) async {
    final hopPacket = packet.withIncrementedHop();
    final json = hopPacket.toJson();
    bool relayed = false;

    for (final entry in _connectedPeers.entries) {
      if (entry.key == packet.senderId) continue; // Don't echo to sender
      try {
        final ok = await _wifiDirect.sendMessage(json, targetAddress: entry.value);
        if (ok) {
          _log('Relayed ${packet.messageId} to ${entry.key}');
          relayed = true;
        }
      } catch (e) {
        _log('Relay error to ${entry.key}: $e');
      }
    }

    if (!relayed) {
      // Store for later delivery
      await _db.insertMessage(MeshMessage(
        messageId: packet.messageId,
        senderId: packet.senderId,
        receiverId: packet.receiverId,
        messageText: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
        deliveryStatus: MeshDeliveryStatus.relayed,
        hopCount: hopPacket.hopCount,
        encryptedPayload: packet.encryptedPayload,
      ));
    }
  }

  Future<void> _deliverPendingTo(String uid, String address) async {
    final pending = await _db.getPendingForReceiver(uid);
    for (final msg in pending) {
      if (msg.hopCount >= kMaxHops) continue;
      final ok = await _sendToAddress(address, msg);
      if (ok) {
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
      }
    }
    if (pending.isNotEmpty) {
      _log('Delivered ${pending.length} pending messages to $uid');
    }
  }

  static void _log(String msg) => debugPrint('[MeshService] $msg');
}
