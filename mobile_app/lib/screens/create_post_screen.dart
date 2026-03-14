import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../constants.dart';
import '../models.dart';

class CreatePostScreen extends StatefulWidget {
  final bool initialIsStory;
  const CreatePostScreen({super.key, this.initialIsStory = false});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _text = TextEditingController();
  File? _file;
  late bool isStory;
  bool _isPosting = false;
  String _postVisibility = 'public';
  final Set<String> _selectedVisibleUids = {};

  @override
  void initState() {
    super.initState();
    isStory = widget.initialIsStory;
  }

  Future<void> _handleShare() async {
    if (_isPosting) return;
    if (_text.text.trim().isEmpty && _file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add some text or media to share")),
      );
      return;
    }
    setState(() => _isPosting = true);
    try {
      await Provider.of<AppState>(context, listen: false)
          .createPost(
          _text.text,
          _file,
          isStory,
          visibility: _postVisibility,
          visibleToUids: _postVisibility == 'selected_connections'
            ? _selectedVisibleUids.toList()
            : const [],
          );
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

  Future<void> _pickVisibleConnections(AppState state) async {
    final users = await Future.wait(
      state.connectedUids.map((uid) => state.firebase.getUser(uid)),
    );
    final connected = users.whereType<AppUser>().toList()
      ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

    if (!mounted) return;
    final selected = Set<String>.from(_selectedVisibleUids);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Choose connections'),
          content: SizedBox(
            width: 360,
            height: 420,
            child: connected.isEmpty
                ? const Center(
                    child: Text('No connections yet',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: connected.length,
                    itemBuilder: (_, i) {
                      final u = connected[i];
                      final checked = selected.contains(u.uid);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) {
                              selected.add(u.uid);
                            } else {
                              selected.remove(u.uid);
                            }
                          });
                        },
                        title: Text(u.username),
                        subtitle: Text(u.fullName.isEmpty ? u.uid : u.fullName),
                        secondary: CircleAvatar(
                          backgroundImage: u.getAvatar(state.isFormal).isNotEmpty
                              ? NetworkImage(u.getAvatar(state.isFormal))
                              : null,
                          child: u.getAvatar(state.isFormal).isEmpty
                              ? Text(u.username.isNotEmpty
                                  ? u.username[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedVisibleUids
                    ..clear()
                    ..addAll(selected);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color =
        state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final modeName = state.isFormal ? 'Pro' : 'Social';

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
                : Text("Share",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color)),
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
                    // MODE INDICATOR
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Posting to $modeName mode',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                    const SizedBox(height: 12),

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
                    const SizedBox(height: 14),
                    if (!isStory)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Who can see this post?',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Public'),
                                selected: _postVisibility == 'public',
                                onSelected: (_) => setState(() {
                                  _postVisibility = 'public';
                                  _selectedVisibleUids.clear();
                                }),
                              ),
                              ChoiceChip(
                                label: const Text('Connections'),
                                selected: _postVisibility == 'connections',
                                onSelected: (_) => setState(() {
                                  _postVisibility = 'connections';
                                  _selectedVisibleUids.clear();
                                }),
                              ),
                              ChoiceChip(
                                label: const Text('Selected connections'),
                                selected:
                                    _postVisibility == 'selected_connections',
                                onSelected: (_) async {
                                  setState(() => _postVisibility =
                                      'selected_connections');
                                  await _pickVisibleConnections(state);
                                },
                              ),
                            ],
                          ),
                          if (_postVisibility == 'selected_connections')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Text(
                                      '${_selectedVisibleUids.length} selected',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () =>
                                        _pickVisibleConnections(state),
                                    child: const Text('Choose people'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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