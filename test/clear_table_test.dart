import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/models/models.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory appData;

  setUpAll(() {
    appData = Directory.systemTemp.createTempSync('clear_table_test');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => appData.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {
        'appName': 'Cafe POS',
        'packageName': 'cafe_pos',
        'version': '1.0.0',
        'buildNumber': '1',
      },
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

  /// Table 4 has an unpaid tab; table 5 is free.
  Future<CafeStore> storeWithOpenTab() async {
    db.closeLocal();
    final store = CafeStore(db);
    await store.load(localStore: openMemoryLocalStateStore());
    final busy = CafeTable(id: 't4', number: '4', qrSlug: 'slug-4');
    final free = CafeTable(id: 't5', number: '5', qrSlug: 'slug-5');
    await db.writeTables([busy, free], changed: [busy, free]);
    final dish = MenuItem(
      id: 'latte',
      nameIt: 'Latte',
      nameEn: 'Latte',
      price: 7.5,
      categoryId: 'drinks',
    );
    await db.writeMenuItems([dish], changed: [dish]);
    await db.writeCarts({
      't4': CartState(
        tableId: 't4',
        lines: [
          OrderLine(menuItemId: dish.id, name: 'Latte', qty: 2, unitPrice: 7.5),
        ],
      ),
    });
    expect(await db.sendTableCart('t4'), isNull);
    await store.syncFromDisk();
    store.locale = 'en';
    return store;
  }

  testWidgets(
    'a free table has no clear button; an occupied one asks "are you sure?" and Cancel changes nothing',
    (tester) async {
      final store = (await tester.runAsync(storeWithOpenTab))!;
      await pumpAdminScreen(tester, const CashierFloorScreen(), store);
      await settle(tester);

      expect(find.byKey(const Key('clear-table-t5')), findsNothing);
      expect(find.byKey(const Key('clear-table-t4')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear-table-t4')));
      await settle(tester);
      expect(find.text('Clear table 4?'), findsOneWidget);
      expect(find.textContaining('Are you sure?'), findsOneWidget);
      expect(
        db.orders,
        hasLength(1),
        reason: 'nothing is cleared before the answer',
      );

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Clear table 4?'), findsNothing);
      expect(db.orders, hasLength(1));
      expect(
        db.tables.firstWhere((t) => t.id == 't4').status,
        TableStatus.dining,
      );
    },
  );

  testWidgets('confirming cancels the unpaid tab and frees the table', (
    tester,
  ) async {
    final store = (await tester.runAsync(storeWithOpenTab))!;
    await pumpAdminScreen(tester, const CashierFloorScreen(), store);
    await settle(tester);

    await tester.tap(find.byKey(const Key('clear-table-t4')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-clear-table')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);

    expect(db.orders.where((o) => o.status != OrderStatus.paid), isEmpty);
    expect(db.tables.firstWhere((t) => t.id == 't4').status, TableStatus.free);
    expect(find.text('Table 4 is clear'), findsOneWidget);
    expect(
      find.byKey(const Key('clear-table-t4')),
      findsNothing,
      reason: 'a freed table needs no clear button',
    );
  });
}
