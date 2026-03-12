import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';
import '../models.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'followers_following_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final user = state.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.username ?? ""),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // AVATAR
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user.getAvatar(state.isFormal).isNotEmpty
                        ? NetworkImage(user.getAvatar(state.isFormal))
                        : null,
                    child: user.getAvatar(state.isFormal).isEmpty
                        ? Text(user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?',
                            style: const TextStyle(fontSize: 36))
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(user.username,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 22)),
                  if (user.headline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Text(user.headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  Text(user.bio.isNotEmpty ? user.bio : "No bio",
                      style: const TextStyle(color: Colors.grey)),

                  const SizedBox(height: 12),

                  // Followers / Following / Connections
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tappableStatCol(context, "Followers", user.getFollowersForMode(state.currentMode).length, user, 0),
                      const SizedBox(width: 30),
                      _tappableStatCol(context, "Following", user.getFollowingForMode(state.currentMode).length, user, 1),
                      const SizedBox(width: 30),
                      _tappableStatCol(context, "Connections", state.connectedUids.length, user, 2),
                    ],
                  ),

                  // Skills (formal mode)
                  if (state.isFormal && user.skills.isNotEmpty) ...[
                    const Divider(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: user.skills
                              .map((s) => Chip(label: Text(s)))
                              .toList(),
                        ),
                      ),
                    ),
                  ],

                  // Open to work / Hiring badge
                  if (state.isFormal && (user.openToWork || user.hiring)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: user.openToWork
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.openToWork ? "Open to Work" : "Hiring",
                        style: TextStyle(
                          color: user.openToWork
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 30),

                  // Posts grid
                  StreamBuilder<List<Post>>(
                    stream: state.firebase.getUserPostsStream(user.uid),
                    builder: (ctx, snap) {
                      final posts = snap.data ?? [];
                      if (posts.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text("No posts yet.",
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2),
                        itemCount: posts.length,
                        itemBuilder: (ctx, i) {
                          final p = posts[i];
                          return GestureDetector(
                            onLongPress: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Delete Post"),
                                  content: const Text(
                                      "Are you sure you want to delete this post?"),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Cancel")),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text("Delete",
                                            style: TextStyle(
                                                color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                await state.deletePost(p.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Post deleted")));
                                }
                              }
                            },
                            child: p.mediaUrl == null
                                ? Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.text_fields))
                                : CachedNetworkImage(
                                    imageUrl: p.mediaUrl!,
                                    fit: BoxFit.cover,
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

  Widget _tappableStatCol(BuildContext context, String label, int count, AppUser user, int tabIndex) {
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}