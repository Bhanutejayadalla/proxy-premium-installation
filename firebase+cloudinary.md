# Firebase & Cloudinary Setup Guide

This project requires Firebase (for authentication, firestore, etc.) and Cloudinary (for media uploads) to function correctly. Since the project's original credentials are not included in this repository, you must set up your own instances of these services.

## 1. Firebase Setup

### Prerequisites
- A Google Account
- [Firebase CLI](https://firebase.google.com/docs/cli) installed (`npm install -g firebase-tools`)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed

### Steps

1. **Create a Firebase Project:**
   - Go to the [Firebase Console](https://console.firebase.google.com/).
   - Click **Add project** and follow the on-screen instructions.

2. **Enable Required Services:**
   - **Authentication:** Go to *Build > Authentication > Sign-in method* and enable the providers you need (e.g., Email/Password, Google).
   - **Cloud Firestore:** Go to *Build > Firestore Database* and click **Create database**. Start in *Test mode* or configure security rules directly from the `firestore.rules` file provided in this repository.

3. **Configure the Flutter App:**
   - Open your terminal and log in to Firebase:
     ```bash
     firebase login
     ```
   - Make sure you are in the `mobile_app` directory:
     ```bash
     cd mobile_app
     ```
   - Run the FlutterFire CLI to configure the app for your Firebase project:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure --project=YOUR_PROJECT_ID
     ```
     *(Replace `YOUR_PROJECT_ID` with the ID of your newly created Firebase project).*
   - This command will automatically generate `lib/firebase_options.dart` and `android/app/google-services.json` (and matching files for iOS/web) containing your specific project credentials.

4. **Deploy Firestore Rules and Indexes:**
   - From the repository root directory, run:
     ```bash
     firebase deploy --only firestore
     ```

5. **(Optional) Create Predefined Songs Collection:**
   - Add sample songs to Firestore for the music feature:
   ```bash
   firebase firestore:start
   ```
   - Or manually add songs via Firebase Console > Firestore Database:
     - Collection: `songs`
     - Document fields:
       ```
       name: (string) Song name
       artist: (string) Artist name
       url: (string) Audio URL (from Cloudinary or external URL)
       thumbnail_url: (optional) Album art
       ```

## 2. Cloudinary Setup

The app uses Cloudinary for free-tier image and video uploads instead of Firebase Storage.

### Steps

1. **Create a Cloudinary Account:**
   - Go to [Cloudinary](https://cloudinary.com/) and sign up for a free account.

2. **Create an Unsigned Upload Preset:**
   - Go to your Cloudinary **Dashboard**.
   - Navigate to **Settings** (gear icon) > **Upload**.
   - Scroll down to *Upload presets* and click **Add upload preset**.
   - Change the **Signing Mode** to **Unsigned**.
   - Give it a name (e.g., `proxi_unsigned`) and save it.

3. **Get Your Credentials:**
   - Find your **Cloud Name** on your Cloudinary Dashboard.
   - For file deletion features, you will also need your **API Key** and **API Secret**. Go to **Settings > Access Keys** to find these.

4. **Update the App Code:**
   - Open `mobile_app/lib/services/cloudinary_service.dart`.
   - Fill in the credentials at the top of the file:
     ```dart
     static const String cloudName = 'YOUR_CLOUD_NAME';
     static const String uploadPreset = 'YOUR_UPLOAD_PRESET';

     // For deletion support:
     static const String apiKey = 'YOUR_API_KEY';
     static const String apiSecret = 'YOUR_API_SECRET';
     ```

5. **(Optional) Upload Sample Songs to Cloudinary:**
   - For the music feature, you can upload audio files to Cloudinary and use their URLs
   - Or use free audio URLs from services like [Bensound](https://www.bensound.com), [Pixabay Music](https://pixabay.com/music/), etc.

## 3. New Features: Posts with Music & Stories

### Database Schema (Firestore)

**Posts Collection:**
```javascript
{
  post_id: "...",
  author_id: "...",
  username: "...",
  author_avatar: "...",
  text: "Post description",
  media_url: "...",
  location: "New York, NY",           // NEW
  song_url: "...",                    // NEW
  song_name: "Blinding Lights",      // NEW
  artist: "The Weeknd",              // NEW
  created_at: Timestamp,
  updated_at: Timestamp,              // NEW
  is_edited: true,                   // NEW
  likes: ["uid1", "uid2"],
  comments: [...],
  visibility: "public",
  visible_to_uids: []
}
```

**Stories Collection:**
```javascript
{
  story_id: "...",
  author_id: "...",
  username: "...",
  author_avatar: "...",
  media_url: "...",
  song_url: "...",                    // NEW
  song_name: "Levitating",           // NEW
  artist: "Dua Lipa",                // NEW
  created_at: Timestamp,
  expires_at: Timestamp,              // 24 hours from creation
}
```

**Songs Collection:**
```javascript
{
  song_id: "...",
  name: "Song Title",
  artist: "Artist Name",
  url: "https://...",
  thumbnail_url: "https://...",
  created_at: Timestamp
}
```

### Key Features

✅ **Editable Posts** - Edit description, location, music, or media WITHOUT deleting  
✅ **Edited Label** - Shows "Edited" badge with timestamps  
✅ **Stories with Music** - Add songs to 24-hour stories  
✅ **Music Player** - Play/pause audio with progress bar  
✅ **Location Tags** - Tag post location  
✅ **Music Selector** - Search and select songs from Firestore  
✅ **Real-time Updates** - Firestore listeners for live feed updates  

Your app is now connected to your own Firebase and Cloudinary projects with full Instagram-like features!

---

## 4. Music Service Architecture

### How It Works

The `MusicService` (in `lib/services/music_service.dart`) handles all song operations:

**Reads:**
- `getAllSongs()` - Fetch all songs (default + user-uploaded)
- `getDefaultSongs()` - Fetch only system songs (userId = null)
- `getAllSongsStream()` - Real-time listener for Music Library
- `getUserSongs(uid)` - Fetch songs uploaded by a specific user

**Writes:**
- `uploadSong(title, artist, imageUrl, file)` - Upload audio to Cloudinary + metadata to Firestore
  - Audio file → Cloudinary (returns secure_url)
  - Metadata → Firestore songs collection (with userId for ownership)
- `updateSong(songId, title, artist, imageUrl)` - Owner can edit metadata
- `deleteSong(songId)` - Owner can delete (prevents deletion of default songs)

**Search & Filter:**
- `searchSongs(query)` - Client-side search by title/artist

**Initialization:**
- `addDemoSongs()` - Auto-creates 5 demo songs on app startup (only if they don't exist)
  - Uses reliable audio URLs (SoundHelix or similar with proper CORS support)
  - All marked with `userId: null` to indicate system/default songs

### Database Structure

**songs Collection:**
```javascript
{
  id: "docId",
  title: "Summer Breeze",        // Song name
  artist: "Bensound",             // Artist name
  audioUrl: "https://...",        // Cloudinary secure_url or external URL
  imageUrl: "https://...",        // Optional: album art
  userId: null,                   // null = default song, uid = user-uploaded
  createdAt: Timestamp,           // Server timestamp
}
```

### Firestore Security Rules

```javascript
match /songs/{document=**} {
  allow read: if true;  // Anyone can read songs
  allow create: if request.auth != null;  // Signed-in users can create
  allow update, delete: if request.auth.uid == resource.data.userId;  // Owners only
}
```

### Workflow: User Uploads a Song

1. User taps 🎵 Music → + Upload
2. File picker shows audio files
3. User selects file (e.g., "mymusic.mp3")
4. `uploadSong()` is called:
   - **Phase 1:** File uploads to Cloudinary
     - Endpoint: `https://api.cloudinary.com/v1_1/{cloudName}/auto/upload`
     - Multi-part form data with file + preset
     - Returns JSON with `secure_url`
   - **Phase 2:** Metadata saved to Firestore
     ```javascript
     {
       title: "mymusic",  // Filename without extension
       artist: "Unknown",  // Could be enhanced with user input
       audioUrl: "https://cloudinary.com/...",  // From step 1
       userId: "uid123",  // Current user's ID
       createdAt: serverTimestamp()
     }
     ```
5. Song appears in Music Library instantly (via real-time listener)
6. Available for all future posts/stories by this user

### Workflow: Demo Songs Initialization

1. App starts → `FirebaseService.initializeApp()` runs
2. After Firebase init, `MusicService().addDemoSongs()` is called in `main.dart`
3. Checks if demo songs already exist (where `userId == null`)
4. If not found, creates 5 songs with pre-defined URLs:
   - Summer Breeze, Epic, Ukulele, Ambient, Happiness (all by Bensound)
5. Each song added to Firestore with `userId: null`
6. Songs available immediately in Music Library

### Troubleshooting Music Features

| Issue | Cause | Solution |
|-------|-------|----------|
| Songs aren't loading | Firestore rules blocking reads | Verify `allow read: if true;` in songs rules |
| Can't upload song | Rules blocking write or file too large | Check `allow create: if request.auth != null;` and file size < 100MB |
| Demo songs missing | `addDemoSongs()` didn't run | Do hard restart: `flutter clean && flutter pub get && flutter run` |
| Audio won't play | Bad URL or CORS blocked | Verify URL is accessible (test in browser); use only public, CORS-enabled URLs |
| Upload to Cloudinary fails | Invalid credentials | Check Cloudinary cloud name and upload preset in `cloudinary_service.dart` |



