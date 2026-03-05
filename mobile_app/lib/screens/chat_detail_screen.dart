import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';

class ChatDetailScreen extends StatefulWidget {
  final String targetUser; // display name
  final String targetUid;
  const ChatDetailScreen(
      {super.key, required this.targetUser, required this.targetUid});
  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _text = TextEditingController();

  String get _chatId {
    final state = Provider.of<AppState>(context, listen: false);
    return state.getChatId(widget.targetUid);
  }

  void _send({String? text, String? fileUrl, String? fileType}) {
    if ((text == null || text.isEmpty) && fileUrl == null) return;
    final state = Provider.of<AppState>(context, listen: false);
    state.sendMessage(
      chatId: _chatId,
      receiverUid: widget.targetUid,
      text: text,
      fileUrl: fileUrl,
      fileType: fileType,
    );
    _text.clear();
  }

  void _pickFile() async {
    final state = Provider.of<AppState>(context, listen: false);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final path =
          'chat_files/$_chatId/${DateTime.now().millisecondsSinceEpoch}';
      final url = await state.firebase.uploadFile(File(x.path), path);
      _send(fileUrl: url, fileType: 'image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myUid = state.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetUser),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'clear') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Clear Chat"),
                    content: const Text(
                        "Delete all messages? The conversation will remain."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel")),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Clear",
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await state.clearChat(_chatId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Chat cleared")));
                  }
                }
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Conversation"),
                    content: const Text(
                        "Delete this entire conversation? This cannot be undone."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel")),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Delete",
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await state.deleteChat(_chatId);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Conversation deleted")));
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text("Clear Messages"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text("Delete Conversation",
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages (real-time from Firestore)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Provider.of<AppState>(context, listen: false)
                  .getChatMessages(_chatId),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text("Error loading messages: ${snap.error}",
                        style: const TextStyle(color: Colors.red)));
                }
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text("No messages yet. Say hello!",
                        style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final m = msgs[i];
                    final isMe = m['sender_uid'] == myUid;
                    return GestureDetector(
                      onLongPress: isMe
                          ? () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Delete Message"),
                                  content: const Text(
                                      "Delete this message?"),
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
                                await state.deleteChatMessage(
                                    _chatId, m['id']);
                              }
                            }
                          : null,
                      child: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          constraints:
                              const BoxConstraints(maxWidth: 250),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (m['file_url'] != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 5),
                                  child: CachedNetworkImage(
                                    imageUrl: m['file_url'],
                                    placeholder: (c, u) =>
                                        const CircularProgressIndicator(),
                                    errorWidget: (c, u, e) =>
                                        const Icon(
                                            Icons.insert_drive_file),
                                  ),
                                ),
                              if (m['text'] != null &&
                                  m['text'].toString().isNotEmpty)
                                Text(m['text'],
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.attach_file), onPressed: _pickFile),
              Expanded(
                  child: TextField(
                      controller: _text,
                      decoration:
                          const InputDecoration(hintText: "Type..."))),
              IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _send(text: _text.text)),
            ]),
          ),
        ],
      ),
    );
  }
}