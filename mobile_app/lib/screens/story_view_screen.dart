import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class StoryViewScreen extends StatefulWidget {
  final dynamic story;
  const StoryViewScreen({super.key, required this.story});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  double _progress = 0.0;
  Timer? _timer;
  bool _isPaused = false;
  final TextEditingController _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPaused) {
        setState(() {
          _progress += 0.01;
          if (_progress >= 1.0) {
            _timer?.cancel();
            Navigator.pop(context);
          }
        });
      }
    });
  }

  void _sendReply() async {
    if (_replyCtrl.text.isEmpty) return;
    _timer?.cancel();

    final state = Provider.of<AppState>(context, listen: false);
    final authorId = widget.story['author_id'] ?? '';
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
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = widget.story['media_url'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPaused = true),
          onTapUp: (_) => setState(() => _isPaused = false),
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
                        child: Text(widget.story['text'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 24)),
                      ),
              ),

              // PROGRESS BAR
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: LinearProgressIndicator(
                    value: _progress,
                    color: Colors.white,
                    backgroundColor: Colors.white24),
              ),

              // USER INFO
              Positioned(
                top: 30,
                left: 15,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: (widget.story['author_avatar'] ?? '').toString().isNotEmpty
                          ? NetworkImage(widget.story['author_avatar'])
                          : null,
                      child: (widget.story['author_avatar'] ?? '').toString().isEmpty
                          ? Text((widget.story['username'] ?? '?')[0],
                              style: const TextStyle(color: Colors.white, fontSize: 12))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(widget.story['username'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
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