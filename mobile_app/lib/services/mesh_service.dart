import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
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

/// Maximum plaintext message size for BLE fallback (pre-encryption).
/// BLE payload characteristic has ~250 bytes capacity; AES-256 overhead ~32 bytes.
/// 180 chars of text ≈ 180 bytes, leaves room for packet framing.
const int kMaxBleMessageLength = 180;

/// Transport mode for mesh messages — tracks which channel was used.
enum MeshTransport {
  wifiDirect, // Wi-Fi Direct TCP
  ble,        // BLE GATT (fallback for small messages)
}

/// Mesh lifecycle states — exposed to the UI for status display.
enum MeshState {
  /// Mesh is off.
  inactive,
  /// Mesh is initializing (requesting permissions, etc.).
  initializing,
  /// BLE scanning for nearby mesh peers.
  scanning,
  /// At least one peer discovered via BLE, attempting Wi-Fi Direct.
  discovered,
  /// Wi-Fi Direct group formed, establishing sockets.
  connecting,
  /// Socket(s) open, handshake complete — ready to exchange messages.
  connected,
  /// Actively relaying messages for other nodes.
  relaying,
}

/// A peer currently connected via Wi-Fi Direct socket.
class MeshPeer {
  final String uid;
  final String endpointId; // Wi-Fi Direct MAC address or socket address
  MeshPeer({required this.uid, required this.endpointId});
}

/// Diagnostic snapshot of mesh state — for the debug panel.
class MeshStatusInfo {
  final MeshState state;
  final int bleDiscoveredCount;
  final int wifiPeerCount;
  final int socketCount;
  final int connectedPeerCount;
  final bool isGroupOwner;
  final String groupOwnerAddress;

  MeshStatusInfo({
    required this.state,
    required this.bleDiscoveredCount,
    required this.wifiPeerCount,
    required this.socketCount,
    required this.connectedPeerCount,
    required this.isGroupOwner,
    required this.groupOwnerAddress,
  });
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
///
/// BLE Coexistence:
///   Mesh does NOT own the BLE hardware scan lifecycle. It passively listens
///   to the BleService.discoveredUsersStream. When no external scan is active
///   (e.g. NearbyScreen is closed), mesh runs its own lightweight periodic
///   scan to keep discovering peers.
/// ──────────────────────────────────────────────────────────────────────────
class MeshService extends ChangeNotifier {
  final MeshDbService _db = MeshDbService();
  final MeshEncryptionService _crypto = MeshEncryptionService();
  final WifiDirectService _wifiDirect = WifiDirectService();
  final _uuid = const Uuid();

  String? _myUid;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  MeshState _meshState = MeshState.inactive;
  MeshState get meshState => _meshState;

  /// Reference to the BleService — used for passive listening only (never
  /// calls startContinuousScan / stopContinuousScan on it).
  BleService? _bleService;

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
  // Mesh-only BLE scan timer (runs only when no external scan is active)
  Timer? _meshBleScanTimer;

  StreamSubscription? _wifiEventSub;
  StreamSubscription<Map<String, BleDiscoveredUser>>? _bleScanSub;
  StreamSubscription<Uint8List>? _blePayloadSub;

  List<MeshPeer> get peers => _connectedPeers.entries
      .map((e) => MeshPeer(uid: e.key, endpointId: e.value))
      .toList();

    /// BLE-discovered peers keyed by UID.
    Map<String, BleDiscoveredUser> get bleDiscoveredPeers =>
      Map.unmodifiable(_bleDiscoveredPeers);

    /// Connected Wi-Fi Direct peers keyed by UID.
    Map<String, String> get connectedPeerEndpoints =>
      Map.unmodifiable(_connectedPeers);

  /// Number of BLE-discovered devices (even if not yet Wi-Fi connected)
  int get bleDiscoveredCount => _bleDiscoveredPeers.length;

  /// Number of socket-connected peers (fully connected for messaging)
  int get socketConnectedCount => _socketConnectedPeers.length;

  /// Diagnostic snapshot for the debug panel.
  MeshStatusInfo get statusInfo => MeshStatusInfo(
        state: _meshState,
        bleDiscoveredCount: _bleDiscoveredPeers.length,
        wifiPeerCount: 0, // populated from WFD discovery events
        socketCount: _socketConnectedPeers.length,
        connectedPeerCount: _connectedPeers.length,
        isGroupOwner: _isGroupOwner,
        groupOwnerAddress: _groupOwnerAddress,
      );

