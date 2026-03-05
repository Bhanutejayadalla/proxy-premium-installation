# PROXI PREMIUM — Proximity-Based Social Connectivity App

**An enhanced dual-mode social networking app that adapts to your life: Professional when you need it, Casual when you don't.**

![Version](https://img.shields.io/badge/version-3.0_Premium-blue)
![Firebase](https://img.shields.io/badge/backend-Firebase-orange)
![Cloudinary](https://img.shields.io/badge/media-Cloudinary-purple)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue)
![Platform](https://img.shields.io/badge/platform-Android-green)
![BLE](https://img.shields.io/badge/BLE-Offline_Mode-orange)

> **Note**: This is **Proxi Premium** — a separate, enhanced version of the original Proxi app. It uses its own Firebase project (`proxi-version2`) and Cloudinary account, and installs independently on your device with package ID `com.proxi.premium`.

---

## 🌟 Features

### 🔄 Dual-Mode System
- **Formal (Pro) Mode**: Professional networking, job board, LinkedIn-style profiles
- **Casual (Social) Mode**: Social posts, reels, stories, TikTok/Instagram-style feed
- **One-Tap Toggle**: Switch seamlessly between Professional and Social personas
- **Mode-Specific Content**: Posts, followers, following, connections, and chats are all separated by mode

### 📡 Proximity Discovery
- **BLE (Bluetooth) — Fully Offline**: Find people within ~30–50 meters using RSSI signal-strength filtering (threshold −80 dBm) — **no internet needed**
- **GPS Mode — Online**: Discover users within a 10 km radius (outdoor events, campus-wide)
- **BLE Advertising**: Your phone broadcasts your Proxi Premium ID via Bluetooth so others find you automatically
- **Animated Radar UI**: Visual representation of nearby users with animated ripple effects
- **Radius Info Banner**: On-screen indicator showing active discovery range for each mode
- **Local Profile Cache**: BLE-discovered users show cached profile data (name, avatar) even without internet

### 📝 Content Creation
- **Posts**: Text, images, mixed media (mode-specific)
- **Stories**: 24-hour expiring content with tap-to-pause viewer
- **Reels**: Short-form vertical videos (Casual mode)
- **Jobs**: Professional listings with skills/salary (Formal mode)
- **Delete Content**: Remove your own posts, reels, and stories at any time

### 💬 Real-Time Chat
- **Direct Messages (DM)**: One-on-one messaging with image sharing
- **Group Chat**: Create group conversations with 2+ connections
- **Mode-Specific Chat**: Pro chats stay in Pro, Social chats stay in Social
- **Delete/Clear DM Chat**: Delete entire conversation or clear all messages
- **Delete/Clear Group Chat**: Delete group or clear all messages; long-press to delete individual messages
- **Story Replies**: Tap to reply → opens DM

### 🔔 Notifications
- **Push Notifications (Free)**: Real-time Firestore listener triggers local push notifications for likes, comments, messages, and connection requests while the app is running
- **Cloud Functions (Optional)**: Server-side triggers when app is fully closed (requires Firebase Blaze plan)

### 🤝 Social Features
- **Connection System**: Send/accept/remove connections with reconnect support
- **Followers/Following Real-Time Sync**: Profile counters update instantly via Firestore listener
- **Tappable Stats**: Tap Followers, Following, or Connections on any profile to see the full list
- **Mode-Specific Social Graph**: Followers, following, and connections are separate for Pro and Social modes
- **Manage Followers**: Tap Followers/Following in Settings to remove followers or unfollow users
- **Remember Me Login**: Save email and password so credentials are pre-filled even after logout
- **Privacy Settings**: Control profile visibility (Public / Connections Only)

### 🏫 Campus Hub
All Campus Hub features are accessible from the **Hub** icon (grid icon) in the top header bar.

#### Profiles & Discovery
- **Advanced Student Search**: Filter by department, year, skills, and interests
- **Personalized Recommendations**: AI-style matching based on overlapping skills, interests, and department

#### Collaboration & Projects
- **Project Board**: Create projects, define required skills, recruit team members, accept/reject applicants
- **Study Groups**: Form study groups by subject with schedule & location; join/leave freely
- **Skill Exchange**: Two-way marketplace — list skills you can teach and skills you want to learn

#### Communities & Groups
- **Departmental & Interest Communities**: Create and join communities organized by All / Department / Interest tabs
- **Discussion Forums**: Reddit-style upvote/downvote ranking on community posts with comment threads

#### Campus Life & Engagement
- **Event Management**: Create workshops, hackathons, seminars, sports & cultural events with registration, capacity tracking, and type-specific icons
- **Sports Venue Booking**: Browse venues, book time slots, join other players' bookings
- **Sports Peer Matching**: Find peers who play the same sport on campus
- **Interactive Campus Map**: Google Maps integration with category-filtered markers (academic, food, sports, hostel, library, admin, transport)
- **Resource Sharing**: Share and discover notes, previous papers, useful links, books & video resources by subject with like/download tracking

---

## 📶 Offline vs Online Features

### ✅ Works Without Internet

| Feature | How it works offline |
|---|---|
| **BLE Scanning (Bluetooth radar)** | Bluetooth hardware scans for nearby devices — works fully offline with cached profiles |
| **BLE Advertising** | Broadcasts your Proxi Premium UID via Bluetooth so others can discover you |
| **Mode Toggle** (Formal ↔ Casual) | Stored in memory — switches instantly |
| **Browse already-loaded feed** | Posts/stories in the current session remain accessible |
| **Cached profile info** | Profile data loaded at login is available throughout the session |
| **Compose a post (draft)** | Type text and pick a photo — publish when back online |

### ❌ Requires Internet

| Feature | Why |
|---|---|
| **Login / Sign-Up** | Firebase Auth server call |
| **Feed / Stories / Reels** | Fetched from Firestore |
| **Publishing content** | Upload to Cloudinary + write to Firestore |
| **Chat (send/receive)** | Firestore stream |
| **GPS Nearby Discovery** | Location queries run on Firestore |
| **Connection Requests** | Written to / read from Firestore |
| **Campus Hub features** | All backed by Firestore collections |
| **Job Board** | Jobs stored in Firestore |
| **Profile Updates** | Firestore + Cloudinary upload |

---

## 🛠 Technology Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter 3.0+ (Dart) |
| **State Management** | Provider |
| **Database** | Firebase Firestore (NoSQL, real-time) |
| **Authentication** | Firebase Auth (email/password) |
| **Media Storage** | Cloudinary (images, videos, PDFs) |
| **Push Notifications** | Firebase Cloud Messaging + local notifications |
| **BLE** | flutter_blue_plus + native Kotlin BLE advertiser |
| **GPS/Maps** | geolocator + google_maps_flutter |
| **Video** | video_player, video_compress, camera |
| **IDE** | VS Code / Android Studio |
| **Deployment** | Firebase CLI, FlutterFire CLI |

---

## 🏗 Architecture

```
┌───────────────────────┐
│  Proxi Premium App    │
│  (Flutter · Android)  │
└──────────┬────────────┘
           │
     ┌─────┴─────────────┐
     │                    │
┌────▼─────┐       ┌─────▼──────┐
│ Firebase  │       │ Cloudinary │
│ Backend   │       │  (Media)   │
└────┬──────┘       └────────────┘
     │
┌────┴──────┬──────────────┐
│           │              │
│ Firestore │  Firebase    │  Firebase Cloud
│ (NoSQL)   │  Auth        │  Messaging
└───────────┘──────────────┘
```

---

## 📁 Project Structure

```
proxi-premium/
├── mobile_app/                 # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── app_state.dart      # Global state (mode, user, scans)
│   │   ├── constants.dart      # App colors & constants
│   │   ├── firebase_options.dart  # Firebase config (proxi-version2)
│   │   ├── models.dart         # Data models (User, Post, Story, Job)
│   │   ├── ble_service.dart    # BLE scanner (offline discovery)
│   │   ├── screens/            # UI screens
│   │   │   ├── auth_screen.dart
│   │   │   ├── home_shell.dart
│   │   │   ├── feed_screen.dart
│   │   │   ├── nearby_screen.dart      # BLE + GPS discovery
│   │   │   ├── chat_list_screen.dart
│   │   │   ├── campus_hub_screen.dart  # Hub for v3 features
│   │   │   ├── reels_screen.dart
│   │   │   ├── jobs_screen.dart
│   │   │   └── ... (20+ screens)
│   │   ├── services/
│   │   │   ├── cloudinary_service.dart  # Media uploads
│   │   │   ├── ble_advertiser_service.dart  # BLE advertising bridge
│   │   │   ├── user_cache_service.dart  # Offline profile cache
│   │   │   ├── notification_service.dart
│   │   │   └── auth_service.dart
│   │   └── widgets/            # Reusable components
│   ├── android/
│   │   └── app/
│   │       ├── build.gradle.kts   # Package: com.proxi.premium
│   │       ├── google-services.json
│   │       └── src/main/kotlin/com/proxi/premium/
│   │           └── MainActivity.kt  # Native BLE advertiser
│   └── pubspec.yaml
│
├── functions/                  # Firebase Cloud Functions (Node.js)
│   ├── index.js
│   └── package.json
│
├── vercel-deploy/              # Download page (hosted on Vercel)
│   ├── index.html
│   ├── vercel.json
│   └── proxi-premium.apk      # Release APK
│
├── firebase.json               # Firebase project config
├── firestore.rules             # Security rules
├── firestore.indexes.json      # Query indexes
├── installation.demo           # APK build & USB install guide
└── README.md                   # This file
```

---

## 🚀 Quick Start

### For Users
1. Download `proxi-premium.apk` from the [download page](https://proxi-premium.vercel.app) or [vercel-deploy/](vercel-deploy/)
2. Enable **Install from Unknown Sources** on your Android phone
3. Install and sign up with email/password
4. Toggle between Pro & Social modes and explore all features

### For Developers
```powershell
# Clone and install
git clone <repo-url>
cd mobile_app
flutter pub get

# Connect your Android phone (USB debugging enabled)
flutter devices
flutter run
```

> See [installation.demo](installation.demo) for detailed APK build and USB install instructions.
> See [installsteps.md](installsteps.md) for full Firebase & Cloudinary setup.

---

## 🔑 Configuration (For Forkers)

This repo uses its own Firebase project and Cloudinary account. To fork and run your own instance:

### Firebase Setup (Free)
1. Create a new project at [Firebase Console](https://console.firebase.google.com/)
2. Enable **Email/Password** authentication
3. Create **Firestore Database** in test mode
4. Register an Android app with package name `com.proxi.premium`
5. Download `google-services.json` → place in `mobile_app/android/app/`
6. Run `flutterfire configure` in `mobile_app/` to generate `firebase_options.dart`

### Cloudinary Setup (Free)
1. Create account at [cloudinary.com](https://cloudinary.com)
2. Create an **unsigned upload preset** in Settings → Upload
3. Update `mobile_app/lib/services/cloudinary_service.dart`:
   ```dart
   static const String cloudName = 'YOUR_CLOUD_NAME';
   static const String uploadPreset = 'YOUR_PRESET_NAME';
   ```

---

## 🎯 Version History

| Version | Date | Highlights |
|---|---|---|
| **3.0 Premium** | March 2026 | Campus Hub, rebranded as Proxi Premium, BLE fixes |
| **3.0** | March 2026 | Campus Hub (search, projects, communities, events, maps) |
| **2.1** | February 2026 | Offline BLE mode, user cache, BLE advertising |
| **2.0** | February 2026 | Dual-mode, chat, reels, stories, jobs, connections |

---

## 🤝 Contributing

1. Fork the repo
2. Complete Firebase & Cloudinary setup (see [Configuration](#-configuration-for-forkers))
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make changes and test: `flutter run`
5. Commit and open a Pull Request

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Bhanutejayadalla/proxi-premium/issues)
- **Email**: bhanuteja2024whatsapp@gmail.com

---

<p align="center">
  <strong>PROXI PREMIUM</strong> v3.0 · Made with ❤️ by <a href="https://github.com/Bhanutejayadalla">Bhanu Teja Yadalla</a>
</p>
