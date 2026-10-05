import 'models/models.dart';

/// Records one paid takeout sale. Does not reuse an open order and does not
/// change the counter table's status. Service is not added.
String? applyQuickTakeout({
  required List<CafeOrder> orders,
  required List<Payment> payments,
  required CafeTable counter,
  required List<OrderLine> lines,
  required String? paymentTypeId,
  required String cashierId,
  required String shiftId,
  required String orderId,
  required String paymentId,
  DateTime? paidAt,
}) {
  final ticket = [
    for (final line in lines)
      if (line.menuItemId.isNotEmpty && line.qty > 0)
        OrderLine(
          menuItemId: line.menuItemId,
          name: line.name,
          qty: line.qty,
          unitPrice: line.unitPrice,
          listUnitPrice: line.listUnitPrice,
        ),
  ];
  if (ticket.isEmpty) return 'cart is empty';
  final due = ticket.fold<double>(0, (sum, line) => sum + line.total);
  final when = paidAt ?? DateTime.now().toUtc();
  orders.add(
    CafeOrder(
      id: orderId,
      tableId: counter.id,
      tableNumber: counter.number,
      status: OrderStatus.paid,
      createdAt: when,
      lines: ticket,
      cashierId: cashierId,
      paymentTypeId: paymentTypeId,
      serviceType: 'takeout',
    ),
  );
  payments.add(
    Payment(
      id: paymentId,
      orderId: orderId,
      tableId: counter.id,
      totalDue: due,
      cashReceived: due,
      changeDue: 0,
      cashierId: cashierId,
      shiftId: shiftId,
      paidAt: when,
      paymentTypeId: paymentTypeId,
    ),
  );
  return null;
}

bool isServiceCounter(CafeTable table) => table.number.trim().toLowerCase() == 'takeout';
