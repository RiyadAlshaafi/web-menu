import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/offline/offline_sync.dart';
import 'package:menu_web_v1/offline/outbox_store.dart';
import 'package:menu_web_v1/offline/outbox_store_io.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/update/app_version.dart';
import 'package:menu_web_v1/update/release_info.dart';
import 'package:menu_web_v1/update/update_checks.dart';
import 'package:menu_web_v1/update/update_platform.dart';
import 'package:menu_web_v1/update/update_platform_io.dart';
import 'package:path/path.dart' as p;

/// Stands in for Windows so the install path can be checked without installing anything.
class FakePlatform implements UpdatePlatform {
  final calls = <String>[];
  Map<String, dynamic>? marker;

  @override
  bool get supported => true;

  @override
  Future<Object?> fetchLatestJson() async => null;

  @override
  Future<String> download(ReleaseInfo info) async => 'setup.exe';

  @override
  Future<String> backup(OutboxStore store, String outboxFileName) async {
    calls.add('backup');
    return 'backup-folder';
  }

  @override
  Future<Map<String, dynamic>?> readMarker() async => marker;

  @override
  Future<void> writeMarker(Map<String, dynamic>? value) async {
    calls.add('marker');
    marker = value;
  }

  @override
  Future<void> install(String installerPath) async => calls.add('install $installerPath');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('versions', () {
    test('compare by number, not by text', () {
      expect(isNewer('1.10.0', '1.9.3'), isTrue);
      expect(isNewer('2.0.0', '1.99.99'), isTrue);
      expect(isNewer('1.2.0', '1.2.0'), isFalse);
      expect(isNewer('1.2.0+9', '1.2.0'), isFalse, reason: 'a build number is not a new release');
      expect(isNewer('v1.3.0', '1.2.9'), isTrue);
      expect(isNewer('nonsense', '1.0.0'), isFalse);
      expect(isNewer('1.0.1', ''), isFalse, reason: 'an unknown current version never triggers an install');
    });
  });

  group('latest.json', () {
    const hash = 'a3f1c2d4e5b6a7980112233445566778899aabbccddeeff00112233445566778';
    test('a complete file is read', () {
      final info = ReleaseInfo.tryParse({'version': '1.2.0', 'url': 'https://example.com/setup.exe', 'sha256': hash.toUpperCase()});
      expect(info!.version, '1.2.0');
      expect(info.sha256, hash);
    });
    test('anything missing or odd starts no install', () {
      expect(ReleaseInfo.tryParse(null), isNull);
      expect(ReleaseInfo.tryParse({'version': '1.2', 'url': 'https://x', 'sha256': hash}), isNull);
      expect(ReleaseInfo.tryParse({'version': '1.2.0', 'url': 'http://insecure', 'sha256': hash}), isNull);
      expect(ReleaseInfo.tryParse({'version': '1.2.0', 'url': 'https://x', 'sha256': 'short'}), isNull);
    });
  });

  group('download', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('update_dl'));
    tearDown(() => dir.deleteSync(recursive: true));

    final bytes = utf8.encode('installer bytes');
    final good = sha256.convert(bytes).toString();
    final client = MockClient.streaming((request, body) async => http.StreamedResponse(Stream.value(bytes), 200));

    test('a matching installer is kept', () async {
      final file = File(p.join(dir.path, 'setup.exe'));
      await downloadVerified(client, Uri.parse('https://example.com/setup.exe'), good, file);
      expect(file.readAsBytesSync(), bytes);
    });

