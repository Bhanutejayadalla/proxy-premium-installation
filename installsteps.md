# PROXI — Complete Setup Guide (Step by Step)

Everything below costs **$0**. No credit card needed anywhere.

---

## 📋 TABLE OF CONTENTS

### 🖥️ LAPTOP/DESKTOP SETUP
- [PART 1: Prerequisites](#part-1-prerequisites-one-time-setup)
- [PART 2: Firebase Setup](#part-2-firebase-setup-database--auth--notifications)
- [PART 3: Cloudinary Setup](#part-3-cloudinary-setup-imagevideo-upload--free)
- [PART 4: Install Dependencies](#part-4-install-dependencies--build)

### 📱 PHONE SETUP & CONNECTION
- [PART 5: Connect Your Phone](#part-5-connect-your-phone)
- [PART 6: Run the App](#part-6-run-the-app-on-your-phone)
- [PART 7: Test Every Feature](#part-7-test-every-feature)
- [PART 8: Verify Data in Firebase](#part-8-verify-data-in-firebase-console)

### 🚀 GITHUB & DEPLOYMENT
- [PART 9: Push to GitHub](#part-9-push-to-github)
- [PART 10: Next Steps](#part-10-next-steps)
- [PART 11: Troubleshooting](#part-11-troubleshooting)

---

## PART 1: PREREQUISITES (One-Time Setup)

Make sure these are installed on your PC. Open **PowerShell** and check:

```powershell
flutter --version    # Need 3.0+
dart --version       # Comes with Flutter
node --version       # Need Node.js for Firebase CLI
```

**If Node.js is missing:** Download from [https://nodejs.org](https://nodejs.org) (LTS version), install, restart PowerShell.

**If Flutter is missing:** Follow [https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)

---

## PART 2: FIREBASE SETUP (Database + Auth + Notifications)

### Step 2.1 — Create Firebase Project

1. Open browser → go to **[https://console.firebase.google.com](https://console.firebase.google.com)**
2. Click **"Add project"** (or "Create a project")
3. Project name: **`proxi-social`** (or anything you want)
4. Disable Google Analytics (toggle off) → click **Continue**
5. Click **"Create project"** → wait 30 seconds → click **Continue**

### Step 2.2 — Enable Authentication

1. In Firebase Console left sidebar → **Build → Authentication**
2. Click **"Get started"**
3. Click **Sign-in method** tab
4. Click **"Email/Password"**
5. Toggle **Enable** ON
6. Click **Save**

### Step 2.3 — Enable Cloud Firestore (Database)

1. Left sidebar → **Build → Firestore Database**
2. Click **"Create database"**
3. Select **"Start in test mode"** → click **Next**
4. Choose a region close to you:
   - India: `asia-south1`
   - US: `us-central1`
   - Europe: `europe-west1`
5. Click **"Enable"** → wait 30 seconds

### Step 2.4 — Note Your Project ID

1. Click the **gear icon** (⚙️) next to "Project Overview" in the left sidebar
2. Click **"Project settings"**
3. Under **"General"** tab, find **"Project ID"** (e.g., `proxi-social-abc12`)
4. **Copy this** — you'll need it in Step 2.6

### Step 2.5 — Install Firebase CLI + FlutterFire CLI

Open **PowerShell** and run these commands ONE AT A TIME:

```powershell
# 1. Install Firebase CLI globally
npm install -g firebase-tools

# 2. Login to your Google/Firebase account (opens browser)
firebase login

# 3. Install FlutterFire CLI
dart pub global activate flutterfire_cli
```

**If `flutterfire` command is not found after step 3**, add the Dart pub cache to your PATH:

```powershell
# Add to PATH temporarily (for this session)
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"

# Verify it works
flutterfire --version
```

To make it permanent: **Windows Settings → System → About → Advanced system settings → Environment Variables → PATH → Add: `%LOCALAPPDATA%\Pub\Cache\bin`**

### Step 2.6 — Connect Firebase to Your Flutter Project

This is the **most important step**. Run these in PowerShell:

```powershell
cd d:\Proxi_Social_Connectivity\mobile_app

flutterfire configure --project=YOUR_PROJECT_ID_HERE
```

Replace `YOUR_PROJECT_ID_HERE` with the Project ID from Step 2.4 (e.g., `proxi-social-abc12`).

**When prompted:**
- **Which platforms?** → Select **Android** (use space to select, enter to confirm)
- **Android package name?** → Accept the default `com.example.dual_mode_app`
- **Overwrite firebase_options.dart?** → Yes

**This creates two files automatically:**
- `android/app/google-services.json` ← Android Firebase config
- `lib/firebase_options.dart` ← Dart config used in main.dart

**Verify they exist:**
```powershell
Test-Path android\app\google-services.json   # Should say True
Test-Path lib\firebase_options.dart           # Should say True
```

### Step 2.7 — Deploy Firestore Security Rules (Optional but Recommended)

You can either deploy from terminal OR paste manually:

**Option A: Terminal (if firebase CLI works)**
```powershell
cd d:\Proxi_Social_Connectivity
firebase init
# When prompted:
#   Which features? → Select ONLY "Firestore" (space to select, enter to confirm)  
#   Use existing project → select your proxi-social project
#   Firestore Rules file: firestore.rules → press Enter (already exists)
#   Firestore Indexes file: firestore.indexes.json → press Enter (already exists)
#   Overwrite? → No

firebase deploy --only firestore:rules,firestore:indexes
```

**Option B: Manual (easier)**
1. Firebase Console → Firestore Database → **Rules** tab
2. Open firestore.rules in VS Code
3. Copy all the text, paste into the Firebase Console rules editor
4. Click **Publish**

---

## PART 3: CLOUDINARY SETUP (Image/Video Upload — Free)

### Step 3.1 — Create Free Account

1. Open **[https://cloudinary.com/users/register_free](https://cloudinary.com/users/register_free)**
2. Sign up with email or Google — **NO credit card needed**
3. After signup, you land on the **Dashboard**

### Step 3.2 — Copy Your Cloud Name

On the Dashboard, you'll see a box with:
```
Cloud Name: dxyz1234abc    ← COPY THIS
```

### Step 3.3 — Create Upload Preset

1. In Cloudinary, click **Settings** (gear icon, bottom-left)
2. Click **Upload** in the left menu
3. Scroll down to **"Upload presets"**
4. Click **"Add upload preset"**
5. Set these values:
   - **Upload preset name:** `proxi_unsigned` (or any name — remember it)
   - **Signing Mode:** Change to **Unsigned**
6. Click **Save**

### Step 3.4 — Put Your Credentials in the Code

Open cloudinary_service.dart and update these two lines:

```dart
static const String cloudName = 'dxyz1234abc';        // ← YOUR cloud name
static const String uploadPreset = 'proxi_unsigned';   // ← YOUR preset name
```

Save the file.

---

## PART 4: INSTALL DEPENDENCIES & BUILD

Open PowerShell:

```powershell
cd d:\Proxi_Social_Connectivity\mobile_app

# Install all Flutter packages
flutter pub get

# Check everything is OK
flutter doctor
```

`flutter doctor` should show:
- Flutter ✅
- Android toolchain ✅
- Connected device ✅ (after connecting phone)

If there are issues, `flutter doctor` will tell you exactly what's missing.

---

## PART 5: CONNECT YOUR PHONE

### Step 5.1 — Enable Developer Mode on Android Phone

1. Open phone **Settings**
2. Go to **About Phone** (sometimes under System → About)
3. Find **"Build Number"**
4. **Tap it 7 times** rapidly
5. You'll see: *"You are now a developer!"*

### Step 5.2 — Enable USB Debugging

1. Go back to **Settings**
2. Find **Developer Options** (now visible, usually under System)
3. Toggle ON: **USB Debugging**
4. Toggle ON: **Install via USB** (if present)

### Step 5.3 — Connect Phone to PC

1. Plug your phone into your PC with a **USB cable**
2. On your phone, a popup will ask: *"Allow USB debugging?"*
3. Tap **"Allow"** (check "Always allow from this computer")
4. If asked for USB mode, select **"File Transfer"** (not charging-only)

### Step 5.4 — Verify Connection

In PowerShell:
```powershell
flutter devices
```

You should see something like:
```
Samsung Galaxy S21 (mobile) • RF8N12345 • android-arm64 • Android 13
```

If your phone doesn't appear:
- Try a different USB cable (some are charge-only)
- Make sure USB Debugging is ON
- Try: `adb devices` in PowerShell (should list your device)

---

## PART 6: RUN THE APP ON YOUR PHONE

```powershell
cd d:\Proxi_Social_Connectivity\mobile_app

flutter run
```

**First build takes 3-5 minutes.** You'll see:

```
Launching lib/main.dart on Samsung Galaxy S21...
Running Gradle task 'assembleDebug'...
✓ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...
```

The app will launch on your phone automatically.

**While running:**
- Press **`r`** in the terminal → Hot Reload (instant UI refresh)
- Press **`R`** → Hot Restart (full restart)
- Press **`q`** → Quit

---

## PART 7: TEST EVERY FEATURE

Here's the testing checklist. Do them in order:

### 7.1 — Authentication
| Test | Steps | Expected |
|------|-------|----------|
| Register | Enter email + username + password → tap **Register** | Lands on Home screen |
| Logout | Profile tab → gear icon → Logout | Returns to auth screen |
| Login | Enter same email + password → tap **Login** | Lands on Home screen |
| Wrong password | Enter wrong password → Login | Error message appears |

### 7.2 — Mode Toggle
| Test | Steps | Expected |
|------|-------|----------|
| Switch to Casual | Tap the **briefcase FAB** at bottom center | UI turns pink, badge says "SOCIAL", tabs show Reels |
| Switch to Formal | Tap the **party FAB** | UI turns blue, badge says "PRO", tabs show Jobs |

### 7.3 — Content Creation
| Test | Steps | Expected |
|------|-------|----------|
| Text post | + tab → type text → Post | Post appears in feed |
| Photo post | + tab → tap camera icon → pick photo → Post | Post with image appears |
| Story | + tab → toggle "Story" → post | Story circle at top of feed |
| View story | Tap story circle | Full-screen story viewer |

### 7.4 — Social Interactions
| Test | Steps | Expected |
|------|-------|----------|
| Like | Tap heart on any post | Heart fills, count increases |
| Comment | Tap comment icon → type → send | Comment appears under post |

### 7.5 — Profile
| Test | Steps | Expected |
|------|-------|----------|
| View profile | Tap Profile tab | See avatar, bio, posts grid |
| Edit profile | Gear icon → Edit Profile → change name → Save | Name updates |
| Change avatar | Edit Profile → tap avatar → pick photo | Avatar changes (uploaded to Cloudinary) |

### 7.6 — Nearby Discovery
| Test | Steps | Expected |
|------|-------|----------|
| GPS scan | Nearby tab → select GPS → Scan | Shows users (need 2 accounts with location) |
| BLE scan | Nearby tab → select BLE → Scan | Radar animation, scans Bluetooth |

### 7.7 — Chat (Need 2 accounts)
| Test | Steps | Expected |
|------|-------|----------|
| Start chat | Tap user → Message | Opens chat screen |
| Send message | Type text → send | Message appears in real-time |
| Send image | Tap attachment → pick photo | Image uploads + appears in chat |

### 7.8 — Jobs (Formal Mode Only)
| Test | Steps | Expected |
|------|-------|----------|
| View jobs | Switch to Formal → Jobs tab | Job board with listings |
| Create job | Jobs → + button → fill fields → Post | Job appears in list |

### 7.9 — Reels (Casual Mode Only)
| Test | Steps | Expected |
|------|-------|----------|
| View reels | Switch to Casual → Reels tab | Vertical swipe video feed |
| Record reel | Reels → camera button → pick video → post | Reel uploads + appears |

### 7.10 — Notifications
| Test | Steps | Expected |
|------|-------|----------|
| Get notification | Have 2nd account like your post | Notification appears |

### 7.11 — Connections (Need 2 accounts)
| Test | Steps | Expected |
|------|-------|----------|
| Send request | View user → Connect button | Status changes to "Pending" |
| Accept request | Login as other user → Notifications → Accept | Connection established |

### Creating a 2nd Test Account
You need 2 accounts to test chat, connections, and notifications. Options:
- **Easiest:** Firebase Console → Authentication → **Add User** → enter a 2nd email/password
- Then create their Firestore profile: Firestore → `users` collection → Add document (doc ID = the UID from Auth) with fields: `username`, `email`, `bio`, etc.
- **Or:** Install the APK on a 2nd phone/emulator and register normally

---

## PART 8: VERIFY DATA IN FIREBASE CONSOLE

After testing, check your data is actually in Firebase:

1. **Firebase Console → Authentication** → You should see your registered users
2. **Firebase Console → Firestore Database** → Click through collections:
   - `users` → your user documents
   - `posts` → your posts
   - `stories` → your stories
   - `chats` → chat rooms with messages subcollection
   - `notifications` → notification documents
3. **Cloudinary Dashboard → Media Library** → You should see uploaded images/videos

---

## PART 9: PUSH TO GITHUB

Now that your app is running, let's push everything to GitHub so you can access it from anywhere and collaborate with others.

### Step 9.1 — Check if Git is Installed

Open PowerShell and check:

```powershell
git --version
```

If Git is not installed, download from **[https://git-scm.com/download/win](https://git-scm.com/download/win)**, install, and restart PowerShell.

### Step 9.2 — Configure Git (One-Time Setup)

Set your name and email (these will appear in commits):

```powershell
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Step 9.3 — Initialize Git Repository (If Not Already Done)

```powershell
cd D:\Proxi_Social_Connectivity

# Check if Git is already initialized
git status
```

If you see **"fatal: not a git repository"**, initialize Git:

```powershell
git init
```

### Step 9.4 — Create .gitignore (Ignore Unnecessary Files)

Check if `.gitignore` exists:

```powershell
Test-Path .gitignore
```

If it doesn't exist, create it:

```powershell
@"
# Flutter/Dart specific
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
flutter_*.log

# Android specific
*.iml
*.class
*.dex
*.ap_
local.properties
.gradle/
.idea/
captures/
*.jks
*.keystore

# Firebase/sensitive files  
**/*.keystore
google-services.json
firebase_options.dart
.firebaserc
firebase-debug.log

# IDE files
.vscode/
.DS_Store
*.swp
*.swo
*~

# Backend
backend/__pycache__/
backend/uploads/
backend/.env

# Windows
Thumbs.db
desktop.ini

# Node modules
node_modules/
"@ | Out-File -FilePath .gitignore -Encoding utf8
```

### Step 9.5 — Add Remote Repository

Go to **[https://github.com/Bhanutejayadalla/proxi](https://github.com/Bhanutejayadalla/proxi)** and create the repository if it doesn't exist.

Then link your local project to GitHub:

```powershell
# Add the remote repository
git remote add origin https://github.com/Bhanutejayadalla/proxi.git

# Verify it was added
git remote -v
```

### Step 9.6 — Stage, Commit, and Push

```powershell
# Stage all files
git add .

# Check what will be committed
git status

# Commit with a message
git commit -m "Initial commit: PROXI social connectivity app with Firebase"

# Push to GitHub (first time)
git branch -M main
git push -u origin main
```

**If you get authentication errors:**

#### Option A: Using GitHub CLI (Easiest)
```powershell
# Install GitHub CLI
winget install --id GitHub.cli

# Login
gh auth login
# Follow prompts: Choose HTTPS → Login with browser → Authenticate

# Retry push
git push -u origin main
```

#### Option B: Using Personal Access Token
1. Go to **GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **"Generate new token (classic)"**
3. Select scopes: `repo` (full control)
4. Copy the token (save it somewhere safe!)
5. When pushing, use token as password:
   ```powershell
   git push -u origin main
   # Username: Bhanutejayadalla
   # Password: <paste your token here>
   ```

### Step 9.7 — Verify on GitHub

Open **[https://github.com/Bhanutejayadalla/proxi](https://github.com/Bhanutejayadalla/proxi)** in your browser. You should see all your files!

### Step 9.8 — Update Files in Future

Whenever you make changes:

```powershell
cd D:\Proxi_Social_Connectivity

# Check what changed
git status

# Stage changes
git add .

# Commit
git commit -m "Description of what you changed"

# Push to GitHub
git push
```

---

## PART 10: NEXT STEPS

| Priority | What | How |
|----------|------|-----|
| **Do now** | Fix any bugs from testing | Check terminal for errors, run `flutter logs` |
| **Do now** | Deploy security rules | Part 2 Step 2.7 above |
| **Soon** | Build release APK | `flutter build apk --release` → share APK with friends |
| **Soon** | Add app icon and splash screen | Replace files in `android/app/src/main/res/mipmap-*` |
| **Later** | Publish to Play Store | Requires Google Play Developer account ($25 one-time fee) |
| **Later** | Add Cloud Functions | For push notifications when app is closed (requires Blaze plan — optional, in-app push already works free) |
| **Later** | Add iOS support | Need a Mac with Xcode |

---

## PART 11: TROUBLESHOOTING

### Issue: "Unable to locate Android SDK"

**Solution:**
```powershell
# Install Android Studio from https://developer.android.com/studio
# After installation, set Android SDK path:
flutter config --android-sdk "C:\Users\YOUR_USERNAME\AppData\Local\Android\Sdk"

# Verify
flutter doctor
```

### Issue: "Phone not detected"

**Solutions:**
1. Try a different USB cable (some are charge-only)
2. Make sure USB Debugging is ON in Developer Options
3. On phone, change USB mode to "File Transfer" (not just charging)
4. Install phone manufacturer's USB drivers
5. Run `adb devices` in PowerShell to verify

### Issue: "FlutterFire command not found"

**Solution:**
```powershell
# Add Dart pub cache to PATH temporarily
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"

# Verify
flutterfire --version
```

To make it permanent:
- **Windows Settings → System → About → Advanced system settings**
- **Environment Variables → PATH → Edit → New**
- Add: `%LOCALAPPDATA%\Pub\Cache\bin`
- Click OK, restart PowerShell

### Issue: "Firebase configuration error"

**Solutions:**
1. Re-run FlutterFire configuration:
   ```powershell
   cd d:\Proxi_Social_Connectivity\mobile_app
   flutterfire configure --project=YOUR_PROJECT_ID
   ```

2. Verify files exist:
   ```powershell
   Test-Path android\app\google-services.json  # Should be True
   Test-Path lib\firebase_options.dart          # Should be True
   ```

3. Check Project ID matches Firebase console exactly

### Issue: "Build failed with Gradle error"

**Solutions:**
```powershell
# Clear cache and rebuild
cd d:\Proxi_Social_Connectivity\mobile_app
flutter clean
flutter pub get
flutter run
```

### Issue: "Cloudinary upload not working"

**Solutions:**
1. Verify credentials in `cloudinary_service.dart`:
   - `cloudName` matches your Cloudinary dashboard
   - `uploadPreset` exists and is set to **Unsigned**
2. Check internet connection
3. Look for errors in terminal (`flutter logs`)

### Issue: "App crashes on startup"

**Solutions:**
1. Check if Firebase is initialized in `main.dart`:
   ```dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```
2. Run `flutter logs` to see crash details
3. Try `flutter clean` then `flutter run`

### Issue: "BLE scanning not working"

**Solutions:**
1. Make sure Bluetooth is ON on your phone
2. Grant Location permission (Android requires it for BLE)
3. Test on physical device (BLE doesn't work on emulators)
4. Ensure `flutter_blue_plus` package is installed

---

## QUICK REFERENCE — Commands You'll Use Often

```powershell
# Navigate to project
cd d:\Proxi_Social_Connectivity\mobile_app

# Dependencies
flutter pub get          # Install/update packages
flutter pub outdated     # Check for package updates

# Running
flutter devices          # List connected phones
flutter run              # Run on connected phone
flutter run -d chrome    # Run in web browser
flutter logs             # See app logs in real-time

# Building
flutter build apk        # Build debug APK
flutter build apk --release   # Build release APK
flutter clean            # Clear build cache (fixes weird errors)

# Git commands
git status               # Check file changes
git add .                # Stage all changes
git commit -m "message"  # Commit with message
git push                 # Push to GitHub
git pull                 # Pull latest changes
```

---

## YOUR FILE CHECKLIST

Before running, make sure these files exist (check with `Test-Path`):

```
✅ android/app/google-services.json     ← Created by flutterfire configure
✅ lib/firebase_options.dart             ← Created by flutterfire configure
✅ cloudinary_service.dart  ← Must have YOUR cloud name + preset filled in
✅ .gitignore                            ← Prevents sensitive files from going to GitHub
```

If any are missing, go back to the relevant step above.

---

## 🎉 YOU'RE ALL SET!

**Setup Complete!** You now have:
- ✅ Flutter app running on your phone
- ✅ Firebase backend configured
- ✅ Cloudinary media uploads working
- ✅ Code backed up to GitHub
- ✅ Ready to develop and test features

**Start with Part 2 Step 2.1 and work through sequentially. The whole setup takes about 20-30 minutes.**

Need help? Check:
- **[README.md](README.md)** for project overview
- **[plan.md](plan.md)** for development roadmap
- **GitHub Issues** for known bugs
- **Email**: comet200508@gmail.com

Happy coding! 🚀 