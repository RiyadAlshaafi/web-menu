import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/cashier_screens.dart';
import 'package:menu_web_v1/screens/dish_availability_screen.dart';
import 'package:menu_web_v1/screens/sales_log_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';
import 'package:provider/provider.dart';

final db = AppDatabase.instance;

/// Till screens from a small 800x480 touch panel up to a full-HD monitor.
const sizes = [
  Size(800, 480),
  Size(800, 600),
  Size(1024, 600),
  Size(1024, 768),
  Size(1280, 800),
  Size(1366, 768),
  Size(1920, 1080),
];

const busyTableId = 't1';

/// Every cashier page, by the path the app opens it at.
const pages = ['/pos/takeout', '/pos', '/pos/tables', '/pos/tables/$busyTableId', '/pos/dishes', '/pos/log', '/pos/shifts'];

/// The default test font draws every glyph as a wide square, which overflows rows the real font
/// fits. Load the fonts the app ships instead.
Future<void> loadAppFonts() async {
  const families = {
    'PlusJakartaSans': ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'],
    'NotoNaskhArabic': ['Regular', 'Bold'],
  };
  for (final MapEntry(key: family, value: weights) in families.entries) {
    final loader = FontLoader(family);
    for (final weight in weights) {
      final bytes = File('assets/fonts/$family-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// A busy cafe: long dish names in both languages, a long cashier name, 12 tables and an open
/// order on table 1.
Future<CafeStore> seedBusyCafe(String locale) async {
  db.closeLocal();
  final store = CafeStore(db);
  await store.load(localStore: openMemoryLocalStateStore());

  final category = MenuCategory(id: 'mains', nameEn: 'Signature Main Courses and Sharing Plates', nameAr: 'الأطباق الرئيسية المميزة وأطباق المشاركة');
  await db.writeCategories([category], changed: [category]);
  final dishes = [
    for (var i = 1; i <= 10; i++)
      MenuItem(
        id: 'dish-$i',
        nameIt: 'طبق الدجاج المشوي بالأعشاب مع صلصة الليمون والثوم رقم $i',
        nameEn: 'Slow-Roasted Herb Chicken with Lemon Garlic Butter Sauce No. $i',
        description: locale == 'en'
            ? 'Free-range chicken, rosemary, thyme and crispy golden potatoes'
            : 'دجاج بلدي مع إكليل الجبل والزعتر وبطاطس ذهبية مقرمشة',
        price: 1234.5 + i,
        categoryId: category.id,
      ),
  ];
  await db.writeMenuItems(dishes, changed: dishes);
  final tables = [for (var i = 1; i <= 12; i++) CafeTable(id: 't$i', number: '$i', qrSlug: 'slug-$i', zone: 'Garden Terrace')];
  await db.writeTables(tables, changed: tables);
  await db.writeCarts({
    busyTableId: CartState(tableId: busyTableId, lines: [
      for (final dish in dishes.take(6)) OrderLine(menuItemId: dish.id, name: dish.displayName(locale), qty: 3, unitPrice: dish.price),
    ]),
  });
  expect(await db.sendTableCart(busyTableId), isNull);

  await store.addCashier(name: 'Maximilian Alexander Abdulrahman Al-Khatib', pin: '1234');
  await store.syncFromDisk();
  store.selectCashier(store.cashiers.first.id);
  for (final digit in ['1', '2', '3', '4']) {
    store.enterPinDigit(digit);
  }
  expect(await store.signInCashier(), isTrue, reason: store.loginError);
  store.locale = locale;
  return store;
}

Widget posApp(CafeStore store, String location) {
  return ChangeNotifierProvider<CafeStore>.value(
    value: store,
    child: MaterialApp.router(
      theme: CafeTheme.light,
      locale: Locale(store.locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(initialLocation: location, routes: [
        ShellRoute(
          builder: (_, state, child) => CashierShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/pos/takeout', builder: (_, _) => const QuickTakeoutScreen()),
            GoRoute(path: '/pos', builder: (_, _) => const CashierDashboardScreen()),
            GoRoute(path: '/pos/tables', builder: (_, _) => const CashierFloorScreen()),
            GoRoute(path: '/pos/tables/:id', builder: (_, state) => TableOrderScreen(tableId: state.pathParameters['id']!)),
            GoRoute(path: '/pos/dishes', builder: (_, _) => const DishAvailabilityScreen()),
            GoRoute(path: '/pos/log', builder: (_, _) => const SalesLogScreen(ownSalesOnly: true)),
            GoRoute(path: '/pos/shifts', builder: (_, _) => const CashierShiftsScreen()),
          ],
        ),
        GoRoute(path: '/:rest(.*)', builder: (_, state) => Text('page ${state.uri}')),
      ]),
    ),
  );
}

/// Every error thrown while drawing, so the test names the page and size that broke.
List<String> takeErrors(WidgetTester tester) {
  final errors = <String>[];
  for (Object? error = tester.takeException(); error != null; error = tester.takeException()) {
    errors.add(error.toString().split('\n').take(3).join(' '));
  }
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory appData;

  setUpAll(() async {
    await loadAppFonts();
    appData = Directory.systemTemp.createTempSync('pos_screen_sizes_test');
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

  for (final locale in ['en', 'ar']) {
    testWidgets('every POS page fits every till size in $locale', (tester) async {
      final store = (await tester.runAsync(() => seedBusyCafe(locale)))!;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failures = <String>[];
      for (final size in sizes) {
        tester.view.physicalSize = size;
        for (final page in pages) {
          await tester.pumpWidget(posApp(store, page), duration: Duration.zero);
          // The cashier pages keep timers running, so pump a fixed time instead of settling.
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          for (final error in takeErrors(tester)) {
            failures.add('$locale ${size.width.toInt()}x${size.height.toInt()} $page: $error');
          }
          // A fresh router per page: drop the old tree so its state does not carry over.
          await tester.pumpWidget(const SizedBox());
          takeErrors(tester);
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
