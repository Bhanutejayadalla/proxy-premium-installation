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
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final state = Provider.of<AppState>(context, listen: false);
      final path =
          'chat_files/${_chatId}/${DateTime.now().millisecondsSinceEpoch}';
      final url = await state.firebase.uploadFile(File(x.path), path);
      _send(fileUrl: url, fileType: 'image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = Provider.of<AppState>(context).currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(widget.targetUser)),
      body: Column(
        children: [
          // Messages (real-time from Firestore)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Provider.of<AppState>(context, listen: false)
                  .getChatMessages(_chatId),
              builder: (ctx, snap) {
                final msgs = snap.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final m = msgs[i];
                    final isMe = m['sender_uid'] == myUid;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 250),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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