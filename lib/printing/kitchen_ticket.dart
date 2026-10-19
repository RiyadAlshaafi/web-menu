import 'package:flutter/foundation.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/choice_labels.dart';
import '../core/report_error.dart';
import '../core/time_format.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import 'pdf_text.dart';

/// What happened when a kitchen ticket was asked for.
enum KitchenPrintResult { off, nothingNew, printed, noPrinter, failed }

/// This till's printers, picked in Settings from the ones Windows knows: the kitchen printer gets
/// kitchen tickets (what to cook, no prices) and the cashier printer gets receipts, both with no
/// dialog. The choice belongs to this device, since each till has its own printers. No kitchen
/// printer means no kitchen tickets; no cashier printer means receipts open the print dialog.
class TillPrinters {
  static const _kitchenKey = 'kitchenPrinterUrl';
  static const _receiptKey = 'receiptPrinterUrl';
  static const _printedKey = 'kitchenPrintedRounds';

  /// How many printed rounds are remembered, so a round is never printed twice.
  static const _keepPrinted = 300;

  /// Direct printing to a named printer works on the Windows till only.
  static Future<bool> supported() async {
    if (kIsWeb) return false;
    try {
      final info = await Printing.info();
      return info.directPrint && info.canListPrinters;
    } on Exception {
      return false;
    }
  }

  static Future<({String? kitchen, String? receipt})> settings() async {
    if (kIsWeb) return (kitchen: null, receipt: null);
    final prefs = await SharedPreferences.getInstance();
    return (kitchen: prefs.getString(_kitchenKey), receipt: prefs.getString(_receiptKey));
  }

  static Future<void> saveKitchen(String? printerUrl) => _save(_kitchenKey, printerUrl);

  static Future<void> saveReceipt(String? printerUrl) => _save(_receiptKey, printerUrl);

