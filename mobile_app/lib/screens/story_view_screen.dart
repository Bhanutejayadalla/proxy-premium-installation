import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// Full-screen story viewer.
///
/// Supports a single story (backward-compatible) **or** a group of stories
/// from the same user.  When a group is provided, the viewer auto-advances
/// through them with individual progress segments.
class StoryViewScreen extends StatefulWidget {
  final dynamic story;
  final List<Map<String, dynamic>>? storyGroup;

  const StoryViewScreen({
    super.key,
    required this.story,
    this.storyGroup,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late List<Map<String, dynamic>> _stories;
  int _currentIndex = 0;
  double _segmentProgress = 0.0;
  Timer? _timer;
  bool _isPaused = false;
  final TextEditingController _replyCtrl = TextEditingController();

  Map<String, dynamic> get _current => _stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    if (widget.storyGroup != null && widget.storyGroup!.isNotEmpty) {
      _stories = widget.storyGroup!;
    } else {
      _stories = [widget.story as Map<String, dynamic>];
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _segmentProgress = 0.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_isPaused) return;
      setState(() {
        _segmentProgress += 0.01;
        if (_segmentProgress >= 1.0) {
          _goNext();
        }
      });
    });
  }

  void _goNext() {
    if (_currentIndex < _stories.length - 1) {
      _currentIndex++;
      _startTimer();
    } else {
      _timer?.cancel();
      Navigator.pop(context);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _startTimer();
    } else {
      _segmentProgress = 0.0;
      _startTimer();
    }
  }

  void _sendReply() async {
    if (_replyCtrl.text.isEmpty) return;
    _timer?.cancel();

    final state = Provider.of<AppState>(context, listen: false);
    final authorId = _current['author_id'] ?? '';
    if (state.currentUser != null && authorId.isNotEmpty) {
      final chatId = state.getChatId(authorId);
      await state.sendMessage(
        chatId: chatId,
        receiverUid: authorId,
        text: "Replied to story: ${_replyCtrl.text}",
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Reply sent!")));
      _replyCtrl.clear();
      _goNext();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _current['media_url'];
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPaused = true),
          onTapUp: (details) {
            setState(() => _isPaused = false);
            // Left third => previous, right third => next
            if (details.localPosition.dx < screenW / 3) {
              _goPrev();
            } else if (details.localPosition.dx > screenW * 2 / 3) {
              _goNext();
            }
          },
          child: Stack(
            children: [
              // STORY CONTENT
              Center(
                child: mediaUrl != null && mediaUrl.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: mediaUrl,
                        fit: BoxFit.contain,
                        errorWidget: (c, u, e) => const Text(
                            "Could not load image",
                            style: TextStyle(color: Colors.white)),
                      )
                    : Container(
                        color: Colors.blue,
                        alignment: Alignment.center,
                        child: Text(_current['text'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 24)),
                      ),
              ),

              // SEGMENTED PROGRESS BAR (one segment per story)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: List.generate(_stories.length, (i) {
                    double value;
                    if (i < _currentIndex) {
                      value = 1.0;
                    } else if (i == _currentIndex) {
                      value = _segmentProgress;
                    } else {
                      value = 0.0;
                    }
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i < _stories.length - 1 ? 4 : 0),
                        child: LinearProgressIndicator(
                          value: value,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                          minHeight: 2.5,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // USER INFO + CLOSE + DELETE
              Positioned(
                top: 24,
                left: 15,
                right: 15,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage:
                          (_current['author_avatar'] ?? '').toString().isNotEmpty
                              ? NetworkImage(_current['author_avatar'])
                              : null,
                      child:
                          (_current['author_avatar'] ?? '').toString().isEmpty
                              ? Text(
                                  (_current['username'] ?? '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12))
                              : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_current['username'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    // Delete button — only show for own stories
                    if (Provider.of<AppState>(context, listen: false)
                                .currentUser
                                ?.uid ==
                            _current['author_id'])
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () async {
                          _timer?.cancel();
                          final state = Provider.of<AppState>(context,
                              listen: false);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Story"),
                              content: const Text(
                                  "Are you sure you want to delete this story?"),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text("Cancel")),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text("Delete",
                                        style:
                                            TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            final storyId = _current['id'] ?? '';
                            if (storyId.isNotEmpty) {
                              await state.deleteStory(storyId);
                            }
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Story deleted")));
                              // Remove from group and advance or pop
                              _stories.removeAt(_currentIndex);
                              if (_stories.isEmpty) {
                                if (context.mounted) Navigator.pop(context);
                                return;
                              }
                              if (_currentIndex >= _stories.length) {
                                _currentIndex = _stories.length - 1;
                              }
                              _startTimer();
                            }
                          } else {
                            _startTimer(); // Resume timer if cancelled
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // REPLY FIELD
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Send message...",
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        onTap: () => setState(() => _isPaused = true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendReply,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}