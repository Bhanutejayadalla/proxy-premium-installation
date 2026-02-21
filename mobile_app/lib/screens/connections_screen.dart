import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/firebase_service.dart';
import 'user_detail_screen.dart';
import 'connection_requests_screen.dart';

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Connections"),
        actions: [
          TextButton.icon(
            icon: const Icon(LucideIcons.inbox, size: 18),
            label: const Text("Requests"),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ConnectionRequestsScreen())),
          ),
        ],
      ),
      body: StreamBuilder<List<Connection>>(
        stream: state.connectionsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final connections = snap.data ?? [];
          final accepted =
              connections.where((c) => c.status == 'accepted').toList();

          if (accepted.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.users, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No connections yet",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text("Discover people nearby and connect!",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: accepted.length,
            itemBuilder: (context, i) {
              final conn = accepted[i];
              final otherUid = conn.from == state.currentUser?.uid
                  ? conn.to
                  : conn.from;

              return FutureBuilder<AppUser?>(
                future: FirebaseService().getUser(otherUid),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text("Loading..."),
                    );
                  }
                  final user = userSnap.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          user.getAvatar(state.isFormal).isNotEmpty
                              ? NetworkImage(user.getAvatar(state.isFormal))
                              : null,
                      child: user.getAvatar(state.isFormal).isEmpty
                          ? Text(user.username[0].toUpperCase())
                          : null,
                    ),
                    title: Text(user.fullName.isNotEmpty
                        ? user.fullName
                        : user.username),
                    subtitle: Text(user.headline.isNotEmpty
                        ? user.headline
                        : conn.mode),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (value) async {
                        if (value == 'remove') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Remove Connection"),
                              content: Text(
                                  "Remove ${user.username} from your connections? You can reconnect later."),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text("Remove",
                                        style: TextStyle(
                                            color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final appState = Provider.of<AppState>(
                                context,
                                listen: false);
                            await appState.removeConnection(otherUid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "${user.username} removed")));
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove,
                                  color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text("Remove Connection",
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => UserDetailScreen(user: user))),
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
