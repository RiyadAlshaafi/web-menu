import 'local_state_store.dart';

Future<LocalStateStore> openLocalStateStore() =>
    Future.error(UnsupportedError('The local database runs on the Windows app only.'));

LocalStateStore openMemoryLocalStateStore() =>
    throw UnsupportedError('The local database runs on the Windows app only.');
