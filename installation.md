# Proxi — Installation Guide

Three ways to install the app on your device.

---

## Method 1 — USB (Run Directly from Source)

Best for developers. Builds and installs live from your laptop onto the phone.

### Prerequisites

| Tool | Download |
|---|---|
| Flutter SDK 3.0+ | https://docs.flutter.dev/get-started/install/windows |
| Android Studio | https://developer.android.com/studio |
| Git | https://git-scm.com/download/win |
| USB data cable | Must support data transfer (not charge-only) |

---

### Step 1 — Install Flutter

1. Download the Flutter SDK zip from https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter` (avoid spaces in path)
3. Add `C:\flutter\bin` to your system PATH:
   - Search "Environment Variables" in Start
   - Under **System Variables** → select **Path** → Edit → New → paste `C:\flutter\bin`
4. Open a new PowerShell window and verify:

```powershell
flutter --version
```

---

### Step 2 — Install Android Studio

1. Download from https://developer.android.com/studio and run the installer
2. During setup, ensure these are checked:
   - Android SDK
   - Android SDK Platform-Tools
   - Android Virtual Device (optional — you have a real device)
3. After install, open Android Studio → **More Actions** → **SDK Manager**
4. Under **SDK Tools**, install:
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
5. Accept all licenses:

```powershell
flutter doctor --android-licenses
```

---

### Step 3 — Enable Developer Mode on Your Phone (Android)

1. Open **Settings** → **About phone**
2. Find **Build number** (may be under *Software information*)
3. Tap **Build number 7 times** quickly
4. You'll see: *"You are now a developer!"*
5. Go back to **Settings** → **Developer options**
6. Turn on **USB debugging**
7. Tap **OK** on the confirmation popup

---

### Step 4 — Connect Phone via USB

1. Plug your phone into your laptop with a data cable
2. On your phone, when the popup appears: **"Allow USB debugging?"**
   - Check **"Always allow from this computer"**
   - Tap **Allow**
3. When asked **"Use USB for"** → select **File Transfer (MTP)**
4. Verify the connection:

```powershell
adb devices
```

Expected output:
```
List of devices attached
RF8N20XXXXX    device
```

If it shows `unauthorized` — look at your phone screen and tap **Allow**.

---

### Step 5 — Clone the Repository

```powershell
git clone https://github.com/Bhanutejayadalla/proxi.git
cd proxi\mobile_app
flutter pub get
```

---

### Step 6 — Run on Your Phone

```powershell
flutter devices        # confirm your phone is listed
flutter run            # builds and installs the app
```

- **First build**: 3–5 minutes
- **Subsequent runs**: ~15 seconds (hot reload with `r`, hot restart with `R`)

---

### Troubleshooting USB

| Problem | Fix |
|---|---|
| `No devices found` | Try a different USB cable (data cable, not charge-only) |
| `unauthorized` | Accept the debugging popup on your phone |
| Device disappears | Disable battery optimization for ADB in Developer options |
| `adb: command not found` | Add `%LOCALAPPDATA%\Android\Sdk\platform-tools` to PATH |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Uninstall the old version from your phone first |

```powershell
# Reset ADB if detection is unstable
adb kill-server
adb start-server
adb devices
```

---

---

## Method 2 — Build APK and Install Directly

Best for sharing with testers or installing without a laptop connection.

### Step 1 — Build the APK

```powershell
cd proxi\mobile_app

# Debug APK (fast build, larger file, for testing)
flutter build apk --debug

# Release APK (optimized, smaller, for distribution)
flutter build apk --release

# Split APKs by CPU architecture (smallest file sizes — recommended)
flutter build apk --split-per-abi --release
```

The built APK files will be at:

| Build type | Output path |
|---|---|
| Debug | `build\app\outputs\flutter-apk\app-debug.apk` |
| Release | `build\app\outputs\flutter-apk\app-release.apk` |
| Split (arm64) | `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` |
| Split (arm32) | `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` |

> For most modern Android phones (2017+), use `app-arm64-v8a-release.apk`.

---

### Step 2 — Transfer the APK to Your Phone

**Option A — USB transfer**
1. Connect phone via USB → select **File Transfer (MTP)**
2. Open File Explorer → your phone will appear as a drive
3. Copy the `.apk` file to the **Downloads** folder on your phone

**Option B — Google Drive / WhatsApp / Telegram**
1. Upload the APK file to Google Drive
2. Open Google Drive on your phone and download the file

**Option C — ADB install (fastest, no phone setup needed)**
```powershell
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

### Step 3 — Install on Android

1. Open your phone's **File Manager**
2. Navigate to **Downloads** (or wherever you saved the APK)
3. Tap the `.apk` file
4. You'll see: **"Install from unknown sources"** warning
   - Tap **Settings**
   - Enable **Install unknown apps** for your file manager app
   - Go back and tap **Install**
5. Tap **Open** when installation completes

---

### Step 4 — Enable Firebase (Required for the App to Work)

The app connects to a Firebase backend. The bundled `google-services.json` already points to the correct project, so no additional setup is needed as long as you have an internet connection on the device.

---

---

## Method 3 — Full Platform Setup

### Android — Full Steps

#### Requirements

- Windows, macOS, or Linux PC
- Android phone with Android 6.0 (API 23) or higher
- USB cable
- Flutter SDK, Android Studio, Git (see Method 1)

---

