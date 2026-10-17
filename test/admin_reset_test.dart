import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:menu_web_v1/data/admin_reset.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/data/local_state_store_io.dart' show SqliteLocalStateStore, localDatabaseFileName;
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/auth_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/update/update_platform.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

final db = AppDatabase.instance;
const _nonce = '0123456789abcdef0123456789abcdef';

/// A ticket as the Windows setup writes it (windows/installer/cafe_pos.iss).
String _ticket({String nonce = _nonce, DateTime? issued, String? sig}) {
  final stamp = _setupStamp(issued ?? DateTime.now());
  return jsonEncode({'nonce': nonce, 'issued': stamp, 'sig': sig ?? adminResetSignature(nonce, stamp)});
}

/// The setup's GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':'), in local time.
String _setupStamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Stands in for admin_reset.json beside the exe.
class _FakeResetFile implements AdminResetFile {
  _FakeResetFile(this.text);
  String? text;

  @override
  Future<String?> read() async => text;

  @override
  Future<void> delete() async => text = null;
}

Future<void> _sell() async {
  final dish = MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7.5, categoryId: 'drinks');
  await db.writeMenuItems([dish], changed: [dish]);
  final sara = (await db.createCashier(name: 'Sara', pin: '1234', initials: 'S'))!;
  expect((await db.loginCashier(sara, '1234'))['ok'], isTrue);
  await db.writeShifts([CashShift(id: 'shift-1', cashierId: sara, openedAt: DateTime.now().toUtc(), openingCash: 0)]);
  await db.quickTakeoutReceipt(
    [OrderLine(menuItemId: dish.id, name: dish.nameEn, qty: 2, unitPrice: dish.price)],
    db.paymentTypes.first.id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reset ticket', () {
    final now = DateTime(2026, 10, 17, 12);
    AdminResetTicket? check(String? text, {Set<String> used = const {}}) =>
        AdminResetTicket.check(text, now: now, used: used);

    test('the signature is plain SHA-256 of key|nonce|issued, as the setup computes it', () {
      // Worked out with Python's hashlib, independently of the Dart code.
      expect(
        adminResetSignature(_nonce, '2026-10-17 10:00:00', key: 'tawla-offline-admin-reset-v1'),
        '9d656ced37a0e4ed7ebc7fee96e8482e4e77d8da4c8aa7e3ba28d7f77a179470',
      );
    });

    test('a fresh ticket from the setup is accepted', () {
      final ticket = check(_ticket(issued: now.subtract(const Duration(hours: 2))));
      expect(ticket?.nonce, _nonce);
      expect(ticket?.issuedAt, DateTime(2026, 10, 17, 10));
    });

    test('upper-case hex from the setup is accepted', () {
      final upper = _nonce.toUpperCase();
      final stamp = _setupStamp(now);
      final text = jsonEncode({'nonce': upper, 'issued': stamp, 'sig': adminResetSignature(upper, stamp).toUpperCase()});
      expect(check(text)?.nonce, _nonce);
    });

    test('a hand-written or edited ticket is refused', () {
      expect(check(_ticket(issued: now, sig: 'a' * 64)), isNull);
      final stamp = _setupStamp(now);
      final edited = jsonEncode({'nonce': _nonce, 'issued': stamp, 'sig': adminResetSignature(_nonce, '2026-10-16 12:00:00')});
      expect(check(edited), isNull, reason: 'moving the date breaks the signature');
      final otherKey = jsonEncode({'nonce': _nonce, 'issued': stamp, 'sig': adminResetSignature(_nonce, stamp, key: 'guess')});
      expect(check(otherKey), isNull);
    });

    test('an expired, future-dated or already used ticket is refused', () {
      expect(check(_ticket(issued: now.subtract(const Duration(hours: 24, minutes: 1)))), isNull);
      expect(check(_ticket(issued: now.add(const Duration(hours: 1)))), isNull);
      expect(check(_ticket(issued: now.add(const Duration(minutes: 2)))), isNotNull, reason: 'small clock skew is fine');
      expect(check(_ticket(issued: now), used: {_nonce}), isNull);
    });

    test('a missing or broken file is refused', () {
      expect(check(null), isNull);
      expect(check('not json'), isNull);
      expect(check('[]'), isNull);
      expect(check(jsonEncode({'nonce': _nonce})), isNull);
      expect(check(_ticket(nonce: 'short', issued: now)), isNull);
    });
  });

  group('local database reset', () {
    setUp(() async => db.initLocal(openMemoryLocalStateStore()));
    tearDown(() => db.closeLocal());

    test('sets a new password for the same admin; sales and settings stay', () async {
      db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      await db.writeCafe({...db.cafe, 'name': 'Tawla Test'});
      await _sell();

      expect(db.resetLocalAdminPassword(nonce: _nonce, next: 'Better#456'), isTrue);

      expect(db.localAdminEmail, 'owner@cafe.ly');
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123', remember: false), isFalse);
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Better#456', remember: false), isTrue);
      expect(db.cafe['name'], 'Tawla Test');
      expect(db.payments.single.totalDue, 15);
      expect(db.cashiers.single.name, 'Sara');
      expect(db.menuItems.single.nameEn, 'Latte');
    });

    test('a ticket works once, and only when there is an admin', () {
      expect(db.resetLocalAdminPassword(nonce: _nonce, next: 'Better#456'), isFalse);
      db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      expect(db.resetLocalAdminPassword(nonce: _nonce, next: 'Better#456'), isTrue);
      expect(db.resetLocalAdminPassword(nonce: _nonce, next: 'Other#789'), isFalse);
      expect(db.usedLocalAdminResets, {_nonce});
      expect(db.signInLocalAdmin(email: 'owner@cafe.ly', password: 'Better#456', remember: false), isTrue);
    });

    test('used tickets are remembered after the app restarts', () async {
      final dir = Directory.systemTemp.createTempSync('admin_reset');
      addTearDown(() {
        db.closeLocal();
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows may still hold the file briefly; the temp folder is cleaned up later.
        }
      });
      final path = p.join(dir.path, localDatabaseFileName);
      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));
      db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      db.resetLocalAdminPassword(nonce: _nonce, next: 'Better#456');

      db.closeLocal();
      await db.initLocal(SqliteLocalStateStore.open(path));

      expect(db.usedLocalAdminResets, {_nonce});
      expect(db.resetLocalAdminPassword(nonce: _nonce, next: 'Other#789'), isFalse);
    });
  });

  group('the app with a reset ticket', () {
    late Directory appData;
    late LocalStateStore local;
    final stores = <CafeStore>[];

    Future<CafeStore> start(_FakeResetFile file) async {
      db.closeLocal();
      final store = CafeStore(db)..updatePlatform = _NoUpdates();
      stores.add(store);
      // Reopening the same in-memory database stands in for an app restart.
      await store.load(localStore: _Reopened(local), resetFile: file);
      return store;
    }

    setUp(() async {
      appData = Directory.systemTemp.createTempSync('admin_reset_app');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => appData.path,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (call) async => {'appName': 'Cafe POS', 'packageName': 'cafe_pos', 'version': '1.0.0', 'buildNumber': '1'},
      );
      local = openMemoryLocalStateStore();
    });
    tearDown(() {
      for (final store in stores) {
        store.dispose();
      }
      stores.clear();
      local.close();
      try {
        appData.deleteSync(recursive: true);
      } on FileSystemException {
        // Already gone or still locked; nothing to keep.
      }
    });

    test('the forgotten password is replaced once and the admin is signed in', () async {
      final first = await start(_FakeResetFile(null));
      await first.createAdmin(email: 'owner@cafe.ly', password: 'Secret#123', confirm: 'Secret#123');
      await _sell();
      first.signOut();

      final file = _FakeResetFile(_ticket());
      final store = await start(file);
      expect(store.adminResetReady, isTrue);
      expect(store.adminResetEmail, 'owner@cafe.ly');
      expect(await store.resetAdminPassword(password: 'Better#456', confirm: 'Other#456'), store.l10n.errPasswordsMismatch);
      expect(await store.resetAdminPassword(password: 'weak', confirm: 'weak'), store.l10n.errWeakPassword);
      expect(store.adminResetReady, isTrue, reason: 'a typo does not use up the ticket');

      expect(await store.resetAdminPassword(password: 'Better#456', confirm: 'Better#456'), isNull);
      expect(store.authKind, AuthKind.admin);
      expect(store.adminResetReady, isFalse);
      expect(file.text, isNull, reason: 'the ticket file is removed');
      expect(store.payments.single.totalDue, 15);
      store.signOut();
      expect(await store.signInAdmin('owner@cafe.ly', 'Secret#123'), isNotNull);
      expect(await store.signInAdmin('owner@cafe.ly', 'Better#456'), isNull);

      final copy = _FakeResetFile(_ticket());
      final again = await start(copy);
      expect(again.adminResetReady, isFalse, reason: 'a copied ticket cannot be used twice');
      expect(copy.text, isNull);
      expect(await again.resetAdminPassword(password: 'Other#789', confirm: 'Other#789'), again.l10n.authResetUnavailable);
    });

    test('a ticket with no admin yet is dropped and setup stays as normal', () async {
      final file = _FakeResetFile(_ticket());
      final store = await start(file);
      expect(store.hasAdmin, isFalse);
      expect(store.adminResetReady, isFalse);
      expect(file.text, isNull);
    });

    test('a forged ticket is dropped and the old password still works', () async {
      final first = await start(_FakeResetFile(null));
      await first.createAdmin(email: 'owner@cafe.ly', password: 'Secret#123', confirm: 'Secret#123');
      first.signOut();

      final forged = _FakeResetFile(_ticket(sig: 'f' * 64));
      final store = await start(forged);
      expect(store.adminResetReady, isFalse);
      expect(forged.text, isNull);
      expect(await store.signInAdmin('owner@cafe.ly', 'Secret#123'), isNull);
    });
  });

  group('admin sign-in screen', () {
    testWidgets('asks for a new password while a reset is ready', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _ResetStore();
      await tester.pumpWidget(
        ChangeNotifierProvider<CafeStore>.value(
          value: store,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(routes: [
              GoRoute(path: '/', builder: (_, _) => const AdminAuthScreen()),
              GoRoute(path: '/admin/dashboard', builder: (_, _) => const Text('dashboard')),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {} // test font is wider, so the header row overflows

      expect(find.textContaining('owner@cafe.ly'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
      await tester.enterText(find.byKey(const Key('reset-password')), 'Better#456');
      await tester.enterText(find.byKey(const Key('reset-confirm')), 'Better#456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(store.resets, [('Better#456', 'Better#456')]);
      expect(find.text('dashboard'), findsOneWidget);
    });
  });
}

/// Hands [inner] to a new CafeStore without closing it when the old one is replaced.
class _Reopened implements LocalStateStore {
  _Reopened(this.inner);
  final LocalStateStore inner;

  @override
  Object? readDoc(String key) => inner.readDoc(key);

  @override
  void writeDoc(String key, Object? value) => inner.writeDoc(key, value);

  @override
  List<Map<String, dynamic>> readRecords(String kind) => inner.readRecords(kind);

  @override
  void putRecords(String kind, Iterable<Map<String, dynamic>> rows) => inner.putRecords(kind, rows);

  @override
  void transaction(void Function() action) => inner.transaction(action);

  @override
  void close() {}
}

/// Keeps the self-updater quiet (no download checks) in these tests.
class _NoUpdates implements UpdatePlatform {
  @override
  bool get supported => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('no updates in tests');
}

class _ResetStore extends CafeStore {
  _ResetStore() : super(AppDatabase.instance) {
    cafe = {'name': 'Test Cafe'};
  }

  final resets = <(String, String)>[];

  @override
  bool get adminResetReady => true;

  @override
  String get adminResetEmail => 'owner@cafe.ly';

  @override
  Future<String?> resetAdminPassword({required String password, required String confirm}) async {
    resets.add((password, confirm));
    return null;
  }
}
