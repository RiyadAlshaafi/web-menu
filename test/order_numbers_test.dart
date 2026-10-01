import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/money.dart';

void main() {
  test('monthly scope is year and month only', () {
    expect(monthlyCounterScope('2609'), 'month:2609');
    expect(monthlyCounterScope('2609'), isNot(contains('29')));
    expect(monthlyCounterScope('2609'), isNot(contains('30')));
    expect(monthlyCounterScope('2610'), 'month:2610');
  });

  test('admin number keeps counting across a day change and takeout', () {
    final counter = <String, int>{};
    int next(String yearMonth) {
      final key = monthlyCounterScope(yearMonth);
      final value = (counter[key] ?? 0) + 1;
      counter[key] = value;
      return value;
    }

    expect(formatSaleNumber('2609', next('2609')), '2609001');
    expect(formatSaleNumber('2609', next('2609')), '2609002');
    expect(formatSaleNumber('2609', next('2609')), '2609003');
    // Next calendar day, still September, including a takeout. Same key.
    expect(formatSaleNumber('2609', next('2609')), '2609004');
    expect(formatSaleNumber('2609', next('2609')), '2609005');
    // A new shift uses a different key and must not affect this one.
    expect(counter['month:2609'], 5);
    expect(counter.containsKey('shift:anything'), isFalse);
  });

  test('shift number can restart while the monthly number does not', () {
    expect(formatSaleNumber('2609', 1), '2609001');
    expect(formatSaleNumber('2609', 4), '2609004');
    expect(formatSaleNumber('2609', 1000), '26091000');
  });

  test('cashier resets at midnight and admin keeps counting, including past 999', () {
    final daily = <String, int>{};
    final monthly = <String, int>{};

    ({String cashier, String admin}) issue(DateTime at) {
      final yymm = yearMonthInTripoli(at);
      final dayNumber = nextScopedCounter(daily, dailyCounterScope(at));
      final monthNumber = nextScopedCounter(monthly, monthlyCounterScope(yymm));
      return (
        cashier: cashierSaleNumber(yearMonth: yymm, shiftOrderNumber: dayNumber),
        admin: adminSaleNumber(yearMonth: yymm, monthlyOrderNumber: monthNumber),
      );
    }

    // 23:59 and 00:01 in Tripoli, still September.
    final beforeMidnight = DateTime.utc(2026, 9, 29, 21, 59);
    final afterMidnight = DateTime.utc(2026, 9, 29, 22, 1);
    expect(yearMonthInTripoli(beforeMidnight), '2609');
    expect(yearMonthInTripoli(afterMidnight), '2609');
    expect(dailyCounterScope(beforeMidnight), isNot(dailyCounterScope(afterMidnight)));

    final first = issue(beforeMidnight);
    final second = issue(afterMidnight);
    expect(first.cashier, '2609001');
    expect(second.cashier, '2609001');
    expect(first.admin, '2609001');
    expect(second.admin, '2609002');

    expect(formatSaleNumber('2610', 1), '2610001');
    expect(formatSaleNumber('2610', 999), '2610999');
    expect(formatSaleNumber('2610', 1000), '26101000');
    expect(formatSaleNumber('2610', 99999), '261099999');
    expect(monthly.containsKey('month:2609'), isTrue);
    expect(daily.keys.every((key) => key.startsWith('day:')), isTrue);
    expect(daily.keys.any((key) => key.startsWith('shift:')), isFalse);
  });
}
