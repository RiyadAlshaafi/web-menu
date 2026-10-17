import 'dart:io';

import '../core/report_error.dart';

/// Reads `features.json` from the install folder, written by windows/installer/cafe_pos.iss.
Future<String?> readFeatureFile() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  final file = File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}features.json');
  try {
    if (!await file.exists()) return null;
    return await file.readAsString();
  } on FileSystemException catch (error, stackTrace) {
    reportError('read features.json', error, stackTrace);
    return null;
  }
}
