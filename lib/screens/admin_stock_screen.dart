import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/tawla_ui.dart';

/// Most a dish's stock may be set to; the database refuses more.
const _maxStock = 100000;

/// Dishes sold from a counted stock: "No limit" is on by default; turned off, the admin types how
/// many are left. Each sale lowers the number and at 0 the dish is sold out.
class AdminStockScreen extends StatefulWidget {
  const AdminStockScreen({super.key});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  final search = TextEditingController();
  String? categoryId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final query = search.text.trim().toLowerCase();
    final categories = store.orderedCategories.where((category) => categoryId == null || category.id == categoryId);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.stockHelp, style: const TextStyle(color: TawlaTokens.muted, fontSize: 14)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final field = PageSearchField(controller: search, hint: context.l10n.dishSearchHint, onChanged: (_) => setState(() {}));
              final select = SelectBox<String?>(
                value: categoryId,
                minWidth: 190,
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.dishAllCategories)),
                  ...store.orderedCategories.map(
                    (category) => DropdownMenuItem(value: category.id, child: Text(category.label(store.locale))),
                  ),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [field, const SizedBox(height: 12), select],
                );
              }
              return Row(children: [Expanded(child: field), const SizedBox(width: 12), select]);
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                for (final category in categories) _category(context, store, category, query),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _category(BuildContext context, CafeStore store, MenuCategory category, String query) {
    final dishes = store.dishesIn(category.id).where((dish) {
      final name = '${dish.nameEn} ${dish.nameIt}'.toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();
    if (dishes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TawlaPanel(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.hairline))),
              child: PanelTitle(category.label(store.locale)),
            ),
            for (final dish in dishes) _StockRow(key: ValueKey(dish.id), dish: dish),
          ],
        ),
      ),
    );
  }
}

class _StockRow extends StatefulWidget {
  const _StockRow({super.key, required this.dish});

  final MenuItem dish;

  @override
  State<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<_StockRow> {
  late final TextEditingController qty = TextEditingController(text: widget.dish.stockQty?.toString() ?? '');

  /// The switch is off but no number was saved yet: the box shows without changing the dish.
  bool counting = false;
  bool saving = false;

  /// The admin changed the number but has not saved it, so live updates leave the box alone.
  bool _typing = false;

  bool get limited => widget.dish.hasStockLimit || counting;

  @override
  void didUpdateWidget(covariant _StockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A sale lowered the stock on another till: show the new number unless the admin is typing.
    final left = widget.dish.stockQty;
    if (left != null && !saving && qty.text != '$left' && !_typing) qty.text = '$left';
  }

  @override
  void dispose() {
    qty.dispose();
    super.dispose();
  }

  Future<void> _setNoLimit(CafeStore store, bool noLimit) async {
    if (!noLimit) {
      setState(() => counting = true);
      return;
    }
    setState(() => counting = false);
    if (!widget.dish.hasStockLimit) return;
    await _save(store, null);
  }

  Future<void> _saveTyped(CafeStore store) async {
    final value = int.tryParse(qty.text.trim());
    if (value == null || value < 0 || value > _maxStock) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.stockInvalid)));
      return;
    }
    await _save(store, value);
  }

  Future<void> _save(CafeStore store, int? value) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final name = widget.dish.displayName(store.locale);
    setState(() => saving = true);
    final error = await store.setDishStock(widget.dish, value);
    if (!mounted) return;
    setState(() {
      saving = false;
      _typing = false;
      if (error == null) counting = false;
      if (value == null && error == null) qty.clear();
    });
    messenger.showSnackBar(SnackBar(content: Text(error == null ? l10n.stockSaved(name) : l10n.errorText(error))));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final dish = widget.dish;
    final left = dish.stockQty;
    final (label, tone) = switch (left) {
      null => (context.l10n.stockNoLimit, BadgeTone.neutral),
      0 => (context.l10n.stockSoldOut, BadgeTone.terracotta),
      _ => (context.l10n.stockLeft(left), BadgeTone.success),
    };
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dish.displayName(store.locale), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CafeColors.ink)),
        const SizedBox(height: 2),
        Text(store.currency.format(dish.price), style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
      ],
    );
    final noLimit = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.stockNoLimit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 8),
        Switch(value: !limited, onChanged: saving ? null : (value) => _setNoLimit(store, value)),
      ],
    );
    final box = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          child: TextField(
            controller: qty,
            enabled: !saving,
            autofocus: counting && !dish.hasStockLimit,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onChanged: (_) => _typing = true,
            onSubmitted: (_) => _saveTyped(store),
            decoration: InputDecoration(hintText: context.l10n.stockQtyHint, isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: saving ? null : () => _saveTyped(store),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(context.l10n.stockSave),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.rowLine))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 14,
        runSpacing: 10,
        children: [
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 180), child: name),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(label, tone: tone),
              const SizedBox(width: 14),
              noLimit,
            ],
          ),
          if (limited) box,
        ],
      ),
    );
  }
}
