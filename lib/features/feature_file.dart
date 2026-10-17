import 'feature_file_stub.dart' if (dart.library.io) 'feature_file_io.dart' as impl;

/// The installer's `features.json` text, or null when there is none (web, tests, older installs).
Future<String?> readFeatureFile() => impl.readFeatureFile();
