/// A release number like `1.4.2`. A build suffix (`+7`) or label (`-beta`) is ignored.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  /// Reads `1.4.2` (also `v1.4.2` and `1.4.2+7`); null when it isn't a version.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[+-].*)?$').firstMatch(text.trim());
    if (match == null) return null;
    return AppVersion(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Whether [candidate] is a newer release than [current]. Unreadable versions are never newer.
bool isNewer(String? candidate, String? current) {
  final a = AppVersion.tryParse(candidate);
  final b = AppVersion.tryParse(current);
  return a != null && b != null && a > b;
}
