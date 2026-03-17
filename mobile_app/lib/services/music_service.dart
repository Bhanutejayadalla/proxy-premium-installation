import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models.dart';
import 'cloudinary_service.dart';

/// Service to manage songs using Cloudinary for storage + Firestore for metadata
/// - Default songs: created by admin, no userId
/// - User songs: created by users, have userId for ownership
class MusicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  static const String _songsPath = 'songs';

  // ═══════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Get all songs: default + user-uploaded
  Future<List<Song>> getAllSongs() async {
    try {
      final snapshot = await _firestore
          .collection(_songsPath)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[MusicService] Error fetching all songs: $e');
      return [];
    }
  }

  /// Get only default songs (no userId)
  Future<List<Song>> getDefaultSongs() async {
    try {
      // Simplified: get all songs and filter in-app to avoid Firestore composite index issue
      final snapshot = await _firestore
          .collection(_songsPath)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromFirestore(doc))
          .where((song) => song.userId == null)
          .toList();
    } catch (e) {
      debugPrint('[MusicService] Error fetching default songs: $e');
      return [];
    }
  }

  /// Get user-uploaded songs
  Future<List<Song>> getUserSongs(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_songsPath)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[MusicService] Error fetching user songs: $e');
      return [];
    }
  }

  /// Get real-time stream of all songs
  Stream<List<Song>> getAllSongsStream() {
    return _firestore
        .collection(_songsPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList());
  }

  /// Get a single song by ID
  Future<Song?> getSongById(String songId) async {
    try {
      final doc = await _firestore
          .collection(_songsPath)
          .doc(songId)
          .get();

      if (doc.exists) {
        return Song.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('[MusicService] Error fetching song: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UPLOAD OPERATIONS (Cloudinary + Firestore)
  // ═══════════════════════════════════════════════════════════════

  /// Upload audio to Cloudinary + save metadata to Firestore
  /// If file is provided, uses it directly. Otherwise shows file picker.
  Future<Song> uploadSong({
    required String title,
    required String artist,
    String? imageUrl,
    File? file,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Use provided file or pick from device
      File audioFile;
      if (file != null) {
        audioFile = file;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
        );

        if (result == null || result.files.isEmpty) {
          throw Exception('No file selected');
        }

        audioFile = File(result.files.first.path!);
      }

      debugPrint('[MusicService] Selected file: ${audioFile.path}');

      // Upload to Cloudinary (their secure_url is returned)
      debugPrint('[MusicService] Uploading to Cloudinary...');
      final fileName = audioFile.path.split('/').last;
      final audioUrl = await _cloudinary.uploadFile(
        audioFile,
        'songs/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      debugPrint('[MusicService] Cloudinary URL: $audioUrl');

      // Save metadata to Firestore
      final docRef = await _firestore.collection(_songsPath).add({
        'title': title,
        'artist': artist,
        'audioUrl': audioUrl,
        'imageUrl': imageUrl,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[MusicService] Song saved to Firestore: ${docRef.id}');

      // Return newly created song
      return Song(
        id: docRef.id,
        name: title, // For compatibility with Song model
        artist: artist,
        url: audioUrl,
        thumbnailUrl: imageUrl,
        userId: uid,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[MusicService] Error uploading song: $e');
      throw Exception('Failed to upload song: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UPDATE OPERATIONS (Owner Only)
  // ═══════════════════════════════════════════════════════════════

  /// Update song (owner only)
  Future<void> updateSong({
    required String songId,
    required String title,
    required String artist,
    String? imageUrl,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Fetch song
      final song = await getSongById(songId);
      if (song == null) {
        throw Exception('Song not found');
      }

      // Verify ownership
      if (song.userId != uid) {
        throw Exception('Only song owner can edit this song');
      }

      // Update Firestore
      await _firestore.collection(_songsPath).doc(songId).update({
        'title': title,
        'artist': artist,
        'imageUrl': imageUrl,
      });

      debugPrint('[MusicService] Song updated: $songId');
    } catch (e) {
      debugPrint('[MusicService] Error updating song: $e');
      throw Exception('Failed to update song: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DELETE OPERATIONS (Owner Only, Not for Default Songs)
  // ═══════════════════════════════════════════════════════════════

  /// Delete song (owner only, cannot delete default songs)
  Future<void> deleteSong(String songId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Fetch song
      final song = await getSongById(songId);
      if (song == null) {
        throw Exception('Song not found');
      }

      // Prevent deletion of default songs
      if (song.userId == null) {
        throw Exception('Cannot delete default songs');
      }

      // Verify ownership
      if (song.userId != uid) {
        throw Exception('Only song owner can delete this song');
      }

      // Delete from Firestore
      await _firestore.collection(_songsPath).doc(songId).delete();

      debugPrint('[MusicService] Song deleted: $songId');
    } catch (e) {
      debugPrint('[MusicService] Error deleting song: $e');
      throw Exception('Failed to delete song: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH & FILTER
  // ═══════════════════════════════════════════════════════════════

  /// Search all songs by title or artist
  Future<List<Song>> searchSongs(String query) async {
    try {
      if (query.isEmpty) {
        return getAllSongs();
      }

      final allSongs = await getAllSongs();
      final lowerQuery = query.toLowerCase();

      return allSongs
          .where((song) =>
              song.name.toLowerCase().contains(lowerQuery) ||
              song.artist.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      debugPrint('[MusicService] Error searching songs: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ADD DEMO SONGS (Call once to initialize)
  // ═══════════════════════════════════════════════════════════════

  /// Add demo songs to Firestore (userId = null for default songs)
  /// These are free music URLs from reliable CDNs that support CORS
  Future<void> addDemoSongs() async {
    try {
      debugPrint('[MusicService] Adding demo songs...');

      // Check if demo songs already exist
      final existing = await _firestore
          .collection(_songsPath)
          .where('userId', isEqualTo: null)
          .get();
      
      if (existing.docs.isNotEmpty) {
        debugPrint('[MusicService] Demo songs already exist. Skipping...');
        return;
      }

      final demoSongs = [
        {
          'title': 'Summer Breeze',
          'artist': 'Bensound',
          'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          'userId': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Epic',
          'artist': 'Bensound',
          'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          'userId': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Ukulele',
          'artist': 'Bensound',
          'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
          'userId': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Ambient',
          'artist': 'Bensound',
          'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
          'userId': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Happiness',
          'artist': 'Bensound',
          'audioUrl': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
          'userId': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final song in demoSongs) {
        await _firestore.collection(_songsPath).add(song);
      }

      debugPrint('[MusicService] Demo songs added successfully');
    } catch (e) {
      debugPrint('[MusicService] Error adding demo songs: $e');
    }
  }
}
