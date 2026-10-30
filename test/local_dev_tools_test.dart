import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/dev_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:provider/provider.dart';

final db = AppDatabase.instance;

Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? extra]) async =>
    (await db.devCall(name, 'not-used-offline', extra))!;

/// A cashier on an open shift, who sold one takeout and paid one expense.
Future<void> _sale() async {
  final id = (await db.createCashier(name: 'Sara', pin: '1234', initials: 'S'))!;
  expect((await db.loginCashier(id, '1234'))['ok'], isTrue);
  await db.writeShifts([CashShift(id: 'shift', cashierId: id, openedAt: DateTime.now().toUtc(), openingCash: 0)]);
  final dish = MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7.5, categoryId: 'drinks');
  await db.writeMenuItems([dish], changed: [dish]);
  expect(await db.quickTakeoutReceipt([OrderLine(menuItemId: dish.id, name: 'Latte', qty: 2, unitPrice: 7.5)], null), isNull);
  expect(
    await db.addShiftExpense(
      shiftId: 'shift',
      cashierId: id,
      categoryId: db.expenseCategories.first.id,
      paidToCafe: true,
      paidToCashierId: null,
      amount: 3,
      description: 'Milk',
    ),
    isNull,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => db.initLocal(openMemoryLocalStateStore()));
  tearDown(() => db.closeLocal());

  group('the dev password check without a Supabase connection', () {
    Future<bool?> ask(MockClient server) => http.runWithClient(
      () => askDevAccess('https://x.test', 'key', 'secret'),
      () => server,
    );

    test('asks the server and sends the password in the body', () async {
      late http.Request sent;
      final answer = await ask(MockClient((request) async {
        sent = request;
        return http.Response('true', 200);
      }));
      expect(answer, isTrue);
      expect(sent.url.toString(), 'https://x.test/rest/v1/rpc/check_dev_access');
      expect(sent.headers['apikey'], 'key');
      expect(jsonDecode(sent.body), {'p_password': 'secret'});
    });

    test('a wrong password is false', () async {
      expect(await ask(MockClient((_) async => http.Response('false', 200))), isFalse);
    });

    test('no internet or a server error is null, not a wrong password', () async {
      expect(await ask(MockClient((_) async => throw http.ClientException('no internet'))), isNull);
      expect(await ask(MockClient((_) async => http.Response('oops', 500))), isNull);
    });
  });

  group('the dev tools on the local database', () {
    test('reset admin removes only the admin, and a new one can be created', () async {
      await _sale();
      expect(db.createLocalAdmin(email: 'Admin', password: 'Secret#123'), isNull);

      expect((await _call('dev_reset_admin'))['ok'], isTrue);

      expect(db.anyAdmin, isFalse);
      expect(db.admin, isNull);
      expect(db.payments, hasLength(1));
      expect(db.menuItems, hasLength(1));
      expect(db.createLocalAdmin(email: 'Admin', password: 'Other#1234'), isNull);
    });

    test('export gives every receipt and expense in the server shape', () async {
      await _sale();

      final result = await _call('dev_export_logs');

      final payment = (result['payments'] as List).single as Map;
      expect(payment['service_type'], 'takeout');
      expect(payment['total_due'], 15.0);
      expect(payment['lines'], [
        {'name': 'Latte', 'qty': 2, 'unit_price': 7.5},
      ]);
      final expense = (result['expenses'] as List).single as Map;
      expect(expense['description'], 'Milk');
      expect(expense['paid_to_cafe'], isTrue);
    });

    test('wiping the logs empties sales and restarts numbering, shifts stay', () async {
      await _sale();
      final first = db.payments.single.monthlyDisplayNumber;

      expect((await _call('dev_wipe_logs'))['ok'], isTrue);

      expect(db.payments, isEmpty);
      expect(db.orders, isEmpty);
      expect(db.expenses, isEmpty);
      expect(db.shifts, hasLength(1));
      expect(
        await db.quickTakeoutReceipt([OrderLine(menuItemId: 'latte', name: 'Latte', qty: 1, unitPrice: 7.5)], null),
        isNull,
      );
      expect(db.payments.single.monthlyDisplayNumber, first);
    });

    test('wiping the menu empties dishes and categories, receipts keep their text', () async {
      await _sale();

      expect((await _call('dev_wipe_menu'))['ok'], isTrue);

      expect(db.menuItems, isEmpty);
      expect(db.categories, isEmpty);
      expect(db.payments, hasLength(1));
      expect(db.orders.single.lines.single.name, 'Latte');
    });

    test('import adds the rows as new ones and survives a reload', () async {
      await _sale();

      final result = await _call('dev_import_logs', {
        'p_receipts': [
          {
            'paid_at': '2026-10-01T10:00:00.000Z',
            'receipt': '2610-001',
            'monthly': '2610-001',
            'table': 'Takeout',
            'service': 'takeout',
            'total_due': '9.50',
            'lines': [
              {'name': 'Tea', 'qty': 1, 'unit_price': '9.50'},
            ],
          },
        ],
        'p_expenses': [
          {
            'created_at': '2026-10-01T11:00:00.000Z',
            'amount': '4',
            'description': 'Ice',
            'kind': 'cash_out',
            'paid_to_cafe': false,
          },
        ],
      });

      expect(result, {'ok': true, 'receipts': 1, 'expenses': 1});
      expect(db.payments, hasLength(2));
      expect(db.expenses, hasLength(2));
      final imported = db.payments.firstWhere((p) => p.totalDue == 9.5);
      expect(imported.isTakeout, isTrue);
      expect(imported.shiftId, 'shift');
      expect(db.orders.firstWhere((o) => o.id == imported.orderId).lines.single.name, 'Tea');
    });

    test('import refuses a dine-in table that does not exist, and writes nothing', () async {
      await _sale();

      final result = await _call('dev_import_logs', {
        'p_receipts': [
          {
            'paid_at': '2026-10-01T10:00:00.000Z',
            'table': 'T9',
            'service': 'dine_in',
            'total_due': '1',
            'lines': const <Object>[],
          },
        ],
        'p_expenses': const <Object>[],
      });

      expect(result, {'ok': false, 'error': 'No table named T9.'});
      expect(db.payments, hasLength(1));
    });

    test('import needs a cashier', () async {
      final result = await _call('dev_import_logs', {
        'p_receipts': const <Object>[],
        'p_expenses': [
          {'created_at': '2026-10-01T11:00:00.000Z', 'amount': '4', 'description': 'Ice', 'paid_to_cafe': true},
        ],
      });

      expect(result['error'], 'Add a cashier before importing logs.');
    });

    test('a slot-only tool is refused', () async {
      expect((await _call('dev_list_slots'))['ok'], isFalse);
    });
  });

  testWidgets('offline, the dev screen hides slots and tills and its tools are enabled', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<CafeStore>(
        create: (_) => CafeStore(db),
        child: const MaterialApp(home: DevScreen(password: 'x')),
      ),
    );
    await tester.pump();

    expect(find.text('Cafe slots'), findsNothing);
    expect(find.text('Tills and app versions'), findsNothing);
    for (final label in ['Reset admin', 'Export', 'Import', 'Delete all logs', 'Delete all dishes']) {
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
      expect(button.onPressed, isNotNull, reason: label);
    }
  });
}
