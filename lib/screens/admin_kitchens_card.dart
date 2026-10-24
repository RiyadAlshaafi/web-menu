import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../printing/kitchen_ticket.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/tawla_ui.dart';

/// The cafe's kitchens (pizza oven, grill, bar): each one makes the categories ticked for it and
/// prints on the printer picked for it on this till. Dishes of unticked categories go to the
/// first kitchen.
class KitchensCard extends StatefulWidget {
  const KitchensCard({super.key});

  @override
  State<KitchensCard> createState() => _KitchensCardState();
}

class _KitchensCardState extends State<KitchensCard> {
  bool printing = false;
  List<Printer> printers = const [];
  Map<String, String> picked = const {};

  @override
  void initState() {
    super.initState();
    _loadPrinters();
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
    final saved = await TillPrinters.kitchenPrinters();
    if (!mounted) return;
    setState(() {
      printing = ok;
      printers = found;
      picked = saved;
    });
  }

  String _printerName(String? url) {
    if (url == null) return context.l10n.kitchensPrinterMain;
    return printers.where((printer) => printer.url == url).firstOrNull?.name ?? context.l10n.printersMissing(url);
  }

  Future<void> _edit(CafeStore store, [Kitchen? kitchen]) async {
    final saved = await showDialog<_KitchenDraft>(
      context: context,
      builder: (context) => _KitchenDialog(
        store: store,
        kitchen: kitchen,
        printers: printing ? printers : null,
        printer: kitchen == null ? null : picked[kitchen.id],
      ),
    );
    if (saved == null || !mounted) return;
    final id = await store.saveKitchen(kitchenId: kitchen?.id, name: saved.name, categoryIds: saved.categoryIds);
    if (printing) await TillPrinters.saveKitchenPrinter(id, saved.printer);
    await _loadPrinters();
  }

  Future<void> _delete(CafeStore store, Kitchen kitchen) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.kitchensDeleteTitle(kitchen.name),
      message: context.l10n.kitchensDeleteMessage,
    );
    if (!ok || !mounted) return;
    await store.deleteKitchen(kitchen.id);
    await TillPrinters.saveKitchenPrinter(kitchen.id, null);
    await _loadPrinters();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final kitchens = store.orderedKitchens;
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.kitchensTitle, size: 18),
          const SizedBox(height: 2),
          Text(context.l10n.kitchensHint, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
          const SizedBox(height: 6),
          for (final (index, kitchen) in kitchens.indexed)
            _KitchenRow(
              title: index == 0 ? context.l10n.kitchensFirst(kitchen.name) : kitchen.name,
              categories: [
                for (final category in store.orderedCategories)
                  if (store.categoryIdsOf(kitchen.id).contains(category.id)) category.label(store.locale),
              ],
              printer: printing ? _printerName(picked[kitchen.id]) : null,
              onEdit: () => _edit(store, kitchen),
              onDelete: () => _delete(store, kitchen),
            ),
          const SizedBox(height: 14),
          OutlineAction(label: '+ ${context.l10n.kitchensAdd}', height: 44, onPressed: () => _edit(store)),
        ],
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
