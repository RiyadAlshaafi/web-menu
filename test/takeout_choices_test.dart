import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/features/app_feature.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_brand_settings.dart';
import 'package:menu_web_v1/screens/cashier_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

/// The cashier screens keep timers running, so frames are pumped for a fixed time instead of
/// waiting for them to settle.
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  ignoreOverflow(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory appData;

  setUpAll(() {
    appData = Directory.systemTemp.createTempSync('takeout_choices_test');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => appData.path);
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

  Future<CafeStore> storeWithBurger() async {
    await AppDatabase.instance.resetEmpty();
    final store = CafeStore(AppDatabase.instance);
    await store.load();
    store.locale = 'en';
    store.categories = [MenuCategory(id: 'c', nameEn: 'Food', nameAr: 'طعام')];
    store.menuItems = [
      MenuItem(
        id: 'burger',
        nameIt: 'برجر',
        nameEn: 'Burger',
        price: 10,
        categoryId: 'c',
        options: const [
          DishOption(id: 'onion', kind: DishOption.ingredient, nameAr: 'بصل', nameEn: 'Onion', defaultOn: true),
          DishOption(id: 'cheese', kind: DishOption.topping, nameAr: 'جبنة', nameEn: 'Extra cheese', price: 1.5),
        ],
      ),
    ];
    return store;
  }

  testWidgets('the classic takeout layout shows every dish at once, the cards layout only categories', (tester) async {
    final store = (await tester.runAsync(storeWithBurger))!;
    store.cafe = {...store.cafe, 'takeoutLayout': 'classic'};
    await pumpAdminScreen(tester, const QuickTakeoutScreen(), store);
    expect(find.text('Burger'), findsOneWidget, reason: 'classic lists the dish straight away');

    store.cafe = {...store.cafe, 'takeoutLayout': 'cards'};
    await pumpAdminScreen(tester, const QuickTakeoutScreen(), store);
    expect(find.text('Burger'), findsNothing, reason: 'cards show categories first');
    expect(store.takeoutCards, isTrue);
  });

  testWidgets('the takeout screen choice is kept only after Save is pressed', (tester) async {
    final store = (await tester.runAsync(storeWithBurger))!;
    await pumpAdminScreen(tester, const TakeoutLayoutCard(), store);
    expect(store.takeoutCards, isTrue);

    await tester.tap(find.text('Classic'));
    await tester.pump();
    expect(store.takeoutCards, isTrue, reason: 'picking alone changes nothing');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(store.takeoutCards, isFalse);
  });

  testWidgets('tapping the ticket line opens the choices and the extra is charged', (tester) async {
    final store = (await tester.runAsync(storeWithBurger))!;
    await pumpAdminScreen(tester, const QuickTakeoutScreen(), store);
    // The counter opens on category cards; open the one holding the burger.
    await tapAndWait(tester, find.text('Food').last);
    await tapAndWait(tester, find.text('Burger').first);
    await tapAndWait(tester, find.descendant(of: find.byType(TicketLineName), matching: find.byIcon(Icons.tune)));
    expect(find.text('Extra cheese'), findsOneWidget);
    await tapAndWait(tester, find.text('Extra cheese'));
    await tapAndWait(tester, find.textContaining('Apply'));
    expect(find.textContaining('+ Extra cheese'), findsOneWidget);
    expect(find.textContaining('11.5'), findsWidgets);
  });

  testWidgets('holding a dish for a second opens its choices; a short tap just adds it', (tester) async {
    final store = (await tester.runAsync(storeWithBurger))!;
    await pumpAdminScreen(tester, const QuickTakeoutScreen(), store);
    // The counter opens on category cards; open the one holding the burger.
    await tapAndWait(tester, find.text('Food').last);

    // A press shorter than a second is an ordinary tap: the dish goes on the ticket as it comes.
    final quick = await tester.startGesture(tester.getCenter(find.text('Burger').first));
    await tester.pump(const Duration(milliseconds: 600));
    await quick.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.textContaining('10.000'), findsWidgets);

    // Holding for a second opens the choices; the chosen dish is a second ticket line.
    final hold = await tester.startGesture(tester.getCenter(find.text('Burger').first));
    await tester.pump(const Duration(milliseconds: 1100));
    await hold.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    ignoreOverflow(tester);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tapAndWait(tester, find.text('Extra cheese'));
    await tapAndWait(tester, find.textContaining('Apply'));
    expect(find.textContaining('+ Extra cheese'), findsOneWidget);
    expect(find.textContaining('21.500'), findsWidgets);
  });

  testWidgets('with the dish choices feature off, holding a dish and the ticket line have no choices', (tester) async {
    final store = (await tester.runAsync(storeWithBurger))!;
    store.features = FeatureSet.fromKeys(const ['tables']);
    await pumpAdminScreen(tester, const QuickTakeoutScreen(), store);
    // The counter opens on category cards; open the one holding the burger.
    await tapAndWait(tester, find.text('Food').last);

    final hold = await tester.startGesture(tester.getCenter(find.text('Burger').first));
    await tester.pump(const Duration(milliseconds: 1100));
    await hold.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    ignoreOverflow(tester);
    expect(find.byType(CheckboxListTile), findsNothing, reason: 'no choices sheet');
    expect(find.descendant(of: find.byType(TicketLineName), matching: find.byIcon(Icons.tune)), findsNothing);
    expect(store.hasChoices(store.menuItems.single), isFalse);
  });
}
