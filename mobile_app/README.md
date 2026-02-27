# Proxi 2.0 — Dual-Mode Social Connectivity Platform (Firebase Edition)

**Proxi** is an innovative social networking application that enables users to maintain two distinct online personas with a simple toggle. Switch seamlessly between:

- 🔵 **Formal / PRO Mode** — Professional networking (LinkedIn-style interface with blue theme)
- 🎨 **Casual / SOCIAL Mode** — Personal social sharing (Instagram-style interface with pink/gradient theme)

The app uses **Bluetooth Low Energy (BLE)** and **GPS** for proximity-based user discovery, allowing you to find and connect with people physically near you.

---

## ✨ Key Features

- **Dual Persona System** — Instantly switch between formal and casual modes without logging out
- **Mode-Specific Content** — Separate feeds, avatars, and UI themes for each mode
- **Proximity Discovery** — BLE proximity (≈10–15 m range) + GPS distance scanning (10 km radius) with animated UI
- **Real-time Chat** — Firestore-powered 1:1 messaging with media sharing, delete individual messages, clear or delete entire conversations
- **Group Chat** — Create group conversations with your connections (select 2+ members), clear or delete group chats
- **Stories & Posts** — Create ephemeral stories (24h auto-expiry) or permanent posts with media
- **Delete Content** — Delete your own posts, reels, and stories from anywhere in the app (including from the story viewer)
- **Video Reels** — Record and browse short-form vertical video content (casual mode)
- **Professional Profiles** — Full name, headline, skills, experience, education (formal mode)
- **Job Board** — Post and apply for jobs in formal mode
- **Connection Requests** — Send, accept, or decline connections with smart status indicators (Connected / Pending / Accept); automatically allows re-sending after a declined request
- **Mutual Followers** — When a connection is accepted, both users automatically follow each other; removing a connection unfollows both ways
- **Remove & Reconnect** — Remove any connection and reconnect later from the Nearby or Profile screen
- **Push Notifications** — FCM-powered notifications for likes, comments, messages, and connections
- **Content Visibility** — Posts, stories, and reels respect the author's privacy setting (public / connections-only / private) and are filtered in real-time
- **Connection Status Awareness** — Nearby users and profile pages display live connection state so you never send duplicate requests
- **Onboarding** — 4-page walkthrough introducing app features

---

## 🏗️ Tech Stack

### **Backend — Firebase (Serverless)**

No self-hosted backend required. All operations use Firebase SDKs directly from the Flutter app.

| Service | Purpose |
|---------|---------|
| **Firebase Auth** | Email/password authentication with JWT |
| **Cloud Firestore** | Real-time NoSQL database |
| **Firebase Storage** | CDN-backed media file storage |
| **Firebase Cloud Messaging** | Push notifications |

**Firestore Collections:**
- `users` — User profiles with dual avatars, professional fields, location
- `posts` — Mode-specific user posts
- `stories` — Ephemeral story content (24h expiry)
- `reels` — Short-form video content
- `chats/{chatId}/messages` — Real-time chat messages (subcollection)
- `notifications` — Social interaction alerts
- `jobs` — Job postings (formal mode)
- `connections` — Connection requests and statuses

### **Frontend (Flutter)**

**Core:**
- **Flutter 3.0+** — Cross-platform mobile framework
- **Dart SDK** >=3.0.0 <4.0.0

**State Management:**
- `provider: ^6.0.0` — Centralized app state with `ChangeNotifier`

