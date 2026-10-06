import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/dev_logs.dart';

void main() {
  test('a receipts export groups lines into one receipt', () {
    const csv = '''
paid_at,receipt,monthly,table,service,item,qty,unit_price,total_due
2026-10-01T10:00:00Z,2510001,2510009,4,dine_in,Coffee,2,3.5,7
2026-10-01T10:00:00Z,2510001,2510009,4,dine_in,Water,1,1,7
''';
    final backup = parseDevLogFiles({'all-receipts.csv': csv});
    expect(backup.receipts, hasLength(1));
    expect(backup.receipts.single.lines, hasLength(2));
    expect(backup.receipts.single.receipt, '2510001');
    expect(backup.expenses, isEmpty);
  });

  test('a file with the wrong header is rejected before any receipt is kept', () {
    expect(
      () => parseDevLogFiles({'notes.csv': 'hello,world\n1,2\n'}),
      throwsFormatException,
    );
  });

  test('an expenses export is accepted on its own', () {
    const csv = '''
created_at,amount,description,kind,paid_to_cafe
2026-10-01T11:00:00Z,12.5,Milk,cash_out,false
''';
    final backup = parseDevLogFiles({'all-expenses.csv': csv});
    expect(backup.expenses, hasLength(1));
    expect(backup.expenses.single.paidToCafe, isFalse);
    expect(backup.receipts, isEmpty);
  });
}