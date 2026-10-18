import 'package:flutter/material.dart';

import '../core/choice_labels.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../theme/cafe_theme.dart';
import 'tawla_ui.dart';

/// Lets the cashier tick a dish's ingredients and extras. Returns the option ids
/// that are on, or null when closed without applying.
Future<Set<String>?> showDishChoicesSheet(
  BuildContext context, {
  required MenuItem item,
  required Set<String> onIds,
  required String locale,
  required String Function(double amount) money,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _DishChoicesSheet(item: item, initial: onIds, locale: locale, money: money),
  );
}

class _DishChoicesSheet extends StatefulWidget {
  const _DishChoicesSheet({required this.item, required this.initial, required this.locale, required this.money});

  final MenuItem item;
  final Set<String> initial;
  final String locale;
  final String Function(double amount) money;

  @override
  State<_DishChoicesSheet> createState() => _DishChoicesSheetState();
}

class _DishChoicesSheetState extends State<_DishChoicesSheet> {
  late Set<String> on = {...widget.initial};

  void _toggle(String id, bool value) => setState(() => on = value ? {...on, id} : {...on}..remove(id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final ingredients = item.options.where((option) => !option.isTopping).toList();
    final extras = item.options.where((option) => option.isTopping).toList();
    final line = item.lineWith(locale: widget.locale, onIds: on);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 4),
              child: Row(
                children: [
                  Expanded(child: PanelTitle(item.displayName(widget.locale), size: 20)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  if (ingredients.isNotEmpty) _section(l10n.dishChoicesIngredients, ingredients),
                  if (extras.isNotEmpty) _section(l10n.dishChoicesExtras, extras),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (line.choices.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        choicesText(line.choices, widget.locale, without: l10n.dishChoiceWithout),
                        style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13),
                      ),
                    ),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, on),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(
                        '${l10n.dishChoicesApply} · ${widget.money(line.unitPrice)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<DishOption> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
          child: EyebrowLabel(title),
        ),
        for (final option in options)
          CheckboxListTile(
            value: on.contains(option.id),
            onChanged: (value) => _toggle(option.id, value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(option.displayName(widget.locale), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            secondary: option.chargedPrice > 0
                ? Text('+ ${widget.money(option.chargedPrice)}', style: const TextStyle(color: CafeColors.inkMuted))
                : null,
          ),
      ],
    );
  }
}
