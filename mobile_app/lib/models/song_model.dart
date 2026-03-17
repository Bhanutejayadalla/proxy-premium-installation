import 'package:cloud_firestore/cloud_firestore.dart';

/// Song model for music app
/// - Default songs: no userId
/// - User uploaded songs: has userId
class Song {
  final String id;
  final String title;
  final String artist;
  final String audioUrl; // Cloudinary secure_url
  final String? imageUrl; // Optional thumbnail
  final String? userId; // null for default songs, uid for user songs
  final DateTime createdAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.imageUrl,
    this.userId,
    required this.createdAt,
  });

  /// Check if this song belongs to a specific user
  bool isOwnedBy(String uid) => userId == uid;

  /// Check if this is a default song (no owner)
  bool isDefault() => userId == null;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'userId': userId,
      'createdAt': createdAt,
    };
  }

  /// Convert from Firestore snapshot
  factory Song.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Song(
      id: doc.id,
      title: data['title'] ?? 'Unknown',
      artist: data['artist'] ?? 'Unknown',
      audioUrl: data['audioUrl'] ?? '',
      imageUrl: data['imageUrl'],
      userId: data['userId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with modified fields
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? audioUrl,
    String? imageUrl,
    String? userId,
    DateTime? createdAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Song(id: $id, title: $title, artist: $artist)';
}
