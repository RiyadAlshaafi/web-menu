import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/money.dart';

void main() {
  test('sale numbers pad to 3 digits and grow past 999 without clipping', () {
    expect(formatSaleNumber('2610', 7), '2610007');
    expect(formatSaleNumber('2610', 999), '2610999');
    expect(formatSaleNumber('2610', 1000), '26101000');
    expect(formatSaleNumber(null, 5), '—');
    expect(formatSaleNumber('0000', 7).substring(4), '007');
    expect(formatSaleNumber('0000', 999).substring(4), '999');
    expect(formatSaleNumber('0000', 1000).substring(4), '1000');
  });

  test('Tripoli helpers cross midnight and the month boundary', () {
    final beforeMidnight = DateTime.utc(2026, 9, 29, 21, 59);
    final afterMidnight = DateTime.utc(2026, 9, 29, 22, 1);
    expect(yearMonthInTripoli(beforeMidnight), '2609');
    expect(yearMonthInTripoli(afterMidnight), '2609');
    expect(dailyCounterScope(beforeMidnight), 'day:260929');
    expect(dailyCounterScope(afterMidnight), 'day:260930');

    final octoberEnd = DateTime.utc(2026, 10, 31, 22, 30);
    expect(yearMonthInTripoli(octoberEnd), '2611');
    expect(dailyCounterScope(octoberEnd), 'day:261101');
  });
}
