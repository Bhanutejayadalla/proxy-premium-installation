# PROXI 2.0 — EVOLUTION PLAN (FIREBASE VERSION)
## Upgrading Proxi Social Connectivity With Firebase While Preserving Its Unique DNA

---

## TABLE OF CONTENTS

1. [Current System Audit](#1-current-system-audit)
2. [Design Principles](#2-design-principles)
3. [Architecture Evolution](#3-architecture-evolution)
4. [Phase 1 — Firebase Migration](#4-phase-1--firebase-migration)
5. [Phase 2 — Enhanced User Profiles & Professional Layer](#5-phase-2--enhanced-user-profiles--professional-layer)
6. [Phase 3 — GPS-Based Discovery (Alongside BLE)](#6-phase-3--gps-based-discovery-alongside-ble)
7. [Phase 4 — Video Reels & Rich Media](#7-phase-4--video-reels--rich-media)
8. [Phase 5 — Push Notifications & Real-Time Upgrades](#8-phase-5--push-notifications--real-time-upgrades)
9. [Phase 6 — Privacy Controls & Connection Request System](#9-phase-6--privacy-controls--connection-request-system)
10. [Phase 7 — Feed Algorithm & Story Expiry](#10-phase-7--feed-algorithm--story-expiry)
11. [Phase 8 — Polish, Testing & Deployment](#11-phase-8--polish-testing--deployment)
12. [Database Schema Evolution](#12-database-schema-evolution)
13. [Firebase SDK Operations (Replaces REST API)](#13-firebase-sdk-operations-replaces-rest-api)
14. [New Flutter Files To Create](#14-new-flutter-files-to-create)
15. [Files To Modify](#15-files-to-modify)
16. [Dependency Changes](#16-dependency-changes)
17. [Risk Register](#17-risk-register)
18. [MVP Milestone Checklist](#18-mvp-milestone-checklist)
19. [Cost Estimation](#19-cost-estimation)
20. [Timeline](#20-timeline)

---

## 1. CURRENT SYSTEM AUDIT

### What We Have (KEEP ALL OF THIS)

```
UNIQUE FEATURES — DO NOT TOUCH
├── Formal/Casual dual-mode toggle (AppColors, HomeShell FAB, app_state.isFormal)
├── Mode-specific UI themes (blue professional ↔ pink/gradient casual)
├── Dual avatar system (avatar_formal + avatar_casual per user)
├── Mode-tagged content (posts/stories filtered by "formal"/"casual")
├── BLE proximity scanning (ble_service.dart + flutter_blue_plus)
├── Animated radar ripple discovery UI (nearby_screen.dart)
├── Story view with tap-to-pause + reply-to-DM flow (story_view_screen.dart)
└── Mode-aware ModeSwitch widget (widgets/mode_switch.dart)
```

### Current File Inventory

```
BACKEND (Firebase - No backend/ folder needed)
├── Firestore Database   → Cloud-hosted NoSQL database
├── Firebase Auth        → Managed authentication service
├── Firebase Storage     → Cloud file storage with CDN
├── firestore.rules      → Security rules (replaces API auth middleware)
└── storage.rules        → File access permissions

FLUTTER APP (mobile_app/lib/)
├── main.dart            → 33 lines  — App entry, Provider setup, MaterialApp
├── app_state.dart       → 88 lines  — Global state: auth, feed, mode toggle, BLE scan
├── api_service.dart     → 106 lines — REST client with 10 methods
├── ble_service.dart     → 27 lines  — BLE init + scan
├── constants.dart       → 13 lines  — AppColors (formal/casual)
├── models.dart          → 86 lines  — User, Post, Comment, NotificationItem
├── screens/
│   ├── auth_screen.dart          → 40 lines  — Username/password login
│   ├── home_shell.dart           → 93 lines  — 5-tab nav + mode FAB
│   ├── feed_screen.dart          → 88 lines  — Stories row + posts list
│   ├── nearby_screen.dart        → 95 lines  — BLE radar + user list
│   ├── create_post_screen.dart   → 73 lines  — Post/story creator
│   ├── chat_list_screen.dart     → 35 lines  — Conversations list
│   ├── chat_detail_screen.dart   → 130 lines — WebSocket chat + media
│   ├── profile_screen.dart       → 117 lines — Avatar, bio, posts grid
│   ├── story_view_screen.dart    → 141 lines — Full-screen story + reply
│   └── notifications_screen.dart → 52 lines  — Notification list
└── widgets/
    ├── post_card.dart    → 127 lines — Post with like/comment actions
    ├── mode_switch.dart  → 40 lines  — Animated formal/casual toggle
    └── story_circle.dart → 33 lines  — Circular story avatar

TOTAL: ~1,523 lines of Dart + 234 lines of Python = ~1,757 lines
```

### Current Firestore Collections

```
Firestore Database
├── users           → { username, password_hash, avatar_formal, avatar_casual, bio, ble_uuid, followers[], following[] }
├── posts           → { username, text, mode, type, media_url, timestamp, likes[], comments[], author_avatar }
├── stories         → { same schema as posts }
├── chats/{chatId}/messages → { sender, receiver, text, file_url, file_type, timestamp }
└── notifications   → { to, from, type, post_id, text, timestamp }

Note: Firestore uses subcollections for chat messages to optimize queries.
```

### What's Broken / Weak (FIX THESE)

| Issue | Severity | Current Implementation |
|-------|----------|------------------------|
| Passwords stored in plain text | 🔴 CRITICAL | No hashing (will use Firebase Auth) |
| No input validation on any endpoint | 🔴 CRITICAL | Direct database writes (will use Firestore Security Rules) |
| No auth tokens / session management | 🟡 HIGH | Basic username check (will use Firebase Auth tokens) |
| No rate limiting | 🟡 HIGH | None (Firestore has built-in quotas) |
| No file type/size validation on upload | 🟡 HIGH | No checks (will use Storage Rules) |
| Stories never expire | 🟢 MEDIUM | No TTL (will use Cloud Functions or client-side filter) |
| No pagination on feed/notifications | 🟢 MEDIUM | Loads all (will use Firestore pagination) |
| Chat list uses nearbyUsers (not real conversations) | 🟢 MEDIUM | chat_list_screen.dart line 15 |
| No error handling on login failure | 🟢 MEDIUM | auth_screen.dart line 33 |
| Bio update dialog does nothing | 🟢 MEDIUM | profile_screen.dart line 41 |

---

## 2. DESIGN PRINCIPLES

### Non-Negotiable Rules

```
1. PRESERVE DUAL-MODE    → Every new feature works in BOTH formal and casual mode
2. PRESERVE BLE           → BLE discovery stays; GPS is ADDITIVE, not a replacement
3. INCREMENTAL UPGRADES   → Each phase produces a working app; no big-bang rewrites
4. BACKWARD COMPATIBLE    → Old data survives; new fields use defaults
5. SAME TECH STACK        → Stay on FastAPI + MongoDB + Flutter; add Firebase ONLY for specific services
```

### New Feature Integration Rule

Every new feature must answer: **"How does this behave in Formal mode vs Casual mode?"**

| New Feature | Formal Mode Behavior | Casual Mode Behavior |
|-------------|---------------------|---------------------|
| Professional Profile | Full resume visible | Hidden or collapsed |
| Job Posts | Shown in feed | Hidden from feed |
| Video Reels | Professional short talks | Fun/creative reels |
| GPS Discovery | "Nearby professionals" | "People around me" |
| Connection Request | "Connect professionally" | "Let's hang out" |
| Push Notifications | Formal bell icon, muted tone | Fun emoji icon, pop sound |

---

## 3. ARCHITECTURE EVOLUTION

### Current Architecture (To Be Migrated)
```
┌─────────────────┐       HTTP/WS        ┌──────────────┐      ┌──────────┐
│  Flutter App     │ ◄──────────────────► │  FastAPI      │ ◄──► │ Firestore│
│  (Provider)      │     Port 8000        │  (Uvicorn)    │      │ (Cloud)  │
│                  │                      │               │      │          │
│  ble_service ────┤─── BLE scan ───────► │  (No BLE)     │      │ Firebase │
└─────────────────┘                      └──────────────┘      └──────────┘
                                               │
                                    Firebase Storage (cloud)
```

### Target Architecture (After All Phases - Firebase Version)
```
┌──────────────────────┐                          ┌───────────────────────┐
│  Flutter App          │  Firebase SDKs Direct   │  Firebase Services    │
│  (Provider)           │ ◄─────────────────────► │  (Fully Managed)      │
│                       │                         │                       │
│  ble_service ─────────┤── BLE (local) ──┐       │  • Firestore (DB)     │
│  firebase_service ────┤── Firestore      │       │  • Auth (JWT auto)    │
│  location_service ────┤── GeoFlutterFire │       │  • Storage (CDN)      │
│  auth_service ────────┤── Firebase Auth  ├─────► │  • FCM (Push)         │
│  video_player ────────┤── Storage upload │       │  • Cloud Functions    │
│                       │                  │       │    (Optional)         │
│  Real-time streams:   │                  │       │                       │
│  • feed.snapshots()   │◄─────────────────┘       └───────────────────────┘
│  • chats.snapshots()  │   WebSocket-like                  │
│  • nearby.stream()    │   (built-in)                      │
└──────────────────────┘                          Push Notifications
                                                   (FCM to device)

NO BACKEND SERVER NEEDED
(except optional Cloud Functions for:
 - Story expiration cleanup
 - Push notification triggers
 - Complex aggregations)
```

### Firebase Services Used (Full Stack Approach)

| Service | Why Firebase? | What It Replaces |
|---------|--------------|------------------|
| **Cloud Firestore** | Real-time NoSQL database with offline support, automatic scaling | MongoDB (entire database) |
| **Firebase Authentication** | Built-in auth with email, Google, Apple sign-in; JWT handled automatically | Custom JWT + bcrypt implementation |
| **Firebase Storage** | CDN-backed file storage with automatic image optimization | Local uploads/ folder OR S3 |
| **Cloud Messaging (FCM)** | Push notifications to closed apps | No alternative for mobile push |
| **Cloud Functions (Optional)** | Serverless triggers for background tasks (story expiry, notifications) | FastAPI background tasks |

**FastAPI becomes optional:** Only needed for complex operations Firestore can't handle efficiently (advanced geoqueries, video transcoding). Most apps can go 100% Flutter + Firebase.

---

## 4. PHASE 1 — FIREBASE MIGRATION

**Goal:** Migrate from MongoDB + FastAPI to Firebase (Firestore + Auth + Storage). Complete backend replacement.
**Duration:** 2 weeks
**Risk:** MEDIUM (major migration, but Firebase simplifies architecture and security)

### Firebase Project Setup

#### 1A. Create Firebase Project

```bash
# 1. Go to https://console.firebase.google.com
# 2. Click "Add project" → Name: "Proxi Social"
# 3. Disable Google Analytics (optional for now)
# 4. Wait for project creation (~30 seconds)

# 5. Enable Firestore Database:
#    - Build → Firestore Database → Create database
#    - Start in PRODUCTION mode (we'll add security rules)
#    - Choose region closest to users (e.g., us-central)

# 6. Enable Authentication:
#    - Build → Authentication → Get started
#    - Sign-in method → Enable "Email/Password"
#    - (Optional) Enable Google, Apple for Phase 2+

# 7. Enable Storage:
#    - Build → Storage → Get started
#    - Start in PRODUCTION mode

# 8. Enable Cloud Messaging:
#    - Already enabled by default

# 9. Add Flutter app:
#    - Project Overview → Add app → Flutter (FlutterFire CLI)
#    - Follow setup instructions
```

#### 1B. Firebase Authentication (Flutter Side)

```dart
// NEW: Add to pubspec.yaml
// firebase_core: ^2.24.0
// firebase_auth: ^4.15.0
// cloud_firestore: ^4.13.0

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Register
  Future<User?> register(String email, String password, String username) async {
    try {
      // Check if username is taken
      final usernameCheck = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (usernameCheck.docs.isNotEmpty) {
        throw Exception('Username already taken');
      }
      
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create Firestore user document
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'username': username,
        'email': email,
        'avatar_formal': 'https://ui-avatars.com/api/?name=$username&background=0D8ABC&color=fff&size=128',
        'avatar_casual': 'https://api.dicebear.com/7.x/pixel-art/png?seed=$username',
        'bio': 'New to Proxi',
        'ble_uuid': _generateUuid(),
        'followers': [],
        'following': [],
        'created_at': FieldValue.serverTimestamp(),
      });
      
      return credential.user;
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }
  
  // Login
  Future<User?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }
  
  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
  
  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  String _generateUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
```

#### 1C. Firestore Security Rules (Replaces API Middleware)

```javascript
// firestore.rules — Deploy via Firebase Console or CLI
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Anyone can read public profiles
      allow read: if isSignedIn();
      // Only owner can write their own profile
      allow write: if isOwner(userId);
    }
    
    // Posts collection
    match /posts/{postId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;
      allow update, delete: if isSignedIn() && resource.data.uid == request.auth.uid;
    }
    
    // Stories collection
    match /stories/{storyId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;
      allow delete: if isOwner(resource.data.uid);
    }
    
    // Chat messages (subcollection)
    match /chats/{chatId}/messages/{messageId} {
      // Only participants can read/write
      allow read, write: if isSignedIn() && 
        (request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants);
    }
    
    // Notifications
    match /notifications/{notifId} {
      // Only recipient can read their notifications
      allow read: if isSignedIn() && resource.data.to_uid == request.auth.uid;
      allow create: if isSignedIn();
    }
  }
}
```

#### 1D. Firebase Storage Rules (File Upload Validation)

```javascript
// storage.rules — Deploy via Firebase Console or CLI
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isValidImage() {
      return request.resource.contentType.matches('image/.*') &&
             request.resource.size < 10 * 1024 * 1024;  // 10 MB
    }
    
    function isValidVideo() {
      return request.resource.contentType.matches('video/.*') &&
             request.resource.size < 100 * 1024 * 1024;  // 100 MB
    }
    
    // User uploads
    match /uploads/{userId}/{filename} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && 
                      request.auth.uid == userId &&
                      (isValidImage() || isValidVideo());
    }
    
    // Chat attachments
    match /chat_files/{userId}/{filename} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && 
                      request.auth.uid == userId &&
                      (isValidImage() || isValidVideo());
    }
    
    // Resumes (PDF only)
    match /resumes/{userId}/{filename} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && 
                      request.auth.uid == userId &&
                      request.resource.contentType == 'application/pdf' &&
                      request.resource.size < 5 * 1024 * 1024;  // 5 MB
    }
  }
}
```

**Note:** Firebase has built-in rate limiting via quotas. For additional rate limiting, use Firebase App Check.

#### 1E. Firebase Security Best Practices

```dart
// main.dart — Initialize Firebase with proper security
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // Auto-generated by FlutterFire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable offline persistence (critical for mobile)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  runApp(const MyApp());
}
```

**Security:** Firebase automatically handles CORS, SSL, and DDoS protection. No additional configuration needed.

### Flutter Changes

#### 1F. Firebase Service Layer (firebase_service.dart)

```dart
// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Get user by UID
  Future<DocumentSnapshot> getUser(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }
  
  // Get user by username
  Future<QuerySnapshot> getUserByUsername(String username) async {
    return await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
  }
  
  // Update user profile
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }
  
  // Get feed (posts for a specific mode)
  Stream<QuerySnapshot> getFeedStream(String mode) {
    return _firestore
        .collection('posts')
        .where('mode', isEqualTo: mode)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }
  
  // Create post
  Future<void> createPost(Map<String, dynamic> postData) async {
    await _firestore.collection('posts').add(postData);
  }
  
  // Upload file to Firebase Storage
  Future<String> uploadFile(File file, String path) async {
    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }
  
  // Get chat messages stream
  Stream<QuerySnapshot> getChatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }
  
  // Send message
  Future<void> sendMessage(String chatId, Map<String, dynamic> messageData) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);
  }
}
```

#### 1G. Auth Screen Error Handling (auth_screen.dart)

```dart
// Add registration mode toggle
// Add loading indicator
// Add error messages for wrong password / username taken
// Add "Forgot Password" placeholder
```

### New Files (Phase 1)

| File | Purpose |
|------|---------|
| `lib/services/auth_service.dart` | Firebase Authentication wrapper |
| `lib/services/firebase_service.dart` | Firestore database operations |
| `firebase_options.dart` | Auto-generated Firebase config (from FlutterFire CLI) |
| `firestore.rules` | Firestore security rules (deploy separately) |
| `storage.rules` | Firebase Storage security rules (deploy separately) |

### New Dependencies (Phase 1)

| Package | Platform | Purpose |
|---------|----------|---------|
| `firebase_core: ^2.24.0` | Flutter | Firebase initialization |
| `firebase_auth: ^4.15.0` | Flutter | Authentication (replaces JWT) |
| `cloud_firestore: ^4.13.0` | Flutter | Database (replaces MongoDB) |
| `firebase_storage: ^11.5.0` | Flutter | File storage (replaces local uploads) |
| `shared_preferences: ^2.2.0` | Flutter | Cache non-sensitive settings |

### Migration Script (One-Time)

```python
# scripts/migrate_to_firebase.py
# Run ONCE to migrate MongoDB data to Firestore
import firebase_admin
from firebase_admin import credentials, firestore
from pymongo import MongoClient

# Initialize Firebase Admin
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)

db_firebase = firestore.client()
db_mongo = MongoClient('mongodb://localhost:27017/')['proxi_social_db']

# Migrate users
print('Migrating users...')
for user in db_mongo.users.find():
    user_id = str(user['_id'])
    user.pop('_id')
    user.pop('password', None)  # Don't migrate passwords (use Firebase Auth)
    db_firebase.collection('users').document(user_id).set(user)
    print(f"Migrated user: {user['username']}")

# Migrate posts
print('Migrating posts...')
for post in db_mongo.posts.find():
    post_id = str(post['_id'])
    post.pop('_id')
    db_firebase.collection('posts').document(post_id).set(post)

# Migrate stories
print('Migrating stories...')
for story in db_mongo.stories.find():
    story_id = str(story['_id'])
    story.pop('_id')
    db_firebase.collection('stories').document(story_id).set(story)

# Migrate notifications
print('Migrating notifications...')
for notif in db_mongo.notifications.find():
    notif_id = str(notif['_id'])
    notif.pop('_id')
    db_firebase.collection('notifications').document(notif_id).set(notif)

print('Migration complete. TEST THOROUGHLY before removing MongoDB.')
print('Users must re-register (passwords not migrated for security).')
```

---

## 5. PHASE 2 — ENHANCED USER PROFILES & PROFESSIONAL LAYER

**Goal:** Add LinkedIn-style professional data to the existing dual-mode system.
**Duration:** 2 weeks
**Risk:** LOW (additive fields; existing features untouched)

### Design Decision: Professional Data in Dual Mode

```
FORMAL MODE sees:
├── Full name, headline, company
├── Skills with endorsements
├── Experience timeline
├── Education
├── Certifications
├── "Open to Work" badge
├── "Connect Professionally" button
└── Job posts in the feed

CASUAL MODE sees:
├── Display name, fun bio
├── Interests (same data as skills, different label)
├── "What I'm into" (same as headline, casual wording)
├── Hidden: resume, certifications, experience
└── "Say Hi" button instead of "Connect Professionally"
```

### New Firestore Fields on `users` Collection

```javascript
// ADD these fields to existing user documents (Firestore)
{
  // --- EXISTING (unchanged) ---
  "username": "john_doe",
  // password stored in Firebase Auth, NOT in Firestore
  "avatar_formal": "https://storage.googleapis.com/...",  // Firebase Storage URL
  "avatar_casual": "https://storage.googleapis.com/...",  // Firebase Storage URL
  "bio": "Full-stack developer by day, gamer by night",
  "ble_uuid": "...",
  "followers": [],
  "following": [],

  // --- NEW: Professional Profile ---
  "full_name": "John Doe",
  "headline": "Senior Flutter Developer at TechCorp",    // Formal: shown as-is. Casual: "What I'm into"
  "skills": ["Flutter", "Python", "Firebase", "UI/UX"],  // Formal: "Skills". Casual: "Interests"
  "experience": [
    {
      "title": "Senior Developer",
      "company": "TechCorp",
      "start_date": "2023-01",
      "end_date": null,            // null = present
      "description": "Leading mobile team"
    }
  ],
  "education": [
    {
      "institution": "MIT",
      "degree": "B.S. Computer Science",
      "year": "2022"
    }
  ],
  "certifications": [
    {
      "name": "Google Associate Android Developer",
      "issuer": "Google",
      "year": "2023",
      "url": "https://credential.example.com/abc123"
    }
  ],
  "portfolio_links": [
    { "title": "My GitHub", "url": "https://github.com/johndoe" }
  ],
  "resume_url": null,              // Firebase Storage URL to uploaded PDF
  "open_to_work": false,
  "hiring": false,                 // "I'm hiring for my team"

  // --- NEW: Privacy & Visibility ---
  "visibility": "public",          // public | connections | private
  "show_distance": true,
  "discoverable": true,            // Appears in nearby results

  // --- NEW: Timestamps (Firestore Timestamp type) ---
  "created_at": Timestamp,
  "last_active": Timestamp
}
```

### New Firestore Collection: `jobs`

```javascript
// NEW COLLECTION: jobs (auto-generated document IDs)
{
  "posted_by": "john_doe",         // Username
  "posted_by_uid": "abc123...",   // Firebase Auth UID
  "company": "TechCorp",
  "title": "Flutter Developer Intern",
  "description": "Join our mobile team...",
  "skills_required": ["Flutter", "Dart"],
  "location": "Remote",
  "type": "full-time",              // full-time | part-time | internship | freelance
  "salary_range": "$40k-$60k",
  "mode": "formal",                 // Jobs ONLY appear in formal mode
  "applicants": ["user1", "user2"], // Array of usernames
  "timestamp": Timestamp,
  "active": true
}
```

### Firebase Client-Side Operations (Phase 2)

**Note:** With Firebase, most operations are moved from backend endpoints to client-side SDK calls with Security Rules enforcement.

```dart
// lib/services/firebase_service.dart — Profile operations

// Update profile (replaces PUT /user/profile endpoint)
Future<void> updateProfile(String uid, {
  String? fullName,
  String? headline,
  String? bio,
  List<String>? skills,
  bool? openToWork,
  bool? hiring,
  String? visibility,
}) async {
  final updates = <String, dynamic>{};
  
  if (fullName != null) updates['full_name'] = fullName;
  if (headline != null) updates['headline'] = headline;
  if (bio != null) updates['bio'] = bio;
  if (skills != null) updates['skills'] = skills;
  if (openToWork != null) updates['open_to_work'] = openToWork;
  if (hiring != null) updates['hiring'] = hiring;
  if (visibility != null) updates['visibility'] = visibility;
  
  if (updates.isNotEmpty) {
    updates['last_active'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(uid).update(updates);
  }
}

// Update experience (replaces PUT /user/experience)
Future<void> updateExperience(String uid, List<Map<String, dynamic>> experience) async {
  await _firestore.collection('users').doc(uid).update({
    'experience': experience,
    'last_active': FieldValue.serverTimestamp(),
  });
}

// Update education (replaces PUT /user/education)
Future<void> updateEducation(String uid, List<Map<String, dynamic>> education) async {
  await _firestore.collection('users').doc(uid).update({
    'education': education,
    'last_active': FieldValue.serverTimestamp(),
  });
}

// Upload resume to Firebase Storage (replaces POST /user/resume)
Future<String> uploadResume(String uid, File file) async {
  final ext = path.extension(file.path).toLowerCase();
  if (!['.pdf', '.doc', '.docx'].contains(ext)) {
    throw Exception('Only PDF/DOC files allowed');
  }
  
  final ref = _storage.ref().child('resumes/$uid/${DateTime.now().millisecondsSinceEpoch}$ext');
  await ref.putFile(file);
  final url = await ref.getDownloadURL();
  
  // Update user document with resume URL
  await _firestore.collection('users').doc(uid).update({
    'resume_url': url,
    'last_active': FieldValue.serverTimestamp(),
  });
  
  return url;
}

// --- JOB OPERATIONS ---

// Create job (replaces POST /jobs/create)
Future<void> createJob(String uid, String username, {
  required String title,
  required String company,
  required String description,
  List<String> skillsRequired = const [],
  String location = 'Remote',
  String type = 'full-time',
  String salaryRange = '',
}) async {
  await _firestore.collection('jobs').add({
    'posted_by': username,
    'posted_by_uid': uid,
    'company': company,
    'title': title,
    'description': description,
    'skills_required': skillsRequired,
    'location': location,
    'type': type,
    'salary_range': salaryRange,
    'mode': 'formal',
    'applicants': [],
    'timestamp': FieldValue.serverTimestamp(),
    'active': true,
  });
}

// Get jobs feed (replaces GET /jobs)
Stream<QuerySnapshot> getJobsStream({String type = 'all'}) {
  Query query = _firestore
      .collection('jobs')
      .where('active', isEqualTo: true)
      .where('mode', isEqualTo: 'formal')
      .orderBy('timestamp', descending: true)
      .limit(20);
  
  if (type != 'all') {
    query = query.where('type', isEqualTo: type);
  }
  
  return query.snapshots();
}

// Apply to job (replaces POST /jobs/{id}/apply)
Future<void> applyToJob(String jobId, String username) async {
  await _firestore.collection('jobs').doc(jobId).update({
    'applicants': FieldValue.arrayUnion([username]),
  });
}

// Get job applicants (replaces GET /jobs/{id}/applicants)
Future<List<String>> getJobApplicants(String jobId, String currentUid) async {
  final job = await _firestore.collection('jobs').doc(jobId).get();
  
  // Security: Only job poster can see applicants (checked in Security Rules)
  if (job.data()?['posted_by_uid'] != currentUid) {
    throw Exception('Unauthorized');
  }
  
  return List<String>.from(job.data()?['applicants'] ?? []);
}
```

**Security Rules for Jobs:**

```javascript
// Add to firestore.rules
match /jobs/{jobId} {
  // Anyone authenticated can read active jobs
  allow read: if isSignedIn() && resource.data.active == true;
  
  // Only authenticated users can create jobs
  allow create: if isSignedIn() && 
                   request.resource.data.posted_by_uid == request.auth.uid;
  
  // Only job poster can update/delete
  allow update, delete: if isSignedIn() && 
                           resource.data.posted_by_uid == request.auth.uid;
}
```
        "salary_range": salary_range,
        "mode": "formal",
        "applicants": [],
        "timestamp": datetime.now().isoformat(),
        "active": True
    }
    db.jobs.insert_one(job)
    return {"status": "success"}

@app.get("/jobs")
def get_jobs(username: str = Depends(get_current_user)):
    jobs = list(db.jobs.find({"active": True}).sort("timestamp", -1))
    return [fix_id(j) for j in jobs]

@app.post("/jobs/{job_id}/apply")
def apply_job(job_id: str, username: str = Depends(get_current_user)):
    db.jobs.update_one(
        {"_id": ObjectId(job_id)}, 
        {"$addToSet": {"applicants": username}}
    )
    # Notify job poster
    job = db.jobs.find_one({"_id": ObjectId(job_id)})
    if job:
        db.notifications.insert_one({
            "to": job["posted_by"],
            "from": username,
            "type": "job_application",
            "text": f"applied to your {job['title']} position",
            "timestamp": datetime.now().isoformat()
        })
    return {"status": "success"}
```

### New Flutter Files (Phase 2)

| New File | Purpose | Estimated Lines |
|----------|---------|----------------|
| `lib/screens/edit_profile_screen.dart` | Edit full name, headline, bio, skills, open_to_work, visibility | ~200 |
| `lib/screens/experience_screen.dart` | Add/edit work experience entries | ~180 |
| `lib/screens/education_screen.dart` | Add/edit education entries | ~150 |
| `lib/screens/jobs_screen.dart` | Browse job posts (formal mode only) | ~160 |
| `lib/screens/create_job_screen.dart` | Post a new job | ~130 |
| `lib/screens/user_detail_screen.dart` | View another user's full profile | ~200 |
| `lib/widgets/skill_chip.dart` | Reusable skill tag widget | ~30 |
| `lib/widgets/experience_card.dart` | Work experience card | ~50 |
| `lib/widgets/job_card.dart` | Job listing card | ~60 |

### Files To Modify (Phase 2)

| Existing File | Changes |
|---------------|---------|
| `models.dart` | Add professional fields to `User`, add `Job` model, add `Experience`, `Education`, `Certification` models |
| `api_service.dart` | Add `updateProfile()`, `updateExperience()`, `uploadResume()`, `getJobs()`, `createJob()`, `applyToJob()` methods |
| `app_state.dart` | Add `jobs` list, `fetchJobs()`, professional profile update methods |
| `profile_screen.dart` | Show professional info in formal mode, casual info in casual mode; fix bio edit to actually work |
| `home_shell.dart` | Add 6th tab "Jobs" visible ONLY in formal mode (hide in casual) |
| `nearby_screen.dart` | Show "Open to Work" badge, skills preview in result tiles |
| `constants.dart` | Add professional section colors |

### Updated User Model (models.dart)

```dart
class User {
  final String username;
  final String avatarFormal;
  final String avatarCasual;
  final String bio;
  final String bleUuid;
  final List<String> followers;
  final List<String> following;
  
  // NEW — Professional
  final String fullName;
  final String headline;
  final List<String> skills;
  final List<Experience> experience;
  final List<Education> education;
  final List<Certification> certifications;
  final List<PortfolioLink> portfolioLinks;
  final String? resumeUrl;
  final bool openToWork;
  final bool hiring;
  
  // NEW — Privacy
  final String visibility;     // public | connections | private
  final bool discoverable;
  
  User({ ... });  // Constructor with all fields
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // ... existing fields ...
      fullName: json['full_name'] ?? '',
      headline: json['headline'] ?? '',
      skills: List<String>.from(json['skills'] ?? []),
      experience: (json['experience'] as List? ?? [])
          .map((e) => Experience.fromJson(e)).toList(),
      education: (json['education'] as List? ?? [])
          .map((e) => Education.fromJson(e)).toList(),
      certifications: (json['certifications'] as List? ?? [])
          .map((e) => Certification.fromJson(e)).toList(),
      portfolioLinks: (json['portfolio_links'] as List? ?? [])
          .map((e) => PortfolioLink.fromJson(e)).toList(),
      resumeUrl: json['resume_url'],
      openToWork: json['open_to_work'] ?? false,
      hiring: json['hiring'] ?? false,
      visibility: json['visibility'] ?? 'public',
      discoverable: json['discoverable'] ?? true,
    );
  }
  
  String getAvatar(bool isFormal) => isFormal ? avatarFormal : avatarCasual;
  
  // NEW: Mode-aware display
  String getHeadline(bool isFormal) => isFormal 
      ? headline 
      : headline.isNotEmpty ? "Into: $headline" : "";
      
  String getSkillsLabel(bool isFormal) => isFormal ? "Skills" : "Interests";
}
```

---

## 6. PHASE 3 — GPS-BASED DISCOVERY (ALONGSIDE BLE)

**Goal:** Add GPS-based nearby user discovery as a SECOND discovery mode alongside BLE.
**Duration:** 2 weeks
**Risk:** MEDIUM (new permission flows, battery impact, location privacy)

### Discovery Mode Design

```
NEARBY TAB (nearby_screen.dart)
├── [Toggle: BLE Radar | GPS Map]     ← User picks discovery method
│
├── BLE MODE (current — unchanged)
│   ├── Tap radar to scan
│   ├── Shows users within ~100m
│   ├── No location stored
│   └── Works offline/indoors
│
└── GPS MODE (new)
    ├── Opt-in: "Share my location to see nearby people"
    ├── Stores { lat, lng, geohash } in Firestore
    ├── Queries users within configurable radius (1-50 km)
    ├── Shows approximate distance ("~2.3 km away")
    ├── Optional map view
    └── Auto-stops when leaving screen
```

### Firestore: Geospatial Setup with GeoFlutterFire

**Note:** Firestore doesn't have built-in geospatial queries like MongoDB's `$nearSphere`. We use **GeoFlutterFire** library which stores geohashes for efficient location queries.

```dart
// lib/services/location_service.dart
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeoFlutterFire _geo = GeoFlutterFire();
  
  // Update user location in Firestore (replaces POST /location/update)
  Future<void> updateLocation(String uid, double lat, double lng) async {
    // Create GeoFirePoint with lat, lng
    GeoFirePoint point = _geo.point(latitude: lat, longitude: lng);
    
    await _firestore.collection('users').doc(uid).update({
      'location': {
        'lat': lat,
        'lng': lng,
        'geohash': point.hash,         // Used for geospatial queries
        'geopoint': point.geoPoint,    // Firestore GeoPoint type
        'timestamp': FieldValue.serverTimestamp(),
      },
      'last_active': FieldValue.serverTimestamp(),
      'discoverable': true,  // User is sharing location
    });
  }
  
  // Get nearby users via GPS (replaces GET /users/nearby/gps)
  Stream<List<DocumentSnapshot>> getNearbyUsersStream({
    required double lat,
    required double lng,
    required String currentUid,
    double radiusKm = 10.0,
  }) {
    GeoFirePoint center = _geo.point(latitude: lat, longitude: lng);
    
    var collectionRef = _firestore.collection('users');
    
    // GeoFlutterFire query: returns Stream of DocumentSnapshots
    // within radius, automatically filtered by geohash
    return _geo.collection(collectionRef: collectionRef)
        .within(
          center: center,
          radius: radiusKm,
          field: 'location',  // Field containing geohash
          strictMode: true,
        )
        .map((docs) {
          // Filter out current user and non-discoverable users
          return docs.where((doc) {
            if (doc.id == currentUid) return false;
            final data = doc.data() as Map<String, dynamic>?;
            return data?['discoverable'] == true;
          }).toList();
        });
  }
  
  // Calculate distance between two points (for display)
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // Returns km
  }
  
  // Clear user location (replaces POST /location/clear)
  Future<void> clearLocation(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'location': FieldValue.delete(),  // Remove location field entirely
      'discoverable': false,
    });
  }
}
```

**Firestore Data Structure for Location:**

```javascript
// users/{uid}
{
  "location": {
    "lat": 37.7749,
    "lng": -122.4194,
    "geohash": "9q8yy",           // GeoFlutterFire uses this for queries
    "geopoint": GeoPoint(37.7749, -122.4194),  // Firestore GeoPoint type
    "timestamp": Timestamp
  },
  "discoverable": true            // Privacy flag
}
```
```

### New Flutter Files (Phase 3)

| New File | Purpose | Lines |
|----------|---------|-------|
| `lib/services/location_service.dart` | GPS permission, get position, periodic updates | ~100 |
| `lib/screens/nearby_map_screen.dart` | Google Maps view of nearby users | ~150 |
| `lib/widgets/discovery_mode_toggle.dart` | BLE / GPS toggle widget | ~40 |

### Files To Modify (Phase 3)

| File | Changes |
|------|---------|
| `nearby_screen.dart` | Add BLE/GPS toggle at top; GPS mode shows list with distances; link to map view |
| `app_state.dart` | Add `locationService`, `nearbyGpsUsers`, location update timer, `discoveryMode` enum |
| `api_service.dart` | Add `updateLocation()`, `getNearbyGps()`, `clearLocation()` |
| `models.dart` | Add `distanceKm` optional field to User |

### New Dependencies (Phase 3)

| Package | Purpose |
|---------|---------|
| `geolocator: ^11.0.0` | GPS coordinates |
| `geoflutterfire2: ^2.3.15` | Geospatial queries in Firestore |
| `google_maps_flutter: ^2.5.0` | Map view (optional, can defer) |

### Battery Optimization Strategy

```dart
// location_service.dart
class LocationService {
  Timer? _updateTimer;
  
  /// Start periodic updates (only when nearby screen is active)
  void startUpdates(Function(double lat, double lng) onUpdate) {
    _updateTimer = Timer.periodic(
      const Duration(seconds: 30),  // Update every 30 seconds (not continuous)
      (_) async {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,  // Medium = less battery
        );
        onUpdate(pos.latitude, pos.longitude);
      },
    );
  }
  
  /// Stop updates when leaving screen
  void stopUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }
}
```

---

## 7. PHASE 4 — VIDEO REELS & RICH MEDIA

**Goal:** Add short video upload, playback, and a TikTok-style vertical swipe feed.
**Duration:** 2-3 weeks
**Risk:** MEDIUM (video processing, storage, performance)

### Content Type Extension

```
CURRENT content types:
├── "post" (text + optional image)
└── "story" (text + optional image, shown differently)

NEW content types:
├── "post" (text + optional image)          ← unchanged
├── "story" (text + optional image)         ← + auto-expiry (Phase 7)
├── "reel" (short video, 15-60 seconds)     ← NEW
└── "article" (long-form text, formal only) ← NEW (optional, Phase 2+)
```

### Backend Changes

```python
# Video upload size limit
MAX_VIDEO_SIZE = 100 * 1024 * 1024  # 100 MB
MAX_VIDEO_DURATION = 60              # seconds

@app.post("/content/create")
async def create_content(
    username: str = Form(...),
    text: str = Form(""),
    mode: str = Form(...),
    type: str = Form(...),        # post | story | reel
    file: UploadFile = File(None),
    duration: float = Form(0),    # Video duration in seconds (NEW)
    thumbnail: UploadFile = File(None)  # Video thumbnail (NEW)
):
    media_url = None
    thumb_url = None
    
    if file:
        ext = validate_upload(file)   # From Phase 1
        fname = f"{type}_{int(datetime.now().timestamp())}_{file.filename}"
        with open(os.path.join(UPLOADS_DIR, fname), "wb+") as f:
            shutil.copyfileobj(file.file, f)
        media_url = f"/uploads/{fname}"
    
    if thumbnail:
        tname = f"thumb_{int(datetime.now().timestamp())}_{thumbnail.filename}"
        with open(os.path.join(UPLOADS_DIR, tname), "wb+") as f:
            shutil.copyfileobj(thumbnail.file, f)
        thumb_url = f"/uploads/{tname}"
    
    item = {
        "username": username,
        "text": text,
        "mode": mode,
        "type": type,
        "media_url": media_url,
        "thumbnail_url": thumb_url,   # NEW
        "duration": duration,          # NEW (for reels)
        "timestamp": datetime.now().isoformat(),
        "likes": [],
        "comments": [],
        "views": 0,                    # NEW (for reels)
        "shares": 0,                   # NEW
        "author_avatar": ""
    }
    
    u = db.users.find_one({"username": username})
    if u:
        item["author_avatar"] = u.get(f'avatar_{mode.lower()}', "")
    
    if type == 'story':
        item["expires_at"] = (datetime.now() + timedelta(hours=24)).isoformat()
        db.stories.insert_one(item)
    elif type == 'reel':
        db.reels.insert_one(item)       # NEW collection
    else:
        db.posts.insert_one(item)
    
    return {"status": "success"}

# NEW: Reels feed endpoint
@app.get("/reels")
def get_reels(mode: str, page: int = 0, limit: int = 10):
    skip = page * limit
    reels = list(db.reels.find({"mode": mode})
        .sort("timestamp", -1)
        .skip(skip)
        .limit(limit))
    
    for r in reels:
        u = db.users.find_one({"username": r['username']})
        if u:
            r['author_avatar'] = u.get(f'avatar_{mode.lower()}', "")
    
    return [fix_id(r) for r in reels]

@app.post("/reel/{reel_id}/view")
def record_view(reel_id: str):
    db.reels.update_one({"_id": ObjectId(reel_id)}, {"$inc": {"views": 1}})
    return {"status": "success"}
```

### New Flutter Files (Phase 4)

| New File | Purpose | Lines |
|----------|---------|-------|
| `lib/screens/reels_screen.dart` | Vertical PageView swipe feed for short videos | ~200 |
| `lib/screens/record_reel_screen.dart` | Camera + timer for recording reels | ~180 |
| `lib/widgets/reel_card.dart` | Single reel display with overlay controls | ~120 |
| `lib/widgets/video_player_widget.dart` | Reusable video player with controls | ~80 |

### Files To Modify (Phase 4)

| File | Changes |
|------|---------|
| `home_shell.dart` | Add "Reels" tab (6th tab, or replace placeholder) |
| `create_post_screen.dart` | Add "Reel" option alongside "Feed Post" and "Story"; add video picker |
| `models.dart` | Add `Reel` model with `thumbnailUrl`, `duration`, `views`, `shares` |
| `api_service.dart` | Add `getReels()`, `recordView()`, video upload method |
| `app_state.dart` | Add `reels` list, `fetchReels()`, `createReel()` |
| `post_card.dart` | Handle video media_url (show play button overlay) |

### New Dependencies (Phase 4)

| Package | Purpose |
|---------|---------|
| `video_player: ^2.8.0` | Video playback |
| `chewie: ^1.7.0` | Enhanced video player UI (optional) |
| `video_compress: ^3.1.0` | Compress video before upload |
| `camera: ^0.10.0` | Record reels from within app |
| `path_provider: ^2.1.0` | Temp directory for video processing |

---

## 8. PHASE 5 — PUSH NOTIFICATIONS & REAL-TIME UPGRADES

**Goal:** Users receive notifications even when app is closed. This is the ONE thing that requires Firebase.
**Duration:** 1-2 weeks
**Risk:** MEDIUM (Firebase setup, platform-specific config)

### Why Firebase Is Needed Here (And Only Here)

```
Self-Hosted Alternative         | Why It Doesn't Work
─────────────────────────────── | ────────────────────────────
Custom WebSocket push           | Doesn't work when app is killed
Local notifications             | Can't be triggered from server
Email notifications             | Too slow, low engagement
SMS notifications               | Costs money per message

Firebase Cloud Messaging (FCM)  | Free, works on iOS+Android, 
                                | works when app is killed, 
                                | Google-maintained
```

### Backend Changes

```python
# NEW: Add to requirements.txt
# firebase-admin

import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase Admin (ONE TIME)
cred = credentials.Certificate("firebase-service-account.json")
firebase_admin.initialize_app(cred)

@app.post("/user/fcm-token")
async def register_fcm(
    token: str = Form(...),
    username: str = Depends(get_current_user)
):
    db.users.update_one({"username": username}, {"$set": {"fcm_token": token}})
    return {"status": "success"}

def send_push(to_username: str, title: str, body: str, data: dict = None):
    """Send push notification to a user."""
    user = db.users.find_one({"username": to_username})
    token = user.get("fcm_token") if user else None
    if not token:
        return
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=token,
        )
        messaging.send(message)
    except Exception as e:
        print(f"FCM Error: {e}")

# UPDATE existing notification points to also push:

# In interact() after creating like notification:
send_push(
    to_username=post['username'],
    title="Proxi",
    body=f"{username} liked your post",
    data={"type": "like", "post_id": id}
)

# In interact() after creating comment notification:
send_push(
    to_username=post['username'],
    title="Proxi",
    body=f"{username} commented: {comment}",
    data={"type": "comment", "post_id": id}
)

# In ws_endpoint/send_http after saving message:
send_push(
    to_username=data['to'],
    title=f"Message from {username}",
    body=data.get('text', 'Sent an attachment'),
    data={"type": "chat", "from": username}
)
```

### New Flutter Files (Phase 5)

| New File | Purpose | Lines |
|----------|---------|-------|
| `lib/services/notification_service.dart` | FCM init, token management, foreground handling | ~80 |

### New Dependencies (Phase 5)

| Package | Purpose |
|---------|---------|
| `firebase_core: ^2.24.0` | Firebase initialization |
| `firebase_messaging: ^14.7.0` | Push notification handling |
| `flutter_local_notifications: ^16.0.0` | Show notifications when app is in foreground |
| `firebase-admin` (Python) | Server-side push sending |

### Firebase Setup Steps

```
1. Create Firebase project at console.firebase.google.com
2. Add Android app (package: com.example.dual_mode_app)
3. Download google-services.json → android/app/
4. Add iOS app (if needed) → download GoogleService-Info.plist
5. Generate service account key → save as backend/firebase-service-account.json
6. Add Firebase SDK to Android build.gradle
7. NO Firestore, NO Firebase Auth, NO Firebase Storage — ONLY FCM
```

### Cost: $0

FCM is completely free with no usage limits.

---

## 9. PHASE 6 — PRIVACY CONTROLS & CONNECTION REQUEST SYSTEM

**Goal:** Add consent-based connection requests with tiered profile visibility.
**Duration:** 2 weeks
**Risk:** MEDIUM (new UX flows, state management complexity)

### Connection Request Flow

```
USER A sees USER B on Nearby screen
│
├── BEFORE Request:
│   ├── Shows: display name, avatar, approximate distance
│   ├── Shows: basic tags (3 skills max)
│   ├── Hidden: full profile, bio, experience, exact location
│   ├── Disabled: Chat button
│   └── Shows: [Connect] button
│
├── Request Sent (pending):
│   ├── A sees: "Request Sent ✓"
│   ├── B sees: notification "A wants to connect"
│   └── B can: Accept / Decline / Block
│
├── AFTER Accepted:
│   ├── Full profile visible to both
│   ├── Chat enabled
│   ├── Precise distance shown
│   ├── Optional: temporary location sharing
│   └── Appear in each other's "Connections" list
│
└── Declined / Blocked:
    ├── Declined: A can re-request after 7 days
    └── Blocked: A never sees B again in any list
```

### New MongoDB Collection: `connections`

```javascript
{
  "_id": ObjectId("..."),
  "from": "user_a",
  "to": "user_b",
  "status": "pending",           // pending | accepted | declined | blocked
  "mode": "formal",             // Which mode the request was sent in
  "message": "Hey, let's connect!",  // Optional intro message
  "created_at": "2026-02-18T...",
  "updated_at": "2026-02-18T...",
  "share_location_until": null   // Timestamp for temp location sharing
}
```

### New Backend Endpoints (Phase 6)

```python
@app.post("/connection/request")
async def send_request(
    target: str = Form(...),
    message: str = Form(""),
    mode: str = Form("formal"),
    username: str = Depends(get_current_user)
):
    # Check if already connected or blocked
    existing = db.connections.find_one({
        "$or": [
            {"from": username, "to": target},
            {"from": target, "to": username}
        ]
    })
    
    if existing:
        if existing['status'] == 'blocked':
            return {"status": "error", "message": "Cannot connect"}
        if existing['status'] == 'accepted':
            return {"status": "error", "message": "Already connected"}
        if existing['status'] == 'pending':
            return {"status": "error", "message": "Request already sent"}
    
    db.connections.insert_one({
        "from": username,
        "to": target,
        "status": "pending",
        "mode": mode,
        "message": message,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat()
    })
    
    # Notify target
    db.notifications.insert_one({
        "to": target, "from": username,
        "type": "connection_request",
        "text": "wants to connect with you",
        "timestamp": datetime.now().isoformat()
    })
    send_push(target, "Connection Request", f"{username} wants to connect with you")
    
    return {"status": "success"}

@app.post("/connection/respond")
async def respond_request(
    request_id: str = Form(...),
    action: str = Form(...),       # accept | decline | block
    username: str = Depends(get_current_user)
):
    conn = db.connections.find_one({"_id": ObjectId(request_id), "to": username})
    if not conn:
        return {"status": "error"}
    
    db.connections.update_one(
        {"_id": ObjectId(request_id)},
        {"$set": {"status": action, "updated_at": datetime.now().isoformat()}}
    )
    
    if action == 'accept':
        # Add to each other's followers/following
        db.users.update_one({"username": username}, {"$addToSet": {"following": conn['from'], "followers": conn['from']}})
        db.users.update_one({"username": conn['from']}, {"$addToSet": {"following": username, "followers": username}})
        
        send_push(conn['from'], "Connected!", f"{username} accepted your connection request")
    
    return {"status": "success"}

@app.get("/connections/{username}")
def get_connections(username: str = Depends(get_current_user)):
    connections = list(db.connections.find({
        "$or": [{"from": username}, {"to": username}],
        "status": "accepted"
    }))
    return [fix_id(c) for c in connections]

@app.get("/connections/pending")
def get_pending(username: str = Depends(get_current_user)):
    pending = list(db.connections.find({"to": username, "status": "pending"}))
    return [fix_id(p) for p in pending]

def are_connected(user_a: str, user_b: str) -> bool:
    return db.connections.find_one({
        "$or": [
            {"from": user_a, "to": user_b, "status": "accepted"},
            {"from": user_b, "to": user_a, "status": "accepted"}
        ]
    }) is not None
```

### New Flutter Files (Phase 6)

| New File | Purpose | Lines |
|----------|---------|-------|
| `lib/screens/connections_screen.dart` | List of connections, pending requests | ~150 |
| `lib/screens/connection_requests_screen.dart` | Accept/decline incoming requests | ~120 |
| `lib/widgets/privacy_settings_sheet.dart` | Bottom sheet for visibility controls | ~80 |
| `lib/widgets/connection_button.dart` | Smart button: Connect / Pending / Connected / Chat | ~60 |

### Files To Modify (Phase 6)

| File | Changes |
|------|---------|
| `nearby_screen.dart` | Show limited info for non-connected users; show Connect button |
| `chat_list_screen.dart` | Only show connected users (not all nearby users) |
| `chat_detail_screen.dart` | Block chat if not connected |
| `user_detail_screen.dart` | Show tiered profile based on connection status |
| `profile_screen.dart` | Add privacy settings button |
| `notifications_screen.dart` | Handle "connection_request" notification type |
| `models.dart` | Add `Connection` model |

---

## 10. PHASE 7 — FEED ALGORITHM & STORY EXPIRY

**Goal:** Personalize the feed; auto-delete stories after 24 hours.  
**Duration:** 1-2 weeks
**Risk:** LOW

### Story Expiry

```python
# OPTION A: TTL Index (MongoDB handles deletion automatically)
# Run once:
# db.stories.createIndex({"expires_at": 1}, {expireAfterSeconds: 0})

# OPTION B: Background task (more control)
# Add to requirements.txt: apscheduler

from apscheduler.schedulers.background import BackgroundScheduler

scheduler = BackgroundScheduler()

def cleanup_expired_stories():
    cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
    result = db.stories.delete_many({"timestamp": {"$lt": cutoff}})
    print(f"Cleaned up {result.deleted_count} expired stories")

scheduler.add_job(cleanup_expired_stories, 'interval', minutes=15)
scheduler.start()
```

### Personalized Feed

```python
@app.get("/feed")
def get_feed(mode: str, page: int = 0, limit: int = 20, username: str = Depends(get_current_user)):
    user = db.users.find_one({"username": username})
    following = user.get("following", []) if user else []
    
    skip = page * limit
    
    # Priority: posts from followed users first, then others
    followed_posts = list(db.posts.find({
        "mode": mode, 
        "username": {"$in": following}
    }).sort("timestamp", -1).skip(skip).limit(limit))
    
    # Fill remaining with other posts
    remaining = limit - len(followed_posts)
    if remaining > 0:
        other_posts = list(db.posts.find({
            "mode": mode, 
            "username": {"$nin": following + [username]}
        }).sort("timestamp", -1).limit(remaining))
        followed_posts.extend(other_posts)
    
    # Refresh avatars
    for p in followed_posts:
        u = db.users.find_one({"username": p['username']})
        if u:
            p['author_avatar'] = u.get(f'avatar_{mode.lower()}', "")
    
    # Stories (non-expired)
    cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
    stories = list(db.stories.find({
        "mode": mode,
        "timestamp": {"$gt": cutoff}
    }).sort("timestamp", -1))
    
    for s in stories:
        u = db.users.find_one({"username": s['username']})
        if u:
            s['author_avatar'] = u.get(f'avatar_{mode.lower()}', "")
    
    return {
        "posts": [fix_id(p) for p in followed_posts],
        "stories": [fix_id(s) for s in stories]
    }
```

### Files To Modify (Phase 7)

| File | Changes |
|------|---------|
| `feed_screen.dart` | Add infinite scroll pagination (load more on scroll) |
| `api_service.dart` | Add `page` parameter to `getFeed()` |
| `app_state.dart` | Pagination state, `loadMoreFeed()` method |

### New Dependencies (Phase 7)

| Package | Side | Purpose |
|---------|------|---------|
| `apscheduler` | Backend | Background task scheduler for story cleanup |

---

## 11. PHASE 8 — POLISH, TESTING & DEPLOYMENT

**Goal:** Production readiness, testing, deployment.
**Duration:** 2 weeks
**Risk:** LOW

### Polish Checklist

- [ ] Empty state screens (no posts, no connections, no notifications)
- [ ] Loading spinners on all async operations
- [ ] Pull-to-refresh on all list screens
- [ ] Error snackbars on API failures
- [ ] Offline mode detection (show banner)
- [ ] App icon and splash screen
- [ ] Onboarding/tour for first-time users
- [ ] Settings screen (notification preferences, privacy, theme)
- [ ] About/help screen
- [ ] Delete account functionality
- [ ] Logout clears token and state

### Testing Plan

```
UNIT TESTS (Flutter)
├── models_test.dart          — JSON parsing edge cases
├── api_service_test.dart     — Mock HTTP responses
├── app_state_test.dart       — State transitions
└── haversine_test.dart       — Distance calculation accuracy

WIDGET TESTS
├── post_card_test.dart       — Like/comment interactions
├── mode_switch_test.dart     — Toggle state changes
└── auth_screen_test.dart     — Validation messages

INTEGRATION TESTS  
├── login_flow_test.dart      — Register → Login → Feed
├── post_creation_test.dart   — Create post → appears in feed
├── chat_flow_test.dart       — Send message → received
└── nearby_flow_test.dart     — GPS update → appears in results

BACKEND TESTS (pytest)
├── test_auth.py              — Register, login, invalid password
├── test_content.py           — Create post, get feed, interactions
├── test_chat.py              — Message sending, history
├── test_location.py          — Geo queries, distance calculation
├── test_connections.py       — Request → Accept → Connected
└── test_security.py          — JWT validation, rate limits
```

### Deployment Options

```
BACKEND DEPLOYMENT
├── Option A: Railway.app     — Free tier, auto-deploy from GitHub
├── Option B: Render.com      — Free tier, supports FastAPI
├── Option C: VPS (DigitalOcean $5/mo) — Full control
└── Docker: Dockerfile provided for any platform

MONGODB
├── Option A: MongoDB Atlas   — Free 512MB cluster
├── Option B: Self-hosted     — On same VPS as backend
└── Connection string update in main.py

FLUTTER APP
├── Android: APK build → Play Store or direct install
├── iOS: Xcode archive → TestFlight / App Store
└── Both: flutter build apk --release / flutter build ios
```

### New Files (Phase 8)

| New File | Purpose |
|----------|---------|
| `lib/screens/settings_screen.dart` | App settings, notification prefs, privacy |
| `lib/screens/onboarding_screen.dart` | First-time user walkthrough |
| `lib/widgets/empty_state.dart` | Reusable "nothing here yet" widget |
| `lib/widgets/loading_overlay.dart` | Full-screen loading indicator |
| `backend/Dockerfile` | Container deployment |
| `backend/tests/` | Pytest test suite |
| `mobile_app/test/` | Flutter test suite |
| `docker-compose.yml` | One-command development setup |

---

## 12. DATABASE SCHEMA EVOLUTION

### Migration Summary (Firestore)

**Note:** Firestore doesn't require formal migrations like SQL. New fields can be added at any time. This shows the progressive schema evolution across phases.

```javascript
// Phase 1: Firebase Migration
// - Migrate MongoDB → Firestore
// - Users re-register (Firebase Auth handles passwords)
// - Document IDs = Firebase Auth UIDs

// Phase 2: ADD to users (write these fields when creating/updating profiles)
{ 
  "full_name": "", 
  "headline": "", 
  "skills": [], 
  "experience": [], 
  "education": [], 
  "certifications": [], 
  "portfolio_links": [],
  "resume_url": null, 
  "open_to_work": false, 
  "hiring": false,
  "visibility": "public", 
  "discoverable": true,
  "created_at": Timestamp,
  "last_active": Timestamp
}
// + CREATE jobs collection (new top-level collection)

// Phase 3: ADD to users
{ 
  "location": { 
    "lat": 0, 
    "lng": 0, 
    "geohash": "",  // For GeoFlutterFire queries
    "geopoint": GeoPoint(0, 0),
    "timestamp": Timestamp 
  } 
}

// Phase 4: ADD to posts/stories
{ 
  "thumbnail_url": null, 
  "duration": 0, 
  "views": 0, 
  "shares": 0,
  "media_type": "image" | "video" | "reel"
}
// + CREATE reels collection (new top-level collection)

// Phase 5: ADD to users
{ "fcm_token": null }

// Phase 6: CREATE connections collection
// Structure: connections/{connectionId}
{ 
  "from": String,      // User UID
  "to": String,        // User UID
  "status": String,    // pending | accepted | blocked
  "mode": String,      // formal | casual
  "message": String,
  "created_at": Timestamp, 
  "updated_at": Timestamp 
}

// Phase 7: Stories auto-expiration
// - Add TTL Cloud Function to delete stories where expires_at < now()
// - Firestore doesn't have native TTL like MongoDB
// - Alternative: Add expires_at field, delete via scheduled function
```

### Firestore Indexes To Create

**Note:** Firestore automatically creates single-field indexes. Only composite indexes (multiple fields) need manual configuration via Firebase Console or `firestore.indexes.json`.

```json
// firestore.indexes.json — Place in project root, deploy via Firebase CLI
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "mode", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "author_id", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "stories",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "mode", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "reels",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "mode", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "connections",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "to", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "jobs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "active", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Deploy indexes:**
```bash
firebase deploy --only firestore:indexes
```

---

## 13. FIREBASE SDK OPERATIONS (REPLACES REST API)

### Architecture Shift: Backend → Client

**With Firebase, there is NO backend REST API.** All operations happen directly from Flutter app via Firebase SDKs, secured by Security Rules.

### Complete Operations Map

```
AUTH (Firebase Auth SDK)
  • signUp(email, password)           [Firebase Auth]  Create account
  • signIn(email, password)           [Firebase Auth]  Login
  • signOut()                         [Firebase Auth]  Logout
  • authStateChanges stream           [Firebase Auth]  Listen to auth state
  • sendPasswordResetEmail()          [Firebase Auth]  Reset password

PROFILE (Firestore SDK)
  • getUser(uid)                      [READ]   Get user by UID
  • getUserByUsername(username)       [QUERY]  Find user by username
  • updateProfile(uid, data)          [UPDATE] Update profile fields
  • updateExperience(uid, list)       [UPDATE] Update experience array
  • updateEducation(uid, list)        [UPDATE] Update education array
  • uploadResume(file)                [Storage] Upload PDF to Firebase Storage
  • uploadAvatar(file)                [Storage] Upload image to Firebase Storage
  • updateFcmToken(uid, token)        [UPDATE] Store push notification token

CONTENT (Firestore SDK + Storage)
  • createPost(data)                  [CREATE] Add post document
  • getFeedStream(mode)               [QUERY]  Real-time feed query
  • getUserPostsStream(uid)           [QUERY]  User's posts
  • likePost(postId, uid)             [UPDATE] Increment likes, add to likes subcollection
  • commentOnPost(postId, comment)    [CREATE] Add comment subcollection
  • deletePost(postId)                [DELETE] Remove post document
  • sharePost(postId, uid)            [CREATE] Create share/repost

REELS (Firestore SDK + Storage)
  • getReelsStream(mode)              [QUERY]  Real-time reels feed
  • uploadReelVideo(file)             [Storage] Upload video + generate thumbnail
  • recordReelView(reelId)            [UPDATE] Increment view count

STORIES (Firestore SDK + Storage)
  • createStory(data)                 [CREATE] Add story with expires_at
  • getStoriesStream(mode)            [QUERY]  Real-time stories (filtered by expires_at)
  • deleteExpiredStories()            [Cloud Function scheduled hourly]

DISCOVERY
  • BLE: scanForNearbyUsers()         [flutter_blue_plus] Local Bluetooth scanning
  • updateLocation(uid, lat, lng)     [UPDATE] Store location with geohash
  • getNearbyUsersStream(lat, lng, r) [GeoFlutterFire] Real-time geospatial query
  • clearLocation(uid)                [UPDATE] Remove location field

CONNECTIONS (Firestore SDK)
  • sendConnectionRequest(from, to)   [CREATE] Add connection document
  • respondToRequest(id, status)      [UPDATE] Update connection status
  • getConnectionsStream(uid)         [QUERY]  Real-time accepted connections
  • getPendingRequestsStream(uid)     [QUERY]  Real-time incoming requests

JOBS (Firestore SDK - Formal Mode Only)
  • createJob(data)                   [CREATE] Add job document
  • getJobsStream(type, mode)         [QUERY]  Real-time jobs feed
  • applyToJob(jobId, uid)            [UPDATE] Add user to applicants array
  • getJobApplicants(jobId)           [READ]   List applicants (poster only, Security Rules enforce)

CHAT (Firestore SDK subcollections)
  • getChatStream(chatId)             [QUERY]  Real-time messages subcollection
  • sendMessage(chatId, message)      [CREATE] Add message to subcollection
  • uploadChatAttachment(file)        [Storage] Upload media to chat_files/
  • getConversationsStream(uid)       [QUERY]  List all chats for user
  • markChatAsRead(chatId)            [UPDATE] Update read status

NOTIFICATIONS (Firestore SDK + FCM)
  • getNotificationsStream(uid)       [QUERY]  Real-time notifications
  • markAsRead(notificationId)        [UPDATE] Update read field
  • sendPushNotification(uid, data)   [FCM Admin SDK via Cloud Function]

TOTAL: 40+ operations, all client-side via Firebase SDKs
```

### Why No Backend?

| Feature | Old (FastAPI) | New (Firebase) |
|---------|---------------|----------------|
| **Auth** | JWT tokens, bcrypt in Python | Firebase Auth handles everything |
| **Database** | MongoDB via REST endpoints | Firestore SDK direct access |
| **File Upload** | Multipart/form-data to /uploads | Firebase Storage SDK direct upload |
| **Real-time** | WebSockets (custom implementation) | Firestore snapshots() (built-in) |
| **Security** | Python middleware, manual checks | Firestore Security Rules (declarative) |
| **Push Notifications** | (not implemented) | FCM built-in |
| **Geospatial** | MongoDB $nearSphere queries | GeoFlutterFire library |

### Optional: Cloud Functions (For Advanced Features)

```javascript
// functions/index.js — Optional backend logic
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Example: Send push notification when someone likes your post
exports.sendLikeNotification = functions.firestore
  .document('posts/{postId}/likes/{likeId}')
  .onCreate(async (snap, context) => {
    const like = snap.data();
    const postId = context.params.postId;
    
    // Get post author's FCM token
    const post = await admin.firestore().collection('posts').doc(postId).get();
    const authorId = post.data().author_id;
    
    const authorDoc = await admin.firestore().collection('users').doc(authorId).get();
    const fcmToken = authorDoc.data().fcm_token;
    
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'New Like',
          body: `${like.username} liked your post`,
        },
        data: { postId, type: 'like' },
      });
    }
  });

// Delete expired stories (runs hourly)
exports.cleanupExpiredStories = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const expiredStories = await admin.firestore()
      .collection('stories')
      .where('expires_at', '<', now)
      .get();
    
    const batch = admin.firestore().batch();
    expiredStories.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    
    console.log(`Deleted ${expiredStories.size} expired stories`);
  });
```

---

## 14. NEW FLUTTER FILES TO CREATE

### Complete New File List

```
Phase 1 (0 new files — all modifications)

Phase 2 (9 new files)
  lib/screens/edit_profile_screen.dart       ~200 lines
  lib/screens/experience_screen.dart         ~180 lines
  lib/screens/education_screen.dart          ~150 lines
  lib/screens/jobs_screen.dart               ~160 lines
  lib/screens/create_job_screen.dart         ~130 lines
  lib/screens/user_detail_screen.dart        ~200 lines
  lib/widgets/skill_chip.dart                ~30 lines
  lib/widgets/experience_card.dart           ~50 lines
  lib/widgets/job_card.dart                  ~60 lines

Phase 3 (3 new files)
  lib/services/location_service.dart         ~100 lines
  lib/screens/nearby_map_screen.dart         ~150 lines
  lib/widgets/discovery_mode_toggle.dart     ~40 lines

Phase 4 (4 new files)
  lib/screens/reels_screen.dart              ~200 lines
  lib/screens/record_reel_screen.dart        ~180 lines
  lib/widgets/reel_card.dart                 ~120 lines
  lib/widgets/video_player_widget.dart       ~80 lines

Phase 5 (1 new file)
  lib/services/notification_service.dart     ~80 lines

Phase 6 (4 new files)
  lib/screens/connections_screen.dart        ~150 lines
  lib/screens/connection_requests_screen.dart ~120 lines
  lib/widgets/privacy_settings_sheet.dart    ~80 lines
  lib/widgets/connection_button.dart         ~60 lines

Phase 7 (0 new files — all modifications)

Phase 8 (4 new files)
  lib/screens/settings_screen.dart           ~200 lines
  lib/screens/onboarding_screen.dart         ~250 lines
  lib/widgets/empty_state.dart               ~40 lines
  lib/widgets/loading_overlay.dart           ~30 lines

TOTAL NEW FILES: 25
TOTAL NEW LINES: ~3,240 (estimated)
CURRENT LINES:   ~1,523
FINAL TOTAL:     ~4,763 lines of Dart (3.1x growth)
```

---

## 15. FILES TO MODIFY

### Modification Map

```
BACKEND:
  main.py              — HEAVY: auth rewrite, new endpoints, pagination, geo queries
  requirements.txt     — ADD: bcrypt, pyjwt, slowapi, firebase-admin, apscheduler

FLUTTER CORE:
  models.dart          — HEAVY: User expanded, + 8 new models
  api_service.dart     — HEAVY: token auth, + 15 new methods
  app_state.dart       — HEAVY: + jobs, reels, connections, location, notifications state
  constants.dart       — LIGHT: + professional section colors
  main.dart            — LIGHT: + notification initialization

SCREENS:
  auth_screen.dart     — MEDIUM: + register mode, error handling, loading state
  home_shell.dart      — MEDIUM: + conditional tabs (jobs in formal, reels tab)
  feed_screen.dart     — MEDIUM: + pagination, story expiry badge
  nearby_screen.dart   — HEAVY: + BLE/GPS toggle, connection status, privacy-aware display
  profile_screen.dart  — HEAVY: + professional info, privacy settings, working bio edit
  chat_list_screen.dart — MEDIUM: + real conversation list (not nearby users)
  chat_detail_screen.dart — LIGHT: + connection check before allowing chat
  create_post_screen.dart — MEDIUM: + reel option, video picker
  story_view_screen.dart  — LIGHT: + expiry indicator
  notifications_screen.dart — MEDIUM: + connection request type, mark as read

WIDGETS:
  post_card.dart       — MEDIUM: + video support, share button
  mode_switch.dart     — KEEP: unchanged
  story_circle.dart    — LIGHT: + expiry indicator ring

PUBSPEC:
  pubspec.yaml         — ADD: ~12 new dependencies
```

---

## 16. DEPENDENCY CHANGES (FIREBASE VERSION)

### pubspec.yaml Evolution

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # EXISTING (keep all)
  provider: ^6.0.0
  google_fonts: ^6.1.0
  lucide_icons: ^0.257.0
  flutter_animate: ^4.2.0
  cached_network_image: ^3.3.0
  intl: ^0.18.0
  image_picker: ^1.0.4
  permission_handler: ^11.0.0
  flutter_blue_plus: ^1.15.0
  
  # REMOVE (no longer needed with Firebase)
  # http: ^1.1.0 — Firebase SDKs handle all HTTP
  # web_socket_channel: ^2.4.0 — Firestore snapshots() replace WebSockets
  
  # NEW — Phase 1: Firebase Core
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  firebase_storage: ^11.5.0
  shared_preferences: ^2.2.0
  
  # NEW — Phase 3: GPS Discovery
  geolocator: ^11.0.0
  geoflutterfire2: ^2.3.15         # Geospatial queries for Firestore
  google_maps_flutter: ^2.5.0
  
  # NEW — Phase 4: Video
  video_player: ^2.8.0
  video_compress: ^3.1.0
  camera: ^0.10.0
  path_provider: ^2.1.0
  
  # NEW — Phase 5: Push Notifications
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.0.0
```

### Backend Dependencies (ELIMINATED)

**Firebase eliminates the need for a Python backend entirely.**

Old `requirements.txt` (obsolete):
```python
# NO LONGER NEEDED
# fastapi
# uvicorn
# pymongo
# python-multipart
# pydantic
# websockets
# bcrypt
# pyjwt
# slowapi
# firebase-admin
# apscheduler
```

**Optional: Cloud Functions (Node.js)**

If you need backend logic (push notifications, scheduled tasks), use Firebase Cloud Functions:

```json
// package.json (deploy to Firebase)
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  }
}
```

**Deploy:**
```bash
firebase deploy --only functions
```

---

## 17. RISK REGISTER (FIREBASE VERSION)

| Risk | Phase | Severity | Likelihood | Mitigation |
|------|-------|----------|------------|------------|
| Data loss during Firebase migration | 1 | HIGH | LOW | Run migration script, test thoroughly, keep MongoDB backup for 2 weeks |
| Firebase free tier limits exceeded | 1-2 | MEDIUM | LOW | Monitor usage in console; free tier generous for dev/testing |
| Breaking existing login flow | 1 | HIGH | MEDIUM | Users must re-register (Firebase Auth incompatible with old passwords); communicate this clearly |
| Firebase Security Rules misconfigured | 1 | HIGH | MEDIUM | Test rules thoroughly; use Firebase Emulator Suite locally |
| GPS drains battery in background | 3 | MEDIUM | HIGH | Only update when nearby screen active; 30s intervals; medium accuracy |
| Video uploads too large / slow | 4 | MEDIUM | MEDIUM | 100MB Storage Rules limit; client-side compression; Firebase Storage CDN handles delivery |
| Firebase learning curve | 1-5 | MEDIUM | MEDIUM | Follow official Firebase docs; use FlutterFire CLI for setup |
| Connection request spam | 6 | MEDIUM | LOW | Rate limit via app logic: 20 requests/day; 7-day cooldown after decline |
| Firestore query costs at scale | 7+ | MEDIUM | LOW | Use composite indexes; pagination; denormalize data; monitor Firebase Console |
| Feature creep / scope expansion | ALL | HIGH | HIGH | Strict phase boundaries; each phase = working app; no skipping |
| Breaking dual-mode parity | ALL | HIGH | MEDIUM | Every feature must test in BOTH modes before release |
| Firebase vendor lock-in | ALL | LOW | HIGH | Firebase = industry standard; migration path exists (export Firestore data to JSON) |

---

## 18. MVP MILESTONE CHECKLIST (FIREBASE VERSION)

### After Phase 1 ✅ (Week 2)
- [ ] Firebase project created and configured
- [ ] Firebase Auth working (email/password signup & login)
- [ ] Old MongoDB data migrated to Firestore
- [ ] Firestore Security Rules deployed
- [ ] Firebase Storage Rules deployed
- [ ] All existing features work with Firebase
- [ ] Auth state persists across app restarts
- [ ] Users can re-register with Firebase Auth

### After Phase 2 ✅ (Week 4)
- [ ] User can edit full name, headline, skills in Firestore
- [ ] Experience and education sections on profile
- [ ] Profile looks different in formal vs casual mode
- [ ] Job posts visible in formal mode feed
- [ ] Can apply to jobs (stored in Firestore)

### After Phase 3 ✅ (Week 5)
- [ ] BLE radar still works exactly as before
- [ ] GPS toggle available on nearby screen
- [ ] Nearby users show with distance ("2.3 km away")
- [ ] Location cleared when leaving screen
- [ ] Optional map view

### After Phase 4 ✅ (Week 7)
- [ ] Can record 15-60 second video
- [ ] Reels tab with vertical swipe
- [ ] Videos auto-play, auto-pause on scroll
- [ ] View count tracks
- [ ] Works in both formal and casual mode

### After Phase 5 ✅ (Week 8)
- [ ] Push notification on like
- [ ] Push notification on comment
- [ ] Push notification on new message
- [ ] Push notification on connection request
- [ ] Works when app is killed

### After Phase 6 ✅ (Week 10)
- [ ] Connection request sends from nearby screen
- [ ] Pending requests show in notifications
- [ ] Accept/decline works
- [ ] Chat only available for connected users
- [ ] Profile visibility respects privacy settings

### After Phase 7 ✅ (Week 11)
- [ ] Stories disappear after 24 hours
- [ ] Feed shows followed users' posts first
- [ ] Pagination works (infinite scroll)

### After Phase 8 ✅ (Week 13)
- [ ] Settings screen functional
- [ ] Empty states on all screens
- [ ] Loading indicators everywhere
- [ ] No crashes on edge cases
- [ ] App icon and splash screen
- [ ] Backend deployed to cloud
- [ ] APK built and installable

---

## 19. COST ESTIMATION (FIREBASE VERSION)

### Development Phase (Free)

| Resource | Cost | Notes |
|----------|------|-------|
| Firebase Spark Plan | $0 | Includes Auth, Firestore, Storage, FCM, Hosting |
| Firestore | $0 | 1 GB storage, 50K reads/day, 20K writes/day |
| Firebase Storage | $0 | 5 GB storage, 1 GB downloads/day |
| Firebase Auth | $0 | Unlimited auth operations |
| Firebase Cloud Messaging | $0 | Unlimited push notifications |
| Firebase Hosting | $0 | 10 GB hosting, 360 MB/day transfer |
| Flutter SDK | $0 | Open source |
| GeoFlutterFire | $0 | Open source library |
| Google Maps SDK | $0 | Free: 28,000 map loads/month |
| Total Dev Cost | **$0** | |

### Production Phase (< 1,000 Users)

**Firebase Spark Plan (Free Tier) is sufficient:**

| Resource | Cost/Month | Notes |
|----------|------------|-------|
| Firebase Spark Plan | $0 | Generous limits for small apps |
| Domain (optional) | $1 | .xyz or .app TLD |
| **Total** | **$0-1/month** | |

**Firebase Spark Plan Limits:**
- **Firestore:** 50K reads/day, 20K writes/day, 1 GB storage
- **Storage:** 5 GB files, 1 GB downloads/day
- **Auth:** Unlimited users
- **FCM:** Unlimited notifications
- **Hosting:** 10 GB bandwidth/month

**Expected Usage (1,000 users):**
- ~10K Firestore reads/day ✅ (within limit)
- ~3K Firestore writes/day ✅ (within limit)
- ~500 MB storage ✅ (within limit)

### Production Phase (1,000-10,000 Users)

**Upgrade to Firebase Blaze Plan (Pay-As-You-Go):**

| Resource | Est. Cost/Month | Notes |
|----------|----------------|-------|
| Firestore reads | $1-3 | $0.06 per 100K reads |
| Firestore writes | $0.50-2 | $0.18 per 100K writes |
| Firestore storage | $0-1 | $0.18/GB/month |
| Storage (media files) | $2-5 | $0.026/GB stored, $0.12/GB egress |
| Cloud Functions (optional) | $0-5 | Auto-cleanup, push triggers |
| Domain | $1 | .xyz or .app TLD |
| **Total** | **$5-17/month** | |

**Blaze Plan Usage Estimates (10,000 users):**
- **Reads:** ~500K/day → $9/month
- **Writes:** ~100K/day → $5.40/month
- **Storage:** 10 GB files → $0.26/month
- **Egress:** 20 GB downloads → $2.40/month

### Production Phase (10,000+ Users)

| Resource | Est. Cost/Month | Notes |
|----------|----------------|-------|
| Firestore operations | $20-40 | Scales with activity |
| Storage + CDN | $10-20 | Firebase Storage includes CDN |
| Cloud Functions | $5-15 | For background tasks |
| Domain + Custom email | $2-5 | |
| **Total** | **$37-80/month** | |

### Cost Comparison: Firebase vs Self-Hosted

| Metric | Self-Hosted (MongoDB + VPS) | Firebase |
|--------|----------------------------|----------|
| **< 1K users** | $5-13/month (VPS required) | $0/month (free tier) ✅ |
| **10K users** | $74-91/month (dedicated cluster) | $5-17/month ✅ |
| **Scalability** | Manual scaling, server management | Auto-scales, zero ops |
| **Security** | Manual SSL, firewall, updates | Built-in, auto-updates ✅ |
| **Backups** | Manual setup | Automatic daily backups ✅ |
| **Monitoring** | Self-hosted tools | Firebase Console built-in ✅ |
| **Push Notifications** | Separate FCM setup | Included ✅ |
| **File Storage** | Local disk or S3 ($5-10) | Included with CDN ✅ |
| **DDoS Protection** | DIY or Cloudflare | Built-in ✅ |

**Firebase is ~3-5x cheaper** and eliminates server maintenance entirely.

---

## 20. TIMELINE (FIREBASE VERSION)

```
WEEK 01-02    Phase 1: Firebase Migration
              ├── Firebase project setup (Auth, Firestore, Storage)
              ├── Migrate MongoDB data → Firestore (one-time script)
              ├── Replace API calls with Firebase SDK
              ├── Deploy Security Rules (firestore.rules + storage.rules)
              └── Test: All features work with Firebase

WEEK 03-04    Phase 2: Professional Profiles
              ├── Add Firestore fields to users collection
              ├── Profile edit screens  
              ├── Job posts system (new Firestore collection)
              └── Mode-aware profile display

WEEK 05-06    Phase 3: GPS Discovery
              ├── GeoFlutterFire integration for geospatial queries
              ├── Location service + permissions
              ├── BLE/GPS toggle on nearby screen
              └── Optional map view

WEEK 07-08    Phase 4: Video Reels
              ├── Firebase Storage video upload + CDN delivery
              ├── Reels vertical swipe feed
              ├── Record reel screen
              └── View tracking

WEEK 09       Phase 5: Push Notifications
              ├── FCM integration (already included in Firebase)
              ├── Cloud Functions for notification triggers (optional)
              └── Flutter: notification handling

WEEK 10-11    Phase 6: Privacy & Connection Requests
              ├── Connection request flow (new Firestore collection)
              ├── Tiered profile visibility (Security Rules)
              ├── Chat gating
              └── Privacy settings

WEEK 12       Phase 7: Feed Algorithm & Story Expiry
              ├── Personalized feed queries
              ├── Story TTL / auto-delete (Cloud Function)
              └── Pagination everywhere

WEEK 13-14    Phase 8: Polish & Deployment
              ├── Settings, onboarding, empty states
              ├── Testing suite
              ├── Deploy to Firebase Hosting (web) or Play Store (Android)
              └── Performance monitoring via Firebase Performance

TOTAL: ~14 WEEKS (3.5 months)
```

---

## GOLDEN RULE

**After every phase, the app must:**
1. ✅ Compile and run without errors
2. ✅ All EXISTING features still work
3. ✅ Formal/Casual toggle works on ALL new features
4. ✅ BLE discovery still works exactly as before
5. ✅ No data loss from previous phases

**This plan adds 22 new features without removing a single existing one.**

---

*Plan created: February 18, 2026 | Updated for Firebase: February 18, 2026*
*Project: Proxi Social Connectivity v2.0 (Firebase Edition)*
*Architecture: Flutter + Firebase (Firestore, Auth, Storage, FCM)*
*Estimated completion: June 2026 (14 weeks)*



