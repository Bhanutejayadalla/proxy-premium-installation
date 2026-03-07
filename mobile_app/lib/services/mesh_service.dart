import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import 'mesh_db_service.dart';
import 'mesh_encryption_service.dart';

/// Maximum number of relay hops before a packet is discarded.
const int kMaxHops = 5;

/// BLE GATT service UUID for Proxi Mesh.
const String kMeshServiceUuid = '12345678-1234-1234-1234-1234567890ab';

/// BLE GATT characteristic for mesh message exchange.
const String kMeshCharUuid = '12345678-1234-1234-1234-1234567890cd';

/// Company ID embedded in BLE advertisement manufacturer data.
const int kProxiCompanyId = 0xFF01;

/// A device discovered on the mesh with its BLE reference.
class MeshPeer {
  final String uid;
  final BluetoothDevice device;
  final int rssi;

  MeshPeer({required this.uid, required this.device, required this.rssi});
}

/// Core mesh service:
///  - BLE advertisement (discovery beacon)
///  - BLE scanning (peer discovery)
///  - GATT server / client for message exchange
///  - Multi-hop relay logic
///  - Battery optimisation (scan only when active)
class MeshService extends ChangeNotifier {
  // ── dependencies ────────────────────────────────────────────────────────────
  final MeshDbService _db = MeshDbService();
  final MeshEncryptionService _crypto = MeshEncryptionService();
  final _uuid = const Uuid();

  // ── state ────────────────────────────────────────────────────────────────────
  String? _myUid;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Peers currently visible in range: uid → MeshPeer
  final Map<String, MeshPeer> _peers = {};
  List<MeshPeer> get peers => _peers.values.toList();

  /// Stream of incoming mesh messages for the UI layer.
  final _incomingController =
      StreamController<MeshMessage>.broadcast();
  Stream<MeshMessage> get incomingMessages => _incomingController.stream;

