import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/choice_labels.dart';
import '../core/report_error.dart';
import '../core/time_format.dart';
import '../features/app_feature.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import 'slip.dart';

/// What happened when a kitchen ticket was asked for.
enum KitchenPrintResult { off, nothingNew, printed, noPrinter, failed }

/// What happened to one order's kitchen tickets: [failed] names each kitchen whose ticket did not
/// print ('' for the cafe's one kitchen when it has no kitchens set up).
class KitchenPrintReport {
  const KitchenPrintReport(this.result, [this.failed = const []]);

  final KitchenPrintResult result;
  final List<String> failed;
}

/// The dishes of one ticket and the kitchen that makes them; [kitchen] is null when the cafe has
/// no kitchens set up.
typedef KitchenTicketGroup = ({Kitchen? kitchen, List<OrderLine> lines});

/// Sends one PDF to a printer; the real one is [TillPrinters.printPdf]. [build] lays the PDF out
/// for that printer's paper width in mm.
typedef PdfSender = Future<KitchenPrintResult> Function(
  String? printerUrl, {
  required String name,
  required Future<Uint8List> Function(int paperMm) build,
});

/// Splits [lines] into one group per kitchen, in kitchen order, keeping the dishes' order.
List<KitchenTicketGroup> splitByKitchen(CafeStore store, List<OrderLine> lines) {
  final byKitchen = <String?, List<OrderLine>>{};
  for (final line in lines) {
    (byKitchen[store.kitchenFor(line.menuItemId)?.id] ??= []).add(line);
  }
  return [
    if (byKitchen.containsKey(null)) (kitchen: null, lines: byKitchen[null]!),
    for (final kitchen in store.orderedKitchens)
      if (byKitchen.containsKey(kitchen.id)) (kitchen: kitchen, lines: byKitchen[kitchen.id]!),
  ];
}

/// This till's printers, picked in Settings from the ones Windows knows: kitchen printers get
/// kitchen tickets (what to cook, no prices) and the cashier printer gets receipts, both with no
/// dialog. The choice belongs to this device, since each till has its own printers. Each kitchen
/// can have its own printer; one without falls back to the main kitchen printer, so no dish is
/// lost. No kitchen printer at all means no kitchen tickets; no cashier printer means receipts
/// open the print dialog.
class TillPrinters {
  static const _kitchenKey = 'kitchenPrinterUrl';
  static const _kitchensKey = 'kitchenPrinterUrls';
  static const _receiptKey = 'receiptPrinterUrl';
  static const _widthsKey = 'printerPaperWidths';
  static const _printedKey = 'kitchenPrintedRounds';

  /// How many printed rounds are remembered, so a round is never printed twice.
  static const _keepPrinted = 300;

  /// Replaced in tests so no real printer is needed.
  @visibleForTesting
  static PdfSender send = printPdf;

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

