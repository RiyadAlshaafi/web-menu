import 'app_version.dart';

/// Where the newest Windows release is described (written by .github/workflows/windows-release.yml).
const latestReleaseUrl = 'https://github.com/RiyadAlshaafi/web-menu/releases/latest/download/latest.json';

/// The newest release: its version, the installer to download and the installer's SHA-256.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.url, required this.sha256, this.notes = ''});

  /// Reads `latest.json`; null when anything is missing or doesn't look right, so a broken file
  /// can never start an install.
  static ReleaseInfo? tryParse(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final url = json['url'];
    final hash = json['sha256'];
    if (version is! String || AppVersion.tryParse(version) == null) return null;
    if (url is! String || !url.startsWith('https://')) return null;
    if (hash is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hash)) return null;
    final notes = json['notes'];
    return ReleaseInfo(version: version, url: url, sha256: hash.toLowerCase(), notes: notes is String ? notes : '');
  }

  final String version;
  final String url;
  final String sha256;
  final String notes;
}
