import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import 'chat_detail_screen.dart';
import 'create_group_chat_screen.dart';
import 'group_chat_detail_screen.dart';
import 'mesh_chat_screen.dart';

bool _isMoodActiveUser(AppUser? user) {
  if (user == null) return false;
  if (user.moodStatus.trim().isEmpty) return false;
  if (user.moodExpiresAt == null) return false;
  return user.moodExpiresAt!.isAfter(DateTime.now());
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Future<void> _showMoodPicker(BuildContext context, AppState state) async {
    final moodOptions = <String>['Studying', 'Available', 'Busy'];
    final durationOptions = <Duration>[
      const Duration(minutes: 30),
      const Duration(hours: 2),
      const Duration(hours: 8),
    ];

    String selectedMood = moodOptions.first;
    Duration selectedDuration = durationOptions[1];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Set Mood Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedMood,
                items: moodOptions
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setLocal(() => selectedMood = v ?? moodOptions.first),
                decoration: const InputDecoration(labelText: 'Mood'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Duration>(
                initialValue: selectedDuration,
                items: durationOptions
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.inMinutes < 60
                              ? '${d.inMinutes} mins'
                              : '${d.inHours} hours'),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => selectedDuration = v ?? durationOptions[1]),
                decoration: const InputDecoration(labelText: 'Duration'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await state.clearMoodStatus();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await state.setMoodStatus(selectedMood, selectedDuration);
                if (ctx.mounted) Navigator.pop(ctx);
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
    final state = Provider.of<AppState>(context);
    final myUid = state.currentUser?.uid ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Messages (${state.isFormal ? 'Pro' : 'Social'})"),
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              tooltip: 'Set mood status',
              onPressed: () => _showMoodPicker(context, state),
            ),
            // Mesh broadcast shortcut
            Tooltip(
              message: 'Mesh Broadcast (offline)',
              child: IconButton(
                icon: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Icon(Icons.bluetooth),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MeshChatScreen(
                        targetUid: 'broadcast',
                        targetName: 'Nearby Mesh Devices',
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.users),
              tooltip: "New Group",
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateGroupChatScreen())),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Direct"),
              Tab(text: "Groups"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Direct Messages ──
            _DirectChatsTab(myUid: myUid, state: state),
            // ── Group Chats ──
            _GroupChatsTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _DirectChatsTab extends StatelessWidget {
  final String myUid;
  final AppState state;
  const _DirectChatsTab({required this.myUid, required this.state});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.conversationsStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error.toString();
          // Firestore missing-index errors contain a URL to create the index
          if (err.contains('indexes?create_composite')) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build, size: 48, color: Colors.orange),
                    SizedBox(height: 12),
                    Text(
                      "Firestore index not yet created.\n"
                      "Ask the admin to deploy indexes:\n"
                      "firebase deploy --only firestore:indexes",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Text("Error: $err",
                style: const TextStyle(color: Colors.red)));
        }
        final convos = snap.data ?? [];
        if (convos.isEmpty) {
          return const Center(
              child: Text("No conversations yet.\nConnect with people nearby!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          itemCount: convos.length,
          itemBuilder: (ctx, i) {
            final c = convos[i];
            final participants =
                List<String>.from(c['participants'] ?? []);
            final otherUid =
                participants.firstWhere((p) => p != myUid, orElse: () => '');
            final lastMsg = c['last_message'] ?? '';

            return FutureBuilder(
              future: state.firebase.getUser(otherUid),
              builder: (ctx, userSnap) {
                final otherUser = userSnap.data;
                final name = otherUser?.username ?? otherUid;
                final avatar =
                    otherUser?.getAvatar(state.isFormal) ?? '';
                final moodActive = _isMoodActiveUser(otherUser);
                final moodText = moodActive
                  ? '${otherUser!.moodStatus} until ${DateFormat('h:mm a').format(otherUser.moodExpiresAt!.toLocal())}'
                  : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (moodActive)
                        Container(
                          margin: const EdgeInsets.only(top: 2, bottom: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            moodText,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      Text(lastMsg,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                              targetUser: name, targetUid: otherUid))),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GroupChatsTab extends StatelessWidget {
  final AppState state;
  const _GroupChatsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.groupChatsStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error.toString();
          if (err.contains('indexes?create_composite')) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build, size: 48, color: Colors.orange),
                    SizedBox(height: 12),
                    Text(
                      "Firestore index not yet created.\n"
                      "Ask the admin to deploy indexes:\n"
                      "firebase deploy --only firestore:indexes",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Text("Error: $err",
                style: const TextStyle(color: Colors.red)));
        }
        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.users, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text("No group chats yet",
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(LucideIcons.plusCircle, size: 18),
                  label: const Text("Create Group"),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateGroupChatScreen())),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (ctx, i) {
            final g = groups[i];
            final name = g['name'] ?? 'Group';
            final lastMsg = g['last_message'] ?? '';
            final memberCount =
                (g['members'] as List?)?.length ?? 0;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'G',
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lastMsg,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text("$memberCount",
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => GroupChatDetailScreen(
                          groupId: g['id'],
                          groupName: name,
                          creatorUid: (g['creator'] ?? '') as String))),
            );
          },
        );
      },
    );
  }
}