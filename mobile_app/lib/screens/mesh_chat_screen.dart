import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/mesh_db_service.dart';
import '../services/mesh_service.dart';

/// Full-screen mesh chat between the current user and [targetUid].
///
/// Messages are sent and received entirely over BLE + Wi-Fi Direct (no internet
/// required). Firebase sync happens automatically in the background via
/// [MeshSyncService] when connectivity returns.
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

  final Map<String, List<MeshMessage>> _conversationCache = {};
  List<MeshMessage> _messages = [];
  String? _selectedRecipientUid;
  String? _selectedRecipientName;
  String? _selectedRecipientStatus;
  bool _meshActive = false;
  bool _isSending = false;
  bool _showDebugPanel = false;
  StreamSubscription<MeshMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    _meshActive = false;
    if (widget.targetUid != 'broadcast') {
      _selectedRecipientUid = widget.targetUid;
      _selectedRecipientName = widget.targetName;
    }
    _load();
  }

  @override
  void dispose() {
    if (_meshActive) {
      final state = Provider.of<AppState>(context, listen: false);
      state.stopMesh();
    }
    _msgSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final state = Provider.of<AppState>(context, listen: false);
    final myUid = state.currentUser?.uid ?? '';
    final recipientUid = _selectedRecipientUid;
    if (recipientUid == null) {
      if (!mounted) return;
      setState(() => _messages = []);
      return;
    }

    final cached = _conversationCache[recipientUid];
    if (cached != null) {
      if (!mounted) return;
      setState(() => _messages = List<MeshMessage>.from(cached));
      _scrollToBottom();
      return;
    }

    final msgs = await _db.getConversation(myUid, recipientUid);
    if (!mounted) return;
    _conversationCache[recipientUid] = List<MeshMessage>.from(msgs);
    setState(() => _messages = msgs);
    _scrollToBottom();
  }

  void _subscribeToIncoming() {
    _msgSub?.cancel();
    final state = Provider.of<AppState>(context, listen: false);
    final recipientUid = _selectedRecipientUid;
    if (recipientUid == null) {
      _msgSub = null;
      return;
    }
    _msgSub = state.meshService.incomingMessages.listen((msg) {
      // Only add messages from/to the active conversation.
      if (msg.senderId == recipientUid || msg.receiverId == recipientUid) {
        if (!mounted) return;
        setState(() {
          _messages.add(msg);
          _conversationCache[recipientUid] = List<MeshMessage>.from(_messages);
        });
        _scrollToBottom();
      }
    });
  }

  void _unsubscribeFromIncoming() {
    _msgSub?.cancel();
    _msgSub = null;
  }

  Future<void> _selectRecipient(_MeshRecipient peer) async {
    final previousRecipient = _selectedRecipientUid;
    if (previousRecipient == peer.uid && _selectedRecipientName == peer.name) {
      return;
    }

    if (previousRecipient != null) {
      _conversationCache[previousRecipient] = List<MeshMessage>.from(_messages);
    }

    setState(() {
      _selectedRecipientUid = peer.uid;
      _selectedRecipientName = peer.name;
      _selectedRecipientStatus = peer.statusLabel;
      _messages = _conversationCache[peer.uid] ?? <MeshMessage>[];
    });

    if (_meshActive) {
      _subscribeToIncoming();
    }
    await _load();
  }

  List<_MeshRecipient> _buildRecipients(AppState state, String myUid) {
    final recipients = <String, _MeshRecipient>{};

    for (final entry in state.meshService.bleDiscoveredPeers.entries) {
      final user = entry.value;
      recipients[user.uid] = _MeshRecipient(
        uid: user.uid,
        name: user.username.isNotEmpty ? user.username : _shortName(user.uid),
        statusLabel: state.meshService.connectedPeerEndpoints.containsKey(user.uid)
            ? 'connected'
            : (state.meshService.meshState == MeshState.connecting ||
                    state.meshService.meshState == MeshState.discovered)
                ? 'connecting'
                : 'available',
        rssi: user.rssi,
        distanceM: user.distanceM,
        sourceLabel: 'BLE',
        isConnected: state.meshService.connectedPeerEndpoints.containsKey(user.uid),
      );
    }

    for (final peer in state.meshService.peers) {
      recipients.putIfAbsent(
        peer.uid,
        () => _MeshRecipient(
          uid: peer.uid,
          name: _shortName(peer.uid),
          statusLabel: 'connected',
          rssi: null,
          distanceM: null,
          sourceLabel: 'Wi-Fi Direct',
          isConnected: true,
        ),
      );
    }

    if (_selectedRecipientUid != null &&
        !recipients.containsKey(_selectedRecipientUid)) {
      recipients[_selectedRecipientUid!] = _MeshRecipient(
        uid: _selectedRecipientUid!,
        name: _selectedRecipientName ?? _shortName(_selectedRecipientUid!),
        statusLabel: _selectedRecipientStatus ?? 'available',
        rssi: null,
        distanceM: null,
        sourceLabel: 'Conversation',
        isConnected: false,
      );
    }

    if (widget.targetUid == 'broadcast' && recipients.isEmpty) {
      return const <_MeshRecipient>[];
    }

    final list = recipients.values.toList();
    list.sort((a, b) {
      if (a.isConnected != b.isConnected) {
        return a.isConnected ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  String _shortName(String uid) {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 8)}…';
  }

  Future<void> _selectFirstAvailableRecipient(AppState state) async {
    final recipients = _buildRecipients(state, state.currentUser?.uid ?? '');
    if (recipients.isNotEmpty && _selectedRecipientUid == null) {
      await _selectRecipient(recipients.first);
    }
  }

  String? get _activeRecipientUid => _selectedRecipientUid;

  String get _recipientTitle => _selectedRecipientName ?? 'Select a device';

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
    if (text.isEmpty || _isSending || !_meshActive || _activeRecipientUid == null) {
      if (_activeRecipientUid == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a device to send message'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final state = Provider.of<AppState>(context, listen: false);
    final recipientUid = _activeRecipientUid!;

    setState(() => _isSending = true);
    try {
      final msg = await state.meshService.sendMessage(
        receiverUid: recipientUid,
        text: text,
      );
      _textCtrl.clear();
      if (!mounted) return;
      setState(() {
        _messages.add(msg);
        _conversationCache[recipientUid] = List<MeshMessage>.from(_messages);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Send failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── mesh toggle ──────────────────────────────────────────────────────────────

  Future<void> _toggleMesh(bool value) async {
    final state = Provider.of<AppState>(context, listen: false);

    if (value) {
      // Start mesh
      await state.startMesh();
      if (widget.targetUid == 'broadcast' && _selectedRecipientUid == null) {
        await _selectFirstAvailableRecipient(state);
      }
      _subscribeToIncoming();
      if (!mounted) return;
      setState(() => _meshActive = true);
    } else {
      // Stop mesh
      _unsubscribeFromIncoming();
      await state.stopMesh();
      if (!mounted) return;
      setState(() => _meshActive = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myUid = state.currentUser?.uid ?? '';
    final recipients = _buildRecipients(state, myUid);
    _MeshRecipient? activeRecipient;
    for (final peer in recipients) {
      if (peer.uid == _selectedRecipientUid) {
        activeRecipient = peer;
        break;
      }
    }
    final canSend = _meshActive && _selectedRecipientUid != null;
    final appBarTitle = _selectedRecipientName ?? widget.targetName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appBarTitle, style: const TextStyle(fontSize: 16)),
            Text(
              _meshActive ? 'Mesh Chat • Active' : 'Mesh Chat',
              style: TextStyle(
                fontSize: 11,
                color: _meshActive ? Colors.greenAccent : Colors.white70,
              ),
            ),
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
              padding: const EdgeInsets.only(right: 4),
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
          // ── Debug toggle ─────────────────────────────────────────────────
          IconButton(
            icon: Icon(
              Icons.bug_report,
              size: 18,
              color: _showDebugPanel ? Colors.amber : Colors.white38,
            ),
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
            tooltip: 'Toggle debug panel',
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
              meshState: state.meshService.meshState,
              isMeshActive: _meshActive,
              peerCount: state.meshService.peers.length,
              bleDiscoveredCount: state.meshService.bleDiscoveredCount,
              isWifiConnected: state.meshService.isWifiDirectConnected,
              socketCount: state.meshService.socketConnectedCount,
            ),

            _RecipientHeader(
              selectedName: _selectedRecipientUid == null
                  ? null
                  : (activeRecipient?.name ?? _recipientTitle),
              selectedStatus: _selectedRecipientUid == null
                  ? null
                  : (activeRecipient?.statusLabel ?? 'available'),
              isMeshActive: _meshActive,
            ),

            _RecipientPanel(
              recipients: recipients,
              selectedUid: _selectedRecipientUid,
              onSelect: _selectRecipient,
            ),

            if (_selectedRecipientUid == null)
              const _SendWarningBanner(
                text: 'Please select a device to send message',
              ),

            // ── Debug panel ──────────────────────────────────────────────
            if (_showDebugPanel && _meshActive)
              _DebugPanel(meshService: state.meshService),

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
              canSend: canSend,
              warningText: _selectedRecipientUid == null
                  ? 'Please select a device to send message'
                  : null,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recipient selector ───────────────────────────────────────────────────────

class _MeshRecipient {
  final String uid;
  final String name;
  final String statusLabel;
  final int? rssi;
  final double? distanceM;
  final String sourceLabel;
  final bool isConnected;

  const _MeshRecipient({
    required this.uid,
    required this.name,
    required this.statusLabel,
    required this.rssi,
    required this.distanceM,
    required this.sourceLabel,
    required this.isConnected,
  });
}

class _RecipientHeader extends StatelessWidget {
  final String? selectedName;
  final String? selectedStatus;
  final bool isMeshActive;

  const _RecipientHeader({
    required this.selectedName,
    required this.selectedStatus,
    required this.isMeshActive,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedName != null;
    final status = selectedStatus ?? 'no device selected';
    final color = hasSelection
        ? (status == 'connected' ? Colors.greenAccent : Colors.amber)
        : Colors.white54;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15162A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSelection ? color.withValues(alpha: 0.45) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSelection ? Icons.mark_chat_unread : Icons.bluetooth_searching,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSelection ? 'Messaging: $selectedName' : 'Messaging: Select a device',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasSelection
                      ? (status == 'connected'
                          ? 'Connected and ready to send'
                          : status == 'connecting'
                              ? 'Connecting via Wi-Fi Direct...'
                              : 'Available for messaging')
                      : 'Please select a device to send message',
                  style: TextStyle(
                    color: isMeshActive ? Colors.white70 : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (hasSelection)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipientPanel extends StatelessWidget {
  final List<_MeshRecipient> recipients;
  final String? selectedUid;
  final ValueChanged<_MeshRecipient> onSelect;

  const _RecipientPanel({
    required this.recipients,
    required this.selectedUid,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101326).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              const Text(
                'Nearby devices',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                recipients.isEmpty ? 'No peers found' : '${recipients.length} available',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recipients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No nearby devices yet',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 176,
              child: ListView.separated(
                itemCount: recipients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final peer = recipients[index];
                  final isSelected = peer.uid == selectedUid;
                  final statusColor = peer.isConnected
                      ? Colors.greenAccent
                      : peer.statusLabel == 'connecting'
                          ? Colors.amber
                          : Colors.white54;
                  return InkWell(
                    onTap: () => onSelect(peer),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.025),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.cyanAccent : Colors.white12,
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: statusColor.withValues(alpha: 0.15),
                            child: Icon(
                              peer.isConnected
                                  ? Icons.wifi_tethering
                                  : Icons.bluetooth,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        peer.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, size: 18, color: Colors.cyanAccent),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${peer.sourceLabel} • ${peer.statusLabel}',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                  ),
                                ),
                                if (peer.rssi != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Signal: ${peer.rssi} dBm${peer.distanceM != null ? ' • ${peer.distanceM!.toStringAsFixed(1)} m' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SendWarningBanner extends StatelessWidget {
  final String text;

  const _SendWarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mesh status banner ────────────────────────────────────────────────────────

class _MeshStatusBanner extends StatelessWidget {
  final MeshState meshState;
  final bool isMeshActive;
  final int peerCount;
  final int bleDiscoveredCount;
  final bool isWifiConnected;
  final int socketCount;

  const _MeshStatusBanner({
    required this.meshState,
    required this.isMeshActive,
    required this.peerCount,
    required this.bleDiscoveredCount,
    required this.isWifiConnected,
    required this.socketCount,
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

    String statusText;
    IconData statusIcon;
    Color statusColor;

    switch (meshState) {
      case MeshState.connected:
      case MeshState.relaying:
        statusText = '$peerCount peer${peerCount > 1 ? 's' : ''} connected (Wi-Fi Direct primary • BLE fallback available)';
        statusIcon = Icons.check_circle;
        statusColor = Colors.greenAccent;
        break;
      case MeshState.connecting:
        statusText = isWifiConnected
            ? 'Wi-Fi Direct connected — handshaking…'
            : 'Establishing Wi-Fi Direct connection…';
        statusIcon = Icons.sync;
        statusColor = Colors.amber;
        break;
      case MeshState.discovered:
        statusText = '$bleDiscoveredCount device${bleDiscoveredCount > 1 ? 's' : ''} found via BLE — connecting Wi-Fi Direct…';
        statusIcon = Icons.bluetooth_searching;
        statusColor = Colors.amber;
        break;
      case MeshState.scanning:
        statusText = 'Scanning via BLE + Wi-Fi Direct…';
        statusIcon = Icons.radar;
        statusColor = Colors.amber;
        break;
      case MeshState.initializing:
        statusText = 'Initializing mesh…';
        statusIcon = Icons.hourglass_top;
        statusColor = Colors.white54;
        break;
      case MeshState.inactive:
        statusText = 'Mesh inactive';
        statusIcon = Icons.power_off;
        statusColor = Colors.white38;
        break;
    }

    final isGood = meshState == MeshState.connected || meshState == MeshState.relaying;

    return Container(
      width: double.infinity,
      color: isGood
          ? Colors.green.shade900.withValues(alpha: 0.6)
          : Colors.orange.shade900.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, color: statusColor),
                ),
              ),
            ],
          ),
          if (bleDiscoveredCount > 0 || socketCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'BLE: $bleDiscoveredCount found  •  '
                'Wi-Fi: ${isWifiConnected ? "✓" : "—"}  •  '
                'Sockets: $socketCount  •  '
                'Peers: $peerCount',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Debug panel ───────────────────────────────────────────────────────────────

class _DebugPanel extends StatelessWidget {
  final MeshService meshService;

  const _DebugPanel({required this.meshService});

  @override
  Widget build(BuildContext context) {
    final info = meshService.statusInfo;
    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔧 Mesh Debug',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 4),
          _debugRow('State', info.state.name),
          _debugRow('BLE Discovered', '${info.bleDiscoveredCount}'),
          _debugRow('Socket Connected', '${info.socketCount}'),
          _debugRow('Identified Peers', '${info.connectedPeerCount}'),
          _debugRow('Group Owner', info.isGroupOwner ? 'YES' : 'NO'),
          if (info.groupOwnerAddress.isNotEmpty)
            _debugRow('GO Address', info.groupOwnerAddress),
          _debugRow('Max Hops', '$kMaxHops'),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontFamily: 'monospace',
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.bluetooth,
                                size: 9,
                                color: Colors.greenAccent),
                            const SizedBox(width: 3),
                            Text(
                              message.hopCount > 0
                                  ? 'mesh • ${message.hopCount} hop${message.hopCount > 1 ? "s" : ""}'
                                  : 'mesh',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.greenAccent),
                            ),
                          ],
                        ),
                      ),
                      // Transport badge (BLE vs Wi-Fi Direct)
                      if (message.transport != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: message.transport == 'ble'
                                ? Colors.blueAccent.withValues(alpha: 0.18)
                                : Colors.amberAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                message.transport == 'ble'
                                    ? Icons.signal_cellular_alt
                                    : Icons.router,
                                size: 9,
                                color: message.transport == 'ble'
                                    ? Colors.blueAccent
                                    : Colors.amberAccent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                message.transport == 'ble'
                                    ? 'BLE'
                                    : 'Wi-Fi',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: message.transport == 'ble'
                                      ? Colors.blueAccent
                                      : Colors.amberAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
  final bool canSend;
  final String? warningText;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.isMeshActive,
    required this.canSend,
    required this.warningText,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warningText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  warningText!,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: isMeshActive && canSend,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isMeshActive
                          ? (canSend ? 'Mesh message…' : 'Select a device to send')
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
                    color: (isMeshActive && canSend)
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
                    onPressed: (isMeshActive && canSend) ? onSend : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
