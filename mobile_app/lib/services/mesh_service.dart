import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import 'mesh_db_service.dart';
import 'mesh_encryption_service.dart';

/// Maximum number of relay hops before a packet is discarded.
const int kMaxHops = 5;

/// Unique service ID for Proxi mesh — must match on both devices.
const String kProxiServiceId = 'com.proxi.mesh.v1';

/// A peer currently connected via Google Nearby Connections.
class MeshPeer {
  final String uid;
  final String endpointId;
  MeshPeer({required this.uid, required this.endpointId});
}

class MeshService extends ChangeNotifier {
  final MeshDbService _db = MeshDbService();
  final MeshEncryptionService _crypto = MeshEncryptionService();
  final _uuid = const Uuid();

  String? _myUid;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  final Map<String, String> _endpointToUid = {};
  final Map<String, String> _connectedPeers = {};

  // Track known endpoints that have been found but not yet connected,
  // so we can attempt reconnect after a disconnect.
  final Set<String> _knownEndpoints = {};

  // Health-check timer — restarts discovery/advertising if peers drop.
  Timer? _healthTimer;

  List<MeshPeer> get peers => _connectedPeers.entries
      .map((e) => MeshPeer(uid: e.key, endpointId: e.value))
      .toList();

  final _incomingCtrl = StreamController<MeshMessage>.broadcast();
  Stream<MeshMessage> get incomingMessages => _incomingCtrl.stream;

  Future<bool> init(String myUid) async {
    _myUid = myUid;
    final ok = await _requestPermissions();
    _log('init uid=$myUid permissions=$ok');
    return ok;
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

    // Wi-Fi Direct permissions.
    // NEARBY_WIFI_DEVICES is required on Android 13+ for Wi-Fi P2P.
    final wifiResults = await [
      Permission.nearbyWifiDevices,
    ].request();

    final wifiOk = wifiResults[Permission.nearbyWifiDevices]?.isGranted == true;
    _log('BLE permissions ok=$bleOk, NEARBY_WIFI_DEVICES ok=$wifiOk');

    // BLE must be granted; Wi-Fi Direct is optional (falls back to BLE only).
    return bleOk;
  }

