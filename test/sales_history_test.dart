import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/sales_history.dart';
import 'package:menu_web_v1/models/models.dart';

void main() {
  test('500 payments load one page, an old month still filters, and shift totals stay on the shift', () {
    final now = DateTime.utc(2026, 10, 2, 12);
    final cutoff = salesHistoryCutoff(now);
    final payments = [
      ...List<Payment>.generate(500, (index) {
      final paidAt = now.subtract(Duration(hours: index));
      return Payment(
        id: 'pay-$index',
        orderId: 'order-$index',
        tableId: 'table',
        totalDue: 10,
        cashReceived: 10,
        changeDue: 0,
        cashierId: 'cashier',
        shiftId: 'shift',
        paidAt: paidAt,
        yearMonth: '2610',
        shiftOrderNumber: index + 1,
        monthlyOrderNumber: index + 1,
      );
    }),
      ...List<Payment>.generate(40, (index) {
        return Payment(
          id: 'old-$index',
          orderId: 'old-order-$index',
          tableId: 'table',
          totalDue: 10,
          cashReceived: 10,
          changeDue: 0,
          cashierId: 'cashier',
          shiftId: 'shift',
          paidAt: DateTime.utc(2026, 8, 1).add(Duration(days: index)),
          yearMonth: '2608',
          shiftOrderNumber: 800 + index,
          monthlyOrderNumber: 800 + index,
        );
      }),
    ];

    final first = slicePayments(payments, from: cutoff, limit: salesPageSize);
    expect(first.rows, hasLength(salesPageSize));
    expect(first.hasMore, isTrue);
    expect(first.rows.first.paidAt.isAfter(first.rows.last.paidAt), isTrue);
    expect(first.rows.every((payment) => !payment.paidAt.isBefore(cutoff)), isTrue);

    final more = slicePayments(payments, from: cutoff, limit: salesPageSize * 2);
    expect(more.rows, hasLength(100));

    final august = DateTime.utc(2026, 8, 1);
    final augustEnd = DateTime.utc(2026, 8, 31, 23, 59, 59);
    final oldMonth = slicePayments(payments, from: august, to: augustEnd, limit: salesPageSize);
    expect(oldMonth.rows, isNotEmpty);
    expect(oldMonth.rows.every((payment) => !payment.paidAt.isBefore(august) && !payment.paidAt.isAfter(augustEnd)), isTrue);
    expect(oldMonth.rows.first.yearMonth, '2608');
    expect(oldMonth.rows.first.monthlyOrderNumber, greaterThanOrEqualTo(800));

    final shift = CashShift(
      id: 'shift',
      cashierId: 'cashier',
      openedAt: now,
      openingCash: 0,
      cashSales: 5000,
      transactionCount: 500,
    );
    expect(shift.cashSales, 5000);
    expect(shift.transactionCount, 500);
    expect(first.rows.fold<double>(0, (sum, payment) => sum + payment.totalDue), isNot(shift.cashSales));
  });

  test('open orders stay loaded and old paid orders wait for their payment ids', () {
    final now = DateTime.utc(2026, 10, 2);
    final from = salesHistoryCutoff(now);
    final orders = [
      CafeOrder(id: 'open', tableId: 't', tableNumber: '1', status: OrderStatus.served, createdAt: now.subtract(const Duration(days: 80)), lines: const []),
      CafeOrder(id: 'recent', tableId: 't', tableNumber: '1', status: OrderStatus.paid, createdAt: now.subtract(const Duration(days: 2)), lines: const []),
      CafeOrder(id: 'old', tableId: 't', tableNumber: '1', status: OrderStatus.paid, createdAt: now.subtract(const Duration(days: 80)), lines: const []),
    ];
    final live = ordersForLive(orders, from: from);
    expect(live.map((order) => order.id), ['open', 'recent']);
    final withOld = ordersForLive(orders, from: from, extraIds: {'old'});
    expect(withOld.map((order) => order.id), contains('old'));
  });
}
