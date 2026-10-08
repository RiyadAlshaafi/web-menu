import 'dart:convert';

import 'outbox_store_stub.dart' if (dart.library.io) 'outbox_store_io.dart' as impl;

/// One saved change waiting to be uploaded, in the order it happened.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.failed = false,
  });

  /// Unique id of the change; the server uses it to ignore a repeated upload.
  final String id;

  /// What to upload: `takeout`, `expense`, `shift_open` or `shift_close`.
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// The server refused it for a reason a retry won't fix; kept for review, never deleted.
  final bool failed;
}

/// A receipt or expense the server confirmed, remembered so it can be checked again later
/// (before an app update the till asks the server to confirm all of them).
class SentRecord {
  const SentRecord({required this.id, required this.kind, required this.amount, required this.sentAt});

  final String id;

  /// `takeout` or `expense`.
  final String kind;
  final double amount;
  final DateTime sentAt;
}

/// Durable queue of changes made on this device, plus a few saved values.
abstract class OutboxStore {
  /// The device's store for the server at [serverUrl]: a SQLite file on desktop and mobile,
  /// memory on the web. Each server gets its own file, so work saved while connected to one
  /// database can never be uploaded to another.
  static Future<OutboxStore> open(String serverUrl) => impl.openOutboxStore(serverUrl);

  /// File name of the outbox for [serverUrl] in the app's data folder.
  static String fileNameFor(String serverUrl) => 'offline_outbox_${scopeOf(serverUrl)}.sqlite';

  /// Short stable name for [serverUrl], used in the file name.
  static String scopeOf(String serverUrl) {
    var hash = 0x811c9dc5;
    for (final unit in serverUrl.trim().toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> add(OutboxItem item);

  /// Items still to upload, oldest first.
  Future<List<OutboxItem>> pending();

  /// Items the server refused, oldest first.
  Future<List<OutboxItem>> failed();

  Future<void> remove(String id);

  /// Replaces what an item will upload (for example to fill in the cashier chosen later).
  Future<void> updatePayload(String id, Map<String, dynamic> payload);
  Future<void> noteAttempt(String id, String error);
  Future<void> markFailed(String id, String error);

  /// Puts every refused item back in the queue at its original place, so order is kept.
  Future<void> requeueFailed();
  Future<String?> readValue(String key);
  Future<void> writeValue(String key, String? value);

  /// Remembers an upload the server confirmed.
  Future<void> recordSent(SentRecord record);

  /// Uploads confirmed since [since], oldest first.
  Future<List<SentRecord>> sentSince(DateTime since);

  /// Writes a consistent copy of the whole store to [path] (for the backup before an update).
  /// Returns false when this store keeps nothing on disk.
  Future<bool> backupTo(String path);
}

/// Keeps everything in memory. Used on the web and in tests.
class MemoryOutboxStore implements OutboxStore {
  final List<OutboxItem> _items = [];
  final Map<String, String> _values = {};
  final Map<String, SentRecord> _sent = {};

  @override
  Future<void> recordSent(SentRecord record) async => _sent[record.id] = record;

  @override
  Future<List<SentRecord>> sentSince(DateTime since) async =>
      _sent.values.where((r) => !r.sentAt.isBefore(since)).toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));

  @override
  Future<bool> backupTo(String path) async => false;

  @override
  Future<void> add(OutboxItem item) async {
    if (_items.any((existing) => existing.id == item.id)) return;
    _items.add(item);
  }

  @override
  Future<List<OutboxItem>> pending() async => _items.where((item) => !item.failed).toList();

  @override
  Future<List<OutboxItem>> failed() async => _items.where((item) => item.failed).toList();

  @override
  Future<void> remove(String id) async => _items.removeWhere((item) => item.id == id);

  @override
  Future<void> updatePayload(String id, Map<String, dynamic> payload) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final old = _items[index];
    _items[index] = OutboxItem(
      id: old.id,
      kind: old.kind,
      payload: payload,
      createdAt: old.createdAt,
      attempts: old.attempts,
      lastError: old.lastError,
      failed: old.failed,
    );
  }

  @override
  Future<void> noteAttempt(String id, String error) async => _replace(id, failed: false, error: error);

  @override
  Future<void> markFailed(String id, String error) async => _replace(id, failed: true, error: error);

  @override
  Future<void> requeueFailed() async {
    for (var i = 0; i < _items.length; i++) {
      final old = _items[i];
      if (!old.failed) continue;
      _items[i] = OutboxItem(
        id: old.id,
        kind: old.kind,
        payload: old.payload,
        createdAt: old.createdAt,
        attempts: old.attempts,
      );
    }
  }

  void _replace(String id, {required bool failed, required String error}) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final old = _items[index];
    _items[index] = OutboxItem(
      id: old.id,
      kind: old.kind,
      payload: old.payload,
      createdAt: old.createdAt,
      attempts: old.attempts + 1,
      lastError: error,
      failed: failed,
    );
  }

  @override
  Future<String?> readValue(String key) async => _values[key];

  @override
  Future<void> writeValue(String key, String? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

String encodePayload(Map<String, dynamic> payload) => jsonEncode(payload);

Map<String, dynamic> decodePayload(String text) => Map<String, dynamic>.from(jsonDecode(text) as Map);
