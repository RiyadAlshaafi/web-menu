import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'save_bytes_io.dart' if (dart.library.html) 'save_bytes_web.dart' as writer;

/// Saves [bytes] with the same dialog the other exports use.
/// On the web this starts a browser download. On desktop the native save
/// dialog chooses the path, then the bytes are written there.
/// Returns null when the desktop dialog is cancelled.
Future<String?> saveBytesFile({
  required String dialogTitle,
  required String fileName,
  required Uint8List bytes,
  FileType type = FileType.any,
  List<String>? allowedExtensions,
}) {
  return writer.saveBytesFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: bytes,
    type: type,
    allowedExtensions: allowedExtensions,
  );
}
