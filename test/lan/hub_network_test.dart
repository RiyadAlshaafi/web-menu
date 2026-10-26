import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/lan/hub_server_io.dart';
import 'package:menu_web_v1/lan/waiter_devices.dart';
import 'package:menu_web_v1/lan/waiter_hub.dart';
import 'package:menu_web_v1/waiter/hub_client.dart';

import 'fake_hub_host.dart';

// No TestWidgetsFlutterBinding here: it replaces HttpClient with one that never connects.
void main() {
  late WaiterHub hub;

  setUp(() => hub = WaiterHub(host: FakeHost(), deviceStore: MemoryWaiterDeviceStore()));

  group('over the network', () {
    test('a phone pairs and orders through the real HTTP port', () async {
      final server = HubServer(hub, httpPort: 0, discoveryPort: 0);
      await server.start();
      addTearDown(server.stop);
      final client = LanHubClient();
      final port = server.boundPort!;

      final pairing = client.send('127.0.0.1', port, 'POST', '/pair', body: {'deviceId': 'p', 'deviceName': 'Sara'});
      while (hub.pairRequests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      hub.answerPair(hub.pairRequests.single, allow: true);
      final paired = await pairing;
      expect(paired.status, 200);
      final token = paired.body['token'] as String;

      final denied = await client.send('127.0.0.1', port, 'GET', '/menu');
      expect(denied.status, 401);

      final sent = await client.send('127.0.0.1', port, 'POST', '/order', token: token, body: {
        'tableId': 't1',
        'lines': [
          {'itemId': 'latte', 'qty': 1},
        ],
      });
      expect(sent.status, 200);
      expect(hub.pendingOrders, hasLength(1));
    });

    test('an unreachable till reads as status 0', () async {
      final reply = await LanHubClient().send('127.0.0.1', 1, 'GET', '/menu', timeout: const Duration(seconds: 2));
      expect(reply.unreachable, isTrue);
    });
  });

}
