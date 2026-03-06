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

  // Campus / Academic fields
  final String department;
  final String year; // e.g. '1st', '2nd', '3rd', '4th', 'Masters', 'PhD'
  final List<String> interests;
  final List<String> sportsPreferences;
  final String rollNumber;
  final String college;

  // Phase 3: Location
  final double? locationLat;
  final double? locationLng;
  final double? distanceKm;

  // Phase 5: Push
  final String? fcmToken;

  // Privacy / Discovery
  final String visibility;
  final bool discoverable;
  final String locationSharing; // 'connections' | 'off'

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
    this.department = '',
    this.year = '',
    this.interests = const [],
    this.sportsPreferences = const [],
    this.rollNumber = '',
    this.college = '',
    this.locationLat,
    this.locationLng,
    this.distanceKm,
    this.fcmToken,
    this.visibility = 'public',
    this.discoverable = true,
    this.locationSharing = 'connections',
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
      department: d['department'] ?? '',
      year: d['year'] ?? '',
      interests: List<String>.from(d['interests'] ?? []),
      sportsPreferences: List<String>.from(d['sports_preferences'] ?? []),
      rollNumber: d['roll_number'] ?? '',
      college: d['college'] ?? '',
      locationLat: loc != null ? (loc['lat'] as num?)?.toDouble() : null,
      locationLng: loc != null ? (loc['lng'] as num?)?.toDouble() : null,
      fcmToken: d['fcm_token'],
      visibility: d['visibility'] ?? 'public',
      discoverable: d['discoverable'] ?? true,
      locationSharing: d['location_sharing'] ?? 'connections',
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
    String? department,
    String? year,
    List<String>? interests,
    List<String>? sportsPreferences,
    String? rollNumber,
    String? college,
    double? locationLat,
    double? locationLng,
    double? distanceKm,
    String? fcmToken,
    String? visibility,
    bool? discoverable,
    String? locationSharing,
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
      department: department ?? this.department,
      year: year ?? this.year,
      interests: interests ?? this.interests,
      sportsPreferences: sportsPreferences ?? this.sportsPreferences,
      rollNumber: rollNumber ?? this.rollNumber,
      college: college ?? this.college,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      distanceKm: distanceKm ?? this.distanceKm,
      fcmToken: fcmToken ?? this.fcmToken,
      visibility: visibility ?? this.visibility,
      discoverable: discoverable ?? this.discoverable,
      locationSharing: locationSharing ?? this.locationSharing,
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

// ─────────────────────────────────────────────
//  PROJECT MODEL (Collaboration)
// ─────────────────────────────────────────────

class Project {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorUsername;
  final List<String> requiredSkills;
  final List<String> memberIds;
  final List<String> applicantIds;
  final String status; // open | in-progress | completed
  final String domain; // e.g. 'AI/ML', 'Web', 'Mobile', 'IoT'
  final int maxMembers;
  final DateTime? deadline;

  Project({
    required this.id,
    required this.title,
    this.description = '',
    required this.creatorId,
    required this.creatorUsername,
    this.requiredSkills = const [],
    this.memberIds = const [],
    this.applicantIds = const [],
    this.status = 'open',
    this.domain = '',
    this.maxMembers = 5,
    this.deadline,
  });

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Project(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      creatorId: d['creator_id'] ?? '',
      creatorUsername: d['creator_username'] ?? '',
      requiredSkills: List<String>.from(d['required_skills'] ?? []),
      memberIds: List<String>.from(d['member_ids'] ?? []),
      applicantIds: List<String>.from(d['applicant_ids'] ?? []),
      status: d['status'] ?? 'open',
      domain: d['domain'] ?? '',
      maxMembers: d['max_members'] ?? 5,
      deadline: d['deadline'] != null
          ? (d['deadline'] as Timestamp).toDate()
          : null,
    );
  }
}

// ─────────────────────────────────────────────
//  STUDY GROUP MODEL
// ─────────────────────────────────────────────

class StudyGroup {
  final String id;
  final String name;
  final String subject;
  final String description;
  final String creatorId;
  final String creatorUsername;
  final List<String> memberIds;
  final int maxMembers;
  final String schedule; // e.g. 'Mon/Wed/Fri 5pm'
  final String location; // e.g. 'Library Room 204'

  StudyGroup({
    required this.id,
    required this.name,
    this.subject = '',
    this.description = '',
    required this.creatorId,
    required this.creatorUsername,
    this.memberIds = const [],
    this.maxMembers = 10,
    this.schedule = '',
    this.location = '',
  });

