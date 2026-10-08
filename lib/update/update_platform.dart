import '../offline/outbox_store.dart';
import 'release_info.dart';
import 'update_platform_stub.dart' if (dart.library.io) 'update_platform_io.dart' as impl;

/// What the updater needs from the device. Only the Windows app updates itself; elsewhere
/// [supported] is false and nothing else is called.
abstract class UpdatePlatform {
  static UpdatePlatform create() => impl.createUpdatePlatform();

  bool get supported;

  /// Reads `latest.json` from the release page.
  Future<Object?> fetchLatestJson();

  /// Downloads the installer and checks its SHA-256. Returns the file path; throws on any mismatch.
  Future<String> download(ReleaseInfo info);

  /// Copies the till's own data (offline sales, saved menu, slot link) to a new dated backup
  /// folder and keeps the newest three. Returns the folder path.
  Future<String> backup(OutboxStore store, String outboxFileName);

  /// The note left before an update, read by the next start to check the update went well.
  Future<Map<String, dynamic>?> readMarker();
  Future<void> writeMarker(Map<String, dynamic>? marker);

  /// Starts the installer silently and closes the app; the installer reopens it.
  Future<void> install(String installerPath);
}
