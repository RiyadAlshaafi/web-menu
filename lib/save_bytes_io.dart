import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveBytesFile({
  required String dialogTitle,
  required String fileName,
  required Uint8List bytes,
  FileType type = FileType.any,
  List<String>? allowedExtensions,
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: type,
    allowedExtensions: allowedExtensions,
    lockParentWindow: true,
  );
  if (path == null) return null;
  await writeBytesAt(path, bytes);
  return path;
}

Future<void> writeBytesAt(String path, Uint8List bytes) {
  return File(path).writeAsBytes(bytes, flush: true);
}
