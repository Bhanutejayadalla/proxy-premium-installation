import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import 'chat_detail_screen.dart';
import 'create_group_chat_screen.dart';
import 'group_chat_detail_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.build, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text(
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
                  subtitle: Text(lastMsg,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.build, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text(
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
                          groupId: g['id'], groupName: name))),
            );
          },
        );
      },
    );
  }
}