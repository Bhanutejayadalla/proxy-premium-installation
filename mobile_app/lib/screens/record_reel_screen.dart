import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../constants.dart';

class RecordReelScreen extends StatefulWidget {
  const RecordReelScreen({super.key});
  @override
  State<RecordReelScreen> createState() => _RecordReelScreenState();
}

class _RecordReelScreenState extends State<RecordReelScreen> {
  File? _videoFile;
  final _captionCtrl = TextEditingController();
  bool _uploading = false;
  String? _statusMessage;

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final video = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (video != null) {
        final file = File(video.path);
        final sizeMB = await file.length() / (1024 * 1024);
        setState(() {
          _videoFile = file;
          _statusMessage =
              'Video selected (${sizeMB.toStringAsFixed(1)} MB)';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick video: $e')),
        );
      }
    }
  }

  Future<void> _upload() async {
    if (_videoFile == null) return;
    setState(() {
      _uploading = true;
      _statusMessage = 'Uploading video...';
    });
    try {
      final state = Provider.of<AppState>(context, listen: false);
      await state.createReel(_captionCtrl.text, _videoFile!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reel uploaded!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Upload failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Retry', onPressed: _upload),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color =
        state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Reel'),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Share',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: color)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // STATUS MESSAGE
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (_uploading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    Expanded(
                      child: Text(_statusMessage!,
                          style: TextStyle(color: color, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // VIDEO PREVIEW
            SizedBox(
              height: 350,
              child: _videoFile != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(Icons.play_circle_outline,
                                size: 64, color: Colors.white54),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          child: Text(
                            _videoFile!.path.split('/').last,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text('Select a video to create a reel'),
                            const SizedBox(height: 4),
                            Text('Max 60 seconds, 100 MB',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // CAPTION
            TextField(
              controller: _captionCtrl,
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // PICK BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: _uploading
                      ? null
                      : () => _pickVideo(ImageSource.gallery),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: _uploading
                      ? null
                      : () => _pickVideo(ImageSource.camera),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
