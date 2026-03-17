import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import 'audio_player_widget.dart';

/// Enhanced post card with support for location, music, edited label
class EnhancedPostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isOwner;
  final bool isLiked;

  const EnhancedPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.isOwner = false,
    this.isLiked = false,
  });

  @override
  State<EnhancedPostCard> createState() => _EnhancedPostCardState();
}

class _EnhancedPostCardState extends State<EnhancedPostCard> {
  bool _showMusic = false;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, y');
    final createdDate = widget.post.createdAt != null
        ? dateFormatter.format(widget.post.createdAt!)
        : '';
    final updatedDate = widget.post.updatedAt != null
        ? dateFormatter.format(widget.post.updatedAt!)
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author info + actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.post.authorAvatar.isNotEmpty
                      ? NetworkImage(widget.post.authorAvatar)
                      : null,
                  child: widget.post.authorAvatar.isEmpty
                      ? Text(widget.post.username.isNotEmpty
                          ? widget.post.username[0].toUpperCase()
                          : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.post.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          // Edited label
                          if (widget.post.isEdited)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.orange.shade400,
                                  ),
                                ),
                                child: Text(
                                  'Edited',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdDate,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (widget.post.isEdited && updatedDate.isNotEmpty)
                        Text(
                          'Updated: $updatedDate',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                // More options menu
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        widget.onEdit?.call();
                        break;
                      case 'delete':
                        widget.onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    if (!widget.isOwner) return [];
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),

          // Post description
          if (widget.post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(widget.post.text),
            ),

          // Location badge
          if (widget.post.location != null && widget.post.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.location!,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Media
          if (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl!,
                  fit: BoxFit.cover,
                  height: 300,
                  width: double.infinity,
                  progressIndicatorBuilder: (context, url, progress) =>
                      Center(
                    child: CircularProgressIndicator(
                      value: progress.progress,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            ),

          // Music player (if has song)
          if (widget.post.songUrl != null &&
              widget.post.songUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_showMusic)
                    GestureDetector(
                      onTap: () => setState(() => _showMusic = true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.music_note, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.post.songName ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    widget.post.artist ?? 'Unknown Artist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_arrow, color: Colors.blue),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        AudioPlayerWidget(
                          audioUrl: widget.post.songUrl!,
                          songName: widget.post.songName,
                          artist: widget.post.artist,
                          onClose: () => setState(() => _showMusic = false),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // Engagement stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  '${widget.post.likes.length} Likes',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${widget.post.comments.length} Comments',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${widget.post.shares} Shares',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Like button
                TextButton.icon(
                  onPressed: widget.onLike,
                  icon: Icon(
                    widget.isLiked ? Icons.favorite : Icons.favorite_outline,
                    color: widget.isLiked ? Colors.red : null,
                  ),
                  label: const Text('Like'),
                ),
                // Comment button
                TextButton.icon(
                  onPressed: widget.onComment,
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('Comment'),
                ),
                // Share button
                TextButton.icon(
                  onPressed: widget.onShare,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
