import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/ledger.dart';
import '../core/sales_report.dart';
import '../features/app_feature.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../printing/export_pdfs.dart';
import '../printing/kitchen_ticket.dart';
import '../printing/receipt_print.dart';
import '../printing/receipt_settings.dart';
import '../printing/report_print.dart';
import '../printing/slip.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/tawla_ui.dart';

/// Shows one printout's PDF. The app shows the real page ([pdfPagePreview]); tests swap in a
/// stand-in, since drawing a PDF page needs the printing plugin.
typedef PrintPreviewBuilder = Widget Function({required String label, required PdfPageFormat format, required Future<Uint8List> Function() build});

Widget pdfPagePreview({required String label, required PdfPageFormat format, required Future<Uint8List> Function() build}) {
  final thermal = format.width < PdfPageFormat.a5.width;
  return SizedBox(
    width: thermal ? 280 : 520,
    height: thermal ? 560 : 420,
    child: PdfPreview(
      build: (_) => build(),
      initialPageFormat: format,
      pdfFileName: '$label.pdf',
      useActions: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: false,
      padding: EdgeInsets.zero,
      previewPageMargin: const EdgeInsets.all(6),
    ),
  );
}

/// The printouts the preview can show.
sealed class _Printout {
  const _Printout();
}

final class _Receipt extends _Printout {
  const _Receipt({required this.takeout});

  final bool takeout;

  @override
  bool operator ==(Object other) => other is _Receipt && other.takeout == takeout;

  @override
  int get hashCode => takeout.hashCode;
}

/// A kitchen's ticket; [kitchen] is null for a cafe with no kitchens set up.
final class _KitchenTicket extends _Printout {
  const _KitchenTicket(this.kitchen);

  final Kitchen? kitchen;

  @override
  bool operator ==(Object other) => other is _KitchenTicket && other.kitchen?.id == kitchen?.id;

  @override
  int get hashCode => kitchen?.id.hashCode ?? 0;
}

final class _Report extends _Printout {
  const _Report();

  @override
  bool operator ==(Object other) => other is _Report;

  @override
  int get hashCode => 3;
}

final class _SalesLog extends _Printout {
  const _SalesLog();

  @override
  bool operator ==(Object other) => other is _SalesLog;

  @override
  int get hashCode => 1;
}

final class _Expenses extends _Printout {
  const _Expenses();

  @override
  bool operator ==(Object other) => other is _Expenses;

  @override
  int get hashCode => 2;
}

/// Settings → Receipts & printouts. On top, what every till prints (saved with the cafe): cafe
/// name and logo, header and footer, which lines show. Then this till's paper width for each of
/// its printers (saved on this device). Below, a live preview of each printout, drawn by the
/// same builder the printer gets, at this till's paper width (both widths when the printout has
/// no printer here).
class ReceiptEditorCard extends StatefulWidget {
  const ReceiptEditorCard({super.key});

  @visibleForTesting
  static PrintPreviewBuilder preview = pdfPagePreview;

  @override
  State<ReceiptEditorCard> createState() => _ReceiptEditorCardState();
}

class _ReceiptEditorCardState extends State<ReceiptEditorCard> {
  late ReceiptSettings saved;
  late ReceiptSettings draft;
  late final header = TextEditingController();
  late final footer = TextEditingController();
  bool saving = false;
  _Printout showing = const _Receipt(takeout: false);

  // This till's printers.
  bool printersSupported = false;
  List<Printer> printers = const [];
  String? receiptPrinter;
  String? kitchenPrinter;
  Map<String, String> kitchenPrinters = const {};
  Map<String, int> widths = const {};

  @override
  void initState() {
    super.initState();
    saved = context.read<CafeStore>().receiptSettings;
    _startDraft(saved);
    _loadPrinters();
  }

  @override
  void dispose() {
    header.dispose();
    footer.dispose();
    super.dispose();
  }

  void _startDraft(ReceiptSettings value) {
    draft = value;
    header.text = value.header;
    footer.text = value.footer;
  }

