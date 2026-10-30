import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/ledger.dart';
import 'package:menu_web_v1/core/sales_report.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/widgets/tawla_ui.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_wages_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

/// Answers the save dialog with a fixed path.
class _FakePicker extends FilePicker {
  _FakePicker(this.path);

  final String path;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async =>
      path;
}

ShiftExpense _expense(
  String id,
  double amount,
  String description, {
  String? paidTo,
  String paidToName = '',
  String? staff,
  String staffName = '',
  bool voided = false,
  String? editedFrom,
}) =>
    ShiftExpense(
      id: id,
      shiftId: 's1',
      cashierId: 'c2',
      cashierName: 'Omar',
      paidToCafe: paidTo == null,
      paidToCashierId: paidTo,
      paidToCashierName: paidToName,
      staffId: staff,
      staffName: staffName,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
      voided: voided,
      editedFrom: editedFrom,
    );

/// Answers the cards' report as the server would, from every sale and expense in [all] (which
/// can hold more than the loaded lists), or with [error].
class _ServerStore extends CafeStore {
  _ServerStore() : super(AppDatabase.instance);

  List<ShiftExpense>? all;
  String? error;
  final asked = <(DateTime, DateTime)>[];

  @override
  Future<({SalesReport? report, String? error})> salesReport(DateTime from, DateTime to) async {
    asked.add((from, to));
    if (error != null) return (report: null, error: error);
    final report = SalesReport.fromRows(
      from: from,
      to: to,
      payments: payments,
      expenses: all ?? expenses,
      paymentTypes: paymentTypes,
      expenseCategories: expenseCategories,
      staff: cashiers,
    );
    return (report: report, error: null);
  }
}

/// Sara (cashier), Omar (cashier, records everything), Lina (chef) and Hani, who was removed
/// but still has an expense under his saved name.
_ServerStore _store() => _ServerStore()
  ..cafe = {'name': 'Test Cafe'}
  ..cashiers = [
    Cashier(id: 'c1', name: 'Sara Ali', initials: 'SA'),
    Cashier(id: 'c2', name: 'Omar', initials: 'O'),
    Cashier(id: 'k1', name: 'Lina', initials: 'L', role: StaffJob.chef, active: false),
  ]
  ..payments = [
    Payment(
      id: 'p1',
      orderId: 'o1',
      tableId: 't1',
      tableNumber: '1',
      totalDue: 200,
      cashReceived: 200,
      changeDue: 0,
      cashierId: 'c2',
      shiftId: 's1',
      paidAt: DateTime.now(),
    ),
  ]
  ..expenses = [
    _expense('e1', 50, 'Sara advance', paidTo: 'c1', paidToName: 'Sara Ali'),
    _expense('e2', 30, 'Chef knives', staff: 'k1', staffName: 'Lina'),
    _expense('e3', 20, 'Milk'),
    _expense('e4', 15, 'Hani last wage', staff: 'x9', staffName: 'Old Hani'),
    _expense('e5', 99, 'Voided thing', staff: 'c1', staffName: 'Sara Ali', voided: true),
    // Edited: the old copy is voided and the corrected one counts once.
    _expense('e6a', 40, 'Sara bonus', staff: 'c1', staffName: 'Sara Ali', voided: true),
    _expense('e6b', 45, 'Sara bonus fixed', staff: 'c1', staffName: 'Sara Ali', editedFrom: 'e6a'),
  ];

/// Opens the wages screen with its filter row showing.
Future<void> _pumpWages(WidgetTester tester, CafeStore store) async {
  await pumpAdminScreen(tester, const AdminWagesScreen(), store);
  await tapVisible(tester, find.text(l10n.filtersButton));
}

