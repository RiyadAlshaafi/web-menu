import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/money.dart';
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

  group('dish stock', () {
    test('each sale lowers the stock and at 0 the dish is sold out', () async {
      final dish = await _dish();
      expect(await db.setDishStock(dish.id, 3), isNull);
      await _openShift(await _cashier('Sara', '1234'));

      await db.quickTakeoutReceipt(_ticket(dish, 2), null);
      expect(db.menuItems.single.stockQty, 1);
      expect(db.menuItems.single.soldOut, isFalse);

      await db.writeCarts({'t1': CartState(tableId: 't1', lines: _ticket(dish, 1))});
      final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
      await db.writeTables([table], changed: [table]);
      expect(await db.sendTableCart('t1'), isNull);
      expect(db.menuItems.single.stockQty, 0);
      expect(db.menuItems.single.soldOut, isTrue);
    });

    test('a dish without a limit is never counted', () async {
      final dish = await _dish();
      await _openShift(await _cashier('Sara', '1234'));
      await db.quickTakeoutReceipt(_ticket(dish, 5), null);
      expect(db.menuItems.single.stockQty, isNull);
      expect(db.menuItems.single.soldOut, isFalse);
    });

    test('restocking turns a sold-out dish back on; no limit keeps it as it was', () async {
      final dish = await _dish();
      await db.setDishStock(dish.id, 0);
      expect(db.menuItems.single.soldOut, isTrue);
      await db.setDishStock(dish.id, 13);
      expect(db.menuItems.single.soldOut, isFalse);
      expect(db.menuItems.single.stockQty, 13);
      await db.setDishStock(dish.id, null);
      expect(db.menuItems.single.stockQty, isNull);
    });
  });

  group('voided sales', () {
    test('a void keeps the sale listed but takes it off the shift, and the order stays paid', () async {
      final dish = await _dish();
      final shift = await _openShift(await _cashier('Sara', '1234'));
      await db.quickTakeoutReceipt(_ticket(dish, 2), db.paymentTypes.first.id);
      await db.quickTakeoutReceipt(_ticket(dish, 1), db.paymentTypes.first.id);
      final sale = db.payments.firstWhere((p) => p.totalDue == 15);

      expect(await db.voidPayment(sale.id, '  Customer left  '), isNull);

      final voided = db.payments.firstWhere((p) => p.id == sale.id);
      expect(voided.isVoided, isTrue);
      expect(voided.voidReason, 'Customer left');
      expect(db.payments, hasLength(2));
      final saved = db.shifts.firstWhere((s) => s.id == shift.id);
      expect(saved.cashSales, 7.5);
      expect(saved.transactionCount, 1);
      expect(db.orders.firstWhere((o) => o.id == sale.orderId).status, OrderStatus.paid);
    });

    test('a blank reason, a second void, another cashier or a closed shift are refused', () async {
      final dish = await _dish();
      final sara = await _cashier('Sara', '1234');
      final omar = await _cashier('Omar', '1234');
      final shift = await _openShift(sara);
      await db.quickTakeoutReceipt(_ticket(dish, 1), null);
      final sale = db.payments.single;

      expect(await db.voidPayment(sale.id, '   '), 'reason required');
      expect((await db.loginCashier(omar, '1234'))['ok'], isTrue);
      expect(await db.voidPayment(sale.id, 'left'), 'not_found');
      expect((await db.loginCashier(sara, '1234'))['ok'], isTrue);
      expect(db.payments.single.isVoided, isFalse);
      expect(await db.voidPayment(sale.id, 'left'), isNull);
      expect(await db.voidPayment(sale.id, 'again'), 'already voided');

      await db.quickTakeoutReceipt(_ticket(dish, 1), null);
      final later = db.payments.firstWhere((p) => !p.isVoided);
      final open = db.shifts.firstWhere((s) => s.id == shift.id)..closedAt = DateTime.now().toUtc();
      await db.writeShifts([open, ...db.shifts.where((s) => s.id != shift.id)]);
      expect(await db.voidPayment(later.id, 'late'), 'shift closed');
    });
  });

  group('refunds', () {
    test('a cash refund takes the dish share off the sale, the shift and the drawer', () async {
      final dish = await _dish();
      final shift = await _openShift(await _cashier('Sara', '1234'));
      await db.quickTakeoutReceipt(_ticket(dish, 3), db.paymentTypes.first.id);
      final sale = db.payments.single;

      expect(await db.refundLine(sale.id, '#0', 1, '  cold  '), isNull);

      final refunded = db.payments.single;
      expect(refunded.refundedTotal, 7.5);
      expect(refunded.netTotal, 15);
      expect(refunded.refunds.single.reason, 'cold');
      final saved = db.shifts.firstWhere((s) => s.id == shift.id);
      expect(saved.cashSales, 15);
      expect(saved.cashRefunds, 7.5);
    });

    test('more than is left is refused; the last refund takes what is left', () async {
      final dish = await _dish();
      await _openShift(await _cashier('Sara', '1234'));
      await db.quickTakeoutReceipt(_ticket(dish, 3), null);
      final sale = db.payments.single;
      expect(await db.refundLine(sale.id, '#0', 1, 'cold'), isNull);

      expect(await db.refundLine(sale.id, '#0', 3, 'more'), 'too many');
      expect(await db.refundLine(sale.id, '#9', 1, 'more'), 'not_found');
      expect(await db.refundLine(sale.id, '#0', 1, ' '), 'reason required');
      expect(await db.refundLine(sale.id, '#0', 2, 'rest'), isNull);
      expect(db.payments.single.netTotal, 0);
    });

    test('a card refund leaves the drawer alone; a later void takes only the rest', () async {
      final dish = await _dish();
      final shift = await _openShift(await _cashier('Sara', '1234'));
      final card = db.paymentTypes.firstWhere((type) => type.nameEn == 'Card');
      await db.quickTakeoutReceipt(_ticket(dish, 2), card.id);
      await db.quickTakeoutReceipt(_ticket(dish, 2), null);
      final cardSale = db.payments.firstWhere((p) => p.paymentTypeId == card.id);
      final cashSale = db.payments.firstWhere((p) => p.id != cardSale.id);

      expect(await db.refundLine(cardSale.id, '#0', 1, 'spilt'), isNull);
      expect(db.shifts.firstWhere((s) => s.id == shift.id).cashRefunds, 0);

      expect(await db.refundLine(cashSale.id, '#0', 1, 'cold'), isNull);
      expect(await db.voidPayment(cashSale.id, 'left'), isNull);
      final saved = db.shifts.firstWhere((s) => s.id == shift.id);
      expect(saved.cashSales, 7.5, reason: 'only what is left of the card sale');
      expect(saved.cashRefunds, 0, reason: 'the voided sale no longer counts in the drawer at all');
      expect(await db.refundLine(cashSale.id, '#0', 1, 'again'), 'already voided');
    });

    test('the share of a service charge is refunded too', () {
      final lines = [
        OrderLine(menuItemId: 'tea', name: 'Tea', qty: 3, unitPrice: 2),
        OrderLine(menuItemId: 'cake', name: 'Cake', qty: 1, unitPrice: 5),
      ];
      final sale = Payment(
        id: 'p', orderId: 'o', tableId: 't', totalDue: 12.1, cashReceived: 12.1, changeDue: 0,
        cashierId: 'c', shiftId: 's', paidAt: DateTime.utc(2026),
      );

      expect(refundAmount(sale, lines, lines[0], 1), 2.2, reason: '2 of 11 plus its 10% service');
      expect(refundAmount(sale, lines, lines[1], 1), 5.5);
    });
  });

  group('expenses', () {
    test('can be tagged with an employee, and an edit keeps the tag', () async {
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
          staffId: 'chef-1',
          staffName: 'Omar',
          amount: 20,
          description: 'advance',
        ),
        isNull,
      );
      final first = db.expenses.single;
      expect(first.staffId, 'chef-1');
      expect(first.employeeName, 'Omar');
      expect(first.paidToCafe, isTrue, reason: 'a tag never turns the expense into a withdrawal');

      expect(await db.editShiftExpense(id: first.id, categoryId: cafe, amount: 25, description: 'advance x'), isNull);
      final fixed = db.expenses.firstWhere((e) => !e.voided);
      expect(fixed.staffId, 'chef-1');
      expect(fixed.employeeName, 'Omar');
    });

    test('the report is worked out from the SQLite file: voids apart, an edit counts once', () async {
      final sara = await _cashier('Sara', '1234');
      final shift = await _openShift(sara);
      final dish = await _dish();
      await db.quickTakeoutReceipt(_ticket(dish, 2), db.paymentTypes.first.id);
      await db.quickTakeoutReceipt(_ticket(dish, 1), db.paymentTypes.first.id);
      expect(await db.voidPayment(db.payments.first.id, 'mistake'), isNull);
      final cafe = db.expenseCategories.first.id;
      await db.addShiftExpense(
        shiftId: shift.id,
        cashierId: sara,
        categoryId: cafe,
        paidToCafe: true,
        paidToCashierId: null,
        amount: 10,
        description: 'milk',
      );
      await db.editShiftExpense(id: db.expenses.single.id, categoryId: cafe, amount: 12, description: 'milk x');

      final local = toTripoli(DateTime.now());
      final today = DateTime(local.year, local.month, local.day);
      final result = await db.salesReport(today, today);
      final report = result.report!;
      expect((report.salesCount, report.salesTotal), (1, 15.0));
      expect((report.voidCount, report.voidTotal), (1, 7.5));
      expect(report.expensesTotal, 12, reason: 'the edited expense counts once');
      expect(report.net, 3);
      final empty = (await db.salesReport(DateTime(2020, 1, 1), DateTime(2020, 1, 31))).report!;
      expect(empty.isEmpty, isTrue);
    });

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
      await db.writeReceiptSettings({'footer': 'Grazie', 'showCashier': true});
      final dish = await _dish();
      final sara = await _cashier('Sara', '1234');
      await _openShift(sara);
      await db.quickTakeoutReceipt(_ticket(dish, 3), db.paymentTypes.first.id);
      await db.setItemAvailable(dish.id, false);
      await db.writeCarts({'t9': CartState(tableId: 't9', lines: _ticket(dish, 2))});

      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));

      expect(db.cafe['name'], 'Tawla Test');
      expect(db.locale, 'ar');
      expect(db.cafe['receiptSettings'], {'footer': 'Grazie', 'showCashier': true}, reason: 'receipt settings live on an offline till too');
      expect(db.anyAdmin, isTrue);
      expect(db.admin, isNull, reason: 'the admin was not kept signed in');
      expect(db.menuItems.single.available, isFalse);
      expect(db.cashiers.single.name, 'Sara');
      expect(db.payments.single.totalDue, 22.5);
      expect(db.shifts.single.cashSales, 22.5);
      expect(db.paymentTypes, hasLength(4), reason: 'defaults are not added twice');
      expect(db.carts['t9']?.lines.single.qty, 2, reason: 'a half-entered table cart survives');
      expect((await db.loginCashier(sara, '1234'))['ok'], isTrue);
      await db.quickTakeoutReceipt(_ticket(dish, 1), null);
      expect(db.payments.first.monthlyOrderNumber, 2, reason: 'numbering continues after a restart');
    });

    test('a voided sale is still voided after the app restarts', () async {
      final path = p.join(dir.path, localDatabaseFileName);
      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));
      final dish = await _dish();
      await _openShift(await _cashier('Sara', '1234'));
      await db.quickTakeoutReceipt(_ticket(dish, 2), null);
      expect(await db.voidPayment(db.payments.single.id, 'Customer left'), isNull);

      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));

      expect(db.payments.single.isVoided, isTrue);
      expect(db.payments.single.voidReason, 'Customer left');
      expect(db.shifts.single.cashSales, 0);
    });
  });

  group('moving tables', () {
    late MenuItem dish;
    final t1 = CafeTable(id: 't1', number: '1', qrSlug: 'slug-1');
    final t2 = CafeTable(id: 't2', number: '2', qrSlug: 'slug-2');
    final t3 = CafeTable(id: 't3', number: '3', qrSlug: 'slug-3');

    Future<void> send(String tableId, int qty) async {
      await db.writeCarts({tableId: CartState(tableId: tableId, lines: _ticket(dish, qty))});
      expect(await db.sendTableCart(tableId), isNull);
    }

    CafeOrder? tab(String tableId) => db.orders.where((o) => o.tableId == tableId && o.status != OrderStatus.paid).firstOrNull;

    setUp(() async {
      dish = await _dish();
      for (final table in [t1, t2, t3]) {
        table.status = TableStatus.free;
      }
      await db.writeTables([t1, t2, t3], changed: [t1, t2, t3]);
      await _openShift(await _cashier('Sara', '1234'));
    });

    test('to a free table the same tab moves and the first table is freed', () async {
      await send('t1', 2);
      final before = tab('t1')!;

      expect(await db.moveTable('t1', 't2'), isNull);

      expect(tab('t1'), isNull);
      expect(tab('t2')!.id, before.id, reason: 'the same order, so the kitchen does not print it again');
      expect(tab('t2')!.tableNumber, '2');
      expect(db.tables.firstWhere((t) => t.id == 't1').status, TableStatus.free);
      expect(db.tables.firstWhere((t) => t.id == 't2').status, TableStatus.dining);
    });

    test('into a busy table the dishes join its tab within its rounds', () async {
      await send('t1', 1);
      await send('t1', 2);
      await send('t3', 4);

      expect(await db.moveTable('t1', 't3'), isNull);

      expect(tab('t1'), isNull);
      expect(tab('t3')!.itemCount, 7);
      expect(tab('t3')!.lines.map((l) => l.round), everyElement(1), reason: 'capped at table 3\'s last round');
      expect(db.orders.where((o) => o.status != OrderStatus.paid), hasLength(1));
    });

    test('an empty table, the same table or an unknown table is refused', () async {
      expect(await db.moveTable('t1', 't2'), 'nothing to move');
      await send('t1', 1);
      expect(await db.moveTable('t1', 't1'), 'pick another table');
      expect(await db.moveTable('t1', 'nope'), 'table not found');
    });
  });

  group('tables (open tab, pay later)', () {
    late MenuItem dish;
    late CashShift shift;
    final table = CafeTable(id: 't4', number: '4', qrSlug: 'slug-4');

    Future<void> cart(int qty) =>
        db.writeCarts({'t4': CartState(tableId: 't4', lines: _ticket(dish, qty))});

    setUp(() async {
      dish = await _dish();
      table.status = TableStatus.free;
      await db.writeTables([table], changed: [table]);
      await db.writeCafe({...db.cafe, 'serviceChargeRate': 0.1});
      shift = await _openShift(await _cashier('Sara', '1234'));
    });

    CafeOrder openTab() => db.orders.singleWhere((o) => o.tableId == 't4' && o.status != OrderStatus.paid);

    test('dishes join the tab in rounds; settling adds service and frees the table', () async {
      await cart(2);
      expect(await db.sendTableCart('t4'), isNull);
      final tab = openTab();
      expect(tab.status, OrderStatus.served, reason: 'cashier-entered tabs can be settled at once');
      expect(tab.shiftOrderNumber, 1);
      expect(tab.tableNumber, '4');
      expect(db.tables.single.status, TableStatus.dining);
      expect(db.carts['t4'], isNull, reason: 'the sent cart is cleared');

      await cart(1);
      expect(await db.sendTableCart('t4'), isNull);
      expect(db.orders.where((o) => o.tableId == 't4'), hasLength(1), reason: 'one tab, not two orders');
      expect(openTab().lines.map((l) => l.round), [1, 2]);

      expect(await db.settleCash('t4', 20), 'insufficient cash', reason: '22.5 + 10% = 24.75');
      expect(await db.settleCash('t4', 30, paymentTypeId: db.paymentTypes[1].id), isNull);
      final paid = db.payments.single;
      expect(paid.totalDue, 24.75);
      expect(paid.cashReceived, 30);
      expect(paid.changeDue, 5.25);
      expect(paid.tableNumber, '4');
      expect(paid.isTakeout, isFalse);
      expect(paid.paymentTypeNameEn, 'Card');
      expect(paid.monthlyOrderNumber, 1);
      expect(paid.shiftOrderNumber, 1);
      expect(db.orders.single.status, OrderStatus.paid);
      expect(db.tables.single.status, TableStatus.free);
      expect(db.shifts.firstWhere((s) => s.id == shift.id).cashSales, 24.75);
      expect(await db.settleCash('t4', 30), 'no open bill');
    });

    test('split bill: a part is paid on its own, the rest stays open, the last part frees the table', () async {
      await cart(3);
      expect(await db.sendTableCart('t4'), isNull);
      final number = openTab().shiftOrderNumber;
      final key = orderLineKey(openTab().lines.single, 0);

      expect(await db.settlePart('t4', {key: 1}, 100, paymentTypeId: db.paymentTypes[1].id), isNull);

      final part = db.payments.single;
      expect(part.totalDue, 8.25, reason: 'one latte 7.5 + 10%');
      expect(part.paymentTypeNameEn, 'Card');
      expect(part.shiftOrderNumber, number, reason: 'the part keeps the tab\'s order number');
      expect(openTab().itemCount, 2);
      expect(db.tables.single.status, TableStatus.dining);
      expect(db.shifts.firstWhere((s) => s.id == shift.id).cashSales, 8.25);

      expect(await db.settleCash('t4', 100), isNull);
      expect(db.payments, hasLength(2));
      expect(db.payments.first.totalDue, 16.5);
      expect(db.tables.single.status, TableStatus.free);
    });

    test('split bill: the whole bill, too many or too little cash is refused', () async {
      await cart(2);
      expect(await db.sendTableCart('t4'), isNull);

      final key = orderLineKey(openTab().lines.single, 0);

      expect(await db.settlePart('t4', {key: 2}, 100), 'whole bill');
      expect(await db.settlePart('t4', {key: 3}, 100), 'pick dishes');
      expect(await db.settlePart('t4', {'#7': 1}, 100), 'pick dishes');
      expect(await db.settlePart('t4', {key: 1}, 1), 'insufficient cash');
      expect(db.payments, isEmpty);
      expect(openTab().itemCount, 2);
    });

    test('settling without service charges only the dishes', () async {
      await cart(2);
      await db.sendTableCart('t4');
      expect(await db.settleCash('t4', 15, applyService: false), isNull);
      expect(db.payments.single.totalDue, 15);
      expect(db.payments.single.changeDue, 0);
    });

    test('a tab and a takeout sale share the daily and monthly numbers', () async {
      await db.quickTakeoutReceipt(_ticket(dish, 1), null);
      await cart(1);
      await db.sendTableCart('t4');
      expect(openTab().shiftOrderNumber, 2);
      await db.settleCash('t4', 100);
      expect(db.payments.first.monthlyOrderNumber, 2);
    });

    test('a dish that is off the menu is refused when sent', () async {
      await cart(1);
      await db.setItemAvailable(dish.id, false);
      expect(await db.sendTableCart('t4'), '${AppDatabase.unavailableItemsError}Latte');
      expect(db.orders, isEmpty);
    });

    test('taking off a dish keeps the tab; taking off the last one frees the table', () async {
      await db.writeCarts({
        't4': CartState(tableId: 't4', lines: [
          ..._ticket(dish, 1),
          OrderLine(menuItemId: dish.id, name: 'Latte extra', qty: 1, unitPrice: 3),
        ]),
      });
      await db.sendTableCart('t4');
      final lines = openTab().lines;
      expect(await db.removeOrderLine(lines.first.id!), isNull);
      expect(openTab().lines, hasLength(1));
      expect(await db.removeOrderLine(openTab().lines.single.id!), isNull);
      expect(db.orders, isEmpty);
      expect(db.tables.single.status, TableStatus.free);
    });

    test('clearing a table cancels its unpaid tab, empties the cart and frees it; paid sales stay', () async {
      // A paid sale on table 4 first.
      await cart(1);
      await db.sendTableCart('t4');
      await db.settleCash('t4', 100);
      expect(db.payments, hasLength(1));
      // Then a new unpaid tab, a pending cart and an open call.
      await cart(2);
      await db.sendTableCart('t4');
      await cart(1);
      await db.writeCalls([
        StaffCall(id: 'c1', tableId: 't4', tableNumber: '4', createdAt: DateTime.now(), kind: 'assistance'),
      ]);
      expect(db.tables.single.status, TableStatus.dining);

      expect(await db.clearTable('t4'), isNull);

      expect(db.orders.where((o) => o.status != OrderStatus.paid), isEmpty, reason: 'the unpaid tab is cancelled');
      expect(db.orders.where((o) => o.status == OrderStatus.paid), hasLength(1), reason: 'paid history stays');
      expect(db.payments, hasLength(1));
      expect(db.carts['t4']?.lines ?? const [], isEmpty);
      expect(db.calls.where((c) => !c.resolved), isEmpty);
      expect(db.tables.single.status, TableStatus.free);
      expect(db.tables.single.guests, 0);
    });

    test('clearing a table that does not exist is refused', () async {
      expect(await db.clearTable('nope'), 'table not found');
    });

    test('the chosen payment method is kept on the tab', () async {
      await cart(1);
      await db.sendTableCart('t4');
      expect(await db.setTablePaymentType('slug-4', db.paymentTypes[2].id), isNull);
      await db.settleCash('t4', 100);
      expect(db.payments.single.paymentTypeNameEn, 'Bank Transfer');
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

      // A table: open tab, add more, settle from the floor.
      final table = await store.addTable('7');
      store.addToCart(table.id, dish);
      await store.sendCartToKitchen(table.id);
      store.addToCart(table.id, dish);
      await store.sendCartToKitchen(table.id);
      expect(store.openOrderFor(table.id)?.itemCount, 2);
      expect(store.tabTotal(table.id), 15);
      expect(await store.settleCash(tableId: table.id, cashReceived: 20), isNull);
      expect(store.openOrderFor(table.id), isNull);
      expect(store.payments, hasLength(2));

      expect(await store.closeShift(actualCash: 15), isNull);
      expect(db.shifts.single.isOpen, isFalse);
      expect(db.shifts.single.actualCash, 15);
    });

    test('a table cart holds no more of a dish than its stock', () async {
      await _dish();
      await store.syncFromDisk();
      final item = store.menuItems.single;
      expect(await store.setDishStock(item, 2), isNull);
      final table = await store.addTable('3');
      for (var i = 0; i < 3; i++) {
        store.addToCart(table.id, item);
      }
      expect(store.cartFor(table.id).lines.single.qty, 2);
      store.setCartQty(table.id, store.cartFor(table.id).lines.single.mergeKey, 5);
      expect(store.cartFor(table.id).lines.single.qty, 2);
    });
  });
}
