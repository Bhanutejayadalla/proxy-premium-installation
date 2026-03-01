# PROXI — Proximity-Based Social Connectivity App

**A dual-mode social networking app that adapts to your life: Professional when you need it, Casual when you don't.**

![Version](https://img.shields.io/badge/version-2.0-blue)
![Firebase](https://img.shields.io/badge/backend-Firebase-orange)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue)
![Platform](https://img.shields.io/badge/platform-Android-green)

---

## 🌟 Key Features

### Dual-Mode System
- **Formal Mode**: Professional networking, job board, LinkedIn-style profiles
- **Casual Mode**: Social posts, reels, stories, TikTok/Instagram-style feed
- **One-Tap Toggle**: Switch seamlessly between Professional and Social personas

### Proximity Discovery
- **BLE (Bluetooth)**: Find people within ~30-50 meters using RSSI signal-strength filtering (threshold -80 dBm)
- **GPS Mode**: Discover users within a 10 km radius (outdoor events, campus-wide)
- **Animated Radar UI**: Visual representation of nearby users
- **Radius Info Banner**: On-screen indicator showing active discovery range for each mode

### Content Creation
- **Posts**: Text, images, mixed media (mode-specific)
- **Stories**: 24-hour expiring content with tap-to-pause viewer
- **Reels**: Short-form vertical videos (Casual mode)
- **Jobs**: Professional listings with skills/salary (Formal mode)

### Real-Time Features
- **Live Chat**: Direct messages with image sharing
- **Group Chat**: Create group conversations with 2+ connections
- **Notifications**: Push alerts for likes, comments, connections
- **Connection System**: Send/accept/remove connections with reconnect support
- **Followers/Following Real-Time Sync**: Profile counters update instantly via Firestore listener
- **Tappable Stats**: Tap Followers, Following, or Connections on any profile to see the full list of names
- **Mode-Specific Social Graph**: Followers, following, and connections are separate for Pro and Social modes
- **Manage Followers**: Tap Followers/Following in Settings to remove followers or unfollow users
- **Remember Me Login**: Save email and password so credentials are pre-filled even after logout
- **Delete Content**: Remove your own posts, reels, and stories
- **Delete/Clear DM Chat**: Delete entire conversation or clear all messages from a DM
- **Delete/Clear Group Chat**: Delete group or clear all messages; long-press to delete individual messages
- **Mode-Specific Chat**: DM and group conversations are separated by mode — Pro chats stay in Pro, Social chats stay in Social
- **Story Replies**: Tap to reply → opens DM
- **Push Notifications (Free)**: Real-time Firestore listener triggers local push notifications for likes, comments, messages, and connection requests while the app is running

---

## 📋 Table of Contents

1. [Quick Start](#-quick-start)
2. [How to Connect Your Phone](#-how-to-connect-your-phone)
3. [Setup Instructions](#-setup-instructions)
4. [How to Send & Accept Connections](#-how-to-send--accept-connections)
5. [Offline Features](#-offline-features)
6. [Architecture](#-architecture)
7. [Technology Stack](#-technology-stack)
8. [Project Structure](#-project-structure)
9. [Contributing](#-contributing)
10. [License](#-license)

---

## 🚀 Quick Start

### For Users (Testing the App)

1. **Get the APK**: Download the latest release from [Releases](https://github.com/Bhanutejayadalla/proxi/releases)
2. **Install**: Enable "Install from Unknown Sources" in your Android settings
3. **Sign Up**: Create an account with email/password
4. **Explore**: Toggle between Formal/Casual modes and try all features

### For Developers (Running from Source)

**Prerequisites**: Windows PC with Flutter 3.0+, Node.js, and Android SDK installed

```powershell
# 1. Clone the repository
git clone https://github.com/Bhanutejayadalla/proxy-sharing-others.git
cd proxy-sharing-others

# 2. Install dependencies
cd mobile_app
flutter pub get

# 3. Connect your Android phone (USB debugging enabled)
flutter devices

# 4. Run the app
flutter run
```

> ⚠️ **The app will NOT work until you complete the Firebase & Cloudinary setup below.**

📘 **Full setup guide**: See [installsteps.md](installsteps.md) for detailed instructions

---

## 🔑 Required Setup (For Forkers / New Developers)

This repo does **not** include API keys or Firebase config files. You must create your own (free) accounts and generate config files before the app will compile and run.

### Step 1 — Firebase Setup (Free)

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project
2. **Enable Authentication**: Firebase Console → Authentication → Sign-in method → Enable **Email/Password**
3. **Create Firestore Database**: Firebase Console → Firestore Database → Create database → Start in **test mode**
4. **Register an Android app**:
   - Package name: `com.example.mobile_app` (or your own)
   - Download `google-services.json` → place it in `mobile_app/android/app/`
5. **Generate Firebase Options for Flutter**:
   ```powershell
   # Install FlutterFire CLI (one-time)
   dart pub global activate flutterfire_cli

   # Run in the mobile_app/ directory
   cd mobile_app
   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
   ```
   This generates `lib/firebase_options.dart` automatically.
6. **Deploy Firestore rules & indexes**:
   ```powershell
   # From the project root
   firebase login
   firebase use YOUR_FIREBASE_PROJECT_ID
   firebase deploy --only firestore:rules
   firebase deploy --only firestore:indexes
   ```

### Step 2 — Cloudinary Setup (Free)

Cloudinary is used for all media uploads (profile pictures, post images, story media, reel videos).

1. Create a **free** account at [cloudinary.com](https://cloudinary.com)
2. From your **Dashboard**, copy your **Cloud Name** (e.g. `dxyz1234abc`)
3. Go to **Settings → Upload** → scroll to **Upload presets**
4. Click **Add upload preset**:
   - **Signing Mode**: Select **Unsigned**
   - **Preset name**: Give it a name (e.g. `proxi_unsigned`)
   - Click **Save**
5. Open `mobile_app/lib/services/cloudinary_service.dart` and fill in your values:
   ```dart
   static const String cloudName = 'YOUR_CLOUD_NAME';       // from Dashboard
   static const String uploadPreset = 'YOUR_UPLOAD_PRESET'; // preset name you created
   ```

### Step 3 — (Optional) Firebase Cloud Functions

Push notifications via Cloud Functions require the **Firebase Blaze plan** (pay-as-you-go, but has a generous free tier). The app already works with free local push notifications without this.

```powershell
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Summary of Files You Need to Create

| File | How to Get It |
|---|---|
| `mobile_app/android/app/google-services.json` | Download from Firebase Console after registering Android app |
| `mobile_app/lib/firebase_options.dart` | Auto-generated by `flutterfire configure` |
| `mobile_app/firebase.json` | Auto-generated by `flutterfire configure` |
| Cloudinary credentials in `cloudinary_service.dart` | Sign up at cloudinary.com → Dashboard + Upload Settings |

---

## � How to Connect Your Phone

This section covers two methods: **USB** (most reliable) and **Wireless** (Android 11+).

---

### Method 1 — USB Debugging (Recommended)

#### Step 1 — Enable Developer Mode on Your Android Phone

1. Open **Settings** on your phone
2. Scroll down → tap **About phone**
3. Find **Build number** (may be under *Software information*)
4. **Tap Build number 7 times** in quick succession
5. You'll see: *"You are now a developer!"*
6. Go back to **Settings** → scroll down → tap **Developer options**

#### Step 2 — Enable USB Debugging

1. Inside **Developer options**, find **USB debugging**
2. Toggle it **ON**
3. Tap **OK** on the confirmation popup

#### Step 3 — Connect via USB Cable

1. Plug your phone into your laptop using a **data-capable USB cable**  
   ⚠️ *Some cables are charge-only — if detection fails, try a different cable*
2. On your phone, a popup appears: **"Allow USB debugging?"**
3. Check **"Always allow from this computer"** then tap **Allow**
4. On your phone, when asked **"Use USB for"**, select **File Transfer (MTP)**

#### Step 4 — Verify Connection

```powershell
# In your project folder:
adb devices
```

You should see something like:
```
List of devices attached
RF8N20XXXXX   device
```

If it shows `unauthorized` — look at your phone for the debugging popup and tap Allow.

#### Step 5 — Run the App on Your Phone

```powershell
cd D:\Proxi_Social_Connectivity\mobile_app
flutter devices          # verify your phone appears
flutter run              # builds and installs app on phone
```

The first build takes **3-5 minutes**. Subsequent runs are ~15 seconds (hot reload).

---

### Method 2 — Wireless Debugging (Android 11+)

No USB cable required after initial setup.

#### On Your Phone
1. Go to **Settings** → **Developer options** → **Wireless debugging**
2. Toggle **Wireless debugging ON**
3. Tap **Pair device with pairing code**
4. Note the **IP address:port** and **pairing code** shown

#### On Your Laptop (same Wi-Fi network)

```powershell
# Step 1: Pair once using the code from your phone screen
adb pair <IP_ADDRESS>:<PAIRING_PORT>
# Enter the 6-digit pairing code when prompted

# Step 2: Connect (use the main port, not the pairing port)
adb connect <IP_ADDRESS>:<PORT>

# Step 3: Verify
adb devices

# Step 4: Run app
cd mobile_app
flutter run
```

**Example:**
```powershell
adb pair 192.168.1.5:37549   # pairing code: 123456
adb connect 192.168.1.5:40123
```

---

### Troubleshooting Connection Issues

| Problem | Solution |
|---|---|
| `No devices found` | Check USB cable (use data cable, not charge-only) |
| `unauthorized` | Accept the USB debugging popup on your phone |
| Device shows then disappears | Disable battery optimization for ADB |
| `adb: command not found` | Add Android SDK `platform-tools` to your PATH |
| Wireless debugging not visible | Requires Android 11 or higher |
| App installs but crashes | Run `flutter clean` then `flutter run` again |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Uninstall old version from phone first |

```powershell
# Quick fix: reset ADB connection
adb kill-server
adb start-server
adb devices
```

---

## 🛠 Setup Instructions

> **New here?** Follow the steps in [How to Connect Your Phone](#-how-to-connect-your-phone) first.

### Complete Guide for New Developers

Follow the comprehensive guide in **[installsteps.md](installsteps.md)** which covers:

#### PART 1: Laptop Setup
- Installing Flutter, Node.js, Android SDK
- Setting up Firebase project (free tier)
- Configuring Cloudinary for media uploads
- Running the app locally

#### PART 2: Phone Connection
- Enabling Developer Mode on Android
- USB debugging setup
- Connecting and testing on physical device
- Troubleshooting connection issues

#### PART 3: GitHub Integration
- Setting up Git credentials
- Pushing code to repository
- Managing branches and pull requests

**Estimated Setup Time**: 20-30 minutes (first-time)

---

## 🤝 How to Send & Accept Connections

Connections are a **Formal (Pro) mode** feature — professional networking between users you discover nearby.

---

### Step 1 — Switch to Pro Mode

Tap the **PRO / SOCIAL** chip in the top header of the app to switch to **PRO** mode.  
Connections are mode-specific: Pro connections = professional network, Social connections = casual network.

---

### Step 2 — Discover a Nearby User

1. Go to the **Nearby** tab (radar icon in the bottom nav)
2. Tap **Scan** to start BLE or GPS discovery
3. Nearby users appear as cards on screen

---

### Step 3 — Send a Connection Request

1. On a nearby user's card, tap **Connect**
2. A confirmation snackbar appears: *"Connection request sent!"*
3. The request is stored in Firestore with status `pending`

> You can also send a request from a user's **profile page** — tap their avatar in the Nearby list to open their profile, then tap **Connect**.

---

### Step 4 — Accepting a Connection Request (Recipient)

When someone sends you a request, you have **two ways** to accept it:

#### Option A — via Notifications (Bell Icon)
1. Tap the 🔔 **bell icon** in the top-right header
2. You'll see a notification: **"[Username] sent you a connection request"**
3. Tapping the notification takes you to the **Connection Requests** screen

#### Option B — via Settings
1. Go to the **Profile** tab (last tab in the bottom nav)
2. Tap the **⚙ Settings** gear icon (top-right of profile screen)
3. Scroll down to **"Connection Requests"**
4. Tap it to open the full requests list

#### On the Connection Requests screen:
| What you see | What to do |
|---|---|
| Requester's name, avatar, and headline | Review who is requesting |
| Mode label (Pro / Social) | Know which mode the request is for |
| Optional message from requester | Read their note (if they added one) |
| **Accept** button | Tap to accept — you're now connected |
| **Decline** button | Tap to decline — request is removed |

After accepting, a *"Connection accepted"* confirmation appears at the bottom of the screen.

---

### Step 5 — Viewing Your Connections

Your accepted connections are visible in **Settings → Connection Requests** (shows pending only) and will be used for feed filtering and profile visibility in future updates.

---

### Connection Privacy

You can control who sees your profile in **Settings → Privacy**:

| Setting | Effect |
|---|---|
| **Public** | Anyone can view your profile |
| **Connections Only** | Only accepted connections see your full profile |

---

## 📶 Offline Features

A breakdown of exactly what works with and without an internet connection.

---

### ✅ Works Without Internet

These features run entirely on-device with no server calls:

| Feature | How it works offline |
|---|---|
| **Mode Toggle** (Formal ↔ Casual) | State stored in memory — switches instantly with no network calls |
| **BLE Scanning (Bluetooth radar)** | Bluetooth hardware scans for nearby devices — the radar animation and device detection work fully offline |
| **Browse already-loaded feed** | Posts loaded in the current session stay in Provider state — you can scroll through them without reconnecting |
| **Browse already-loaded stories** | Same as feed — stories visible in current session remain accessible |
| **Cached profile info** | Your own profile data (name, avatar, bio) loaded at login is available throughout the session |
| **Compose a post (draft)** | You can type text and pick a photo — the Share button will fail without internet, but drafting works |

---

### ❌ Requires Internet

These features make Firestore / Firebase / Cloudinary calls and will fail or show empty data without a connection:

| Feature | Why it needs internet |
|---|---|
| **Login / Sign-Up** | Firebase Auth requires a server call to verify identity |
| **Loading the Feed** | Posts are fetched via Firestore real-time stream |
| **Loading Stories** | Stories fetched from Firestore with 24h expiry check |
| **Loading Reels** | Reel video metadata + URLs fetched from Firestore |
| **Liking / Commenting** | Writes to Firestore `posts` or `reels` collection |
| **Publishing a Post/Story/Reel** | Image uploaded to Cloudinary, metadata written to Firestore |
| **Chat (send/receive)** | Firestore stream subscription for real-time messages |
| **Push Notifications** | Firebase Cloud Messaging requires internet |
| **GPS Nearby Discovery** | Device location is obtained offline, but user matching queries Firestore |
| **BLE Nearby — Show Profiles** | BLE finds devices locally, but profile data (name, avatar) is fetched from Firestore |
| **Job Board** | Jobs loaded from Firestore |
| **Connection Requests** | Written to Firestore |
| **Accepting Connection Requests** | Writes to Firestore — the recipient **cannot** accept a request offline |
| **Profile Updates** | Written to Firestore + avatar uploaded to Cloudinary |

> **Can the other person accept a connection request offline?**
>
> **No.** When you send a connection request, the data is written to Firestore.
> The recipient must have an active internet connection to:
> 1. **See** the incoming request (it is loaded from Firestore into Notifications and Connection Requests screens).
> 2. **Accept or Decline** the request (tapping Accept/Decline writes back to Firestore to update the connection status).
>
> If the recipient is offline, they will see and be able to act on the request the next time they open the app with internet.

---

### 💡 Tips for Low Connectivity

- **Open the app on Wi-Fi first** — data loads into Provider state and stays available during the session even if you step into a weak signal area
- **BLE proximity works best offline** — if you just need to find who is physically near you, Bluetooth scanning works with airplane mode + Bluetooth enabled
- **Drafts**: You can compose post text and pick images while offline; tap Share once you regain connectivity

---

## 🏗 Architecture

### High-Level Overview

```
┌─────────────────┐
│  Flutter App    │
│  (Mobile)       │
└────────┬────────┘
         │
         ├──────────────────┐
         │                  │
    ┌────▼────┐      ┌─────▼──────┐
    │Firebase │      │ Cloudinary │
    │Backend  │      │   (Media)  │
    └─────────┘      └────────────┘
         │
    ┌────┴─────────────────┐
    │                      │
┌───▼────┐          ┌──────▼──────┐
│Firestore│         │   Firebase  │
│(NoSQL)  │         │    Auth     │
└─────────┘         └─────────────┘
```

### Key Components

**Frontend (Flutter)**
- `lib/main.dart`: Entry point, Firebase initialization
- `lib/app_state.dart`: Global state management (mode toggle, user data)
- `lib/screens/`: UI screens (Home, Profile, Chat, Nearby, etc.)
- `lib/services/`: Business logic (Firestore operations, Cloudinary upload)
- `lib/widgets/`: Reusable components (ModeSwitch, PostCard)

**Backend (Firebase)**
- **Firestore**: NoSQL database (users, posts, stories, chats, group_chats, notifications)
- **Authentication**: Email/password (ready for OAuth expansion)
- **Cloud Messaging**: Push notifications via real-time Firestore listener + local notifications (free, no Cloud Functions needed)
- **Cloud Functions** (optional): Server-side triggers for push when app is closed (requires Blaze plan)
- **Storage Rules**: Security rules in `firestore.rules`

**Media Storage (Cloudinary)**
- Profile avatars (formal + casual)
- Post images
- Story media
- Reel videos
- Chat image attachments

---

## 🔧 Technology Stack

### Frontend
- **Flutter 3.0+**: Cross-platform framework (Dart)
- **Provider**: State management
- **flutter_blue_plus**: BLE scanning
- **geolocator**: GPS location services
- **google_maps_flutter**: Map view for GPS discovery

### Backend
- **Firebase Firestore**: Real-time NoSQL database
- **Firebase Authentication**: User management
- **Firebase Cloud Messaging**: Push notifications
- **Cloudinary**: Image/video CDN and processing

### Development Tools
- **VS Code**: Recommended IDE
- **Android Studio**: For Android SDK/emulator
- **Firebase CLI**: Deployment and management
- **FlutterFire CLI**: Firebase configuration automation

---

## 📁 Project Structure

```
proxi/
├── mobile_app/                 # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── app_state.dart      # Global state (mode, user)
│   │   ├── constants.dart      # App constants (colors, strings)
│   │   ├── firebase_options.dart  # Auto-generated Firebase config
│   │   ├── models.dart         # Data models (User, Post, Story)
│   │   ├── ble_service.dart    # Bluetooth Low Energy scanner
│   │   ├── screens/            # UI screens
│   │   │   ├── auth_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── profile_screen.dart
│   │   │   ├── nearby_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── story_view_screen.dart
│   │   │   └── ...
│   │   ├── services/           # Business logic
│   │   │   ├── firestore_service.dart
│   │   │   ├── cloudinary_service.dart
│   │   │   ├── notification_service.dart
│   │   │   └── ...
│   │   └── widgets/            # Reusable components
│   │       ├── mode_switch.dart
│   │       ├── post_card.dart
│   │       └── ...
│   ├── android/                # Android-specific files
│   │   └── app/
│   │       ├── build.gradle.kts
│   │       └── google-services.json  # Firebase config
│   ├── pubspec.yaml            # Flutter dependencies
│   └── README.md
│
├── backend/                    # Legacy Python backend (deprecated)
│   └── main.py
│
├── functions/                  # Firebase Cloud Functions (Node.js)
│   ├── index.js                # Push notification triggers
│   └── package.json            # Node.js dependencies
│
├── firebase.json               # Firebase project configuration
├── firestore.rules             # Firestore security rules
├── firestore.indexes.json      # Firestore query indexes
├── storage.rules               # Firebase Storage rules (future use)
├── installsteps.md             # Detailed setup instructions
├── plan.md                     # Development roadmap
└── README.md                   # This file
```

---

## 🎯 Feature Roadmap

### ✅ Completed (v2.0)
- [x] Dual-mode toggle (Formal/Casual)
- [x] Firebase authentication
- [x] Firestore database integration
- [x] BLE proximity scanning with RSSI filtering (~30-50 m range)
- [x] GPS-based discovery (10 km radius)
- [x] Post creation (text + images)
- [x] Stories with 24h expiry
- [x] Reels (vertical video feed)
- [x] Job board (Formal mode)
- [x] Real-time chat (DM + Group)
- [x] Delete/clear DM and group chat
- [x] Push notifications (real-time Firestore listener + local push)
- [x] Cloud Functions code ready (optional, requires Blaze plan for deploy)
- [x] Connection request system
- [x] Followers/following real-time sync
- [x] Tappable followers/following/connections lists
- [x] Mode-specific chat (Pro and Social separate)
- [x] Mode-specific followers, following, and connections
- [x] Manage followers (add/remove from Settings)
- [x] Accept connection notification to requester
- [x] Delete own posts, reels, and stories

### 🔨 In Progress
- [ ] Cloud Functions deployment (optional, requires Firebase Blaze plan)
- [ ] Story auto-cleanup (24h cron job)
- [ ] Feed algorithm (personalized sorting)

### 🔮 Future Plans
- [ ] iOS support (requires Mac with Xcode)
- [ ] Voice messages in chat
- [ ] Video calling
- [ ] Story reactions (emoji slider)
- [ ] LinkedIn/Google OAuth integration
- [ ] Admin dashboard (web)
- [ ] Analytics dashboard

---

## 🧪 Testing

### Running Tests

```powershell
cd mobile_app
flutter test
```

### Manual Testing Checklist

See [installsteps.md - PART 7](installsteps.md#part-7-test-every-feature) for comprehensive testing guide covering:
- Authentication flow
- Mode toggle functionality
- Content creation (posts, stories, reels)
- Social interactions (likes, comments)
- Chat system
- Proximity discovery (BLE + GPS)
- Job board
- Notifications
- Connection requests

**Tip**: You need 2 test accounts to fully test chat, connections, and notifications.

---

## 🚢 Deployment

### Building Release APK

```powershell
cd mobile_app
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Publishing to Google Play Store

1. **Create Developer Account**: Pay $25 one-time fee at [Google Play Console](https://play.google.com/console)
2. **Generate Signing Key**: Follow [official guide](https://docs.flutter.dev/deployment/android#signing-the-app)
3. **Build App Bundle**: `flutter build appbundle --release`
4. **Upload**: Via Play Console
5. **Fill Store Listing**: Screenshots, description, privacy policy

### Firebase Deployment

```powershell
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# (Optional) Deploy Cloud Functions — requires Blaze plan
# Push notifications already work for free via in-app Firestore listener.
# Cloud Functions are only needed for push when app is completely closed.
cd functions
npm install
cd ..
firebase deploy --only functions
```

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/proxy-sharing-others.git
cd proxy-sharing-others
git remote add upstream https://github.com/Bhanutejayadalla/proxy-sharing-others.git
```

> **Important**: After cloning, follow the [Required Setup](#-required-setup-for-forkers--new-developers) section to configure Firebase and Cloudinary before running the app.

### 2. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 3. Make Changes and Test

```bash
cd mobile_app
flutter pub get
flutter run
```

### 4. Commit and Push

```bash
git add .
git commit -m "Add: Brief description of your changes"
git push origin feature/your-feature-name
```

### 5. Open Pull Request
- Go to your fork on GitHub
- Click "Compare & pull request"
- Fill out the PR template
- Wait for review

### Code Style Guidelines
- Use `dart format` before committing
- Follow Flutter's [style guide](https://dart.dev/guides/language/effective-dart/style)
- Add comments for complex logic
- Update documentation if adding features

---

## 🐛 Troubleshooting

### Common Issues

**"Unable to locate Android SDK"**
```powershell
# Install Android Studio, then run:
flutter config --android-sdk "C:\Users\YOUR_NAME\AppData\Local\Android\Sdk"
```

**"FlutterFire command not found"**
```powershell
# Add Dart pub cache to PATH
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

**"Phone not detected"**
- Ensure USB Debugging is enabled
- Try different USB cable (some are charge-only)
- Run `adb devices` to verify connection

**"Firebase configuration error"**
- Re-run `flutterfire configure` in `mobile_app/` directory
- Verify `google-services.json` exists in `android/app/`
- Check Project ID matches Firebase console

See [installsteps.md](installsteps.md) for detailed troubleshooting steps.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Team

- **Bhanu Teja Yadalla** - Creator & Lead Developer
- [GitHub](https://github.com/Bhanutejayadalla)

---

## 🙏 Acknowledgments

- Firebase for backend infrastructure
- Cloudinary for media management
- Flutter community for amazing packages
- All contributors and testers

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Bhanutejayadalla/proxi/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Bhanutejayadalla/proxi/discussions)
- **Email**: comet200508@gmail.com

---

## 📊 Project Status

![GitHub last commit](https://img.shields.io/github/last-commit/Bhanutejayadalla/proxi)
![GitHub issues](https://img.shields.io/github/issues/Bhanutejayadalla/proxi)
![GitHub stars](https://img.shields.io/github/stars/Bhanutejayadalla/proxi?style=social)

**Current Version**: 2.0 Beta  
**Status**: Active Development  
**First Release**: February 2026

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Bhanutejayadalla">Bhanu Teja Yadalla</a>
</p>

<p align="center">
  <sub>Star ⭐ this repo if you find it useful!</sub>
</p>
