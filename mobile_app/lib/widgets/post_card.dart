import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../app_state.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  void _showComments(BuildContext context) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Comments",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              Expanded(
                child: post.comments.isEmpty
                    ? const Center(
                        child: Text("No comments yet. Be the first!"))
                    : ListView.builder(
                        itemCount: post.comments.length,
                        itemBuilder: (c, i) => ListTile(
                          leading: CircleAvatar(
                              child: Text(post.comments[i].user.isNotEmpty
                                  ? post.comments[i].user[0]
                                  : '?')),
                          title: Text(post.comments[i].user,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(post.comments[i].text),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: commentCtrl,
                          decoration: const InputDecoration(
                              hintText: "Add a comment..."))),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () {
                      if (commentCtrl.text.isNotEmpty) {
                        Provider.of<AppState>(context, listen: false)
                            .addComment(post.id, commentCtrl.text);
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

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final isLiked = post.likes.contains(state.currentUser?.uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post.authorAvatar.isNotEmpty
                  ? NetworkImage(post.authorAvatar)
                  : null,
              child: post.authorAvatar.isEmpty
                  ? Text(post.username.isNotEmpty ? post.username[0] : '?')
                  : null,
            ),
            title: Text(post.username,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),

          // MEDIA
          if (post.mediaUrl != null)
            GestureDetector(
              onDoubleTap: () => state.toggleLike(post.id),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrl!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) =>
                    Container(height: 300, color: Colors.grey[200]),
              ),
            ),

          // ACTIONS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.black),
                        onPressed: () => state.toggleLike(post.id)),
                    IconButton(
                        icon: const Icon(LucideIcons.messageCircle),
                        onPressed: () => _showComments(context)),
                    const Spacer(),
                    Text("${post.likes.length} likes",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (post.text.isNotEmpty) Text(post.text),
                if (post.comments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        "View all ${post.comments.length} comments",
                        style: const TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}