import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/choice_labels.dart';
import '../core/csv_safe.dart';
import '../core/ledger.dart';
import '../printing/export_pdfs.dart';
import '../printing/receipt_print.dart';
import '../platform/save_bytes.dart';
import '../l10n/l10n_ext.dart';
import '../core/time_format.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/tawla_ui.dart';
import '../widgets/sales_report_dialog.dart';
import '../widgets/void_sale_dialog.dart';

enum _Sort { id, when, table, cashier, items, subtotal, discount, total, method, status }

class SalesLogScreen extends StatefulWidget {
  const SalesLogScreen({super.key, this.ownSalesOnly = false});

  final bool ownSalesOnly;

  @override
  State<SalesLogScreen> createState() => _SalesLogScreenState();
}

class _SalesLogScreenState extends State<SalesLogScreen> {
  final search = TextEditingController();
  DateTime? from;
  DateTime? to;
  String? cashierName;
  String? tableNumber;
  String? methodId;
  String? shiftId;
  _Sort sort = _Sort.when;
  bool ascending = false;
  int page = 0;
  static const pageSize = 12;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final rows = _rows(store);
    final pages = (rows.length / pageSize).ceil().clamp(1, 9999);
    final safePage = page.clamp(0, pages - 1);
    final visible = rows.skip(safePage * pageSize).take(pageSize).toList();
    final own = widget.ownSalesOnly;
    final total = salesTotal(rows);

