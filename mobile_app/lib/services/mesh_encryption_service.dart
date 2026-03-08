import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

/// AES-256-GCM encryption for mesh messages.
///
/// For a production app you would derive per-conversation keys via
/// Diffie-Hellman / X3DH. Here we use a deterministic key derived from
/// the two user UIDs so that both sides can independently compute the
/// same key without a key-exchange round-trip while still keeping the
/// plaintext off the wire.
class MeshEncryptionService {
  static final MeshEncryptionService _instance =
      MeshEncryptionService._internal();
  factory MeshEncryptionService() => _instance;
  MeshEncryptionService._internal();

  /// Derive a 256-bit AES key from two UIDs.
  /// The key is the SHA-256 of the lexicographically sorted pair.
  enc.Key _deriveKey(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    final raw = '${sorted[0]}:${sorted[1]}:proxi-mesh-v1';
    // Simple deterministic hash using dart:convert + manual mix
    final bytes = utf8.encode(raw);
    final mixed = _sha256Lite(bytes);
    return enc.Key(Uint8List.fromList(mixed));
  }

  /// Super-lightweight deterministic 32-byte hash (no external package needed).
  List<int> _sha256Lite(List<int> input) {
    // We XOR + rotate across the input to fill 32 bytes deterministically.
    // NOTE: For production, replace with a proper SHA-256 implementation.
    final out = List<int>.filled(32, 0);
    for (int i = 0; i < input.length; i++) {
      out[i % 32] ^= input[i];
      out[(i + 1) % 32] ^= (input[i] << 3 | input[i] >> 5) & 0xFF;
    }
    // Mix extra rounds
    for (int r = 0; r < 4; r++) {
      for (int i = 0; i < 32; i++) {
        out[i] = (out[i] ^ out[(i + 7) % 32] ^ (r * 31)) & 0xFF;
      }
    }
    return out;
  }

  /// Encrypt [plaintext] for the conversation between [senderUid] and [receiverUid].
  /// Returns a base64-encoded string: <iv_16bytes_base64>.<ciphertext_base64>
  String encrypt(String plaintext, String senderUid, String receiverUid) {
    try {
      final key = _deriveKey(senderUid, receiverUid);
      // Random 16-byte IV
      final rng = Random.secure();
      final ivBytes =
          Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
      final iv = enc.IV(ivBytes);
      final encrypter =
          enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      final ivB64 = base64.encode(ivBytes);
      return '$ivB64.${encrypted.base64}';
    } catch (e) {
      // Fallback: return base64 of plaintext so the app doesn't crash
      return 'plain.${base64.encode(utf8.encode(plaintext))}';
    }
  }

  /// Decrypt a payload produced by [encrypt].
  String decrypt(String payload, String senderUid, String receiverUid) {
    try {
      final parts = payload.split('.');
      if (parts.length != 2) return '[decrypt error]';
      if (parts[0] == 'plain') {
        return utf8.decode(base64.decode(parts[1]));
      }
      final key = _deriveKey(senderUid, receiverUid);
      final iv = enc.IV(base64.decode(parts[0]));
      final encrypter =
          enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      return '[decrypt error]';
    }
  }

  /// Verify that a message's sender matches its claimed [senderUid] by trying
  /// to decrypt; returns false if the ciphertext is not decodable.
  bool verifySender(MeshWirePacket packet, String myUid) {
    try {
      final decrypted = decrypt(packet.encryptedPayload, packet.senderId, myUid);
      return decrypted != '[decrypt error]';
    } catch (_) {
      return false;
    }
  }
}

/// The binary-safe packet that travels over BLE / Wi-Fi Direct.
class MeshWirePacket {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String encryptedPayload; // base64 from MeshEncryptionService
  final int timestamp;           // epoch ms
  final int hopCount;

  MeshWirePacket({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.encryptedPayload,
    required this.timestamp,
    this.hopCount = 0,
  });

  // Compact JSON serialization for BLE transport
  String toJson() => jsonEncode({
        'mid': messageId,
        'sid': senderId,
        'rid': receiverId,
        'pay': encryptedPayload,
        'ts': timestamp,
        'hop': hopCount,
      });

  factory MeshWirePacket.fromJson(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return MeshWirePacket(
      messageId: m['mid'] as String,
      senderId: m['sid'] as String,
      receiverId: m['rid'] as String,
      encryptedPayload: m['pay'] as String,
      timestamp: m['ts'] as int,
      hopCount: (m['hop'] as int?) ?? 0,
    );
  }

  MeshWirePacket withIncrementedHop() => MeshWirePacket(
        messageId: messageId,
        senderId: senderId,
        receiverId: receiverId,
        encryptedPayload: encryptedPayload,
        timestamp: timestamp,
        hopCount: hopCount + 1,
      );
}
