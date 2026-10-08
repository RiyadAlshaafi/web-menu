import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/ledger.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/takeout_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A table named Takeout from before takeout stopped needing one: it must stay out of table lists.
  CafeTable legacyCounter() => CafeTable(id: 'counter', number: 'Takeout', qrSlug: 'takeout', status: TableStatus.free);
  CafeTable dining() => CafeTable(id: 't1', number: '4', qrSlug: 't1', status: TableStatus.dining, guests: 2);
  OrderLine espresso() => OrderLine(menuItemId: 'esp', name: 'Espresso', qty: 1, unitPrice: 3);

  test('takeout stays takeout after payment and a json reload', () {
    final orders = <CafeOrder>[];
    final payments = <Payment>[];
    final table = legacyCounter();
    expect(
      applyQuickTakeout(
        orders: orders,
        payments: payments,
        lines: [espresso()],
        paymentTypeId: 'cash',
        cashierId: 'c1',
        shiftId: 's1',
        orderId: 'o1',
        paymentId: 'p1',
      ),
      isNull,
    );
    expect(table.status, TableStatus.free);
    final reloaded = CafeOrder.fromJson(orders.single.toJson());
    expect(reloaded.serviceType, 'takeout');
    expect(reloaded.status, OrderStatus.paid);
    expect(reloaded.tableId, isEmpty);
    expect(payments.single.tableId, isEmpty);
    expect(payments.single.isTakeout, isTrue);

    final store = CafeStore(AppDatabase.instance);
    store.orders = [reloaded];
    store.payments = payments;
    store.tables = [table, dining()];
    expect(store.paymentIsTakeout(payments.single), isTrue);
    expect(saleLedgerRow(store, payments.single).takeout, isTrue);
    expect(saleLedgerRow(store, payments.single).tableNumber, isEmpty);
    expect(store.diningTables.where((item) => item.status != TableStatus.free), hasLength(1));
    expect(store.diningTables.map((item) => item.number), ['4']);
  });

  test('two takeout tickets stay separate and a failed ticket adds no sale', () {
    final orders = <CafeOrder>[];
    final payments = <Payment>[];
    final table = legacyCounter();
    applyQuickTakeout(
      orders: orders,
      payments: payments,
      lines: [espresso()],
      paymentTypeId: 'cash',
      cashierId: 'c1',
      shiftId: 's1',
      orderId: 'o1',
      paymentId: 'p1',
    );
    applyQuickTakeout(
      orders: orders,
      payments: payments,
      lines: [OrderLine(menuItemId: 'tea', name: 'Tea', qty: 2, unitPrice: 2)],
      paymentTypeId: 'card',
      cashierId: 'c1',
      shiftId: 's1',
      orderId: 'o2',
      paymentId: 'p2',
    );
    expect(orders.map((order) => order.id), ['o1', 'o2']);
    expect(payments.map((payment) => payment.orderId), ['o1', 'o2']);
    expect(payments[0].totalDue, 3);
    expect(payments[1].totalDue, 4);
    expect(orders.every((order) => order.serviceType == 'takeout'), isTrue);
    expect(table.status, TableStatus.free);

    expect(
      applyQuickTakeout(
        orders: orders,
        payments: payments,
        lines: const [],
        paymentTypeId: null,
        cashierId: 'c1',
        shiftId: 's1',
        orderId: 'o3',
        paymentId: 'p3',
      ),
      'cart is empty',
    );
    expect(orders, hasLength(2));
    expect(payments, hasLength(2));
  });

  test('a second click while checkout is running does not add another sale', () async {
    final store = CafeStore(AppDatabase.instance);
    store.cafe = {'name': '', 'serviceChargeRate': 0.10};
    if (AppDatabase.instance.client != null) return;
    // No takeout table at all: takeout is only a label.
    store.tables = [dining()];
    store.currentCashier = Cashier(id: 'c1', name: 'Ada', pinHash: '', pinSalt: '', initials: 'A');
    store.currentShift = CashShift(id: 's1', cashierId: 'c1', openedAt: DateTime.utc(2026, 10, 5), openingCash: 0);
    final kept = [espresso()];
    final first = store.checkoutTakeout(lines: kept, paymentTypeId: 'cash');
    final second = store.checkoutTakeout(lines: kept, paymentTypeId: 'cash');
    final results = await Future.wait([first, second]);
    expect(results.where((error) => error == null), hasLength(1));
    expect(results.where((error) => error == 'in_flight'), hasLength(1));
    expect(store.payments, hasLength(1));
    expect(store.orders, hasLength(1));
    expect(store.orders.single.serviceType, 'takeout');
    expect(store.tables.firstWhere((table) => table.number == '4').status, TableStatus.dining);
    expect(kept, isNotEmpty);

    store.currentCashier = null;
    final failed = await store.checkoutTakeout(lines: kept, paymentTypeId: 'cash');
    expect(failed, isNotNull);
    expect(store.payments, hasLength(1));
  });

  test('a dine-in order is not classified as takeout', () {
    final store = CafeStore(AppDatabase.instance);
    store.cafe = {'serviceChargeRate': 0.10};
    final table = dining();
    final order = CafeOrder(
      id: 'dine',
      tableId: table.id,
      tableNumber: table.number,
      status: OrderStatus.paid,
      createdAt: DateTime.utc(2026, 10, 5),
      lines: [espresso()],
    );
    final payment = Payment(
      id: 'pd',
      orderId: order.id,
      tableId: table.id,
      totalDue: 3,
      cashReceived: 3,
      changeDue: 0,
      cashierId: 'c1',
      shiftId: 's1',
      paidAt: DateTime.utc(2026, 10, 5),
    );
    store.tables = [table];
    store.orders = [order];
    store.payments = [payment];
    expect(order.serviceType, 'dine_in');
    expect(store.paymentIsTakeout(payment), isFalse);
    expect(saleLedgerRow(store, payment).takeout, isFalse);
    expect(saleLedgerRow(store, payment).tableNumber, '4');
    expect(store.chargeTotal(3, applyService: false), 3);
    expect(store.chargeTotal(3, applyService: true), closeTo(3.3, 0.001));
  });
}
