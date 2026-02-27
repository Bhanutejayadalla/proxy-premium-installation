import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _fullName;
  late TextEditingController _headline;
  late TextEditingController _bio;
  late TextEditingController _skillsCtrl;
  late bool _openToWork;
  late bool _hiring;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppState>(context, listen: false).currentUser!;
    _fullName = TextEditingController(text: user.fullName);
    _headline = TextEditingController(text: user.headline);
    _bio = TextEditingController(text: user.bio);
    _skillsCtrl = TextEditingController(text: user.skills.join(', '));
    _openToWork = user.openToWork;
    _hiring = user.hiring;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _headline.dispose();
    _bio.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final state = Provider.of<AppState>(context, listen: false);
      final skills = _skillsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await state.updateProfile({
        'full_name': _fullName.text.trim(),
        'headline': _headline.text.trim(),
        'bio': _bio.text.trim(),
        'skills': skills,
        'open_to_work': _openToWork,
        'hiring': _hiring,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Profile updated")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar(bool isFormal) async {
    final state = Provider.of<AppState>(context, listen: false);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    await state.uploadAvatar(File(x.path), isFormal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${isFormal ? 'Formal' : 'Casual'} avatar updated")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final user = state.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Save",
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVATARS
            const Text("Avatars",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _avatarPicker("Formal", user.avatarFormal, true),
                _avatarPicker("Casual", user.avatarCasual, false),
              ],
            ),
            const SizedBox(height: 24),

            // FIELDS
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                  labelText: "Full Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _headline,
              decoration: const InputDecoration(
                  labelText: "Headline",
                  hintText: "e.g. Flutter Developer at Proxi",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bio,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: "Bio", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _skillsCtrl,
              decoration: const InputDecoration(
                  labelText: "Skills",
                  hintText: "Flutter, Dart, Firebase (comma separated)",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            // TOGGLES
            const Text("Status",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text("Open to Work"),
              subtitle: const Text("Let others know you're available"),
              value: _openToWork,
              onChanged: (v) => setState(() => _openToWork = v),
            ),
            SwitchListTile(
              title: const Text("Hiring"),
              subtitle: const Text("Show that you're looking for talent"),
              value: _hiring,
              onChanged: (v) => setState(() => _hiring = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPicker(String label, String url, bool isFormal) {
    return GestureDetector(
      onTap: () => _pickAvatar(isFormal),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty
                ? const Icon(LucideIcons.camera, size: 28)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
