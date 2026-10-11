import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart';

Future<String?> saveBytesFile({
  required String dialogTitle,
  required String fileName,
  required Uint8List bytes,
  FileType type = FileType.any,
  List<String>? allowedExtensions,
}) async {
  final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  document.body?.append(anchor);
  anchor.click();
  // Revoking in the same turn cancels the browser download before it starts.
  Future<void>.delayed(const Duration(seconds: 1), () {
    anchor.remove();
    URL.revokeObjectURL(url);
  });
  return fileName;
}
