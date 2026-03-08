import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/firebase_service.dart';
import 'group_chat_detail_screen.dart';

/// Screen to create a new group chat by selecting from accepted connections.
class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedUids = {};
  final Map<String, AppUser> _userCache = {};
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter a group name")));
      return;
    }
    if (_selectedUids.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least 2 members")));
      return;
    }

    setState(() => _loading = true);
    final state = Provider.of<AppState>(context, listen: false);
    final groupId =
        await state.createGroupChat(name, _selectedUids.toList());
    setState(() => _loading = false);

    if (groupId != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatDetailScreen(
            groupId: groupId,
            groupName: name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final connectedUids = state.connectedUids;

    return Scaffold(
      appBar: AppBar(
        title: const Text("New Group Chat"),
        actions: [
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
                  onPressed: _create,
                  child: const Text("Create",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: "Group Name",
                prefixIcon: const Icon(LucideIcons.users),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Members (${_selectedUids.length} selected)",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: connectedUids.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.userX,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text("No connections yet",
                            style: TextStyle(color: Colors.grey)),
                        const Text("Connect with people to create a group",
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: connectedUids.length,
                    itemBuilder: (ctx, i) {
                      final uid = connectedUids[i];
                      final selected = _selectedUids.contains(uid);

                      // Load user info
                      if (!_userCache.containsKey(uid)) {
                        FirebaseService().getUser(uid).then((u) {
                          if (u != null && mounted) {
                            setState(() => _userCache[uid] = u);
                          }
                        });
                      }
                      final user = _userCache[uid];
                      final name = user?.username ?? uid;
                      final avatar =
                          user?.getAvatar(state.isFormal) ?? '';

                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedUids.add(uid);
                            } else {
                              _selectedUids.remove(uid);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar.isEmpty
                              ? Text(name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: user?.headline.isNotEmpty == true
                            ? Text(user!.headline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
