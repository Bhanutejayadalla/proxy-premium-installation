import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/music_service.dart';

/// Music selector widget for posts and stories
/// Returns selected Song or null
class MusicSelectorWidget extends StatefulWidget {
  final Function(Song?)? onSelected;
  final Song? initialSong;

  const MusicSelectorWidget({
    super.key,
    this.onSelected,
    this.initialSong,
  });

  @override
  State<MusicSelectorWidget> createState() => _MusicSelectorWidgetState();
}

class _MusicSelectorWidgetState extends State<MusicSelectorWidget> {
  final _musicService = MusicService();
  Song? _selectedSong;
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _isUploadingSong = false;
  String? _uploadError;
  final _searchCtrl = TextEditingController();
  List<Song> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _selectedSong = widget.initialSong;
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final songs = await _musicService.getAllSongs();
      setState(() {
        _songs = songs;
        _filteredSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading songs: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterSongs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSongs = _songs;
      } else {
        _filteredSongs = _songs
            .where((song) =>
                song.name.toLowerCase().contains(query.toLowerCase()) ||
                song.artist.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectSong(Song song) {
    setState(() => _selectedSong = song);
    widget.onSelected?.call(song);
    Navigator.pop(context);
  }

  void _clearSelection() {
    setState(() => _selectedSong = null);
    widget.onSelected?.call(null);
    Navigator.pop(context);
  }

  Future<void> _uploadCustomSong() async {
    if (_isUploadingSong) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _uploadError = 'Please login to upload a song');
      return;
    }

    setState(() {
      _isUploadingSong = true;
      _uploadError = null;
    });

    try {
      // Just pick file directly - no dialogs
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isUploadingSong = false);
        return;
      }

      final pickedFile = File(result.files.first.path!);
      final fileName = result.files.first.name;
      
      // Extract title from filename (remove extension)
      final title = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      // Upload directly to Cloudinary with title as filename
      final uploadedSong = await _musicService.uploadSong(
        title: title,
        artist: 'Unknown',
        file: pickedFile,
      );

      if (!mounted) return;
      setState(() {
        _isUploadingSong = false;
        _uploadError = null;
        _songs.add(uploadedSong);
        _filteredSongs = _songs;
      });
      _selectSong(uploadedSong);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingSong = false;
        _uploadError = 'Upload failed: ${e.toString()}';
      });
      debugPrint('Custom song upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎵 Select Music',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchCtrl,
              onChanged: _filterSongs,
              decoration: InputDecoration(
                hintText: 'Search songs or artists...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUploadingSong ? null : _uploadCustomSong,
                icon: _isUploadingSong
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingSong
                    ? 'Uploading your song...'
                    : 'Upload Your Own Song'),
              ),
            ),
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _uploadError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),

            // Songs list
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_filteredSongs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _songs.isEmpty ? 'No songs available' : 'No songs found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _filteredSongs.length,
                  itemBuilder: (context, index) {
                    final song = _filteredSongs[index];
                    final isSelected = _selectedSong?.id == song.id;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.blue.withValues(alpha: 0.2),
                      leading: const Icon(Icons.music_note),
                      title: Text(song.name),
                      subtitle: Text(song.artist),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () => _selectSong(song),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Clear button (if song selected)
            if (_selectedSong != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                  ),
                  onPressed: _clearSelection,
                  child: const Text(
                    'Clear Music',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

/// Mini music selector button for UI
class MusicSelectorButton extends StatefulWidget {
  final Function(Song?)? onSelected;
  final Song? selectedSong;

  const MusicSelectorButton({
    super.key,
    this.onSelected,
    this.selectedSong,
  });

  @override
  State<MusicSelectorButton> createState() => _MusicSelectorButtonState();
}

class _MusicSelectorButtonState extends State<MusicSelectorButton> {
  @override
  Widget build(BuildContext context) {
    final hasSong = widget.selectedSong != null;

    return GestureDetector(
      onTap: () async {
        await showDialog(
          context: context,
          builder: (ctx) => MusicSelectorWidget(
            onSelected: widget.onSelected,
            initialSong: widget.selectedSong,
          ),
        );
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasSong ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasSong ? Colors.blue : Colors.grey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note,
              size: 16,
              color: hasSong ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            if (hasSong)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selectedSong!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.selectedSong!.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Add Music',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
