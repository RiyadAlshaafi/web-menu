import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/data/local_state_store_io.dart' show SqliteLocalStateStore, localDatabaseFileName;
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:path/path.dart' as p;

final db = AppDatabase.instance;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CafeStore store;

  /// Pizza and Drinks categories, one dish each, saved to the local database.
  Future<void> menu() async {
    final pizza = MenuCategory(id: 'pizza', nameEn: 'Pizza', nameAr: 'بيتزا', sortOrder: 1);
    final drinks = MenuCategory(id: 'drinks', nameEn: 'Drinks', nameAr: 'مشروبات', sortOrder: 2);
    final dishes = [
      MenuItem(id: 'margherita', nameIt: 'Margherita', nameEn: 'Margherita', price: 20, categoryId: 'pizza'),
      MenuItem(id: 'juice', nameIt: 'Juice', nameEn: 'Juice', price: 5, categoryId: 'drinks'),
    ];
    await db.writeCategories([pizza, drinks], changed: [pizza, drinks]);
    await db.writeMenuItems(dishes, changed: dishes);
    store
      ..categories = db.categories
      ..menuItems = db.menuItems
      ..kitchens = db.kitchens;
  }

  Kitchen named(String name) => store.kitchens.singleWhere((item) => item.name == name);

  setUp(() async {
    await db.initLocal(openMemoryLocalStateStore());
    store = CafeStore(db);
    await menu();
  });
  tearDown(() => db.closeLocal());

  test('a cafe with no kitchens sends every dish to no kitchen (the one kitchen printer)', () {
    expect(store.kitchenFor('margherita'), isNull);
    expect(store.kitchenFor('juice'), isNull);
  });

  test('each dish goes to the kitchen of its category', () async {
    await store.saveKitchen(name: 'Pizza oven', categoryIds: {'pizza'});
    await store.saveKitchen(name: 'Bar', categoryIds: {'drinks'});

    expect(store.kitchenFor('margherita')?.name, 'Pizza oven');
    expect(store.kitchenFor('juice')?.name, 'Bar');
  });

  test('a category with no kitchen, or a typed-in dish, goes to the first kitchen', () async {
    await store.saveKitchen(name: 'Main', categoryIds: {});
    await store.saveKitchen(name: 'Bar', categoryIds: {'drinks'});

    expect(store.kitchenFor('margherita')?.name, 'Main');
    expect(store.kitchenFor('not-on-menu')?.name, 'Main');
  });

  test('ticking a category in a second kitchen moves it there', () async {
    await store.saveKitchen(name: 'Pizza oven', categoryIds: {'pizza', 'drinks'});
    await store.saveKitchen(name: 'Bar', categoryIds: {'drinks'});

    expect(store.categoryIdsOf(named('Pizza oven').id), {'pizza'});
    expect(store.categoryIdsOf(named('Bar').id), {'drinks'});
  });

  test('editing a kitchen renames it and unticked categories leave it', () async {
    await store.saveKitchen(name: 'Pizza', categoryIds: {'pizza', 'drinks'});
    final id = named('Pizza').id;

    await store.saveKitchen(kitchenId: id, name: 'Pizza oven', categoryIds: {'pizza'});

    expect(store.kitchens.single.name, 'Pizza oven');
    expect(store.categoryIdsOf(id), {'pizza'});
    expect(store.categories.singleWhere((item) => item.id == 'drinks').kitchenId, isNull);
  });

  test('deleting a kitchen frees its categories', () async {
    await store.saveKitchen(name: 'Main', categoryIds: {'pizza'});
    await store.saveKitchen(name: 'Bar', categoryIds: {'drinks'});

    await store.deleteKitchen(named('Bar').id);

    expect(store.kitchens.map((item) => item.name), ['Main']);
    expect(store.categories.singleWhere((item) => item.id == 'drinks').kitchenId, isNull);
    expect(store.kitchenFor('juice')?.name, 'Main');
  });

  group('saved on this PC', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kitchens_db'));
    tearDown(() {
      db.closeLocal();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold the file for a moment; the temp folder is cleaned later.
      }
    });

    test('kitchens and their categories come back after the app restarts', () async {
      final path = p.join(dir.path, localDatabaseFileName);
      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));
      await menu();
      await store.saveKitchen(name: 'Bar', categoryIds: {'drinks'});

      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));

      expect(db.kitchens.single.name, 'Bar');
      expect(db.categories.singleWhere((item) => item.id == 'drinks').kitchenId, db.kitchens.single.id);
    });
  });

  test('the offline copy keeps kitchens and category links', () async {
    await store.saveKitchen(name: 'Bar', categoryIds: {'drinks'});
    final snapshot = db.offlineSnapshot();

    db.applyOfflineSnapshot(snapshot);

    expect(db.kitchens.single.name, 'Bar');
    expect(db.categories.singleWhere((item) => item.id == 'drinks').kitchenId, db.kitchens.single.id);
  });
}
