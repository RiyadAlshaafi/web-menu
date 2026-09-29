import 'package:intl/intl.dart';

/// Libyan dinar, three millièmes. English shows LYD; Arabic shows د.ل.
class CafeMoney {
  const CafeMoney(this.locale);

  final String locale;
  static final NumberFormat _digits = NumberFormat('#,##0.000', 'en');

  String format(num value) {
    final amount = _digits.format(value);
    return locale == 'ar' ? '$amount د.ل' : '$amount LYD';
  }
}
