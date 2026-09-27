import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/models/models.dart';

void main() {
  test('kitchen status advances one step and does not skip to ready', () {
    expect(OrderStatus.received.next, OrderStatus.preparing);
    expect(OrderStatus.preparing.next, OrderStatus.ready);
    expect(OrderStatus.ready.next, OrderStatus.served);
    expect(OrderStatus.served.next, isNull);
    expect(OrderStatus.received.next, isNot(OrderStatus.ready));
  });

  test('settled line total is unit price times quantity', () {
    final wine = OrderLine(menuItemId: 'wine', name: 'Wine', qty: 3, unitPrice: 20);
    final bread = OrderLine(menuItemId: 'bread', name: 'Bread', qty: 1, unitPrice: 4);
    expect(wine.total, 60);
    expect(wine.total, isNot(wine.unitPrice));

    final order = CafeOrder(
      id: 'order-1',
      tableId: 'table-1',
      tableNumber: '1',
      status: OrderStatus.received,
      createdAt: DateTime.utc(2026, 9, 28),
      lines: [wine, bread],
    );
    expect(order.subtotal, 64);

    const serviceRate = 0.10;
    final due = order.subtotal + (order.subtotal * serviceRate);
    expect(due, closeTo(70.4, 0.001));
  });
}
