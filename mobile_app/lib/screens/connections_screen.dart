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
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(conn.mode,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green)),
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