  StreamSubscription? _scanSub;
  Timer? _scanTimer;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  /// Initialise the mesh for [myUid]. Call once after auth.
  Future<bool> init(String myUid) async {
    _myUid = myUid;
    final ok = await _requestPermissions();
    if (!ok) return false;
    return true;
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

  /// Start BLE advertising + scanning.
  Future<void> start() async {
    if (_isRunning || _myUid == null) return;
    _isRunning = true;
    notifyListeners();
    _log('Mesh started for $_myUid');
    _startScan();
  }

  /// Stop all BLE activity (battery optimisation when app idle).
  Future<void> stop() async {
    if (!_isRunning) return;
    _scanTimer?.cancel();
    _scanSub?.cancel();
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    _isRunning = false;
    _peers.clear();
    notifyListeners();
    _log('Mesh stopped');
  }

  // ── scanning ─────────────────────────────────────────────────────────────────

  void _startScan() {
    _scanSub?.cancel();
    _scanTimer?.cancel();

    // Repeat every 15 s for continuous peer discovery
    _scanTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isRunning) _doScan();
    });
    _doScan(); // immediate first scan
  }

  Future<void> _doScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 300));

      final newPeers = <String, MeshPeer>{};

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.rssi < -90) continue; // too far away

          // Parse manufacturer data to extract Proxi UID
          final mfData = r.advertisementData.manufacturerData;
          final uid = _extractUid(mfData);
          if (uid == null || uid == _myUid) continue;

          newPeers[uid] = MeshPeer(
              uid: uid, device: r.device, rssi: r.rssi);
          _log('Peer discovered: $uid rssi=${r.rssi}');
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: true,
      );
      await Future.delayed(const Duration(seconds: 9));

      // Merge new peers
      _peers
        ..clear()
        ..addAll(newPeers);
      notifyListeners();
      _log('Scan complete — ${_peers.length} peer(s) found');

      // Attempt delivery to any newly seen peers
      for (final peer in _peers.values) {
        await _deliverPendingTo(peer);
      }
    } catch (e) {
      _log('Scan error: $e');
    }
  }

  /// Extract UID from BLE manufacturer data bytes.
  /// Format: [2-byte companyId LE] [uid as UTF-8 bytes]
  String? _extractUid(Map<int, List<int>> mfData) {
    final bytes = mfData[kProxiCompanyId];
    if (bytes == null || bytes.length < 4) return null;
    try {
      return utf8.decode(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  // ── send message ─────────────────────────────────────────────────────────────

  /// Send a chat message via mesh. Stores locally first, then attempts BLE
  /// delivery if the recipient is in range; otherwise marks as pending for
  /// relay when a path becomes available.
  Future<MeshMessage> sendMessage({
    required String receiverUid,
    required String text,
  }) async {
    final myUid = _myUid!;
    final msg = MeshMessage(
      messageId: _uuid.v4(),
      senderId: myUid,
      receiverId: receiverUid,
      messageText: text,
      timestamp: DateTime.now(),
      deliveryStatus: MeshDeliveryStatus.pending,
    );

    // Encrypt before storing
    msg.encryptedPayload = _crypto.encrypt(text, myUid, receiverUid);

    // 1. Persist locally
    await _db.insertMessage(msg);

    // 2. Attempt direct delivery if peer is in range
    final peer = _peers[receiverUid];
    if (peer != null) {
      final ok = await _sendToPeer(peer, msg);
      if (ok) {
        msg.deliveryStatus = MeshDeliveryStatus.delivered;
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
      }
    } else {
      // Broadcast to all peers as relay candidates
      await _broadcastRelay(msg);
    }

    notifyListeners();
    return msg;
  }

  // ── GATT write ───────────────────────────────────────────────────────────────

  /// Send [msg] directly to [peer] via GATT write. Returns true on success.
  Future<bool> _sendToPeer(MeshPeer peer, MeshMessage msg) async {
    try {
      await peer.device.connect(timeout: const Duration(seconds: 6));
      final services = await peer.device.discoverServices();
      BluetoothCharacteristic? txChar;
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() ==
            kMeshServiceUuid.toLowerCase()) {
          for (final c in svc.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                kMeshCharUuid.toLowerCase()) {
              txChar = c;
              break;
            }
          }
        }
      }
      if (txChar == null) {
        await peer.device.disconnect();
        return false;
      }

      final packet = MeshWirePacket(
        messageId: msg.messageId,
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        encryptedPayload: msg.encryptedPayload,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
      );

      // BLE MTU is 512 bytes max; split if required
      final json = packet.toJson();
      final bytes = utf8.encode(json);
      const chunkSize = 480;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = min(i + chunkSize, bytes.length);
        await txChar.write(bytes.sublist(i, end), withoutResponse: false);
      }

      await peer.device.disconnect();
      _log('Direct send OK → ${peer.uid}');
      return true;
    } catch (e) {
      _log('Direct send failed to ${peer.uid}: $e');
      try { await peer.device.disconnect(); } catch (_) {}
      return false;
    }
  }

  // ── relay ────────────────────────────────────────────────────────────────────

  /// Broadcast [msg] to all currently visible peers for relaying.
  Future<void> _broadcastRelay(MeshMessage msg) async {
    if (msg.hopCount >= kMaxHops) return;
    for (final peer in _peers.values) {
      if (peer.uid == msg.senderId) continue; // don't send back to sender
      final ok = await _sendToPeer(peer, msg);
      if (ok) {
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.relayed);
        _log('Relayed ${msg.messageId} via ${peer.uid}');
        break; // one relay is enough per scan cycle
      }
    }
  }

  /// When [peer] comes into range, forward any pending messages addressed to them.
  Future<void> _deliverPendingTo(MeshPeer peer) async {
    final pending = await _db.getPendingForReceiver(peer.uid);
    for (final msg in pending) {
      if (msg.hopCount >= kMaxHops) continue;
      final ok = await _sendToPeer(peer, msg);
      if (ok) {
        await _db.updateStatus(msg.messageId, MeshDeliveryStatus.delivered);
        _log('Delivered pending ${msg.messageId} → ${peer.uid}');
      }
    }
  }

  // ── receive (called by GATT server / notification listener) ─────────────────

  /// Process a [MeshWirePacket] received over BLE.
  /// - If addressed to me: decrypt + store + notify UI
  /// - If addressed to someone else: relay if hop count allows
  Future<void> onPacketReceived(MeshWirePacket packet) async {
    final myUid = _myUid;
    if (myUid == null) return;

    // Security: Verify sender can encrypt for this conversation
    if (!_crypto.verifySender(packet, myUid)) {
      _log('Rejected packet from ${packet.senderId}: auth failed');
      return;
    }

    if (packet.receiverId == myUid) {
      // Message is for me
      final plaintext = _crypto.decrypt(
          packet.encryptedPayload, packet.senderId, myUid);
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
      _incomingController.add(msg);
      _log('Received message for me: ${packet.messageId}');
    } else if (packet.hopCount < kMaxHops) {
      // Relay to recipient if in range
      final relayPeer = _peers[packet.receiverId];
      if (relayPeer != null) {
        final relayMsg = MeshMessage(
          messageId: packet.messageId,
          senderId: packet.senderId,
          receiverId: packet.receiverId,
          messageText: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
          deliveryStatus: MeshDeliveryStatus.relayed,
          hopCount: packet.hopCount + 1,
          encryptedPayload: packet.encryptedPayload,
        );
        await _sendToPeer(relayPeer, relayMsg);
        _log('Relayed ${packet.messageId} → ${packet.receiverId} (hop ${packet.hopCount + 1})');
      } else {
        // Store for later relay
        final pendingRelay = MeshMessage(
          messageId: packet.messageId,
          senderId: packet.senderId,
          receiverId: packet.receiverId,
          messageText: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(packet.timestamp),
          deliveryStatus: MeshDeliveryStatus.relayed,
          hopCount: packet.hopCount + 1,
          encryptedPayload: packet.encryptedPayload,
        );
        await _db.insertMessage(pendingRelay);
      }
    }
  }

  static void _log(String msg) => debugPrint('[MeshService] $msg');
}
