import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ledger.dart';
import 'pdf_text.dart';
import 'models/models.dart';
import 'state/cafe_store.dart';
import 'time_format.dart';

final Map<String, Uint8List> _logoCache = {};

/// Decodes or downloads the logo once per URL so repeat prints skip the fetch.
Future<pw.MemoryImage?> _logoFor(String url) async {
  try {
    var bytes = _logoCache[url];
    if (bytes == null) {
      if (url.startsWith('data:')) {
        bytes = base64Decode(url.split(',').last);
      } else if (url.startsWith('http')) {
        final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
        bytes = data.buffer.asUint8List();
      } else {
        return null;
      }
      _logoCache[url] = bytes;
    }
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

Future<Uint8List> receiptPdfBytes(CafeStore store, Payment payment, AppLocalizations l10n) async {
  final row = saleLedgerRow(store, payment);
  final charged = row.lines.fold<double>(0, (sum, line) => sum + line.total);
  final service = row.total - charged;
  final logo = await _logoFor(store.logoUrl);
  final theme = await PdfFonts.theme();
  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      theme: theme,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (logo != null) pw.Center(child: pw.Image(logo, height: 48)),
          pdfText(store.cafeName, align: pw.TextAlign.center, size: 16, bold: true),
          pw.SizedBox(height: 6),
          pdfText('${l10n.salesReceiptNo} ${store.receiptNumber(payment)}'),
          pdfText(l10n.cashierOrderNumber(store.orderNumber(payment.shiftOrderNumber))),
          pdfText(formatTripoliDateTime(payment.paidAt)),
          pdfText(row.takeout ? l10n.serviceTakeout : l10n.cashierTableShort(row.tableNumber)),
          pw.Divider(),
          for (final line in row.lines)
            _item(line.name, '${line.qty}', store.currency.format(line.total)),
          pw.Divider(),
          pdfPair(l10n.cashierSubtotal, store.currency.format(row.subtotal)),
          if (row.discount > 0) pdfPair(l10n.salesColDiscount, store.currency.format(row.discount)),
          if (service > 0.009) pdfPair(l10n.cashierServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.currency.format(service)),
          pdfPair(l10n.cashierTotalPayable, store.currency.format(row.total)),
          pdfText('${l10n.salesColMethod} ${store.paymentLabel(payment)}'),
          pw.SizedBox(height: 8),
          pdfText(l10n.receiptThankYou, align: pw.TextAlign.center),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _item(String name, String qty, String price) {
  final label = pdfText('$qty  $name');
  final amount = pdfText(price);
  final arabic = pdfHasArabic(name);
  return pw.Row(
    children: arabic ? [amount, pw.Expanded(child: label)] : [pw.Expanded(child: label), amount],
  );
}

Future<void> showReceiptPrint(CafeStore store, Payment payment, AppLocalizations l10n) async {
  final bytes = await receiptPdfBytes(store, payment, l10n);
  await Printing.layoutPdf(
    name: 'receipt-${store.receiptNumber(payment)}',
    onLayout: (format) async => bytes,
  );
}
