import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models.dart';

/// Local SQLite store for all offline mesh messages.
/// Schema:
///   table mesh_messages
///     message_id      TEXT PRIMARY KEY
///     sender_id       TEXT NOT NULL
///     receiver_id     TEXT NOT NULL
///     message_text    TEXT NOT NULL
///     timestamp       INTEGER NOT NULL   (epoch ms)
///     delivery_status TEXT NOT NULL      (pending | relayed | delivered | synced)
///     hop_count       INTEGER DEFAULT 0
///     encrypted_payload TEXT DEFAULT ''
class MeshDbService {
  static final MeshDbService _instance = MeshDbService._internal();
  factory MeshDbService() => _instance;
  MeshDbService._internal();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'mesh_messages.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE mesh_messages (
            message_id       TEXT PRIMARY KEY,
            sender_id        TEXT NOT NULL,
            receiver_id      TEXT NOT NULL,
            message_text     TEXT NOT NULL,
            timestamp        INTEGER NOT NULL,
            delivery_status  TEXT NOT NULL DEFAULT 'pending',
            hop_count        INTEGER DEFAULT 0,
            encrypted_payload TEXT DEFAULT '',
            transport        TEXT
          )
        ''');
        // Index for fast look-up by conversation pair
        await db.execute('''
          CREATE INDEX idx_conversation
          ON mesh_messages (sender_id, receiver_id)
        ''');
        // Index for finding unsynced messages quickly
        await db.execute('''
          CREATE INDEX idx_status
          ON mesh_messages (delivery_status)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add transport column if upgrading from v1
          final columns = await db.rawQuery(
            "PRAGMA table_info(mesh_messages)",
          );
          final hasTransport = columns.any(
            (col) => (col['name'] as String?) == 'transport',
          );
          if (!hasTransport) {
            await db.execute(
              'ALTER TABLE mesh_messages ADD COLUMN transport TEXT',
            );
          }
        }
      },
    );
  }

  // ── INSERT ──────────────────────────────────────────────────────────────────

  Future<void> insertMessage(MeshMessage msg) async {
    final db = await _database;
    await db.insert(
      'mesh_messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── UPDATE STATUS ────────────────────────────────────────────────────────────

  Future<void> updateStatus(
      String messageId, MeshDeliveryStatus status) async {
    final db = await _database;
    await db.update(
      'mesh_messages',
      {'delivery_status': status.name},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  // ── QUERY CONVERSATION ───────────────────────────────────────────────────────

  /// Returns all messages between two users (both directions), newest last.
  Future<List<MeshMessage>> getConversation(
      String myUid, String otherUid) async {
    final db = await _database;
    final rows = await db.query(
      'mesh_messages',
      where:
          '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [myUid, otherUid, otherUid, myUid],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MeshMessage.fromMap).toList();
  }

  // ── PENDING RELAY ────────────────────────────────────────────────────────────

  /// Returns all messages addressed to [receiverId] that are still pending
  /// delivery — used by the relay logic to forward to newly seen devices.
  Future<List<MeshMessage>> getPendingForReceiver(String receiverId) async {
    final db = await _database;
    final rows = await db.query(
      'mesh_messages',
      where: "receiver_id = ? AND delivery_status IN ('pending','relayed')",
      whereArgs: [receiverId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MeshMessage.fromMap).toList();
  }

  // ── FIREBASE SYNC ────────────────────────────────────────────────────────────

  /// All messages that haven't been synced to Firebase yet.
  Future<List<MeshMessage>> getUnsynced(String myUid) async {
    final db = await _database;
    final rows = await db.query(
      'mesh_messages',
      where: "sender_id = ? AND delivery_status != 'synced'",
      whereArgs: [myUid],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MeshMessage.fromMap).toList();
  }

  // ── UPSERT FROM FIREBASE ─────────────────────────────────────────────────────

  /// Insert a message received from Firebase cloud sync, if not already present.
  Future<void> upsertFromFirebase(MeshMessage msg) async {
    final db = await _database;
    await db.insert(
      'mesh_messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // don't overwrite local
    );
  }

  // ── MARK ALL SYNCED ──────────────────────────────────────────────────────────

  Future<void> markSynced(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(messageIds.length, '?').join(',');
    await db.rawUpdate(
      "UPDATE mesh_messages SET delivery_status = 'synced' "
      "WHERE message_id IN ($placeholders)",
      messageIds,
    );
  }
}
