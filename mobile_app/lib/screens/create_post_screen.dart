import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _text = TextEditingController();
  File? _file;
  bool isStory = false;
  bool _isPosting = false;

  Future<void> _handleShare() async {
    if (_isPosting) return;
    setState(() => _isPosting = true);
    try {
      await Provider.of<AppState>(context, listen: false)
          .createPost(_text.text, _file, isStory);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to share: $e")),
        );
      }
    }
    if (mounted) setState(() => _isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("New Post"),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _handleShare,
            child: _isPosting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Share",
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ChoiceChip(
                        label: const Text("Feed Post"),
                        selected: !isStory,
                        onSelected: (v) => setState(() => isStory = false),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Story"),
                        selected: isStory,
                        onSelected: (v) => setState(() => isStory = true),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _text,
                      decoration: const InputDecoration(
                        hintText: "What's happening?",
                        border: InputBorder.none,
                      ),
                      maxLines: 5,
                    ),
                    if (_file != null) ...[
                      const SizedBox(height: 12),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_file!,
                                height: 200, fit: BoxFit.cover),
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black54,
                              child:
                                  Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                            onPressed: () => setState(() => _file = null),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text("Photo"),
                    onPressed: () async {
                      final x = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (x != null) setState(() => _file = File(x.path));
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    onPressed: () async {
                      final x = await ImagePicker()
                          .pickImage(source: ImageSource.camera);
                      if (x != null) setState(() => _file = File(x.path));
                    },
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