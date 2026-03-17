import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/music_service.dart';
import '../widgets/audio_player_widget.dart';

/// Song Library: Default songs + User uploaded songs with CRUD
class SongListScreen extends StatefulWidget {
  const SongListScreen({Key? key}) : super(key: key);

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  final MusicService _musicService = MusicService();
  final TextEditingController _searchController = TextEditingController();
  bool _isUploading = false;
  String? _uploadError;
  List<Song> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() {});
  }

  void _filterSongs() {
    setState(() {});
  }

  Future<void> _uploadNewSong() async {
    final titleController = TextEditingController();
    final artistController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Song'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Song Title',
                  hintText: 'e.g., My Awesome Song',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: artistController,
                decoration: const InputDecoration(
                  labelText: 'Artist Name',
                  hintText: 'e.g., Your Name',
                ),
              ),
              const SizedBox(height: 16),
              if (_uploadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _uploadError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  artistController.text.isEmpty) {
                setState(() => _uploadError = 'Please fill all fields');
                return;
              }

              setState(() {
                _isUploading = true;
                _uploadError = null;
              });

              try {
                await _musicService.uploadSong(
                  title: titleController.text,
                  artist: artistController.text,
                );

                _loadSongs();
                if (mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song uploaded successfully!')),
                  );
                }
              } catch (e) {
                setState(() => _uploadError = e.toString());
              } finally {
                setState(() => _isUploading = false);
              }
            },
            child: _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Upload'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadSongs();
    }
  }

  Future<void> _editSong(Song song) async {
    final titleController = TextEditingController(text: song.name);
    final artistController = TextEditingController(text: song.artist);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Song'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Song Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: artistController,
                decoration: const InputDecoration(labelText: 'Artist Name'),
              ),
              const SizedBox(height: 16),
              if (_uploadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _uploadError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _uploadError = null);

              try {
                await _musicService.updateSong(
                  songId: song.id,
                  title: titleController.text,
                  artist: artistController.text,
                );

                _loadSongs();
                if (mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Song updated successfully!')),
                  );
                }
              } catch (e) {
                setState(() => _uploadError = e.toString());
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadSongs();
    }
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song?'),
        content: Text('Are you sure you want to delete "${song.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _musicService.deleteSong(song.id);
        _loadSongs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Library'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Song>>(
        stream: _musicService.getAllSongsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final allSongs = snapshot.data ?? [];
          
          // Filter by search
          final searchQuery = _searchController.text.toLowerCase();
          final filteredSongs = allSongs
              .where((song) =>
                  song.name.toLowerCase().contains(searchQuery) ||
                  song.artist.toLowerCase().contains(searchQuery))
              .toList();

          // Separate default and user songs
          final defaultSongs =
              filteredSongs.where((s) => s.isDefault()).toList();
          final userSongs = filteredSongs.where((s) => !s.isDefault()).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search songs or artists...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              // Songs list
              Expanded(
                child: filteredSongs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note_outlined,
                                size: 64,
                                color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No songs found'),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          // DEFAULT SONGS SECTION
                          if (defaultSongs.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Default Songs',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...defaultSongs
                                .map((song) => _buildSongCard(song))
                                .toList(),
                            const SizedBox(height: 16),
                          ],
                          // USER SONGS SECTION
                          if (userSongs.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                'My Songs',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...userSongs
                                .map((song) => _buildSongCard(song,
                                    isUserSong: true))
                                .toList(),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadNewSong,
        tooltip: 'Upload Song',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSongCard(Song song, {bool isUserSong = false}) {
    final appState = context.read<AppState>();
    final currentUid = appState.currentUser?.uid;
    final isOwner = currentUid != null && song.isOwnedBy(currentUid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade300,
                    Colors.deepPurple.shade600,
                  ],
                ),
              ),
              child: const Icon(Icons.music_note,
                  color: Colors.white),
            ),
            title: Text(song.name),
            subtitle: Text(song.artist),
            trailing: !isUserSong
                ? null
                : PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                        onTap: () => _editSong(song),
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        onTap: () => _deleteSong(song),
                      ),
                    ],
                  ),
          ),
          // Audio player
          if (song.url.isNotEmpty)
            Container(
              color: Colors.grey.shade100,
              child: CompactAudioPlayerWidget(audioUrl: song.url, songName: song.name, artist: song.artist),
            ),
        ],
      ),
    );
  }
}
