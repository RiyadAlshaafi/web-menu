import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/local_state_store.dart';
import 'package:menu_web_v1/lan/lan_protocol.dart';
import 'package:menu_web_v1/lan/store_hub_host.dart';
import 'package:menu_web_v1/lan/waiter_devices.dart';
import 'package:menu_web_v1/lan/waiter_hub.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'fake_hub_host.dart';

/// Pairs a phone, letting [allow] decide what the cashier taps.
Future<HubResponse> pairPhone(WaiterHub hub, {bool allow = true, String id = 'phone-1'}) async {
  final asking = hub.handle(HubRequest(method: 'POST', path: '/pair', body: {'deviceId': id, 'deviceName': 'Omar'}));
  await Future<void>.delayed(Duration.zero);
  hub.answerPair(hub.pairRequests.single, allow: allow);
  return asking;
}

Future<String> pairedToken(WaiterHub hub) async => (await pairPhone(hub)).body['token'] as String;

HubRequest order(String token, Map<String, dynamic> body) =>
    HubRequest(method: 'POST', path: '/order', token: token, body: body);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHost host;
  late MemoryWaiterDeviceStore devices;
  late WaiterHub hub;

  setUp(() {
    host = FakeHost();
    devices = MemoryWaiterDeviceStore();
    hub = WaiterHub(host: host, deviceStore: devices);
  });

  group('pairing', () {
    test('an allowed phone gets a token; only its hash is saved', () async {
      final reply = await pairPhone(hub);
      expect(reply.status, 200);
      final token = reply.body['token'] as String;
      expect(token, isNotEmpty);
      expect(devices.devices.single.name, 'Omar');
      expect(devices.devices.single.tokenHash, WaiterTokens.hash(token));
      expect(devices.devices.single.tokenHash, isNot(contains(token)));
      expect(host.rings, 1, reason: 'the till rings so the cashier sees the ask');
    });

    test('a denied phone gets 403 and is not saved', () async {
      final reply = await pairPhone(hub, allow: false);
      expect(reply.status, 403);
      expect(devices.devices, isEmpty);
    });

    test('pairing again replaces the old token', () async {
      final first = await pairedToken(hub);
      await pairedToken(hub);
      expect(devices.devices, hasLength(1));
      final reply = await hub.handle(HubRequest(method: 'GET', path: '/tables', token: first));
      expect(reply.status, 401);
    });

    test('a request without the deviceId is refused', () async {
      final reply = await hub.handle(const HubRequest(method: 'POST', path: '/pair', body: {}));
      expect(reply.status, 400);
    });
  });

  group('who may ask', () {
    test('no token or a wrong token gets 401', () async {
      await pairedToken(hub);
      for (final token in [null, '', 'made-up']) {
        final reply = await hub.handle(HubRequest(method: 'GET', path: '/menu', token: token));
        expect(reply.status, 401, reason: '$token');
      }
    });

    test('a removed phone gets 401', () async {
      final token = await pairedToken(hub);
      await hub.forget('phone-1');
      final reply = await hub.handle(HubRequest(method: 'GET', path: '/tables', token: token));
      expect(reply.status, 401);
    });
  });

  group('menu and floor', () {
    test('the menu leaves out hidden categories and their dishes', () async {
      final token = await pairedToken(hub);
      final reply = await hub.handle(HubRequest(method: 'GET', path: '/menu', token: token));
      expect([for (final c in reply.body['categories'] as List) (c as Map)['id']], ['coffee']);
      expect([for (final i in reply.body['items'] as List) (i as Map)['id']], ['latte', 'pizza', 'gone']);
    });

    test('the floor lists every table with its status', () async {
      final token = await pairedToken(hub);
      final reply = await hub.handle(HubRequest(method: 'GET', path: '/tables', token: token));
      final tables = reply.body['tables'] as List;
      expect(tables.map((t) => (t as Map)['number']), ['1', '2']);
      expect((tables[1] as Map)['status'], 'dining');
    });
  });

  group('orders', () {
    test('an order waits for the cashier; prices come from the till', () async {
      final token = await pairedToken(hub);
      final reply = await hub.handle(order(token, {
        'tableId': 't1',
        'lines': [
          {'itemId': 'latte', 'qty': 2, 'unitPrice': 0.01},
          {'itemId': 'pizza', 'qty': 1, 'onIds': ['cheese']},
          {'itemId': 'latte', 'qty': 1},
        ],
      }));
      expect(reply.status, 200);
      expect(host.sent, isEmpty, reason: 'nothing reaches the bill before accept');
      final waiting = hub.pendingOrders.single;
      expect(waiting.tableNumber, '1');
      expect(waiting.deviceName, 'Omar');
      final latte = waiting.lines.firstWhere((line) => line.menuItemId == 'latte');
      expect(latte.qty, 3, reason: 'two lines of the same dish merge');
      expect(latte.unitPrice, 7);
      final pizza = waiting.lines.firstWhere((line) => line.menuItemId == 'pizza');
      expect(pizza.unitPrice, 23, reason: 'the cheese extra is priced by the till');
      expect(waiting.total, 3 * 7 + 23);

      final result = await hub.accept(waiting);
      expect(result.orderId, 'order-1');
      expect(host.sent.single.tableId, 't1');
      expect(hub.pendingOrders, isEmpty);

      final floor = await hub.handle(HubRequest(method: 'GET', path: '/tables', token: token));
      expect(((floor.body['orders'] as List).single as Map)['status'], 'accepted');
    });

    test('on an online till the order waits in the new-order list like a QR order', () async {
      host.holdsOrders = true;
      final token = await pairedToken(hub);
      final reply = await hub.handle(order(token, {
        'tableId': 't1',
        'lines': [
          {'itemId': 'latte', 'qty': 2},
        ],
      }));
      expect(reply.status, 200);
      expect(host.sent.single.forAccept, isTrue, reason: 'sent as a guest order, not auto-accepted');
      expect(hub.pendingOrders, isEmpty, reason: 'no separate waiter banner');

      Future<Map> floor() async =>
          (await hub.handle(HubRequest(method: 'GET', path: '/tables', token: token))).body;
      var tables = await floor();
      expect(((tables['orders'] as List).single as Map)['status'], 'pending');
      expect(((tables['tables'] as List).first as Map)['waiting'], 1);

      host.tillStatuses['order-1'] = OrderStatus.preparing;
      tables = await floor();
      expect(((tables['orders'] as List).single as Map)['status'], 'accepted');
      expect(((tables['tables'] as List).first as Map)['waiting'], 0);
    });

    test('a till without internet pauses table orders and tells the phone', () async {
      host.takesTableOrders = false;
      final token = await pairedToken(hub);
      final reply = await hub.handle(order(token, {
        'tableId': 't1',
        'lines': [
          {'itemId': 'latte', 'qty': 1},
        ],
      }));
      expect(reply.status, 503);
      expect(reply.body['error'], 'orders_paused');
      expect(host.sent, isEmpty);
      expect(hub.pendingOrders, isEmpty, reason: 'nothing waits for an Accept that cannot work');
      final floor = await hub.handle(HubRequest(method: 'GET', path: '/tables', token: token));
      expect(floor.body['paused'], isTrue);
    });

    test('the menu carries the admin brand colours', () async {
      final token = await pairedToken(hub);
      final menu = await hub.handle(HubRequest(method: 'GET', path: '/menu', token: token));
      expect(menu.body['brand'], {'headerColor': '#123456', 'buttonColor': '#00AA55'});
    });

    test('a refused order never reaches the bill and the phone sees it', () async {
      final token = await pairedToken(hub);
      await hub.handle(order(token, {
        'tableId': 't2',
        'lines': [
          {'itemId': 'latte', 'qty': 1},
        ],
      }));
      hub.refuse(hub.pendingOrders.single);
      expect(host.sent, isEmpty);
      final floor = await hub.handle(HubRequest(method: 'GET', path: '/tables', token: token));
      expect(((floor.body['orders'] as List).single as Map)['status'], 'refused');
    });

    test('an unknown table, an unknown or sold-out dish and bad amounts are refused', () async {
      final token = await pairedToken(hub);
      final cases = <Map<String, dynamic>, int>{
        {'tableId': 'nope', 'lines': [{'itemId': 'latte', 'qty': 1}]}: 404,
        {'tableId': 't1', 'lines': [{'itemId': 'nope', 'qty': 1}]}: 409,
        {'tableId': 't1', 'lines': [{'itemId': 'gone', 'qty': 1}]}: 409,
        {'tableId': 't1', 'lines': [{'itemId': 'latte', 'qty': 0}]}: 400,
        {'tableId': 't1', 'lines': [{'itemId': 'latte', 'qty': 100}]}: 400,
        {'tableId': 't1', 'lines': [{'itemId': 'pizza', 'qty': 1, 'onIds': ['ham']}]}: 400,
        {'tableId': 't1', 'lines': []}: 400,
      };
      for (final entry in cases.entries) {
        final reply = await hub.handle(order(token, entry.key));
        expect(reply.status, entry.value, reason: '${entry.key}');
      }
      expect(hub.pendingOrders, isEmpty);
    });
  });

  group('on the till', () {
    late Directory appData;
    final db = AppDatabase.instance;

    setUpAll(() {
      appData = Directory.systemTemp.createTempSync('waiter_hub_test');
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

    test('an accepted waiter order lands on the bill; the cashier\'s own cart stays', () async {
      db.closeLocal();
      final store = CafeStore(db);
      await store.load(localStore: openMemoryLocalStateStore());
      final table = CafeTable(id: 't5', number: '5', qrSlug: 'slug-5');
      await db.writeTables([table], changed: [table]);
      final category = MenuCategory(id: 'drinks', nameEn: 'Drinks', nameAr: 'مشروبات');
      await db.writeCategories([category], changed: [category]);
      final latte = MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7.5, categoryId: 'drinks');
      final tea = MenuItem(id: 'tea', nameIt: 'Tea', nameEn: 'Tea', price: 3, categoryId: 'drinks');
      await db.writeMenuItems([latte, tea], changed: [latte, tea]);
      await store.syncFromDisk();
      store
        ..locale = 'en'
        ..authKind = AuthKind.cashier;
      store.addToCart('t5', tea);

      final tillHub = WaiterHub(host: StoreHubHost(store), deviceStore: MemoryWaiterDeviceStore());
      final token = await pairedToken(tillHub);
      final reply = await tillHub.handle(order(token, {
        'tableId': 't5',
        'lines': [
          {'itemId': 'latte', 'qty': 2},
        ],
      }));
      expect(reply.status, 200);
      expect(store.openOrderFor('t5'), isNull, reason: 'waits for accept');

      final result = await tillHub.accept(tillHub.pendingOrders.single);
      expect(result.error, isNull);
      final bill = store.openOrderFor('t5')!;
      expect(result.orderId, bill.id);
      expect(bill.lines.single.menuItemId, 'latte');
      expect(bill.lines.single.qty, 2);
      expect(bill.subtotal, 15);
      expect(store.cartFor('t5').lines.single.menuItemId, 'tea', reason: 'the cashier\'s unsent dish is kept');
    });
  });

  test('discovery answers name the cafe and port', () {
    final answer = hub.discoveryAnswer();
    final found = FoundHub.fromAnswer(answer, '10.0.0.5');
    expect(found?.cafeName, 'Caffe test');
    expect(found?.port, LanProtocol.httpPort);
    expect(found?.hubId, hub.hubId);
  });
}
