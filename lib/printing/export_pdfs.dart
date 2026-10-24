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
  final receiptHeader = l10n.salesReceiptNo;
  final orderHeader = l10n.salesOrderNo;
  final theme = await PdfFonts.theme();
  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (context) => [
        pdfText('Sales Log', size: 18, bold: true),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          cellBuilder: (index, data, rowNum) => pdfText('$data'),
          headers: [
            pdfText(receiptHeader, bold: true),
            pdfText(orderHeader, bold: true),
            pdfText('When', bold: true),
            pdfText('Table', bold: true),
            pdfText('Cashier', bold: true),
            pdfText('Items', bold: true),
            pdfText('Subtotal', bold: true),
            pdfText('Discount', bold: true),
            pdfText('Total', bold: true),
            pdfText('Method', bold: true),
            pdfText('Status', bold: true),
          ],
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
                    store.paymentLabel(row.payment),
                    row.payment.isVoided ? 'Void' : 'Paid',
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfText(
            'Total (excl. void): ${store.currency.format(rows.where((r) => !r.payment.isVoided).fold<num>(0, (sum, r) => sum + r.total))}',
            size: 14,
            bold: true,
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// The expenses in [rows] as an A4 landscape table. [employee] names the employee filter when
/// one is picked, so the printout says whose expenses these are.
Future<Uint8List> expensesPdf(CafeStore store, List<ShiftExpense> rows, {String? employee}) async {
  final theme = await PdfFonts.theme();
  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (context) => [
        if (employee != null) ...[
          pdfText(store.l10n.expenseFilterEmployee(employee), size: 13, bold: true),
          pw.SizedBox(height: 8),
        ],
        pw.TableHelper.fromTextArray(
          cellBuilder: (index, data, rowNum) => pdfText('$data'),
          headers: [
            pdfText(store.l10n.expenseColId, bold: true),
            pdfText(store.l10n.expenseColWhen, bold: true),
            pdfText(store.l10n.expenseColCashier, bold: true),
            pdfText(store.l10n.expensePaidTo, bold: true),
            pdfText(store.l10n.expenseColType, bold: true),
            pdfText(store.l10n.expenseColDescription, bold: true),
            pdfText(store.l10n.expenseColAmount, bold: true),
          ],
          data: [
            for (final row in rows)
              [
                row.shortId,
                formatTripoliDateTime(row.createdAt),
                expenseCashierName(store, row),
                row.employeeName,
                store.expenseCategoryLabel(row),
                row.description,
                row.amount.toString(),
              ],
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pdfText(
            'Total (excl. void): ${rows.where((r) => !r.voided).fold<double>(0, (sum, r) => sum + r.amount)}',
            size: 14,
            bold: true,
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
