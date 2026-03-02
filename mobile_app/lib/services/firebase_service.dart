import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import 'cloudinary_service.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _storage = CloudinaryService();

  // ─────────────────────────────────────────────
  //  USER OPERATIONS
  // ─────────────────────────────────────────────

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  /// Real-time stream of the user's profile document.
  Stream<AppUser?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return AppUser.fromFirestore(query.docs.first);
  }

  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set({
      ...data,
      'followers': [],
      'following': [],
      'followers_formal': [],
      'followers_casual': [],
      'following_formal': [],
      'following_casual': [],
      'skills': [],
      'experience': [],
      'education': [],
      'certifications': [],
      'portfolio_links': [],
      'open_to_work': false,
      'hiring': false,
      'visibility': 'public',
      'discoverable': true,
      'created_at': FieldValue.serverTimestamp(),
      'last_active': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'last_active': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────
  //  FEED OPERATIONS
  // ─────────────────────────────────────────────

  Stream<List<Post>> getFeedStream(String mode) {
    return _db
        .collection('posts')
        .where('mode', isEqualTo: mode)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Post.fromFirestore(d)).toList());
  }

  Stream<List<Map<String, dynamic>>> getStoriesStream(String mode) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _db
        .collection('stories')
        .where('mode', isEqualTo: mode)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> createPost({
    required String authorId,
    required String username,
    required String authorAvatar,
    required String text,
    required String mode,
    required String type,
    String? mediaUrl,
    String? thumbnailUrl,
    double duration = 0,
    String visibility = 'public',
  }) async {
    final data = <String, dynamic>{
      'author_id': authorId,
      'username': username,
      'author_avatar': authorAvatar,
      'text': text,
      'mode': mode,
      'type': type,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'visibility': visibility,
      'likes': <String>[],
      'comments': <Map<String, dynamic>>[],
      'views': 0,
      'shares': 0,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (type == 'story') {
      data['expires_at'] =
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));
      await _db.collection('stories').add(data);
    } else if (type == 'reel') {
      await _db.collection('reels').add(data);
    } else {
      await _db.collection('posts').add(data);
    }
  }

  Future<void> toggleLike(String postId, String uid, String username, {String collection = 'posts'}) async {
    final ref = _db.collection(collection).doc(postId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    if (likes.contains(uid)) {
      await ref.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([uid])
      });
      final authorId = doc.data()?['author_id'];
      if (authorId != null && authorId != uid) {
        await createNotification(
          userId: authorId,
          fromUid: uid,
          fromUsername: username,
          type: 'like',
          text: collection == 'reels' ? 'liked your reel' : 'liked your post',
          postId: postId,
        );
      }
    }
  }

  Future<void> addComment(
      String postId, String uid, String username, String text, {String collection = 'posts'}) async {
    final ref = _db.collection(collection).doc(postId);
    await ref.update({
      'comments': FieldValue.arrayUnion([
        {
          'user': username,
          'uid': uid,
          'text': text,
          'timestamp': DateTime.now().toIso8601String(),
        }
      ])
    });

    final doc = await ref.get();
    final authorId = doc.data()?['author_id'];
    if (authorId != null && authorId != uid) {
      await createNotification(
        userId: authorId,
        fromUid: uid,
        fromUsername: username,
        type: 'comment',
        text: 'commented: $text',
        postId: postId,
      );
    }
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  Future<void> deleteReel(String reelId) async {
    await _db.collection('reels').doc(reelId).delete();
  }

  Future<void> deleteStory(String storyId) async {
    await _db.collection('stories').doc(storyId).delete();
  }

  Future<void> deleteConnection(String connectionId) async {
    final doc = await _db.collection('connections').doc(connectionId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    // Remove mutual follow if it was accepted
    if (data['status'] == 'accepted') {
      final from = data['from'] as String;
      final to = data['to'] as String;
      final mode = data['mode'] ?? 'formal';
      await unfollowUser(from, to, mode: mode);
      await unfollowUser(to, from, mode: mode);
    }
    await _db.collection('connections').doc(connectionId).delete();
  }

  /// Find the connection doc ID between two users (any direction, any status).
  /// Optionally filter by [mode].
  Future<String?> findConnectionId(String uid1, String uid2, {String? mode}) async {
    final q1 = await _db
        .collection('connections')
        .where('from', isEqualTo: uid1)
        .where('to', isEqualTo: uid2)
        .get();
    for (final doc in q1.docs) {
      if (mode == null || doc.data()['mode'] == mode) return doc.id;
    }

    final q2 = await _db
        .collection('connections')
        .where('from', isEqualTo: uid2)
        .where('to', isEqualTo: uid1)
        .get();
    for (final doc in q2.docs) {
      if (mode == null || doc.data()['mode'] == mode) return doc.id;
    }
    return null;
  }

  // ─────────────────────────────────────────────
  //  USER POSTS
  // ─────────────────────────────────────────────

  Stream<List<Post>> getUserPostsStream(String uid) {
    return _db
        .collection('posts')
        .where('author_id', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Post.fromFirestore(d)).toList());
  }

  // ─────────────────────────────────────────────
  //  REELS (Phase 4)
  // ─────────────────────────────────────────────

  Stream<List<Post>> getReelsStream(String mode) {
    return _db
        .collection('reels')
        .where('mode', isEqualTo: mode)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Post.fromFirestore(d)).toList());
  }

  Future<void> recordReelView(String reelId) async {
    await _db.collection('reels').doc(reelId).update({
      'views': FieldValue.increment(1),
    });
  }

  // ─────────────────────────────────────────────
  //  CHAT OPERATIONS
  // ─────────────────────────────────────────────

  String getChatId(String uid1, String uid2, {String mode = 'formal'}) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}_$mode';
  }

  Stream<List<Map<String, dynamic>>> getChatStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String senderUsername,
    required String receiverUid,
    String? text,
    String? fileUrl,
    String? fileType,
    String mode = 'formal',
  }) async {
    await _db.collection('chats').doc(chatId).set({
      'participants': [senderUid, receiverUid],
      'last_message': text ?? (fileType != null ? 'Sent a \$fileType' : ''),
      'last_timestamp': FieldValue.serverTimestamp(),
      'mode': mode,
    }, SetOptions(merge: true));

    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'sender_uid': senderUid,
      'sender_username': senderUsername,
      'text': text ?? '',
      'file_url': fileUrl,
      'file_type': fileType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (text != null && text.isNotEmpty) {
      await createNotification(
        userId: receiverUid,
        fromUid: senderUid,
        fromUsername: senderUsername,
        type: 'message',
        text: text,
      );
    }
  }

  Stream<List<Map<String, dynamic>>> getConversationsStream(String uid, {String? mode}) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('last_timestamp', descending: true)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mode != null) {
        return docs.where((c) => c['mode'] == mode).toList();
      }
      return docs;
    });
  }

  // ─────────────────────────────────────────────
  //  NOTIFICATIONS
  // ─────────────────────────────────────────────

  Future<void> createNotification({
    required String userId,
    required String fromUid,
    required String fromUsername,
    required String type,
    required String text,
    String? postId,
  }) async {
    await _db.collection('notifications').add({
      'user_id': userId,
      'from_uid': fromUid,
      'from_username': fromUsername,
      'type': type,
      'text': text,
      'post_id': postId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<NotificationItem>> getNotificationsStream(String uid) {
    return _db
        .collection('notifications')
        .where('user_id', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NotificationItem.fromFirestore(d)).toList());
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // ─────────────────────────────────────────────
  //  FILE UPLOAD (Cloudinary — free, no credit card)
  // ─────────────────────────────────────────────

  Future<String> uploadFile(File file, String path) async {
    return await _storage.uploadFile(file, path);
  }

  // ─────────────────────────────────────────────
  //  FOLLOW / UNFOLLOW
  // ─────────────────────────────────────────────

  Future<void> followUser(String myUid, String targetUid, {String mode = 'formal'}) async {
    final modeFollowing = 'following_$mode';
    final modeFollowers = 'followers_$mode';
    await _db.collection('users').doc(myUid).update({
      'following': FieldValue.arrayUnion([targetUid]),
      modeFollowing: FieldValue.arrayUnion([targetUid]),
    });
    await _db.collection('users').doc(targetUid).update({
      'followers': FieldValue.arrayUnion([myUid]),
      modeFollowers: FieldValue.arrayUnion([myUid]),
    });
  }

  Future<void> unfollowUser(String myUid, String targetUid, {String mode = 'formal'}) async {
    final modeFollowing = 'following_$mode';
    final modeFollowers = 'followers_$mode';
    await _db.collection('users').doc(myUid).update({
      'following': FieldValue.arrayRemove([targetUid]),
      modeFollowing: FieldValue.arrayRemove([targetUid]),
    });
    await _db.collection('users').doc(targetUid).update({
      'followers': FieldValue.arrayRemove([myUid]),
      modeFollowers: FieldValue.arrayRemove([myUid]),
    });
  }

  // ─────────────────────────────────────────────
  //  NEARBY / DISCOVERY
  // ─────────────────────────────────────────────

  Future<List<AppUser>> getNearbyUsers() async {
    final snap = await _db
        .collection('users')
        .where('discoverable', isEqualTo: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => AppUser.fromFirestore(d)).toList();
  }

  /// Get nearby users by GPS within [radiusKm] of [lat],[lng].
  Future<List<AppUser>> getNearbyByGps(
      double lat, double lng, double radiusKm) async {
    final snap = await _db
        .collection('users')
        .where('discoverable', isEqualTo: true)
        .get();

    return snap.docs
        .map((d) => AppUser.fromFirestore(d))
        .where((u) {
          if (u.locationLat == null || u.locationLng == null) return false;
          final dist = _haversine(lat, lng, u.locationLat!, u.locationLng!);
          return dist <= radiusKm;
        })
        .map((u) {
          final dist = _haversine(lat, lng, u.locationLat!, u.locationLng!);
          return u.copyWith(distanceKm: dist);
        })
        .toList()
      ..sort((a, b) =>
          (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
  }

  Future<void> updateLocation(String uid, double lat, double lng, {bool bleActive = false}) async {
    await _db.collection('users').doc(uid).update({
      'location': {
        'lat': lat,
        'lng': lng,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'ble_active': bleActive,
      'ble_last_scan': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearLocation(String uid) async {
    await _db.collection('users').doc(uid).update({
      'location': FieldValue.delete(),
      'ble_active': false,
    });
  }

  /// Get nearby users by GPS within [radiusKm] who are BLE-active
  /// (have ble_active flag set to true and location within range).
  Future<List<AppUser>> getNearbyBleUsers(
      double lat, double lng, double radiusKm,
      {int maxAgeMinutes = 5}) async {
    final snap = await _db
        .collection('users')
        .where('discoverable', isEqualTo: true)
        .where('ble_active', isEqualTo: true)
        .get();

    return snap.docs
        .map((d) => AppUser.fromFirestore(d))
        .where((u) {
          if (u.locationLat == null || u.locationLng == null) return false;
          final dist = _haversine(lat, lng, u.locationLat!, u.locationLng!);
          return dist <= radiusKm;
        })
        .map((u) {
          final dist = _haversine(lat, lng, u.locationLat!, u.locationLng!);
          return u.copyWith(distanceKm: dist);
        })
        .toList()
      ..sort((a, b) =>
          (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
  }

  // ─────────────────────────────────────────────
  //  JOBS (Phase 2 — Formal Mode Only)
  // ─────────────────────────────────────────────

  Future<void> createJob(Map<String, dynamic> data) async {
    await _db.collection('jobs').add({
      ...data,
      'timestamp': FieldValue.serverTimestamp(),
      'active': true,
      'applicants': <String>[],
    });
  }

  Stream<List<Job>> getJobsStream() {
    return _db
        .collection('jobs')
        .where('active', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Job.fromFirestore(d)).toList());
  }

  Future<void> applyToJob(String jobId, String uid) async {
    await _db.collection('jobs').doc(jobId).update({
      'applicants': FieldValue.arrayUnion([uid]),
    });
  }

  // ─────────────────────────────────────────────
  //  CONNECTIONS (Phase 6)
  // ─────────────────────────────────────────────

  Future<void> sendConnectionRequest({
    required String fromUid,
    required String toUid,
    required String fromUsername,
    required String mode,
    String message = '',
  }) async {
    // Check existing: from → to (same mode only; null mode = any mode)
    final existing = await _db
        .collection('connections')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .get();
    for (final doc in existing.docs) {
      final docMode = doc.data()['mode'];
      if (docMode != null && docMode != mode) continue; // skip other modes
      final status = doc.data()['status'] ?? '';
      if (status == 'pending' || status == 'accepted') return; // Already active in this mode
      // Declined/blocked — remove so we can re-send
      await doc.reference.delete();
    }

    // Check reverse: to → from (same mode only)
    final reverse = await _db
        .collection('connections')
        .where('from', isEqualTo: toUid)
        .where('to', isEqualTo: fromUid)
        .get();
    for (final doc in reverse.docs) {
      final docMode = doc.data()['mode'];
      if (docMode != null && docMode != mode) continue;
      final status = doc.data()['status'] ?? '';
      if (status == 'pending' || status == 'accepted') return;
      await doc.reference.delete();
    }

    await _db.collection('connections').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'mode': mode,
      'message': message,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await createNotification(
      userId: toUid,
      fromUid: fromUid,
      fromUsername: fromUsername,
      type: 'connection_request',
      text: 'wants to connect with you',
    );
  }

  Future<void> respondToConnection(String connectionId, String status) async {
    final doc =
        await _db.collection('connections').doc(connectionId).get();
    if (!doc.exists) return;

    await _db.collection('connections').doc(connectionId).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (status == 'accepted') {
      final data = doc.data()!;
      final mode = data['mode'] ?? 'formal';
      // Mutual follow: both users follow each other in the connection's mode
      await followUser(data['from'], data['to'], mode: mode);
      await followUser(data['to'], data['from'], mode: mode);
      // Notify the requester that their connection was accepted
      final acceptor = await getUser(data['to']);
      await createNotification(
        userId: data['from'],
        fromUid: data['to'],
        fromUsername: acceptor?.username ?? '',
        type: 'connection_accepted',
        text: 'accepted your connection request',
      );
    }
  }

  Stream<List<Map<String, dynamic>>> getConnectionsStream(String uid, {String? mode}) {
    return _db
        .collection('connections')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs
            .where((d) {
                final data = d.data();
                final isUser = data['from'] == uid || data['to'] == uid;
                if (!isUser) return false;
                if (mode != null) return data['mode'] == mode;
                return true;
            })
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getSentRequestsStream(String uid, {String? mode}) {
    return _db
        .collection('connections')
        .where('from', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mode != null) return docs.where((d) => d['mode'] == mode).toList();
      return docs;
    });
  }

  Stream<List<Map<String, dynamic>>> getPendingRequestsStream(String uid, {String? mode}) {
    return _db
        .collection('connections')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mode != null) return docs.where((d) => d['mode'] == mode).toList();
      return docs;
    });
  }

  /// Returns directional connection status:
  /// 'accepted', 'pending_sent', 'pending_received', or 'none'.
  Future<String> getConnectionStatus(String myUid, String otherUid) async {
    // Check outgoing: I sent to them
    final q1 = await _db
        .collection('connections')
        .where('from', isEqualTo: myUid)
        .where('to', isEqualTo: otherUid)
        .get();
    for (final doc in q1.docs) {
      final status = doc.data()['status'] ?? '';
      if (status == 'accepted') return 'accepted';
      if (status == 'pending') return 'pending_sent';
    }

    // Check incoming: they sent to me
    final q2 = await _db
        .collection('connections')
        .where('from', isEqualTo: otherUid)
        .where('to', isEqualTo: myUid)
        .get();
    for (final doc in q2.docs) {
      final status = doc.data()['status'] ?? '';
      if (status == 'accepted') return 'accepted';
      if (status == 'pending') return 'pending_received';
    }

    return 'none';
  }

  /// Find the incoming connection doc ID from [senderUid] to [receiverUid].
  Future<String?> findIncomingConnectionId(String senderUid, String receiverUid) async {
    final q = await _db
        .collection('connections')
        .where('from', isEqualTo: senderUid)
        .where('to', isEqualTo: receiverUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.id;
    return null;
  }

  // ─────────────────────────────────────────────
  //  HAVERSINE DISTANCE
  // ─────────────────────────────────────────────

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  // ─────────────────────────────────────────────
  //  GROUP CHAT OPERATIONS
  // ─────────────────────────────────────────────

  /// Create a new group chat and return its document ID.
  Future<String> createGroupChat({
    required String name,
    required String creatorUid,
    required List<String> memberUids,
    String mode = 'formal',
  }) async {
    final all = <String>{creatorUid, ...memberUids}.toList();
    final doc = await _db.collection('group_chats').add({
      'name': name,
      'creator': creatorUid,
      'members': all,
      'last_message': '',
      'last_timestamp': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'mode': mode,
    });
    return doc.id;
  }

  /// Stream of group chats this user is a member of.
  Stream<List<Map<String, dynamic>>> getGroupChatsStream(String uid, {String? mode}) {
    return _db
        .collection('group_chats')
        .where('members', arrayContains: uid)
        .orderBy('last_timestamp', descending: true)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mode != null) {
        return docs.where((g) => g['mode'] == mode).toList();
      }
      return docs;
    });
  }

  /// Send a message in a group chat.
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderUid,
    required String senderUsername,
    String? text,
    String? fileUrl,
    String? fileType,
  }) async {
    await _db.collection('group_chats').doc(groupId).update({
      'last_message': text ?? (fileType != null ? 'Sent a $fileType' : ''),
      'last_timestamp': FieldValue.serverTimestamp(),
    });

    await _db
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .add({
      'sender_uid': senderUid,
      'sender_username': senderUsername,
      'text': text ?? '',
      'file_url': fileUrl,
      'file_type': fileType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of messages in a group chat.
  Stream<List<Map<String, dynamic>>> getGroupChatStream(String groupId) {
    return _db
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Add members to an existing group chat.
  Future<void> addGroupMembers(String groupId, List<String> uids) async {
    await _db.collection('group_chats').doc(groupId).update({
      'members': FieldValue.arrayUnion(uids),
    });
  }

  /// Remove a member from a group chat.
  Future<void> removeGroupMember(String groupId, String uid) async {
    await _db.collection('group_chats').doc(groupId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  // ─────────────────────────────────────────────
  //  CHAT DELETE / CLEAR OPERATIONS
  // ─────────────────────────────────────────────

  /// Delete a single message from a DM chat.
  Future<void> deleteChatMessage(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Clear all messages in a DM chat (keeps the chat doc).
  Future<void> clearChat(String chatId) async {
    final msgs = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    // Reset last message
    await _db.collection('chats').doc(chatId).update({
      'last_message': '',
      'last_timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a DM chat entirely (messages + chat doc).
  Future<void> deleteChat(String chatId) async {
    // Delete all messages first
    final msgs = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('chats').doc(chatId));
    await batch.commit();
  }

  /// Delete a single message from a group chat.
  Future<void> deleteGroupChatMessage(String groupId, String messageId) async {
    await _db
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Clear all messages in a group chat (keeps the group doc).
  Future<void> clearGroupChat(String groupId) async {
    final msgs = await _db
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    // Reset last message
    await _db.collection('group_chats').doc(groupId).update({
      'last_message': '',
      'last_timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a group chat entirely (messages + group doc).
  Future<void> deleteGroupChat(String groupId) async {
    final msgs = await _db
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('group_chats').doc(groupId));
    await batch.commit();
  }
}
