import 'dart:typed_data';

import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/ledger.dart';
import '../core/time_format.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import 'pdf_text.dart';

/// The A4 exports of the Sales Log and Wages / Expenses screens, used by their export buttons and
/// by the preview in Settings, so both show the same layout. CSV exports have no layout; their
/// columns are listed here so the preview can name them.

List<String> salesLogCsvColumns(AppLocalizations l10n) =>
    [l10n.salesReceiptNo, l10n.salesOrderNo, 'date', 'table', 'cashier', 'items', 'subtotal', 'discount', 'total', 'method', 'status', 'void_reason'];

const expensesCsvColumns = ['id', 'when', 'cashier', 'paid_to', 'type', 'description', 'amount'];

/// The sales in [rows] as an A4 landscape table, with the total of the ones not voided.
Future<Uint8List> salesLogPdf(CafeStore store, List<SaleLedgerRow> rows, AppLocalizations l10n) async {
  final kept = rows.where((row) => !row.payment.isVoided).fold<double>(0, (sum, row) => sum + row.total);
  return _a4Table(
    l10n: l10n,
    title: l10n.navSalesLog,
    headers: [
      l10n.salesReceiptNo,
      l10n.salesOrderNo,
      l10n.salesColWhen,
      l10n.salesColTable,
      l10n.salesColCashier,
      l10n.salesColItems,
      l10n.salesColSubtotal,
      l10n.salesColDiscount,
      l10n.salesColTotal,
      l10n.salesColMethod,
      l10n.salesColStatus,
    ],
    rows: [
      for (final row in rows)
        [
          store.receiptNumber(row.payment),
          store.orderNumber(row.payment.shiftOrderNumber),
          formatTripoliDateTime(row.payment.paidAt),
          row.takeout ? l10n.serviceTakeout : row.tableNumber,
          row.cashierName,
          '${row.itemCount}',
          store.currency.format(row.subtotal),
          store.currency.format(row.discount),
          store.currency.format(row.total),
          store.paymentLabel(row.payment),
          row.payment.isVoided ? l10n.voidStatus : l10n.salesPaid,
        ],
    ],
    total: l10n.pdfTotalExclVoid(store.currency.format(kept)),
  );
}

/// The expenses in [rows] as an A4 landscape table. [employee] names the employee filter when
/// one is picked, so the printout says whose expenses these are.
Future<Uint8List> expensesPdf(CafeStore store, List<ShiftExpense> rows, {String? employee}) async {
  final l10n = store.l10n;
  final kept = rows.where((row) => !row.voided).fold<double>(0, (sum, row) => sum + row.amount);
  return _a4Table(
    l10n: l10n,
    title: l10n.navWages,
    subtitle: employee == null ? null : l10n.expenseFilterEmployee(employee),
    headers: [
      l10n.expenseColId,
      l10n.expenseColWhen,
      l10n.expenseColCashier,
      l10n.expensePaidTo,
      l10n.expenseColType,
      l10n.expenseColDescription,
      l10n.expenseColAmount,
    ],
    rows: [
      for (final row in rows)
        [
          row.shortId,
          formatTripoliDateTime(row.createdAt),
          expenseCashierName(store, row),
          row.employeeName,
          store.expenseCategoryLabel(row),
          row.description,
          store.currency.format(row.amount),
        ],
    ],
    total: l10n.pdfTotalExclVoid(store.currency.format(kept)),
  );
}

/// One A4 landscape table. In Arabic the page reads right to left: the title and total sit on
/// the right and the first column is the rightmost, since the pdf table does not flip itself.
Future<Uint8List> _a4Table({
  required AppLocalizations l10n,
  required String title,
  String? subtitle,
  required List<String> headers,
  required List<List<String>> rows,
  required String total,
}) async {
  final rtl = l10n.localeName == 'ar';
  final align = rtl ? pw.TextAlign.right : pw.TextAlign.left;
  List<T> inOrder<T>(List<T> cells) => rtl ? cells.reversed.toList() : cells;
  pw.Widget cell(String value, {bool bold = false}) =>
      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pdfText(value, align: align, bold: bold, size: 9));

  final theme = await PdfFonts.theme();
  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      crossAxisAlignment: rtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      build: (context) => [
        pdfText(title, size: 18, bold: true, align: align),
        if (subtitle != null) pdfText(subtitle, size: 13, bold: true, align: align),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: inOrder([for (final header in headers) cell(header, bold: true)]),
            ),
            for (final row in rows) pw.TableRow(children: inOrder([for (final value in row) cell(value)])),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: rtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
          child: pdfText(total, size: 14, bold: true),
        ),
      ],
    ),
  );
  return doc.save();
}
