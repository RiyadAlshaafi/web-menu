import '../offline/outbox_store.dart';
import 'release_info.dart';
import 'update_platform.dart';

/// The web app is updated by the site itself, never by this updater.
UpdatePlatform createUpdatePlatform() => _Unsupported();

class _Unsupported implements UpdatePlatform {
  @override
  bool get supported => false;

  @override
  Future<Object?> fetchLatestJson() async => null;

  @override
  Future<String> download(ReleaseInfo info) => throw UnsupportedError('no updates on this platform');

  @override
  Future<String> backup(OutboxStore store, String outboxFileName) =>
      throw UnsupportedError('no updates on this platform');

  @override
  Future<Map<String, dynamic>?> readMarker() async => null;

  @override
  Future<void> writeMarker(Map<String, dynamic>? marker) async {}

  @override
  Future<void> install(String installerPath) => throw UnsupportedError('no updates on this platform');
}
