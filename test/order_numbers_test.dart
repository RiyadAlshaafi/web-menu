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

  test('the recorded takeout stays on the September counter when its shift restarts', () {
    final monthly = <String, int>{};
    final shifts = <String, int>{};
    String settle({required DateTime at, required String shiftId}) {
      final yymm = yearMonthInTripoli(at);
      nextScopedCounter(shifts, 'shift:$shiftId');
      final monthNumber = nextScopedCounter(monthly, monthlyCounterScope(yymm));
      return formatSaleNumber(yymm, monthNumber);
    }

    expect(settle(at: DateTime.utc(2026, 9, 29, 19, 46), shiftId: 'shift-a'), '2609001');
    expect(settle(at: DateTime.utc(2026, 9, 29, 19, 49), shiftId: 'shift-a'), '2609002');
    expect(settle(at: DateTime.utc(2026, 9, 29, 20, 12), shiftId: 'shift-a'), '2609003');
    expect(yearMonthInTripoli(DateTime.utc(2026, 9, 29, 23, 59)), '2609');
    expect(yearMonthInTripoli(DateTime.utc(2026, 9, 30, 0, 1)), '2609');
    // Next day, new shift, takeout. Monthly key is still month:2609.
    expect(settle(at: DateTime.utc(2026, 9, 30, 16, 20), shiftId: 'shift-b'), '2609004');
    expect(shifts['shift:shift-b'], 1);
    expect(monthly['month:2609'], 4);
    expect(adminSaleNumber(yearMonth: '2609', monthlyOrderNumber: 4, monthlyDisplayNumber: '2609004'), '2609004');
    expect(cashierSaleNumber(yearMonth: '2609', shiftOrderNumber: 1), '2609001');
  });
}
