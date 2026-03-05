import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/ble_advertiser_service.dart';
import 'services/firebase_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/user_cache_service.dart';
import 'ble_service.dart';
import 'models.dart';

enum DiscoveryMode { ble, gps }

class AppState extends ChangeNotifier {
  final AuthService auth = AuthService();
  final FirebaseService firebase = FirebaseService();
  final BleService ble = BleService();
  final BleAdvertiserService bleAdvertiser = BleAdvertiserService();
  final LocationService location = LocationService();
  final UserCacheService userCache = UserCacheService();

  AppUser? currentUser;
  bool isFormal = true;
  bool isAuthLoading = true; // True until first auth check
  List<Post> feed = [];
  List<Map<String, dynamic>> stories = [];
  List<AppUser> nearbyUsers = [];
  List<Post> reels = [];
  List<Job> jobs = [];
  DiscoveryMode discoveryMode = DiscoveryMode.ble;

  StreamSubscription? _feedSub;
  StreamSubscription? _storySub;
  StreamSubscription? _reelsSub;
  StreamSubscription? _jobsSub;
  StreamSubscription? _connectionsSub;
  StreamSubscription? _sentRequestsSub;
  StreamSubscription? _receivedRequestsSub;
  StreamSubscription? _profileSub; // Real-time profile listener
  StreamSubscription? _notifSub; // Real-time push notification listener
  final NotificationService _notifService = NotificationService();
  bool _notifInitialSnapshotSkipped = false; // Skip first snapshot to avoid old notifs
  List<String> _connectedUids = []; // UIDs of accepted connections
  List<String> _pendingSentUids = []; // UIDs where current user sent pending request
  List<String> _pendingReceivedUids = []; // UIDs who sent current user a pending request

  AppState() {
    // Listen for Firebase Auth state changes (auto-login on restart)
    auth.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        final profile = await firebase.getUser(firebaseUser.uid);
        if (profile != null) {
          currentUser = profile;
          _startListeners();
        }
      } else {
        currentUser = null;
        _stopListeners();
      }
      isAuthLoading = false;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────
  //  AUTH
  // ─────────────────────────────────────────────

