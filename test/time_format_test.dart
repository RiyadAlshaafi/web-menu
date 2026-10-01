import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/time_format.dart';

void main() {
  test('stored UTC timestamps display as Tripoli time', () {
    expect(formatTripoliDateTime(DateTime.utc(2026, 10, 1, 22, 25)), '2026-10-02 00:25');
    expect(formatTripoliDateTime(DateTime.utc(2026, 10, 1, 19, 1)), '2026-10-01 21:01');
    expect(formatTripoliTime(DateTime.utc(2026, 10, 1, 22, 25)), '00:25');
    expect(formatTripoliDate(DateTime.utc(2026, 10, 1, 22, 25)), '2026-10-02');
  });

  test('a local DateTime matches its UTC equivalent', () {
    final utc = DateTime.utc(2026, 10, 1, 22, 25);
    final local = utc.toLocal();
    expect(formatTripoliDateTime(local), formatTripoliDateTime(utc));
    expect(formatTripoliDateTime(local), '2026-10-02 00:25');
  });

  test('date filters use Tripoli calendar days and include the whole end day', () {
    final paid = DateTime.utc(2026, 10, 1, 22, 25);
    expect(inTripoliDateRange(paid, from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 2)), isTrue);
    expect(inTripoliDateRange(paid, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 1)), isFalse);
    expect(inTripoliDateRange(DateTime.utc(2026, 10, 2, 21, 59), to: DateTime(2026, 10, 2)), isTrue);
    expect(inTripoliDateRange(DateTime.utc(2026, 10, 2, 22, 0), to: DateTime(2026, 10, 2)), isFalse);
  });
}
