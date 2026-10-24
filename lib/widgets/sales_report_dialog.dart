import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/money.dart';
import '../core/sales_report.dart';
import '../l10n/l10n_ext.dart';
import '../printing/report_print.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import 'tawla_ui.dart';

/// Which days a report covers.
enum ReportRangeKind { today, month, custom }

/// The Tripoli calendar days a report covers: today, the whole [month], or [from] to [to].
/// Null when a custom range is missing a day or runs backwards.
({DateTime from, DateTime to})? reportRange(ReportRangeKind kind, {required DateTime now, DateTime? month, DateTime? from, DateTime? to}) {
  final local = toTripoli(now);
  final today = DateTime(local.year, local.month, local.day);
  switch (kind) {
    case ReportRangeKind.today:
      return (from: today, to: today);
    case ReportRangeKind.month:
      final first = DateTime((month ?? today).year, (month ?? today).month, 1);
      final last = DateTime(first.year, first.month + 1, 0);
      return (from: first, to: last.isAfter(today) ? today : last);
    case ReportRangeKind.custom:
      if (from == null || to == null || to.isBefore(from)) return null;
      return (from: DateTime(from.year, from.month, from.day), to: DateTime(to.year, to.month, to.day));
  }
}

/// A button that opens [SalesReportDialog].
class PrintReportButton extends StatelessWidget {
  const PrintReportButton({super.key, this.height = 44});

  final double height;

  @override
  Widget build(BuildContext context) => OutlineAction(
        label: context.l10n.reportButton,
        icon: Icons.summarize_outlined,
        height: height,
        onPressed: () => showDialog<void>(context: context, builder: (_) => const SalesReportDialog()),
      );
}

/// Picks the days (today, a month, or from–to in Tripoli time), says where the report will go,
/// then fetches the totals (server online, local SQLite offline) and prints them.
class SalesReportDialog extends StatefulWidget {
  const SalesReportDialog({super.key});

  @override
  State<SalesReportDialog> createState() => _SalesReportDialogState();
}

class _SalesReportDialogState extends State<SalesReportDialog> {
  ReportRangeKind kind = ReportRangeKind.today;
  late DateTime month;
  DateTime? from;
  DateTime? to;
  bool busy = false;
  String? error;
  ({ReportOutput output, String? printer, int paperMm})? target;

  @override
  void initState() {
    super.initState();
    final now = toTripoli(DateTime.now());
    month = DateTime(now.year, now.month);
    ReportPrinter.target().then((value) {
      if (mounted) setState(() => target = value);
    });
  }

  String _rangeLabel(({DateTime from, DateTime to}) range) {
    final l10n = context.l10n;
    String day(DateTime value) => DateFormat('y-MM-dd').format(value);
    return switch (kind) {
      ReportRangeKind.today => l10n.reportToday(day(range.from)),
      ReportRangeKind.month => DateFormat.yMMMM(l10n.localeName).format(range.from),
      ReportRangeKind.custom => range.from == range.to ? day(range.from) : l10n.reportFromTo(day(range.from), day(range.to)),
    };
  }

  Future<void> _print() async {
    final range = reportRange(kind, now: DateTime.now(), month: month, from: from, to: to);
    final l10n = context.l10n;
    final store = context.read<CafeStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (range == null) {
      setState(() => error = l10n.reportPickDays);
      return;
    }
    if (range.to.difference(range.from).inDays > maxReportDays) {
      setState(() => error = l10n.reportTooLong(maxReportDays));
      return;
    }
    final label = _rangeLabel(range);
    setState(() {
      busy = true;
      error = null;
    });
    final result = await store.salesReport(range.from, range.to);
    if (!mounted) return;
    final report = result.report;
    if (report == null) {
      setState(() {
        busy = false;
        error = l10n.reportFailed(l10n.errorText(result.error ?? ''));
      });
      return;
    }
    try {
      final output = await ReportPrinter.print(store, report, l10n, label);
      navigator.pop();
      if (output == ReportOutput.printer) messenger.showSnackBar(SnackBar(content: Text(l10n.reportPrinted)));
    } on Object {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = l10n.reportPrinterFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = toTripoli(DateTime.now());
    final months = [for (var back = 0; back < 12; back++) DateTime(now.year, now.month - back)];
    final where = target;
    return AlertDialog(
      title: Text(l10n.reportTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedPills<ReportRangeKind>(
              options: [
                (ReportRangeKind.today, l10n.reportRangeToday),
                (ReportRangeKind.month, l10n.reportRangeMonth),
                (ReportRangeKind.custom, l10n.reportRangeCustom),
              ],
              selected: kind,
              onSelected: (value) => setState(() {
                kind = value;
                error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (kind == ReportRangeKind.month)
              SelectBox<DateTime>(
                value: month,
                height: 48,
                items: [for (final item in months) DropdownMenuItem(value: item, child: Text(DateFormat.yMMMM(l10n.localeName).format(item)))],
                onChanged: (value) => setState(() => month = value ?? month),
              ),
            if (kind == ReportRangeKind.custom)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  DateBox(label: l10n.salesDateFrom, value: from, onPicked: (value) => setState(() => from = value)),
                  DateBox(label: l10n.salesDateTo, value: to, onPicked: (value) => setState(() => to = value)),
                ],
              ),
            const SizedBox(height: 10),
            Text(l10n.reportTripoliNote, style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Text(
              switch (where) {
                null => l10n.printersLooking,
                (output: ReportOutput.printer, :final printer, :final paperMm) => l10n.reportGoesToPrinter(printer ?? '', paperMm),
                _ => l10n.reportGoesToPreview,
              },
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: busy ? null : _print, child: Text(busy ? l10n.reportWorking : l10n.reportPrint)),
      ],
    );
  }
}
