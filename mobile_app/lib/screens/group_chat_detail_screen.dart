import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import 'mesh_chat_screen.dart';

class GroupChatDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String creatorUid;

  const GroupChatDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.creatorUid = '',
  });

  @override
  State<GroupChatDetailScreen> createState() => _GroupChatDetailScreenState();
}

class _GroupChatDetailScreenState extends State<GroupChatDetailScreen> {
  final _text = TextEditingController();
  final _search = TextEditingController();

  Map<String, dynamic>? _replyTo;
  bool _showSearch = false;
  Timer? _typingDebounce;

  static const _reactionOptions = ['👍', '❤️', '😂', '🔥', '👏'];
  static const _editWindow = Duration(minutes: 15);

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

  void _send({String? text, String? fileUrl, String? fileType}) {
    if ((text == null || text.isEmpty) && fileUrl == null) return;
    final state = Provider.of<AppState>(context, listen: false);
    state.sendGroupMessage(
      groupId: widget.groupId,
      text: text,
      fileUrl: fileUrl,
      fileType: fileType,
      replyToId: _replyTo?['id'] as String?,
      replyPreview: (_replyTo?['text'] ?? '').toString(),
    );
    _text.clear();
    state.setGroupTyping(widget.groupId, false);
    setState(() => _replyTo = null);
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTypingChanged);
  }

  void _onTypingChanged() {
    final state = Provider.of<AppState>(context, listen: false);
    final hasText = _text.text.trim().isNotEmpty;
    state.setGroupTyping(widget.groupId, hasText);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) state.setGroupTyping(widget.groupId, false);
    });
  }

  Future<void> _pickFile() async {
    final state = Provider.of<AppState>(context, listen: false);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final path =
          'group_files/${widget.groupId}/${DateTime.now().millisecondsSinceEpoch}';
      final url = await state.firebase.uploadFile(File(x.path), path);
      _send(fileUrl: url, fileType: 'image');
    }
  }

  Future<List<AppUser>> _loadGroupMembers(List<dynamic> memberUids) async {
    final state = Provider.of<AppState>(context, listen: false);
    final users = await Future.wait(
      memberUids.map((uid) => state.firebase.getUser(uid.toString())),
    );
    final out = users.whereType<AppUser>().toList();
    out.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return out;
  }

  Future<void> _promptRoleUpdate({
    required bool promote,
    required List<dynamic> memberUids,
    required Map<String, dynamic> roles,
    required String creatorUid,
  }) async {
    final state = Provider.of<AppState>(context, listen: false);
    final myUid = state.currentUser?.uid ?? '';

    final selectedUid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(promote ? 'Promote Member to Admin' : 'Demote Admin to Member'),
        content: SizedBox(
          width: 360,
          height: 380,
          child: FutureBuilder<List<AppUser>>(
            future: _loadGroupMembers(memberUids),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snap.data!;
              final filtered = users.where((u) {
                if (u.uid == creatorUid || u.uid == myUid) return false;
                final role = (roles[u.uid] ?? 'member').toString();
                return promote ? role != 'admin' : role == 'admin';
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    promote ? 'No eligible members to promote.' : 'No admins to demote.',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final user = filtered[i];
                  final role = (roles[user.uid] ?? 'member').toString();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatarFormal.isNotEmpty
                          ? NetworkImage(user.avatarFormal)
                          : null,
                      child: user.avatarFormal.isEmpty
                          ? Text(
                              user.username.isNotEmpty
                                  ? user.username[0].toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    title: Text(user.username),
                    subtitle: Text('${user.fullName.isEmpty ? 'User' : user.fullName} • $role'),
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(ctx, user.uid),
                      child: Text(promote ? 'Promote' : 'Demote'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (selectedUid == null || selectedUid.isEmpty || !mounted) return;
    await state.setGroupRole(
      groupId: widget.groupId,
      uid: selectedUid,
      role: promote ? 'admin' : 'member',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(promote ? 'Member promoted to admin' : 'Admin demoted to member'),
      ),
    );
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _text.removeListener(_onTypingChanged);
    final state = Provider.of<AppState>(context, listen: false);
    state.setGroupTyping(widget.groupId, false);
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myUid = state.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName, style: const TextStyle(fontSize: 16)),
            const Text('Group Chat', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
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
          Tooltip(
            message: 'Open Mesh Chat (offline)',
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
                      targetUid: widget.groupId,
                      targetName: '${widget.groupName} (mesh)',
                    ),
                  ),
                );
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              final meta = await state.getGroupMeta(widget.groupId).first;
              final creatorUid = (meta?['creator'] ?? widget.creatorUid).toString();
              final admins = ((meta?['admins'] as List?) ?? const []).cast<dynamic>();
              final members = ((meta?['members'] as List?) ?? const []).cast<dynamic>();
              final roles = Map<String, dynamic>.from((meta?['roles'] as Map?) ?? const {});
              final isAdmin = creatorUid == myUid || admins.contains(myUid);

              if (value == 'clear') {
                if (!context.mounted) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Group Chat'),
                    content: const Text('Delete all messages? The group will remain.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await state.clearGroupChat(widget.groupId);
                }
              } else if (value == 'delete') {
                if (!context.mounted) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Group'),
                    content: const Text('Delete this group chat entirely? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await state.deleteGroupChat(widget.groupId);
                  if (context.mounted) Navigator.pop(context);
                }
              } else if (value == 'promote' && isAdmin) {
                await _promptRoleUpdate(
                  promote: true,
                  memberUids: members,
                  roles: roles,
                  creatorUid: creatorUid,
                );
              } else if (value == 'demote' && isAdmin) {
                await _promptRoleUpdate(
                  promote: false,
                  memberUids: members,
                  roles: roles,
                  creatorUid: creatorUid,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('Clear Messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'promote',
                child: Row(
                  children: [
                    Icon(Icons.upgrade, size: 20),
                    SizedBox(width: 8),
                    Text('Promote member'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'demote',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, size: 20),
                    SizedBox(width: 8),
                    Text('Demote admin'),
                  ],
                ),
              ),
              if (myUid == widget.creatorUid)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Group', style: TextStyle(color: Colors.red)),
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
                  hintText: 'Search group messages',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: state.getGroupTyping(widget.groupId),
            builder: (context, typingSnap) {
              final typingDocs = typingSnap.data ?? const [];
              final typingUsers = typingDocs.where((d) {
                if (d['id'] == myUid) return false;
                if (d['is_typing'] != true) return false;
                final ts = _toDateTime(d['updated_at']);
                if (ts == null) return false;
                return DateTime.now().difference(ts.toLocal()).inSeconds < 12;
              }).toList();
              final bool hasTyping = typingUsers.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: hasTyping ? 24 : 0,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: hasTyping
                    ? Text(
                        typingUsers.length == 1
                            ? 'Someone is typing...'
                            : '${typingUsers.length} people are typing...',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    : null,
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: state.getGroupMeta(widget.groupId),
              builder: (ctx, metaSnap) {
                final groupMeta = metaSnap.data;
                final creatorUid = (groupMeta?['creator'] ?? widget.creatorUid).toString();
                final admins = ((groupMeta?['admins'] as List?) ?? const []).cast<dynamic>();
                final isAdmin = creatorUid == myUid || admins.contains(myUid);
                final pinnedId = groupMeta?['pinned_message_id'] as String?;

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: state.getGroupMessages(widget.groupId),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error loading messages: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final rawMsgs = snap.data ?? [];
                    final msgs = rawMsgs.where((m) {
                      final deletedFor = (m['deleted_for'] as List?) ?? const [];
                      if (deletedFor.contains(myUid)) return false;
                      final q = _search.text.trim().toLowerCase();
                      if (q.isEmpty) return true;
                      final txt = (m['text'] ?? '').toString().toLowerCase();
                      final sender = (m['sender_username'] ?? '').toString().toLowerCase();
                      return txt.contains(q) || sender.contains(q);
                    }).toList()
                      ..sort((a, b) {
                        final ad = _toDateTime(a['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bd = _toDateTime(b['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return ad.compareTo(bd);
                      });

                    if (msgs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet.\nSay hello to the group!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    Map<String, dynamic>? pinned;
                    if (pinnedId != null) {
                      for (final m in msgs) {
                        if (m['id'] == pinnedId) {
                          pinned = m;
                          break;
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (pinned != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.push_pin, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (pinned['text'] ?? '[attachment]').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (isAdmin)
                                  GestureDetector(
                                    onTap: () => state.unpinGroupMessage(widget.groupId),
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: msgs.length,
                            itemBuilder: (ctx, i) {
                              final m = msgs[i];
                              final isMe = m['sender_uid'] == myUid;
                              final sender = m['sender_username'] ?? '';
                              final msgTime = _toDateTime(m['timestamp'])?.toLocal();
                              final prevTime =
                                  i > 0 ? _toDateTime(msgs[i - 1]['timestamp'])?.toLocal() : null;
                              final showDayHeader =
                                  msgTime != null && (prevTime == null || !_isSameDay(msgTime, prevTime));
                              final isDeleted = m['is_deleted'] == true;
                              final canEdit = isMe &&
                                  msgTime != null &&
                                  DateTime.now().difference(msgTime) <= _editWindow &&
                                  !isDeleted;
                              final reactionMap =
                                  Map<String, dynamic>.from((m['reactions'] as Map?) ?? const {});

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
                                                    final users =
                                                        List<dynamic>.from(reactionMap[emoji] ?? const []);
                                                    final hasMine = users.contains(myUid);
                                                    return ChoiceChip(
                                                      label: Text(emoji),
                                                      selected: hasMine,
                                                      onSelected: (_) async {
                                                        Navigator.pop(sheetCtx);
                                                        await state.toggleGroupReaction(
                                                          groupId: widget.groupId,
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
                                                      final c = TextEditingController(
                                                          text: (m['text'] ?? '').toString());
                                                      final updated = await showDialog<String>(
                                                        context: context,
                                                        builder: (dctx) => AlertDialog(
                                                          title: const Text('Edit message'),
                                                          content: TextField(controller: c, maxLines: 4),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () => Navigator.pop(dctx),
                                                                child: const Text('Cancel')),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(dctx, c.text.trim()),
                                                              child: const Text('Save'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (updated != null && updated.isNotEmpty) {
                                                        await state.editGroupMessage(
                                                            widget.groupId, m['id'], updated);
                                                      }
                                                    },
                                                  ),
                                                if (isMe)
                                                  ListTile(
                                                    leading: const Icon(Icons.delete_sweep),
                                                    title: const Text('Delete for everyone'),
                                                    onTap: () async {
                                                      Navigator.pop(sheetCtx);
                                                      await state.deleteGroupMessageForEveryone(
                                                          widget.groupId, m['id']);
                                                    },
                                                  ),
                                                ListTile(
                                                  leading: const Icon(Icons.delete_outline),
                                                  title: const Text('Delete for me'),
                                                  onTap: () async {
                                                    Navigator.pop(sheetCtx);
                                                    await state.deleteGroupMessageForMe(
                                                        widget.groupId, m['id']);
                                                  },
                                                ),
                                                if (isAdmin)
                                                  ListTile(
                                                    leading: const Icon(Icons.push_pin),
                                                    title: Text(pinnedId == m['id'] ? 'Unpin' : 'Pin message'),
                                                    onTap: () async {
                                                      Navigator.pop(sheetCtx);
                                                      if (pinnedId == m['id']) {
                                                        await state.unpinGroupMessage(widget.groupId);
                                                      } else {
                                                        await state.pinGroupMessage(widget.groupId, m['id']);
                                                      }
                                                    },
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                isMe ? 'You' : sender,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe ? Colors.white70 : Colors.indigo.shade400,
                                                ),
                                              ),
                                            ),
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
                                                padding: const EdgeInsets.only(bottom: 5),
                                                child: CachedNetworkImage(
                                                  imageUrl: m['file_url'],
                                                  placeholder: (c, u) => const CircularProgressIndicator(),
                                                  errorWidget: (c, u, e) =>
                                                      const Icon(Icons.insert_drive_file),
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
                                              Text(
                                                m['text'],
                                                style: TextStyle(
                                                  color: isMe ? Colors.white : Colors.black,
                                                ),
                                              ),
                                            if (reactionMap.isNotEmpty)
                                              Wrap(
                                                spacing: 6,
                                                children: reactionMap.entries
                                                    .where((e) => (e.value as List).isNotEmpty)
                                                    .map((e) => Container(
                                                          margin: const EdgeInsets.only(top: 6),
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                isMe ? Colors.white24 : Colors.black12,
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            '${e.key} ${(e.value as List).length}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  isMe ? Colors.white70 : Colors.black54,
                                                            ),
                                                          ),
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
                                                        color:
                                                            isMe ? Colors.white70 : Colors.black54,
                                                      ),
                                                    ),
                                                    if (m['edited_at'] != null) ...[
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '(edited)',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isMe
                                                              ? Colors.white70
                                                              : Colors.black54,
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
                          ),
                        ),
                      ],
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
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickFile),
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
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send), onPressed: () => _send(text: _text.text)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