Future<void> _pick(WidgetTester tester, String current, String option) async {
  await tapVisible(tester, find.text(current).first);
  await tapVisible(tester, find.text(option).last);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the employee of an expense', () {
    test('is whom a withdrawal paid, else the tagged employee, else no one', () {
      expect(expenseEmployeeId(_expense('a', 1, '', paidTo: 'c1', staff: 'k1')), 'c1');
      expect(expenseEmployeeId(_expense('b', 1, '', staff: 'k1')), 'k1');
      expect(expenseEmployeeId(_expense('c', 1, '')), isNull);
    });

    test('the options are every staff member plus removed ones by their saved name, by name', () {
      expect(expenseEmployees(_store()).map((person) => person.name), ['Lina', 'Old Hani', 'Omar', 'Sara Ali']);
    });

    test('each filter keeps its own expenses; voided ones never count and an edit counts once', () {
      final store = _store();
      double total(EmployeeFilter filter) => expenseLedgerRows(store, employee: filter).fold(0, (sum, e) => sum + e.amount);

      expect(total(const AllEmployees()), 160);
      expect(total(const OneEmployee('c1')), 95);
      expect(total(const OneEmployee('k1')), 30);
      expect(total(const OneEmployee('x9')), 15);
      expect(total(const NoEmployee()), 20);
      expect(total(const OneEmployee('c2')), 0, reason: 'Omar recorded them but was paid nothing');
    });
  });

  group('the wages screen', () {
    testWidgets('filters stay hidden until the Filters button, which counts the ones in use', (tester) async {
      await pumpAdminScreen(tester, const AdminWagesScreen(), _store());
      expect(find.text(l10n.expenseAllEmployees), findsNothing);

      await tapVisible(tester, find.text(l10n.filtersButton));
      await _pick(tester, l10n.expenseAllEmployees, 'Sara Ali');
      await tapVisible(tester, find.text(l10n.filtersButtonActive(1)));

      expect(find.byType(SelectBox<EmployeeFilter>), findsNothing, reason: 'the row is hidden again');
      expect(find.text('Sara advance'), findsOneWidget, reason: 'the hidden filter still applies');
    });

    testWidgets('all employees: every expense, and no sales, expenses or net cards', (tester) async {
      final store = _store();
      await _pumpWages(tester, store);
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseAllEmployees), findsOneWidget);
      expect(find.textContaining(l10n.summaryNet), findsNothing);
      expect(find.textContaining(l10n.summarySales), findsNothing);
      for (final row in ['Sara advance', 'Chef knives', 'Milk', 'Hani last wage', 'Sara bonus fixed']) {
        expect(find.text(row), findsOneWidget);
      }
      expect(find.text('Voided thing'), findsNothing);
      expect(find.text('Sara bonus'), findsNothing, reason: 'the edited copy replaces the old one');
    });

    testWidgets('the dropdown offers all, none and every employee, also removed ones', (tester) async {
      await _pumpWages(tester, _store());

      await tapVisible(tester, find.text(l10n.expenseAllEmployees));
      for (final option in [l10n.expenseNoEmployee, 'Sara Ali', 'Omar', 'Lina', 'Old Hani']) {
        expect(find.text(option), findsWidgets);
      }
    });

    testWidgets('one employee: only their expenses', (tester) async {
      final store = _store();
      await _pumpWages(tester, store);

      await _pick(tester, l10n.expenseAllEmployees, 'Sara Ali');

      expect(find.text('Sara advance'), findsOneWidget);
      expect(find.text('Sara bonus fixed'), findsOneWidget);
      expect(find.text('Chef knives'), findsNothing);
      expect(find.text('Milk'), findsNothing);
    });

    testWidgets('a removed employee is found by the saved name', (tester) async {
      final store = _store();
      await _pumpWages(tester, store);

      await _pick(tester, l10n.expenseAllEmployees, 'Old Hani');

      expect(find.text('Hani last wage'), findsOneWidget);
      expect(find.text('Sara advance'), findsNothing);
      expect(find.text(store.currency.format(15)), findsWidgets);
    });

    testWidgets('no employee: only expenses paid to and tagged with no one', (tester) async {
      final store = _store();
      await _pumpWages(tester, store);

      await _pick(tester, l10n.expenseAllEmployees, l10n.expenseNoEmployee);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Sara advance'), findsNothing);
      expect(find.text('Chef knives'), findsNothing);
      expect(find.text(store.currency.format(20)), findsWidgets);
      expect(find.textContaining(l10n.summaryNet), findsNothing);
    });

    testWidgets('the CSV holds only the filtered expenses', (tester) async {
      final dir = Directory.systemTemp.createTempSync('wages_export');
      addTearDown(() {
        // Windows may still hold the just-written file for a moment; the temp folder is cleared later.
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException catch (_) {}
      });
      final file = '${dir.path}${Platform.pathSeparator}out.csv';
      FilePicker.platform = _FakePicker(file);
      await _pumpWages(tester, _store());

      await _pick(tester, l10n.expenseAllEmployees, 'Sara Ali');
      await tapVisible(tester, find.text(l10n.salesExportCsv));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      final lines = File(file).readAsLinesSync();
      expect(lines, hasLength(3), reason: 'a header and Sara\'s two expenses');
      expect(lines.skip(1).every((line) => line.contains('Sara')), isTrue);
    });
  });
}
