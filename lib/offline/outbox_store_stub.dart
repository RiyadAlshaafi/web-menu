import 'outbox_store.dart';

/// The web has no local file database; changes are kept in memory only.
Future<OutboxStore> openOutboxStore(String serverUrl) async => MemoryOutboxStore();
