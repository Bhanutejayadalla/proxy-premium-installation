import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class RecordReelScreen extends StatefulWidget {
  const RecordReelScreen({super.key});
  @override
  State<RecordReelScreen> createState() => _RecordReelScreenState();
}

class _RecordReelScreenState extends State<RecordReelScreen> {
  File? _videoFile;
  final _captionCtrl = TextEditingController();
  bool _uploading = false;

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (video != null) {
      setState(() => _videoFile = File(video.path));
    }
  }

  Future<void> _upload() async {
    if (_videoFile == null) return;
    setState(() => _uploading = true);
    try {
      final state = Provider.of<AppState>(context, listen: false);
      await state.createReel(_captionCtrl.text, _videoFile!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Reel uploaded!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Reel"),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Share",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // VIDEO PREVIEW
            Expanded(
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
                            const Text("Select a video to create a reel"),
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
                hintText: "Write a caption...",
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
                  label: const Text("Gallery"),
                  onPressed: () => _pickVideo(ImageSource.gallery),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text("Record"),
                  onPressed: () => _pickVideo(ImageSource.camera),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
