import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local cache for user profiles.
///
/// Stores minimal profile data (uid, username, avatar, bio) so BLE
/// discovery can show user info without an internet connection.
/// Synced from Firestore whenever the app is online.
class UserCacheService {
  static const String _cacheKey = 'proxi_user_cache';
  static const String _lastSyncKey = 'proxi_cache_last_sync';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Cache a single user's profile data.
  Future<void> cacheUser(Map<String, dynamic> userData) async {
    final prefs = await _preferences;
    final cache = await getAllCachedUsers();
    final uid = userData['uid'] as String? ?? '';
    if (uid.isEmpty) return;
    cache[uid] = {
      'uid': uid,
      'username': userData['username'] ?? '',
      'avatar_formal': userData['avatar_formal'] ?? '',
      'avatar_casual': userData['avatar_casual'] ?? '',
      'bio': userData['bio'] ?? '',
      'headline': userData['headline'] ?? '',
      'full_name': userData['full_name'] ?? '',
      'cached_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  /// Cache multiple users at once (batch sync from Firestore).
  Future<void> cacheUsers(List<Map<String, dynamic>> users) async {
    final prefs = await _preferences;
    final cache = await getAllCachedUsers();
    for (final u in users) {
      final uid = u['uid'] as String? ?? '';
      if (uid.isEmpty) continue;
      cache[uid] = {
        'uid': uid,
        'username': u['username'] ?? '',
        'avatar_formal': u['avatar_formal'] ?? '',
        'avatar_casual': u['avatar_casual'] ?? '',
        'bio': u['bio'] ?? '',
        'headline': u['headline'] ?? '',
        'full_name': u['full_name'] ?? '',
        'cached_at': DateTime.now().toIso8601String(),
      };
    }
    await prefs.setString(_cacheKey, jsonEncode(cache));
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Get a cached user by UID. Returns null if not cached.
  Future<Map<String, dynamic>?> getCachedUser(String uid) async {
    final cache = await getAllCachedUsers();
    return cache[uid];
  }

  /// Get all cached users as a map of uid → profile data.
  Future<Map<String, Map<String, dynamic>>> getAllCachedUsers() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    } catch (_) {
      return {};
    }
  }

  /// Get the last sync time.
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Clear all cached data.
  Future<void> clearCache() async {
    final prefs = await _preferences;
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastSyncKey);
  }

  /// Get total number of cached users.
  Future<int> get cachedUserCount async {
    final cache = await getAllCachedUsers();
    return cache.length;
  }
}
