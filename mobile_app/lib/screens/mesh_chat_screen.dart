import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/mesh_db_service.dart';

/// Full-screen mesh chat between the current user and [targetUid].
///
/// Messages are sent and received entirely over BLE (no internet required).
/// Firebase sync happens automatically in the background via [MeshSyncService].
class MeshChatScreen extends StatefulWidget {
  final String targetUid;
  final String targetName;

  const MeshChatScreen({
    super.key,
    required this.targetUid,
    required this.targetName,
  });

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = MeshDbService();

  List<MeshMessage> _messages = [];
  bool _meshActive = false;
  bool _isSending = false;
  StreamSubscription<MeshMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToIncoming();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final state = Provider.of<AppState>(context, listen: false);
    final myUid = state.currentUser?.uid ?? '';
    final msgs = await _db.getConversation(myUid, widget.targetUid);
    if (!mounted) return;
    setState(() => _messages = msgs);
    _scrollToBottom();
  }

  void _subscribeToIncoming() {
    final state = Provider.of<AppState>(context, listen: false);
    _msgSub = state.meshService.incomingMessages.listen((msg) {
      if (msg.senderId == widget.targetUid ||
          msg.receiverId == widget.targetUid) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── send ─────────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final state = Provider.of<AppState>(context, listen: false);
    if (!_meshActive) {
      // Mesh mode is off — inform user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable the Mesh toggle to send offline messages.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    _textCtrl.clear();

    try {
      final msg = await state.meshService.sendMessage(
        receiverUid: widget.targetUid,
        text: text,
      );
      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ── mesh toggle ──────────────────────────────────────────────────────────────

  Future<void> _toggleMesh(bool value) async {
    final state = Provider.of<AppState>(context, listen: false);
    final myUid = state.currentUser?.uid ?? '';

    if (value) {
      // Ensure permissions before starting.
      final ok = await state.meshService.init(myUid);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth, Location permissions, and GPS must be enabled for Mesh Chat.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _meshActive = true);
      await state.meshService.start();
    } else {
      setState(() => _meshActive = false);
      await state.meshService.stop();
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myUid = state.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.targetName,
                style: const TextStyle(fontSize: 16)),
            const Text('Mesh Chat',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          // ── Mesh toggle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _meshActive
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  size: 18,
                  color: _meshActive
                      ? Colors.greenAccent
                      : Colors.white38,
                ),
                const SizedBox(width: 4),
                Text(
                  'Mesh',
                  style: TextStyle(
                    fontSize: 12,
                    color: _meshActive
                        ? Colors.greenAccent
                        : Colors.white38,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _meshActive,
                  onChanged: _toggleMesh,
                  activeThumbColor: Colors.greenAccent,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          // ── Peer count badge ─────────────────────────────────────────────
          if (_meshActive)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Nearby mesh peers',
                child: Chip(
                  avatar: const Icon(Icons.people,
                      size: 14, color: Colors.white),
                  label: Text(
                    '${state.meshService.peers.length}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Column(
          children: [
            // ── Mesh status banner ───────────────────────────────────────
            _MeshStatusBanner(
              isMeshActive: _meshActive,
              peerCount: state.meshService.peers.length,
            ),

            // ── Message list ─────────────────────────────────────────────
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(isMeshActive: _meshActive)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        return _MessageBubble(
                          message: _messages[i],
                          isMine: _messages[i].senderId == myUid,
                        );
                      },
                    ),
            ),

            // ── Input bar ────────────────────────────────────────────────
            _InputBar(
              controller: _textCtrl,
              isSending: _isSending,
              isMeshActive: _meshActive,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mesh status banner ────────────────────────────────────────────────────────

class _MeshStatusBanner extends StatelessWidget {
  final bool isMeshActive;
  final int peerCount;

  const _MeshStatusBanner({
    required this.isMeshActive,
    required this.peerCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMeshActive) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF2D1B69).withValues(alpha: 0.7),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.white54),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Mesh mode is OFF — toggle to send messages without internet',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.green.shade900.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_searching,
              size: 14, color: Colors.greenAccent),
          const SizedBox(width: 4),
          const Icon(Icons.wifi, size: 14, color: Colors.greenAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              peerCount == 0
                  ? 'Scanning via BLE + Wi-Fi Direct…'
                  : '$peerCount nearby device${peerCount > 1 ? 's' : ''} connected (BLE + Wi-Fi)',
              style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isMeshActive;
  const _EmptyState({required this.isMeshActive});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMeshActive
                  ? Icons.bluetooth_searching
                  : Icons.bluetooth_disabled,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              isMeshActive
                  ? 'No messages yet\nSend the first mesh message!'
                  : 'Enable Mesh to chat\nwithout the internet',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MeshMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  String _statusIcon() {
    switch (message.deliveryStatus) {
      case MeshDeliveryStatus.pending:
        return '🕐';
      case MeshDeliveryStatus.relayed:
        return '↔';
      case MeshDeliveryStatus.delivered:
        return '✓';
      case MeshDeliveryStatus.synced:
        return '☁';
    }
  }

  String _statusLabel() {
    switch (message.deliveryStatus) {
      case MeshDeliveryStatus.pending:
        return 'Pending';
      case MeshDeliveryStatus.relayed:
        return 'Relayed (${message.hopCount} hop${message.hopCount != 1 ? 's' : ''})';
      case MeshDeliveryStatus.delivered:
        return 'Delivered';
      case MeshDeliveryStatus.synced:
        return 'Synced to cloud';
    }
  }

  @override
  Widget build(BuildContext context) {
    final time =
        DateFormat('HH:mm').format(message.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.deepPurple,
              child:
                  Icon(Icons.person, size: 14, color: Colors.white),
            ),
          if (!isMine) const SizedBox(width: 6),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMine
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF2D2D44),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      Radius.circular(isMine ? 16 : 4),
                  bottomRight:
                      Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Mesh badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent
                              .withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                Icons.bluetooth,
                                size: 9,
                                color: Colors.greenAccent),
                            SizedBox(width: 3),
                            Text('mesh',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.greenAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Message text
                  Text(
                    message.messageText,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  // Timestamp + status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white54),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: _statusLabel(),
                        child: Text(
                          _statusIcon(),
                          style:
                              const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 6),
          if (isMine)
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF7C3AED),
              child:
                  Icon(Icons.person, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isMeshActive;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.isMeshActive,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F23),
        boxShadow: [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: isMeshActive,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isMeshActive
                      ? 'Mesh message…'
                      : 'Enable Mesh to type',
                  hintStyle:
                      const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2D2D44),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isMeshActive
                    ? const Color(0xFF7C3AED)
                    : Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.send,
                        color: Colors.white, size: 20),
                onPressed: isMeshActive ? onSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
