import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/lan/lan_protocol.dart';
import 'package:menu_web_v1/lan/waiter_devices.dart';
import 'package:menu_web_v1/lan/waiter_hub.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/waiter/order_screen.dart';
import 'package:menu_web_v1/waiter/waiter_app.dart';
import 'package:menu_web_v1/waiter/waiter_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lan/fake_hub_host.dart';
import 'waiter_alerts_test.dart' show FakeBackground, HubBackedClient;

void main() {
  late WaiterController waiter;
  late FakeHost host;
  late FakeBackground background;

  Future<void> startWithCall(WidgetTester tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      host = FakeHost();
      final hub = WaiterHub(host: host, deviceStore: MemoryWaiterDeviceStore());
      waiter = WaiterController(
        HubBackedClient(hub),
        pollEvery: const Duration(hours: 1),
        playTone: (_) async {},
        background: background = FakeBackground(),
      );
      final pairing = hub.handle(
        const HubRequest(method: 'POST', path: '/pair', body: {'deviceId': 'p1', 'deviceName': 'Omar'}),
      );
      await Future<void>.delayed(Duration.zero);
      hub.answerPair(hub.pairRequests.single, allow: true);
      final token = (await pairing).body['token'] as String;
      SharedPreferences.setMockInitialValues({
        'waiter_hub': '{"host":"10.0.0.5","port":${LanProtocol.httpPort},"hubId":"${hub.hubId}","cafe":"Caffe test"}',
        'waiter_token': token,
      });
      await waiter.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      host.openCalls.add(StaffCall(id: 'c1', tableId: 't1', tableNumber: '1', createdAt: DateTime(2026)));
      await waiter.refresh();
    });
    addTearDown(waiter.dispose);
    await tester.pumpWidget(WaiterApp(controller: waiter));
    await tester.pump(const Duration(seconds: 1));
    expect(waiter.alertFor('t1'), isNotNull);
  }

  testWidgets('tapping the phone notification opens that table', (tester) async {
    await startWithCall(tester);

    background.opened.add('t1');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(waiter.alertFor('t1'), isNull);
    expect(find.byType(OrderScreen), findsOneWidget);
    expect(waiter.tableToOpen, isNull);
  });

  testWidgets('tapping a table that called opens its order screen', (tester) async {
    await startWithCall(tester);

    await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text('1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(waiter.alertFor('t1'), isNull);
    expect(find.byType(OrderScreen), findsOneWidget);
  });
}
