import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/cafe_widgets.dart';

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
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.navDishAvailability, style: CafeTheme.display.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(hintText: context.l10n.dishSearchHint, prefixIcon: const Icon(Icons.search)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              DropdownButton<String?>(
                value: categoryId,
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.dishAllCategories)),
                  ...store.orderedCategories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.nameEn))),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              ),
              _statusChip(context.l10n.dishFilterAll, status == _DishStatus.all, () => setState(() => status = _DishStatus.all)),
              _statusChip(context.l10n.dishFilterActive, status == _DishStatus.active, () => setState(() => status = _DishStatus.active)),
              _statusChip(context.l10n.dishFilterInactive, status == _DishStatus.inactive, () => setState(() => status = _DishStatus.inactive)),
            ],
          ),
          const SizedBox(height: 12),
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

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    final button = CafeSurfaces.of(context).button;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? button : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? button : CafeColors.line),
        ),
        child: Text(label, style: TextStyle(color: selected ? CafeSurfaces.of(context).onButton : CafeColors.ink, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _category(BuildContext context, CafeStore store, MenuCategory category, String query) {
    final dishes = store.dishesIn(category.id).where((dish) {
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(category.nameEn, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
              TextButton(onPressed: () => _bulk(context, store, category, true), child: Text(context.l10n.dishActivateAll)),
              TextButton(onPressed: () => _bulk(context, store, category, false), child: Text(context.l10n.dishDeactivateAll)),
            ],
          ),
          const SizedBox(height: 8),
          for (final dish in dishes) _dish(context, store, dish),
        ],
      ),
    );
  }

  Widget _dish(BuildContext context, CafeStore store, MenuItem dish) {
    final inactive = !dish.available;
    return Opacity(
      opacity: inactive ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SoftCard(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              DishPhoto(path: dish.imageUrl, size: 48, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.nameEn.isEmpty ? dish.nameIt : dish.nameEn,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: inactive ? CafeColors.inkMuted : CafeColors.ink,
                        decoration: inactive ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(store.currency.format(dish.price), style: const TextStyle(color: CafeColors.inkMuted)),
                    if (inactive)
                      Text(context.l10n.dishInactive, style: TextStyle(color: CafeSurfaces.of(context).button, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: dish.available,
                onChanged: (value) => store.setItemAvailable(dish.id, value),
              ),
            ],
          ),
        ),
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
