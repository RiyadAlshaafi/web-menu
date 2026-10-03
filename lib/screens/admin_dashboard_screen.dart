import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ledger.dart';
import '../l10n/l10n_ext.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../time_format.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/metric_trio.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final sales = saleLedgerRows(store);
    final expenses = expenseLedgerRows(store);
    final today = tripoliToday();
    final month = summaryWindow();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: ListView(
        children: [
          Text(context.l10n.navDashboard, style: CafeTheme.display.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final salesCard = _listCard(
                context,
                title: context.l10n.dashboardRecentSales,
                onViewAll: () => context.go('/admin/sales'),
                child: Column(
                  children: [
                    for (final row in sales.take(10))
                      ListTile(
                        dense: true,
                        title: Text(store.receiptNumber(row.payment)),
                        subtitle: Text(
                          '${formatTripoliDateTime(row.payment.paidAt)} · ${row.takeout ? context.l10n.serviceTakeout : row.tableNumber} · ${row.cashierName}',
                        ),
                        trailing: Text(store.currency.format(row.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              );
              final expenseCard = _listCard(
                context,
                title: context.l10n.dashboardRecentExpenses,
                onViewAll: () => context.go('/admin/wages'),
                child: Column(
                  children: [
                    for (final row in expenses.take(10))
                      ListTile(
                        dense: true,
                        title: Text(row.shortId),
                        subtitle: Text(
                          '${formatTripoliDateTime(row.createdAt)} · ${row.paidToCafe ? context.l10n.expenseTypeCafe : context.l10n.expenseTypeWithdrawal}',
                        ),
                        trailing: Text(
                          store.currency.format(-row.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: CafeColors.alert),
                        ),
                      ),
                  ],
                ),
              );
              if (stacked) {
                return Column(children: [salesCard, const SizedBox(height: 12), expenseCard]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: salesCard),
                  const SizedBox(width: 12),
                  Expanded(child: expenseCard),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _metrics(context, store, today, '${context.l10n.summaryToday} — ${DateFormat.yMMMd().format(today.from!)}'),
          const SizedBox(height: 16),
          _metrics(
            context,
            store,
            month,
            '${context.l10n.summaryThisMonth} — ${DateFormat.yMMMM().format(month.from!)}',
          ),
        ],
      ),
    );
  }

  Widget _metrics(BuildContext context, CafeStore store, SummaryWindow window, String title) {
    final sales = saleLedgerRows(store, from: window.from, to: window.to).fold<double>(0, (sum, row) => sum + row.total);
    final expenses = expenseLedgerRows(store, from: window.from, to: window.to).fold<double>(0, (sum, row) => sum + row.amount);
    return MetricTrio(
      title: title,
      subtitle: '',
      salesLabel: context.l10n.summarySales,
      sales: store.currency.format(sales),
      expensesLabel: context.l10n.summaryExpenses,
      expenses: store.currency.format(-expenses),
      netLabel: context.l10n.summaryNet,
      net: store.currency.format(sales - expenses),
    );
  }

  Widget _listCard(BuildContext context, {required String title, required VoidCallback onViewAll, required Widget child}) {
    return SoftCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
              TextButton(onPressed: onViewAll, child: Text(context.l10n.dashboardViewAll)),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