  Future<void> _loadPrinters() async {
    final ok = await TillPrinters.supported();
    var found = const <Printer>[];
    if (ok) {
      try {
        found = await TillPrinters.printers();
      } on Exception {
        found = const [];
      }
    }
    final picked = await TillPrinters.settings();
    final perKitchen = await TillPrinters.kitchenPrinters();
    final paper = await TillPrinters.paperWidths();
    if (!mounted) return;
    setState(() {
      printersSupported = ok;
      printers = found;
      receiptPrinter = picked.receipt;
      kitchenPrinter = picked.kitchen;
      kitchenPrinters = perKitchen;
      widths = paper;
    });
  }

  Future<void> _save(CafeStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => saving = true);
    await store.saveReceiptSettings(draft);
    if (!mounted) return;
    setState(() {
      saving = false;
      saved = draft;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.receiptSaved)));
  }

  Future<void> _setWidth(String printerUrl, int paperMm) async {
    await TillPrinters.savePaperWidth(printerUrl, paperMm);
    final paper = await TillPrinters.paperWidths();
    if (mounted) setState(() => widths = paper);
  }

  String _printerName(String url) => printers.where((printer) => printer.url == url).firstOrNull?.name ?? url;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    // Saved elsewhere (another till) while nothing was being edited here: show the new settings.
    final latest = store.receiptSettings;
    if (latest != saved && draft == saved) {
      saved = latest;
      _startDraft(latest);
    }
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.receiptEditorTitle, size: 18),
          const SizedBox(height: 4),
          Text(context.l10n.receiptEditorHint, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
          const SizedBox(height: 14),
          EyebrowLabel(context.l10n.settingsScopeWholeCafe),
          ..._cafeWide(store),
          const SizedBox(height: 18),
          const Divider(height: 1, color: TawlaTokens.border),
          const SizedBox(height: 14),
          EyebrowLabel(context.l10n.settingsScopeThisTill),
          const SizedBox(height: 6),
          ..._paperWidths(store),
          const SizedBox(height: 18),
          const Divider(height: 1, color: TawlaTokens.border),
          const SizedBox(height: 14),
          PanelTitle(context.l10n.receiptPreviewTitle, size: 16),
          const SizedBox(height: 8),
          _printoutPicker(store),
          const SizedBox(height: 12),
          _preview(store),
        ],
      ),
    );
  }

  List<Widget> _cafeWide(CafeStore store) {
    void set(ReceiptSettings next) => setState(() => draft = next);
    final lines = <(String, bool, ReceiptSettings Function(bool))>[
      (context.l10n.receiptLineOrderNumber, draft.showOrderNumber, (on) => draft.copyWith(showOrderNumber: on)),
      (context.l10n.receiptLineTable, draft.showTable, (on) => draft.copyWith(showTable: on)),
      (context.l10n.receiptLineDate, draft.showDate, (on) => draft.copyWith(showDate: on)),
      (context.l10n.receiptLineCashier, draft.showCashier, (on) => draft.copyWith(showCashier: on)),
      (context.l10n.receiptLineChoices, draft.showChoices, (on) => draft.copyWith(showChoices: on)),
      (context.l10n.receiptLineDiscount, draft.showDiscount, (on) => draft.copyWith(showDiscount: on)),
      (context.l10n.receiptLineService, draft.showServiceCharge, (on) => draft.copyWith(showServiceCharge: on)),
      (context.l10n.receiptLineMethod, draft.showPaymentMethod, (on) => draft.copyWith(showPaymentMethod: on)),
    ];
    return [
      SwitchRow(
        title: context.l10n.receiptShowCafeName,
        hint: store.cafeName,
        value: draft.showCafeName,
        onChanged: (on) => set(draft.copyWith(showCafeName: on)),
      ),
      SwitchRow(
        title: context.l10n.receiptShowLogo,
        hint: store.logoUrl.isEmpty ? context.l10n.receiptNoLogo : '',
        value: draft.showLogo,
        onChanged: (on) => set(draft.copyWith(showLogo: on)),
      ),
      const SizedBox(height: 10),
      LabeledField(
        label: context.l10n.receiptHeader,
        child: TextField(
          controller: header,
          minLines: 1,
          maxLines: 3,
          maxLength: ReceiptSettings.maxTextLength,
          decoration: InputDecoration(hintText: context.l10n.receiptHeaderHint),
          onChanged: (value) => set(draft.copyWith(header: value.trim())),
        ),
      ),
      LabeledField(
        label: context.l10n.receiptFooter,
        child: TextField(
          controller: footer,
          maxLength: ReceiptSettings.maxTextLength,
          decoration: InputDecoration(hintText: context.l10n.receiptFooterHint(context.l10n.receiptThankYou)),
          onChanged: (value) => set(draft.copyWith(footer: value.trim())),
        ),
      ),
      Text(context.l10n.receiptLinesTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, on, change) in lines)
            FilterChip(
              label: Text(label, style: TextStyle(color: on ? CafeSurfaces.of(context).onButton : CafeColors.ink)),
              selected: on,
              onSelected: (value) => set(change(value)),
            ),
        ],
      ),
      const SizedBox(height: 14),
      NavyButton(label: context.l10n.receiptSave, onPressed: saving || draft == saved ? null : () => _save(store)),
    ];
  }

  /// Each printer picked on this till, with its paper width.
  List<Widget> _paperWidths(CafeStore store) {
    final kitchenOn = store.allows(AppFeature.kitchenPrinter);
    final picked = <(String, String)>[
      if (receiptPrinter case final url?) (context.l10n.printersReceipt, url),
      if (kitchenOn)
        if (kitchenPrinter case final url?) (store.kitchens.isEmpty ? context.l10n.printersKitchen : context.l10n.kitchensPrinterMain, url),
      if (kitchenOn)
        for (final kitchen in store.orderedKitchens)
          if (kitchenPrinters[kitchen.id] case final url?) (kitchen.name, url),
    ];
    if (!printersSupported || picked.isEmpty) {
      return [
        Text(
          kIsWeb || !printersSupported ? context.l10n.receiptPaperWeb : context.l10n.receiptPaperNone,
          style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
        ),
      ];
    }
    return [
      Text(context.l10n.receiptPaperTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      for (final (role, url) in picked)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: Text(context.l10n.receiptPrinterOf(role, _printerName(url)), overflow: TextOverflow.ellipsis)),
              SegmentedPills<int>(
                height: 36,
                options: [for (final mm in paperWidthsMm) (mm, context.l10n.receiptPaperMm(mm))],
                selected: widths[url] ?? defaultPaperMm,
                onSelected: (mm) => _setWidth(url, mm),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _printoutPicker(CafeStore store) {
    final options = <(_Printout, String)>[
      (const _Receipt(takeout: false), context.l10n.receiptPreviewReceipt),
      (const _Receipt(takeout: true), context.l10n.receiptPreviewTakeout),
      if (store.allows(AppFeature.kitchenPrinter)) ...[
        if (store.kitchens.isEmpty) (const _KitchenTicket(null), context.l10n.receiptPreviewKitchen),
        for (final kitchen in store.orderedKitchens) (_KitchenTicket(kitchen), context.l10n.receiptPreviewKitchenOf(kitchen.name)),
      ],
      (const _Report(), context.l10n.receiptPreviewReport),
      (const _SalesLog(), context.l10n.receiptPreviewSalesLog),
      if (store.allows(AppFeature.expenses)) (const _Expenses(), context.l10n.receiptPreviewExpenses),
    ];
    // A kitchen deleted (or a feature turned off) while its preview was showing.
    if (!options.any((option) => option.$1 == showing)) showing = options.first.$1;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (printout, label) in options)
          ChoiceChip(label: Text(label), selected: printout == showing, onSelected: (_) => setState(() => showing = printout)),
      ],
    );
  }

  /// The printer this till uses for [printout], or null when it has none (or it is an A4 export).
  String? _printerFor(_Printout printout) => switch (printout) {
        _Receipt() || _Report() => receiptPrinter,
        _KitchenTicket(:final kitchen) => (kitchen == null ? null : kitchenPrinters[kitchen.id]) ?? kitchenPrinter,
        _SalesLog() || _Expenses() => null,
      };

  Widget _preview(CafeStore store) {
    final l10n = context.l10n;
    final printout = showing;
    if (printout is _SalesLog || printout is _Expenses) {
      final sales = printout is _SalesLog;
      final columns = sales ? salesLogCsvColumns(l10n) : expensesCsvColumns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.receiptPreviewA4, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
          const SizedBox(height: 8),
          ReceiptEditorCard.preview(
            label: sales ? 'sales-log' : 'wages',
            format: PdfPageFormat.a4.landscape,
            build: sales
                ? () => salesLogPdf(store, saleLedgerRows(store, includeVoided: true).take(20).toList(), l10n)
                : () => expensesPdf(store, expenseLedgerRows(store).take(20).toList()),
          ),
          const SizedBox(height: 8),
          Text(l10n.receiptCsvColumns(columns.join(', ')), style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
        ],
      );
    }
    final printer = _printerFor(printout);
    final paper = printer == null ? paperWidthsMm : [widths[printer] ?? defaultPaperMm];
    final slip = switch (printout) {
      _Receipt(:final takeout) => receiptSlip(store, ReceiptData.sample(store, l10n, takeout: takeout), l10n, settings: draft),
      _KitchenTicket(:final kitchen) => _sampleTicket(store, kitchen),
      _Report() => _sampleReport(store),
      _SalesLog() || _Expenses() => const <SlipLine>[],
    };
    // A new key when the content changes, so the page is drawn again.
    final signature = jsonEncode([for (final line in slip) line.toString(), draft.toJson(), store.logoUrl.length]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          printer == null ? l10n.receiptPreviewBothWidths : l10n.receiptPreviewPrinterWidth(paper.single),
          style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
        ),
        if (printout is _KitchenTicket) ...[
          const SizedBox(height: 4),
          Text(l10n.receiptKitchenFixed, style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final mm in paper)
              Column(
                key: ValueKey('$signature|$mm'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.receiptPaperMm(mm), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ReceiptEditorCard.preview(
                    label: 'slip-$mm',
                    format: rollFormat(mm),
                    build: () => slipPdf(slip, paperMm: mm),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// A made-up day's report, laid out as the report printout.
  List<SlipLine> _sampleReport(CafeStore store) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final cash = store.paymentTypes.firstOrNull;
    final report = SalesReport(
      from: now,
      to: now,
      salesCount: 12,
      salesTotal: 345.5,
      voidCount: 1,
      voidTotal: 20,
      methods: [ReportMethod(id: cash?.id, nameEn: cash?.nameEn ?? l10n.receiptSampleMethod, nameAr: cash?.nameAr ?? '', count: 12, total: 345.5)],
      expenses: [
        ReportExpenseGroup(typeKey: 'cafe', typeId: null, typeEn: 'Café Expense', typeAr: 'مصروف المقهى', employeeId: null, employee: '', count: 3, total: 60),
        ReportExpenseGroup(
          typeKey: 'withdrawal',
          typeId: null,
          typeEn: 'Cash Withdrawal',
          typeAr: 'سحب نقدي',
          employeeId: 'sample',
          employee: store.cashiers.firstOrNull?.name ?? l10n.receiptSampleCashier,
          count: 1,
          total: 50,
        ),
      ],
    );
    return reportSlip(
      report: report,
      cafeName: store.cafeName,
      rangeLabel: l10n.reportRangeToday,
      printedAt: now,
      l10n: l10n,
      money: store.currency.format,
    );
  }

  /// A sample ticket for [kitchen]: the first dishes of its categories, or a test dish.
  List<SlipLine> _sampleTicket(CafeStore store, Kitchen? kitchen) {
    final l10n = context.l10n;
    final dishes = store.menuItems.where((item) => kitchen == null || store.kitchenFor(item.id)?.id == kitchen.id).take(2).toList();
    final lines = dishes.isEmpty
        ? [OrderLine(menuItemId: 'sample', name: l10n.kitchenTestDish, qty: 2, unitPrice: 0)]
        : [for (final dish in dishes) OrderLine(menuItemId: dish.id, name: dish.displayName(store.locale), qty: 1, unitPrice: dish.price)];
    return kitchenSlip(
      l10n: l10n,
      number: store.orderNumber(7),
      where: l10n.cashierTableShort('4'),
      kitchen: kitchen?.name,
      added: false,
      at: DateTime.now(),
      lines: lines,
    );
  }
}