  factory StudyGroup.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return StudyGroup(
      id: doc.id,
      name: d['name'] ?? '',
      subject: d['subject'] ?? '',
      description: d['description'] ?? '',
      creatorId: d['creator_id'] ?? '',
      creatorUsername: d['creator_username'] ?? '',
      memberIds: List<String>.from(d['member_ids'] ?? []),
      maxMembers: d['max_members'] ?? 10,
      schedule: d['schedule'] ?? '',
      location: d['location'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────
//  SKILL EXCHANGE MODEL
// ─────────────────────────────────────────────

class SkillExchange {
  final String id;
  final String userId;
  final String username;
  final List<String> skillsOffered;
  final List<String> skillsWanted;
  final String description;
  final String status; // active | matched | closed

  SkillExchange({
    required this.id,
    required this.userId,
    required this.username,
    this.skillsOffered = const [],
    this.skillsWanted = const [],
    this.description = '',
    this.status = 'active',
  });

  factory SkillExchange.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SkillExchange(
      id: doc.id,
      userId: d['user_id'] ?? '',
      username: d['username'] ?? '',
      skillsOffered: List<String>.from(d['skills_offered'] ?? []),
      skillsWanted: List<String>.from(d['skills_wanted'] ?? []),
      description: d['description'] ?? '',
      status: d['status'] ?? 'active',
    );
  }
}

// ─────────────────────────────────────────────
//  COMMUNITY MODEL
// ─────────────────────────────────────────────

class Community {
  final String id;
  final String name;
  final String description;
  final String type; // department | interest | club
  final String creatorId;
  final List<String> memberIds;
  final List<String> moderatorIds;
  final String? bannerUrl;
  final String? iconUrl;
  final List<String> tags;

  Community({
    required this.id,
    required this.name,
    this.description = '',
    this.type = 'interest',
    required this.creatorId,
    this.memberIds = const [],
    this.moderatorIds = const [],
    this.bannerUrl,
    this.iconUrl,
    this.tags = const [],
  });

  factory Community.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Community(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      type: d['type'] ?? 'interest',
      creatorId: d['creator_id'] ?? '',
      memberIds: List<String>.from(d['member_ids'] ?? []),
      moderatorIds: List<String>.from(d['moderator_ids'] ?? []),
      bannerUrl: d['banner_url'],
      iconUrl: d['icon_url'],
      tags: List<String>.from(d['tags'] ?? []),
    );
  }
}

// ─────────────────────────────────────────────
//  COMMUNITY POST / DISCUSSION MODEL
// ─────────────────────────────────────────────

class CommunityPost {
  final String id;
  final String communityId;
  final String authorId;
  final String authorUsername;
  final String title;
  final String content;
  final String? mediaUrl;
  final List<String> upvotes;
  final List<String> downvotes;
  final List<Comment> comments;
  final bool isPinned;
  final String type; // discussion | resource | poll | announcement

  CommunityPost({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.authorUsername,
    this.title = '',
    this.content = '',
    this.mediaUrl,
    this.upvotes = const [],
    this.downvotes = const [],
    this.comments = const [],
    this.isPinned = false,
    this.type = 'discussion',
  });

  int get score => upvotes.length - downvotes.length;

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityPost(
      id: doc.id,
      communityId: d['community_id'] ?? '',
      authorId: d['author_id'] ?? '',
      authorUsername: d['author_username'] ?? '',
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      mediaUrl: d['media_url'],
      upvotes: List<String>.from(d['upvotes'] ?? []),
      downvotes: List<String>.from(d['downvotes'] ?? []),
      comments: (d['comments'] as List? ?? [])
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList(),
      isPinned: d['is_pinned'] ?? false,
      type: d['type'] ?? 'discussion',
    );
  }
}

// ─────────────────────────────────────────────
//  EVENT MODEL (Campus)
// ─────────────────────────────────────────────

class CampusEvent {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerUsername;
  final String type; // workshop | hackathon | seminar | sports | cultural | other
  final String location;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<String> registeredUserIds;
  final int maxCapacity;
  final String? bannerUrl;
  final List<String> tags;
  final String status; // upcoming | ongoing | completed | cancelled

  CampusEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.organizerId,
    required this.organizerUsername,
    this.type = 'other',
    this.location = '',
    this.startTime,
    this.endTime,
    this.registeredUserIds = const [],
    this.maxCapacity = 100,
    this.bannerUrl,
    this.tags = const [],
    this.status = 'upcoming',
  });

  factory CampusEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CampusEvent(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      organizerId: d['organizer_id'] ?? '',
      organizerUsername: d['organizer_username'] ?? '',
      type: d['type'] ?? 'other',
      location: d['location'] ?? '',
      startTime: d['start_time'] != null
          ? (d['start_time'] as Timestamp).toDate()
          : null,
      endTime: d['end_time'] != null
          ? (d['end_time'] as Timestamp).toDate()
          : null,
      registeredUserIds: List<String>.from(d['registered_user_ids'] ?? []),
      maxCapacity: d['max_capacity'] ?? 100,
      bannerUrl: d['banner_url'],
      tags: List<String>.from(d['tags'] ?? []),
      status: d['status'] ?? 'upcoming',
    );
  }
}

