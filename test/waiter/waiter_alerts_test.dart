import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/lan/lan_protocol.dart';
import 'package:menu_web_v1/lan/waiter_devices.dart';
import 'package:menu_web_v1/lan/waiter_hub.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/waiter/hub_client.dart';
import 'package:menu_web_v1/waiter/waiter_state.dart';
import 'package:menu_web_v1/waiter/waiter_tone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lan/fake_hub_host.dart';

/// Talks to a real hub in memory, so the test covers what the till sends and what the phone does.
class HubBackedClient implements HubClient {
  HubBackedClient(this.hub);

  final WaiterHub hub;

  @override
  Future<List<FoundHub>> discover({Duration wait = Duration.zero}) async => const [];

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
    final answer = await hub.handle(HubRequest(method: method, path: path, token: token, body: body));
    return HubReply(answer.status, answer.body);
  }
}

void main() {
  late FakeHost host;
  late WaiterHub hub;
  late WaiterController waiter;
  late List<WaiterTone> beeps;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = FakeHost();
    hub = WaiterHub(host: host, deviceStore: MemoryWaiterDeviceStore());
    beeps = [];
    waiter = WaiterController(
      HubBackedClient(hub),
      pollEvery: const Duration(hours: 1),
      playTone: (tone) async => beeps.add(tone),
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
  });

  tearDown(() => waiter.dispose());

  test('hub tells the phone which table has food ready and which called', () async {
    host.readyTables.add('t1');
    host.openCalls.add(StaffCall(id: 'c1', tableId: 't2', tableNumber: '2', createdAt: DateTime(2026), kind: 'bill'));
    await waiter.refresh();
    expect(waiter.tableById('t1')!.ready, isTrue);
    expect(waiter.tableById('t2')!.call, 'bill');
    expect(waiter.alertFor('t1'), WaiterAlertKind.ready);
    expect(waiter.alertFor('t2'), WaiterAlertKind.bill);
  });

  test('beeps once when food becomes ready, not on every refresh', () async {
    expect(beeps, isEmpty);
    host.readyTables.add('t1');
    await waiter.refresh();
    await waiter.refresh();
    expect(beeps, [WaiterTone.ready]);
  });

  test('a guest call beeps with the call tone', () async {
    host.openCalls.add(StaffCall(id: 'c1', tableId: 't1', tableNumber: '1', createdAt: DateTime(2026)));
    await waiter.refresh();
    expect(beeps, [WaiterTone.call]);
  });

  test('tapping a table stops its alert until it comes again', () async {
    host.readyTables.add('t1');
    await waiter.refresh();
    waiter.acknowledge('t1');
    expect(waiter.alertFor('t1'), isNull);
    host.readyTables.clear();
    await waiter.refresh();
    host.readyTables.add('t1');
    await waiter.refresh();
    expect(waiter.alertFor('t1'), WaiterAlertKind.ready);
    expect(beeps.length, 2);
  });

  test('sound off keeps the alert on screen but stays silent, and is remembered', () async {
    await waiter.setSoundOn(false);
    host.readyTables.add('t1');
    await waiter.refresh();
    expect(beeps, isEmpty);
    expect(waiter.alertFor('t1'), WaiterAlertKind.ready);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('waiter_sound'), isFalse);
  });
}
