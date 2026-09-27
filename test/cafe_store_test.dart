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
    expect(AppDatabase.instance.isSqlite, isFalse);
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
