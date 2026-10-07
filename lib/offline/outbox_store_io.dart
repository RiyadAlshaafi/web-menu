import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'outbox_store.dart';

/// Opens the device's outbox file in the app's support folder.
Future<OutboxStore> openOutboxStore(String serverUrl) async {
  final folder = await getApplicationSupportDirectory();
  await folder.create(recursive: true);
  return SqliteOutboxStore.open(p.join(folder.path, 'offline_outbox_${OutboxStore.scopeOf(serverUrl)}.sqlite'));
}

/// Outbox kept in a SQLite file, so saved sales survive a crash or restart.
class SqliteOutboxStore implements OutboxStore {
  SqliteOutboxStore._(this._db);

  /// Opens (or creates) the outbox at [path]; pass ':memory:' for a throwaway one.
  factory SqliteOutboxStore.open(String path) {
    final db = path == ':memory:' ? sqlite3.openInMemory() : sqlite3.open(path);
    db.execute('pragma journal_mode = wal');
    db.execute('pragma synchronous = full');
    db.execute('''
      create table if not exists outbox (
        seq integer primary key autoincrement,
        id text not null unique,
        kind text not null,
        payload text not null,
        created_at text not null,
        attempts integer not null default 0,
        last_error text,
        failed integer not null default 0
      )''');
    db.execute('create table if not exists kv (key text primary key, value text not null)');
    return SqliteOutboxStore._(db);
  }

  final Database _db;

  @override
  Future<void> add(OutboxItem item) async {
    _db.execute(
      'insert or ignore into outbox (id, kind, payload, created_at) values (?, ?, ?, ?)',
      [item.id, item.kind, encodePayload(item.payload), item.createdAt.toUtc().toIso8601String()],
    );
  }

  List<OutboxItem> _select(bool failed) => [
    for (final row in _db.select('select * from outbox where failed = ? order by seq', [failed ? 1 : 0]))
      OutboxItem(
        id: row['id'] as String,
        kind: row['kind'] as String,
        payload: decodePayload(row['payload'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
        failed: (row['failed'] as int) == 1,
      ),
  ];

  @override
  Future<List<OutboxItem>> pending() async => _select(false);

  @override
  Future<List<OutboxItem>> failed() async => _select(true);

  @override
  Future<void> remove(String id) async => _db.execute('delete from outbox where id = ?', [id]);

  @override
  Future<void> updatePayload(String id, Map<String, dynamic> payload) async =>
      _db.execute('update outbox set payload = ? where id = ?', [encodePayload(payload), id]);

  @override
  Future<void> noteAttempt(String id, String error) async =>
      _db.execute('update outbox set attempts = attempts + 1, last_error = ? where id = ?', [error, id]);

  @override
  Future<void> markFailed(String id, String error) async =>
      _db.execute('update outbox set attempts = attempts + 1, last_error = ?, failed = 1 where id = ?', [error, id]);

  @override
  Future<String?> readValue(String key) async {
    final rows = _db.select('select value from kv where key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> writeValue(String key, String? value) async {
    if (value == null) {
      _db.execute('delete from kv where key = ?', [key]);
    } else {
      _db.execute('insert into kv (key, value) values (?, ?) on conflict(key) do update set value = excluded.value', [key, value]);
    }
  }
}
