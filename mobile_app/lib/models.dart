import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────
//  USER MODEL
// ─────────────────────────────────────────────

class AppUser {
  final String uid;
  final String username;
  final String email;
  final String avatarFormal;
  final String avatarCasual;
  final String bio;
  final String bleUuid;
  final List<String> followers;
  final List<String> following;
  final List<String> followersFormal;
  final List<String> followersCasual;
  final List<String> followingFormal;
  final List<String> followingCasual;

  // Phase 2: Professional fields
  final String fullName;
  final String headline;
  final List<String> skills;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> education;
  final List<String> certifications;
  final List<String> portfolioLinks;
  final String? resumeUrl;
  final bool openToWork;
  final bool hiring;

  // Phase 3: Location
  final double? locationLat;
  final double? locationLng;
  final double? distanceKm;

  // Phase 5: Push
  final String? fcmToken;

  // Privacy / Discovery
  final String visibility;
  final bool discoverable;

  AppUser({
    required this.uid,
    required this.username,
    this.email = '',
    this.avatarFormal = '',
    this.avatarCasual = '',
    this.bio = '',
    this.bleUuid = '',
    this.followers = const [],
    this.following = const [],
    this.followersFormal = const [],
    this.followersCasual = const [],
    this.followingFormal = const [],
    this.followingCasual = const [],
    this.fullName = '',
    this.headline = '',
    this.skills = const [],
    this.experience = const [],
    this.education = const [],
    this.certifications = const [],
    this.portfolioLinks = const [],
    this.resumeUrl,
    this.openToWork = false,
    this.hiring = false,
    this.locationLat,
    this.locationLng,
    this.distanceKm,
    this.fcmToken,
    this.visibility = 'public',
    this.discoverable = true,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final loc = d['location'] as Map<String, dynamic>?;
    return AppUser(
      uid: doc.id,
      username: d['username'] ?? '',
      email: d['email'] ?? '',
      avatarFormal: d['avatar_formal'] ?? '',
      avatarCasual: d['avatar_casual'] ?? '',
      bio: d['bio'] ?? '',
      bleUuid: d['ble_uuid'] ?? '',
      followers: List<String>.from(d['followers'] ?? []),
      following: List<String>.from(d['following'] ?? []),
      followersFormal: List<String>.from(d['followers_formal'] ?? []),
      followersCasual: List<String>.from(d['followers_casual'] ?? []),
      followingFormal: List<String>.from(d['following_formal'] ?? []),
      followingCasual: List<String>.from(d['following_casual'] ?? []),
      fullName: d['full_name'] ?? '',
      headline: d['headline'] ?? '',
      skills: List<String>.from(d['skills'] ?? []),
      experience: List<Map<String, dynamic>>.from(d['experience'] ?? []),
      education: List<Map<String, dynamic>>.from(d['education'] ?? []),
      certifications: List<String>.from(d['certifications'] ?? []),
      portfolioLinks: List<String>.from(d['portfolio_links'] ?? []),
      resumeUrl: d['resume_url'],
      openToWork: d['open_to_work'] ?? false,
      hiring: d['hiring'] ?? false,
      locationLat: loc != null ? (loc['lat'] as num?)?.toDouble() : null,
      locationLng: loc != null ? (loc['lng'] as num?)?.toDouble() : null,
      fcmToken: d['fcm_token'],
      visibility: d['visibility'] ?? 'public',
      discoverable: d['discoverable'] ?? true,
    );
  }

  /// Old JSON factory — kept for backward compat / testing.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarFormal: json['avatar_formal'] ?? '',
      avatarCasual: json['avatar_casual'] ?? '',
      bio: json['bio'] ?? '',
      bleUuid: json['ble_uuid'] ?? '',
      followers: List<String>.from(json['followers'] ?? []),
      following: List<String>.from(json['following'] ?? []),
    );
  }

  String getAvatar(bool isFormal) => isFormal ? avatarFormal : avatarCasual;

  /// Mode-specific followers (falls back to global for legacy users).
  List<String> getFollowersForMode(String mode) {
    final modeList = mode == 'formal' ? followersFormal : followersCasual;
    // If any mode-specific data exists for any field, trust mode-specific lists
    final hasModeData = followersFormal.isNotEmpty ||
        followersCasual.isNotEmpty ||
        followingFormal.isNotEmpty ||
        followingCasual.isNotEmpty;
    if (hasModeData) return modeList;
    // Legacy user with no mode-specific data — fall back to global
    return followers;
  }

  /// Mode-specific following (falls back to global for legacy users).
  List<String> getFollowingForMode(String mode) {
    final modeList = mode == 'formal' ? followingFormal : followingCasual;
    final hasModeData = followersFormal.isNotEmpty ||
        followersCasual.isNotEmpty ||
        followingFormal.isNotEmpty ||
        followingCasual.isNotEmpty;
    if (hasModeData) return modeList;
    return following;
  }

  AppUser copyWith({
    String? uid,
    String? username,
    String? email,
    String? avatarFormal,
    String? avatarCasual,
    String? bio,
    String? bleUuid,
    List<String>? followers,
    List<String>? following,
    List<String>? followersFormal,
    List<String>? followersCasual,
    List<String>? followingFormal,
    List<String>? followingCasual,
    String? fullName,
    String? headline,
    List<String>? skills,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? education,
    List<String>? certifications,
    List<String>? portfolioLinks,
    String? resumeUrl,
    bool? openToWork,
    bool? hiring,
    double? locationLat,
    double? locationLng,
    double? distanceKm,
    String? fcmToken,
    String? visibility,
    bool? discoverable,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarFormal: avatarFormal ?? this.avatarFormal,
      avatarCasual: avatarCasual ?? this.avatarCasual,
      bio: bio ?? this.bio,
      bleUuid: bleUuid ?? this.bleUuid,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      followersFormal: followersFormal ?? this.followersFormal,
      followersCasual: followersCasual ?? this.followersCasual,
      followingFormal: followingFormal ?? this.followingFormal,
      followingCasual: followingCasual ?? this.followingCasual,
      fullName: fullName ?? this.fullName,
      headline: headline ?? this.headline,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      certifications: certifications ?? this.certifications,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      openToWork: openToWork ?? this.openToWork,
      hiring: hiring ?? this.hiring,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      distanceKm: distanceKm ?? this.distanceKm,
      fcmToken: fcmToken ?? this.fcmToken,
      visibility: visibility ?? this.visibility,
      discoverable: discoverable ?? this.discoverable,
    );
  }
}

