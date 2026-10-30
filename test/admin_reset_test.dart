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
import 'package:pinenacl/ed25519.dart';
import 'package:provider/provider.dart';

final db = AppDatabase.instance;
const _nonce = '0123456789abcdef0123456789abcdef';

/// Stands in for the server's key pair (the real private key is an Edge Function secret).
final _serverKey = SigningKey.fromSeed(Uint8List.fromList(List.generate(32, (i) => i + 1)));
String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The server's signature on a ticket (supabase/functions/admin-reset-ticket).
String _sign(String nonce, String issued, [SigningKey? key]) =>
    _hex((key ?? _serverKey).sign(Uint8List.fromList(utf8.encode(adminResetMessage(nonce, issued)))).signature);

/// A ticket as the setup saves it from the server's answer.
String _ticket({String nonce = _nonce, DateTime? issued, String? sig}) {
  final stamp = (issued ?? DateTime.now()).toUtc().toIso8601String();
  return jsonEncode({'nonce': nonce, 'issued': stamp, 'sig': sig ?? _sign(nonce, stamp)});
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
  setUpAll(() => adminResetCheckKey = _hex(_serverKey.verifyKey));
  tearDownAll(() => adminResetCheckKey = adminResetPublicKey);

  group('reset ticket', () {
    final now = DateTime(2026, 10, 17, 12);
    AdminResetTicket? check(String? text, {Set<String> used = const {}}) =>
        AdminResetTicket.check(text, now: now, used: used);

    test('a ticket signed by the server is accepted', () {
      final ticket = check(_ticket(issued: now.subtract(const Duration(hours: 2))));
      expect(ticket?.nonce, _nonce);
      expect(ticket?.issuedAt.isAtSameMomentAs(now.subtract(const Duration(hours: 2))), isTrue);
    });

    test('the key in the app is a real Ed25519 public key, and the test key is not it', () {
      expect(adminResetPublicKey, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(_hex(_serverKey.verifyKey), isNot(adminResetPublicKey));
      final stamp = now.toUtc().toIso8601String();
      expect(adminResetSignatureValid(_nonce, stamp, _sign(_nonce, stamp), publicKey: adminResetPublicKey), isFalse,
          reason: 'a ticket signed by anyone but the server is refused by the shipped app');
    });

    test('a hand-written, edited or wrongly signed ticket is refused', () {
      expect(check(_ticket(issued: now, sig: 'a' * 128)), isNull);
      final stamp = now.toUtc().toIso8601String();
      final earlier = now.subtract(const Duration(days: 1)).toUtc().toIso8601String();
      final edited = jsonEncode({'nonce': _nonce, 'issued': stamp, 'sig': _sign(_nonce, earlier)});
      expect(check(edited), isNull, reason: 'moving the date breaks the signature');
      final otherNonce = jsonEncode({'nonce': 'f' * 32, 'issued': stamp, 'sig': _sign(_nonce, stamp)});
      expect(check(otherNonce), isNull, reason: 'a signature belongs to one nonce');
      final stranger = SigningKey.fromSeed(Uint8List(32));
      expect(check(jsonEncode({'nonce': _nonce, 'issued': stamp, 'sig': _sign(_nonce, stamp, stranger)})), isNull);
      expect(check(jsonEncode({'nonce': _nonce.toUpperCase(), 'issued': stamp, 'sig': _sign(_nonce.toUpperCase(), stamp)})), isNull);
    });

    test('an expired, future-dated or already used ticket is refused', () {
      expect(check(_ticket(issued: now.subtract(const Duration(hours: 24, minutes: 1)))), isNull);
      expect(check(_ticket(issued: now.add(const Duration(hours: 2)))), isNull);
      expect(check(_ticket(issued: now.add(const Duration(minutes: 40)))), isNotNull, reason: 'a PC clock a little behind is fine');
      expect(check(_ticket(issued: now), used: {_nonce}), isNull);
    });

    test('a missing or broken file is refused', () {
      expect(check(null), isNull);
      expect(check('not json'), isNull);
      expect(check('[]'), isNull);
      expect(check(jsonEncode({'nonce': _nonce})), isNull);
      expect(check(_ticket(nonce: 'abc123', issued: now)), isNull);
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

    test('the forgotten PIN is replaced once and the admin is signed in', () async {
      final first = await start(_FakeResetFile(null));
      expect(await first.createAdmin(email: '', password: '1234', confirm: '1234'), isNull);
      await _sell();
      first.signOut();

      final file = _FakeResetFile(_ticket());
      final store = await start(file);
      expect(store.adminResetReady, isTrue);
      expect(await store.resetAdminPassword(password: '567890', confirm: '567891'), store.l10n.errPinsMismatch);
      expect(await store.resetAdminPassword(password: '12', confirm: '12'), store.l10n.errWeakAdminPin('4'));
      expect(store.adminResetReady, isTrue, reason: 'a typo does not use up the ticket');

      expect(await store.resetAdminPassword(password: '567890', confirm: '567890'), isNull);
      expect(store.authKind, AuthKind.admin);
      expect(store.adminResetReady, isFalse);
      expect(file.text, isNull, reason: 'the ticket file is removed');
      expect(store.payments.single.totalDue, 15);
      store.signOut();
      expect(await store.signInAdmin('', '1234'), isNotNull);
      expect(await store.signInAdmin('', '567890'), isNull, reason: 'offline the admin signs in with the PIN alone');

      final copy = _FakeResetFile(_ticket());
      final again = await start(copy);
      expect(again.adminResetReady, isFalse, reason: 'a copied ticket cannot be used twice');
      expect(copy.text, isNull);
      expect(await again.resetAdminPassword(password: '4321', confirm: '4321'), again.l10n.authResetUnavailable);
    });

    test('a ticket with no admin yet is dropped and setup stays as normal', () async {
      final file = _FakeResetFile(_ticket());
      final store = await start(file);
      expect(store.hasAdmin, isFalse);
      expect(store.adminResetReady, isFalse);
      expect(file.text, isNull);
    });

    test('a forged ticket is dropped and the old PIN still works', () async {
      final first = await start(_FakeResetFile(null));
      await first.createAdmin(email: '', password: '1234', confirm: '1234');
      first.signOut();

      final forged = _FakeResetFile(_ticket(sig: 'f' * 128));
      final store = await start(forged);
      expect(store.adminResetReady, isFalse);
      expect(forged.text, isNull);
      expect(await store.signInAdmin('', '1234'), isNull);
    });

    test('an admin made with a password before PINs still signs in with it, without the email', () async {
      final first = await start(_FakeResetFile(null));
      expect(await first.createAdmin(email: 'owner@cafe.ly', password: 'Secret#123', confirm: 'Secret#123'), first.l10n.errWeakAdminPin('4'));
      first.db.createLocalAdmin(email: 'owner@cafe.ly', password: 'Secret#123');
      first.signOut();
      final store = await start(_FakeResetFile(null));
      expect(await store.signInAdmin('', 'Secret#123'), isNull);
    });
  });

  group('admin sign-in screen', () {
    testWidgets('asks for a new PIN while a reset is ready', (tester) async {
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

      expect(find.text(store.l10n.authResetPinTitle), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
      await tester.enterText(find.byKey(const Key('reset-password')), '567890');
      await tester.enterText(find.byKey(const Key('reset-confirm')), '567890');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(store.resets, [('567890', '567890')]);
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
  void deleteRecord(String kind, String id) => inner.deleteRecord(kind, id);

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
