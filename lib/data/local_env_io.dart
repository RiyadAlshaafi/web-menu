import 'dart:io';

Future<Map<String, String>> loadLocalEnv() async {
  final merged = <String, String>{};
  for (final file in _envFiles()) {
    if (!file.existsSync()) continue;
    merged.addAll(_parse(file.readAsStringSync()));
  }
  for (final key in _keys) {
    final value = Platform.environment[key];
    if (value != null && value.trim().isNotEmpty) merged[key] = value.trim();
  }
  return merged;
}

const _keys = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_PUBLISHABLE_KEY',
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
  'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
];

Iterable<File> _envFiles() sync* {
  final seen = <String>{};
  File? add(String path) {
    final file = File(path);
    final resolved = file.absolute.path;
    if (!seen.add(resolved)) return null;
    return file;
  }

  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final file = add('${dir.path}${Platform.pathSeparator}.env');
    if (file != null) yield file;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  final besideExe = add('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}.env');
  if (besideExe != null) yield besideExe;
}

Map<String, String> _parse(String raw) {
  final values = <String, String>{};
  for (var line in raw.split(RegExp(r'\r?\n'))) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    var value = line.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    values[line.substring(0, eq).trim()] = value;
  }
  return values;
}