    test('a changed installer is deleted and never run', () async {
      final file = File(p.join(dir.path, 'setup.exe'));
      await expectLater(
        downloadVerified(client, Uri.parse('https://example.com/setup.exe'), 'b' * 64, file),
        throwsStateError,
      );
      expect(file.existsSync(), isFalse);
    });
  });

  group('backup before update', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('update_backup'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('copies the till data and a consistent outbox, keeps the newest three', () async {
      const outboxName = 'offline_outbox_abcd1234.sqlite';
      final store = SqliteOutboxStore.open(p.join(dir.path, outboxName));
      await store.add(OutboxItem(id: 'sale-1', kind: 'takeout', payload: {'params': <String, dynamic>{}}, createdAt: DateTime.utc(2026)));
      File(p.join(dir.path, 'shared_preferences.json')).writeAsStringSync('{"flutter.device_cafe_slot":1}');

      final made = <String>[];
      for (var i = 0; i < 4; i++) {
        made.add(await backupAppData(source: dir, store: store, outboxFileName: outboxName, now: DateTime(2026, 10, 8, 11, i)));
      }
      final kept = Directory(p.join(dir.path, backupFolderName)).listSync().map((e) => e.path).toList()..sort();
      expect(kept, made.sublist(1), reason: 'only the newest three backups are kept');

      final latest = made.last;
      expect(File(p.join(latest, 'shared_preferences.json')).readAsStringSync(), contains('device_cafe_slot'));
      expect(Directory(p.join(latest, backupFolderName)).existsSync(), isFalse, reason: 'backups are not copied into backups');
      final copy = SqliteOutboxStore.open(p.join(latest, outboxName));
      expect((await copy.pending()).single.id, 'sale-1', reason: 'unsent sales are in the backup');
      // Windows locks open files: close both so the test folder can be deleted afterwards.
      copy.close();
      store.close();
    });

    test('an outbox that never opened is still copied as files', () async {
      const outboxName = 'offline_outbox_abcd1234.sqlite';
      File(p.join(dir.path, outboxName)).writeAsStringSync('raw');
      final made = await backupAppData(source: dir, store: MemoryOutboxStore(), outboxFileName: outboxName);
      expect(File(p.join(made, outboxName)).readAsStringSync(), 'raw');
    });
  });

  group('upload records', () {
    test('confirmed uploads are remembered with their amounts', () async {
      final store = MemoryOutboxStore();
      var duplicate = false;
      final sync = OfflineSync(
        store: store,
        rpc: (name, params) async => duplicate ? {'ok': true, 'duplicate': true} : {'ok': true},
      );
      await sync.enqueue(OutboxItem(
        id: 'sale',
        kind: 'takeout',
        createdAt: DateTime.utc(2026),
        payload: {
          'params': {'p_client_id': 'sale', 'p_cashier_id': 'c'},
          'local': {'payment': {'totalDue': 12.5}},
        },
      ));
      await sync.flush();
      duplicate = true;
      await sync.enqueue(OutboxItem(
        id: 'exp',
        kind: 'expense',
        createdAt: DateTime.utc(2026),
        payload: {
          'params': {'p_client_id': 'exp', 'p_cashier_id': 'c', 'p_amount': 4},
        },
      ));
      await sync.flush();
      final summary = UploadSummary.ofSent(await store.sentSince(DateTime.utc(2000)));
      expect(summary.receipts, 1);
      expect(summary.receiptsTotal, 12.5);
      expect(summary.expenses, 1, reason: 'a duplicate answer still means the server has it');
      expect(summary.expensesTotal, 4);
    });

    test('the till and the server must agree to the cent', () async {
      const local = UploadSummary(receipts: 2, receiptsTotal: 20.10, expenses: 1, expensesTotal: 3);
      final asked = <int>[];
      final server = await confirmOnServer(
        List.generate(5, (i) => 'id$i'),
        (chunk) async {
          asked.add(chunk.length);
          return {'ok': true, 'receipts': chunk.length == 2 ? 2 : 0, 'receipts_total': chunk.length == 2 ? 20.1 : 0, 'expenses': chunk.length == 1 ? 1 : 0, 'expenses_total': chunk.length == 1 ? 3 : 0};
        },
        chunkSize: 2,
      );
      expect(asked, [2, 2, 1]);
      expect(local.matches(server), isFalse, reason: 'two chunks of two each found two receipts: 4 != 2');
      expect(local.matches(const UploadSummary(receipts: 2, receiptsTotal: 20.1, expenses: 1, expensesTotal: 3)), isTrue);
      expect(local.matches(const UploadSummary(receipts: 2, receiptsTotal: 20.0, expenses: 1, expensesTotal: 3)), isFalse);
    });

    test('the heartbeat sends the app version and reads the minimum version', () async {
      Map<String, dynamic>? sent;
      final sync = OfflineSync(
        store: MemoryOutboxStore(),
        rpc: (name, params) async {
          sent = {'name': name, ...params};
          return {'ok': true, 'min_app_version': '1.3.0'};
        },
      )..appVersion = '1.2.0';
      await sync.heartbeat();
      expect(sent, {'name': 'cashier_heartbeat_v2', 'p_app_version': '1.2.0'});
      expect(sync.minAppVersion, '1.3.0');
    });
  });

  group('installing', () {
    CafeStore storeWith(FakePlatform platform) => CafeStore(AppDatabase.instance)
      ..updatePlatform = platform
      ..appVersion = '1.0.0'
      ..updateRelease = ReleaseInfo.tryParse({'version': '1.1.0', 'url': 'https://x/setup.exe', 'sha256': 'a' * 64})
      ..updateFile = 'setup.exe';

    test('never while a cashier is signed in', () async {
      final platform = FakePlatform();
      final store = storeWith(platform)..authKind = AuthKind.cashier;
      expect(await store.installUpdate(), UpdateBlock.signedIn);
      expect(platform.calls, isEmpty);
    });

    test('never while sales are waiting to upload', () async {
      final platform = FakePlatform();
      final sync = OfflineSync(store: MemoryOutboxStore(), rpc: (n, p) async => {'ok': true});
      await sync.enqueue(OutboxItem(id: 's', kind: 'takeout', payload: {'params': <String, dynamic>{}}, createdAt: DateTime.utc(2026)));
      final store = storeWith(platform)..offline = sync;
      expect(await store.installUpdate(), UpdateBlock.pendingUploads);
      expect(platform.calls, isEmpty);
    });

    test('below the minimum version a cashier cannot sign in', () async {
      final store = storeWith(FakePlatform())
        ..minAppVersion = '1.1.0'
        ..selectedCashierId = 'c'
        ..pinBuffer = '1234';
      expect(store.belowMinVersion, isTrue);
      expect(await store.signInCashier(), isFalse);
      expect(store.authKind, AuthKind.none);
    });
  });


  test('the Windows app keeps the name its data folder is found by', () {
    // Windows keeps each till's offline sales, saved menu and slot link under
    // %APPDATA%\<CompanyName>\<ProductName>. A new name would make an update open an empty folder.
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(rc, contains('VALUE "CompanyName", "com.example"'));
    expect(rc, contains('VALUE "ProductName", "menu_web_v1"'));
    final iss = File('windows/installer/cafe_pos.iss').readAsStringSync();
    expect(iss, contains('AppId={{6B0F3B5E-2C7A-4E61-9C1B-8E5A2D4F7C31}'), reason: 'a new AppId installs a second app');
  });
}