  /// The printer this till picked for each kitchen, by kitchen id.
  static Future<Map<String, String>> kitchenPrinters() async {
    if (kIsWeb) return const {};
    final raw = (await SharedPreferences.getInstance()).getString(_kitchensKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is String) entry.key.toString(): entry.value as String,
      };
    } on FormatException {
      return const {};
    }
  }

  /// Picks [printerUrl] for [kitchenId] on this till; null or empty clears it.
  static Future<void> saveKitchenPrinter(String kitchenId, String? printerUrl) async {
    final next = {...await kitchenPrinters()}..remove(kitchenId);
    if (printerUrl != null && printerUrl.isNotEmpty) next[kitchenId] = printerUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kitchensKey, jsonEncode(next));
  }

  /// The printer for [kitchen]'s tickets: its own, else the main kitchen printer.
  static String? _printerFor(Kitchen? kitchen, String? main, Map<String, String> perKitchen) =>
      (kitchen == null ? null : perKitchen[kitchen.id]) ?? main;

  static Future<void> saveReceipt(String? printerUrl) => _save(_receiptKey, printerUrl);

  /// The paper width of each printer on this till, in mm, by printer. A printer never set is
  /// [defaultPaperMm], the width every printout had before widths could be picked.
  static Future<Map<String, int>> paperWidths() async {
    if (kIsWeb) return const {};
    final raw = (await SharedPreferences.getInstance()).getString(_widthsKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (paperWidthsMm.contains(entry.value)) entry.key.toString(): entry.value as int,
      };
    } on FormatException {
      return const {};
    }
  }

  static Future<int> paperWidthOf(String? printerUrl) async =>
      printerUrl == null ? defaultPaperMm : (await paperWidths())[printerUrl] ?? defaultPaperMm;

  static Future<void> savePaperWidth(String printerUrl, int paperMm) async {
    if (!paperWidthsMm.contains(paperMm)) return;
    final next = {...await paperWidths(), printerUrl: paperMm};
    await (await SharedPreferences.getInstance()).setString(_widthsKey, jsonEncode(next));
  }

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
  /// order, or only what was added later. Each kitchen gets a ticket with only its own dishes,
  /// and a kitchen whose ticket failed is the only one printed again next time.
  static Future<KitchenPrintReport> printNewRounds(CafeStore store, String orderId, AppLocalizations l10n) async {
    final main = (await settings()).kitchen;
    final perKitchen = await kitchenPrinters();
    if ((main == null && perKitchen.isEmpty) || !store.allows(AppFeature.kitchenPrinter)) {
      return const KitchenPrintReport(KitchenPrintResult.off);
    }
    var order = store.orders.where((item) => item.id == orderId).firstOrNull;
    if (order == null) return const KitchenPrintReport(KitchenPrintResult.nothingNew);
    if (order.shiftOrderNumber == null) {
      // Online the order number is given just after the send; wait for it so the ticket has it.
      await store.ensureShiftNumbers();
      order = store.orders.where((item) => item.id == orderId).firstOrNull ?? order;
    }
    final shown = order;
    final prefs = await SharedPreferences.getInstance();
    final printed = (prefs.getStringList(_printedKey) ?? const <String>[]).toSet();
    // A round printed before kitchens were set up ('order:round') counts for every kitchen.
    String key(int round, Kitchen? kitchen) => kitchen == null ? '$orderId:$round' : '$orderId:$round:${kitchen.id}';
    bool done(int round, Kitchen? kitchen) => printed.contains('$orderId:$round') || printed.contains(key(round, kitchen));
    final groups = [
      for (final group in splitByKitchen(store, shown.lines))
        (kitchen: group.kitchen, lines: [for (final line in group.lines) if (!done(line.round, group.kitchen)) line]),
    ].where((group) => group.lines.isNotEmpty).toList();
    if (groups.isEmpty) return const KitchenPrintReport(KitchenPrintResult.nothingNew);
    final takeout = shown.serviceType == 'takeout';
    final report = await _printGroups(groups, main, perKitchen, name: 'kitchen-$orderId', ticket: (group, paperMm) {
      final rounds = {for (final line in group.lines) line.round};
      return kitchenTicketPdf(
        l10n: l10n,
        number: shown.shiftOrderNumber == null ? '' : store.shiftTicket(shown),
        where: takeout ? l10n.serviceTakeout : l10n.cashierTableShort(shown.tableNumber),
        kitchen: group.kitchen?.name,
        added: rounds.any((round) => round > 1),
        at: DateTime.now(),
        lines: group.lines,
        paperMm: paperMm,
      );
    }, onPrinted: (group) {
      printed.addAll({for (final line in group.lines) key(line.round, group.kitchen)});
    });
    final kept = printed.toList();
    await prefs.setStringList(_printedKey, kept.length > _keepPrinted ? kept.sublist(kept.length - _keepPrinted) : kept);
    return report;
  }

  /// Prints a paid quick takeout: [lines] are the dishes just sold, one ticket per kitchen.
  static Future<KitchenPrintReport> printTakeout(CafeStore store, Payment payment, List<OrderLine> lines, AppLocalizations l10n) async {
    final main = (await settings()).kitchen;
    final perKitchen = await kitchenPrinters();
    if ((main == null && perKitchen.isEmpty) || !store.allows(AppFeature.kitchenPrinter)) {
      return const KitchenPrintReport(KitchenPrintResult.off);
    }
    if (lines.isEmpty) return const KitchenPrintReport(KitchenPrintResult.nothingNew);
    return _printGroups(
      splitByKitchen(store, lines),
      main,
      perKitchen,
      name: 'kitchen-${payment.id}',
      ticket: (group, paperMm) => kitchenTicketPdf(
        l10n: l10n,
        number: payment.shiftOrderNumber == null ? '' : store.orderNumber(payment.shiftOrderNumber),
        where: l10n.serviceTakeout,
        kitchen: group.kitchen?.name,
        added: false,
        at: payment.paidAt,
        lines: group.lines,
        paperMm: paperMm,
      ),
    );
  }

  /// Prints one ticket per group; the report names every kitchen whose ticket did not print.
  static Future<KitchenPrintReport> _printGroups(
    List<KitchenTicketGroup> groups,
    String? main,
    Map<String, String> perKitchen, {
    required String name,
    required Future<Uint8List> Function(KitchenTicketGroup group, int paperMm) ticket,
    void Function(KitchenTicketGroup group)? onPrinted,
  }) async {
    final failed = <String>[];
    var worst = KitchenPrintResult.printed;
    for (final group in groups) {
      final result = await send(
        _printerFor(group.kitchen, main, perKitchen),
        name: group.kitchen == null ? name : '$name-${group.kitchen!.id}',
        build: (paperMm) => ticket(group, paperMm),
      );
      if (result == KitchenPrintResult.printed) {
        onPrinted?.call(group);
      } else {
        failed.add(group.kitchen?.name ?? '');
        worst = result;
      }
    }
    return KitchenPrintReport(worst, failed);
  }

  /// A sample ticket, to check the printer from Settings.
  static Future<KitchenPrintResult> printTest(String? printerUrl, AppLocalizations l10n) {
    return send(
      printerUrl,
      name: 'kitchen-test',
      build: (paperMm) => kitchenTicketPdf(
        paperMm: paperMm,
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
  static Future<KitchenPrintResult> printPdf(String? printerUrl, {required String name, required Future<Uint8List> Function(int paperMm) build}) async {
    if (printerUrl == null || printerUrl.isEmpty) return KitchenPrintResult.noPrinter;
    try {
      final printer = (await printers()).where((item) => item.url == printerUrl).firstOrNull;
      if (printer == null) return KitchenPrintResult.noPrinter;
      final paperMm = await paperWidthOf(printerUrl);
      final bytes = await build(paperMm);
      final done = await Printing.directPrintPdf(printer: printer, name: name, format: rollFormat(paperMm), onLayout: (_) async => bytes);
      return done ? KitchenPrintResult.printed : KitchenPrintResult.failed;
    } catch (error, stackTrace) {
      // Any printer driver failure: the sale is saved, so tell the cashier and carry on.
      reportError('print to $printerUrl', error, stackTrace);
      return KitchenPrintResult.failed;
    }
  }
}

/// One kitchen ticket as slip lines: the kitchen, order number, table or takeout, then each dish
/// with how many and its choices (removed ingredients first, then added toppings). No prices.
List<SlipLine> kitchenSlip({
  required AppLocalizations l10n,
  required String number,
  required String where,
  required bool added,
  required DateTime at,
  required List<OrderLine> lines,
  String? kitchen,
}) =>
    [
      SlipText(l10n.kitchenTicketTitle, center: true, size: 14, bold: true),
      if (kitchen != null && kitchen.isNotEmpty) SlipText(kitchen, center: true, size: 16, bold: true),
      const SlipGap(4),
      if (number.isNotEmpty) SlipText(l10n.cashierOrderNumber(number), center: true, size: 24, bold: true),
      SlipText(where, center: true, size: 18, bold: true),
      if (added) SlipText(l10n.kitchenTicketAdded, center: true, size: 13, bold: true),
      SlipText(formatTripoliDateTime(at), center: true),
      const SlipDivider(),
      for (final line in lines) ...[
        SlipText('${line.qty} × ${line.name}', size: 15, bold: true),
        for (final choice in [...line.choices.where((choice) => !choice.on), ...line.choices.where((choice) => choice.on)])
          SlipText(choiceText(choice, l10n.localeName, without: l10n.dishChoiceWithout), size: 12, indent: true),
        const SlipGap(),
      ],
    ];

/// One kitchen ticket on a roll [paperMm] wide; see [kitchenSlip].
Future<Uint8List> kitchenTicketPdf({
  required AppLocalizations l10n,
  required String number,
  required String where,
  required bool added,
  required DateTime at,
  required List<OrderLine> lines,
  String? kitchen,
  int paperMm = defaultPaperMm,
}) =>
    slipPdf(
      kitchenSlip(l10n: l10n, number: number, where: where, added: added, at: at, lines: lines, kitchen: kitchen),
      paperMm: paperMm,
    );
