import '../models/models.dart';

const salesHistoryWindow = Duration(days: 45);
const salesPageSize = 50;

DateTime salesHistoryCutoff(DateTime now) => now.toUtc().subtract(salesHistoryWindow);

class SalesSlice<T> {
  const SalesSlice(this.rows, this.hasMore);

  final List<T> rows;
  final bool hasMore;
}

SalesSlice<Payment> slicePayments(
  List<Payment> all, {
  required DateTime from,
  DateTime? to,
  required int limit,
}) {
  final rows = all.where((payment) {
    if (payment.paidAt.isBefore(from)) return false;
    if (to != null && payment.paidAt.isAfter(to)) return false;
    return true;
  }).toList()
    ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
  return SalesSlice(rows.take(limit).toList(), rows.length > limit);
}

List<CafeOrder> ordersForLive(
  List<CafeOrder> all, {
  required DateTime from,
  Set<String> extraIds = const {},
}) {
  return all.where((order) {
    if (order.status != OrderStatus.paid) return true;
    if (!order.createdAt.isBefore(from)) return true;
    return extraIds.contains(order.id);
  }).toList();
}
