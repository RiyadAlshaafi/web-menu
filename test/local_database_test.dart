import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/data/local_state_store_io.dart' show SqliteLocalStateStore, localDatabaseFileName;
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:path/path.dart' as p;

final db = AppDatabase.instance;

Future<String> _cashier(String name, String pin) async =>
    (await db.createCashier(name: name, pin: pin, initials: name[0]))!;

/// Signs [cashierId] in and opens their shift, as the store does at sign-in.
Future<CashShift> _openShift(String cashierId) async {
  expect((await db.loginCashier(cashierId, '1234'))['ok'], isTrue);
  final shift = CashShift(id: 'shift-$cashierId', cashierId: cashierId, openedAt: DateTime.now().toUtc(), openingCash: 0);
  await db.writeShifts([shift, ...db.shifts]);
  return shift;
}

List<OrderLine> _ticket(MenuItem dish, int qty) =>
    [OrderLine(menuItemId: dish.id, name: dish.nameEn, qty: qty, unitPrice: dish.price)];

Future<MenuItem> _dish() async {
  final dish = MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7.5, categoryId: 'drinks');
  await db.writeMenuItems([dish], changed: [dish]);
  return dish;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => db.initLocal(openMemoryLocalStateStore()));
  tearDown(() => db.closeLocal());

  group('first start', () {
    test('has the default payment methods and expense types, and no admin yet', () {
      expect(db.isLocal, isTrue);
      expect(db.paymentTypes.map((t) => t.nameEn), ['Cash', 'Card', 'Bank Transfer', 'Mobile Wallet']);
      expect(db.expenseCategories.map((c) => c.nameEn), ['Café Expense', 'Cash Withdrawal']);
      expect(db.anyAdmin, isFalse);
      expect(db.admin, isNull);
    });
  });

  group('admin', () {
    test('is created once and signs in only with the right email and password', () {
      expect(db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123'), isNull);
      expect(db.anyAdmin, isTrue);
      expect(db.createLocalAdmin(email: 'other@cafe.ly', password: 'Secret#123'), 'admin_exists');
      db.signOutLocalAdmin();
      expect(db.admin, isNull);
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'wrong', remember: false), isFalse);
      expect(db.signInLocalAdmin(email: 'x@cafe.ly', password: 'Secret#123', remember: false), isFalse);
      expect(db.signInLocalAdmin(email: ' OWNER@cafe.ly', password: 'Secret#123', remember: false), isTrue);
      expect(db.admin?.email, 'owner@cafe.ly');
    });

    test('changes password only after the current one is checked', () {
      db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      expect(db.changeLocalAdminPassword(current: 'nope', next: 'Better#456'), isFalse);
      expect(db.changeLocalAdminPassword(current: 'Secret#123', next: 'Better#456'), isTrue);
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123', remember: false), isFalse);
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Better#456', remember: false), isTrue);
    });
  });

  group('cashiers', () {
    test('sign in with their PIN; 5 wrong PINs lock them for 15 minutes', () async {
      final sara = await _cashier('Sara', '1234');
      expect(db.cashiers.map((c) => c.name), ['Sara']);
      for (var i = 0; i < 4; i++) {
        expect((await db.loginCashier(sara, '0000'))['ok'], isFalse);
      }
      final fifth = await db.loginCashier(sara, '0000');
      expect(fifth['ok'], isFalse);
      final locked = await db.loginCashier(sara, '1234');
      expect(locked['code'], 'locked');
      expect(locked['retry_after_seconds'], greaterThan(800));
    });

    test('a removed cashier can no longer sign in', () async {
      final sara = await _cashier('Sara', '1234');
      await db.deactivateCashier(sara);
      expect(db.cashiers, isEmpty);
      expect((await db.loginCashier(sara, '1234'))['ok'], isFalse);
    });
  });

  group('takeout sales', () {
    test('are numbered like the server and added to the shift', () async {
      final dish = await _dish();
      final sara = await _cashier('Sara', '1234');
      final shift = await _openShift(sara);
      final cash = db.paymentTypes.first.id;

      expect(await db.quickTakeoutReceipt(_ticket(dish, 2), cash), isNull);
      expect(await db.quickTakeoutReceipt(_ticket(dish, 1), cash), isNull);

      final sales = db.payments;
      expect(sales, hasLength(2));
      final newest = sales.first;
      expect(newest.totalDue, 7.5);
      expect(newest.monthlyOrderNumber, 2);
      expect(newest.shiftOrderNumber, 2);
      expect(newest.monthlyDisplayNumber, '${newest.yearMonth}002');
      expect(newest.cashierName, 'Sara');
      expect(newest.paymentTypeNameEn, 'Cash');
      expect(newest.isTakeout, isTrue);
      expect(RegExp(r'^\d{4}$').hasMatch(newest.yearMonth!), isTrue);
      final saved = db.shifts.firstWhere((s) => s.id == shift.id);
      expect(saved.cashSales, 22.5);
      expect(saved.transactionCount, 2);
      expect(db.orders.where((o) => o.status == OrderStatus.paid), hasLength(2));
    });

    test('need a signed-in cashier with an open shift', () async {
      final dish = await _dish();
      expect(await db.quickTakeoutReceipt(_ticket(dish, 1), null), 'sign in as a cashier first');
    });

    test('the payment method can be changed later and the change is kept', () async {
      final dish = await _dish();
      await _openShift(await _cashier('Sara', '1234'));
      await db.quickTakeoutReceipt(_ticket(dish, 1), db.paymentTypes.first.id);
      final card = db.paymentTypes[1];
      expect(await db.changePaymentType(db.payments.single.id, card.id), isNull);
      expect(db.payments.single.paymentTypeNameEn, 'Card');
      expect(db.payments.single.changes.single.newTypeId, card.id);
    });

    test('a payment method already on a receipt is archived, not deleted', () async {
      final dish = await _dish();
      await _openShift(await _cashier('Sara', '1234'));
      final cash = db.paymentTypes.first;
      await db.quickTakeoutReceipt(_ticket(dish, 1), cash.id);
      await db.deletePaymentType(cash.id);
      await db.deletePaymentType(db.paymentTypes.last.id);
      expect(db.paymentTypes.firstWhere((t) => t.id == cash.id).archived, isTrue);
      expect(db.paymentTypes.map((t) => t.nameEn), isNot(contains('Mobile Wallet')));
    });
  });

  group('expenses', () {
    test('are numbered E-001, E-002 and an edit voids the old one', () async {
      final sara = await _cashier('Sara', '1234');
      final shift = await _openShift(sara);
      final cafe = db.expenseCategories.first.id;
      expect(
        await db.addShiftExpense(
          shiftId: shift.id,
          cashierId: sara,
          categoryId: cafe,
          paidToCafe: true,
          paidToCashierId: null,
          amount: 12,
          description: 'milk',
        ),
        isNull,
      );
      final first = db.expenses.single;
      expect(first.displayNumber, 'E-001');
      expect(first.cashierName, 'Sara');

      expect(await db.editShiftExpense(id: first.id, categoryId: cafe, amount: 15, description: 'milk x2'), isNull);
      final all = db.expenses;
      expect(all, hasLength(2));
      expect(all.firstWhere((e) => e.id == first.id).voided, isTrue);
      final fixed = all.firstWhere((e) => !e.voided);
      expect(fixed.amount, 15);
      expect(fixed.displayNumber, 'E-002');
      expect(fixed.editedFrom, first.id);
    });

    test('are refused on a closed shift or with no amount', () async {
      final sara = await _cashier('Sara', '1234');
      final shift = await _openShift(sara);
      final cafe = db.expenseCategories.first.id;
      Future<String?> add(double amount) => db.addShiftExpense(
            shiftId: shift.id,
            cashierId: sara,
            categoryId: cafe,
            paidToCafe: true,
            paidToCashierId: null,
            amount: amount,
            description: 'x',
          );
      expect(await add(0), 'invalid');
      shift.closedAt = DateTime.now().toUtc();
      await db.writeShifts(db.shifts);
      expect(await add(5), 'not_found');
    });
  });

  group('saved on this PC', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('local_db'));
    tearDown(() {
      db.closeLocal();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('everything comes back after the app restarts', () async {
      final path = p.join(dir.path, localDatabaseFileName);
      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));
      db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      await db.writeCafe({...db.cafe, 'name': 'Tawla Test'});
      await db.writeLocale('ar');
      final dish = await _dish();
      final sara = await _cashier('Sara', '1234');
      await _openShift(sara);
      await db.quickTakeoutReceipt(_ticket(dish, 3), db.paymentTypes.first.id);
      await db.setItemAvailable(dish.id, false);

      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));

      expect(db.cafe['name'], 'Tawla Test');
      expect(db.locale, 'ar');
      expect(db.anyAdmin, isTrue);
      expect(db.admin, isNull, reason: 'the admin was not kept signed in');
      expect(db.menuItems.single.available, isFalse);
      expect(db.cashiers.single.name, 'Sara');
      expect(db.payments.single.totalDue, 22.5);
      expect(db.shifts.single.cashSales, 22.5);
      expect(db.paymentTypes, hasLength(4), reason: 'defaults are not added twice');
      expect((await db.loginCashier(sara, '1234'))['ok'], isTrue);
      await db.quickTakeoutReceipt(_ticket(dish, 1), null);
      expect(db.payments.first.monthlyOrderNumber, 2, reason: 'numbering continues after a restart');
    });
  });

  group('the app in offline mode', () {
    late CafeStore store;
    late Directory appData;

    setUp(() async {
      appData = Directory.systemTemp.createTempSync('local_app');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => appData.path,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (call) async => {'appName': 'Cafe POS', 'packageName': 'cafe_pos', 'version': '1.0.0', 'buildNumber': '1'},
      );
      db.closeLocal();
      store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
    });
    tearDown(() {
      store.dispose();
      try {
        appData.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('admin signs up, adds a cashier and a dish; the cashier sells and closes the shift', () async {
      expect(store.isLocalMode, isTrue);
      expect(store.deviceLinked, isTrue);
      expect(store.hasAdmin, isFalse);
      expect(await store.createAdmin(email: 'owner@cafe.ly', password: 'Secret#123', confirm: 'Secret#123'), isNull);
      expect(store.authKind, AuthKind.admin);
      expect(await store.changeAdminPassword(current: 'Secret#123', next: 'Better#456'), isNull);
      await store.addCashier(name: 'Sara Ali', pin: '1234');
      final dish = await _dish();
      await store.syncFromDisk();
      store.signOut();
      expect(store.hasAdmin, isTrue);
      expect(await store.signInAdmin('owner@cafe.ly', 'Secret#123'), isNotNull);
      expect(await store.signInAdmin('owner@cafe.ly', 'Better#456'), isNull);
      store.signOut();

      store.selectCashier(store.cashiers.single.id);
      for (final digit in '1234'.split('')) {
        store.enterPinDigit(digit);
      }
      expect(await store.signInCashier(), isTrue, reason: store.loginError);
      expect(store.currentShift, isNotNull);

      expect(await store.checkoutTakeout(lines: _ticket(dish, 2), paymentTypeId: store.enabledPaymentTypes.first.id), isNull);
      expect(store.payments.single.totalDue, 15);
      expect(store.payments.single.cashierName, 'Sara Ali');

      expect(await store.closeShift(actualCash: 15), isNull);
      expect(db.shifts.single.isOpen, isFalse);
      expect(db.shifts.single.actualCash, 15);
    });
  });
}
