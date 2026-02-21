import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../app_state.dart';

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLiking = false;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _isLiked = widget.post.likes.contains(state.currentUser?.uid);
    _likeCount = widget.post.likes.length;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likes.length != widget.post.likes.length) {
      final state = Provider.of<AppState>(context, listen: false);
      _isLiked = widget.post.likes.contains(state.currentUser?.uid);
      _likeCount = widget.post.likes.length;
    }
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    _isLiking = true;

    // Optimistic update — instant UI feedback
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final state = Provider.of<AppState>(context, listen: false);
      await state.toggleLike(widget.post.id);
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    }
    _isLiking = false;
  }

  Future<void> _handleDoubleTapLike() async {
    if (!_isLiked) {
      await _handleLike();
    }
    // Show heart animation
    setState(() => _showHeart = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showHeart = false);
  }

  void _showComments(BuildContext context) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text("Comments",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                // Real-time comments from Firestore
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<Comment> comments = widget.post.comments;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>? ??
                                {};
                        comments = (data['comments'] as List? ?? [])
                            .map((c) =>
                                Comment.fromJson(c as Map<String, dynamic>))
                            .toList();
                      }

                      if (comments.isEmpty) {
                        return const Center(
                          child: Text("No comments yet. Be the first!",
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (c, i) => ListTile(
                          leading: CircleAvatar(
                            child: Text(comments[i].user.isNotEmpty
                                ? comments[i].user[0].toUpperCase()
                                : '?'),
                          ),
                          title: Text(comments[i].user,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(comments[i].text),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            Provider.of<AppState>(context, listen: false)
                                .addComment(widget.post.id, text.trim());
                            commentCtrl.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () {
                        if (commentCtrl.text.trim().isNotEmpty) {
                          Provider.of<AppState>(context, listen: false)
                              .addComment(
                                  widget.post.id, commentCtrl.text.trim());
                          commentCtrl.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              backgroundImage: widget.post.authorAvatar.isNotEmpty
                  ? NetworkImage(widget.post.authorAvatar)
                  : null,
              child: widget.post.authorAvatar.isEmpty
                  ? Text(widget.post.username.isNotEmpty
                      ? widget.post.username[0]
                      : '?')
                  : null,
            ),
            title: Text(widget.post.username,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),

          // MEDIA with double-tap like animation
          if (widget.post.mediaUrl != null)
            GestureDetector(
              onDoubleTap: _handleDoubleTapLike,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.post.mediaUrl!,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (c, u, e) =>
                        Container(height: 300, color: Colors.grey[200]),
                  ),
                  // Heart animation on double tap
                  if (_showHeart)
                    const Icon(Icons.favorite,
                        color: Colors.white, size: 80),
                ],
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
                    GestureDetector(
                      onTap: _handleLike,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(_isLiked),
                          color: _isLiked ? Colors.red : Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.messageCircle),
                      onPressed: () => _showComments(context),
                    ),
                    const Spacer(),
                    Text("$_likeCount likes",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (widget.post.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(widget.post.text),
                  ),
                if (widget.post.comments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: () => _showComments(context),
                      child: Text(
                        "View all ${widget.post.comments.length} comments",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}