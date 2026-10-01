import 'package:intl/intl.dart';

import 'money.dart';

String formatTripoliDateTime(DateTime instant) => DateFormat('y-MM-dd HH:mm').format(toTripoli(instant));

String formatTripoliTime(DateTime instant) => DateFormat('HH:mm').format(toTripoli(instant));

String formatTripoliDate(DateTime instant) => DateFormat('y-MM-dd').format(toTripoli(instant));

String formatTripoliClock(DateTime instant) => DateFormat('HH:mm:ss').format(toTripoli(instant));

String formatTripoliJm(DateTime instant) => DateFormat.jm().format(toTripoli(instant));

/// [from] and [to] are calendar days the user picked. [to] includes that whole Tripoli day.
bool inTripoliDateRange(DateTime instant, {DateTime? from, DateTime? to}) {
  final paid = toTripoli(instant);
  final paidDay = DateTime.utc(paid.year, paid.month, paid.day);
  if (from != null) {
    final start = toTripoli(DateTime.utc(from.year, from.month, from.day));
    if (paidDay.isBefore(DateTime.utc(start.year, start.month, start.day))) return false;
  }
  if (to != null) {
    final end = toTripoli(DateTime.utc(to.year, to.month, to.day));
    if (paidDay.isAfter(DateTime.utc(end.year, end.month, end.day))) return false;
  }
  return true;
}

/// UTC instant of midnight at the start of the picked Tripoli calendar day.
DateTime tripoliDayStartUtc(DateTime picked) => DateTime.utc(picked.year, picked.month, picked.day).subtract(const Duration(hours: 2));

/// UTC instant of 23:59:59 on the picked Tripoli calendar day.
DateTime tripoliDayEndUtc(DateTime picked) => DateTime.utc(picked.year, picked.month, picked.day, 23, 59, 59).subtract(const Duration(hours: 2));
