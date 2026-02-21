import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models.dart';
import 'video_player_widget.dart';

class ReelCard extends StatefulWidget {
  final Post reel;
  final bool isActive;

  const ReelCard({
    super.key,
    required this.reel,
    this.isActive = false,
  });

  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _isLiked = widget.reel.likes.contains(state.currentUser?.uid);
    _likeCount = widget.reel.likes.length;
  }

  @override
  void didUpdateWidget(ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id ||
        oldWidget.reel.likes.length != widget.reel.likes.length) {
      final state = Provider.of<AppState>(context, listen: false);
      _isLiked = widget.reel.likes.contains(state.currentUser?.uid);
      _likeCount = widget.reel.likes.length;
    }
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    _isLiking = true;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final state = Provider.of<AppState>(context, listen: false);
      await state.toggleLike(widget.reel.id, collection: 'reels');
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    }
    _isLiking = false;
  }

  void _showComments(BuildContext context) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reels')
                        .doc(widget.reel.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<Comment> comments = widget.reel.comments;
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
                          child: Text("No comments yet",
                              style: TextStyle(color: Colors.white38)),
                        );
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (c, i) => ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text(
                                comments[i].user.isNotEmpty
                                    ? comments[i].user[0]
                                    : '?',
                                style: const TextStyle(fontSize: 10)),
                          ),
                          title: Text(comments[i].user,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          subtitle: Text(comments[i].text,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            Provider.of<AppState>(context, listen: false)
                                .addComment(widget.reel.id, text.trim(),
                                    collection: 'reels');
                            commentCtrl.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () {
                        if (commentCtrl.text.trim().isNotEmpty) {
                          Provider.of<AppState>(context, listen: false)
                              .addComment(
                                  widget.reel.id, commentCtrl.text.trim(),
                                  collection: 'reels');
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // VIDEO PLAYER
        if (widget.reel.mediaUrl != null)
          VideoPlayerWidget(
            url: widget.reel.mediaUrl!,
            autoPlay: widget.isActive,
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
                    backgroundImage: widget.reel.authorAvatar.isNotEmpty
                        ? NetworkImage(widget.reel.authorAvatar)
                        : null,
                    child: widget.reel.authorAvatar.isEmpty
                        ? Text(widget.reel.username.isNotEmpty
                            ? widget.reel.username[0]
                            : '?')
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(widget.reel.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
              if (widget.reel.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.reel.text,
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
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: "$_likeCount",
                color: _isLiked ? Colors.red : Colors.white,
                onTap: _handleLike,
              ),
              const SizedBox(height: 20),
              _sideButton(
                icon: LucideIcons.messageCircle,
                label: "${widget.reel.comments.length}",
                color: Colors.white,
                onTap: () => _showComments(context),
              ),
              const SizedBox(height: 20),
              _sideButton(
                icon: LucideIcons.eye,
                label: "${widget.reel.views}",
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
}
