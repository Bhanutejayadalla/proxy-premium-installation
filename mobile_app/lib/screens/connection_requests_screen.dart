import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/firebase_service.dart';

class ConnectionRequestsScreen extends StatelessWidget {
  const ConnectionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Connection Requests")),
      body: StreamBuilder<List<Connection>>(
        stream: state.pendingRequestsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snap.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No pending requests",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final req = requests[i];
              return FutureBuilder<AppUser?>(
                future: FirebaseService().getUser(req.from),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text("Loading..."),
                    );
                  }
                  final user = userSnap.data!;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: user
                                        .getAvatar(state.isFormal)
                                        .isNotEmpty
                                    ? NetworkImage(
                                        user.getAvatar(state.isFormal))
                                    : null,
                                child: user
                                        .getAvatar(state.isFormal)
                                        .isEmpty
                                    ? Text(
                                        user.username[0].toUpperCase())
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName.isNotEmpty
                                          ? user.fullName
                                          : user.username,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (user.headline.isNotEmpty)
                                      Text(user.headline,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(req.mode,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.blue)),
                              ),
                            ],
                          ),
                          if (req.message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(req.message,
                                style: TextStyle(
                                    color: Colors.grey[700], fontSize: 13)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    state.respondToConnection(
                                        req.id, 'accepted');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text("Connection accepted")));
                                  },
                                  child: const Text("Accept"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    state.respondToConnection(
                                        req.id, 'declined');
                                  },
                                  child: const Text("Decline"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