// ─────────────────────────────────────────────
//  VENUE / SPORTS BOOKING MODEL
// ─────────────────────────────────────────────

class Venue {
  final String id;
  final String name;
  final String type; // basketball | football | tennis | badminton | cricket | gym | pool
  final String location;
  final String description;
  final double? lat;
  final double? lng;
  final List<String> amenities;
  final String? imageUrl;

  Venue({
    required this.id,
    required this.name,
    this.type = '',
    this.location = '',
    this.description = '',
    this.lat,
    this.lng,
    this.amenities = const [],
    this.imageUrl,
  });

  factory Venue.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Venue(
      id: doc.id,
      name: d['name'] ?? '',
      type: d['type'] ?? '',
      location: d['location'] ?? '',
      description: d['description'] ?? '',
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      amenities: List<String>.from(d['amenities'] ?? []),
      imageUrl: d['image_url'],
    );
  }
}

class VenueBooking {
  final String id;
  final String venueId;
  final String venueName;
  final String bookerId;
  final String bookerUsername;
  final DateTime? date;
  final String timeSlot; // e.g. '10:00-11:00'
  final List<String> playerIds;
  final int maxPlayers;
  final String sport;
  final String status; // confirmed | pending | cancelled

  VenueBooking({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.bookerId,
    required this.bookerUsername,
    this.date,
    this.timeSlot = '',
    this.playerIds = const [],
    this.maxPlayers = 10,
    this.sport = '',
    this.status = 'pending',
  });

  factory VenueBooking.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return VenueBooking(
      id: doc.id,
      venueId: d['venue_id'] ?? '',
      venueName: d['venue_name'] ?? '',
      bookerId: d['booker_id'] ?? '',
      bookerUsername: d['booker_username'] ?? '',
      date: d['date'] != null ? (d['date'] as Timestamp).toDate() : null,
      timeSlot: d['time_slot'] ?? '',
      playerIds: List<String>.from(d['player_ids'] ?? []),
      maxPlayers: d['max_players'] ?? 10,
      sport: d['sport'] ?? '',
      status: d['status'] ?? 'pending',
    );
  }
}

// ─────────────────────────────────────────────
//  CAMPUS LOCATION (Interactive Map)
// ─────────────────────────────────────────────

class CampusLocation {
  final String id;
  final String name;
  final String category; // building | lab | library | cafeteria | sports | parking | hostel
  final String description;
  final double lat;
  final double lng;
  final String? imageUrl;
  final String floor;
  final String openHours;

  CampusLocation({
    required this.id,
    required this.name,
    this.category = 'building',
    this.description = '',
    required this.lat,
    required this.lng,
    this.imageUrl,
    this.floor = '',
    this.openHours = '',
  });

  factory CampusLocation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CampusLocation(
      id: doc.id,
      name: d['name'] ?? '',
      category: d['category'] ?? 'building',
      description: d['description'] ?? '',
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      imageUrl: d['image_url'],
      floor: d['floor'] ?? '',
      openHours: d['open_hours'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────
//  USER MARKER (Custom Map Pins)
// ─────────────────────────────────────────────

class UserMarker {
  final String id;
  final String createdBy;
  final String title;
  final String description;
  final String category;
  final double lat;
  final double lng;
  final DateTime? createdAt;

  UserMarker({
    required this.id,
    required this.createdBy,
    required this.title,
    this.description = '',
    this.category = 'custom',
    required this.lat,
    required this.lng,
    this.createdAt,
  });

  factory UserMarker.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return UserMarker(
      id: doc.id,
      createdBy: d['createdBy'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? 'custom',
      lat: (d['lat'] as num?)?.toDouble() ?? 0,
      lng: (d['lng'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ─────────────────────────────────────────────
//  RESOURCE SHARING MODEL
// ─────────────────────────────────────────────

class SharedResource {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final String authorUsername;
  final String type; // notes | pdf | link | video | presentation
  final String? fileUrl;
  final String? linkUrl;
  final String subject;
  final List<String> tags;
  final List<String> likes;
  final int downloads;

  SharedResource({
    required this.id,
    required this.title,
    this.description = '',
    required this.authorId,
    required this.authorUsername,
    this.type = 'notes',
    this.fileUrl,
    this.linkUrl,
    this.subject = '',
    this.tags = const [],
    this.likes = const [],
    this.downloads = 0,
  });

  factory SharedResource.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SharedResource(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      authorId: d['author_id'] ?? '',
      authorUsername: d['author_username'] ?? '',
      type: d['type'] ?? 'notes',
      fileUrl: d['file_url'],
      linkUrl: d['link_url'],
      subject: d['subject'] ?? '',
      tags: List<String>.from(d['tags'] ?? []),
      likes: List<String>.from(d['likes'] ?? []),
      downloads: d['downloads'] ?? 0,
    );
  }
}
