import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../features/app_feature.dart';
import '../models/models.dart';
import '../printing/cash_drawer.dart';
import '../printing/kitchen_ticket.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/tawla_ui.dart';

/// One card for printing. On top, this till's printers from the ones Windows finds (the kitchen
/// printer for kitchen tickets, the cashier printer for receipts), saved on this device only.
/// Below, when the kitchen feature is on, the cafe's kitchens (pizza oven, grill, bar): each one
/// makes the categories ticked for it and prints on the printer picked for it on this till.
/// Dishes of unticked categories go to the first kitchen. Between them, the cafe-wide auto-print
/// switch, the same on every till. The card always shows, also on the web.
class PrintersKitchensCard extends StatefulWidget {
  const PrintersKitchensCard({super.key});

  @override
  State<PrintersKitchensCard> createState() => _PrintersKitchensCardState();
}

class _PrintersKitchensCardState extends State<PrintersKitchensCard> {
  bool loading = true;
  bool supported = false;
  bool testing = false;
  bool drawer = false;
  List<Printer> printers = const [];
  String? kitchen;
  String? receipt;

  /// The printer picked for each kitchen on this till, by kitchen id.
  Map<String, String> picked = const {};

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
    final perKitchen = await TillPrinters.kitchenPrinters();
    final drawerOn = await CashDrawer.enabled();
    if (!mounted) return;
    setState(() {
      loading = false;
      supported = ok;
      printers = found;
      kitchen = saved.kitchen;
      receipt = saved.receipt;
      picked = perKitchen;
      drawer = drawerOn;
    });
  }

  Future<void> _openDrawer() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final opened = await CashDrawer.open();
    messenger.showSnackBar(SnackBar(content: Text(opened ? l10n.cashDrawerTestSent : l10n.cashDrawerFailed)));
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

  String _printerName(String? url) {
    if (url == null) return context.l10n.kitchensPrinterMain;
    return printers.where((printer) => printer.url == url).firstOrNull?.name ?? context.l10n.printersMissing(url);
  }

  Future<void> _editKitchen(CafeStore store, [Kitchen? item]) async {
    final saved = await showDialog<_KitchenDraft>(
      context: context,
      builder: (context) => _KitchenDialog(
        store: store,
        kitchen: item,
        printers: supported ? printers : null,
        printer: item == null ? null : picked[item.id],
      ),
    );
    if (saved == null || !mounted) return;
    final id = await store.saveKitchen(kitchenId: item?.id, name: saved.name, categoryIds: saved.categoryIds);
    if (supported) await TillPrinters.saveKitchenPrinter(id, saved.printer);
    await _load();
  }

  Future<void> _deleteKitchen(CafeStore store, Kitchen item) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.kitchensDeleteTitle(item.name),
      message: context.l10n.kitchensDeleteMessage,
    );
    if (!ok || !mounted) return;
    await store.deleteKitchen(item.id);
    await TillPrinters.saveKitchenPrinter(item.id, null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final kitchenOn = store.allows(AppFeature.kitchenPrinter);
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: PanelTitle(context.l10n.printersKitchensTitle, size: 18)),
              if (supported)
                IconButton(
                  tooltip: context.l10n.printersRefresh,
                  onPressed: loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 10),
          EyebrowLabel(context.l10n.settingsScopeThisTill),
          const SizedBox(height: 4),
          ..._tillPrinters(store, kitchenOn),
          const SizedBox(height: 18),
          const Divider(height: 1, color: TawlaTokens.border),
          const SizedBox(height: 14),
          EyebrowLabel(context.l10n.settingsScopeWholeCafe),
          SwitchRow(
            title: context.l10n.adminAutoPrintReceipt,
            hint: context.l10n.adminAutoPrintReceiptHint,
            value: store.autoPrintReceipt,
            onChanged: (value) => store.setAutoPrintReceipt(value),
            // The kitchens part below starts with its own line.
            divider: false,
          ),
          if (kitchenOn) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: TawlaTokens.border),
            const SizedBox(height: 14),
            ..._kitchens(store),
          ],
        ],
      ),
    );
  }

  List<Widget> _tillPrinters(CafeStore store, bool kitchenOn) {
    return [
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
            // With kitchens, this one prints for every kitchen that has no printer of its own.
            label: store.kitchens.isEmpty ? context.l10n.printersKitchen : context.l10n.kitchensPrinterMain,
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
        if (receipt != null && context.read<CafeStore>().allows(AppFeature.cashDrawer)) ...[
          const SizedBox(height: 4),
          SwitchRow(
            title: context.l10n.cashDrawerSwitch,
            hint: context.l10n.cashDrawerHint,
            value: drawer,
            onChanged: (value) {
              setState(() => drawer = value);
              CashDrawer.setEnabled(value);
            },
            divider: false,
          ),
          if (drawer)
            OutlineAction(label: context.l10n.cashDrawerTest, icon: Icons.point_of_sale_outlined, onPressed: _openDrawer),
        ],
        if (kitchenOn && kitchen != null) ...[
          const SizedBox(height: 12),
          OutlineAction(
            label: context.l10n.printersTestKitchen,
            icon: Icons.print_outlined,
            onPressed: testing ? null : _test,
          ),
        ],
      ],
    ];
  }

  List<Widget> _kitchens(CafeStore store) {
    return [
      PanelTitle(context.l10n.kitchensTitle, size: 16),
      const SizedBox(height: 2),
      Text(context.l10n.kitchensHint, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
      const SizedBox(height: 6),
      for (final (index, item) in store.orderedKitchens.indexed)
        _KitchenRow(
          title: index == 0 ? context.l10n.kitchensFirst(item.name) : item.name,
          categories: [
            for (final category in store.orderedCategories)
              if (store.categoryIdsOf(item.id).contains(category.id)) category.label(store.locale),
          ],
          printer: supported ? _printerName(picked[item.id]) : null,
          onEdit: () => _editKitchen(store, item),
          onDelete: () => _deleteKitchen(store, item),
        ),
      const SizedBox(height: 14),
      OutlineAction(label: '+ ${context.l10n.kitchensAdd}', height: 44, onPressed: () => _editKitchen(store)),
    ];
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

class _KitchenRow extends StatelessWidget {
  const _KitchenRow({required this.title, required this.categories, required this.printer, required this.onEdit, required this.onDelete});

  final String title;
  final List<String> categories;
  final String? printer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.border))),
      child: Row(
        children: [
          const Icon(Icons.soup_kitchen_outlined, color: CafeColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  categories.isEmpty ? context.l10n.kitchensNoCategories : categories.join(', '),
                  style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
                ),
                if (printer != null)
                  Text(context.l10n.kitchensPrintsOn(printer!), style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
              ],
            ),
          ),
          IconAction(icon: Icons.edit_outlined, tooltip: context.l10n.commonEdit, onPressed: onEdit),
          const SizedBox(width: 8),
          IconAction(icon: Icons.delete_outline, tooltip: context.l10n.commonDelete, danger: true, onPressed: onDelete),
        ],
      ),
    );
  }
}

