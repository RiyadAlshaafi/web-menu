import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/tawla_ui.dart';

enum _DishStatus { all, active, inactive }

class DishAvailabilityScreen extends StatefulWidget {
  const DishAvailabilityScreen({super.key});

  @override
  State<DishAvailabilityScreen> createState() => _DishAvailabilityScreenState();
}

class _DishAvailabilityScreenState extends State<DishAvailabilityScreen> {
  final search = TextEditingController();
  String? categoryId;
  _DishStatus status = _DishStatus.all;

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
          LayoutBuilder(
            builder: (context, constraints) {
              final search = PageSearchField(controller: this.search, hint: context.l10n.dishSearchHint, onChanged: (_) => setState(() {}));
              final pills = SegmentedPills<_DishStatus>(
                options: [
                  (_DishStatus.all, context.l10n.dishFilterAll),
                  (_DishStatus.active, context.l10n.dishFilterActive),
                  (_DishStatus.inactive, context.l10n.dishFilterInactive),
                ],
                selected: status,
                onSelected: (value) => setState(() => status = value),
              );
              final select = SelectBox<String?>(
                value: categoryId,
                minWidth: 190,
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.dishAllCategories)),
                  ...store.orderedCategories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.nameEn))),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 12), Wrap(spacing: 12, runSpacing: 12, children: [pills, select])],
                );
              }
              return Row(children: [Expanded(child: search), const SizedBox(width: 12), pills, const SizedBox(width: 12), select]);
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                for (final category in categories)
                  _category(context, store, category, query),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _category(BuildContext context, CafeStore store, MenuCategory category, String query) {
    final all = store.dishesIn(category.id).toList();
    final dishes = all.where((dish) {
      final name = '${dish.nameEn} ${dish.nameIt}'.toLowerCase();
      if (query.isNotEmpty && !name.contains(query)) return false;
      return switch (status) {
        _DishStatus.all => true,
        _DishStatus.active => dish.available,
        _DishStatus.inactive => !dish.available,
      };
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
              child: Row(
                children: [
                  Flexible(child: PanelTitle(category.nameEn)),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.dishActiveCount(all.where((dish) => dish.available).length, all.length),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TawlaTokens.muted),
                  ),
                  const Spacer(),
                  OutlineAction(label: context.l10n.dishActivateAll, onPressed: () => _bulk(context, store, category, true)),
                  const SizedBox(width: 10),
                  OutlineAction(label: context.l10n.dishDeactivateAll, danger: true, onPressed: () => _bulk(context, store, category, false)),
                ],
              ),
            ),
            for (final dish in dishes) _dish(context, store, dish),
          ],
        ),
      ),
    );
  }

  Widget _dish(BuildContext context, CafeStore store, MenuItem dish) {
    final inactive = !dish.available;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.rowLine))),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: inactive ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.nameEn.isEmpty ? dish.nameIt : dish.nameEn, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CafeColors.ink)),
                  const SizedBox(height: 2),
                  Text(store.currency.format(dish.price), style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
          StatusBadge(inactive ? context.l10n.dishInactive : context.l10n.dishFilterActive, tone: inactive ? BadgeTone.neutral : BadgeTone.success),
          const SizedBox(width: 14),
          Switch(
            value: dish.available,
            onChanged: (value) => store.setItemAvailable(dish.id, value),
          ),
        ],
      ),
    );
  }

  Future<void> _bulk(BuildContext context, CafeStore store, MenuCategory category, bool available) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.dishBulkTitle,
      message: context.l10n.dishBulkMessage(category.nameEn),
      confirm: available ? context.l10n.dishActivateAll : context.l10n.dishDeactivateAll,
    );
    if (!ok) return;
    await store.setItemsAvailable(store.dishesIn(category.id).map((dish) => dish.id), available);
  }
}
