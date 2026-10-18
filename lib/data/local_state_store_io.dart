import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'local_state_store.dart';

/// File name of the offline database, in the app's support folder (never the install folder).
const localDatabaseFileName = 'tawla_local.db';

Future<LocalStateStore> openLocalStateStore() async {
  final folder = await getApplicationSupportDirectory();
  await folder.create(recursive: true);
  return SqliteLocalStateStore.open(p.join(folder.path, localDatabaseFileName));
}

LocalStateStore openMemoryLocalStateStore() => SqliteLocalStateStore.open(':memory:');

class SqliteLocalStateStore implements LocalStateStore {
  SqliteLocalStateStore._(this._db);

  factory SqliteLocalStateStore.open(String path) {
    final db = path == ':memory:' ? sqlite3.openInMemory() : sqlite3.open(path);
    db.execute('pragma journal_mode = wal');
    db.execute('pragma synchronous = full');
    db.execute('create table if not exists docs (key text primary key, value text not null)');
    db.execute('''
      create table if not exists records (
        kind text not null,
        id text not null,
        body text not null,
        seq integer not null,
        primary key (kind, id)
      )''');
    return SqliteLocalStateStore._(db);
  }

  final Database _db;

  @override
  Object? readDoc(String key) {
    final rows = _db.select('select value from docs where key = ?', [key]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value'] as String);
  }

  @override
  void writeDoc(String key, Object? value) {
    _db.execute('insert or replace into docs (key, value) values (?, ?)', [key, jsonEncode(value)]);
  }

  @override
  List<Map<String, dynamic>> readRecords(String kind) => [
    for (final row in _db.select('select body from records where kind = ? order by seq', [kind]))
      Map<String, dynamic>.from(jsonDecode(row['body'] as String) as Map),
  ];

  @override
  void putRecords(String kind, Iterable<Map<String, dynamic>> rows) {
    final statement = _db.prepare('''
      insert into records (kind, id, body, seq)
      values (?, ?, ?, (select coalesce(max(seq), 0) + 1 from records))
      on conflict (kind, id) do update set body = excluded.body''');
    try {
      for (final row in rows) {
        statement.execute([kind, row['id'] as String, jsonEncode(row)]);
      }
    } finally {
      statement.close();
    }
  }

  @override
  void deleteRecord(String kind, String id) {
    _db.execute('delete from records where kind = ? and id = ?', [kind, id]);
  }

  /// Nested calls join the outer transaction.
  int _depth = 0;

  @override
  void transaction(void Function() action) {
    if (_depth > 0) {
      action();
      return;
    }
    _db.execute('begin immediate');
    _depth++;
    try {
      action();
      _db.execute('commit');
    } catch (_) {
      _db.execute('rollback');
      rethrow;
    } finally {
      _depth--;
    }
  }

  @override
  void close() => _db.close();
}
