import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/error_codes.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/navigation/app_sections.dart';
import 'package:menu_web_v1/screens/cashier_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final db = AppDatabase.instance;

/// The cashier screens keep timers running, so frames are pumped for a fixed time instead of
/// waiting for them to settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  ignoreOverflow(tester);
}

Cashier staff(String role, {bool usesDevice = false}) =>
    Cashier(id: role, name: role, initials: 'X', role: role, usesDevice: usesDevice);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('who signs in', () {
    test('a cashier signs in at the till, a server only with a tablet or phone', () {
      expect(staff(StaffJob.cashier).canSignIn, isTrue);
      expect(staff(StaffJob.server).canSignIn, isFalse);
      expect(staff(StaffJob.server, usesDevice: true).canSignIn, isTrue);
    });

    test('chefs and cleaners never sign in, even marked as using a device', () {
      expect(staff(StaffJob.chef, usesDevice: true).canSignIn, isFalse);
      expect(staff(StaffJob.cleaner, usesDevice: true).canSignIn, isFalse);
    });

    test('only a server with a device is a waiter', () {
      expect(staff(StaffJob.server, usesDevice: true).isWaiter, isTrue);
      expect(staff(StaffJob.cashier, usesDevice: true).isWaiter, isFalse);
      expect(staff(StaffJob.server).isWaiter, isFalse);
    });

    test('usesDevice survives a save and reload, and is off when missing', () {
      final saved = staff(StaffJob.server, usesDevice: true).toJson();
      expect(Cashier.fromJson(saved).usesDevice, isTrue);
      expect(Cashier.fromJson({'id': 'a', 'name': 'A', 'initials': 'A', 'role': 'server'}).usesDevice, isFalse);
    });
  });

  group('where a waiter may go', () {
    test('the floor and one table open', () {
      expect(AppSections.waiterRedirect('/pos/tables'), isNull);
      expect(AppSections.waiterRedirect('/pos/tables/t4'), isNull);
    });

    test('every other till page goes to the floor', () {
      for (final path in ['/pos', '/pos/takeout', '/pos/log', '/pos/shifts', '/pos/dishes', '/pos/tables/t4/pay']) {
        expect(AppSections.waiterRedirect(path), '/pos/tables', reason: path);
      }
    });

    test('admin pages go to sign-in; sign-in itself stays open', () {
      expect(AppSections.waiterRedirect('/admin'), '/login');
      expect(AppSections.waiterRedirect('/admin/sales'), '/login');
      expect(AppSections.waiterRedirect('/admin/wages'), '/login');
      expect(AppSections.waiterRedirect('/login'), isNull);
    });

    test('the waiter menu has the floor only', () {
      expect(AppSections.waiter.map((s) => s.path), ['/pos/tables']);
    });
  });

  group('on the device', () {
    late Directory appData;

    setUpAll(() {
      appData = Directory.systemTemp.createTempSync('waiter_device_test');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => appData.path,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (call) async => {'appName': 'Cafe POS', 'packageName': 'cafe_pos', 'version': '1.0.0', 'buildNumber': '1'},
      );
    });
    tearDownAll(() {
      try {
        appData.deleteSync(recursive: true);
      } on FileSystemException {
        // a locked temp file is left for the OS to clean up
      }
    });
    tearDown(() => db.closeLocal());

    /// Table 4 has an unpaid tab, table 5 is seated with nothing ordered, table 6 asked for the bill.
    Future<CafeStore> waiterStore() async {
      db.closeLocal();
      final store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
      final tables = [
        CafeTable(id: 't4', number: '4', qrSlug: 'slug-4'),
        CafeTable(id: 't5', number: '5', qrSlug: 'slug-5', status: TableStatus.dining, guests: 2),
        CafeTable(id: 't6', number: '6', qrSlug: 'slug-6'),
      ];
      await db.writeTables(tables, changed: tables);
      final dish = MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7.5, categoryId: 'drinks');
      await db.writeMenuItems([dish], changed: [dish]);
      await db.writeCarts({
        for (final id in ['t4', 't6'])
          id: CartState(tableId: id, lines: [OrderLine(menuItemId: dish.id, name: 'Latte', qty: 2, unitPrice: 7.5)]),
      });
      expect(await db.sendTableCart('t4'), isNull);
      expect(await db.sendTableCart('t6'), isNull);
      await store.syncFromDisk();
      await store.requestBill('t6', force: true);
      store
        ..locale = 'en'
        ..authKind = AuthKind.waiter;
      return store;
    }

    test('a device server signs in as a waiter, a cashier as a till', () async {
      db.closeLocal();
      final store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
      await store.addCashier(name: 'Omar', pin: '2222', role: StaffJob.server, usesDevice: true);
      await store.addCashier(name: 'Sara', pin: '1111');
      final omar = store.cashiers.firstWhere((c) => c.name == 'Omar');
      expect(omar.isWaiter, isTrue);

      store.selectCashier(omar.id);
      for (final digit in '2222'.split('')) {
        store.enterPinDigit(digit);
      }
      expect(await store.signInCashier(), isTrue);
      expect(store.authKind, AuthKind.waiter);
      expect(store.currentShift, isNull, reason: 'a waiter opens no shift');
      store.signOut();

      store.selectCashier(store.cashiers.firstWhere((c) => c.name == 'Sara').id);
      for (final digit in '1111'.split('')) {
        store.enterPinDigit(digit);
      }
      expect(await store.signInCashier(), isTrue);
      expect(store.authKind, AuthKind.cashier);
      store.signOut();
    });

    test('a waiter cannot clear an unpaid table, but can clear one with nothing unpaid', () async {
      final store = await waiterStore();
      expect(await store.clearTable('t4'), ErrorCodes.waitingForPayment);
      expect(db.orders.where((o) => o.tableId == 't4' && o.status != OrderStatus.paid), hasLength(1),
          reason: 'the unpaid tab stays');
      expect(await store.clearTable('t5'), isNull);
      expect(db.tables.firstWhere((t) => t.id == 't5').status, TableStatus.free);
    });

    testWidgets('the waiter floor has no settle button and waits for payment', (tester) async {
      final store = (await tester.runAsync(waiterStore))!;
      await pumpAdminScreen(tester, const CashierFloorScreen(), store);
      await settle(tester);

      expect(find.text('Settle Bill'), findsNothing);
      expect(find.textContaining('Settle'), findsNothing);
      final waiting = find.widgetWithText(FilledButton, 'Waiting for payment');
      expect(waiting, findsOneWidget, reason: 'table 6 asked for the bill');
      expect(tester.widget<FilledButton>(waiting).onPressed, isNull);

      // The cart dialog shows the tab but offers no settle button either.
      await tester.tap(find.text('View cart').first);
      await settle(tester);
      expect(find.textContaining('Settle'), findsNothing);
    });

    testWidgets('Clear is disabled on an unpaid table and works on a paid-up one', (tester) async {
      final store = (await tester.runAsync(waiterStore))!;
      await pumpAdminScreen(tester, const CashierFloorScreen(), store);
      await settle(tester);

      final unpaid = tester.widget<IconButton>(find.byKey(const Key('clear-table-t4')));
      expect(unpaid.onPressed, isNull);
      expect(unpaid.tooltip, 'Waiting for payment');

      final paidUp = tester.widget<IconButton>(find.byKey(const Key('clear-table-t5')));
      expect(paidUp.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('clear-table-t5')));
      await settle(tester);
      expect(find.textContaining('Everything on this table is paid'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-clear-table')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);
      expect(db.tables.firstWhere((t) => t.id == 't5').status, TableStatus.free);
    });
  });
}
