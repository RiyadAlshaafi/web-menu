import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../ledger.dart';
import '../l10n/l10n_ext.dart';
import '../time_format.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';

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
  String? cashierId;
  String? tableId;
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
    final button = CafeSurfaces.of(context).button;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.ownSalesOnly ? context.l10n.navCashierLog : context.l10n.navSalesLog, style: CafeTheme.display.copyWith(fontSize: 28)),
          if (widget.ownSalesOnly) ...[
            const SizedBox(height: 4),
            Text(context.l10n.cashierLogScope, style: const TextStyle(color: CafeColors.inkMuted)),
          ],
          const SizedBox(height: 12),
          _summary(context, store),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(hintText: context.l10n.salesSearchHint, prefixIcon: const Icon(Icons.search)),
                  onChanged: (_) => setState(() => page = 0),
                ),
              ),
              _date(context.l10n.salesDateFrom, from, (value) {
                setState(() { from = value; page = 0; });
                store.alignSalesWindow(from: from, to: to);
              }),
              _date(context.l10n.salesDateTo, to, (value) {
                setState(() { to = value; page = 0; });
                store.alignSalesWindow(from: from, to: to);
              }),
              if (!widget.ownSalesOnly)
                _menu<String?>(
                  cashierId,
                  [null, ...store.cashiers.map((item) => item.id)],
                  (id) => id == null ? context.l10n.salesAllCashiers : _cashierName(store, id),
                  (value) => setState(() { cashierId = value; page = 0; }),
                ),
              _menu<String?>(
                tableId,
                [null, ...store.tables.map((item) => item.id)],
                (id) => id == null ? context.l10n.salesAllTables : store.tableById(id).number,
                (value) => setState(() { tableId = value; page = 0; }),
              ),
              _menu<String?>(
                methodId,
                [null, ...store.paymentTypes.map((item) => item.id)],
                (id) => id == null ? context.l10n.salesAllMethods : store.typeName(id),
                (value) => setState(() { methodId = value; page = 0; }),
              ),
              if (widget.ownSalesOnly)
                _menu<String?>(
                  shiftId,
                  [null, ...store.shifts.where((shift) => shift.cashierId == store.currentCashier?.id).map((shift) => shift.id)],
                  (id) => id == null ? context.l10n.salesAllShifts : _shiftLabel(store, id),
                  (value) => setState(() { shiftId = value; page = 0; }),
                ),
              FilledButton(onPressed: () => _exportCsv(store, rows), child: Text(context.l10n.salesExportCsv)),
              OutlinedButton(
                onPressed: () => _exportPdf(store, rows),
                style: OutlinedButton.styleFrom(foregroundColor: button, side: BorderSide(color: button)),
                child: Text(context.l10n.salesExportPdf),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SoftCard(
              radius: 16,
              child: rows.isEmpty
                  ? EmptyHint(context.l10n.salesEmpty)
                  : Column(
                      children: [
                        _header(context),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = visible[index];
                              return InkWell(
                                onTap: () => _detail(context, row),
                                child: _line(context, store, row, button),
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Text(context.l10n.salesPage(safePage + 1, pages)),
                            if (store.salesHasMore)
                              TextButton(onPressed: () => store.loadMoreSales(), child: Text(context.l10n.salesLoadMore)),
                            const Spacer(),
                            IconButton(onPressed: safePage == 0 ? null : () => setState(() => page = safePage - 1), icon: const Icon(Icons.chevron_left)),
                            IconButton(onPressed: safePage >= pages - 1 ? null : () => setState(() => page = safePage + 1), icon: const Icon(Icons.chevron_right)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    Widget cell(String label, _Sort column, {int flex = 2}) {
      final active = sort == column;
      final color = active ? CafeSurfaces.of(context).button : CafeColors.inkMuted;
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          ),
        ),
      );
    }

    return Row(
      children: [
        cell(context.l10n.salesReceiptNo, _Sort.id),
        cell(context.l10n.salesColWhen, _Sort.when, flex: 3),
        cell(context.l10n.salesColTable, _Sort.table),
        cell(context.l10n.salesColCashier, _Sort.cashier, flex: 3),
        cell(context.l10n.salesColItems, _Sort.items),
        cell(context.l10n.salesColSubtotal, _Sort.subtotal),
        cell(context.l10n.salesColDiscount, _Sort.discount),
        cell(context.l10n.salesColTotal, _Sort.total),
        cell(context.l10n.salesColMethod, _Sort.method),
        cell(context.l10n.salesColStatus, _Sort.status),
      ],
    );
  }

  Widget _line(BuildContext context, CafeStore store, SaleLedgerRow row, Color button) {
    Widget cell(String value, {int flex = 2}) => Expanded(flex: flex, child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.receiptNumber(row.payment), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  context.l10n.cashierOrderNumber(store.orderNumber(row.payment.shiftOrderNumber)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          cell(formatTripoliDateTime(row.payment.paidAt), flex: 3),
          cell(row.takeout ? context.l10n.serviceTakeout : row.tableNumber),
          cell(row.cashierName, flex: 3),
          cell('${row.itemCount}'),
          cell(store.currency.format(row.subtotal)),
          cell(store.currency.format(row.discount)),
          cell(store.currency.format(row.total)),
          cell(store.typeName(row.payment.paymentTypeId)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: button.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: button),
                ),
                child: Text(context.l10n.salesPaid, style: TextStyle(color: button, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, CafeStore store) {
    final window = summaryWindow(from: from, to: to);
    final rows = saleLedgerRows(
      store,
      query: search.text,
      cashierId: cashierId,
      ownCashierId: widget.ownSalesOnly ? store.currentCashier?.id : null,
      tableId: tableId,
      methodId: methodId,
      shiftId: shiftId,
      from: window.from,
      to: window.to,
    );
    final total = rows.fold<double>(0, (sum, row) => sum + row.total);
    final range = _rangeLabel(window);
    return SoftCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            window.monthly ? context.l10n.summaryThisMonth : context.l10n.summarySelectedRange,
            style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
          ),
          Text(store.currency.format(total), style: CafeTheme.display.copyWith(fontSize: 24)),
          Text(range, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
        ],
      ),
    );
  }

  String _rangeLabel(SummaryWindow window) {
    final start = window.from == null ? '…' : DateFormat.yMd().format(window.from!);
    final end = window.to == null ? '…' : DateFormat.yMd().format(window.to!);
    return '$start – $end';
  }

  Widget _date(String label, DateTime? value, ValueChanged<DateTime?> onPick) {
    return SizedBox(
      width: 200,
      child: OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDate: value ?? DateTime.now());
        onPick(picked);
      },
        child: Text(
          value == null ? label : '$label ${DateFormat.yMd().format(value)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _menu<T>(T value, List<T> items, String Function(T) label, ValueChanged<T?> onChanged) {
    return DropdownButton<T>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(label(item)))).toList(),
      onChanged: onChanged,
    );
  }

  List<SaleLedgerRow> _rows(CafeStore store) {
    final list = saleLedgerRows(
      store,
      query: search.text,
      cashierId: cashierId,
      ownCashierId: widget.ownSalesOnly ? store.currentCashier?.id : null,
      tableId: tableId,
      methodId: methodId,
      shiftId: shiftId,
      from: from,
      to: to,
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
        _Sort.method => store.typeName(a.payment.paymentTypeId).compareTo(store.typeName(b.payment.paymentTypeId)),
        _Sort.status => 0,
      };
      return ascending ? result : -result;
    });
    return list;
  }

  String _cashierName(CafeStore store, String id) {
    final match = store.cashiers.where((item) => item.id == id);
    return match.isEmpty ? id : match.first.name;
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
                              '  ${live.currency.format(line.total)}',
                            ),
                          )),
                    const Divider(),
                    Text('${context.l10n.salesColSubtotal}: ${live.currency.format(row.subtotal)}'),
                    Text('${context.l10n.salesColDiscount}: ${live.currency.format(row.discount)}'),
                    Text('${context.l10n.salesColTotal}: ${live.currency.format(row.total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${context.l10n.salesColMethod}: ${live.typeName(current.paymentTypeId)}'),
                    if (choices.isNotEmpty)
                      DropdownButton<String>(
                        value: choices.contains(current.paymentTypeId) ? current.paymentTypeId : null,
                        items: choices.map((id) => DropdownMenuItem(value: id, child: Text(live.typeName(id)))).toList(),
                        onChanged: (value) async {
                          if (value == null || value == current.paymentTypeId) return;
                          final error = await live.changePaymentType(current.id, value);
                          if (!context.mounted || error == null) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
                    Text('${context.l10n.salesColStatus}: ${context.l10n.salesPaid}'),
                  ],
                ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel))],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(CafeStore store, List<SaleLedgerRow> rows) async {
    final buffer = StringBuffer('${context.l10n.salesReceiptNo},${context.l10n.salesOrderNo},date,table,cashier,items,subtotal,discount,total,method,status\n');
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
        store.typeName(row.payment.paymentTypeId),
        'paid',
      ].map((value) => '"${'$value'.replaceAll('"', '""')}"').join(','));
    }
    await FilePicker.platform.saveFile(dialogTitle: context.l10n.salesExportCsv, fileName: 'sales-log.csv', bytes: utf8.encode(buffer.toString()));
  }

  Future<void> _exportPdf(CafeStore store, List<SaleLedgerRow> rows) async {
    final l10n = context.l10n;
    final receiptHeader = l10n.salesReceiptNo;
    final orderHeader = l10n.salesOrderNo;
    await Printing.layoutPdf(
      name: 'sales-log',
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            build: (context) => [
              pw.Text('Sales Log', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [receiptHeader, orderHeader, 'When', 'Table', 'Cashier', 'Items', 'Subtotal', 'Discount', 'Total', 'Method', 'Status'],
                data: rows
                    .map((row) => [
                          '$receiptHeader ${store.receiptNumber(row.payment)}',
                          l10n.cashierOrderNumber(store.orderNumber(row.payment.shiftOrderNumber)),
                          formatTripoliDateTime(row.payment.paidAt),
                          row.takeout ? 'Takeout' : row.tableNumber,
                          row.cashierName,
                          '${row.itemCount}',
                          store.currency.format(row.subtotal),
                          store.currency.format(row.discount),
                          store.currency.format(row.total),
                          store.typeName(row.payment.paymentTypeId),
                          'Paid',
                        ])
                    .toList(),
              ),
            ],
          ),
        );
        return doc.save();
      },
    );
  }
}
