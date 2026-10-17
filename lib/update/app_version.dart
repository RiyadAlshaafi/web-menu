/// A release number like `1.4.2`. A build suffix (`+7`) is ignored; a label (`-beta.1`) makes it a
/// pre-release, which comes before the same number without a label.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, {this.preRelease = false});

  /// Reads `1.4.2` (also `v1.4.2` and `1.4.2+7`); null when it isn't a version.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(-[^+]*)?(?:\+.*)?$').firstMatch(text.trim());
    if (match == null) return null;
    return AppVersion(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!), preRelease: match[4] != null);
  }

  final int major;
  final int minor;
  final int patch;
  final bool preRelease;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (preRelease == other.preRelease) return 0;
    return preRelease ? -1 : 1;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Whether [candidate] is a newer release than [current]. Unreadable versions are never newer.
bool isNewer(String? candidate, String? current) {
  final a = AppVersion.tryParse(candidate);
  final b = AppVersion.tryParse(current);
  return a != null && b != null && a > b;
}
