import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ledger.dart';
import 'models/models.dart';
import 'state/cafe_store.dart';
import 'time_format.dart';

Future<Uint8List> receiptPdfBytes(CafeStore store, Payment payment, AppLocalizations l10n) async {
  final row = saleLedgerRow(store, payment);
  final charged = row.lines.fold<double>(0, (sum, line) => sum + line.total);
  final service = row.total - charged;
  pw.MemoryImage? logo;
  final url = store.logoUrl;
  try {
    if (url.startsWith('data:')) {
      final encoded = url.split(',').last;
      logo = pw.MemoryImage(base64Decode(encoded));
    } else if (url.startsWith('http')) {
      final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
      logo = pw.MemoryImage(data.buffer.asUint8List());
    }
  } catch (_) {
    logo = null;
  }
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (logo != null) pw.Center(child: pw.Image(logo, height: 48)),
          pw.Text(store.cafeName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('${l10n.salesReceiptNo} ${store.receiptNumber(payment)}'),
          pw.Text(l10n.cashierOrderNumber(store.orderNumber(payment.shiftOrderNumber))),
          pw.Text(formatTripoliDateTime(payment.paidAt)),
          pw.Text(row.takeout ? l10n.serviceTakeout : l10n.cashierTableShort(row.tableNumber)),
          pw.Divider(),
          for (final line in row.lines)
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text('${line.qty}  ${line.name}')),
                pw.Text(store.currency.format(line.total)),
              ],
            ),
          pw.Divider(),
          _kv(l10n.cashierSubtotal, store.currency.format(row.subtotal)),
          if (row.discount > 0) _kv(l10n.salesColDiscount, store.currency.format(row.discount)),
          if (service > 0.009) _kv(l10n.cashierServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.currency.format(service)),
          _kv(l10n.cashierTotalPayable, store.currency.format(row.total)),
          pw.Text('${l10n.salesColMethod} ${store.typeName(payment.paymentTypeId)}'),
          pw.SizedBox(height: 8),
          pw.Text(l10n.receiptThankYou, textAlign: pw.TextAlign.center),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _kv(String label, String value) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(label), pw.Text(value)],
  );
}

Future<void> showReceiptPrint(CafeStore store, Payment payment, AppLocalizations l10n) async {
  final bytes = await receiptPdfBytes(store, payment, l10n);
  await Printing.layoutPdf(
    name: 'receipt-${store.receiptNumber(payment)}',
    onLayout: (format) async => bytes,
  );
}