  static Future<void> _save(String key, String? printerUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (printerUrl == null || printerUrl.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, printerUrl);
    }
  }

  static Future<List<Printer>> printers() => Printing.listPrinters();

  /// Prints the rounds of [orderId] this till has not printed yet: the first round of a new
  /// order, or only what was added later.
  static Future<KitchenPrintResult> printNewRounds(CafeStore store, String orderId, AppLocalizations l10n) async {
    final kitchen = (await settings()).kitchen;
    if (kitchen == null) return KitchenPrintResult.off;
    var order = store.orders.where((item) => item.id == orderId).firstOrNull;
    if (order == null) return KitchenPrintResult.nothingNew;
    if (order.shiftOrderNumber == null) {
      // Online the order number is given just after the send; wait for it so the ticket has it.
      await store.ensureShiftNumbers();
      order = store.orders.where((item) => item.id == orderId).firstOrNull ?? order;
    }
    final prefs = await SharedPreferences.getInstance();
    final printed = prefs.getStringList(_printedKey) ?? const <String>[];
    final rounds = {for (final line in order.lines) line.round}.where((round) => !printed.contains('$orderId:$round')).toList()
      ..sort();
    if (rounds.isEmpty) return KitchenPrintResult.nothingNew;
    final takeout = order.serviceType == 'takeout';
    final result = await printPdf(
      kitchen,
      name: 'kitchen-${order.id}',
      build: () => kitchenTicketPdf(
        l10n: l10n,
        number: order!.shiftOrderNumber == null ? '' : store.shiftTicket(order),
        where: takeout ? l10n.serviceTakeout : l10n.cashierTableShort(order.tableNumber),
        added: rounds.first > 1,
        at: DateTime.now(),
        lines: [for (final round in rounds) ...order.linesInRound(round)],
      ),
    );
    if (result == KitchenPrintResult.printed) {
      final next = [...printed, for (final round in rounds) '$orderId:$round'];
      await prefs.setStringList(_printedKey, next.length > _keepPrinted ? next.sublist(next.length - _keepPrinted) : next);
    }
    return result;
  }

  /// Prints a paid quick takeout: [lines] are the dishes just sold.
  static Future<KitchenPrintResult> printTakeout(CafeStore store, Payment payment, List<OrderLine> lines, AppLocalizations l10n) async {
    final kitchen = (await settings()).kitchen;
    if (kitchen == null) return KitchenPrintResult.off;
    if (lines.isEmpty) return KitchenPrintResult.nothingNew;
    return printPdf(
      kitchen,
      name: 'kitchen-${payment.id}',
      build: () => kitchenTicketPdf(
        l10n: l10n,
        number: payment.shiftOrderNumber == null ? '' : store.orderNumber(payment.shiftOrderNumber),
        where: l10n.serviceTakeout,
        added: false,
        at: payment.paidAt,
        lines: lines,
      ),
    );
  }

  /// A sample ticket, to check the printer from Settings.
  static Future<KitchenPrintResult> printTest(String? printerUrl, AppLocalizations l10n) {
    return printPdf(
      printerUrl,
      name: 'kitchen-test',
      build: () => kitchenTicketPdf(
        l10n: l10n,
        number: '1',
        where: l10n.cashierTableShort('1'),
        added: false,
        at: DateTime.now(),
        lines: [OrderLine(menuItemId: 'test', name: l10n.kitchenTestDish, qty: 2, unitPrice: 0)],
      ),
    );
  }

  /// Prints the PDF from [build] on the printer [printerUrl] with no dialog.
  static Future<KitchenPrintResult> printPdf(String? printerUrl, {required String name, required Future<Uint8List> Function() build}) async {
    if (printerUrl == null || printerUrl.isEmpty) return KitchenPrintResult.noPrinter;
    try {
      final printer = (await printers()).where((item) => item.url == printerUrl).firstOrNull;
      if (printer == null) return KitchenPrintResult.noPrinter;
      final bytes = await build();
      final done = await Printing.directPrintPdf(printer: printer, name: name, format: PdfPageFormat.roll80, onLayout: (_) async => bytes);
      return done ? KitchenPrintResult.printed : KitchenPrintResult.failed;
    } catch (error, stackTrace) {
      // Any printer driver failure: the sale is saved, so tell the cashier and carry on.
      reportError('print to $printerUrl', error, stackTrace);
      return KitchenPrintResult.failed;
    }
  }
}

/// One kitchen ticket on an 80 mm roll: order number, table or takeout, then each dish with how
/// many and its choices (added toppings, removed ingredients). No prices.
Future<Uint8List> kitchenTicketPdf({
  required AppLocalizations l10n,
  required String number,
  required String where,
  required bool added,
  required DateTime at,
  required List<OrderLine> lines,
}) async {
  final theme = await PdfFonts.theme();
  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      theme: theme,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pdfText(l10n.kitchenTicketTitle, align: pw.TextAlign.center, size: 14, bold: true),
          pw.SizedBox(height: 4),
          if (number.isNotEmpty) pdfText(l10n.cashierOrderNumber(number), align: pw.TextAlign.center, size: 24, bold: true),
          pdfText(where, align: pw.TextAlign.center, size: 18, bold: true),
          if (added) pdfText(l10n.kitchenTicketAdded, align: pw.TextAlign.center, size: 13, bold: true),
          pdfText(formatTripoliDateTime(at), align: pw.TextAlign.center, size: 10),
          pw.Divider(),
          for (final line in lines) ...[
            pdfText('${line.qty} × ${line.name}', size: 15, bold: true),
            for (final choice in [...line.choices.where((choice) => !choice.on), ...line.choices.where((choice) => choice.on)])
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pdfText(choiceText(choice, l10n.localeName, without: l10n.dishChoiceWithout), size: 12),
              ),
            pw.SizedBox(height: 6),
          ],
        ],
      ),
    ),
  );
  return doc.save();
}
