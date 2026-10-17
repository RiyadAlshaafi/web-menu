import 'dart:io';

import '../core/report_error.dart';
import 'admin_reset.dart' show adminResetFileName;

File get _ticket =>
    File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$adminResetFileName');

/// Reads the setup's reset ticket from the install folder (windows/installer/cafe_pos.iss).
Future<String?> readAdminResetFile() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  try {
    if (!await _ticket.exists()) return null;
    return await _ticket.readAsString();
  } on FileSystemException catch (error, stackTrace) {
    reportError('read admin_reset.json', error, stackTrace);
    return null;
  }
}

Future<void> deleteAdminResetFile() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    if (await _ticket.exists()) await _ticket.delete();
  } on FileSystemException catch (error, stackTrace) {
    reportError('delete admin_reset.json', error, stackTrace);
  }
}