**Firebase:**
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`

**UI/UX:**
- `google_fonts: ^6.1.0` — Custom typography
- `lucide_icons: ^0.257.0` — Modern icon library
- `flutter_animate: ^4.2.0` — Smooth animations (radar pulse effects)
- `cached_network_image: ^3.3.0` — Optimized image loading
- `intl: ^0.18.0` — Date/time formatting

**Hardware & Media:**
- `flutter_blue_plus: ^1.15.0` — Bluetooth Low Energy scanning
- `geolocator: ^11.0.0` — GPS location services
- `google_maps_flutter: ^2.5.0` — Optional map view
- `image_picker: ^1.0.4` — Camera and gallery access
- `video_player: ^2.8.0` — Video playback for reels
- `video_compress: ^3.1.0` — Client-side video compression
- `camera: ^0.10.0` — Camera access for recording
- `permission_handler: ^11.0.0` — Runtime permission management

**Notifications:**
- `flutter_local_notifications: ^16.0.0` — Foreground notification display

---

## 📋 Prerequisites

Before running this project, ensure you have:

1. **Flutter SDK** — Version 3.0 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
2. **Firebase Project** — Created at [Firebase Console](https://console.firebase.google.com/)
3. **FlutterFire CLI** — `dart pub global activate flutterfire_cli` ([FlutterFire docs](https://firebase.flutter.dev/docs/cli/))
4. **Android Studio** (for Android) or **Xcode** (for iOS)
5. **Physical Device** (recommended) — BLE features require a real device

---

## 🚀 Setup Instructions

### **Step 1: Create Firebase Project**

1. Go to [Firebase Console](https://console.firebase.google.com/) → Add Project
2. Enable these services in the console:
   - **Authentication** → Sign-in method → Email/Password → Enable
   - **Cloud Firestore** → Create database → Start in production mode
   - **Storage** → Get started → Start in production mode
   - **Cloud Messaging** → Enabled by default

### **Step 2: Configure Firebase in Flutter**

```bash
cd mobile_app

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (generates google-services.json / GoogleService-Info.plist)
flutterfire configure --project=YOUR_PROJECT_ID
```

This generates:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

### **Step 3: Deploy Security Rules**

```bash
# From project root (where firestore.rules is located)
firebase deploy --only firestore:rules
firebase deploy --only storage
firebase deploy --only firestore:indexes
```

Or copy the rules from `firestore.rules` and `storage.rules` into Firebase Console manually.

### **Step 4: Install Dependencies & Run**

```bash
cd mobile_app
flutter pub get
flutter run
```

### **Step 5: Grant Permissions**

When you first launch the app, grant the following permissions:
- **Bluetooth** — For proximity discovery
- **Location** — For GPS nearby scanning + required by Android for BLE
- **Camera** — For taking photos/videos
- **Storage** — For selecting media from gallery
- **Notifications** — For push notifications

---

## 📁 Project Structure

```
Proxi_Social_Connectivity/
├── firestore.rules                     # Firestore security rules
├── storage.rules                       # Firebase Storage security rules
├── firestore.indexes.json              # Composite index definitions
├── plan.md                             # Full 8-phase evolution blueprint
│
└── mobile_app/                         # Flutter Mobile App
    ├── pubspec.yaml                    # Flutter dependencies
    ├── lib/
    │   ├── main.dart                   # App entry (Firebase init, Provider setup)
    │   ├── app_state.dart              # Global state (auth, feed, reels, jobs, chat)
    │   ├── ble_service.dart            # Bluetooth Low Energy scanning
    │   ├── constants.dart              # Color themes & shared constants
    │   ├── models.dart                 # Data models (AppUser, Post, Job, Connection)
    │   │
    │   ├── services/                   # Firebase & device services
    │   │   ├── auth_service.dart       # Firebase Auth wrapper
    │   │   ├── firebase_service.dart   # Firestore CRUD (40+ operations)
    │   │   ├── location_service.dart   # GPS permissions & location updates
    │   │   └── notification_service.dart # FCM + local notifications
    │   │
    │   ├── screens/                    # UI screens (23 files)
    │   │   ├── auth_screen.dart        # Login / Register
    │   │   ├── onboarding_screen.dart  # 4-page first-launch walkthrough
    │   │   ├── home_shell.dart         # Tab navigation (6 tabs per mode)
    │   │   ├── feed_screen.dart        # Stories + posts feed
    │   │   ├── nearby_screen.dart      # BLE/GPS discovery with radar UI
    │   │   ├── nearby_map_screen.dart  # Visual radar-style map
    │   │   ├── create_post_screen.dart # Post/story creator
    │   │   ├── reels_screen.dart       # Vertical video swipe feed
    │   │   ├── record_reel_screen.dart # Record/upload short video
    │   │   ├── jobs_screen.dart        # Job board (formal mode)
    │   │   ├── create_job_screen.dart  # Post new job
    │   │   ├── chat_list_screen.dart   # Conversations list
    │   │   ├── chat_detail_screen.dart # Real-time messages
    │   │   ├── profile_screen.dart     # User profile + posts grid
    │   │   ├── edit_profile_screen.dart # Edit profile fields & avatars
    │   │   ├── user_detail_screen.dart # View another user's profile
    │   │   ├── experience_screen.dart  # Work experience editor
    │   │   ├── education_screen.dart   # Education editor
    │   │   ├── connections_screen.dart # Accepted connections list
    │   │   ├── connection_requests_screen.dart # Pending requests
    │   │   ├── notifications_screen.dart # Notification feed
    │   │   ├── settings_screen.dart    # App settings & privacy
    │   │   ├── story_view_screen.dart  # Full-screen story viewer
    │   │   ├── create_group_chat_screen.dart # Create group from connections
    │   │   └── group_chat_detail_screen.dart # Group chat messages
    │   │
    │   └── widgets/                    # Reusable components (13 files)
    │       ├── mode_switch.dart        # Formal/Casual toggle animation
    │       ├── post_card.dart          # Post display card
    │       ├── story_circle.dart       # Story avatar bubble
    │       ├── reel_card.dart          # Full-screen reel overlay
    │       ├── video_player_widget.dart # Video playback controller
    │       ├── job_card.dart           # Job listing card
    │       ├── skill_chip.dart         # Skill tag chip
    │       ├── experience_card.dart    # Work history entry
    │       ├── connection_button.dart  # Smart connect/pending/accepted button
    │       ├── discovery_mode_toggle.dart # BLE/GPS selector
    │       ├── privacy_settings_sheet.dart # Visibility bottom sheet
    │       ├── empty_state.dart        # Empty screen placeholder
    │       └── loading_overlay.dart    # Full-screen loading indicator
    │
    └── test/
        └── widget_test.dart            # Basic smoke tests
