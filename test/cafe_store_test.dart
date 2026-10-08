import 'package:flutter_test/flutter_test.dart';

import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const skipLive = bool.fromEnvironment('SUPABASE_URL') == false && String.fromEnvironment('SUPABASE_URL') == '';

  late CafeStore store;

  setUp(() async {
    await AppDatabase.instance.resetEmpty();
    store = CafeStore(AppDatabase.instance);
    await store.load();
  });

  test('one add is one line and a second add increments quantity', () async {
    final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
    store.tables = [table];
    store.menuItems = [
      MenuItem(id: 'wine', nameIt: 'red wine', nameEn: 'red wine', price: 10, categoryId: 'c'),
    ];
    final dish = store.menuItems.single;
    store.addToCart(table.id, dish);
    expect(store.cartFor(table.id).lines, hasLength(1));
    expect(store.cartFor(table.id).lines.single.qty, 1);
    expect(store.cartFor(table.id).total, 10);

    store.addToCart(table.id, dish);
    expect(store.cartFor(table.id).lines, hasLength(1));
    expect(store.cartFor(table.id).lines.single.qty, 2);
    expect(store.cartFor(table.id).total, 20);

    await store.sendCartToKitchen(table.id);
    expect(store.cartFor(table.id).lines, isEmpty);
    final order = store.openOrderFor(table.id)!;
    expect(order.lines, hasLength(1));
    expect(order.lines.single.qty, 2);
    expect(order.lines.single.total, 20);
    expect(store.tabSubtotal(table.id), 20);
    expect(store.chargeTotal(20, applyService: false), 20);
    expect(store.chargeTotal(20, applyService: true), closeTo(22, 0.001));
  });

  test('cashier cannot skip a new order straight to ready, and a bill request stays open', () async {
    final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
    store.tables = [table];
    store.orders = [
      CafeOrder(
        id: 'order-1',
        tableId: table.id,
        tableNumber: table.number,
        status: OrderStatus.received,
        createdAt: DateTime.utc(2026, 9, 28),
        lines: [OrderLine(menuItemId: 'wine', name: 'red wine', qty: 1, unitPrice: 10)],
      ),
    ];
    store.setOrderStatus('order-1', OrderStatus.ready);
    expect(store.orders.single.status, OrderStatus.received);
    store.setOrderStatus('order-1', OrderStatus.preparing);
    expect(store.orders.single.status, OrderStatus.preparing);
    store.setOrderStatus('order-1', OrderStatus.ready);
    expect(store.orders.single.status, OrderStatus.ready);
    store.setOrderStatus('order-1', OrderStatus.served);
    expect(store.orders.single.status, OrderStatus.served);

    // A bill can be asked for once the order is served; asking does not change
    // the kitchen status.
    expect(await store.requestBill(table.id), isNull);
    expect(store.openOrderFor(table.id)!.status, OrderStatus.served);
    expect(store.tables.single.status, TableStatus.billRequested);
    expect(store.openCalls.where((call) => call.kind == 'bill'), isNotEmpty);
    expect(store.payments, isEmpty);
  });

  test('a second kitchen send while the first is in flight does not double the item', () async {
    final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
    store.tables = [table];
    store.menuItems = [
      MenuItem(id: 'wine', nameIt: 'red wine', nameEn: 'red wine', price: 10, categoryId: 'c'),
    ];
    store.addToCart(table.id, store.menuItems.single);
    expect(store.tryBeginOrderConfirm(table.id), isTrue);
    expect(store.tryBeginOrderConfirm(table.id), isFalse);
    store.endOrderConfirm(table.id);

    final first = store.sendCartToKitchen(table.id);
    final second = store.sendCartToKitchen(table.id);
    expect(store.tryBeginOrderConfirm(table.id), isFalse);
    await first;
    await second;
    final order = store.openOrderFor(table.id)!;
    expect(order.lines, hasLength(1));
    expect(order.lines.single.qty, 1);
    expect(order.lines.single.total, 10);
    expect(store.cartFor(table.id).lines, isEmpty);
  });

  test('two tables can request the bill without dropping either notice', () async {
    final first = CafeTable(id: 'a', number: '1', qrSlug: 'a');
    final second = CafeTable(id: 'b', number: '2', qrSlug: 'b');
    store.tables = [first, second];
    store.orders = [
      for (final table in [first, second])
        CafeOrder(
          id: 'order-${table.id}',
          tableId: table.id,
          tableNumber: table.number,
          status: OrderStatus.served,
          createdAt: DateTime.utc(2026, 9, 28),
          lines: [OrderLine(menuItemId: 'wine', name: 'red wine', qty: 1, unitPrice: 10)],
        ),
    ];
    await store.requestBill(first.id);
    await store.requestBill(second.id);
    await store.requestBill(first.id);
    final bills = store.openCalls.where((call) => call.kind == 'bill' && !call.resolved).toList();
    expect(bills.map((call) => call.tableId).toSet(), {'a', 'b'});
    expect(store.billTables.map((table) => table.id).toSet(), {'a', 'b'});
    expect(store.payments, isEmpty);
  });

  test('the bill charges only what was sent to the kitchen', () {
    final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
    store.tables = [table];
    store.menuItems = [
      MenuItem(id: 'wine', nameIt: 'red wine', nameEn: 'red wine', price: 10, categoryId: 'c'),
      MenuItem(id: 'bread', nameIt: 'bread', nameEn: 'bread', price: 4, categoryId: 'c'),
    ];
    store.orders = [
      CafeOrder(
        id: 'order-1',
        tableId: table.id,
        tableNumber: table.number,
        status: OrderStatus.served,
        createdAt: DateTime.utc(2026, 9, 28),
        lines: [OrderLine(menuItemId: 'wine', name: 'red wine', qty: 2, unitPrice: 10)],
      ),
    ];
    store.addToCart(table.id, store.menuItems.last);
    expect(store.cartFor(table.id).total, 4);
    expect(store.tabSubtotal(table.id), 20);
    expect(store.tabTotal(table.id, applyService: false), 20);
  });

  test('one dish stops at the most a single send may carry', () {
    final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
    store.tables = [table];
    store.menuItems = [
      MenuItem(id: 'wine', nameIt: 'red wine', nameEn: 'red wine', price: 10, categoryId: 'c'),
    ];
    for (var i = 0; i < CafeStoreOrders.maxDishQty + 5; i++) {
      store.addToCart(table.id, store.menuItems.single);
    }
    expect(store.cartFor(table.id).lines.single.qty, CafeStoreOrders.maxDishQty);
    store.setCartQty(table.id, 'wine', 500);
    expect(store.cartFor(table.id).lines.single.qty, CafeStoreOrders.maxDishQty);
  });

  test('a status change that skips a kitchen step is ignored', () async {
    final table = CafeTable(id: 't1', number: '1', qrSlug: 't1');
    store.tables = [table];
    store.orders = [
      CafeOrder(
        id: 'order-1',
        tableId: table.id,
        tableNumber: table.number,
        status: OrderStatus.received,
        createdAt: DateTime.utc(2026, 9, 28),
        lines: [OrderLine(menuItemId: 'wine', name: 'red wine', qty: 1, unitPrice: 10)],
      ),
    ];
    expect(await store.setOrderStatus('order-1', OrderStatus.served), isNull);
    expect(store.orders.single.status, OrderStatus.received);
    expect(await store.setOrderStatus('order-1', OrderStatus.preparing), isNull);
    expect(store.orders.single.status, OrderStatus.preparing);
  });

  test('a sent line keeps its database id and a cart line has none', () {
    final sent = OrderLine.fromJson({'id': 'line-1', 'menuItemId': 'wine', 'name': 'red wine', 'qty': 1, 'unitPrice': 10});
    expect(sent.id, 'line-1');
    expect(OrderLine.fromJson(sent.toJson()).id, 'line-1');
    final cart = OrderLine(menuItemId: 'wine', name: 'red wine', qty: 1, unitPrice: 10);
    expect(cart.id, isNull);
    expect(cart.toJson().containsKey('id'), isFalse);
  });

  test('first launch is empty with no demo data', () {
    expect(store.hasAdmin, isFalse);
    expect(store.cashiers, isEmpty);
    expect(store.tables, isEmpty);
    expect(store.menuItems, isEmpty);
    expect(store.categories, isEmpty);
    expect(store.orders, isEmpty);
  });

  test('admin setup, cashier PIN, guest order, cash settle', () async {
    if (skipLive) return;
    expect(
      await store.createAdmin(
        email: 'admin@cafeitaliano.com',
        password: 'Cafe123!',
        confirm: 'Cafe123!',
      ),
      isNull,
    );
    expect(store.hasAdmin, isTrue);
    expect(store.authKind, AuthKind.admin);

    await store.addCashier(name: 'Lina Rossi', pin: '1234');
    await store.addTable('12');
    await store.addCategory('Primi', 'Primi');
    await store.saveMenuItem(
      MenuItem(
        id: 'dish-1',
        nameIt: 'Pappardelle',
        nameEn: 'Pappardelle',
        price: 18,
        categoryId: store.categories.first.id,
      ),
    );

    store.signOut();
    store.selectCashier(store.cashiers.first.id);
    store.enterPinDigit('1');
    store.enterPinDigit('2');
    store.enterPinDigit('3');
    store.enterPinDigit('4');
    expect(await store.signInCashier(), isTrue);

    final table = store.tables.first;
    final dish = store.menuItems.first;
    store.addToCart(table.id, dish);
    store.addToCart(table.id, dish);
    store.addToCart(table.id, dish);
    expect(store.cartFor(table.id).lines.single.total, 54);
    await store.sendCartToKitchen(table.id);
    await store.requestBill(table.id);
    expect(store.openOrderFor(table.id)!.lines.single.qty, 3);
    expect(store.openOrderFor(table.id)!.subtotal, 54);

    final due = store.tabTotal(table.id);
    expect(due, closeTo(59.4, 0.01));
    expect(await store.settleCash(tableId: table.id, cashReceived: 10), isNotNull);
    expect(await store.settleCash(tableId: table.id, cashReceived: 60), isNull);
    expect(store.tables.first.status, TableStatus.free);
    expect(store.openOrderFor(table.id), isNull);
    expect(store.cartFor(table.id).lines, isEmpty);
    expect(store.currentShift!.expectedCash, closeTo(59.4, 0.01));
  });

  test('supabase keeps admin after a fresh load', () async {
    if (skipLive) return;
    expect(
      await store.createAdmin(
        email: 'admin@cafeitaliano.com',
        password: 'Cafe123!',
        confirm: 'Cafe123!',
      ),
      isNull,
    );
    final again = CafeStore(AppDatabase.instance);
    await again.load();
    expect(again.hasAdmin, isTrue);
    expect(again.admin?.email, 'admin@cafeitaliano.com');
  });

  test('hidden categories stay off the guest menu', () async {
    if (skipLive) return;
    await store.addCategory('Hidden', 'مخفي');
    await store.saveMenuItem(
      MenuItem(
        id: 'dish-hidden',
        nameIt: 'Hidden Dish',
        nameEn: 'Hidden Dish',
        price: 10,
        categoryId: store.categories.first.id,
      ),
    );
    await store.saveCategory(store.categories.first..visible = false);
    expect(store.guestCategories, isEmpty);
    expect(store.liveMenu, isEmpty);
  });
}
