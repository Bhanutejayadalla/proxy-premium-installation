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
- **BLE (Bluetooth)**: Find people within 10-15 meters (indoor/crowded spaces)
- **GPS Mode**: Discover users within customizable radius (outdoor events)
- **Animated Radar UI**: Visual representation of nearby users

### Content Creation
- **Posts**: Text, images, mixed media (mode-specific)
- **Stories**: 24-hour expiring content with tap-to-pause viewer
- **Reels**: Short-form vertical videos (Casual mode)
- **Jobs**: Professional listings with skills/salary (Formal mode)

### Real-Time Features
- **Live Chat**: Direct messages with image sharing
- **Notifications**: Push alerts for likes, comments, connections
- **Connection System**: Send/accept requests in Formal mode
- **Story Replies**: Tap to reply → opens DM

---

## 📋 Table of Contents

1. [Quick Start](#-quick-start)
2. [Setup Instructions](#-setup-instructions)
3. [Architecture](#-architecture)
4. [Technology Stack](#-technology-stack)
5. [Project Structure](#-project-structure)
6. [Contributing](#-contributing)
7. [License](#-license)

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
git clone https://github.com/Bhanutejayadalla/proxi.git
cd proxi

# 2. Install dependencies
cd mobile_app
flutter pub get

# 3. Connect your Android phone (USB debugging enabled)
flutter devices

# 4. Run the app
flutter run
```

📘 **Full setup guide**: See [installsteps.md](installsteps.md) for detailed instructions

---

## 🛠 Setup Instructions

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
- **Firestore**: NoSQL database (users, posts, stories, chats, notifications)
- **Authentication**: Email/password (ready for OAuth expansion)
- **Cloud Messaging**: Push notifications (FCM tokens in user docs)
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
- [x] BLE proximity scanning
- [x] GPS-based discovery
- [x] Post creation (text + images)
- [x] Stories with 24h expiry
- [x] Reels (vertical video feed)
- [x] Job board (Formal mode)
- [x] Real-time chat
- [x] Push notifications structure
- [x] Connection request system

### 🔨 In Progress
- [ ] Cloud Functions for automated tasks
- [ ] Story auto-cleanup (24h cron job)
- [ ] Advanced notification triggers
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
```

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/proxi.git
cd proxi
git remote add upstream https://github.com/Bhanutejayadalla/proxi.git
```

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