```

---

## 🔧 Architecture

### **Dual Mode System**

Users have two separate avatars, themes, and content feeds:
- **Formal (PRO)** — Blue theme, 6 tabs: Home | Nearby | Post | Jobs | Chat | Profile
- **Casual (SOCIAL)** — Pink/gradient theme, 6 tabs: Home | Nearby | Post | Reels | Chat | Profile

When mode is toggled via the FAB in `home_shell.dart`:
1. UI theme switches (blue ↔ pink/gradient)
2. Feed, stories, and reels filter by `mode` field
3. Displayed avatar changes (formal ↔ casual)
4. New content is tagged with current mode
5. Tab bar switches jobs ↔ reels

### **Proximity Discovery**

Two discovery modes available on the **Nearby** tab:

- **BLE (Bluetooth) — Range: ~10–15 meters**  
  `ble_service.dart` triggers a Bluetooth Low Energy scan to detect nearby physical devices. The app uses the BLE scan as a proximity gate — confirming that real devices are in physical range — and cross-references GPS coordinates within a 15-meter radius to identify discoverable Proxi users. If BLE hardware is unavailable, the app falls back to close-range GPS (~50 m). If GPS is also unavailable, the app attempts to match BLE device UUIDs with the `ble_uuid` field stored in each user's Firestore profile.

- **GPS — Range: 10 km radius**  
  `location_service.dart` obtains the device's coordinates via the `geolocator` package and writes them to the user's Firestore document. `firebase_service.dart` then queries all users in the same mode and calculates **haversine distance** to each one, returning only those within a **10 km** radius. Location updates run every 30 seconds while the Nearby tab is active.

Both modes display each discovered user as a card showing their avatar, name, headline, and a **live connection status indicator**:

| Status | Label | Color | Action |
|--------|-------|-------|--------|
| No connection | *Connect* | Green icon | Sends a connection request |
| Request sent | *Pending* | Orange | No action (waiting for response) |
| Request received | *Accept?* | Blue | Tap to open Connection Requests screen |
| Already connected | *Connected* | Green | No action |

### **Content Visibility System**

Every post, story, and reel is stored with a `visibility` field inherited from the author's privacy setting at the time of creation:

| Setting | Who can see the content |
|---------|------------------------|
| `public` | Everyone in the same mode |
| `connections` | Only accepted connections + the author |
| `private` | Only the author |

Filtering happens client-side in `app_state.dart` listeners — content that the current user is not allowed to see is excluded before it reaches the UI. This means feeds update instantly when a user changes their privacy setting or a new connection is accepted.

### **Connection Request Flow**

1. User A taps **Connect** on User B's card (Nearby screen or profile).
2. A `connections` document is created in Firestore with `status: 'pending'`.
3. User B sees the request in **Settings → Connection Requests** and can **Accept** or **Decline**.
4. If declined, the connection document is removed, and User A can re-send the request later.
5. If accepted, **both users automatically follow each other** (mutual follow) and appear in each other's **Connections** list. Both users' follower/following counts update in real-time on their profiles.
6. If a connection is **removed**, both users are **mutually unfollowed** and can reconnect later.

### **Real-time Data**

All data flows via Firestore `snapshots()` streams:
- Feed posts, stories, and reels update in real-time (with visibility filtering)
- Chat messages appear instantly for both participants
- Notifications stream to the notification badge
- Connection status (sent/received/accepted) is tracked via dedicated streams and reflected across the UI
- Connections and job postings reflect changes live

### **Security**

- **Authentication** — Firebase Auth handles email/password with automatic JWT
- **Database** — Firestore Security Rules restrict read/write by auth state and ownership
- **Storage** — Storage Rules enforce file type and size limits (10 MB images, 100 MB video, 5 MB PDFs)
- **No backend server required** — All security is declarative via rules files

---

## ⚠️ Important Notes

### **Firebase Setup Required**

Before the app will compile and run, you **must** set up a Firebase project and run `flutterfire configure`. Without this, `Firebase.initializeApp()` will fail at launch.

### **Platform Considerations**

**Android:**
- Permissions configured in `android/app/src/main/AndroidManifest.xml`
- `usesCleartextTraffic="true"` may be needed for local development
- Location permission required for both BLE scanning and GPS discovery

**iOS:**
- Requires `Info.plist` entries for Camera, Bluetooth, Location, and Notification usage descriptions
- FCM requires an APNs certificate or key configured in Firebase Console

### **Free Tier Limits**

Firebase Spark plan (free) is generous for development and small apps:
- **Firestore:** 50K reads/day, 20K writes/day, 1 GB storage
- **Storage:** 5 GB files, 1 GB downloads/day
- **Auth:** Unlimited users
- **FCM:** Unlimited push notifications

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|---------|
| `Firebase.initializeApp()` fails | Run `flutterfire configure` to generate config files |
| BLE not working | Use a physical device, grant Bluetooth + Location permissions. On Android 12+, `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` permissions are required. BLE range is approximately **10–15 meters** — users must be physically nearby. If BLE hardware is unavailable, the app falls back to close-range GPS. |
| GPS shows no users | Ensure location permission granted; other users must have location enabled and be within **10 km**. Check that both users are in the **same mode** (Formal or Casual). The app stores location on each scan, so both users must have scanned recently. |
| Connection request not received | Verify both users are online and the recipient checks **Settings → Connection Requests**. If a previous request was declined, the sender can re-send. |
| Content not visible | The author's privacy setting may be set to *connections* or *private*. Accept a connection request or ask the author to change their visibility in Settings. |
| Images not loading | Verify Firebase Storage rules allow authenticated reads |
| Push notifications not received | Check FCM token is stored in user document; verify `notification_service.dart` init |
| Videos won't play | Ensure `video_player` dependency is installed; check Storage URLs |

---

## 🎯 Usage Guide

### **First Time**

1. **Register** — Enter email, username, and password on the auth screen
2. **Grant Permissions** — Allow Bluetooth, Location, Camera, Storage, Notifications
3. **Onboarding** — Swipe through the 4-page walkthrough
4. **Toggle Mode** — Tap the FAB (briefcase ↔ party) to switch Formal/Casual
5. **Create Content** — Tap + tab to create a post or story
6. **Discover** — Go to Nearby tab to scan for users via BLE or GPS
7. **Connect** — Send connection requests from user profiles
8. **Chat** — Start conversations with connected users

### **Formal Mode Features**
- Professional profile (headline, skills, experience, education)
- Job board — browse and post jobs
- "Open to Work" and "Hiring" badges
- Blue-themed UI

### **Casual Mode Features**
- Fun/personal profile with casual avatar
- Video Reels tab — swipe through short videos
- Pink/gradient theme
- Relaxed content vibe

---

## 📜 License

This project is a prototype for educational/demonstration purposes.

---

**Built with Flutter + Firebase** | **Proxi 2.0** | **Last Updated: July 2025**
