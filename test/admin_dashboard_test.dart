import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_dashboard_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

Payment _sale(String id, double total, DateTime paidAt) => Payment(
      id: id,
      orderId: 'order-$id',
      tableId: 't1',
      tableNumber: '4',
      totalDue: total,
      cashReceived: total,
      changeDue: 0,
      cashierId: 'c1',
      cashierName: 'Sara',
      shiftId: 's1',
      paidAt: paidAt,
    );

ShiftExpense _expense(String id, double amount, {bool voided = false}) => ShiftExpense(
      id: id,
      shiftId: 's1',
      cashierId: 'c1',
      paidToCafe: false,
      amount: amount,
      description: 'Milk $id',
      createdAt: DateTime.now(),
      voided: voided,
    );

CafeStore _store() {
  final store = CafeStore(AppDatabase.instance);
  store.payments = [
    _sale('today', 30, DateTime.now()),
    _sale('old', 100, DateTime.now().subtract(const Duration(days: 40))),
  ];
  store.expenses = [_expense('e1', 12), _expense('e2', 50, voided: true)];
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('totals count this period\'s sales and expenses, not old sales or voided expenses', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminDashboardScreen(), store);

    // This month: 30 in sales, 12 in expenses, 18 net.
    expect(find.text(store.currency.format(30)), findsWidgets);
    expect(find.text(store.currency.format(18)), findsOneWidget);
    expect(find.text(store.currency.format(130)), findsNothing, reason: 'a sale from 40 days ago is outside the month');
    expect(find.text(store.currency.format(-32)), findsNothing, reason: 'a voided expense is not counted');

    await tapVisible(tester, find.text(l10n.summaryToday));
    expect(find.text(store.currency.format(18)), findsOneWidget);
  });

  testWidgets('recent sales list the receipt and its table, and View all opens the sales log', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminDashboardScreen(), store);

    expect(find.textContaining(l10n.adminTableNumber('4')), findsWidgets);
    expect(find.text('Milk e1'), findsOneWidget);
    expect(find.text('Milk e2'), findsNothing, reason: 'voided expenses stay off the recent list');

    await tapVisible(tester, find.text(l10n.dashboardViewAll).first);
    expect(find.text('page /admin/sales'), findsOneWidget);
  });

  testWidgets('View all on recent expenses opens the wages page', (tester) async {
    await pumpAdminScreen(tester, const AdminDashboardScreen(), _store());

    await tapVisible(tester, find.text(l10n.dashboardViewAll).last);
    expect(find.text('page /admin/wages'), findsOneWidget);
  });
}
