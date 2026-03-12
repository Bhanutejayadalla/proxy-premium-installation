import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models.dart';
import 'mesh_db_service.dart';

/// Watches network connectivity and, when online, syncs unsynced local
/// mesh messages up to Firebase and pulls down any missing remote messages.
///
/// Firebase collection layout:
///   mesh_messages/{messageId}    — top-level collection
///     message_id, sender_id, receiver_id, message_text, timestamp,
///     delivery_status, hop_count, source='mesh'
///
/// Security rules (add to firestore.rules):
///   match /mesh_messages/{msgId} {
///     allow read: if request.auth != null &&
///       (resource.data.sender_id == request.auth.uid ||
///        resource.data.receiver_id == request.auth.uid);
///     allow create: if request.auth != null &&
///       request.resource.data.sender_id == request.auth.uid;
///     allow update, delete: if false;
///   }
class MeshSyncService {
  final MeshDbService _localDb = MeshDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  /// Start watching connectivity. Pass [myUid] once auth is complete.
  void startWatching(String myUid) {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasInternet = results.any(
          (r) => r != ConnectivityResult.none);
      if (hasInternet && !_isSyncing) {
        await syncNow(myUid);
      }
    });

    // Also attempt an immediate sync in case we're already online
    _checkAndSync(myUid);
  }

  Future<void> _checkAndSync(String myUid) async {
    final results = await Connectivity().checkConnectivity();
    final hasInternet =
        results.any((r) => r != ConnectivityResult.none);
    if (hasInternet) await syncNow(myUid);
  }

  void stopWatching() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Full sync cycle:
  ///  1. Upload unsynced local messages to Firestore
  ///  2. Download remote messages not yet in local DB
  Future<void> syncNow(String myUid) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _log('Sync started for $myUid');

    try {
      await _uploadUnsynced(myUid);
      await _downloadMissing(myUid);
    } catch (e) {
      _log('Sync error: $e');
    } finally {
      _isSyncing = false;
      _log('Sync finished');
    }
  }

  // ── UPLOAD ───────────────────────────────────────────────────────────────────

  Future<void> _uploadUnsynced(String myUid) async {
    final unsynced = await _localDb.getUnsynced(myUid);
    if (unsynced.isEmpty) {
      _log('Nothing to upload');
      return;
    }
    _log('Uploading ${unsynced.length} message(s) to Firebase');

    final batch = _firestore.batch();
    final ids = <String>[];

    for (final msg in unsynced) {
      // Don't upload relay-only messages (empty messageText means we were relay)
      if (msg.messageText.isEmpty) continue;
      final ref = _firestore.collection('mesh_messages').doc(msg.messageId);
      batch.set(ref, msg.toFirestore(), SetOptions(merge: true));
      ids.add(msg.messageId);
    }

    await batch.commit();
    await _localDb.markSynced(ids);
    _log('Uploaded & marked synced: ${ids.length} message(s)');
  }

  // ── DOWNLOAD ─────────────────────────────────────────────────────────────────

  Future<void> _downloadMissing(String myUid) async {
    _log('Checking Firebase for messages addressed to $myUid');

    final snap = await _firestore
        .collection('mesh_messages')
        .where('receiver_id', isEqualTo: myUid)
        .orderBy('timestamp', descending: false)
        .limit(100)
        .get();

    int inserted = 0;
    for (final doc in snap.docs) {
      final msg = MeshMessage.fromFirestore(doc.data());
      await _localDb.upsertFromFirebase(msg);
      inserted++;
    }
    _log('Downloaded $inserted remote message(s)');
  }

  static void _log(String msg) => debugPrint('[MeshSync] $msg');
}
