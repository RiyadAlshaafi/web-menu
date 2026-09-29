import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';

enum _Sort { when, table, cashier, items, subtotal, discount, tax, total, method, status }

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
          Text(context.l10n.navSalesLog, style: CafeTheme.display.copyWith(fontSize: 28)),
          if (widget.ownSalesOnly) ...[
            const SizedBox(height: 4),
            Text(context.l10n.salesOwnOnly, style: const TextStyle(color: CafeColors.inkMuted)),
          ],
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
              _date(context.l10n.salesDateFrom, from, (value) => setState(() { from = value; page = 0; })),
              _date(context.l10n.salesDateTo, to, (value) => setState(() { to = value; page = 0; })),
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
                                onTap: () => _detail(context, store, row),
                                child: _line(context, store, row, button),
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Text(context.l10n.salesPage(safePage + 1, pages)),
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
        cell(context.l10n.salesColWhen, _Sort.when, flex: 3),
        cell(context.l10n.salesColTable, _Sort.table),
        cell(context.l10n.salesColCashier, _Sort.cashier, flex: 3),
        cell(context.l10n.salesColItems, _Sort.items),
        cell(context.l10n.salesColSubtotal, _Sort.subtotal),
        cell(context.l10n.salesColDiscount, _Sort.discount),
        cell(context.l10n.salesColTax, _Sort.tax),
        cell(context.l10n.salesColTotal, _Sort.total),
        cell(context.l10n.salesColMethod, _Sort.method),
        cell(context.l10n.salesColStatus, _Sort.status),
      ],
    );
  }

  Widget _line(BuildContext context, CafeStore store, _Sale row, Color button) {
    Widget cell(String value, {int flex = 2}) => Expanded(flex: flex, child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          cell(DateFormat('y-MM-dd HH:mm').format(row.payment.paidAt), flex: 3),
          cell(row.tableNumber),
          cell(row.cashierName, flex: 3),
          cell('${row.itemCount}'),
          cell(store.currency.format(row.subtotal)),
          cell(store.currency.format(row.discount)),
          cell(store.currency.format(row.tax)),
          cell(store.currency.format(row.total)),
          cell(row.payment.method),
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

  Widget _date(String label, DateTime? value, ValueChanged<DateTime?> onPick) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDate: value ?? DateTime.now());
        onPick(picked);
      },
      child: Text(value == null ? label : '$label ${DateFormat.yMd().format(value)}'),
    );
  }

  Widget _menu<T>(T value, List<T> items, String Function(T) label, ValueChanged<T?> onChanged) {
    return DropdownButton<T>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(label(item)))).toList(),
      onChanged: onChanged,
    );
  }

  List<_Sale> _rows(CafeStore store) {
    final query = search.text.trim().toLowerCase();
    final mine = widget.ownSalesOnly ? store.currentCashier?.id : null;
    final list = store.payments.where((payment) {
      if (mine != null && payment.cashierId != mine) return false;
      if (cashierId != null && payment.cashierId != cashierId) return false;
      if (tableId != null && payment.tableId != tableId) return false;
      if (from != null && payment.paidAt.isBefore(DateTime(from!.year, from!.month, from!.day))) return false;
      if (to != null && payment.paidAt.isAfter(DateTime(to!.year, to!.month, to!.day, 23, 59, 59))) return false;
      final row = _sale(store, payment);
      if (query.isEmpty) return true;
      return row.tableNumber.toLowerCase().contains(query) ||
          row.cashierName.toLowerCase().contains(query) ||
          payment.id.toLowerCase().contains(query);
    }).map((payment) => _sale(store, payment)).toList();
    list.sort((a, b) {
      final result = switch (sort) {
        _Sort.when => a.payment.paidAt.compareTo(b.payment.paidAt),
        _Sort.table => a.tableNumber.compareTo(b.tableNumber),
        _Sort.cashier => a.cashierName.compareTo(b.cashierName),
        _Sort.items => a.itemCount.compareTo(b.itemCount),
        _Sort.subtotal => a.subtotal.compareTo(b.subtotal),
        _Sort.discount => a.discount.compareTo(b.discount),
        _Sort.tax => a.tax.compareTo(b.tax),
        _Sort.total => a.total.compareTo(b.total),
        _Sort.method => a.payment.method.compareTo(b.payment.method),
        _Sort.status => 0,
      };
      return ascending ? result : -result;
    });
    return list;
  }

  _Sale _sale(CafeStore store, Payment payment) {
    final table = store.tables.where((item) => item.id == payment.tableId);
    final order = store.orders.where((item) => item.id == payment.orderId);
    final subtotal = order.isEmpty ? payment.totalDue : order.first.subtotal;
    return _Sale(
      payment: payment,
      tableNumber: table.isEmpty ? '' : table.first.number,
      cashierName: _cashierName(store, payment.cashierId),
      itemCount: order.isEmpty ? 0 : order.first.itemCount,
      items: order.isEmpty ? '' : order.first.lines.map((line) => '${line.qty}× ${line.name}').join(', '),
      subtotal: subtotal,
      discount: 0,
      tax: 0,
      total: payment.totalDue,
    );
  }

  String _cashierName(CafeStore store, String id) {
    final match = store.cashiers.where((item) => item.id == id);
    return match.isEmpty ? id : match.first.name;
  }

  Future<void> _detail(BuildContext context, CafeStore store, _Sale row) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat('y-MM-dd HH:mm').format(row.payment.paidAt)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${context.l10n.salesColTable}: ${row.tableNumber}'),
              Text('${context.l10n.salesColCashier}: ${row.cashierName}'),
              Text(row.payment.id, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Text(row.items.isEmpty ? '${row.itemCount}' : row.items),
              const Divider(),
              Text('${context.l10n.salesColSubtotal}: ${store.currency.format(row.subtotal)}'),
              Text('${context.l10n.salesColDiscount}: ${store.currency.format(row.discount)}'),
              Text('${context.l10n.salesColTax}: ${store.currency.format(row.tax)}'),
              Text('${context.l10n.salesColTotal}: ${store.currency.format(row.total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${context.l10n.salesColMethod}: ${row.payment.method}'),
              Text('${context.l10n.salesColStatus}: ${context.l10n.salesPaid}'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel))],
      ),
    );
  }

  Future<void> _exportCsv(CafeStore store, List<_Sale> rows) async {
    final buffer = StringBuffer('date,table,cashier,items,subtotal,discount,tax,total,method,status,id\n');
    for (final row in rows) {
      buffer.writeln([
        DateFormat('y-MM-dd HH:mm').format(row.payment.paidAt),
        row.tableNumber,
        row.cashierName,
        row.itemCount,
        row.subtotal,
        row.discount,
        row.tax,
        row.total,
        row.payment.method,
        'paid',
        row.payment.id,
      ].map((value) => '"${'$value'.replaceAll('"', '""')}"').join(','));
    }
    await FilePicker.platform.saveFile(dialogTitle: context.l10n.salesExportCsv, fileName: 'sales-log.csv', bytes: utf8.encode(buffer.toString()));
  }

  Future<void> _exportPdf(CafeStore store, List<_Sale> rows) async {
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
                headers: const ['When', 'Table', 'Cashier', 'Items', 'Subtotal', 'Discount', 'Tax', 'Total', 'Method', 'Status'],
                data: rows
                    .map((row) => [
                          DateFormat('y-MM-dd HH:mm').format(row.payment.paidAt),
                          row.tableNumber,
                          row.cashierName,
                          '${row.itemCount}',
                          store.currency.format(row.subtotal),
                          store.currency.format(row.discount),
                          store.currency.format(row.tax),
                          store.currency.format(row.total),
                          row.payment.method,
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

class _Sale {
  const _Sale({
    required this.payment,
    required this.tableNumber,
    required this.cashierName,
    required this.itemCount,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final Payment payment;
  final String tableNumber;
  final String cashierName;
  final int itemCount;
  final String items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
}
