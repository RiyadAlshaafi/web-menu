import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../theme/cafe_theme.dart';
import 'tawla_ui.dart';

/// Admin list of a dish's ingredients and extra toppings.
///
/// An ingredient can be in the dish by default or not; an extra never is. The
/// price only counts when a guest turns on something that is off by default, so
/// the price field is hidden for default ingredients. Rows without any name are
/// left out of [onChanged].
class DishChoicesEditor extends StatefulWidget {
  const DishChoicesEditor({super.key, required this.initial, required this.onChanged});

  final List<DishOption> initial;
  final ValueChanged<List<DishOption>> onChanged;

  @override
  State<DishChoicesEditor> createState() => _DishChoicesEditorState();
}

class _DishChoicesEditorState extends State<DishChoicesEditor> {
  late List<_OptionRow> rows = [for (final option in widget.initial) _OptionRow(option)];

  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(List.unmodifiable([
      for (final row in rows)
        if (row.nameAr.text.trim().isNotEmpty || row.nameEn.text.trim().isNotEmpty) row.toOption(),
    ]));
  }

  void _update(VoidCallback change) {
    setState(change);
    _emit();
  }

  void _add() => _update(
    () => rows = [
      ...rows,
      _OptionRow(DishOption(id: DishOption.newId(), kind: DishOption.ingredient, nameAr: '', nameEn: '', defaultOn: true)),
    ],
  );

  void _remove(_OptionRow row) {
    _update(() => rows = [for (final other in rows) if (other != row) other]);
    row.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dishChoicesTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(l10n.dishChoicesHint, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 8),
        for (final row in rows) ...[
          _OptionCard(row: row, onChanged: _update, onRemove: () => _remove(row)),
          const SizedBox(height: 8),
        ],
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.dishChoicesAdd, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _OptionRow {
  _OptionRow(DishOption option)
    : id = option.id,
      kind = option.kind,
      defaultOn = option.isTopping ? false : option.defaultOn,
      nameAr = TextEditingController(text: option.nameAr),
      nameEn = TextEditingController(text: option.nameEn),
      price = TextEditingController(text: option.price == 0 ? '' : option.price.toString());

  final String id;
  String kind;
  bool defaultOn;
  final TextEditingController nameAr;
  final TextEditingController nameEn;
  final TextEditingController price;

  bool get priced => !defaultOn;

  DishOption toOption() => DishOption(
    id: id,
    kind: kind,
    nameAr: nameAr.text.trim(),
    nameEn: nameEn.text.trim(),
    price: priced ? (double.tryParse(price.text.trim()) ?? 0).clamp(0, 100000).toDouble() : 0,
    defaultOn: defaultOn,
  );

  void dispose() {
    nameAr.dispose();
    nameEn.dispose();
    price.dispose();
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.row, required this.onChanged, required this.onRemove});

  final _OptionRow row;
  final void Function(VoidCallback change) onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const fill = Color(0xFFFBF6F0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CafeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedPills<String>(
                    height: 36,
                    options: [
                      (DishOption.ingredient, l10n.dishChoiceIngredient),
                      (DishOption.topping, l10n.dishChoiceTopping),
                    ],
                    selected: row.kind,
                    onSelected: (kind) => onChanged(() {
                      row.kind = kind;
                      if (kind == DishOption.topping) row.defaultOn = false;
                    }),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.dishChoiceRemove,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: CafeColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.nameAr,
                  onChanged: (_) => onChanged(() {}),
                  decoration: InputDecoration(hintText: l10n.dishChoiceNameAr, isDense: true, fillColor: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: row.nameEn,
                  onChanged: (_) => onChanged(() {}),
                  decoration: InputDecoration(hintText: l10n.dishChoiceNameEn, isDense: true, fillColor: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          if (row.kind == DishOption.ingredient)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.dishChoiceInByDefault, style: const TextStyle(fontWeight: FontWeight.w600)),
              value: row.defaultOn,
              onChanged: (value) => onChanged(() => row.defaultOn = value),
            ),
          if (row.priced) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: TextField(
                controller: row.price,
                onChanged: (_) => onChanged(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.dishChoicePrice,
                  hintText: '0.500',
                  isDense: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
