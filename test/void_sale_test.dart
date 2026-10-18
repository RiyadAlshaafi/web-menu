import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/ledger.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

Payment _sale(String id, double total, {bool voided = false}) => Payment(
      id: id,
      orderId: 'order-$id',
      tableId: '',
      totalDue: total,
      cashReceived: total,
      changeDue: 0,
      cashierId: 'c1',
      shiftId: 's1',
      paidAt: DateTime.now(),
      voidedAt: voided ? DateTime.now() : null,
      voidReason: voided ? 'Customer left' : null,
    );

CafeStore _store() {
  final store = CafeStore(AppDatabase.instance);
  store.payments = [_sale('kept', 30), _sale('voided', 20, voided: true)];
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sales lists skip a voided sale unless asked, and totals never count it', () {
    final store = _store();
    expect(saleLedgerRows(store).map((row) => row.payment.id), ['kept']);
    final all = saleLedgerRows(store, includeVoided: true);
    expect(all, hasLength(2));
    expect(salesTotal(all), 30);
  });

  test('the drawer does not expect cash from a voided sale', () {
    final store = _store();
    final shift = CashShift(id: 's1', cashierId: 'c1', openedAt: DateTime.now(), openingCash: 10);
    expect(store.expectedDrawer(shift), 40);
  });

  test('a void survives the payment being saved and read back', () {
    final copy = Payment.fromJson(_sale('voided', 20, voided: true).toJson());
    expect(copy.isVoided, isTrue);
    expect(copy.voidReason, 'Customer left');
    expect(Payment.fromJson(_sale('kept', 30).toJson()).isVoided, isFalse);
  });

  test('only the cashier who took the sale may void it', () {
    final store = _store();
    expect(store.canVoid(store.payments.first), isFalse, reason: 'nobody is signed in');
  });
}
