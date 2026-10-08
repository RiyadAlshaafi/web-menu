import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ledger.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../time_format.dart';
import '../widgets/tawla_ui.dart';

enum _Period { today, month, range }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const salesColor = Color(0xFF2F6F8F);
  static const expensesColor = Color(0xFFE8A48C);

  _Period period = _Period.month;
  DateTimeRange? range;

  SummaryWindow get _window => switch (period) {
        _Period.today => tripoliToday(),
        _Period.month => summaryWindow(),
        _Period.range => summaryWindow(from: range?.start, to: range?.end),
      };

  Future<void> _pickRange(CafeStore store) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: range ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (picked == null) return;
    setState(() {
      range = picked;
      period = _Period.range;
    });
    store.alignSalesWindow(from: picked.start, to: picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final window = _window;
    final sales = saleLedgerRows(store, from: window.from, to: window.to);
    final expenses = expenseLedgerRows(store, from: window.from, to: window.to);
    final salesTotal = sales.fold<double>(0, (sum, row) => sum + row.total);
    final expensesTotal = expenses.fold<double>(0, (sum, row) => sum + row.amount);
    final recentSales = saleLedgerRows(store);
    final recentExpenses = expenseLedgerRows(store);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedPills<_Period>(
              options: [
                (_Period.today, context.l10n.summaryToday),
                (_Period.month, context.l10n.summaryThisMonth),
                (_Period.range, context.l10n.summarySelectedRange),
              ],
              selected: period,
              onSelected: (value) {
                if (value == _Period.range) {
                  _pickRange(store);
                  return;
                }
                setState(() => period = value);
              },
            ),
            Text(_rangeLabel(window, store.locale), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TawlaTokens.muted)),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              FigureCard(
                label: context.l10n.summarySales,
                dot: salesColor,
                value: store.currency.format(salesTotal),
                caption: context.l10n.dashboardSettledReceipts(sales.length),
              ),
              FigureCard(
                label: context.l10n.summaryExpenses,
                dot: CafeColors.terracotta,
                value: store.currency.format(expensesTotal),
                valueColor: CafeColors.terracottaDark,
                caption: context.l10n.dashboardExpensesCaption,
              ),
              FigureCard(
                label: context.l10n.summaryNet,
                value: store.currency.format(salesTotal - expensesTotal),
                caption: context.l10n.dashboardNetCaption,
                dark: true,
              ),
            ];
            if (constraints.maxWidth < 720) {
              return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: card)]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[2]),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _chart(context, store, window),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final salesPanel = _listPanel(
              context,
              title: context.l10n.dashboardRecentSales,
              onViewAll: () => context.go('/admin/sales'),
              rows: [for (final row in recentSales.take(5)) _saleRow(context, store, row)],
            );
            final expensesPanel = _listPanel(
              context,
              title: context.l10n.dashboardRecentExpenses,
              onViewAll: () => context.go('/admin/wages'),
              rows: [for (final row in recentExpenses.take(5)) _expenseRow(context, store, row)],
            );
            if (constraints.maxWidth < 900) {
              return Column(children: [salesPanel, const SizedBox(height: 16), expensesPanel]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: salesPanel),
                const SizedBox(width: 16),
                Expanded(child: expensesPanel),
              ],
            );
          },
        ),
      ],
    );
  }

  String _rangeLabel(SummaryWindow window, String locale) {
    final from = window.from;
    final to = window.to;
    if (from == null || to == null) return '';
    if (from == to) return DateFormat.yMMMd(locale).format(from);
    if (from.year == to.year && from.month == to.month) return '${from.day} – ${to.day} ${DateFormat.MMMM(locale).format(to)}';
    return '${DateFormat.MMMd(locale).format(from)} – ${DateFormat.yMMMd(locale).format(to)}';
  }

  /// Daily bars: the two weeks up to the end of the period, or the chosen range (up to a month).
  Widget _chart(BuildContext context, CafeStore store, SummaryWindow window) {
    final end = window.to ?? tripoliToday().to!;
    final custom = period == _Period.range && window.from != null;
    var first = custom ? window.from! : DateTime(end.year, end.month, end.day - 13);
    if (end.difference(first).inDays > 30) first = DateTime(end.year, end.month, end.day - 30);
    final days = <DateTime>[
      for (var day = first; !day.isAfter(end); day = DateTime(day.year, day.month, day.day + 1)) day,
    ];
    final points = [
      for (final day in days)
        (
          day: day,
          sales: saleLedgerRows(store, from: day, to: day).fold<double>(0, (sum, row) => sum + row.total),
          expenses: expenseLedgerRows(store, from: day, to: day).fold<double>(0, (sum, row) => sum + row.amount),
        ),
    ];
    final peak = points.fold<double>(0, (max, p) => [max, p.sales, p.expenses].reduce((a, b) => a > b ? a : b));
    Widget legend(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TawlaTokens.muted)),
          ],
        );
    Widget bar(double value, Color color) => Flexible(
          child: FractionallySizedBox(
            heightFactor: peak == 0 ? 0 : (value / peak).clamp(0.0, 1.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 18),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ),
          ),
        );
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PanelTitle(context.l10n.dashboardSalesVsExpenses),
              legend(salesColor, context.l10n.summarySales),
              legend(expensesColor, context.l10n.summaryExpenses),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 180,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CafeColors.line))),
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Semantics(
                      label: context.l10n.dashboardChartBar(
                        DateFormat.MMMd(store.locale).format(p.day),
                        store.currency.format(p.sales),
                        store.currency.format(p.expenses),
                      ),
                      child: Tooltip(
                        message: '${DateFormat.MMMd(store.locale).format(p.day)} · ${store.currency.format(p.sales)} · ${store.currency.format(p.expenses)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              bar(p.sales, salesColor),
                              const SizedBox(width: 2),
                              bar(p.expenses, expensesColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final p in points)
                  Expanded(
                    child: Text('${p.day.day}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listPanel(BuildContext context, {required String title, required VoidCallback onViewAll, required List<Widget> rows}) {
    return TawlaPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                Expanded(child: PanelTitle(title)),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(foregroundColor: CafeSurfaces.of(context).header),
                  child: Text(
                    context.l10n.dashboardViewAll,
                    style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const SizedBox(height: 16)
          else
            for (final row in rows) ...[const Divider(height: 1, color: TawlaTokens.hairline), row],
        ],
      ),
    );
  }

  Widget _listRow({required Widget lead, required String title, required String subtitle, required String amount, Color? amountColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: amountColor ?? CafeColors.ink)),
        ],
      ),
    );
  }

  Widget _tile(Widget child, Color background) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: child,
      );

  Widget _saleRow(BuildContext context, CafeStore store, SaleLedgerRow row) {
    final header = CafeSurfaces.of(context).header;
    final place = row.takeout ? context.l10n.serviceTakeout : context.l10n.adminTableNumber(row.tableNumber);
    return _listRow(
      lead: _tile(
        Text(row.takeout ? 'TO' : 'T-${row.tableNumber}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: header)),
        const Color(0xFFE1ECF2),
      ),
      title: context.l10n.salesReceiptLine(store.receiptNumber(row.payment)),
      subtitle: '$place · ${row.cashierName} · ${formatTripoliTime(row.payment.paidAt)}',
      amount: store.currency.format(row.total),
    );
  }

  Widget _expenseRow(BuildContext context, CafeStore store, ShiftExpense row) {
    final who = expenseCashierName(store, row);
    return _listRow(
      lead: _tile(const Icon(Icons.account_balance_wallet_outlined, size: 18, color: CafeColors.terracottaDark), CafeColors.terracottaSoft),
      title: row.description.isEmpty ? row.shortId : row.description,
      subtitle: [store.expenseCategoryLabel(row), if (who.isNotEmpty) who, formatTripoliTime(row.createdAt)].join(' · '),
      amount: store.currency.format(row.amount),
      amountColor: CafeColors.terracottaDark,
    );
  }
}
