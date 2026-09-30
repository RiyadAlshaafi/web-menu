import 'package:intl/intl.dart';

/// `YYMM` plus a sequence. Month keys are `month:YYMM` only — never the day or the shift.
String formatSaleNumber(String? yearMonth, int? sequence) {
  if (yearMonth == null || yearMonth.isEmpty || sequence == null) return '—';
  final width = sequence > 999 ? 4 : 3;
  return '$yearMonth${sequence.toString().padLeft(width, '0')}';
}

/// Admin id. Never the shift sequence.
String adminSaleNumber({required String? yearMonth, required int? monthlyOrderNumber, String? monthlyDisplayNumber}) {
  if (monthlyDisplayNumber != null && RegExp(r'^\d{6,}$').hasMatch(monthlyDisplayNumber)) {
    return monthlyDisplayNumber;
  }
  return formatSaleNumber(yearMonth, monthlyOrderNumber);
}

/// Cashier id. Never the monthly sequence.
String cashierSaleNumber({required String? yearMonth, required int? shiftOrderNumber}) {
  return formatSaleNumber(yearMonth, shiftOrderNumber);
}

/// Tripoli is UTC+2. The monthly key is YYMM only.
String yearMonthInTripoli(DateTime instant) {
  final local = instant.toUtc().add(const Duration(hours: 2));
  final year = (local.year % 100).toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$year$month';
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