  Future<void> start() async {
    if (_isRunning || _myUid == null) return;
    _isRunning = true;
    notifyListeners();
    _log('Starting mesh for $_myUid');
    await _startNearby();

    // Health-check: if no peers connect within 30s, restart discovery.
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isRunning && _connectedPeers.isEmpty) {
        _log('Health-check: no peers — restarting discovery/advertising');
        _restartNearby();
      }
    });
  }

  Future<void> _startNearby() async {
    try {
      final adOk = await Nearby().startAdvertising(
        _myUid!,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: kProxiServiceId,
      );
      _log('Advertising started: $adOk');
    } catch (e) {
      _log('startAdvertising error: $e');
    }

    try {
      final disOk = await Nearby().startDiscovery(
        _myUid!,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: kProxiServiceId,
      );
      _log('Discovery started: $disOk');
    } catch (e) {
      _log('startDiscovery error: $e');
    }
  }

  Future<void> _restartNearby() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    if (_isRunning) await _startNearby();
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _healthTimer?.cancel();
    _healthTimer = null;
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    _isRunning = false;
    _connectedPeers.clear();
    _endpointToUid.clear();
    _knownEndpoints.clear();
    notifyListeners();
    _log('Mesh stopped');
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    _log('Endpoint found: $endpointName ($endpointId)');
    _endpointToUid[endpointId] = endpointName;
    _knownEndpoints.add(endpointId);
    // Request connection only if not already connected/connecting.
    if (!_connectedPeers.containsValue(endpointId)) {
      Nearby().requestConnection(
        _myUid!,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      ).catchError((e) {
        _log('requestConnection error for $endpointId: $e');
        return false;
      });
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    final uid = _endpointToUid.remove(endpointId);
    if (uid != null) {
      _connectedPeers.remove(uid);
      notifyListeners();
      _log('Endpoint lost: $uid ($endpointId)');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _log('Connection initiated: ${info.endpointName} incoming=${info.isIncomingConnection}');
    _endpointToUid[endpointId] = info.endpointName;
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (id, update) {},
    ).catchError((e) {
      _log('acceptConnection error: $e');
      return false;
    });
  }

  void _onConnectionResult(String endpointId, Status status) {
    _log('Connection result: $status for $endpointId');
    if (status == Status.CONNECTED) {
      final uid = _endpointToUid[endpointId];
      if (uid != null && uid != _myUid) {
        _connectedPeers[uid] = endpointId;
        notifyListeners();
        _log('Peer connected: $uid (${peers.length} total)');
        _deliverPendingTo(uid, endpointId);
      }
    } else {
      _endpointToUid.remove(endpointId);
      _log('Connection failed for $endpointId: $status');
    }
  }

  void _onDisconnected(String endpointId) {
    final uid = _endpointToUid.remove(endpointId);
    if (uid != null) {
      _connectedPeers.remove(uid);
      notifyListeners();
      _log('Peer disconnected: $uid — will retry via discovery');
    }
    // Trigger a discovery restart so we can reconnect shortly.
    if (_isRunning) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_isRunning && !_connectedPeers.values.contains(endpointId)) {
          _restartNearby();
        }
      });
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    try {
      final jsonStr = String.fromCharCodes(payload.bytes!);
      final packet = MeshWirePacket.fromJson(jsonStr);
      _log('Message received from $endpointId: ${packet.messageId}');
      await onPacketReceived(packet);
    } catch (e) {
      _log('Payload parse error: $e');
    }
  }

  Future<void> onPacketReceived(MeshWirePacket packet) async {
    final myUid = _myUid;
    if (myUid == null) return;
    if (packet.receiverId == myUid) {
      try {
        final plaintext = _crypto.decrypt(packet.encryptedPayload, packet.senderId, myUid);
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
      } catch (e) {
        _log('Decrypt error: $e');
      }
    } else if (packet.hopCount < kMaxHops) {
      // Relay to ALL connected peers (not just the first match) to improve delivery.
      await _relayPacket(packet);
    }
  }

  Future<void> _relayPacket(MeshWirePacket packet) async {
    final hopPacket = packet.withIncrementedHop();
    final bytes = Uint8List.fromList(utf8.encode(hopPacket.toJson()));
    bool relayed = false;
    for (final entry in _connectedPeers.entries) {
      if (entry.key == packet.senderId) continue; // Don't echo back to sender.
      try {
        await Nearby().sendBytesPayload(entry.value, bytes);
        _log('Relayed ${packet.messageId} to ${entry.key}');
        relayed = true;
      } catch (e) {
        _log('Relay error to ${entry.key}: $e');
      }
    }
    if (!relayed) {
      // Store for later delivery when a peer connects.
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

  Future<MeshMessage> sendMessage({required String receiverUid, required String text}) async {
    final myUid = _myUid!;
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

    final endpointId = _connectedPeers[receiverUid];
    if (endpointId != null) {
      final ok = await _sendToEndpoint(endpointId, msg);
      if (ok) {
        msg.deliveryStatus = MeshDeliveryStatus.delivered;
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
      }
    } else {
      // Broadcast relay to all peers — message will hop toward destination.
      await _broadcastRelay(msg);
    }
    notifyListeners();
    return msg;
  }

  Future<bool> _sendToEndpoint(String endpointId, MeshMessage msg) async {
    try {
      final packet = MeshWirePacket(
        messageId: msg.messageId,
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        encryptedPayload: msg.encryptedPayload,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
        hopCount: msg.hopCount,
      );
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(packet.toJson())),
      );
      _log('Sent to $endpointId');
      return true;
    } catch (e) {
      _log('Send error: $e');
      return false;
    }
  }

  Future<void> _broadcastRelay(MeshMessage msg) async {
    if (msg.hopCount >= kMaxHops) return;
    // Send to ALL connected peers; each will forward toward the destination.
    bool anyOk = false;
    for (final entry in _connectedPeers.entries) {
      if (entry.key == msg.senderId) continue;
      final ok = await _sendToEndpoint(entry.value, msg);
      if (ok) anyOk = true;
    }
    if (anyOk) {
      await _db.updateStatus(msg.messageId, MeshDeliveryStatus.relayed);
    }
  }

  Future<void> _deliverPendingTo(String uid, String endpointId) async {
    final pending = await _db.getPendingForReceiver(uid);
    for (final msg in pending) {
      if (msg.hopCount >= kMaxHops) continue;
      final ok = await _sendToEndpoint(endpointId, msg);
      if (ok) await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
    }
  }

  static void _log(String msg) => debugPrint('[MeshService] $msg');
}
