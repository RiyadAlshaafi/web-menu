import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/navigation/app_sections.dart';
import 'package:menu_web_v1/screens/auth_screens.dart';
import 'package:menu_web_v1/screens/cashier_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory appData;

  setUpAll(() {
    appData = Directory.systemTemp.createTempSync('touch_screen_test');
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

  test('the theme keeps touch sizes on Windows tills', () {
    expect(CafeTheme.light.visualDensity, VisualDensity.standard);
    expect(CafeTheme.light.materialTapTargetSize, MaterialTapTargetSize.padded);
  });

  test('a 1024px till gets the icon-only menu so dishes and Pay stay side by side', () {
    expect(AppSections.compact(1024), isTrue);
    expect(AppSections.compact(1280), isFalse);
  });

  testWidgets('the PIN screen shows every cashier, not only the first three', (tester) async {
    final store = (await tester.runAsync(() async {
      db.closeLocal();
      final store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
      for (final name in ['Sara', 'Omar', 'Lina', 'Karim', 'Huda']) {
        await store.addCashier(name: name, pin: '1234');
      }
      store.locale = 'en';
      return store;
    }))!;
    await pumpAdminScreen(tester, const PinLoginScreen(), store);
    await settle(tester);

    for (final name in ['Sara', 'Omar', 'Lina', 'Karim', 'Huda']) {
      expect(find.text(name), findsOneWidget, reason: '$name needs a tile to sign in');
    }
    await tester.tap(find.text('Huda'));
    await settle(tester);
    expect(store.selectedCashierId, store.cashiers.firstWhere((c) => c.name == 'Huda').id);
  });

  testWidgets('Refuse asks first, and Cancel keeps the item', (tester) async {
    final store = (await tester.runAsync(() async {
      db.closeLocal();
      final store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
      final table = CafeTable(id: 't4', number: '4', qrSlug: 'slug-4');
      await db.writeTables([table], changed: [table]);
      final dish = MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7.5, categoryId: 'drinks');
      await db.writeMenuItems([dish], changed: [dish]);
      await db.writeCarts({
        't4': CartState(tableId: 't4', lines: [OrderLine(menuItemId: dish.id, name: 'Latte', qty: 2, unitPrice: 7.5)]),
      });
      expect(await db.sendTableCart('t4'), isNull);
      await store.syncFromDisk();
      store.locale = 'en';
      return store;
    }))!;
    await pumpAdminScreen(tester, const CashierFloorScreen(), store);
    await settle(tester);

    await tester.tap(find.text('View cart'));
    await settle(tester);
    await tester.tap(find.text('Refuse'));
    await settle(tester);
    expect(find.text('Refuse Latte?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Refuse Latte?'), findsNothing);
    expect(db.orders.single.lines, hasLength(1), reason: 'Cancel refuses nothing');
  });
}