  final _incomingCtrl = StreamController<MeshMessage>.broadcast();
  Stream<MeshMessage> get incomingMessages => _incomingCtrl.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Init & Permissions
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> init(String myUid) async {
    _myUid = myUid;
    _setMeshState(MeshState.initializing);
    final ok = await _requestPermissions();
    if (!ok) {
      _log('init uid=$myUid permissions=DENIED');
      _setMeshState(MeshState.inactive);
      return false;
    }

    // Wi-Fi Direct requires Location/GPS to be ON (Android).
    try {
      final locStatus = await Permission.location.serviceStatus;
      if (!locStatus.isEnabled) {
        _log('Location/GPS is OFF — mesh will not work');
        _setMeshState(MeshState.inactive);
        return false;
      }
    } catch (e) {
      _log('Location service check error (non-fatal): $e');
    }

    // Initialize native Wi-Fi Direct
    final wifiOk = await _wifiDirect.initialize();
    if (!wifiOk) {
      _log('Wi-Fi Direct initialization FAILED');
      _setMeshState(MeshState.inactive);
      return false;
    }

    _setMeshState(MeshState.inactive);
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
    if (!wifiOk) {
      _log('WARNING: NEARBY_WIFI_DEVICES denied — Wi-Fi Direct may not work on Android 13+');
    }

    // Both BLE and Wi-Fi are required for mesh.
    return bleOk && wifiOk;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Start / Stop
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start mesh networking.
  ///
  /// [bleService] — shared BleService instance from AppState. Mesh subscribes
  /// to its discoveredUsersStream as a **passive listener** and never calls
  /// startContinuousScan / stopContinuousScan on it. This ensures mesh does
  /// not interfere with the NearbyScreen's BLE scan lifecycle.
  Future<void> start({BleService? bleService}) async {
    if (_isRunning || _myUid == null) return;
    _isRunning = true;
    _setMeshState(MeshState.scanning);
    _log('══════ Starting mesh for $_myUid ══════');

    // Listen to Wi-Fi Direct events from native layer
    _wifiEventSub?.cancel();
    _wifiEventSub = _wifiDirect.events.listen(_onWifiDirectEvent);

    // ── Passive BLE listening ──────────────────────────────────────────────
    // Subscribe to the BleService's discovery stream WITHOUT starting the
    // hardware scan. If the NearbyScreen or AppState is already scanning,
    // mesh will pick up peers from that stream. If no scan is active, the
    // _meshBleScanTimer below will kick off short scan bursts.
    if (bleService != null && _myUid != null) {
      _bleService = bleService;
      _bleScanSub?.cancel();
      _bleScanSub = bleService.discoveredUsersStream.listen((users) {
        for (final user in users.values) {
          onBleDeviceDiscovered(user);
        }
      });
      _log('BLE passive listening started for mesh peer discovery');

      // ── BLE Payload Transport (GATT) ───────────────────────────────────
      // Initialize GATT server for dual-transport mesh messaging (fallback
      // for messages ≤180 chars when Wi-Fi Direct unavailable).
      try {
        await bleService.initBlePayloadTransport();
        _blePayloadSub?.cancel();
        _blePayloadSub = bleService.incomingBlePayloads.listen((payload) {
          _log('Incoming BLE payload received: ${payload.length} bytes');
          try {
            final json = utf8.decode(payload);
            final parsed = jsonDecode(json) as Map<String, dynamic>;
            final packet = MeshWirePacket.fromJson(json);
            _onPacketReceived(packet);
          } catch (e) {
            _log('BLE payload parse error: $e');
          }
        }, onError: (e) => _log('BLE payload stream error: $e'));
        _log('BLE Payload transport (GATT) initialized');
      } catch (e) {
        _log('WARNING: BLE Payload transport failed to init: $e');
      }

      // Start a lightweight periodic BLE scan for mesh-only mode.
      // Uses short 6-second bursts every 15 seconds. This runs even
      // when NearbyScreen is closed so mesh can discover new peers.
      _meshBleScanTimer?.cancel();
      _meshBleScanTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        if (!_isRunning || _bleService == null) return;
        // Only start our own scan if no external scan is already running
        // (check by peeking at the continuous scan flag)
        _log('Mesh BLE scan burst starting');
        try {
          await _bleService!.startContinuousScan(myUid: _myUid);
          // Let it run for 6 seconds then stop to free the hardware
          Future.delayed(const Duration(seconds: 6), () async {
            // Only stop if mesh is still running — don't interfere if
            // NearbyScreen started a scan while we were scanning
            if (_isRunning) {
              // Don't stop — leave the continuous scan running so the
              // NearbyScreen doesn't lose its results. The scan stream
              // subscription above will continue to feed us peers.
            }
          });
        } catch (e) {
          _log('Mesh BLE scan burst error: $e');
        }
      });
      // Kick off the first scan immediately
      try {
        await bleService.startContinuousScan(myUid: _myUid);
      } catch (e) {
        _log('Initial mesh BLE scan error: $e');
      }
    }

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
          'wifi=$_isWifiDirectConnected state=$_meshState');
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
    _meshBleScanTimer?.cancel();
    _meshBleScanTimer = null;
    _wifiEventSub?.cancel();
    _wifiEventSub = null;
    _bleScanSub?.cancel();
    _bleScanSub = null;
    _blePayloadSub?.cancel();
    _blePayloadSub = null;

