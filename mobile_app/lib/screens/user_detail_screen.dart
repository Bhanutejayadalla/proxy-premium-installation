import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/firebase_service.dart';
import 'chat_detail_screen.dart';
import 'connection_requests_screen.dart';
import 'followers_following_screen.dart';

class UserDetailScreen extends StatelessWidget {
  final AppUser user;
  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isFormal = state.isFormal;
    final connStatus = state.connectionStatusWith(user.uid);

    return Scaffold(
      appBar: AppBar(title: Text(user.username)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVATAR & NAME
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user.getAvatar(isFormal).isNotEmpty
                        ? NetworkImage(user.getAvatar(isFormal))
                        : null,
                    child: user.getAvatar(isFormal).isEmpty
                        ? Text(user.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 36))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : user.username,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (user.headline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(user.headline,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600])),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // BADGES
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (user.openToWork)
                  _badge("Open to Work", Colors.green),
                if (user.hiring)
                  _badge("Hiring", Colors.blue),
              ],
            ),
            const SizedBox(height: 16),

            // STATS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _tappableStat(context, "Followers", user.followers.length, user, 0),
                _tappableStat(context, "Following", user.following.length, user, 1),
                _tappableStat(context, "Connections", 0, user, 2), // count shown from cached data
              ],
            ),
            const SizedBox(height: 20),

            // BIO
            if (user.bio.isNotEmpty) ...[
              const Text("About",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(user.bio),
              const SizedBox(height: 20),
            ],

            // SKILLS
            if (user.skills.isNotEmpty) ...[
              const Text("Skills",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.skills
                    .map((s) => Chip(label: Text(s)))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // DISTANCE
            if (user.distanceKm != null)
              Card(
                child: ListTile(
                  leading: const Icon(LucideIcons.mapPin),
                  title: Text(
                      "${user.distanceKm!.toStringAsFixed(1)} km away"),
                ),
              ),

            const SizedBox(height: 24),

            // ACTIONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.messageCircle),
                    label: const Text("Message"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            targetUser: user.username,
                            targetUid: user.uid,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: connStatus == 'accepted'
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'remove') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Remove Connection"),
                                  content: Text(
                                      "Remove ${user.username}? You can reconnect later."),
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
                              if (confirmed == true && context.mounted) {
                                await state.removeConnection(user.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("Connection removed")));
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
                                  Text("Remove",
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.userCheck,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 6),
                                Text("Connected",
                                    style: TextStyle(color: Colors.green)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.green, size: 18),
                              ],
                            ),
                          ),
                        )
                      : connStatus == 'pending_sent'
                          ? OutlinedButton.icon(
                              icon: const Icon(LucideIcons.clock,
                                  color: Colors.orange),
                              label: const Text("Pending",
                                  style: TextStyle(color: Colors.orange)),
                              onPressed: null,
                            )
                          : connStatus == 'pending_received'
                              ? ElevatedButton.icon(
                                  icon: const Icon(LucideIcons.userCheck),
                                  label: const Text("Accept"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ConnectionRequestsScreen()),
                                    );
                                  },
                                )
                              : OutlinedButton.icon(
                                  icon: const Icon(LucideIcons.userPlus),
                                  label: const Text("Connect"),
                                  onPressed: () {
                                    state.sendConnectionRequest(user.uid);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Connection request sent")));
                                  },
                                ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // USER POSTS
            const Text("Posts",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<List<Post>>(
              stream: FirebaseService().getUserPostsStream(user.uid),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text("No posts yet"),
                  ));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snap.data!.length,
                  itemBuilder: (c, i) {
                    final post = snap.data![i];
                    return Card(
                      child: ListTile(
                        title: Text(post.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        subtitle:
                            Text("${post.likes.length} likes · ${post.comments.length} comments"),
                        trailing: post.mediaUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(post.mediaUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color)),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _tappableStat(BuildContext context, String label, int count, AppUser user, int tabIndex) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FollowersFollowingScreen(
            user: user,
            initialTab: tabIndex,
          ),
        ),
      ),
      child: Column(
        children: [
          Text("$count",
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _stat(String label, int count) {
    return Column(
      children: [
        Text("$count",
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
