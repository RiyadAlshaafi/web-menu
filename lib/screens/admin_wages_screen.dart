import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/csv_safe.dart';
import '../core/ledger.dart';
import '../printing/export_pdfs.dart';
import '../platform/save_bytes.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../core/time_format.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/tawla_ui.dart';

class AdminWagesScreen extends StatefulWidget {
  const AdminWagesScreen({super.key});

  @override
  State<AdminWagesScreen> createState() => _AdminWagesScreenState();
}

class _AdminWagesScreenState extends State<AdminWagesScreen> {
  final search = TextEditingController();
  DateTime? from;
  DateTime? to;
  EmployeeFilter employee = const AllEmployees();
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
    final expensesTotal = expenseLedgerRows(
      store,
      query: search.text,
      employee: employee,
      categoryId: categoryId,
      from: window.from,
      to: window.to,
    ).fold<double>(0, (sum, row) => sum + row.amount);
    final salesTotal = saleLedgerRows(store, from: window.from, to: window.to).fold<double>(0, (sum, row) => sum + row.total);
    final period = window.monthly ? context.l10n.summaryThisMonth : context.l10n.summarySelectedRange;
    final employees = expenseEmployees(store);
    // One person's expenses next to the whole cafe's sales make no net figure, so Net hides then.
    final oneEmployee = employee is! AllEmployees;
    final categories = store.expenseCategories.where((item) => item.enabled || item.id == categoryId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _figure(
                  context,
                  oneEmployee ? '${context.l10n.summarySales} · $period · ${context.l10n.summaryWholeCafe}' : '${context.l10n.summarySales} · $period',
                  store.currency.format(salesTotal),
                ),
                _figure(
                  context,
                  oneEmployee ? '${context.l10n.summaryExpenses} · $period · ${_employeeLabel(context, employees)}' : '${context.l10n.summaryExpenses} · $period',
                  store.currency.format(expensesTotal),
                  color: CafeColors.terracottaDark,
                ),
                if (!oneEmployee) _figure(context, '${context.l10n.summaryNet} · $period', store.currency.format(salesTotal - expensesTotal), dark: true),
              ];
              if (constraints.maxWidth < 720) {
                return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: card)]);
              }
              return Row(
                children: [
                  for (final (index, card) in cards.indexed) ...[
                    if (index > 0) const SizedBox(width: 14),
                    Expanded(child: card),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedPills<String?>(
                options: [
                  (null, context.l10n.expenseAllTypes),
                  for (final category in categories) (category.id, category.label(store.locale)),
                ],
                selected: categoryId,
                onSelected: (value) => setState(() => categoryId = value),
              ),
              OutlineAction(label: context.l10n.salesExportCsv, icon: Icons.file_download_outlined, height: 44, onPressed: () => _exportCsv(store, rows)),
              OutlineAction(
                label: context.l10n.salesExportPdf,
                icon: Icons.picture_as_pdf_outlined,
                height: 44,
                onPressed: () => _exportPdf(store, rows, oneEmployee ? _employeeLabel(context, employees) : null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 320,
                height: 48,
                child: PageSearchField(controller: search, hint: context.l10n.salesSearchHint, onChanged: (_) => setState(() {})),
              ),
              DateBox(label: context.l10n.salesDateFrom, value: from, onPicked: (value) => setState(() => from = value)),
              DateBox(label: context.l10n.salesDateTo, value: to, onPicked: (value) => setState(() => to = value)),
              SelectBox<EmployeeFilter>(
                value: employee,
                height: 48,
                items: [
                  DropdownMenuItem(value: const AllEmployees(), child: Text(context.l10n.expenseAllEmployees)),
                  DropdownMenuItem(value: const NoEmployee(), child: Text(context.l10n.expenseNoEmployee)),
                  for (final person in employees) DropdownMenuItem(value: OneEmployee(person.id), child: Text(person.name)),
                  // A picked person whose expenses have since left the loaded list stays pickable.
                  if (employee case OneEmployee(:final id) when !employees.any((person) => person.id == id))
                    DropdownMenuItem(value: employee, child: Text(_employeeLabel(context, employees))),
                ],
                onChanged: (value) => setState(() => employee = value ?? const AllEmployees()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TawlaPanel(
              padding: EdgeInsets.zero,
              child: rows.isEmpty
                  ? EmptyHint(context.l10n.noTransactions)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: WideTable(
                        minWidth: 980,
                        child: ListView.builder(
                          // Header, then a divider + line per row, built lazily.
                          itemCount: 1 + rows.length * 2,
                          itemBuilder: (context, index) {
                            if (index == 0) return _header(context);
                            if (index.isOdd) return const Divider(height: 1, color: TawlaTokens.hairline);
                            return _line(context, store, rows[index ~/ 2 - 1]);
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _figure(BuildContext context, String label, String value, {Color? color, bool dark = false}) {
    final surfaces = CafeSurfaces.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: dark ? surfaces.header : Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? const Color(0xFFB9C7CF) : TawlaTokens.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: dark ? Colors.white : (color ?? surfaces.header)),
          ),
        ],
      ),
    );
  }

  /// What the employee filter shows now, for card labels and the PDF.
  String _employeeLabel(BuildContext context, List<({String id, String name})> employees) => switch (employee) {
        AllEmployees() => context.l10n.expenseAllEmployees,
        NoEmployee() => context.l10n.expenseNoEmployee,
        OneEmployee(:final id) => employees.where((person) => person.id == id).firstOrNull?.name ?? '?',
      };

  List<ShiftExpense> _rows(CafeStore store) => expenseLedgerRows(
        store,
        query: search.text,
        employee: employee,
        categoryId: categoryId,
        from: from,
        to: to,
      );

  /// Wages read navy, café expenses terracotta and cash withdrawals amber, as in the sales log.
  BadgeTone _tone(CafeStore store, ShiftExpense row) {
    final match = store.expenseCategories.where((item) => item.id == row.categoryId);
    final name = match.isNotEmpty ? match.first.nameEn : (row.categoryNameEn ?? (row.paidToCafe ? 'Café Expense' : 'Cash Withdrawal'));
    final key = name.toLowerCase();
    if (key.contains('wage')) return BadgeTone.navy;
    if (key.contains('withdraw')) return BadgeTone.amber;
    if (key.contains('expense')) return BadgeTone.terracotta;
    return BadgeTone.neutral;
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: TableHead(context.l10n.expenseColId)),
          Expanded(flex: 3, child: TableHead(context.l10n.expenseColWhen)),
          Expanded(flex: 3, child: TableHead(context.l10n.expenseColCashier)),
          Expanded(flex: 3, child: TableHead(context.l10n.expensePaidTo)),
          Expanded(flex: 3, child: TableHead(context.l10n.expenseColType)),
          Expanded(flex: 4, child: TableHead(context.l10n.expenseColDescription)),
          Expanded(flex: 2, child: TableHead(context.l10n.expenseColAmount, align: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, CafeStore store, ShiftExpense row) {
    const body = TextStyle(fontSize: 14, color: CafeColors.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(row.shortId, style: body.copyWith(fontWeight: FontWeight.w800))),
          Expanded(flex: 3, child: Text(formatTripoliDateTime(row.createdAt), style: body)),
          Expanded(flex: 3, child: Text(expenseCashierName(store, row), maxLines: 1, overflow: TextOverflow.ellipsis, style: body)),
          Expanded(flex: 3, child: Text(row.employeeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: body)),
          Expanded(
            flex: 3,
            child: Align(alignment: AlignmentDirectional.centerStart, child: StatusBadge(store.expenseCategoryLabel(row), tone: _tone(store, row))),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Flexible(child: Text(row.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: body)),
                if (row.editedFrom != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _original(context, store, row),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(context.l10n.expenseEdited, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7A5512))),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              store.currency.format(row.amount),
              textAlign: TextAlign.end,
              style: body.copyWith(fontWeight: FontWeight.w800, color: CafeColors.terracottaDark),
            ),
          ),
        ],
      ),
    );
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
    final buffer = StringBuffer('${expensesCsvColumns.join(',')}\n');
    for (final row in rows) {
      buffer.writeln([
        row.shortId,
        formatTripoliDateTime(row.createdAt),
        expenseCashierName(store, row),
        row.employeeName,
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

  /// [employee] names the employee filter when one is picked, so the printout says whose
  /// expenses these are.
  Future<void> _exportPdf(CafeStore store, List<ShiftExpense> rows, String? employee) async {
    await Printing.layoutPdf(name: 'wages', onLayout: (_) => expensesPdf(store, rows, employee: employee));
  }
}
