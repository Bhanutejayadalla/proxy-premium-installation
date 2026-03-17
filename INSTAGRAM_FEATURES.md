# Instagram-Like Features Implementation Guide

## 📋 Overview

This document describes the complete implementation of Instagram-like features in Proxi Premium v3.2, including:
- ✨ **Editable Posts** - Edit posts without deleting them
- 🎵 **Posts with Music** - Add songs to posts
- 📍 **Location Tags** - Tag post locations
- 📖 **Stories with Music** - 24-hour stories with background music
- 🎶 **Music Selector** - Browse and search songs from Firestore

---

## 🗂️ Files Created & Modified

### New Files Created

1. **`mobile_app/lib/services/music_service.dart`**
   - Manages song retrieval from Firestore
   - Search songs by name/artist
   - Stream support for real-time updates

2. **`mobile_app/lib/widgets/music_selector_widget.dart`**
   - `MusicSelectorWidget` - Full dialog for selecting music
   - `MusicSelectorButton` - Compact button showing selected song
   - Search functionality built-in

3. **`mobile_app/lib/widgets/audio_player_widget.dart`**
   - `AudioPlayerWidget` - Full audio player with progress bar
   - `CompactAudioPlayerWidget` - Minimal player for story viewer
   - Uses `just_audio` package for audio playback

4. **`mobile_app/lib/screens/edit_post_screen.dart`**
   - Complete UI for editing existing posts
   - Change description, location, media, or music
   - Shows creation date and edit history
   - Ownership verification (only post owner can edit)

5. **`mobile_app/lib/screens/create_story_screen.dart`**
   - Beautiful UI for uploading stories with music
   - Real-time media preview
   - Music selector with visual feedback
   - 24-hour auto-expiry info

6. **`mobile_app/lib/widgets/enhanced_post_card.dart`**
   - Modern post card widget
   - Shows "Edited" label with timestamps
   - Displays location badge
   - Integrated audio player for post music
   - Edit/Delete menu for post owners

### Modified Files

1. **`mobile_app/pubspec.yaml`**
   - Added `just_audio: ^0.9.32` - Audio playback library
   - Added `file_picker: ^8.1.0` - File selection for audio

2. **`mobile_app/lib/models.dart`**
   - Updated `Post` model with:
     - `location` field
     - `songUrl`, `songName`, `artist` fields
     - `createdAt`, `updatedAt` timestamps
     - `isEdited` boolean flag
   - Added `Story` model with music support
   - Added `Song` model for song data

3. **`mobile_app/lib/services/firebase_service.dart`**
   - Updated `createPost()` to accept location and music parameters
   - Added `updatePost()` method for post editing
   - Added timestamps (created_at, updated_at, is_edited)
   - Added music fields to Firestore documents

4. **`mobile_app/lib/app_state.dart`**
   - Updated `createPost()` to pass location and song
   - Added `updatePost()` method for editing posts
   - Updated method signatures to support Song objects

5. **`mobile_app/lib/screens/create_post_screen.dart`**
   - Added location input field (for feed posts only)
   - Added music selector widget
   - Integrated music selector into post creation flow
   - Updated `_handleShare()` to pass location and song
   - Added `dispose()` method for cleanup

6. **`mobile_app/lib/screens/story_view_screen.dart`**
   - Added import for `CompactAudioPlayerWidget`
   - Added music player UI to story viewer
   - Shows 🎵 icon and plays audio when story has music
   - Audio player positioned above reply field

7. **`firestore.rules`**
   - Updated Posts rule to allow owner edits
   - Updated Stories rule to allow owner updates
   - Added Songs collection with admin-only write access
   - Maintained security for like/comment operations

8. **`firebase+cloudinary.md`**
   - Comprehensive setup guide for new features
   - Database schema documentation
   - Instructions for creating songs collection
   - Optional audio upload to Cloudinary

9. **`README.md`**
   - Updated version to 3.2.0
   - Added music integration features section
   - Expanded content creation section
   - Highlighted new edit/music capabilities

---

## 🔧 Database Schema

### Posts Collection
```javascript
{
  post_id: "...",
  author_id: "uid123",
  username: "john_doe",
  author_avatar: "https://...",
  text: "Check out this amazing location!",
  media_url: "https://cloudinary.../image.jpg",
  location: "Central Park, NYC",               // NEW
  song_url: "https://cloudinary.../song.mp3", // NEW
  song_name: "Levitating",                    // NEW
  artist: "Dua Lipa",                         // NEW
  created_at: Timestamp,
  updated_at: Timestamp,                       // NEW - updates when edited
  is_edited: true,                            // NEW - flag for edited label
  likes: ["uid1", "uid2"],
  comments: [...],
  visibility: "public",
  visible_to_uids: []
}
```

### Stories Collection
```javascript
{
  story_id: "...",
  author_id: "uid123",
  username: "john_doe",
  author_avatar: "https://...",
  media_url: "https://cloudinary.../story.jpg",
  song_url: "https://cloudinary.../song.mp3", // NEW
  song_name: "Blinding Lights",               // NEW
  artist: "The Weeknd",                       // NEW
  created_at: Timestamp,
  expires_at: Timestamp                        // 24 hours from creation
}
```

### Songs Collection (NEW)
```javascript
{
  song_id: "...",
  name: "Levitating",
  artist: "Dua Lipa",
  url: "https://...",
  thumbnail_url: "https://..." (optional),
  created_at: Timestamp
}
```

---

## 🎛️ API Methods

### AppState Changes