#### Step 1 — Set Up the Development Environment

```powershell
# 1. Verify Flutter
flutter doctor

# 2. Accept Android licenses
flutter doctor --android-licenses

# 3. Install dependencies
cd proxi\mobile_app
flutter pub get
```

`flutter doctor` should show no critical issues (✓ or ✗ only for iOS/Xcode which you can ignore on Windows).

---

#### Step 2 — Configure the App

The repository already contains `android/app/google-services.json` pointing to the live Firebase project. No configuration changes are needed for testing.

#### Step 3 — Run or Build

**Run live on device (USB):**
```powershell
flutter run
```

**Build release APK:**
```powershell
flutter build apk --release --split-per-abi
```

**Build App Bundle (for Google Play Store upload):**
```powershell
flutter build appbundle --release
```

---

#### Step 4 — Required Android Permissions

The app will request these permissions on first launch:

| Permission | Used for |
|---|---|
| Bluetooth / Bluetooth Scan | BLE proximity discovery |
| Location (Fine) | GPS discovery + required by Android for BLE scanning |
| Camera | Taking photos and recording reels |
| Storage / Media | Picking photos/videos from gallery |
| Notifications | Push notifications for messages and connections |

Allow all of them for the full experience.

---

#### Android Minimum Requirements

| Item | Minimum |
|---|---|
| Android version | 6.0 (Marshmallow, API 23) |
| RAM | 2 GB |
| Storage | 100 MB free |
| Bluetooth | 4.0 BLE support |
| GPS | Required for nearby discovery |

---

---

### iOS — Full Steps

> **Requires a Mac computer with Xcode installed.**  
> iOS builds cannot be done on Windows.

---

#### Step 1 — Mac Environment Setup

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Flutter
brew install --cask flutter

# Install CocoaPods (required for iOS dependencies)
sudo gem install cocoapods

# Verify setup
flutter doctor
```

---

#### Step 2 — Install Xcode

1. Open the **Mac App Store**
2. Search for **Xcode** and install it (large download: ~12 GB)
3. After install, open Xcode once to agree to the license
4. Install command-line tools:

```bash
xcode-select --install
sudo xcodebuild -runFirstLaunch
```

---

#### Step 3 — Clone the Project and Install Dependencies

```bash
git clone https://github.com/Bhanutejayadalla/proxi.git
cd proxi/mobile_app

flutter pub get
cd ios
pod install
cd ..
```

---

#### Step 4 — Add Required iOS Permissions (Info.plist)

Open `ios/Runner/Info.plist` in a text editor and add the following keys inside the `<dict>` tag if not already present:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Proxi uses Bluetooth to discover nearby users.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Proxi uses Bluetooth to discover nearby users.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Proxi uses your location to find people nearby.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Proxi uses your location to find people nearby.</string>

<key>NSCameraUsageDescription</key>
<string>Proxi needs camera access to take photos and record reels.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Proxi needs photo library access to select media.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Proxi needs microphone access to record video reels.</string>
```

---

#### Step 5 — Configure Signing in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj`)
2. Select the **Runner** target in the left panel
3. Go to **Signing & Capabilities**
4. Check **Automatically manage signing**
5. Select your **Apple Developer Team** from the dropdown
   - Free Apple ID works for personal device testing (7-day certificate)
   - Paid Apple Developer account ($99/year) required for App Store or >1 device

---

#### Step 6 — Add GoogleService-Info.plist

1. Go to Firebase Console → Project Settings → iOS
2. Register the app with your bundle ID (default: `com.proxi.app`)
3. Download `GoogleService-Info.plist`
4. In Xcode, drag it into the **Runner** folder (tick "Copy items if needed")

---

#### Step 7 — Run on iPhone

**Connect your iPhone via USB**, trust the computer on the phone, then:

```bash
flutter devices           # confirm your iPhone appears
flutter run               # builds and installs
```

Or build a release IPA:

```bash
flutter build ipa --release
```

The `.ipa` file is at `build/ios/ipa/`.

---

#### iOS Minimum Requirements

| Item | Minimum |
|---|---|
| iOS version | 13.0 |
| Device | iPhone 6s or newer |
| Storage | 150 MB free |
| Bluetooth | BLE capable (all iPhones since 4S) |
| Xcode | 14.0 or higher |
| macOS | 12 (Monterey) or higher (for Xcode 14+) |

---

#### iOS Troubleshooting

| Problem | Fix |
|---|---|
| `pod install` fails | Run `sudo gem update cocoapods` then retry |
| "Untrusted Developer" on device | Settings → General → VPN & Device Management → Trust your Apple ID |
| Build fails with signing error | Re-select your team in Xcode Signing & Capabilities |
| BLE not working on simulator | Use a real iPhone — simulators don't support Bluetooth |
| `GoogleService-Info.plist` missing | Add the file from Firebase Console as described in Step 6 |

---

## Quick Reference

| Goal | Command |
|---|---|
| Run on connected device | `flutter run` |
| Build debug APK | `flutter build apk --debug` |
| Build release APK | `flutter build apk --release --split-per-abi` |
| Build App Bundle (Play Store) | `flutter build appbundle --release` |
| Build iOS IPA | `flutter build ipa --release` (Mac only) |
| Install APK via ADB | `adb install app-release.apk` |
| Check connected devices | `flutter devices` |
| Clean build cache | `flutter clean` |
| Get dependencies | `flutter pub get` |
