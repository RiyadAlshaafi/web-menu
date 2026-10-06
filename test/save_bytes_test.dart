import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/save_bytes_io.dart';

void main() {
  test('desktop save writes the chosen file', () async {
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}menu-save-bytes.csv');
    if (await file.exists()) await file.delete();
    await writeBytesAt(file.path, Uint8List.fromList('paid_at,receipt\n'.codeUnits));
    expect(await file.readAsString(), 'paid_at,receipt\n');
    await file.delete();
  });
}
