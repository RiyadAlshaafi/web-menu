import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../features/app_feature.dart';
import '../printing/kitchen_ticket.dart';
import '../state/cafe_store.dart';
import '../widgets/tawla_ui.dart';

/// This till's printers, from the ones Windows finds: which one is the kitchen printer (kitchen
/// tickets) and which is the cashier printer (receipts). Saved on this device only.
class PrintersCard extends StatefulWidget {
  const PrintersCard({super.key});

  @override
  State<PrintersCard> createState() => _PrintersCardState();
}

class _PrintersCardState extends State<PrintersCard> {
  bool loading = true;
  bool supported = false;
  bool testing = false;
  List<Printer> printers = const [];
  String? kitchen;
  String? receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final ok = await TillPrinters.supported();
    var found = const <Printer>[];
    var saved = (kitchen: null as String?, receipt: null as String?);
    if (ok) {
      try {
        found = await TillPrinters.printers();
      } on Exception {
        found = const [];
      }
      saved = await TillPrinters.settings();
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      supported = ok;
      printers = found;
      kitchen = saved.kitchen;
      receipt = saved.receipt;
    });
  }

  Future<void> _test() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => testing = true);
    final result = await TillPrinters.printTest(kitchen, l10n);
    if (!mounted) return;
    setState(() => testing = false);
    messenger.showSnackBar(SnackBar(content: Text(result == KitchenPrintResult.printed ? l10n.printersTestSent : l10n.kitchenPrintFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final kitchenOn = context.watch<CafeStore>().allows(AppFeature.kitchenPrinter);
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: PanelTitle(context.l10n.printersTitle, size: 18)),
              if (supported)
                IconButton(
                  tooltip: context.l10n.printersRefresh,
                  onPressed: loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            !supported
                ? context.l10n.printersWindowsOnly
                : kitchenOn
                    ? context.l10n.printersHint
                    : context.l10n.printersReceiptHint,
            style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(context.l10n.printersLooking, style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          else if (supported) ...[
            if (kitchenOn) ...[
            const SizedBox(height: 14),
            _picker(
              label: context.l10n.printersKitchen,
              none: context.l10n.printersKitchenNone,
              value: kitchen,
              onChanged: (value) {
                setState(() => kitchen = value);
                TillPrinters.saveKitchen(value);
              },
            ),
            ],
            const SizedBox(height: 12),
            _picker(
              label: context.l10n.printersReceipt,
              none: context.l10n.printersReceiptNone,
              value: receipt,
              onChanged: (value) {
                setState(() => receipt = value);
                TillPrinters.saveReceipt(value);
              },
            ),
            if (kitchenOn && kitchen != null) ...[
              const SizedBox(height: 12),
              OutlineAction(
                label: context.l10n.printersTestKitchen,
                icon: Icons.print_outlined,
                onPressed: testing ? null : _test,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// A printer that was picked but is not connected now still shows, marked as missing.
  Widget _picker({required String label, required String none, required String? value, required ValueChanged<String?> onChanged}) {
    final missing = value != null && !printers.any((printer) => printer.url == value);
    return LabeledField(
      label: label,
      child: DropdownButtonFormField<String?>(
        // A new key when the list reloads, so the field shows the saved choice again.
        key: ValueKey('$label|$value|${printers.length}'),
        initialValue: value,
        isExpanded: true,
        items: [
          DropdownMenuItem(value: null, child: Text(none)),
          for (final printer in printers) DropdownMenuItem(value: printer.url, child: Text(printer.name, overflow: TextOverflow.ellipsis)),
          if (missing) DropdownMenuItem(value: value, child: Text(context.l10n.printersMissing(value), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
