import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/main.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows admin setup', (tester) async {
    if (String.fromEnvironment('SUPABASE_URL') == '') return;
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await AppDatabase.instance.resetEmpty();
    final store = CafeStore(AppDatabase.instance);
    await store.load();
    await tester.pumpWidget(TawlaApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Create Admin Access'), findsOneWidget);
    expect(find.text('Café Italiano'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'admin@cafeitaliano.com');
    await tester.enterText(find.byType(TextField).at(1), 'Cafe123!');
    await tester.enterText(find.byType(TextField).at(2), 'Cafe123!');
    await tester.tap(find.text('Create Access  →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(store.hasAdmin, isTrue);
    expect(find.text('Menu Layout & Display Editor'), findsOneWidget);
    expect(find.text('All Sections (0)'), findsOneWidget);
    expect(find.text('Menu Catalog &\nLayout'), findsWidgets);
  });

  testWidgets('staff POS shows empty cashier state', (tester) async {
    if (String.fromEnvironment('SUPABASE_URL') == '') return;
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await AppDatabase.instance.resetEmpty();
    final store = CafeStore(AppDatabase.instance);
    await store.load();
    await tester.pumpWidget(TawlaApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Staff POS  →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Cashier Sign In'), findsOneWidget);
    expect(find.text('No cashiers have been created yet.'), findsOneWidget);
  });

  testWidgets('adding a dish without a photo does not crash', (tester) async {
    if (String.fromEnvironment('SUPABASE_URL') == '') return;
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await AppDatabase.instance.resetEmpty();
    final store = CafeStore(AppDatabase.instance);
    await store.load();
    await tester.pumpWidget(TawlaApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).at(0), 'admin@cafeitaliano.com');
    await tester.enterText(find.byType(TextField).at(1), 'Cafe123!');
    await tester.enterText(find.byType(TextField).at(2), 'Cafe123!');
    await tester.tap(find.text('Create Access  →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await store.addCategory('Pizze', 'Pizze');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('+ Add Dish').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dialogFields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(dialogFields.at(0), 'Margherita');
    await tester.enterText(dialogFields.at(1), '12');
    await tester.tap(find.text('Save & Add Dish'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
    expect(store.menuItems.where((item) => item.nameIt == 'Margherita'), isNotEmpty);
    expect(find.text('Add New Dish'), findsNothing);
    expect(find.text('Margherita'), findsWidgets);
  });
}