// ─────────────────────────────────────────────
//  POST MODEL
// ─────────────────────────────────────────────

class Post {
  final String id;
  final String authorId;
  final String username;
  final String authorAvatar;
  final String text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final double duration;
  final List<String> likes;
  final List<Comment> comments;
  final int views;
  final int shares;
  final String type; // post | story | reel
  final String visibility; // public | connections | private

  Post({
    required this.id,
    this.authorId = '',
    required this.username,
    this.authorAvatar = '',
    required this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.duration = 0,
    this.likes = const [],
    this.comments = const [],
    this.views = 0,
    this.shares = 0,
    this.type = 'post',
    this.visibility = 'public',
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Post(
      id: doc.id,
      authorId: d['author_id'] ?? '',
      username: d['username'] ?? '',
      authorAvatar: d['author_avatar'] ?? '',
      text: d['text'] ?? '',
      mediaUrl: d['media_url'],
      thumbnailUrl: d['thumbnail_url'],
      duration: (d['duration'] ?? 0).toDouble(),
      likes: List<String>.from(d['likes'] ?? []),
      comments: (d['comments'] as List? ?? [])
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList(),
      views: d['views'] ?? 0,
      shares: d['shares'] ?? 0,
      type: d['type'] ?? 'post',
      visibility: d['visibility'] ?? 'public',
    );
  }

  /// Legacy JSON factory.
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? json['id'] ?? '',
      authorId: json['author_id'] ?? '',
      username: json['username'] ?? '',
      authorAvatar: json['author_avatar'] ?? '',
      text: json['text'] ?? '',
      mediaUrl: json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      duration: (json['duration'] ?? 0).toDouble(),
      likes: List<String>.from(json['likes'] ?? []),
      comments: (json['comments'] as List? ?? [])
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList(),
      views: json['views'] ?? 0,
      shares: json['shares'] ?? 0,
      type: json['type'] ?? 'post',
      visibility: json['visibility'] ?? 'public',
    );
  }
}

