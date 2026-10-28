import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/lan/lan_protocol.dart';
import 'package:menu_web_v1/waiter/background_alerts.dart';
import 'package:menu_web_v1/waiter/hub_client.dart';
import 'package:menu_web_v1/waiter/waiter_app.dart';
import 'package:menu_web_v1/waiter/waiter_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A till that answers at once: it allows every phone and takes every order.
class FakeHubClient implements HubClient {
  bool offline = false;
  bool paused = false;
  int discoveries = 0;
  final orders = <Map<String, dynamic>>[];
  final tokens = <String?>[];

  @override
  Future<List<FoundHub>> discover({Duration wait = Duration.zero}) async {
    discoveries++;
    return const [FoundHub(host: '10.0.0.5', port: LanProtocol.httpPort, hubId: 'hub-1', cafeName: 'Caffe test')];
  }

  @override
  Future<HubReply> send(
    String host,
    int port,
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Duration timeout = Duration.zero,
  }) async {
    if (offline) return const HubReply(0);
    if (path != '/pair') tokens.add(token);
    return switch ('$method $path') {
      'POST /pair' => const HubReply(200, {'token': 'secret', 'hubId': 'hub-1', 'cafe': 'Caffe test'}),
      'GET /menu' => const HubReply(200, {
        'cafe': 'Caffe test',
        'categories': [
          {'id': 'coffee', 'nameEn': 'Coffee', 'nameAr': 'قهوة'},
        ],
        'items': [
          {'id': 'latte', 'nameIt': 'Latte', 'nameEn': 'Latte', 'price': 7, 'categoryId': 'coffee'},
          {'id': 'mocha', 'nameIt': 'Mocha', 'nameEn': 'Mocha', 'price': 9, 'categoryId': 'coffee', 'soldOut': true},
        ],
      }),
      'GET /tables' => HubReply(200, {
        'paused': paused,
        'tables': const [
          {'id': 't1', 'number': '1', 'status': 'free'},
          {'id': 't2', 'number': '2', 'status': 'dining', 'items': 3, 'total': 21},
        ],
        'orders': const [],
      }),
      'POST /order' => () {
        orders.add(body!);
        return const HubReply(200, {'id': 'w1'});
      }(),
      _ => const HubReply(404),
    };
  }
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = tester.binding.clock.now().add(duration);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeHubClient till;
  late WaiterController waiter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    till = FakeHubClient();
    waiter = WaiterController(till, pollEvery: const Duration(hours: 1), background: const NoBackgroundAlerts());
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WaiterApp(controller: waiter));
    await waiter.start();
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  testWidgets('connect, pick a table, add dishes and send them to the cashier', (tester) async {
    await open(tester);
    expect(find.text('Choose your cafe'), findsOneWidget);
    expect(find.text('Caffe test'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Omar');
    await tester.tap(find.text('Caffe test'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    expect(waiter.phase, WaiterPhase.ready);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Free'), findsWidgets, reason: 'on the tile and in the header count');
    expect(find.text('Dining'), findsWidgets);
    expect(till.tokens, everyElement('secret'));

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Table 1,')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Sold out'), findsOneWidget, reason: 'mocha is sold out');

    await tester.tap(find.text('Latte'));
    await tester.pump();
    await tester.tap(find.text('Latte'));
    await tester.pump();
    await tester.tap(find.text('Mocha'));
    await tester.pump();
    expect(find.text('Review 2 items · 14.000 LYD'), findsOneWidget);

    await tester.tap(find.text('Review 2 items · 14.000 LYD'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Send to cashier'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    expect(find.text('Waiting for the cashier to accept.'), findsOneWidget);
    expect(till.orders.single, {
      'tableId': 't1',
      'lines': [
        {'itemId': 'latte', 'qty': 2},
      ],
    });
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Tables'), findsOneWidget, reason: 'back on the floor');
    expect(waiter.cartCount('t1'), 0);
    waiter.dispose();
  });

  testWidgets('a phone already allowed opens on the tables', (tester) async {
    SharedPreferences.setMockInitialValues({
      'waiter_hub': '{"host":"10.0.0.5","port":47820,"hubId":"hub-1","cafe":"Caffe test"}',
      'waiter_token': 'secret',
    });
    await open(tester);
    expect(find.text('Choose your cafe'), findsNothing);
    expect(find.text('Tables'), findsOneWidget);
    expect(till.discoveries, 0);
    waiter.dispose();
  });

  testWidgets('a till without internet shows the paused banner', (tester) async {
    SharedPreferences.setMockInitialValues({
      'waiter_hub': '{"host":"10.0.0.5","port":47820,"hubId":"hub-1","cafe":"Caffe test"}',
      'waiter_token': 'secret',
    });
    till.paused = true;
    await open(tester);
    expect(waiter.ordersPaused, isTrue);
    expect(
      find.text('The cashier has no internet. Table orders are paused, tell the cashier in person.'),
      findsOneWidget,
    );
    waiter.dispose();
  });

  testWidgets('a lost connection shows the banner and keeps the cart', (tester) async {
    SharedPreferences.setMockInitialValues({
      'waiter_hub': '{"host":"10.0.0.5","port":47820,"hubId":"hub-1","cafe":"Caffe test"}',
      'waiter_token': 'secret',
    });
    await open(tester);
    waiter.addDish('t1', waiter.items.first);

    till.offline = true;
    await waiter.refresh();
    await tester.pump();
    expect(find.text('Reconnecting to the cashier…'), findsOneWidget);
    expect(waiter.cartCount('t1'), 1);

    till.offline = false;
    await waiter.refresh();
    await tester.pump();
    expect(find.text('Reconnecting to the cashier…'), findsNothing);
    waiter.dispose();
  });
}
