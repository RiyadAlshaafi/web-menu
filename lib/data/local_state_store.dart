import 'local_state_store_stub.dart' if (dart.library.io) 'local_state_store_io.dart' as impl;

/// Where an offline (local database) install keeps everything: one SQLite file on this PC.
///
/// Small collections (menu, cashiers, settings) are saved whole as documents; sales, orders,
/// shifts and expenses are saved one row each, so a busy year never rewrites the whole file.
abstract class LocalStateStore {
  /// A saved document (any JSON value), or null when it was never written.
  Object? readDoc(String key);

  void writeDoc(String key, Object? value);

  /// Every saved row of [kind], oldest first.
  List<Map<String, dynamic>> readRecords(String kind);

  /// Inserts or replaces rows of [kind] by id.
  void putRecords(String kind, Iterable<Map<String, dynamic>> rows);

  /// Runs [action] as one transaction, so a crash never leaves half a sale.
  void transaction(void Function() action);

  void close();
}

/// Opens this PC's local database (desktop only).
Future<LocalStateStore> openLocalStateStore() => impl.openLocalStateStore();

/// A throwaway store for tests.
LocalStateStore openMemoryLocalStateStore() => impl.openMemoryLocalStateStore();
