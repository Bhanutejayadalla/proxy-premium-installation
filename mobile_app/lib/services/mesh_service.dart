import 'dart:async';
import 'dart:convert';
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
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();
    return results.values.every((s) => s.isGranted);
  }

  Future<void> start() async {
    if (_isRunning || _myUid == null) return;
    _isRunning = true;
    notifyListeners();
    _log('Starting mesh for $_myUid');
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
      final disOk = await Nearby().startDiscovery(
        _myUid!,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: kProxiServiceId,
      );
      _log('Discovery started: $disOk');
    } catch (e) {
      _log('Start error: $e');
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    _isRunning = false;
    _connectedPeers.clear();
    _endpointToUid.clear();
    notifyListeners();
    _log('Mesh stopped');
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    _log('Endpoint found: $endpointName ($endpointId)');
    _endpointToUid[endpointId] = endpointName;
    Nearby().requestConnection(
      _myUid!,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    ).catchError((e) {
      _log('requestConnection error: $e');
      return false;
    });
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    final uid = _endpointToUid.remove(endpointId);
    if (uid != null) {
      _connectedPeers.remove(uid);
      notifyListeners();
      _log('Endpoint lost: $uid');
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
      _log('Peer disconnected: $uid');
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
      final relayId = _connectedPeers[packet.receiverId];
      if (relayId != null) {
        try {
          await Nearby().sendBytesPayload(
            relayId,
            Uint8List.fromList(utf8.encode(packet.withIncrementedHop().toJson())),
          );
          _log('Relayed ${packet.messageId}');
        } catch (e) {
          _log('Relay error: $e');
        }
      } else {
        await _db.insertMessage(MeshMessage(
          messageId: packet.messageId,
          senderId: packet.senderId,
          receiverId: packet.receiverId,
          messageText: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
          deliveryStatus: MeshDeliveryStatus.relayed,
          hopCount: packet.hopCount + 1,
          encryptedPayload: packet.encryptedPayload,
        ));
      }
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
    for (final entry in _connectedPeers.entries) {
      if (entry.key == msg.senderId) continue;
      final ok = await _sendToEndpoint(entry.value, msg);
      if (ok) {
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.relayed);
        break;
      }
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
