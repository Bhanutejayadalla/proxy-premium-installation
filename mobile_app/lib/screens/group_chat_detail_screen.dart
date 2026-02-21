import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';

class GroupChatDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatDetailScreen> createState() => _GroupChatDetailScreenState();
}

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen> {
  final _text = TextEditingController();

  void _send({String? text, String? fileUrl, String? fileType}) {
    if ((text == null || text.isEmpty) && fileUrl == null) return;
    final state = Provider.of<AppState>(context, listen: false);
    state.sendGroupMessage(
      groupId: widget.groupId,
      text: text,
      fileUrl: fileUrl,
      fileType: fileType,
    );
    _text.clear();
  }

  void _pickFile() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final state = Provider.of<AppState>(context, listen: false);
      final path =
          'group_files/${widget.groupId}/${DateTime.now().millisecondsSinceEpoch}';
      final url = await state.firebase.uploadFile(File(x.path), path);
      _send(fileUrl: url, fileType: 'image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<AppState>(context).currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName,
                style: const TextStyle(fontSize: 16)),
            const Text("Group Chat",
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages stream
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Provider.of<AppState>(context, listen: false)
                  .getGroupMessages(widget.groupId),
              builder: (ctx, snap) {
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text("No messages yet.\nSay hello to the group!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final m = msgs[i];
                    final isMe = m['sender_uid'] == myUid;
                    final sender = m['sender_username'] ?? '';
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(sender,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.black54)),
                              ),
                            if (m['file_url'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: CachedNetworkImage(
                                  imageUrl: m['file_url'],
                                  placeholder: (c, u) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (c, u, e) =>
                                      const Icon(Icons.insert_drive_file),
                                ),
                              ),
                            if (m['text'] != null &&
                                m['text'].toString().isNotEmpty)
                              Text(m['text'],
                                  style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black)),
                          ],
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
