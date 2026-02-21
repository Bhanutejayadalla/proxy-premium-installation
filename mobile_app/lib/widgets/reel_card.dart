import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import 'video_player_widget.dart';

class ReelCard extends StatelessWidget {
  final Post reel;
  final bool isActive;

  const ReelCard({
    super.key,
    required this.reel,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final isLiked = reel.likes.contains(state.currentUser?.uid);

    return Stack(
      fit: StackFit.expand,
      children: [
        // VIDEO PLAYER
        if (reel.mediaUrl != null)
          VideoPlayerWidget(
            url: reel.mediaUrl!,
            autoPlay: isActive,
          )
        else
          Container(color: Colors.black),

        // GRADIENT OVERLAY
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),

        // BOTTOM INFO
        Positioned(
          bottom: 80,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: reel.authorAvatar.isNotEmpty
                        ? NetworkImage(reel.authorAvatar)
                        : null,
                    child: reel.authorAvatar.isEmpty
                        ? Text(reel.username.isNotEmpty
                            ? reel.username[0]
                            : '?')
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(reel.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
              if (reel.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(reel.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),

        // SIDE ACTIONS
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              _sideButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: "${reel.likes.length}",
                color: isLiked ? Colors.red : Colors.white,
                onTap: () => state.toggleLike(reel.id),
              ),
              const SizedBox(height: 20),
              _sideButton(
                icon: LucideIcons.messageCircle,
                label: "${reel.comments.length}",
                color: Colors.white,
                onTap: () => _showComments(context, reel),
              ),
              const SizedBox(height: 20),
              _sideButton(
                icon: LucideIcons.eye,
                label: "${reel.views}",
                color: Colors.white,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  void _showComments(BuildContext context, Post reel) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: 350,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Comments",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Divider(color: Colors.white24),
              Expanded(
                child: reel.comments.isEmpty
                    ? const Center(
                        child: Text("No comments yet",
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: reel.comments.length,
                        itemBuilder: (c, i) => ListTile(
                          leading: CircleAvatar(
                              radius: 14,
                              child: Text(
                                  reel.comments[i].user.isNotEmpty
                                      ? reel.comments[i].user[0]
                                      : '?',
                                  style: const TextStyle(fontSize: 10))),
                          title: Text(reel.comments[i].user,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          subtitle: Text(reel.comments[i].text,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () {
                      if (commentCtrl.text.isNotEmpty) {
                        Provider.of<AppState>(context, listen: false)
                            .addComment(reel.id, commentCtrl.text);
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
