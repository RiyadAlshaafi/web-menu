import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/sales_log_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

Payment _sale({DateTime? voidedAt}) => Payment(
      id: 'a',
      orderId: 'order-a',
      tableId: 't4',
      tableNumber: '4',
      totalDue: 25,
      cashReceived: 25,
      changeDue: 0,
      cashierId: 'c1',
      cashierName: 'Sara',
      shiftId: 's1',
      paidAt: DateTime.now(),
      paymentTypeNameEn: 'Cash',
      voidedAt: voidedAt,
      voidReason: voidedAt == null ? null : 'left',
    );

/// Opens the sale's details from its row in the log.
Future<void> _openSale(WidgetTester tester, Payment sale) async {
  await pumpAdminScreen(tester, const SalesLogScreen(), CafeStore(AppDatabase.instance)..payments = [sale]);
  await tester.tap(find.descendant(of: find.byType(ListView), matching: find.byType(InkWell)).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a paid sale can print its receipt again from the details', (tester) async {
    await _openSale(tester, _sale());

    expect(find.widgetWithText(OutlinedButton, l10n.cashierPrintReceipt), findsOneWidget);
  });

  testWidgets('a voided sale has no print button, so it cannot pass as paid', (tester) async {
    await _openSale(tester, _sale(voidedAt: DateTime.now()));

    expect(find.text(l10n.cashierPrintReceipt), findsNothing);
  });
}
