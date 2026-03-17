import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../widgets/music_selector_widget.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _mediaFile;
  Song? _selectedSong;
  bool _isUploading = false;

  Future<void> _pickMedia() async {
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
        setState(() => _mediaFile = File(pickedFile.path));
      }
    }
  }

  void _removeMedia() {
    setState(() => _mediaFile = null);
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image or video')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final state = Provider.of<AppState>(context, listen: false);
      await state.createPost(
        '', // Empty description for stories
        _mediaFile,
        true, // isStory = true
        song: _selectedSong,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story uploaded! 🎉')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading story: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Story'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: const Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stories disappear after 24 hours. Add a song to make it more engaging!',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            // Media picker area
            GestureDetector(
              onTap: _mediaFile == null ? _pickMedia : null,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: _mediaFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to add a photo or video',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Recommended: Square or vertical orientation',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _mediaFile!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 300,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeMedia,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Change media button
            if (_mediaFile != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.change_circle_outlined),
                  label: const Text('Change Media'),
                ),
              ),

            const SizedBox(height: 16),

            // Music section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.music_note, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Add Music to Your Story',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  if (_selectedSong != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSong!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _selectedSong!.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Upload button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isUploading ? null : _uploadStory,
                child: _isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Share Story (24hr)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Privacy info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your story is visible to all your followers for 24 hours.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
