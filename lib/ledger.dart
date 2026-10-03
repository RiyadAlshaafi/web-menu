import 'models/models.dart';
import 'money.dart';
import 'state/cafe_store.dart';
import 'time_format.dart';

class SaleLedgerRow {
  const SaleLedgerRow({
    required this.payment,
    required this.tableNumber,
    required this.takeout,
    required this.cashierName,
    required this.itemCount,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final Payment payment;
  final String tableNumber;
  final bool takeout;
  final String cashierName;
  final int itemCount;
  final List<OrderLine> lines;
  final double subtotal;
  final double discount;
  final double total;
}

SaleLedgerRow saleLedgerRow(CafeStore store, Payment payment) {
  final table = store.tables.where((item) => item.id == payment.tableId);
  final order = store.orders.where((item) => item.id == payment.orderId);
  final lines = order.isEmpty ? const <OrderLine>[] : order.first.lines;
  final discount = lines.fold<double>(0, (sum, line) => sum + line.discountAmount);
  final charged = lines.fold<double>(0, (sum, line) => sum + line.total);
  final cashier = store.cashiers.where((item) => item.id == payment.cashierId);
  return SaleLedgerRow(
    payment: payment,
    tableNumber: order.isNotEmpty && order.first.serviceType == 'takeout'
        ? ''
        : (table.isEmpty ? '' : table.first.number),
    takeout: order.isNotEmpty && order.first.serviceType == 'takeout',
    cashierName: cashier.isEmpty ? payment.cashierId : cashier.first.name,
    itemCount: order.isEmpty ? 0 : order.first.itemCount,
    lines: lines,
    subtotal: charged + discount,
    discount: discount,
    total: payment.totalDue,
  );
}

List<SaleLedgerRow> saleLedgerRows(
  CafeStore store, {
  String query = '',
  String? cashierId,
  String? ownCashierId,
  String? tableId,
  String? methodId,
  String? shiftId,
  DateTime? from,
  DateTime? to,
}) {
  final needle = query.trim().toLowerCase();
  final list = store.payments.where((payment) {
    if (ownCashierId != null && payment.cashierId != ownCashierId) return false;
    if (cashierId != null && payment.cashierId != cashierId) return false;
    if (tableId != null && payment.tableId != tableId) return false;
    if (methodId != null && payment.paymentTypeId != methodId) return false;
    if (shiftId != null && payment.shiftId != shiftId) return false;
    if (!inTripoliDateRange(payment.paidAt, from: from, to: to)) return false;
    if (needle.isEmpty) return true;
    final row = saleLedgerRow(store, payment);
    final receipt = store.receiptNumber(payment);
    final order = store.orderNumber(payment.shiftOrderNumber);
    return row.tableNumber.toLowerCase().contains(needle) ||
        row.cashierName.toLowerCase().contains(needle) ||
        saleQueryMatches(needle, receipt: receipt, order: order);
  }).map((payment) => saleLedgerRow(store, payment)).toList();
  list.sort((a, b) => b.payment.paidAt.compareTo(a.payment.paidAt));
  return list;
}

bool _expenseMatchesCategory(CafeStore store, ShiftExpense expense, String categoryId) {
  if (expense.categoryId == categoryId) return true;
  if (expense.categoryId != null) return false;
  final match = store.expenseCategories.where((item) => item.id == categoryId);
  if (match.isEmpty) return false;
  if (match.first.nameEn == 'Café Expense') return expense.paidToCafe;
  if (match.first.nameEn == 'Cash Withdrawal') return !expense.paidToCafe;
  return false;
}

List<ShiftExpense> expenseLedgerRows(
  CafeStore store, {
  String query = '',
  String? cashierId,
  String? categoryId,
  DateTime? from,
  DateTime? to,
}) {
  final needle = query.trim().toLowerCase();
  final list = store.expenses.where((expense) {
    if (expense.voided) return false;
    if (cashierId != null && expense.cashierId != cashierId) return false;
    if (categoryId != null && !_expenseMatchesCategory(store, expense, categoryId)) {
      return false;
    }
    if (!inTripoliDateRange(expense.createdAt, from: from, to: to)) return false;
    if (needle.isEmpty) return true;
    final cashier = store.cashiers.where((item) => item.id == expense.cashierId);
    final name = cashier.isEmpty ? '' : cashier.first.name.toLowerCase();
    return expense.description.toLowerCase().contains(needle) ||
        expense.shortId.toLowerCase().contains(needle) ||
        name.contains(needle);
  }).toList();
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}

class SummaryWindow {
  const SummaryWindow({required this.from, required this.to, required this.monthly});

  final DateTime? from;
  final DateTime? to;
  final bool monthly;
}

SummaryWindow summaryWindow({DateTime? from, DateTime? to, DateTime? now}) {
  if (from != null || to != null) {
    return SummaryWindow(from: from, to: to, monthly: false);
  }
  final clock = toTripoli(now ?? DateTime.now());
  return SummaryWindow(
    from: DateTime(clock.year, clock.month, 1),
    to: DateTime(clock.year, clock.month, clock.day),
    monthly: true,
  );
}

SummaryWindow tripoliToday([DateTime? now]) {
  final clock = toTripoli(now ?? DateTime.now());
  final day = DateTime(clock.year, clock.month, clock.day);
  return SummaryWindow(from: day, to: day, monthly: false);
}