// ─────────────────────────────────────────────
//  COMMENT MODEL
// ─────────────────────────────────────────────

class Comment {
  final String user;
  final String text;
  final String? uid;

  Comment({required this.user, required this.text, this.uid});

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        user: json['user'] ?? '',
        text: json['text'] ?? '',
        uid: json['uid'],
      );
}

// ─────────────────────────────────────────────
//  NOTIFICATION MODEL
// ─────────────────────────────────────────────

class NotificationItem {
  final String id;
  final String fromUser;
  final String fromUid;
  final String type;
  final String text;
  final String? postId;
  final bool read;

  NotificationItem({
    this.id = '',
    required this.fromUser,
    this.fromUid = '',
    required this.type,
    required this.text,
    this.postId,
    this.read = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationItem(
      id: doc.id,
      fromUser: d['from_username'] ?? d['from'] ?? '',
      fromUid: d['from_uid'] ?? '',
      type: d['type'] ?? '',
      text: d['text'] ?? '',
      postId: d['post_id'],
      read: d['read'] ?? false,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        fromUser: json['from'] ?? json['from_username'] ?? '',
        fromUid: json['from_uid'] ?? '',
        type: json['type'] ?? '',
        text: json['text'] ?? '',
        postId: json['post_id'],
      );
}

// ─────────────────────────────────────────────
//  JOB MODEL (Phase 2 — Formal Mode)
// ─────────────────────────────────────────────

class Job {
  final String id;
  final String authorId;
  final String authorUsername;
  final String title;
  final String company;
  final String description;
  final String location;
  final String type; // full-time | part-time | contract | internship
  final List<String> skills;
  final List<String> applicants;
  final bool active;

  Job({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.title,
    this.company = '',
    this.description = '',
    this.location = '',
    this.type = 'full-time',
    this.skills = const [],
    this.applicants = const [],
    this.active = true,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Job(
      id: doc.id,
      authorId: d['author_id'] ?? '',
      authorUsername: d['author_username'] ?? '',
      title: d['title'] ?? '',
      company: d['company'] ?? '',
      description: d['description'] ?? '',
      location: d['location'] ?? '',
      type: d['type'] ?? 'full-time',
      skills: List<String>.from(d['skills'] ?? []),
      applicants: List<String>.from(d['applicants'] ?? []),
      active: d['active'] ?? true,
    );
  }
}

// ─────────────────────────────────────────────
//  CONNECTION MODEL (Phase 6)
// ─────────────────────────────────────────────

class Connection {
  final String id;
  final String from;
  final String to;
  final String status; // pending | accepted | declined | blocked
  final String mode;
  final String message;

  Connection({
    required this.id,
    required this.from,
    required this.to,
    required this.status,
    this.mode = 'formal',
    this.message = '',
  });

  factory Connection.fromMap(Map<String, dynamic> map) => Connection(
        id: map['id'] ?? '',
        from: map['from'] ?? '',
        to: map['to'] ?? '',
        status: map['status'] ?? 'pending',
        mode: map['mode'] ?? 'formal',
        message: map['message'] ?? '',
      );
}
