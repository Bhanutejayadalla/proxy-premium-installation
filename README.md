# PROXI PREMIUM — Download & Installation

> **Enhanced proximity-based social networking app** — find and connect with people nearby using Bluetooth (no internet needed!) or GPS. Dual-mode Professional & Casual networking with Campus Hub features.

[![Version](https://img.shields.io/badge/version-3.0_Premium-blue)](https://github.com/Bhanutejayadalla/proxi-premium)
[![Platform](https://img.shields.io/badge/platform-Android-green)](https://github.com/Bhanutejayadalla/proxi-premium)
[![Flutter](https://img.shields.io/badge/built_with-Flutter-blue)](https://flutter.dev)
[![BLE](https://img.shields.io/badge/BLE-Offline_Mode-orange)](https://github.com/Bhanutejayadalla/proxi-premium)

> **This is Proxi Premium** — a separate app from the original Proxi. Uses its own Firebase & Cloudinary backend.  
> Both apps can be installed side by side on the same device.

---

## 📲 Download

| Build | File | Use For |
|-------|------|---------|
| **Release (arm64)** | `proxi-premium.apk` | All phones from 2017 onward |
| **Release (arm32)** | `proxi-premium-older.apk` | Phones made before 2017 |
| **Debug** | `proxi-premium-debug.apk` | Testers only — includes dev tools |

> **Not sure which to pick?** Use `proxi-premium.apk` (arm64) — it covers 99% of modern Android phones.

---

## 🚀 How to Install (Android)

1. Tap **Download APK** on the page
2. Open your **Downloads** folder
3. Tap `proxi-premium.apk`
4. If prompted, allow **"Install from Unknown Sources"** for your browser
5. Tap **Install** — done! 🎉

> ⚠️ Android shows a warning for apps installed outside the Play Store. This is normal and safe.

---

## ✨ What's in Proxi Premium v3.0

### Core Features
- **Dual-Mode System** — Pro (LinkedIn-style) and Social (Instagram-style) in one app
- **Offline BLE Discovery** — Find nearby Proxi users via Bluetooth without internet
- **GPS Discovery** — Find users within 10 km range (online)
- **BLE Advertising** — Phone broadcasts your ID so others discover you automatically
- **Posts, Stories, Reels** — Full social media content creation
- **Job Board** — Professional listings (Pro mode)
- **Real-Time Chat** — DM + Group chat, mode-specific
- **Push Notifications** — Likes, comments, messages, connection requests
- **Connection System** — Send/accept/remove with mode-specific social graph

### Campus Hub (NEW)
- **Student Search** — Filter by department, year, skills, interests
- **Peer Recommendations** — AI-style matching
- **Project Board** — Create projects, recruit teams
- **Study Groups** — Form and join study groups
- **Skill Exchange** — Teach/learn marketplace
- **Communities** — Department & interest-based with discussion forums
- **Event Management** — Workshops, hackathons, sports events
- **Venue Booking** — Book sports venues, join others' bookings
- **Sports Matching** — Find peers who play the same sport
- **Campus Map** — Google Maps with categorized markers
- **Resource Sharing** — Notes, papers, links with tracking

### Improvements over Original Proxi
- Separate Firebase project & Cloudinary for independent data
- Fixed BLE scanning — proper UID encoding (28 bytes), scan race condition fixes
- Added scan delay between Proxi scan and diagnostic scan
- Enhanced error handling for BLE stream
- Campus Hub with 12+ new feature modules

---

## 🔧 For Developers

To build from source, see the [installation.demo](../installation.demo) file in the project root.

### Quick Build

```powershell
cd mobile_app
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Deploy to Vercel

1. Build the APK (see above)
2. Copy APK to this folder:
   ```powershell
   Copy-Item "mobile_app\build\app\outputs\flutter-apk\app-release.apk" "vercel-deploy\proxi-premium.apk"
   ```
3. Deploy:
   ```powershell
   cd vercel-deploy
   npx vercel --prod
   ```

---

## 📦 Package Info

| Property | Value |
|---|---|
| **App Name** | Proxi Premium |
| **Package ID** | `com.proxi.premium` |
| **Firebase Project** | `proxi-version2` |
| **Cloudinary Cloud** | `ds9dmq1ob` |
| **Min Android Version** | API 21 (Android 5.0) |
| **Target Android Version** | Latest |

---

<p align="center">
  <strong>PROXI PREMIUM</strong> v3.0 · March 2026
</p>
