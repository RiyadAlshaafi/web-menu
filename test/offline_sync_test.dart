import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/offline/offline_sync.dart';
import 'package:menu_web_v1/offline/outbox_store.dart';
import 'package:menu_web_v1/offline/outbox_store_io.dart';

OutboxItem item(String id, [String kind = 'takeout']) => OutboxItem(
  id: id,
  kind: kind,
  payload: {
    'params': {'p_client_id': id},
  },
  createdAt: DateTime.utc(2026, 10, 7),
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('outbox_test'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('saved sales survive closing and reopening the outbox file', () async {
    final path = '${dir.path}/o.sqlite';
    final first = SqliteOutboxStore.open(path);
    await first.add(item('a'));
    await first.add(item('a')); // same sale saved twice stays one
    await first.add(item('b'));
    await first.writeValue('k', 'v');
    final again = SqliteOutboxStore.open(path);
    expect((await again.pending()).map((i) => i.id), ['a', 'b']);
    expect(await again.readValue('k'), 'v');
  });

  test('uploads in order, stops when offline, continues later', () async {
    final store = MemoryOutboxStore();
    final calls = <String>[];
    var offline = false;
    final sync = OfflineSync(
      store: store,
      rpc: (name, params) async {
        if (offline) throw const SocketException('Failed host lookup');
        calls.add(params['p_client_id'] as String);
        return {'ok': true};
      },
    );
    for (final id in ['1', '2', '3']) {
      await sync.enqueue(item(id));
    }
    offline = true;
    expect(await sync.flush(), 0);
    expect(sync.online, isFalse);
    expect(sync.pendingCount, 3);
    offline = false;
    expect(await sync.flush(), 3);
    expect(calls, ['1', '2', '3']);
    expect(sync.pendingCount, 0);
    expect(sync.online, isTrue);
  });

  test('a refused item is kept for review and does not block the rest', () async {
    final store = MemoryOutboxStore();
    final sync = OfflineSync(
      store: store,
      rpc: (name, params) async =>
          params['p_client_id'] == 'bad' ? {'ok': false, 'error': 'unknown cashier'} : {'ok': true},
    );
    await sync.enqueue(item('bad'));
    await sync.enqueue(item('good', 'shift_close'));
    expect(await sync.flush(), 1);
    expect(sync.failedCount, 1);
    expect(sync.pendingCount, 0);
    expect((await sync.failedItems()).single.lastError, 'unknown cashier');
  });

  test('an expired session pauses uploads until the next sign-in', () async {
    final store = MemoryOutboxStore();
    var expired = true;
    final sync = OfflineSync(
      store: store,
      rpc: (name, params) async =>
          expired ? {'ok': false, 'error': 'session expired, sign in again'} : {'ok': true},
    );
    await sync.enqueue(item('x'));
    expect(await sync.flush(), 0);
    expect(sync.needsSignIn, isTrue);
    expect(sync.pendingCount, 1);
    expect(sync.failedCount, 0);
    expired = false;
    sync.signedIn();
    expect(await sync.flush(), 1);
  });

  test('an expired session is reported to the screen straight away', () async {
    var changes = 0;
    final sync = OfflineSync(
      store: MemoryOutboxStore(),
      rpc: (name, params) async => {'ok': false, 'error': 'session expired, sign in again'},
    );
    sync.onChange = () => changes++;
    expect(sync.needsSignIn, isFalse);
    await sync.heartbeat();
    expect(sync.needsSignIn, isTrue);
    expect(changes, greaterThan(0));
    final seen = changes;
    await sync.heartbeat(); // already known: no extra redraw
    expect(changes, seen);
    sync.signedIn();
    expect(sync.needsSignIn, isFalse);
  });

  test('a slow server counts as offline after the timeout', () async {
    final sync = OfflineSync(
      store: MemoryOutboxStore(),
      rpc: (name, params) => Future<dynamic>.delayed(const Duration(milliseconds: 50)).then(
        (_) => throw TimeoutException('slow'),
      ),
    );
    await sync.enqueue(item('t'));
    await sync.flush();
    expect(sync.online, isFalse);
    expect(sync.pendingCount, 1);
  });

  test('reserved numbers are used once each and remembered', () async {
    final store = MemoryOutboxStore();
    var reserveCalls = 0;
    final now = DateTime.utc(2026, 10, 7, 10);
    final sync = OfflineSync(
      store: store,
      clock: () => now,
      rpc: (name, params) async {
        reserveCalls++;
        return {
          'ok': true, 'year_month': '2610', 'first': 101, 'last': 103,
          'day_key': '261007', 'day_first': 7, 'day_last': 9,
        };
      },
    );
    await sync.topUp(below: 2, count: 3);
    expect(reserveCalls, 1);
    final a = await sync.takeNumber();
    final b = await sync.takeNumber();
    expect([a!.monthly, b!.monthly], [101, 102]);
    expect([a.day, b.day], [7, 8]);
    // a restart reads the saved block and continues, never reusing a number
    final restarted = OfflineSync(store: store, clock: () => now, rpc: (n, p) async => {'ok': false});
    await restarted.init();
    expect((await restarted.takeNumber())!.monthly, 103);
    expect(await restarted.takeNumber(), isNull);
  });

  test('order numbers from yesterday are not reused today', () async {
    final store = MemoryOutboxStore();
    var now = DateTime.utc(2026, 10, 7, 10);
    final sync = OfflineSync(
      store: store,
      clock: () => now,
      rpc: (name, params) async => {
        'ok': true, 'year_month': '2610', 'first': 1, 'last': 50,
        'day_key': '261007', 'day_first': 1, 'day_last': 50,
      },
    );
    await sync.topUp();
    now = DateTime.utc(2026, 10, 8, 10);
    final n = await sync.takeNumber();
    expect(n!.monthly, 1);
    expect(n.day, isNull);
  });

  test('sales made with no cashier wait until one is chosen, then upload in order', () async {
    final store = MemoryOutboxStore();
    final sent = <String>[];
    final sync = OfflineSync(
      store: store,
      rpc: (name, params) async {
        sent.add('${params['p_client_id']}:${params['p_cashier_id']}');
        return {'ok': true};
      },
    );
    OutboxItem unassigned(String id) => OutboxItem(
      id: id,
      kind: 'takeout',
      createdAt: DateTime.utc(2026, 10, 7),
      payload: {
        'params': {'p_client_id': id, 'p_cashier_id': null},
        'local': {
          'payment': {'id': id, 'cashierId': null, 'cashierName': ''},
          'order': {'id': id, 'cashierId': null},
        },
      },
    );
    await sync.enqueue(unassigned('s1'));
    await sync.enqueue(unassigned('s2'));
    expect(sync.unassignedCount, 2);
    expect(await sync.flush(), 0);
    expect(sent, isEmpty);
    expect(await sync.assignCashier('cash-7', cashierName: 'Sara'), 2);
    expect(sync.unassignedCount, 0);
    final local = (await sync.pendingItems()).first.payload['local'] as Map;
    expect((local['payment'] as Map)['cashierName'], 'Sara');
    expect(await sync.flush(), 2);
    expect(sent, ['s1:cash-7', 's2:cash-7']);
  });

  test('flush calls running at the same time do not upload twice', () async {
    final store = MemoryOutboxStore();
    var calls = 0;
    final sync = OfflineSync(
      store: store,
      rpc: (name, params) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return {'ok': true};
      },
    );
    await sync.enqueue(item('only'));
    await Future.wait([sync.flush(), sync.flush(), sync.flush()]);
    expect(calls, 1);
  });
}
