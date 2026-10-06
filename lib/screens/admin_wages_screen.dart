import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../csv_safe.dart';
import '../ledger.dart';
import '../pdf_text.dart';
import '../save_bytes.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../time_format.dart';
import '../widgets/cafe_widgets.dart';

class AdminWagesScreen extends StatefulWidget {
  const AdminWagesScreen({super.key});

  @override
  State<AdminWagesScreen> createState() => _AdminWagesScreenState();
}

class _AdminWagesScreenState extends State<AdminWagesScreen> {
  final search = TextEditingController();
  DateTime? from;
  DateTime? to;
  String? cashierId;
  String? categoryId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final rows = _rows(store);
    final window = summaryWindow(from: from, to: to);
    final summed = expenseLedgerRows(
      store,
      query: search.text,
      cashierId: cashierId,
      categoryId: categoryId,
      from: window.from,
      to: window.to,
    );
    final total = summed.fold<double>(0, (sum, row) => sum + row.amount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.navWages, style: CafeTheme.display.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          SoftCard(
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  window.monthly ? context.l10n.summaryThisMonth : context.l10n.summarySelectedRange,
                  style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                ),
                Text(
                  store.currency.format(-total),
                  style: CafeTheme.display.copyWith(fontSize: 24, color: CafeColors.alert),
                ),
                Text(_rangeLabel(window), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
              ],
            ),
          ),
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _date(context.l10n.salesDateFrom, from, (value) => setState(() => from = value)),
              _date(context.l10n.salesDateTo, to, (value) => setState(() => to = value)),
              DropdownButton<String?>(
                value: cashierId,
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.salesAllCashiers)),
                  for (final cashier in store.cashiers)
                    DropdownMenuItem(value: cashier.id, child: Text(cashier.name)),
                ],
                onChanged: (value) => setState(() => cashierId = value),
              ),
              DropdownButton<String?>(
                value: categoryId,
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.expenseAllTypes)),
                  for (final category in store.expenseCategories.where((item) => item.enabled || item.id == categoryId).toList()
                    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                    DropdownMenuItem(value: category.id, child: Text(category.label(store.locale))),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              ),
              OutlinedButton(onPressed: () => _exportCsv(store, rows), child: Text(context.l10n.salesExportCsv)),
              OutlinedButton(onPressed: () => _exportPdf(store, rows), child: Text(context.l10n.salesExportPdf)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SoftCard(
              radius: 16,
              child: rows.isEmpty
                  ? EmptyHint(context.l10n.noTransactions)
                  : WideTable(
                      minWidth: 980,
                      child: ListView.builder(
                        // Header, then a divider + line per row, built lazily.
                        itemCount: 1 + rows.length * 2,
                        itemBuilder: (context, index) {
                          if (index == 0) return _header(context);
                          if (index.isOdd) return const Divider(height: 1);
                          return _line(context, store, rows[index ~/ 2 - 1]);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<ShiftExpense> _rows(CafeStore store) => expenseLedgerRows(
        store,
        query: search.text,
        cashierId: cashierId,
        categoryId: categoryId,
        from: from,
        to: to,
      );

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
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            initialDate: value ?? DateTime.now(),
          );
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

  Widget _header(BuildContext context) {
    final style = const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(context.l10n.expenseColId, style: style)),
          Expanded(flex: 3, child: Text(context.l10n.expenseColWhen, style: style)),
          Expanded(flex: 2, child: Text(context.l10n.expenseColCashier, style: style)),
          Expanded(flex: 2, child: Text(context.l10n.expenseColType, style: style)),
          Expanded(flex: 3, child: Text(context.l10n.expenseColDescription, style: style)),
          Expanded(child: Text(context.l10n.expenseColAmount, textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, CafeStore store, ShiftExpense row) {
    final cashier = store.cashiers.where((item) => item.id == row.cashierId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(row.shortId, style: const TextStyle(fontWeight: FontWeight.w800)),
                    _statusPill(
                      context,
                      label: row.editedFrom == null ? context.l10n.expenseLogged : context.l10n.expenseEdited,
                      edited: row.editedFrom != null,
                      onTap: row.editedFrom == null ? null : () => _original(context, store, row),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 3, child: Text(formatTripoliDateTime(row.createdAt))),
              Expanded(flex: 2, child: Text(cashier.isEmpty ? row.cashierId : cashier.first.name)),
              Expanded(flex: 2, child: Text(store.expenseCategoryLabel(row))),
              Expanded(flex: 3, child: Text(row.description)),
              Expanded(
                child: Text(
                  store.currency.format(-row.amount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: CafeColors.alert),
                ),
              ),
            ],
      ),
    );
  }

  Widget _statusPill(
    BuildContext context, {
    required String label,
    required bool edited,
    VoidCallback? onTap,
  }) {
    final color = edited ? CafeColors.alert : CafeColors.inkMuted;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
    if (onTap == null) return pill;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: pill);
  }

  void _original(BuildContext context, CafeStore store, ShiftExpense row) {
    final prior = store.expenses.where((item) => item.id == row.editedFrom);
    final original = prior.isEmpty ? null : prior.first;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.expenseOriginal),
        content: Text(
          original == null
              ? context.l10n.expenseOriginalMissing
              : '${original.shortId}\n${original.description}\n${store.currency.format(-original.amount)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        ],
      ),
    );
  }

  Future<void> _exportCsv(CafeStore store, List<ShiftExpense> rows) async {
    final buffer = StringBuffer('id,when,cashier,type,description,amount\n');
    for (final row in rows) {
      final cashier = store.cashiers.where((item) => item.id == row.cashierId);
      buffer.writeln([
        row.shortId,
        formatTripoliDateTime(row.createdAt),
        cashier.isEmpty ? row.cashierId : cashier.first.name,
        store.expenseCategoryLabel(row),
        row.description,
        row.amount,
      ].map(csvCell).join(','));
    }
    try {
      await saveBytesFile(
        dialogTitle: context.l10n.salesExportCsv,
        fileName: 'wages.csv',
        bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _exportPdf(CafeStore store, List<ShiftExpense> rows) async {
    await Printing.layoutPdf(
      name: 'wages',
      onLayout: (PdfPageFormat format) async {
        final theme = await PdfFonts.theme();
        final doc = pw.Document(theme: theme);
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            theme: theme,
            build: (context) => [
              pw.TableHelper.fromTextArray(
                cellBuilder: (index, data, rowNum) => pdfText('$data'),
                headers: [
                  pdfText('ID', bold: true),
                  pdfText('When', bold: true),
                  pdfText('Cashier', bold: true),
                  pdfText('Type', bold: true),
                  pdfText('Description', bold: true),
                  pdfText('Amount', bold: true),
                ],
                data: [
                  for (final row in rows)
                    [
                      row.shortId,
                      formatTripoliDateTime(row.createdAt),
                      row.cashierId,
                      store.expenseCategoryLabel(row),
                      row.description,
                      row.amount.toString(),
                    ],
                ],
              ),
            ],
          ),
        );
        return doc.save();
      },
    );
  }
}