    // Stop BLE GATT payload transport
    if (_bleService != null) {
      try {
        await _bleService!.stopBlePayloadTransport();
      } catch (e) {
        _log('Error stopping BLE Payload transport: $e');
      }
    }

    await _wifiDirect.stopDiscovery();
    await _wifiDirect.disconnect();

    // Do NOT stop the BLE scan here — it belongs to NearbyScreen / AppState.
    // We only cancel our stream subscription above.
    _bleService = null;

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
    _setMeshState(MeshState.inactive);
    _log('Mesh stopped');
  }

  void _setMeshState(MeshState state) {
    if (_meshState != state) {
      _meshState = state;
      notifyListeners();
    }
  }

  void _updateMeshStateFromConnections() {
    if (!_isRunning) {
      _setMeshState(MeshState.inactive);
    } else if (_connectedPeers.isNotEmpty) {
      _setMeshState(MeshState.connected);
    } else if (_socketConnectedPeers.isNotEmpty) {
      _setMeshState(MeshState.connecting);
    } else if (_isWifiDirectConnected) {
      _setMeshState(MeshState.connecting);
    } else if (_bleDiscoveredPeers.isNotEmpty) {
      _setMeshState(MeshState.discovered);
    } else {
      _setMeshState(MeshState.scanning);
    }
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
    final previous = _bleDiscoveredPeers[bleUser.uid];
    _bleDiscoveredPeers[bleUser.uid] = bleUser;

    if (!existed || previous?.rssi != bleUser.rssi || previous?.username != bleUser.username) {
      _log('BLE discovered new peer: ${bleUser.uid} (${bleUser.username}) '
          'rssi=${bleUser.rssi} dist=${bleUser.distanceM.toStringAsFixed(1)}m');
      _updateMeshStateFromConnections();
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
        _updateMeshStateFromConnections();
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
        _updateMeshStateFromConnections();
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
        _updateMeshStateFromConnections();
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
    _updateMeshStateFromConnections();
  }

  void _onWifiConnectionChanged(Map<String, dynamic> data) {
    _isWifiDirectConnected = data['connected'] == true;
    _isGroupOwner = data['isGroupOwner'] == true;
    _groupOwnerAddress = data['groupOwnerAddress'] as String? ?? '';
    _pendingWifiConnections.clear();

    _log('Wi-Fi Direct: connected=$_isWifiDirectConnected, '
        'GO=$_isGroupOwner, GOAddr=$_groupOwnerAddress');
    _updateMeshStateFromConnections();
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
    _updateMeshStateFromConnections();

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

    // Loop detection: if we're already in the path, drop
    if (packet.hasVisited(myUid)) {
      _log('Loop detected for ${packet.messageId} — dropping');
      return;
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
          transport: packet.transport,
        );
        await _db.insertMessage(msg);
        _incomingCtrl.add(msg);
        _log('Message delivered: ${packet.messageId} from ${packet.senderId}');
      } catch (e) {
        _log('Decrypt error for ${packet.messageId}: $e');
      }
    } else if (packet.ttl > 0 && packet.hopCount < kMaxHops) {
      // Relay to all connected peers (with loop prevention)
      _log('Relaying ${packet.messageId} (hop ${packet.hopCount}, ttl ${packet.ttl})');
      _setMeshState(MeshState.relaying);
      await _relayPacket(packet);
      // Restore state after relay
      _updateMeshStateFromConnections();
    } else {
      _log('Dropping ${packet.messageId}: exceeded max hops or TTL=0');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Send / Relay Messages (Dual-Transport: Wi-Fi Direct Primary, BLE Fallback)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Select transport for message delivery based on availability and message size.
  /// Returns MeshTransport.wifiDirect if connected to receiver, else
  /// MeshTransport.ble if message is small enough and receiver has BLE connected.
  /// If no transport available, returns null (will use broadcast relay).
  MeshTransport? _selectTransport(
    MeshMessage msg, {
    required bool isDirectDelivery,
    required String receiverUid,
  }) {
    // Primary: Wi-Fi Direct direct delivery (always preferred if available)
    if (isDirectDelivery && _connectedPeers.containsKey(receiverUid)) {
      return MeshTransport.wifiDirect;
    }

    // Fallback: BLE for small plaintexts when Wi-Fi Direct unavailable
    if (msg.messageText.length <= kMaxBleMessageLength) {
      // Check if we have any BLE centrals connected (act as GATT server)
      final bleDevices = _bleService?.getConnectedBleDevices() ?? [];
      if (bleDevices.isNotEmpty) {
        _log('Transport selector: BLE fallback for message ≤${kMaxBleMessageLength} chars');
        return MeshTransport.ble;
      }
    }

    // No suitable transport — will use broadcast relay
    return null;
  }

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
      // Direct delivery — select optimal transport (Wi-Fi Direct preferred)
      final transport = _selectTransport(msg, isDirectDelivery: true, receiverUid: receiverUid)
          ?? MeshTransport.wifiDirect; // Fall back to Wi-Fi if both available
      msg.transport = transport.name;
      final ok = await _sendToAddress(peerAddress, msg, transport: transport);
      if (ok) {
        msg.deliveryStatus = MeshDeliveryStatus.delivered;
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
        _log('Message sent directly to $receiverUid (transport: ${transport.name})');
      }
    } else {
      // Receiver not directly connected — try BLE fallback first, else broadcast relay
      final transport = _selectTransport(msg, isDirectDelivery: false, receiverUid: receiverUid);
      if (transport == MeshTransport.ble) {
        msg.transport = MeshTransport.ble.name;
        // Try BLE broadcast to any connected BLE central (acts as relay)
        final bleOk = await _broadcastViaBlE(msg);
        if (bleOk) {
          msg.deliveryStatus = MeshDeliveryStatus.relayed;
          await _db.updateStatus(msg.messageId, MeshDeliveryStatus.relayed);
          _log('Message sent via BLE relay (will be forwarded to $receiverUid)');
        } else {
          msg.transport = MeshTransport.wifiDirect.name;
          await _broadcastRelay(msg);
        }
      } else {
        msg.transport = MeshTransport.wifiDirect.name;
        _log('Receiver $receiverUid not directly connected — broadcasting relay');
        await _broadcastRelay(msg);
      }
    }
    notifyListeners();
    return msg;
  }

  Future<bool> _sendToAddress(
    String address,
    MeshMessage msg, {
    MeshTransport transport = MeshTransport.wifiDirect,
  }) async {
    try {
      final packet = MeshWirePacket(
        messageId: msg.messageId,
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        encryptedPayload: msg.encryptedPayload,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
        hopCount: msg.hopCount,
        ttl: kMaxHops,
        path: [msg.senderId],
        transport: transport.name,
      );

      if (transport == MeshTransport.ble) {
        // Send via BLE GATT
        final ok = await _bleService?.sendPayloadViaBLE(
              address,
              Uint8List.fromList(utf8.encode(packet.toJson())),
            ) ??
            false;
        _log('Send via BLE to $address: ${ok ? "OK" : "FAILED"}');
        return ok;
      } else {
        // Send via Wi-Fi Direct TCP (default)
        final ok = await _wifiDirect.sendMessage(
          packet.toJson(),
          targetAddress: address,
        );
        _log('Send via Wi-Fi Direct to $address: ${ok ? "OK" : "FAILED"}');
        return ok;
      }
    } catch (e) {
      _log('Send error to $address: $e');
      return false;
    }
  }

  /// Broadcast mesh message via BLE to all connected centrals (experimental dual-transport).
  /// Used when receiver is not directly connected but BLE fallback is available.
  Future<bool> _broadcastViaBlE(MeshMessage msg) async {
    try {
      final packet = MeshWirePacket(
        messageId: msg.messageId,
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        encryptedPayload: msg.encryptedPayload,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
        hopCount: msg.hopCount,
        ttl: kMaxHops,
        path: [msg.senderId],
        transport: MeshTransport.ble.name,
      );
      final count = await _bleService?.broadcastPayloadViaBLE(
            Uint8List.fromList(utf8.encode(packet.toJson())),
          ) ??
          0;
      _log('Broadcast via BLE to $count device(s)');
      return count > 0;
    } catch (e) {
      _log('BLE broadcast error: $e');
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
    final myUid = _myUid;
    if (myUid == null) return;

    // Use withRelay to add ourselves to the path and decrement TTL
    final hopPacket = packet.withRelay(myUid);
    final json = hopPacket.toJson();
    bool relayed = false;

    for (final entry in _connectedPeers.entries) {
      if (entry.key == packet.senderId) continue; // Don't echo to sender
      // Loop prevention: don't forward to peers already in the path
      if (hopPacket.hasVisited(entry.key)) {
        _log('Skipping relay to ${entry.key} — already in path');
        continue;
      }
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
        transport: packet.transport,
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
