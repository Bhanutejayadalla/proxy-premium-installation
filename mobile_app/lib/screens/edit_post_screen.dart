import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../widgets/music_selector_widget.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _descriptionCtrl;
  late TextEditingController _locationCtrl;
  Song? _selectedSong;
  File? _newMediaFile;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _descriptionCtrl = TextEditingController(text: widget.post.text);
    _locationCtrl = TextEditingController(text: widget.post.location ?? '');
    
    if (widget.post.songUrl != null) {
      _selectedSong = Song(
        id: 'current',
        name: widget.post.songName ?? 'Unknown',
        artist: widget.post.artist ?? 'Unknown',
        url: widget.post.songUrl!,
      );
    }
  }

  Future<void> _pickNewMedia() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _newMediaFile = File(pickedFile.path));
      }
    }
  }

  void _removeNewMedia() {
    setState(() => _newMediaFile = null);
  }

  Future<void> _updatePost() async {
    if (_descriptionCtrl.text.trim().isEmpty && widget.post.mediaUrl == null && _newMediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post cannot be empty')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final state = Provider.of<AppState>(context, listen: false);
      final trimmedLocation = _locationCtrl.text.trim();
      final shouldClearLocation =
          (widget.post.location ?? '').isNotEmpty && trimmedLocation.isEmpty;
      final shouldClearSong =
          (widget.post.songUrl ?? '').isNotEmpty && _selectedSong == null;

      debugPrint(
        '[EditPostScreen] postId=${widget.post.id} clearLocation=$shouldClearLocation clearSong=$shouldClearSong newSong=${_selectedSong?.name}',
      );

      await state.updatePost(
        postId: widget.post.id,
        description: _descriptionCtrl.text.trim(),
        location: trimmedLocation.isEmpty ? null : trimmedLocation,
        newMediaFile: _newMediaFile,
        song: _selectedSong,
        clearLocation: shouldClearLocation,
        clearSong: shouldClearSong,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original media preview (read-only)
            if (widget.post.mediaUrl != null && _newMediaFile == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: _pickNewMedia,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade200,
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          widget.post.mediaUrl!,
                          fit: BoxFit.cover,
                          height: 250,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(
                                height: 250,
                                child: Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to change media',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // New media preview
            if (_newMediaFile != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _newMediaFile!,
                        fit: BoxFit.cover,
                        height: 250,
                        width: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeNewMedia,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Change media button
            if (widget.post.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _pickNewMedia,
                  icon: const Icon(Icons.image),
                  label: const Text('Change Media'),
                ),
              ),

            // Description field
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Location field
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add a location (optional)',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Music selector
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Music',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (ctx) => MusicSelectorWidget(
                          onSelected: (song) {
                            setState(() => _selectedSong = song);
                          },
                          initialSong: _selectedSong,
                        ),
                      );
                    },
                    child: MusicSelectorButton(
                      selectedSong: _selectedSong,
                      onSelected: (song) {
                        setState(() => _selectedSong = song);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Edit info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Editing this post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Original post created: ${widget.post.createdAt?.toString().split('.')[0]}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (widget.post.isEdited)
                    Text(
                      'Last edited: ${widget.post.updatedAt?.toString().split('.')[0]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'An "Edited" label will appear on this post when saved.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Update button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updatePost,
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }
}
