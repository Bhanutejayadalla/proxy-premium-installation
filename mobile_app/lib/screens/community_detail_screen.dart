import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../models.dart';
import '../constants.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Community community;
  const CommunityDetailScreen({super.key, required this.community});
  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  bool _sortByVotes = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final uid = state.currentUser?.uid;
    final isMember = widget.community.memberIds.contains(uid);
    final isCreator = widget.community.creatorId == uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.community.name),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_sortByVotes ? LucideIcons.arrowUpDown : LucideIcons.clock),
            tooltip: _sortByVotes ? 'Sort by Time' : 'Sort by Votes',
            onPressed: () => setState(() => _sortByVotes = !_sortByVotes),
          ),
          if (!isMember)
            TextButton(
              onPressed: () => state.firebase.joinCommunity(widget.community.id, uid!),
              child: const Text('Join', style: TextStyle(color: Colors.white)),
            ),
          if (isMember && !isCreator)
            TextButton(
              onPressed: () => _confirmLeave(context, state, uid!),
              child: const Text('Leave', style: TextStyle(color: Colors.white)),
            ),
          if (isCreator)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              tooltip: 'Delete Community',
              onPressed: () => _confirmDelete(context, state),
            ),
        ],
      ),
      floatingActionButton: isMember
          ? FloatingActionButton(
              onPressed: () => _showCreatePostDialog(context, state),
              backgroundColor: color,
              child: const Icon(LucideIcons.edit, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Community Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: color.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.community.description.isNotEmpty) ...[
                  Text(widget.community.description),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(LucideIcons.users, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${widget.community.memberIds.length} members',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    if (widget.community.tags.isNotEmpty)
                      ...widget.community.tags.take(3).map((t) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Chip(
                          label: Text(t, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      )),
                  ],
                ),
              ],
            ),
          ),

          // Posts / Discussions
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: state.firebase.getCommunityPostsStream(
                widget.community.id,
                sortByVotes: _sortByVotes,
              ),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snap.data ?? [];
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.messageSquare, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No discussions yet', style: TextStyle(color: Colors.grey.shade600)),
                        if (isMember)
                          const Text('Start a conversation!'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (ctx, i) => _DiscussionCard(post: posts[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, AppState state, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Community'),
        content: Text('Leave "${widget.community.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.firebase.leaveCommunity(widget.community.id, uid);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Community'),
        content: Text(
          'Permanently delete "${widget.community.name}" and all its posts? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.firebase.deleteCommunity(widget.community.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String type = 'discussion';
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Discussion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: contentCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'discussion', child: Text('Discussion')),
                    DropdownMenuItem(value: 'resource', child: Text('Resource')),
                    DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                    DropdownMenuItem(value: 'poll', child: Text('Poll')),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      state.firebase.createCommunityPost({
                        'community_id': widget.community.id,
                        'author_id': state.currentUser!.uid,
                        'author_username': state.currentUser!.username,
                        'title': titleCtrl.text.trim(),
                        'content': contentCtrl.text.trim(),
                        'type': type,
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Post'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscussionCard extends StatefulWidget {
  final CommunityPost post;
  const _DiscussionCard({required this.post});
  @override
  State<_DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<_DiscussionCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final color = state.isFormal ? AppColors.formalPrimary : AppColors.casualPrimary;
    final hasUpvoted = widget.post.upvotes.contains(state.currentUser?.uid);
    final hasDownvoted = widget.post.downvotes.contains(state.currentUser?.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Upvote/Downvote
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => state.firebase.voteCommunityPost(
                          widget.post.id, state.currentUser!.uid, true),
                      child: Icon(LucideIcons.chevronUp,
                          color: hasUpvoted ? Colors.orange : Colors.grey, size: 28),
                    ),
                    Text('${widget.post.score}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.post.score > 0
                              ? Colors.orange
                              : widget.post.score < 0
                                  ? Colors.blue
                                  : Colors.grey,
                        )),
                    GestureDetector(
                      onTap: () => state.firebase.voteCommunityPost(
                          widget.post.id, state.currentUser!.uid, false),
                      child: Icon(LucideIcons.chevronDown,
                          color: hasDownvoted ? Colors.blue : Colors.grey, size: 28),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.post.isPinned)
                        const Row(
                          children: [
                            Icon(LucideIcons.pin, size: 12, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('Pinned', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      Text(widget.post.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('by ${widget.post.authorUsername}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      if (widget.post.content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(widget.post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(widget.post.type, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showComments = !_showComments),
                  child: Row(
                    children: [
                      Icon(LucideIcons.messageSquare, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${widget.post.comments.length}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            if (_showComments) ...[
              const SizedBox(height: 8),
              ...widget.post.comments.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.user}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Expanded(child: Text(c.text, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_commentCtrl.text.trim().isEmpty) return;
                      state.firebase.addCommunityPostComment(
                        widget.post.id,
                        state.currentUser!.uid,
                        state.currentUser!.username,
                        _commentCtrl.text.trim(),
                      );
                      _commentCtrl.clear();
                    },
                    icon: Icon(LucideIcons.send, color: color),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
