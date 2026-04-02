import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import 'mesh_chat_screen.dart';

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
  final _search = TextEditingController();

  Map<String, dynamic>? _replyTo;
  bool _showSearch = false;
  Timer? _typingDebounce;
  DateTime? _lastSeenWrite;

  static const _reactionOptions = ['👍', '❤️', '😂', '🔥', '👏'];
  static const _editWindow = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _text.removeListener(_onTypingChanged);
    _text.dispose();
    _search.dispose();
    final state = Provider.of<AppState>(context, listen: false);
    state.setChatTyping(_chatId, false);
    super.dispose();
  }

  void _onTypingChanged() {
    final state = Provider.of<AppState>(context, listen: false);
    final hasText = _text.text.trim().isNotEmpty;
    state.setChatTyping(_chatId, hasText);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) state.setChatTyping(_chatId, false);
    });
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatMessageDate(dynamic value) {
    final dt = _toDateTime(value)?.toLocal();
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(dt);
  }

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
      replyToId: _replyTo?['id'] as String?,
      replyPreview: (_replyTo?['text'] ?? '').toString(),
    );
    _text.clear();
    setState(() => _replyTo = null);
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
        title: StreamBuilder(
          stream: state.firebase.getUserStream(widget.targetUid),
          builder: (context, snap) {
            final other = snap.data;
            final hasMood = other != null &&
                other.moodStatus.trim().isNotEmpty &&
                other.moodExpiresAt != null &&
                other.moodExpiresAt!.isAfter(DateTime.now());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.targetUser),
                if (hasMood)
                  Text(
                    '${other.moodStatus} until ${DateFormat('h:mm a').format(other.moodExpiresAt!.toLocal())}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _search.clear();
              });
            },
          ),
          // ── Mesh Chat Toggle ────────────────────────────────────────────
          Tooltip(
            message: 'Switch to Mesh Chat (offline)',
            child: IconButton(
              icon: Stack(
                alignment: Alignment.topRight,
                children: [
                  const Icon(Icons.bluetooth),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeshChatScreen(
                      targetUid: widget.targetUid,
                      targetName: widget.targetUser,
                    ),
                  ),
                );
              },
            ),
          ),
          // ── More options ────────────────────────────────────────────────
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
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search messages',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: state.getChatTyping(_chatId),
            builder: (context, typingSnap) {
              final typingDocs = typingSnap.data ?? const [];
              final otherTyping = typingDocs.any((d) {
                if (d['id'] == myUid) return false;
                if (d['is_typing'] != true) return false;
                final ts = _toDateTime(d['updated_at']);
                if (ts == null) return false;
                return DateTime.now().difference(ts.toLocal()).inSeconds < 12;
              });
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: otherTyping ? 24 : 0,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: otherTyping
                    ? const Text('Typing...',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                    : null,
              );
            },
          ),
          // Messages (real-time from Firestore)
          Expanded(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: state.getChatMeta(_chatId),
              builder: (ctx, metaSnap) {
                final meta = metaSnap.data;
                final seenMap = (meta?['seen_by_uid'] as Map?) ?? const {};
                final seenByOther = _toDateTime(seenMap[widget.targetUid]);
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: state.getChatMessages(_chatId),
                  builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text("Error loading messages: ${snap.error}",
                        style: const TextStyle(color: Colors.red)));
                }
                final rawMsgs = snap.data ?? [];
                final now = DateTime.now();
                if (rawMsgs.isNotEmpty &&
                    (_lastSeenWrite == null ||
                        now.difference(_lastSeenWrite!).inSeconds >= 5)) {
                  _lastSeenWrite = now;
                  state.markChatSeen(_chatId);
                }
                final filtered = rawMsgs.where((m) {
                  final deletedFor = (m['deleted_for'] as List?) ?? const [];
                  if (deletedFor.contains(myUid)) return false;
                  final q = _search.text.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  final txt = (m['text'] ?? '').toString().toLowerCase();
                  final sender = (m['sender_username'] ?? '').toString().toLowerCase();
                  return txt.contains(q) || sender.contains(q);
                }).toList();
                filtered.sort((a, b) {
                  final ad = _toDateTime(a['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bd = _toDateTime(b['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return ad.compareTo(bd);
                });
                final msgs = filtered;
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text("No messages yet. Say hello!",
                        style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) {
                    final m = msgs[i];
                    final isMe = m['sender_uid'] == myUid;
                    final msgTime = _toDateTime(m['timestamp'])?.toLocal();
                    final prevTime = i > 0 ? _toDateTime(msgs[i - 1]['timestamp'])?.toLocal() : null;
                    final showDayHeader =
                        msgTime != null && (prevTime == null || !_isSameDay(msgTime, prevTime));
                    final isDeleted = m['is_deleted'] == true;
                    final canEdit = isMe &&
                        msgTime != null &&
                        DateTime.now().difference(msgTime) <= _editWindow &&
                        !isDeleted;

                    final reactionMap = Map<String, dynamic>.from(
                        (m['reactions'] as Map?) ?? const {});

                    return Column(
                      children: [
                        if (showDayHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _formatDayLabel(msgTime),
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ),
                        GestureDetector(
                          onLongPress: () async {
                            await showModalBottomSheet<void>(
                              context: context,
                              builder: (sheetCtx) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        children: _reactionOptions.map((emoji) {
                                          final users = List<dynamic>.from(reactionMap[emoji] ?? const []);
                                          final hasMine = users.contains(myUid);
                                          return ChoiceChip(
                                            label: Text(emoji),
                                            selected: hasMine,
                                            onSelected: (_) async {
                                              Navigator.pop(sheetCtx);
                                              await state.toggleChatReaction(
                                                chatId: _chatId,
                                                messageId: m['id'],
                                                emoji: emoji,
                                                add: !hasMine,
                                              );
                                            },
                                          );
                                        }).toList(),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.reply),
                                        title: const Text('Reply'),
                                        onTap: () {
                                          Navigator.pop(sheetCtx);
                                          setState(() {
                                            _replyTo = {
                                              'id': m['id'],
                                              'text': (m['text'] ?? '[attachment]').toString(),
                                            };
                                          });
                                        },
                                      ),
                                      if (canEdit)
                                        ListTile(
                                          leading: const Icon(Icons.edit),
                                          title: const Text('Edit'),
                                          onTap: () async {
                                            Navigator.pop(sheetCtx);
                                            final c = TextEditingController(text: (m['text'] ?? '').toString());
                                            final updated = await showDialog<String>(
                                              context: context,
                                              builder: (dctx) => AlertDialog(
                                                title: const Text('Edit message'),
                                                content: TextField(controller: c, maxLines: 4),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dctx, c.text.trim()),
                                                    child: const Text('Save'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (updated != null && updated.isNotEmpty) {
                                              await state.editChatMessage(_chatId, m['id'], updated);
                                            }
                                          },
                                        ),
                                      if (isMe)
                                        ListTile(
                                          leading: const Icon(Icons.delete_sweep),
                                          title: const Text('Delete for everyone'),
                                          onTap: () async {
                                            Navigator.pop(sheetCtx);
                                            await state.deleteChatMessageForEveryone(_chatId, m['id']);
                                          },
                                        ),
                                      ListTile(
                                        leading: const Icon(Icons.delete_outline),
                                        title: const Text('Delete for me'),
                                        onTap: () async {
                                          Navigator.pop(sheetCtx);
                                          await state.deleteChatMessageForMe(_chatId, m['id']);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
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
                              if ((m['reply_preview'] ?? '').toString().isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.white24 : Colors.black12,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (m['reply_preview'] as String).toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isMe ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
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
                              if (isDeleted)
                                Text(
                                  'This message was deleted',
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : Colors.black45,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else if (m['text'] != null &&
                                  m['text'].toString().isNotEmpty)
                                Text(m['text'],
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black)),
                              if (reactionMap.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  children: reactionMap.entries
                                      .where((e) => (e.value as List).isNotEmpty)
                                      .map((e) => Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isMe ? Colors.white24 : Colors.black12,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text('${e.key} ${(e.value as List).length}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isMe ? Colors.white70 : Colors.black54)),
                                          ))
                                      .toList(),
                                ),
                              if (_formatMessageDate(m['timestamp']).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatMessageDate(m['timestamp']),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isMe ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          seenByOther != null &&
                                                  msgTime != null &&
                                                  !seenByOther.isBefore(msgTime)
                                              ? Icons.done_all
                                              : Icons.done,
                                          size: 13,
                                          color: seenByOther != null &&
                                                  msgTime != null &&
                                                  !seenByOther.isBefore(msgTime)
                                              ? Colors.lightGreenAccent
                                              : Colors.white70,
                                        ),
                                      ],
                                      if (m['edited_at'] != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(edited)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                        ),
                      ],
                    );
                  },
                );
                  },
                );
              },
            ),
          ),

          if (_replyTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              color: Colors.black12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying: ${(_replyTo?['text'] ?? '').toString()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2))
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _pickFile),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLines: 6,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withAlpha(80),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _send(text: _text.text)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const SizedBox.shrink(),
    );
  }
}