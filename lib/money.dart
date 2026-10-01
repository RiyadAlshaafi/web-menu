import 'package:intl/intl.dart';

/// `YYMM` plus a sequence. Pads to at least 3 digits and never clips a longer one.
String formatSaleNumber(String? yearMonth, int? sequence) {
  if (yearMonth == null || yearMonth.isEmpty || sequence == null) return '—';
  final text = sequence.toString();
  final seq = text.length >= 3 ? text : text.padLeft(3, '0');
  return '$yearMonth$seq';
}

/// Admin id. The sequence is the monthly counter, not the daily one.
String adminSaleNumber({required String? yearMonth, required int? monthlyOrderNumber, String? monthlyDisplayNumber}) {
  if (monthlyOrderNumber == null) return monthlyDisplayNumber ?? '—';
  return formatSaleNumber(yearMonth, monthlyOrderNumber);
}

/// Cashier id. The sequence is the daily counter.
String cashierSaleNumber({required String? yearMonth, required int? shiftOrderNumber}) {
  return formatSaleNumber(yearMonth, shiftOrderNumber);
}

DateTime _tripoli(DateTime instant) => instant.toUtc().add(const Duration(hours: 2));

/// Tripoli is UTC+2. The monthly key is YYMM only.
String yearMonthInTripoli(DateTime instant) {
  final local = _tripoli(instant);
  final year = (local.year % 100).toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$year$month';
}

/// Calendar day in Tripoli, `day:YYMMDD`. A new day is a new key. A new shift is not.
String dailyCounterScope(DateTime instant) {
  final local = _tripoli(instant);
  final year = (local.year % 100).toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return 'day:$year$month$day';
}

int nextScopedCounter(Map<String, int> counters, String scope) {
  final next = (counters[scope] ?? 0) + 1;
  counters[scope] = next;
  return next;
}

String monthlyCounterScope(String yearMonth) => 'month:$yearMonth';

class CafeMoney {
  const CafeMoney(this.locale);

  final String locale;
  static final NumberFormat _digits = NumberFormat('#,##0.000', 'en');

  String format(num value) {
    final amount = _digits.format(value);
    return locale == 'ar' ? '$amount د.ل' : '$amount LYD';
  }
}