  Future<String?> login(String email, String password) async {
    try {
      final cred = await auth.signIn(email, password);
      final profile = await firebase.getUser(cred.user!.uid);
      if (profile != null) {
        currentUser = profile;
        _startListeners();
        _registerFcmToken();
        // Start BLE advertising + sync user cache (non-blocking)
        startBleAdvertising();
        syncUserCacheFromFirestore();
        notifyListeners();
      }
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register(
      String email, String password, String username) async {
    try {
      final cred = await auth.signUp(email, password);
      await firebase.createUserProfile(cred.user!.uid, {
        'username': username,
        'email': email,
        'bio': '',
        'avatar_formal': '',
        'avatar_casual': '',
        'ble_uuid': '',
      });
      final profile = await firebase.getUser(cred.user!.uid);
      currentUser = profile;
      _startListeners();
      _registerFcmToken();
      // Start BLE advertising + sync user cache (non-blocking)
      startBleAdvertising();
      syncUserCacheFromFirestore();
      notifyListeners();
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _registerFcmToken() async {
    if (currentUser == null) return;
    try {
      final token = await NotificationService().getToken();
      if (token != null) {
        await firebase.updateProfile(currentUser!.uid, {'fcm_token': token});
      }
      // Listen for token refreshes and update Firestore
      NotificationService().onTokenRefresh().listen((newToken) {
        if (currentUser != null) {
          firebase.updateProfile(currentUser!.uid, {'fcm_token': newToken});
        }
      });
    } catch (_) {}
  }

  Future<void> logout() async {
    _stopListeners();
    await stopBleAdvertising();
    if (currentUser != null) {
      try { await firebase.clearLocation(currentUser!.uid); } catch (_) {}
    }
    await auth.signOut();
    currentUser = null;
    feed = [];
    stories = [];
    nearbyUsers = [];
    reels = [];
    jobs = [];
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  MODE TOGGLE
  // ─────────────────────────────────────────────

  void toggleMode() {
    isFormal = !isFormal;
    _startListeners(); // re-subscribe with new mode
    notifyListeners();
  }

  String get currentMode => isFormal ? 'formal' : 'casual';

  // ─────────────────────────────────────────────
  //  REAL-TIME LISTENERS
  // ─────────────────────────────────────────────

  void _startListeners() {
    _stopListeners();

    // Track accepted connections — needed for visibility filtering
    if (currentUser != null) {
      // Live profile listener — keeps followers/following/avatar in sync
      _profileSub = firebase.getUserStream(currentUser!.uid).listen((user) {
        if (user != null) {
          currentUser = user;
          notifyListeners();
        }
      });

      // Live notification listener — shows local push for new notifications
      _notifInitialSnapshotSkipped = false;
      _notifSub = firebase
          .getNotificationsStream(currentUser!.uid)
          .listen((notifications) {
        if (!_notifInitialSnapshotSkipped) {
          // Skip the first snapshot (existing notifications already in Firestore)
          _notifInitialSnapshotSkipped = true;
          return;
        }
        // Show local push for unread notifications
        for (final n in notifications) {
          if (!n.read) {
            String title = 'Proxi';
            String body = n.text;
            switch (n.type) {
              case 'like':
                title = '❤️ ${n.fromUser} liked your post';
                break;
              case 'comment':
                title = '💬 ${n.fromUser} commented';
                break;
              case 'connection_request':
                title = '🤝 Connection Request';
                body = '${n.fromUser} wants to connect';
                break;
              case 'connection_accepted':
                title = '✅ Connection Accepted';
                body = '${n.fromUser} accepted your request';
                break;
              case 'message':
                title = '📩 ${n.fromUser}';
                break;
              default:
                title = 'Proxi';
            }
            _notifService.showLocal(
              id: n.id.hashCode,
              title: title,
              body: body,
            );
          }
        }
      });

      _connectionsSub =
          firebase.getConnectionsStream(currentUser!.uid, mode: currentMode).listen((list) {
        _connectedUids = list.map((m) {
          final from = m['from'] as String? ?? '';
          final to = m['to'] as String? ?? '';
          return from == currentUser!.uid ? to : from;
        }).toList();
        notifyListeners();
      });

      // Track pending sent requests (across ALL modes so status shows after toggling)
      _sentRequestsSub =
          firebase.getSentRequestsStream(currentUser!.uid).listen((list) {
        _pendingSentUids = list
            .map((m) => m['to'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        notifyListeners();
      });

      // Track pending received requests (across ALL modes so requests from other mode are visible)
      _receivedRequestsSub =
          firebase.getPendingRequestsStream(currentUser!.uid).listen((list) {
        _pendingReceivedUids = list
            .map((m) => m['from'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        notifyListeners();
      });
    }

    _feedSub = firebase.getFeedStream(currentMode).listen((posts) {
      feed = posts.where(_isPostVisible).toList();
      notifyListeners();
    });

    _storySub = firebase.getStoriesStream(currentMode).listen((storyList) {
      stories = storyList.where(_isStoryVisible).toList();
      notifyListeners();
    });

    _reelsSub = firebase.getReelsStream(currentMode).listen((reelList) {
      reels = reelList.where(_isPostVisible).toList();
      notifyListeners();
    });

    _jobsSub = firebase.getJobsStream().listen((jobList) {
      jobs = jobList;
      notifyListeners();
    });
  }

  // ---- Visibility helpers ----

  /// Check if a Post is visible to the current user based on author's visibility setting.
  bool _isPostVisible(Post post) {
    if (currentUser == null) return false;
    if (post.authorId == currentUser!.uid) return true; // own content
    final vis = post.visibility;
    if (vis == 'private') return false;
    if (vis == 'connections') return _connectedUids.contains(post.authorId);
    return true; // public or unset
  }

  /// Check if a story map is visible to the current user.
  bool _isStoryVisible(Map<String, dynamic> story) {
    if (currentUser == null) return false;
    final authorId = story['author_id'] ?? '';
    if (authorId == currentUser!.uid) return true;
    final vis = story['visibility'] ?? 'public';
    if (vis == 'private') return false;
    if (vis == 'connections') return _connectedUids.contains(authorId);
    return true;
  }

  /// List of connected user UIDs (accepted connections)
  List<String> get connectedUids => _connectedUids;

  /// UIDs where current user sent a pending request
  List<String> get pendingSentUids => _pendingSentUids;

  /// UIDs who sent current user a pending request
  List<String> get pendingReceivedUids => _pendingReceivedUids;

  /// Get the connection status with another user (synchronous, uses cached data).
  /// Returns: 'accepted', 'pending_sent', 'pending_received', or 'none'
  String connectionStatusWith(String uid) {
    if (_connectedUids.contains(uid)) return 'accepted';
    if (_pendingSentUids.contains(uid)) return 'pending_sent';
    if (_pendingReceivedUids.contains(uid)) return 'pending_received';
    return 'none';
  }

  void _stopListeners() {
    _feedSub?.cancel();
    _storySub?.cancel();
    _reelsSub?.cancel();
    _jobsSub?.cancel();
    _connectionsSub?.cancel();
    _sentRequestsSub?.cancel();
    _receivedRequestsSub?.cancel();
    _profileSub?.cancel();
    _notifSub?.cancel();
  }

  /// Manual refresh (pull-to-refresh) — re-subscribe.
  Future<void> refresh() async {
    _startListeners();
  }

  // ─────────────────────────────────────────────
  //  POST OPERATIONS
  // ─────────────────────────────────────────────

  Future<void> createPost(String text, File? file, bool isStory) async {
    if (currentUser == null) return;
    String? mediaUrl;
    if (file != null) {
      final path =
          '${isStory ? "stories" : "posts"}/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}';
      mediaUrl = await firebase.uploadFile(file, path);
    }
    await firebase.createPost(
      authorId: currentUser!.uid,
      username: currentUser!.username,
      authorAvatar: currentUser!.getAvatar(isFormal),
      text: text,
      mode: currentMode,
      type: isStory ? 'story' : 'post',
      mediaUrl: mediaUrl,
      visibility: currentUser!.visibility,
    );
  }

  Future<void> createReel(String text, File videoFile) async {
    if (currentUser == null) return;
    final path =
        'reels/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}';
    final mediaUrl = await firebase.uploadFile(videoFile, path);
    await firebase.createPost(
      authorId: currentUser!.uid,
      username: currentUser!.username,
      authorAvatar: currentUser!.getAvatar(isFormal),
      text: text,
      mode: currentMode,
      type: 'reel',
      mediaUrl: mediaUrl,
      visibility: currentUser!.visibility,
    );
  }

  Future<void> recordReelView(String reelId) async {
    await firebase.recordReelView(reelId);
  }

  Future<void> toggleLike(String postId, {String collection = 'posts'}) async {
    if (currentUser == null) return;
    await firebase.toggleLike(postId, currentUser!.uid, currentUser!.username, collection: collection);
  }

  Future<void> addComment(String postId, String text, {String collection = 'posts'}) async {
    if (currentUser == null) return;
    await firebase.addComment(
        postId, currentUser!.uid, currentUser!.username, text, collection: collection);
  }

  // ─────────────────────────────────────────────
  //  DELETE CONTENT
  // ─────────────────────────────────────────────

  Future<void> deletePost(String postId) async {
    await firebase.deletePost(postId);
  }

  Future<void> deleteReel(String reelId) async {
    await firebase.deleteReel(reelId);
  }

  Future<void> deleteStory(String storyId) async {
    await firebase.deleteStory(storyId);
  }

  /// Remove a connection (accepted, pending, etc.) and allow reconnect later.
  Future<void> removeConnection(String otherUid) async {
    if (currentUser == null) return;
    final connId = await firebase.findConnectionId(currentUser!.uid, otherUid, mode: currentMode);
    if (connId != null) {
      await firebase.deleteConnection(connId);
    }
    currentUser = await firebase.getUser(currentUser!.uid);
    notifyListeners();
  }

  /// Remove a user from current user's followers in current mode.
  Future<void> removeFollower(String followerUid) async {
    if (currentUser == null) return;
    final connId = await firebase.findConnectionId(currentUser!.uid, followerUid, mode: currentMode);
    if (connId != null) {
      await firebase.deleteConnection(connId);
    } else {
      // No connection found — remove from follower lists directly
      await firebase.unfollowUser(followerUid, currentUser!.uid, mode: currentMode);
    }
    currentUser = await firebase.getUser(currentUser!.uid);
    notifyListeners();
  }

  /// Unfollow a user in current mode.
  Future<void> unfollowUserAction(String targetUid) async {
    if (currentUser == null) return;
    final connId = await firebase.findConnectionId(currentUser!.uid, targetUid, mode: currentMode);
    if (connId != null) {
      await firebase.deleteConnection(connId);
    } else {
      await firebase.unfollowUser(currentUser!.uid, targetUid, mode: currentMode);
    }
    currentUser = await firebase.getUser(currentUser!.uid);
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  NEARBY / DISCOVERY
  // ─────────────────────────────────────────────

  /// Error message from the last scan attempt (empty if successful).
  String bleScanError = '';

  /// Number of Proxi users detected via BLE in the last scan.
  int bleProxiUsersDetected = 0;

  /// Number of total BLE devices detected (for diagnostics).
  int bleDevicesDetected = 0;

  /// Whether BLE advertising is currently active.
  bool isBleAdvertising = false;

  /// Start BLE advertising (called on login and when entering BLE mode).
  Future<void> startBleAdvertising() async {
    if (currentUser == null) return;
    try {
      final supported = await bleAdvertiser.isSupported();
      if (!supported) return;
      await bleAdvertiser.startAdvertising(currentUser!.uid);
      isBleAdvertising = true;
      notifyListeners();
    } catch (_) {
      isBleAdvertising = false;
    }
  }

  /// Stop BLE advertising (called on logout and when leaving BLE mode).
  Future<void> stopBleAdvertising() async {
    try {
      await bleAdvertiser.stopAdvertising();
    } catch (_) {}
    isBleAdvertising = false;
    notifyListeners();
  }

  /// Sync discoverable users to local cache (call when online).
  Future<void> syncUserCacheFromFirestore() async {
    try {
      final users = await firebase.getDiscoverableUsers();
      await userCache.cacheUsers(users);
    } catch (_) {
      // Offline or error — cache stays as-is
    }
  }

  void scanNearby() async {
    bleScanError = '';
    bleDevicesDetected = 0;
    bleProxiUsersDetected = 0;

    if (discoveryMode == DiscoveryMode.ble) {
      // ═══════════════════════════════════════════
      //  BLE MODE — WORKS FULLY OFFLINE
      //  No internet required. Uses Bluetooth only.
      // ═══════════════════════════════════════════

      // ── Step 1: Verify Bluetooth is actually ON ──
      final btOn = await ble.isBluetoothOn();
      if (!btOn) {
        bleScanError = 'Bluetooth is turned off. Please enable Bluetooth in your device settings and try again.';
        notifyListeners();
        return;
      }

      // ── Step 2: Initialize BLE permissions ──
      final ready = await ble.init();
      if (!ready) {
        bleScanError = 'Bluetooth permissions denied. Please grant Bluetooth and Location permissions in Settings.';
        notifyListeners();
        return;
      }

      // ── Step 3: Start advertising our UID so others can find us ──
      await startBleAdvertising();

      // ── Step 4: Scan for other Proxi users (no internet needed!) ──
      // Looks for BLE advertisements with our custom manufacturer data.
      final proxiUsers = await ble.scanForProxiUsers(
        durationSeconds: 8,
        minRssi: BleService.rssiThreshold,
      );
      bleProxiUsersDetected = proxiUsers.length;

      // Run a quick general scan for diagnostics after a small delay
      // to avoid interfering with the Proxi scan results
      await Future.delayed(const Duration(milliseconds: 800));
      final allDevices = await ble.scanAndCollect(
        durationSeconds: 3,
        minRssi: BleService.rssiThreshold,
      );
      bleDevicesDetected = allDevices.length;

      // ── Step 5: Build user list from cache ──
      // For each discovered Proxi UID, look up their profile in local cache.
      final List<AppUser> foundUsers = [];
      for (final bleUser in proxiUsers) {
        if (bleUser.uid == currentUser?.uid) continue;

        // Try local cache first (works offline).
        // bleUser.uid may be a 20-char prefix (BLE advertisement packet limit),
        // so use prefix-aware lookup to find the full profile.
        final cached = await userCache.getCachedUserByUidPrefix(bleUser.uid);
        final resolvedUid = cached?['uid'] as String? ?? bleUser.uid;
        if (cached != null) {
          foundUsers.add(AppUser(
            uid: resolvedUid,
            username: cached['username'] ?? 'Proxi User',
            avatarFormal: cached['avatar_formal'] ?? '',
            avatarCasual: cached['avatar_casual'] ?? '',
            bio: cached['bio'] ?? '',
            headline: cached['headline'] ?? '',
            fullName: cached['full_name'] ?? '',
            distanceKm: bleUser.distanceM / 1000, // Convert meters → km
          ));
        } else {
          // Not in cache — show with minimal info (UID-based placeholder)
          foundUsers.add(AppUser(
            uid: resolvedUid,
            username: 'Proxi User',
            bio: '~${bleUser.distanceM.toStringAsFixed(0)}m away via Bluetooth',
            distanceKm: bleUser.distanceM / 1000,
          ));
        }
      }

      nearbyUsers = foundUsers
        ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));

      // ── Step 6 (optional): If online, also update location for GPS users ──
      try {
        final pos = await location.getCurrentPosition();
        if (pos != null && currentUser != null) {
          await firebase.updateLocation(
              currentUser!.uid, pos.latitude, pos.longitude, bleActive: true);
          // Sync cache while we have internet
          await syncUserCacheFromFirestore();
        }
      } catch (_) {
        // Offline — no problem, BLE results are already shown
      }

    } else {
      // ═══════════════════════════════════════════
      //  GPS MODE — REQUIRES INTERNET
      //  Uses Firestore to find users by location.
      // ═══════════════════════════════════════════

      // Stop BLE advertising (not needed in GPS mode)
      await stopBleAdvertising();

      final pos = await location.getCurrentPosition();
      if (pos == null) {
        bleScanError = 'Could not get your location. Please enable Location services and try again.';
        notifyListeners();
        return;
      }

      try {
        if (currentUser != null) {
          await firebase.updateLocation(
              currentUser!.uid, pos.latitude, pos.longitude);
        }
        final gpsUsers =
            await firebase.getNearbyByGps(pos.latitude, pos.longitude, 10);
        nearbyUsers = gpsUsers
            .where((u) => u.uid != currentUser?.uid)
            .toList();
      } catch (e) {
        bleScanError = 'GPS discovery requires internet connection. Please connect to the internet and try again.';
        notifyListeners();
        return;
      }
    }
    notifyListeners();
  }

  void setDiscoveryMode(DiscoveryMode mode) {
    discoveryMode = mode;
    nearbyUsers = [];
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  NOTIFICATIONS
  // ─────────────────────────────────────────────

  Stream<List<NotificationItem>> get notificationsStream {
    if (currentUser == null) return const Stream.empty();
    return firebase.getNotificationsStream(currentUser!.uid);
  }

  // ─────────────────────────────────────────────
  //  PROFILE
  // ─────────────────────────────────────────────

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    await firebase.updateProfile(currentUser!.uid, data);
    currentUser = await firebase.getUser(currentUser!.uid);
    notifyListeners();
  }

  Future<String?> uploadAvatar(File file, bool isFormalAvatar) async {
    if (currentUser == null) return null;
    final path =
        'avatars/${currentUser!.uid}/${isFormalAvatar ? "formal" : "casual"}_${DateTime.now().millisecondsSinceEpoch}';
    final url = await firebase.uploadFile(file, path);
    await firebase.updateProfile(currentUser!.uid, {
      isFormalAvatar ? 'avatar_formal' : 'avatar_casual': url,
    });
    currentUser = await firebase.getUser(currentUser!.uid);
    notifyListeners();
    return url;
  }

  // ─────────────────────────────────────────────
  //  CHAT
  // ─────────────────────────────────────────────

  String getChatId(String otherUid) {
    if (currentUser == null) return '';
    return firebase.getChatId(currentUser!.uid, otherUid, mode: currentMode);
  }

  Stream<List<Map<String, dynamic>>> getChatMessages(String chatId) {
    return firebase.getChatStream(chatId);
  }

  Stream<List<Map<String, dynamic>>> get conversationsStream {
    if (currentUser == null) return const Stream.empty();
    return firebase.getConversationsStream(currentUser!.uid, mode: currentMode);
  }

  Future<void> sendMessage({
    required String chatId,
    required String receiverUid,
    String? text,
    String? fileUrl,
    String? fileType,
  }) async {
    if (currentUser == null) return;
    await firebase.sendMessage(
      chatId: chatId,
      senderUid: currentUser!.uid,
      senderUsername: currentUser!.username,
      receiverUid: receiverUid,
      text: text,
      fileUrl: fileUrl,
      fileType: fileType,
      mode: currentMode,
    );
  }

  /// Delete a single message in a DM chat.
  Future<void> deleteChatMessage(String chatId, String messageId) async {
    await firebase.deleteChatMessage(chatId, messageId);
  }

  /// Clear all messages in a DM chat.
  Future<void> clearChat(String chatId) async {
    await firebase.clearChat(chatId);
  }

  /// Delete a DM chat entirely (messages + chat doc).
  Future<void> deleteChat(String chatId) async {
    await firebase.deleteChat(chatId);
  }

  // ─────────────────────────────────────────────
  //  GROUP CHAT
  // ─────────────────────────────────────────────

  Future<String?> createGroupChat(String name, List<String> memberUids) async {
    if (currentUser == null) return null;
    return await firebase.createGroupChat(
      name: name,
      creatorUid: currentUser!.uid,
      memberUids: memberUids,
      mode: currentMode,
    );
  }

  Stream<List<Map<String, dynamic>>> get groupChatsStream {
    if (currentUser == null) return const Stream.empty();
    return firebase.getGroupChatsStream(currentUser!.uid, mode: currentMode);
  }

  Stream<List<Map<String, dynamic>>> getGroupMessages(String groupId) {
    return firebase.getGroupChatStream(groupId);
  }

  Future<void> sendGroupMessage({
    required String groupId,
    String? text,
    String? fileUrl,
    String? fileType,
  }) async {
    if (currentUser == null) return;
    await firebase.sendGroupMessage(
      groupId: groupId,
      senderUid: currentUser!.uid,
      senderUsername: currentUser!.username,
      text: text,
      fileUrl: fileUrl,
      fileType: fileType,
    );
  }

  /// Delete a single message in a group chat.
  Future<void> deleteGroupChatMessage(String groupId, String messageId) async {
    await firebase.deleteGroupChatMessage(groupId, messageId);
  }

  /// Clear all messages in a group chat.
  Future<void> clearGroupChat(String groupId) async {
    await firebase.clearGroupChat(groupId);
  }

  /// Delete a group chat entirely.
  Future<void> deleteGroupChat(String groupId) async {
    await firebase.deleteGroupChat(groupId);
  }

  // ─────────────────────────────────────────────
  //  CONNECTIONS (Phase 6)
  // ─────────────────────────────────────────────

  Future<void> sendConnectionRequest(String toUid) async {
    if (currentUser == null) return;
    await firebase.sendConnectionRequest(
      fromUid: currentUser!.uid,
      toUid: toUid,
      fromUsername: currentUser!.username,
      mode: currentMode,
    );
    // Refresh currentUser to pick up updated followers/following arrays
    currentUser = await firebase.getUser(currentUser!.uid);
    notifyListeners();
  }

  Future<void> respondToConnection(String connectionId, String status) async {
    await firebase.respondToConnection(connectionId, status);
    // Refresh currentUser to pick up updated followers/following arrays
    if (currentUser != null) {
      currentUser = await firebase.getUser(currentUser!.uid);
      notifyListeners();
    }
  }

  Stream<List<Connection>> get connectionsStream {
    if (currentUser == null) return const Stream.empty();
    return firebase.getConnectionsStream(currentUser!.uid, mode: currentMode)
        .map((list) => list.map((m) => Connection.fromMap(m)).toList());
  }

  Stream<List<Connection>> get pendingRequestsStream {
    if (currentUser == null) return const Stream.empty();
    // Show pending requests from ALL modes so cross-mode requests are visible
    return firebase.getPendingRequestsStream(currentUser!.uid)
        .map((list) => list.map((m) => Connection.fromMap(m)).toList());
  }

  // ─────────────────────────────────────────────
  //  JOBS (Phase 2)
  // ─────────────────────────────────────────────

  Future<void> createJob({
    Map<String, dynamic>? data,
    String? title,
    String? company,
    String description = '',
    List<String> skills = const [],
    String location = 'Remote',
    String type = 'full-time',
  }) async {
    if (currentUser == null) return;
    final payload = data ?? {
      'title': title ?? '',
      'company': company ?? '',
      'description': description,
      'skills': skills,
      'location': location,
      'type': type,
    };
    await firebase.createJob({
      ...payload,
      'author_id': currentUser!.uid,
      'author_username': currentUser!.username,
    });
  }

  Future<void> applyToJob(String jobId) async {
    if (currentUser == null) return;
    await firebase.applyToJob(jobId, currentUser!.uid);
  }

  @override
  void dispose() {
    _stopListeners();
    super.dispose();
  }
}