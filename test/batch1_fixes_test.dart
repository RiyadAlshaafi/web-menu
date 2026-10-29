import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/money.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/receipt_print.dart';
import 'package:menu_web_v1/printing/slip.dart';
import 'package:menu_web_v1/screens/admin_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final db = AppDatabase.instance;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory appData;

  setUpAll(() {
    appData = Directory.systemTemp.createTempSync('batch1_fixes_test');
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

  group('receipt after a partial refund', () {
    test('keeps the paid total and service, then shows Refunded and Net paid', () {
      final store = CafeStore(db);
      store.cafe = {'name': 'Cafe', 'serviceChargeRate': 0.10};
      store.locale = 'en';
      final l10n = lookupAppLocalizations(const Locale('en'));
      store.orders.add(CafeOrder(
        id: 'o1',
        tableId: 't1',
        tableNumber: '4',
        status: OrderStatus.paid,
        createdAt: DateTime.utc(2026, 10, 29, 10),
        serviceType: 'dine_in',
        lines: [OrderLine(menuItemId: 'latte', name: 'Latte', qty: 4, unitPrice: 25)],
      ));
      final payment = Payment(
        id: 'p1',
        orderId: 'o1',
        tableId: 't1',
        totalDue: 110,
        cashReceived: 110,
        changeDue: 0,
        cashierId: 'c1',
        shiftId: 's1',
        paidAt: DateTime.utc(2026, 10, 29, 10),
        refunds: [
          PaymentRefund(
            lineKey: 'k',
            menuItemId: 'latte',
            name: 'Latte',
            qty: 1,
            amount: 30,
            reason: 'cold',
            at: DateTime.utc(2026, 10, 29, 11),
          ),
        ],
      );

      final data = ReceiptData.ofSale(store, payment);
      expect(data.subtotal, 100);
      expect(data.service, closeTo(10, 0.001), reason: 'the service charge must not turn negative');
      expect(data.total, 110, reason: 'the total matches the lines it sits under');
      expect(data.refunded, 30);

      final pairs = receiptSlip(store, data, l10n).whereType<SlipPair>().map((p) => '${p.label}|${p.value}').toList();
      expect(pairs.where((p) => p.startsWith('Refunded|')).single, contains('-'));
      expect(pairs.where((p) => p.startsWith('Net paid|')).single, contains('80'));
    });
  });

  group('typed cash amounts', () {
    test('accept Arabic digits and commas, and refuse blanks and mistakes', () {
      expect(parseMoneyInput('125.5'), 125.5);
      expect(parseMoneyInput(' 125,5 '), 125.5);
      expect(parseMoneyInput('١٢٥٫٥'), 125.5);
      expect(parseMoneyInput('0'), 0);
      expect(parseMoneyInput(''), isNull);
      expect(parseMoneyInput('12a'), isNull);
      expect(parseMoneyInput('-5'), isNull);
    });
  });

  group('offline admin sign-in', () {
    late LocalStateStore local;
    setUp(() async {
      local = openMemoryLocalStateStore();
      await db.initLocal(local);
      db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      db.signOutLocalAdmin();
    });
    tearDown(() => db.closeLocal());

    bool tryWrong() => db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'wrong', remember: false);

    test('locks after 5 wrong passwords, and then even the right one is refused', () {
      for (var i = 0; i < 4; i++) {
        expect(tryWrong(), isFalse);
      }
      expect(db.localAdminLockedFor, isNull, reason: '4 slips do not lock');
      expect(tryWrong(), isFalse);
      expect(db.localAdminLockedFor, isNotNull);
      expect(db.localAdminLockedFor!.inSeconds, inInclusiveRange(55, 60));
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123', remember: false), isFalse);
    });

    test('a wrong email counts as a wrong try too', () {
      for (var i = 0; i < 5; i++) {
        expect(db.signInLocalAdmin(email: 'guess@cafe.ly', password: 'Secret#123', remember: false), isFalse);
      }
      expect(db.localAdminLockedFor, isNotNull);
    });

    test('the right password clears the count of wrong tries', () {
      for (var i = 0; i < 4; i++) {
        tryWrong();
      }
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123', remember: false), isTrue);
      db.signOutLocalAdmin();
      tryWrong();
      expect(db.localAdminLockedFor, isNull, reason: 'the count started again from 0');
    });

    test('"remember me" survives a restart, but not once it has run out', () async {
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123', remember: true), isTrue);
      await db.initLocal(local);
      expect(db.rememberAdmin, isTrue);
      expect(db.admin, isNotNull);

      final doc = Map<String, dynamic>.from(local.readDoc('admin')! as Map);
      local.writeDoc('admin', {...doc, 'rememberUntil': DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String()});
      await db.initLocal(local);
      expect(db.rememberAdmin, isFalse);
      expect(db.admin, isNull);
    });

    test('an old save that remembers forever asks for the password once', () async {
      final doc = Map<String, dynamic>.from(local.readDoc('admin')! as Map);
      local.writeDoc('admin', {...doc, 'remember': true}..remove('rememberUntil'));
      await db.initLocal(local);
      expect(db.admin, isNull);
    });
  });

  testWidgets('the offline admin console signs out after the idle time, and a touch resets it', (tester) async {
    final store = (await tester.runAsync(() async {
      final store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
      store.locale = 'en';
      expect(await store.createAdmin(email: 'owner@cafe.ly', password: 'Secret#123', confirm: 'Secret#123'), isNull);
      return store;
    }))!;
    addTearDown(db.closeLocal);
    expect(store.authKind, AuthKind.admin);
    await pumpAdminScreen(
      tester,
      const AdminIdleLock(timeout: Duration(seconds: 30), child: SizedBox.expand(child: Text('console'))),
      store,
    );

    await tester.pump(const Duration(seconds: 20));
    await tester.tap(find.text('console'));
    await tester.pump(const Duration(seconds: 20));
    expect(store.authKind, AuthKind.admin, reason: 'the touch restarted the clock');

    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(store.authKind, AuthKind.none);
    expect(find.text('page /admin/login'), findsOneWidget);
    expect(store.adminError, contains('without use'));
  });
}
