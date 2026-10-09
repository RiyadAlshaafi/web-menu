import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/live_updates.dart';
import 'package:menu_web_v1/models/models.dart';

CafeOrder order(String id, OrderStatus status) => CafeOrder(
  id: id,
  tableId: 't1',
  tableNumber: '1',
  status: status,
  createdAt: DateTime.utc(2026, 10, 9),
  lines: const [],
);

void main() {
  group('live update channel', () {
    test('a cashier or admin device listens to its whole cafe', () {
      expect(AppDatabase.liveTopic(restaurantId: 'r1'), 'cafe:r1');
    });

    test('a guest listens only to its own table, never to the whole cafe', () {
      expect(AppDatabase.liveTopic(restaurantId: 'r1', guestSlug: 'abc123'), 'guest:abc123');
    });
  });

  group('new order alert', () {
    test('the first load never alerts: everything on screen is already known', () {
      final alerts = NewOrderWatch();
      expect(alerts.newOrders([order('a', OrderStatus.received)]), isEmpty);
    });

    test('a guest order that appears later alerts once', () {
      final alerts = NewOrderWatch()..newOrders([order('a', OrderStatus.received)]);
      final fresh = alerts.newOrders([order('a', OrderStatus.received), order('b', OrderStatus.received)]);
      expect(fresh.map((o) => o.id), ['b']);
      expect(alerts.newOrders([order('a', OrderStatus.preparing), order('b', OrderStatus.received)]), isEmpty,
          reason: 'a status change is not a new order');
    });

    test('paid orders (quick takeout) never alert', () {
      final alerts = NewOrderWatch()..newOrders(const []);
      expect(alerts.newOrders([order('t', OrderStatus.paid)]), isEmpty);
    });

    test('forgetting the device (sign-out) makes the next load a first load again', () {
      final alerts = NewOrderWatch()..newOrders(const []);
      alerts.reset();
      expect(alerts.newOrders([order('a', OrderStatus.received)]), isEmpty);
    });
  });
}
