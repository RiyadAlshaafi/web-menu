import 'package:flutter/foundation.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

import '../core/sales_report.dart';
import '../core/time_format.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import 'kitchen_ticket.dart';
import 'slip.dart';

/// Where a report goes: this till's cashier printer, or the print preview (web, or no printer).
enum ReportOutput { printer, preview }

/// The summary report as slip lines: cafe and range on top, then sales and their payment types,
/// voids, expenses by type and by employee, net, then the best and slow sellers of [menu] when
/// the report knows its dishes. A summary, not every receipt.
List<SlipLine> reportSlip({
  required SalesReport report,
  required String cafeName,
  required String rangeLabel,
  required DateTime printedAt,
  required AppLocalizations l10n,
  required String Function(double) money,
  List<MenuItem> menu = const [],
}) {
  final locale = l10n.localeName;
  String name(String en, String ar) => locale == 'ar' && ar.isNotEmpty ? ar : en;
  final dishNames = {for (final item in menu) item.id: item.displayName(locale)};
  SlipLine dish(ReportDish dish) => SlipPair('  ${l10n.reportDishLine(dish.qty, dishNames[dish.id] ?? dish.name)}', money(dish.total));
  final best = report.bestSellers();
  final slow = report.slowSellers(menu, locale);
  return [
    SlipText(cafeName, center: true, size: 14, bold: true),
    SlipText(l10n.reportTitle, center: true, size: 13, bold: true),
    SlipText(rangeLabel, center: true),
    SlipText(l10n.reportPrintedAt(formatTripoliDateTime(printedAt)), center: true, size: 8),
    const SlipDivider(),
    if (report.isEmpty) ...[
      SlipText(l10n.reportEmpty, center: true),
      const SlipDivider(),
    ],
    SlipPair(l10n.reportSales(report.salesCount), money(report.salesTotal), bold: true),
    for (final method in report.methods)
      SlipPair('  ${l10n.reportCountOf(method.label(locale).isEmpty ? l10n.reportNoMethod : method.label(locale), method.count)}', money(method.total)),
    const SlipGap(4),
    SlipPair(l10n.reportVoids(report.voidCount), money(report.voidTotal)),
    const SlipDivider(),
    SlipPair(l10n.reportExpenses, money(report.expensesTotal), bold: true),
    if (report.expenses.isNotEmpty) ...[
      SlipText(l10n.reportByType, size: 9, bold: true),
      for (final line in report.expensesByType) SlipPair('  ${l10n.reportCountOf(name(line.nameEn, line.nameAr), line.count)}', money(line.total)),
      SlipText(l10n.reportByEmployee, size: 9, bold: true),
      for (final line in report.expensesByEmployee)
        SlipPair('  ${l10n.reportCountOf(line.id == null ? l10n.expenseNoEmployee : line.nameEn, line.count)}', money(line.total)),
    ],
    const SlipDivider(),
    SlipPair(l10n.reportNet, money(report.net), bold: true),
    if (best.isNotEmpty) ...[
      const SlipDivider(),
      SlipText(l10n.reportBestSellers, size: 9, bold: true),
      for (final line in best) dish(line),
    ],
    if (slow.isNotEmpty) ...[
      const SlipGap(4),
      SlipText(l10n.reportSlowSellers, size: 9, bold: true),
      for (final line in slow) dish(line),
    ],
  ];
}

/// Prints [report] on this till's cashier printer at its paper width, or opens the print preview
/// (80 mm) when there is none. Throws when the printer did not print.
class ReportPrinter {
  /// Replaced in tests so no printer or print dialog is needed.
  @visibleForTesting
  static Future<ReportOutput> Function(List<SlipLine> lines, String name) send = sendToTill;

  /// Where the report will go on this till, so the admin is told before printing.
  static Future<({ReportOutput output, String? printer, int paperMm})> target() async {
    final url = (await TillPrinters.settings()).receipt;
    if (url == null || !await TillPrinters.supported()) return (output: ReportOutput.preview, printer: null, paperMm: defaultPaperMm);
    var name = url;
    try {
      name = (await TillPrinters.printers()).where((printer) => printer.url == url).firstOrNull?.name ?? url;
    } on Exception {
      name = url;
    }
    return (output: ReportOutput.printer, printer: name, paperMm: await TillPrinters.paperWidthOf(url));
  }

  static Future<ReportOutput> print(CafeStore store, SalesReport report, AppLocalizations l10n, String rangeLabel) {
    final lines = reportSlip(
      report: report,
      cafeName: store.cafeName,
      rangeLabel: rangeLabel,
      printedAt: DateTime.now(),
      l10n: l10n,
      money: store.currency.format,
      menu: store.menuItems,
    );
    return send(lines, 'report-${formatTripoliDate(report.from)}-${formatTripoliDate(report.to)}');
  }

  /// The real [send]: the cashier printer when this till has one, else the print preview.
  static Future<ReportOutput> sendToTill(List<SlipLine> lines, String name) async {
    final url = (await TillPrinters.settings()).receipt;
    if (url != null && await TillPrinters.supported()) {
      final result = await TillPrinters.printPdf(url, name: name, build: (paperMm) => slipPdf(lines, paperMm: paperMm));
      if (result != KitchenPrintResult.printed) throw StateError('report printer: ${result.name}');
      return ReportOutput.printer;
    }
    final bytes = await slipPdf(lines, paperMm: defaultPaperMm);
    await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
    return ReportOutput.preview;
  }
}
