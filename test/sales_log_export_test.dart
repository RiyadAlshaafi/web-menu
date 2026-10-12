import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/sales_log_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

/// Answers the save dialog with a fixed path (or as if cancelled) and records what was asked.
class _FakePicker extends FilePicker {
  _FakePicker(this.path);

  final String? path;
  final asked = <String?>[];

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    asked.add(fileName);
    return path;
  }
}

Payment _sale(String id, double total, {String table = '', bool takeout = false, String cashier = 'Sara'}) => Payment(
      id: id,
      orderId: 'order-$id',
      tableId: takeout ? '' : 't$table',
      tableNumber: table,
      isTakeout: takeout,
      totalDue: total,
      cashReceived: total,
      changeDue: 0,
      cashierId: 'c1',
      cashierName: cashier,
      shiftId: 's1',
      paidAt: DateTime.now(),
      paymentTypeNameEn: 'Cash',
    );

/// Taps Export CSV and lets the save finish: the file is written with real I/O, outside the
/// test's fake clock.
Future<void> _export(WidgetTester tester) async {
  await tapVisible(tester, find.text(l10n.salesExportCsv));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sales_export');
  });
  tearDown(() {
    // Windows may still hold the just-written file for a moment; the temp folder is cleared later.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  CafeStore store() => CafeStore(AppDatabase.instance)
    ..payments = [
      _sale('a', 25, table: '4'),
      _sale('b', 9.5, takeout: true),
      _sale('c', 40, table: '7', cashier: '=HYPERLINK("x")'),
    ];

  testWidgets('CSV export saves sales-log.csv with one row per sale', (tester) async {
    final file = '${dir.path}${Platform.pathSeparator}out.csv';
    final picker = _FakePicker(file);
    FilePicker.platform = picker;
    await pumpAdminScreen(tester, const SalesLogScreen(), store());

    await _export(tester);

    expect(picker.asked, ['sales-log.csv']);
    final lines = File(file).readAsLinesSync();
    expect(lines.first, startsWith('${l10n.salesReceiptNo},${l10n.salesOrderNo},date,table,cashier'));
    expect(lines, hasLength(4), reason: 'a header and three sales');
    expect(lines.where((l) => l.contains('"Takeout"')), hasLength(1));
    expect(lines.where((l) => l.contains('"4"') && l.contains('"25.0"')), hasLength(1));
  });

  testWidgets('a cashier name that looks like a spreadsheet formula is exported as text', (tester) async {
    final file = '${dir.path}${Platform.pathSeparator}out.csv';
    FilePicker.platform = _FakePicker(file);
    await pumpAdminScreen(tester, const SalesLogScreen(), store());

    await _export(tester);

    final csv = File(file).readAsStringSync();
    expect(csv, contains('"\'=HYPERLINK(""x"")"'));
    expect(csv, isNot(contains(',"=HYPERLINK')));
  });

  testWidgets('the export holds only the sales the search shows', (tester) async {
    final file = '${dir.path}${Platform.pathSeparator}out.csv';
    FilePicker.platform = _FakePicker(file);
    await pumpAdminScreen(tester, const SalesLogScreen(), store());

    await tester.enterText(find.widgetWithText(TextField, l10n.salesSearchHint), 'Sara');
    await tester.pump();
    await _export(tester);

    expect(File(file).readAsLinesSync(), hasLength(3), reason: 'the header and Sara\'s two sales');
  });

  testWidgets('cancelling the save dialog writes nothing and shows no error', (tester) async {
    FilePicker.platform = _FakePicker(null);
    await pumpAdminScreen(tester, const SalesLogScreen(), store());

    await _export(tester);

    expect(dir.listSync(), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
