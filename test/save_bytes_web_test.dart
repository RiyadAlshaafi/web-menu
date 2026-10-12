@TestOn('chrome')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/platform/save_bytes_web.dart';

void main() {
  test('web save starts a browser download', () async {
    expect(kIsWeb, isTrue);
    final saved = await saveBytesFile(
      dialogTitle: 'Save receipts',
      fileName: 'all-receipts.csv',
      bytes: Uint8List.fromList('paid_at,receipt\n'.codeUnits),
    );
    expect(saved, 'all-receipts.csv');
  });
}
