import 'dart:collection';
import 'mesh_encryption_service.dart';

/// MeshRouter centralizes packet deduplication and forwarding policy.
class MeshRouter {
  final int maxSeen;
  final int maxHops;

  final Set<String> _seenMessageIds = {};
  final Queue<String> _seenQueue = Queue<String>();

  MeshRouter({
    this.maxSeen = 800,
    this.maxHops = 5,
  });

  bool markSeen(String messageId) {
    if (_seenMessageIds.contains(messageId)) {
      return false;
    }
    _seenMessageIds.add(messageId);
    _seenQueue.add(messageId);
    if (_seenMessageIds.length > maxSeen) {
      final oldest = _seenQueue.removeFirst();
      _seenMessageIds.remove(oldest);
    }
    return true;
  }

  bool shouldForward(MeshWirePacket packet, String myUid, {required bool relayEnabled}) {
    if (!relayEnabled) return false;
    if (packet.ttl <= 0) return false;
    if (packet.hopCount >= maxHops) return false;
    if (packet.hasVisited(myUid)) return false;
    return true;
  }

  MeshWirePacket nextRelayPacket(MeshWirePacket packet, String relayUid) {
    return packet.withRelay(relayUid);
  }

  void clear() {
    _seenMessageIds.clear();
    _seenQueue.clear();
  }
}
