import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import 'connection_requests_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<List<NotificationItem>>(
        stream: state.notificationsStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
                child: Text("No notifications yet",
                    style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              IconData icon;
              Color iconColor;
              switch (item.type) {
                case 'like':
                  icon = Icons.favorite;
                  iconColor = Colors.red;
                  break;
                case 'comment':
                  icon = Icons.comment;
                  iconColor = Colors.blue;
                  break;
                case 'connection_request':
                  icon = Icons.person_add;
                  iconColor = Colors.green;
                  break;
                case 'message':
                  icon = Icons.message;
                  iconColor = Colors.orange;
                  break;
                default:
                  icon = Icons.notifications;
                  iconColor = Colors.grey;
              }
              return ListTile(
                leading: CircleAvatar(
                    backgroundColor: iconColor,
                    child: Icon(icon, color: Colors.white)),
                title: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                          text: item.fromUser,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: " ${item.text}"),
                    ],
                  ),
                ),
                trailing: item.type == 'connection_request'
                    ? TextButton(
                        child: const Text("View"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ConnectionRequestsScreen()),
                          );
                        },
                      )
                    : null,
                tileColor: item.read ? null : Colors.blue.withOpacity(0.05),
                onTap: () {
                  if (item.id.isNotEmpty && !item.read) {
                    state.firebase.markNotificationRead(item.id);
                  }
                  // For connection requests, navigate to the requests screen
                  if (item.type == 'connection_request') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConnectionRequestsScreen()),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}