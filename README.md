# PROXI PREMIUM — Proximity-Based Social Connectivity App

**An enhanced dual-mode social networking app that adapts to your life: Professional when you need it, Casual when you don't.**

![Version](https://img.shields.io/badge/version-3.2.0_Premium-blue)
![Firebase](https://img.shields.io/badge/backend-Firebase-orange)
![Cloudinary](https://img.shields.io/badge/media-Cloudinary-purple)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue)
![Platform](https://img.shields.io/badge/platform-Android-green)
![BLE](https://img.shields.io/badge/BLE-Offline_Mode-orange)
![Mesh](https://img.shields.io/badge/Mesh_Chat-Offline_P2P-blueviolet)

> **Note**: This is **Proxi Premium** — a separate, enhanced version of the original Proxi app. It uses its own Firebase project (`proxi-version2`) and Cloudinary account, and installs independently on your device with package ID `com.proxi.premium`.

---

## 🌟 Features

### 🔄 Dual-Mode System
- **Formal (Pro) Mode**: Professional networking, job board, LinkedIn-style profiles
- **Casual (Social) Mode**: Social posts, reels, stories, TikTok/Instagram-style feed
- **One-Tap Toggle**: Switch seamlessly between Professional and Social personas
- **Mode-Specific Content**: Posts, followers, following, connections, and chats are all separated by mode

### 📡 Proximity Discovery
- **BLE (Bluetooth) — Fully Offline**: Find people within ~30–50 meters using RSSI signal-strength filtering (threshold −90 dBm) — **no internet needed**
- **GPS Mode — Online**: Discover users within a 10 km radius (outdoor events, campus-wide)
- **BLE Advertising**: Your phone broadcasts your Proxi Premium ID via Bluetooth so others find you automatically
- **Animated Radar UI**: Visual representation of nearby users with animated ripple effects
- **Radius Info Banner**: On-screen indicator showing active discovery range for each mode
- **Local Profile Cache**: BLE-discovered users show cached profile data (name, avatar) even without internet

### 📝 Content Creation
- **Posts**: Text, images, mixed media (mode-specific)
  - ✨ **NEW**: Add location tags to posts
  - ✨ **NEW**: Add music/songs from music library
  - ✨ **NEW**: Edit posts (description, location, music, media) WITHOUT deleting
  - ✨ **NEW**: "Edited" label shows on modified posts with timestamps
- **Stories**: 24-hour expiring content with tap-to-pause viewer
  - ✨ **NEW**: Add background music to stories
  - ✨ **NEW**: Full audio player with play/pause in story viewer
  - ✨ **NEW**: Auto-delete after 24 hours
- **Reels**: Short-form vertical videos (Casual mode)
- **Jobs**: Professional listings with skills/salary (Formal mode)
- **Delete Content**: Remove your own posts, reels, and stories at any time

### 🎵 Music Integration (NEW in v3.2)
- **Song Library**: Browse and select from predefined songs
- **Post Music**: Add music to regular posts
- **Story Music**: Add background music to 24-hour stories
- **Audio Player**: Play/pause with progress bar and seek controls
- **Search**: Filter songs by name or artist
- **Music Selector Widget**: Easy-to-use dialog for choosing songs

### 💬 Real-Time Chat
- **Direct Messages (DM)**: One-on-one messaging with image sharing
- **Group Chat**: Create group conversations with 2+ connections
- **Mode-Specific Chat**: Pro chats stay in Pro, Social chats stay in Social
- **Delete/Clear DM Chat**: Delete entire conversation or clear all messages
- **Delete/Clear Group Chat**: Delete group or clear all messages; long-press to delete individual messages
- **Story Replies**: Tap to reply → opens DM

### 🔵 Mesh Chat (New in v3.1 — Fully Offline)
- **Zero Internet Required**: Send and receive messages using only Bluetooth — works in tunnels, rural areas, or flight mode
- **Automatic Peer Discovery**: Tap the Bluetooth icon in any chat → toggle Mesh ON → nearby devices appear within seconds
- **Broadcast Chat**: One global Mesh broadcast channel for all nearby devices
- **Per-Contact Mesh Chat**: Open a contact's chat → tap the Bluetooth (🔵) icon for a private offline channel to that specific person
- **Group Mesh Chat**: Open any group → tap the Bluetooth icon → all group members in BLE range connect automatically
- **Multi-Hop Relay**: If the destination is not directly reachable, intermediate devices relay the message up to **5 hops**
- **AES-256 Encryption**: Every mesh message is end-to-end encrypted before transmission — plaintext never leaves the device unencrypted
- **Offline Storage**: All mesh messages stored locally in SQLite — survive app restarts
- **Cloud Sync**: When internet returns, unsynced messages are automatically uploaded to Firebase Firestore for cross-device access
- **Delivery Status**: Visual indicators — 🕐 Pending · ↔ Relayed · ✓ Delivered · ☁ Synced to cloud

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
- **Interactive Campus Map**: OpenStreetMap-based map with search, OSRM walking routes, distance modes, and category-filtered markers
  - **Nearby Connections on Map**: See all connections within 10 km as green markers with profile pictures, department, skills, and quick access to profile/chat
  - **Long-Press to Add Marker**: Long-press anywhere on the map to create a custom marker (Study Spot, Event Location, Cafe, Important Place, Custom) — coordinates captured automatically, no manual lat/lng input
  - **OSRM Walking Routes**: Road-based walking routes with distance and estimated walking time between any two points
  - **Distance Modes**: "My Location → Place" and "Place → Place" routing with polyline overlay
  - **My Location Button**: One-tap GPS re-center with automatic location sharing to database
  - **Privacy Settings**: Control location sharing — share with connections only, or hide from map entirely
  - **Marker Management**: View, filter, and delete your custom markers; route to any marker
  - **Edge Case Handling**: GPS permission denied banner with retry, no connections nearby states, loading indicators
- **Resource Sharing**: Share and discover notes, previous papers, useful links, books & video resources by subject with like/download tracking

---

## 📶 Offline vs Online Features

### ✅ Works Without Internet

| Feature | How it works offline |
|---|---|
| **BLE Scanning (Bluetooth radar)** | Bluetooth hardware scans for nearby devices — works fully offline with cached profiles |
| **BLE Advertising** | Broadcasts your Proxi Premium UID via Bluetooth so others can discover you |
| **Mesh Chat (send & receive)** | Full messaging via Wi-Fi Direct (WifiP2pManager) + TCP sockets — BLE discovers peers, Wi-Fi Direct connects them, raw TCP carries messages |
| **Mesh multi-hop relay** | Intermediate devices forward packets to out-of-range destinations (up to 5 hops) |
| **Mesh SQLite storage** | All mesh messages persisted locally — readable offline after app restart |
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
| **Chat (send/receive)** | Firestore stream (use Mesh Chat for offline) |
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
| **BLE Proximity Discovery** | flutter_blue_plus + native Kotlin BLE advertiser |
| **Mesh Chat Transport** | Native Android `WifiP2pManager` (Wi-Fi Direct) + raw TCP sockets on port 8888 — implemented in `WifiDirectPlugin.kt` via Flutter MethodChannel/EventChannel |
| **Mesh Encryption** | encrypt 5.0.3 — AES-256-CBC, SHA-256 key derivation (crypto 3.0.3) per conversation pair |
| **Mesh Local Storage** | sqflite 2.3.0 — SQLite database (mesh_messages.db) |
| **Mesh Cloud Sync** | connectivity_plus 6.0.3 + Firestore (`mesh_messages` collection — stores encrypted payload, never plaintext) |
| **GPS/Maps** | geolocator + flutter_map (OpenStreetMap) + OSRM routing |
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

## 🔵 Mesh Network — Deep Dive

### What is it?
The Mesh Chat system lets two or more Proxi devices communicate **entirely without mobile data** using Bluetooth Low Energy (for peer discovery) and **Wi-Fi Direct** (for data transfer). The implementation uses Android's native `WifiP2pManager` API — no third-party networking library is involved.

---

### Architecture: BLE Discovery → Wi-Fi Direct → TCP Sockets

```
┌─────────────────────────────────────────────────────────────┐
│                     Proxi Mesh Stack                        │
├─────────────────────────────────────────────────────────────┤
│  Flutter (Dart)                                             │
│  ├── BleService (flutter_blue_plus)   ← BLE scanning        │
│  ├── MeshService                      ← orchestrator        │
│  │    └── WifiDirectService           ← Dart channel wrapper│
│  └── MeshEncryptionService            ← AES-256 + SHA-256   │
├─────────────────────────────────────────────────────────────┤
│  Platform Channel (MethodChannel + EventChannel)            │
│      com.proxi.wifi_direct / com.proxi.wifi_direct/events   │
├─────────────────────────────────────────────────────────────┤
│  Native Kotlin  (WifiDirectPlugin.kt)                       │
│  ├── WifiP2pManager.discoverPeers()   ← Wi-Fi Direct scan   │
│  ├── WifiP2pManager.connect()         ← P2P group formation │
│  ├── ServerSocket(8888)               ← Group Owner side     │
│  └── Socket → InetSocketAddress(8888) ← Non-GO side         │
└─────────────────────────────────────────────────────────────┘
```

---

### Full Connection Lifecycle

```
Device A (Initiator)                        Device B (Peer)
     │                                          │
     │── BLE advertisement (uid, username) ────►│  (flutter_blue_plus)
     │◄── BLE advertisement ────────────────────│
     │                                          │
     │  [MeshService.onBleDeviceDiscovered()]   │
     │── WifiP2pManager.discoverPeers() ────────►│
     │◄── WIFI_P2P_PEERS_CHANGED_ACTION ─────────│
     │                                          │
     │── WifiP2pManager.connect(deviceAddress) ─►│
     │◄═══ WIFI_P2P_CONNECTION_CHANGED_ACTION ═══│  (group formed)
     │     ↳ GO side    → startSocketServer()   │
     │     ↳ Non-GO side→ startSocketClient()   │
     │                                          │
     │◄══ TCP Socket connection on port 8888 ════│
     │── JSON handshake {type:"handshake",uid} ──►│
     │◄── JSON handshake {type:"handshake",uid} ──│
     │                                          │
     │══ MeshWirePacket (JSON, AES-256 payload) ═►│  (message)
```

---

### Message Packet Format (`MeshWirePacket`)

Every message is serialized to newline-delimited JSON over the TCP socket:

```json
{
  "mid": "uuid-v4",
  "sid": "firebase_uid_of_sender",
  "rid": "firebase_uid_of_recipient",
  "pay": "<iv_base64>.<ciphertext_base64>",
  "ts":  1741420800000,
  "hop": 0
}
```

- `pay` is the AES-256-CBC ciphertext of the original message text
- `hop` increments by 1 at each relay node; packets are dropped when `hop ≥ 5`
- A handshake JSON (`type:"handshake", uid:…`) is exchanged first to map Wi-Fi Direct MAC addresses to Firebase UIDs

---

### Encryption Layer (`MeshEncryptionService`)

| Property | Value |
|---|---|
| **Algorithm** | AES-256-CBC |
| **Key derivation** | Real SHA-256 (`package:crypto`) of `sorted(senderUid + receiverUid) + ":proxi-mesh-v1"` |
| **IV** | 16 cryptographically random bytes per message, prepended as `<iv_b64>.<cipher_b64>` |
| **Library** | `encrypt: 5.0.3` + `crypto: 3.0.3` |
| **Cloud storage** | Only `encrypted_payload` is synced to Firestore — plaintext is never uploaded |

**Encrypt flow:**
```
plaintext ──► AES-256-CBC(key=SHA256(sortedUids+salt), iv=random16) ──► "<iv_b64>.<cipher_b64>"
```

**Decrypt flow:**
```
"<iv_b64>.<cipher_b64>" ──► split ──► AES-256-CBC-decrypt(key=SHA256(sortedUids+salt)) ──► plaintext
```

---

### Multi-Hop Relay Logic

When device A wants to reach device C but they are out of Wi-Fi Direct range, device B (in range of both) acts as a relay:

```
 A ──WiFi Direct──► B ──WiFi Direct──► C
                  (relay)
```

1. A sends packet to B (`hop = 0`)
2. B sees `receiverId ≠ myUid` — increments `hop` to 1, forwards to all peers except the sender
3. C decrypts and delivers the message; `hop ≥ 5` → packet dropped
4. If B cannot forward, it stores the relay-packet in SQLite and delivers when a new peer connects

**Deduplication:** A `Set<String>` + FIFO `Queue<String>` (capped at 500 entries) prevents each device from processing the same packet more than once.

---

### Local Persistence Layer (`MeshDbService` · SQLite)

**Database:** `mesh_messages.db`  
**Table:** `mesh_messages`

| Column | Type | Description |
|---|---|---|
| `message_id` | TEXT PK | UUID v4, globally unique |
| `sender_id` | TEXT | Firebase UID of sender |
| `receiver_id` | TEXT | Firebase UID of recipient |
| `message_text` | TEXT | Decrypted plaintext (empty for relay-only records) |
| `timestamp` | INTEGER | Unix epoch milliseconds |
| `delivery_status` | TEXT | `pending` / `relayed` / `delivered` / `synced` |
| `hop_count` | INTEGER | How many relay nodes have forwarded this packet |
| `encrypted_payload` | TEXT | Wire-safe ciphertext (`<iv>.<cipher>`) |

**Indexes:**  
- `idx_conversation (sender_id, receiver_id)` — fast chatlog queries  
- `idx_status (delivery_status)` — fast pending/unsynced queries

---

### Cloud Sync Layer (`MeshSyncService`)

Handled by `connectivity_plus` watching network state changes:

```
Offline  ──► [messages stored in SQLite with status=pending/delivered] ──► Online
                                                                              │
                                              ┌───────────────────────────────┘
                                              ▼
                              _uploadUnsynced() — batch Firestore set()
                                    to mesh_messages/{messageId}
                                    (stores encrypted_payload only, never plaintext)
                              _downloadMissing() — query Firestore
                                    where receiver_id == myUid (limit 100)
```

**Firestore collection:** `mesh_messages/{messageId}`  
**Security rules:** Only sender can create; only sender or receiver can read; nobody can update/delete

---

### Required Android Permissions

| Permission | API Level | Purpose |
|---|---|---|
| `BLUETOOTH_SCAN` | 31+ | BLE scanning |
| `BLUETOOTH_ADVERTISE` | 31+ | BLE advertising so other devices can find us |
| `BLUETOOTH_CONNECT` | 31+ | GATT connections |
| `BLUETOOTH` + `BLUETOOTH_ADMIN` | ≤ 30 | Legacy BLE APIs |
| `ACCESS_FINE_LOCATION` | all | Required for BLE on Android ≤ 11 |
| `ACCESS_WIFI_STATE` + `CHANGE_WIFI_STATE` | all | Wi-Fi Direct peer discovery and group management |
| `CHANGE_NETWORK_STATE` | all | Wi-Fi Direct group removal |
| `NEARBY_WIFI_DEVICES` | 33+ | Android 13+ Wi-Fi Direct scanning |

---

### Source Files

| File | Role |
|---|---|
| `android/…/WifiDirectPlugin.kt` | Native Wi-Fi Direct engine — `WifiP2pManager`, `BroadcastReceiver`, `ServerSocket`/`Socket`, `ConcurrentHashMap` socket streams |
| `lib/services/wifi_direct_service.dart` | Flutter Dart wrapper over platform channel `com.proxi.wifi_direct` |
| `lib/services/mesh_service.dart` | Core orchestrator — BLE→WiFi trigger, handshake protocol, send/receive/relay, FIFO dedup; owns BLE scan lifecycle (starts on `start()`, stops on `stop()`) |
| `lib/services/mesh_db_service.dart` | SQLite singleton — full CRUD for offline message store |
| `lib/services/mesh_encryption_service.dart` | AES-256-CBC encrypt/decrypt + real SHA-256 key derivation + `MeshWirePacket` serialization |
| `lib/services/mesh_sync_service.dart` | Connectivity watcher — uploads encrypted payload, downloads missed messages on reconnect |
| `lib/screens/mesh_chat_screen.dart` | Full chat UI — Mesh toggle, BLE/WiFi/socket/peer count banner, delivery status icons |
| `lib/models.dart` | `MeshMessage` model + `MeshDeliveryStatus` enum |
| `lib/app_state.dart` | Wires `MeshService` and `MeshSyncService` into the global provider; starts/stops with auth lifecycle; NearbyScreen BLE scan coexists safely with mesh BLE scan |

---

### How to Test on Two Physical Devices

> **Wi-Fi Direct does NOT work on Android emulators. Two physical Android phones are required.**

1. Install the APK on **both** devices
2. Sign in with different accounts on each
3. Enable **Bluetooth**, **Wi-Fi**, and **Location** on both; place them within **1–2 metres** of each other
4. On Device A: open any chat → tap the **🔵 Bluetooth icon** to toggle Mesh ON
5. The status banner progresses: `Scanning… → BLE found N → WiFi connecting… → Connected (N socket)`
6. Do the same on Device B
7. Send a message — it arrives on Device B **instantly with no internet**
8. Delivery status: **🕐 Pending → ↔ Relayed → ✓ Delivered → ☁ Synced**
9. Check `logcat` for `[MeshService]` and `WifiDirectPlugin` tags to trace the pipeline

> **Tip:** Both devices must have Bluetooth ON, Wi-Fi ON, and Location permission granted. Multiple devices can connect simultaneously — Multi-peer is fully supported.

---

## �📁 Project Structure

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
│   │   │   ├── cloudinary_service.dart      # Media uploads
│   │   │   ├── ble_advertiser_service.dart  # Legacy BLE advertising bridge
│   │   │   ├── mesh_service.dart            # Wi-Fi Direct + BLE orchestrator (mesh)
│   │   │   ├── mesh_db_service.dart         # SQLite offline message store
│   │   │   ├── mesh_encryption_service.dart # AES-256-CBC + MeshWirePacket
│   │   │   ├── mesh_sync_service.dart       # Firebase sync on reconnect
│   │   │   ├── user_cache_service.dart      # Offline profile cache
│   │   │   ├── notification_service.dart
│   │   │   └── auth_service.dart
│   │   └── widgets/            # Reusable components
│   ├── android/
│   │   └── app/
│   │       ├── build.gradle.kts   # Package: com.proxi.premium
│   │       ├── google-services.json
│   │       └── src/main/kotlin/com/proxi/premium/
│   │           ├── MainActivity.kt      # Native BLE advertiser (runOnUiThread wrappers)
│   │           └── WifiDirectPlugin.kt  # Native Wi-Fi Direct engine (WifiP2pManager + TCP)
│   └── pubspec.yaml                # Deps incl. sqflite, encrypt, crypto, flutter_blue_plus
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
| **3.0.1 Premium** | July 2025 | Fixed Skill Exchange, Community Posts, Events filtering, Resource filtering (missing Firestore indexes); full feature audit |
| **3.1.1 Premium** | March 2026 | Fix: BLE scan lifecycle — NearbyScreen no longer kills mesh BLE scan; mesh properly cleans up BLE on stop; removed duplicate BLE→mesh subscription that caused double-processing |
| **3.1 Premium** | March 2026 | Mesh Chat (offline P2P via native WifiP2pManager / Wi-Fi Direct + TCP sockets, AES-256-CBC + SHA-256 encryption, SQLite store, multi-hop relay, Firebase sync — encrypted payload only) · Improved typing bar UX |
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
  <strong>PROXI PREMIUM</strong> v3.1 · Mesh Chat · Made with ❤️ by <a href="https://github.com/Bhanutejayadalla">Bhanu Teja Yadalla</a>
</p>
