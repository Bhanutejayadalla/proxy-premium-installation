import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;

class ChatEncryptionService {
  static final ChatEncryptionService _instance =
      ChatEncryptionService._internal();
  factory ChatEncryptionService() => _instance;
  ChatEncryptionService._internal();

  enc.Key _deriveDmKey(String senderUid, String receiverUid) {
    final sorted = [senderUid, receiverUid]..sort();
    final raw = '${sorted[0]}:${sorted[1]}:proxi-chat-dm-v1';
    final digest = crypto.sha256.convert(utf8.encode(raw));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  enc.Key _deriveGroupKey(String groupId) {
    final raw = '$groupId:proxi-chat-group-v1';
    final digest = crypto.sha256.convert(utf8.encode(raw));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  String _encryptWithKey(String plaintext, enc.Key key) {
    final rng = Random.secure();
    final ivBytes = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final iv = enc.IV(ivBytes);
    final aes = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    final encrypted = aes.encrypt(plaintext, iv: iv);
    return '${base64.encode(ivBytes)}.${encrypted.base64}';
  }

  String _decryptWithKey(String payload, enc.Key key) {
    final parts = payload.split('.');
    if (parts.length != 2) return '[decrypt error]';
    final iv = enc.IV(base64.decode(parts[0]));
    final aes = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    return aes.decrypt64(parts[1], iv: iv);
  }

  String encryptDmText(String plaintext, String senderUid, String receiverUid) {
    return _encryptWithKey(plaintext, _deriveDmKey(senderUid, receiverUid));
  }

  String decryptDmText(String payload, String senderUid, String receiverUid) {
    return _decryptWithKey(payload, _deriveDmKey(senderUid, receiverUid));
  }

  String encryptGroupText(String plaintext, String groupId) {
    return _encryptWithKey(plaintext, _deriveGroupKey(groupId));
  }

  String decryptGroupText(String payload, String groupId) {
    return _decryptWithKey(payload, _deriveGroupKey(groupId));
  }
}