```dart
// Existing method - now with music/location support
Future<void> createPost(
  String text,
  File? file,
  bool isStory, {
  String? visibility,
  List<String> visibleToUids = const [],
  String? location,        // NEW
  Song? song,              // NEW
}) async { ... }

// NEW METHOD - Edit existing posts
Future<void> updatePost({
  required String postId,
  String? description,
  String? location,
  File? newMediaFile,
  Song? song,
}) async { ... }
```

### Firebase Service Changes

```dart
// Updated to support location and music
Future<void> createPost({
  required String authorId,
  required String username,
  required String authorAvatar,
  required String text,
  required String mode,
  required String type,
  String? mediaUrl,
  String? thumbnailUrl,
  double duration = 0,
  String visibility = 'public',
  List<String> visibleToUids = const [],
  String? location,        // NEW
  String? songUrl,         // NEW
  String? songName,        // NEW
  String? artist,          // NEW
}) async { ... }

// NEW METHOD - Updates post fields
Future<void> updatePost({
  required String postId,
  String? text,
  String? location,
  String? mediaUrl,
  String? thumbnailUrl,
  String? songUrl,
  String? songName,
  String? artist,
}) async { ... }
```

### Music Service

```dart
// Get all songs
Future<List<Song>> getSongs()

// Get single song
Future<Song?> getSongById(String songId)

// Search songs
Future<List<Song>> searchSongs(String query)

// Stream of songs (real-time)
Stream<List<Song>> getSongsStream()

// Add song (admin only)
Future<String> addSong({
  required String name,
  required String artist,
  required String url,
  String? thumbnailUrl,
}) async { ... }
```

---

## 🎨 UI Components

### MusicSelectorWidget
- Full-screen dialog for song selection
- Search bar with real-time filtering
- Scrollable list of songs
- Visual feedback for selected song
- Clear selection button

### MusicSelectorButton
- Compact chip-style button
- Shows selected song info
- Click to open selector dialog
- Integrates seamlessly into forms

### AudioPlayerWidget
- Full-featured audio player
- Play/pause button
- Seek slider with current time display
- Song metadata display
- Close button to minimize

### CompactAudioPlayerWidget
- Minimal audio player for stories
- Single tap to play/pause
- Shows song name and artist
- Optimized for small screen space

### EnhancedPostCard
- Modern post card with all features
- "Edited" label for modified posts
- Location badge
- Audio player integrated
- Edit/Delete menu for owners
- Engagement stats (likes, comments, shares)

---

## 🔐 Security & Permissions

### Firestore Rules
- **Posts**: Owner can update their own posts; others can only affect likes/comments
- **Stories**: Owner can create, update, and delete their stories
- **Songs**: All signed-in users can read; admin-only writes

### Edit Protection
- Only post owner can edit their posts
- `updatePost()` verifies ownership via `author_id`
- Firebase rules enforce additional protection

---

## 📦 Dependencies

### New Packages Added
```yaml
just_audio: ^0.9.32          # Audio playback
file_picker: ^8.1.0          # File selection
```

### Already Included
```yaml
cloud_firestore: ^5.4.0      # Database
firebase_storage: (via Cloudinary)
image_picker: ^1.0.4         # Media pick
intl: ^0.19.0                # Date formatting
```

---

## 🚀 Usage Examples

### Create Post with Music & Location
```dart
final appState = Provider.of<AppState>(context, listen: false);

await appState.createPost(
  "Amazing sunset at the beach! 🌅",
  imageFile,
  false, // Not a story
  location: "Miami Beach, FL",
  song: selectedSong,
);
```

### Edit Existing Post
```dart
await appState.updatePost(
  postId: post.id,
  description: "Updated caption...",
  location: "New Location",
  song: newSong,
);
```

### Create Story with Music
```dart
await appState.createPost(
  "", // Empty text for stories
  videoFile,
  true, // isStory = true
  song: Song(
    id: "song-123",
    name: "Song Name",
    artist: "Artist",
    url: "https://...",
  ),
);
```

---

## 📱 Screens

### CreateStoryScreen
- Beautiful story upload interface
- Media picker (camera/gallery)
- Music selector integration
- Visual feedback for selections
- Upload button with progress indicator

### EditPostScreen
- Pre-filled form with post data
- Media change option
- Description/location editing
- Music selector
- Edit history display

### Enhanced Story Viewer
- Full-screen story display
- Music player UI
- Auto-play music when story opens
- Pause/resume controls
- Story progression indicators

---

## ⚙️ Configuration

### Optional: Add Songs to Firestore

Via Firebase Console:
1. Create `songs` collection
2. Add documents with fields:
   - `name` (string)
   - `artist` (string)
   - `url` (string - audio URL)
   - `thumbnail_url` (optional)

Or programmatically:
```dart
final musicService = MusicService();
await musicService.addSong(
  name: "Levitating",
  artist: "Dua Lipa",
  url: "https://cloudinary.../levitating.mp3",
  thumbnailUrl: "https://...",
);
```

---

## 🧪 Testing Checklist

- [ ] Create post with description + music
- [ ] Create post with location
- [ ] Edit post description
- [ ] Edit post location
- [ ] Change post music
- [ ] Create story with music
- [ ] Play story with music
- [ ] Test music search
- [ ] Verify "Edited" label appears
- [ ] Check timestamps are correct
- [ ] Verify only owner can edit
- [ ] Test story expiry (24 hours)

---

## 🎯 Future Enhancements

- [ ] Upload custom audio files to Cloudinary
- [ ] Lyrics support for songs
- [ ] Share post music to social media
- [ ] Music analytics (top songs)
- [ ] Create playlists from posts
- [ ] Collaborations/duets with music
- [ ] Audio effects/filters

---

For setup instructions, see [firebase+cloudinary.md](firebase+cloudinary.md)  
For full project info, see [README.md](README.md)