/// What the kitchen dialog saves.
typedef _KitchenDraft = ({String name, Set<String> categoryIds, String? printer});

/// Name, ticked categories and (on a Windows till) printer of a new or existing kitchen.
class _KitchenDialog extends StatefulWidget {
  const _KitchenDialog({required this.store, required this.kitchen, required this.printers, required this.printer});

  final CafeStore store;
  final Kitchen? kitchen;

  /// This till's printers; null where printers can't be picked (not on Windows).
  final List<Printer>? printers;
  final String? printer;

  @override
  State<_KitchenDialog> createState() => _KitchenDialogState();
}

class _KitchenDialogState extends State<_KitchenDialog> {
  late final name = TextEditingController(text: widget.kitchen?.name ?? '');
  late Set<String> ticked = widget.kitchen == null ? {} : widget.store.categoryIdsOf(widget.kitchen!.id);
  late String? printer = widget.printer;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  /// The other kitchen a category is in now, so the admin sees it will move.
  String? _elsewhere(MenuCategory category) {
    final id = category.kitchenId;
    if (id == null || id == widget.kitchen?.id) return null;
    return widget.store.kitchens.where((item) => item.id == id).firstOrNull?.name;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final printers = widget.printers;
    final missing = printer != null && printers != null && !printers.any((item) => item.url == printer);
    final valid = name.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.kitchen == null ? context.l10n.kitchensAddTitle : context.l10n.kitchensEditTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                maxLength: 60,
                decoration: InputDecoration(labelText: context.l10n.kitchensName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(context.l10n.kitchensCategories, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              for (final category in store.orderedCategories)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: ticked.contains(category.id),
                  title: Text(category.label(store.locale)),
                  subtitle: switch (_elsewhere(category)) {
                    final other? => Text(context.l10n.kitchensNowIn(other)),
                    null => null,
                  },
                  onChanged: (value) => setState(() {
                    ticked = value == true ? {...ticked, category.id} : ({...ticked}..remove(category.id));
                  }),
                ),
              if (printers != null) ...[
                const SizedBox(height: 12),
                LabeledField(
                  label: context.l10n.kitchensPrinter,
                  child: DropdownButtonFormField<String?>(
                    initialValue: printer,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text(context.l10n.kitchensPrinterMain)),
                      for (final item in printers) DropdownMenuItem(value: item.url, child: Text(item.name, overflow: TextOverflow.ellipsis)),
                      if (missing) DropdownMenuItem(value: printer, child: Text(context.l10n.printersMissing(printer!), overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) => setState(() => printer = value),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, (name: name.text.trim(), categoryIds: ticked, printer: printer)) : null,
          child: Text(context.l10n.kitchensSave),
        ),
      ],
    );
  }
}