    final exportCsv = OutlineAction(
      label: context.l10n.salesExportCsv,
      icon: Icons.file_download_outlined,
      height: 52,
      onPressed: () => _exportCsv(store, rows),
    );
    final exportPdf = NavyButton(label: context.l10n.salesExportPdf, height: 52, onPressed: () => _exportPdf(store, rows));
    final search = PageSearchField(
      controller: this.search,
      hint: context.l10n.salesSearchHint,
      onChanged: (_) => setState(() => page = 0),
    );
    final filters = <Widget>[
      _date(context.l10n.salesDateFrom, from, (value) {
        setState(() { from = value; page = 0; });
        store.alignSalesWindow(from: from, to: to);
      }),
      _date(context.l10n.salesDateTo, to, (value) {
        setState(() { to = value; page = 0; });
        store.alignSalesWindow(from: from, to: to);
      }),
      if (own)
        _menu<String?>(
          shiftId,
          [null, ...store.shifts.where((shift) => shift.cashierId == store.currentCashier?.id).map((shift) => shift.id)],
          (id) => id == null ? context.l10n.salesAllShifts : _shiftLabel(store, id),
          (value) => setState(() { shiftId = value; page = 0; }),
        ),
      if (!own)
        _menu<String?>(
          cashierName,
          // Names come from the receipts themselves, so removed cashiers stay filterable and never appear twice.
          [null, ...(store.payments.map((p) => saleLedgerRow(store, p).cashierName).where((n) => n.isNotEmpty).toSet().toList()..sort())],
          (name) => name ?? context.l10n.salesAllCashiers,
          (value) => setState(() { cashierName = value; page = 0; }),
        ),
      if (!own)
        _menu<String?>(
          tableNumber,
          [null, ...(store.payments.map((p) => saleLedgerRow(store, p).tableNumber).where((n) => n.isNotEmpty).toSet().toList()..sort())],
          (number) => number ?? context.l10n.salesAllTables,
          (value) => setState(() { tableNumber = value; page = 0; }),
        ),
      _menu<String?>(
        methodId,
        [null, ...store.paymentTypes.map((item) => item.id)],
        (id) => id == null ? context.l10n.salesAllMethods : store.typeName(id),
        (value) => setState(() { methodId = value; page = 0; }),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (own) ...[
            Row(
              children: [
                Expanded(child: Text(context.l10n.cashierLogScope, style: const TextStyle(color: TawlaTokens.muted, fontWeight: FontWeight.w600))),
                exportCsv,
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: 340, child: search), ...filters]),
          ] else ...[
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                exportCsv,
                const SizedBox(width: 12),
                exportPdf,
                const SizedBox(width: 12),
                const PrintReportButton(height: 52),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: filters),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: TawlaPanel(
              padding: EdgeInsets.zero,
              child: rows.isEmpty
                  ? EmptyHint(context.l10n.salesEmpty)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: WideTable(
                        minWidth: own ? 900 : 1120,
                        child: Column(
                          children: [
                            _header(context),
                            const Divider(height: 1, color: TawlaTokens.hairline),
                            Expanded(
                              child: ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: TawlaTokens.hairline),
                                itemBuilder: (context, index) {
                                  final row = visible[index];
                                  return InkWell(
                                    onTap: () => _detail(context, row),
                                    child: _line(context, store, row),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.salesReceiptsTotal(rows.length, store.currency.format(total)),
                  style: TextStyle(fontSize: 14, fontWeight: own ? FontWeight.w600 : FontWeight.w700, color: own ? TawlaTokens.muted : CafeColors.ink),
                ),
              ),
              Text(context.l10n.salesPage(safePage + 1, pages), style: const TextStyle(color: TawlaTokens.muted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              IconButton(
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                onPressed: safePage == 0 ? null : () => setState(() => page = safePage - 1),
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(foregroundColor: CafeSurfaces.of(context).buttonInk),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                onPressed: safePage >= pages - 1 ? null : () => setState(() => page = safePage + 1),
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(foregroundColor: CafeSurfaces.of(context).buttonInk),
              ),
              if (store.salesHasMore) ...[
                const SizedBox(width: 4),
                OutlineAction(label: context.l10n.salesLoadMore, height: 44, onPressed: () => store.loadMoreSales()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    Widget cell(String label, _Sort column, {int flex = 2, bool end = false}) {
      final active = sort == column;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => setState(() {
            if (sort == column) {
              ascending = !ascending;
            } else {
              sort = column;
              ascending = column == _Sort.when ? false : true;
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Flexible(child: TableHead(label, align: end ? TextAlign.end : TextAlign.start)),
                if (active) Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: TawlaTokens.muted),
              ],
            ),
          ),
        ),
      );
    }

    final own = widget.ownSalesOnly;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          cell(context.l10n.salesReceiptNo, _Sort.id),
          cell(context.l10n.salesColWhen, _Sort.when, flex: 3),
          cell(context.l10n.salesColTable, _Sort.table),
          if (!own) cell(context.l10n.salesColCashier, _Sort.cashier),
          cell(context.l10n.salesColItems, _Sort.items),
          if (!own) cell(context.l10n.salesColSubtotal, _Sort.subtotal, end: true),
          if (!own) cell(context.l10n.salesColDiscount, _Sort.discount, end: true),
          if (!own) cell(context.l10n.salesColTotal, _Sort.total, end: true),
          const SizedBox(width: 20),
          cell(context.l10n.salesColMethod, _Sort.method),
          cell(context.l10n.salesColStatus, _Sort.status),
          if (own) cell(context.l10n.salesColTotal, _Sort.total, end: true),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, CafeStore store, SaleLedgerRow row) {
    final own = widget.ownSalesOnly;
    const body = TextStyle(fontSize: 14, color: CafeColors.ink, fontFeatures: [FontFeature.tabularFigures()]);
    Widget cell(String value, {int flex = 2, bool end = false, TextStyle style = body}) => Expanded(
          flex: flex,
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: end ? TextAlign.end : TextAlign.start, style: style),
        );
    final totalStyle = body.copyWith(fontWeight: FontWeight.w800, color: CafeSurfaces.of(context).header);
    final table = row.takeout ? context.l10n.serviceTakeout : context.l10n.adminTableNumber(row.tableNumber);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.receiptNumber(row.payment), maxLines: 1, overflow: TextOverflow.ellipsis, style: body.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  context.l10n.cashierOrderNumber(store.orderNumber(row.payment.shiftOrderNumber)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: TawlaTokens.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          cell(formatTripoliDateTime(row.payment.paidAt), flex: 3),
          if (own)
            Expanded(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusBadge(table, tone: row.takeout ? BadgeTone.terracotta : BadgeTone.navy),
              ),
            )
          else
            cell(table),
          if (!own) cell(row.cashierName),
          cell(context.l10n.cashierItemsCount('${row.itemCount}')),
          if (!own) cell(store.currency.amount(row.subtotal), end: true),
          if (!own)
            cell(
              row.discount == 0 ? '—' : '−${store.currency.amount(row.discount)}',
              end: true,
              style: body.copyWith(color: CafeColors.terracottaDark),
            ),
          if (!own) cell(store.currency.format(row.total), end: true, style: totalStyle),
          const SizedBox(width: 20),
          cell(store.paymentLabel(row.payment)),
          Expanded(
            flex: 2,
            child: Align(alignment: AlignmentDirectional.centerStart, child: _statusBadge(context, row.payment)),
          ),
          if (own) cell(store.currency.format(row.total), end: true, style: totalStyle),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, Payment payment) => payment.isVoided
      ? StatusBadge(context.l10n.voidStatus, tone: BadgeTone.danger, dot: true)
      : StatusBadge(context.l10n.salesPaid, tone: BadgeTone.success, dot: true);

  Widget _date(String label, DateTime? value, ValueChanged<DateTime?> onPick) => DateBox(label: label, value: value, onPicked: onPick);

  Widget _menu<T>(T value, List<T> items, String Function(T) label, ValueChanged<T?> onChanged) {
    return SelectBox<T>(
      value: value,
      height: 48,
      minWidth: 120,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(label(item)))).toList(),
      onChanged: onChanged,
    );
  }

  List<SaleLedgerRow> _rows(CafeStore store) {
    final list = saleLedgerRows(
      store,
      query: search.text,
      cashierName: cashierName,
      ownCashierId: widget.ownSalesOnly ? store.currentCashier?.id : null,
      tableNumber: tableNumber,
      methodId: methodId,
      shiftId: shiftId,
      from: from,
      to: to,
      includeVoided: true,
    );
    list.sort((a, b) {
      final result = switch (sort) {
        _Sort.id => store.receiptNumber(a.payment).compareTo(store.receiptNumber(b.payment)),
        _Sort.when => a.payment.paidAt.compareTo(b.payment.paidAt),
        _Sort.table => a.tableNumber.compareTo(b.tableNumber),
        _Sort.cashier => a.cashierName.compareTo(b.cashierName),
        _Sort.items => a.itemCount.compareTo(b.itemCount),
        _Sort.subtotal => a.subtotal.compareTo(b.subtotal),
        _Sort.discount => a.discount.compareTo(b.discount),
        _Sort.total => a.total.compareTo(b.total),
        _Sort.method => store.paymentLabel(a.payment).compareTo(store.paymentLabel(b.payment)),
        _Sort.status => a.payment.isVoided == b.payment.isVoided ? 0 : (a.payment.isVoided ? 1 : -1),
      };
      return ascending ? result : -result;
    });
    return list;
  }

  String _shiftLabel(CafeStore store, String id) {
    final match = store.shifts.where((shift) => shift.id == id);
    if (match.isEmpty) return id;
    final shift = match.first;
    final opened = formatTripoliDateTime(shift.openedAt);
    final closed = shift.closedAt == null ? '' : ' – ${formatTripoliTime(shift.closedAt!)}';
    return '$opened$closed';
  }

  Future<void> _detail(BuildContext context, SaleLedgerRow row) {
    return showDialog<void>(
      context: context,
      builder: (context) => Consumer<CafeStore>(
        builder: (context, live, _) {
          final payment = live.payments.where((item) => item.id == row.payment.id);
          final current = payment.isEmpty ? row.payment : payment.first;
          final choices = {
            ...live.enabledPaymentTypes.map((type) => type.id),
            if (current.paymentTypeId != null) current.paymentTypeId!,
          };
          return AlertDialog(
            title: Text(context.l10n.salesReceiptLine(live.receiptNumber(current))),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.cashierOrderNumber(live.orderNumber(current.shiftOrderNumber)), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13)),
                    Text(formatTripoliDateTime(current.paidAt)),
                    Text('${context.l10n.salesColTable}: ${row.takeout ? context.l10n.serviceTakeout : row.tableNumber}'),
                    Text('${context.l10n.salesColCashier}: ${row.cashierName}'),
                    const SizedBox(height: 8),
                    if (row.lines.isEmpty)
                      Text('${row.itemCount}')
                    else
                      ...row.lines.map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${line.qty}× ${line.name}  ${live.currency.format(line.unitPrice)}'
                              '${line.discountAmount > 0 ? '  −${live.currency.format(line.discountAmount)}' : ''}'
                              '  ${live.currency.format(line.total)}'
                              '${line.choices.isEmpty ? '' : '\n    ${choicesText(line.choices, live.locale, without: context.l10n.dishChoiceWithout, money: live.currency.format)}'}',
                            ),
                          )),
                    const Divider(),
                    Text('${context.l10n.salesColSubtotal}: ${live.currency.format(row.subtotal)}'),
                    Text('${context.l10n.salesColDiscount}: ${live.currency.format(row.discount)}'),
                    Text('${context.l10n.salesColTotal}: ${live.currency.format(row.total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${context.l10n.salesColMethod}: ${live.paymentLabel(current)}'),
                    if (choices.isNotEmpty && !current.isVoided)
                      DropdownButton<String>(
                        value: choices.contains(current.paymentTypeId) ? current.paymentTypeId : null,
                        items: choices.map((id) => DropdownMenuItem(value: id, child: Text(live.typeName(id)))).toList(),
                        onChanged: (value) async {
                          if (value == null || value == current.paymentTypeId) return;
                          final error = await live.changePaymentType(current.id, value);
                          if (!context.mounted || error == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
                        },
                      ),
                    ...current.changes.map((change) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${context.l10n.salesReceiptLine(live.receiptNumber(current))} · ${context.l10n.payChanged(
                              live.typeName(change.oldTypeId),
                              live.typeName(change.newTypeId),
                              change.actorName,
                              formatTripoliDateTime(change.createdAt),
                            )}',
                            style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                          ),
                        )),
                    ...current.refunds.map((refund) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.l10n.refundedLine(refund.qty, refund.name, live.currency.format(refund.amount), refund.reason),
                            style: const TextStyle(color: CafeColors.alert, fontSize: 13),
                          ),
                        )),
                    Text('${context.l10n.salesColStatus}: ${current.isVoided ? context.l10n.voidStatus : context.l10n.salesPaid}'),
                    if (current.isVoided)
                      Text(
                        context.l10n.voidReasonLine(current.voidReason ?? ''),
                        style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              if (live.canVoid(current))
                OutlinedButton.icon(
                  style: CafeButtons.destructiveOutlined,
                  onPressed: () => showVoidSaleDialog(context, live, current),
                  icon: const Icon(Icons.block, size: 18),
                  label: Text(context.l10n.voidSale),
                ),
              if (!current.isVoided)
                OutlinedButton.icon(
                  onPressed: () {
                    final host = context;
                    showReceiptPrint(live, current, host.l10n).catchError((_) {
                      if (!host.mounted) return;
                      ScaffoldMessenger.of(host).showSnackBar(SnackBar(content: Text(host.l10n.receiptReprintFailed)));
                    });
                  },
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(context.l10n.cashierPrintReceipt),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(CafeStore store, List<SaleLedgerRow> rows) async {
    final buffer = StringBuffer('${salesLogCsvColumns(context.l10n).join(',')}\n');
    for (final row in rows) {
      buffer.writeln([
        store.receiptNumber(row.payment),
        store.orderNumber(row.payment.shiftOrderNumber),
        formatTripoliDateTime(row.payment.paidAt),
        row.takeout ? 'Takeout' : row.tableNumber,
        row.cashierName,
        row.itemCount,
        row.subtotal,
        row.discount,
        row.total,
        store.paymentLabel(row.payment),
        row.payment.isVoided ? 'void' : 'paid',
        row.payment.voidReason ?? '',
      ].map(csvCell).join(','));
    }
    try {
      await saveBytesFile(
        dialogTitle: context.l10n.salesExportCsv,
        fileName: 'sales-log.csv',
        bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _exportPdf(CafeStore store, List<SaleLedgerRow> rows) async {
    final l10n = context.l10n;
    await Printing.layoutPdf(name: 'sales-log', onLayout: (_) => salesLogPdf(store, rows, l10n));
  }
}
