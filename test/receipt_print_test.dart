import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/receipt_print.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dine-in and takeout receipts share one pdf builder', () async {
    final store = CafeStore(AppDatabase.instance);
    store.cafe = {'name': 'مقهى الاختبار', 'serviceChargeRate': 0.10, 'autoPrintReceipt': true};
    store.locale = 'en';
    final l10n = lookupAppLocalizations(const Locale('en'));
    Payment paymentFor(String id, String service) {
      final order = CafeOrder(
        id: id,
        tableId: 't1',
        tableNumber: service == 'takeout' ? 'Takeout' : '4',
        status: OrderStatus.paid,
        createdAt: DateTime.utc(2026, 10, 6, 10),
        serviceType: service,
        lines: [OrderLine(menuItemId: 'c', name: 'قهوة', qty: 1, unitPrice: 3, listUnitPrice: 4)],
      );
      store.orders.add(order);
      return Payment(
        id: 'p-$id',
        orderId: id,
        tableId: 't1',
        totalDue: service == 'takeout' ? 3 : 3.3,
        cashReceived: service == 'takeout' ? 3 : 3.3,
        changeDue: 0,
        cashierId: 'c1',
        shiftId: 's1',
        paidAt: DateTime.utc(2026, 10, 6, 10),
        monthlyDisplayNumber: '2610001',
        shiftOrderNumber: 1,
      );
    }
    final dine = await receiptPdfBytes(store, paymentFor('dine', 'dine_in'), l10n);
    final takeout = await receiptPdfBytes(store, paymentFor('out', 'takeout'), l10n);
    expect(dine, isNotEmpty);
    expect(takeout, isNotEmpty);
    expect(String.fromCharCodes(dine), contains('NotoNaskhArabic'));
    expect(store.autoPrintReceipt, isTrue);
  });
}
