import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myUid = state.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: state.conversationsStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
      ),
    );
  }
}