import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../navigation/app_sections.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';
import 'admin_brand_settings.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  String query = '';
  String? categoryFilter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final width = MediaQuery.sizeOf(context).width;
    final dishes = store.menuItems.where((item) {
      final category = store.categories.where((entry) => entry.id == item.categoryId);
      final name = item.displayName(store.locale).toLowerCase();
      final catName = category.isEmpty ? '' : category.first.nameEn.toLowerCase();
      final matchesQuery = query.isEmpty || name.contains(query.toLowerCase()) || catName.contains(query.toLowerCase());
      final matchesCategory = categoryFilter == null || item.categoryId == categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.navDiscounts, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(width))),
              FilledButton.icon(
                onPressed: () => _showCreateDiscount(context, store),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.catalogNewDiscount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(context.l10n.catalogAllCategoriesCount('${store.categories.length}'), categoryFilter == null, () {
                setState(() => categoryFilter = null);
              }),
              for (final category in store.orderedCategories)
                _chip(category.nameEn, categoryFilter == category.id, () {
                  setState(() => categoryFilter = category.id);
                }),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260, minWidth: 160),
                child: TextField(
                  decoration: InputDecoration(hintText: context.l10n.catalogSearchDishesHint, prefixIcon: const Icon(Icons.search, size: 18), isDense: true),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: store.menuItems.isEmpty
                ? SoftCard(child: EmptyHint(context.l10n.catalogNoDishesHint))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppSections.columnsFor(constraints.maxWidth),
                          childAspectRatio: width < 720 ? 1.35 : 1.55,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: dishes.length,
                        itemBuilder: (context, index) => _DiscountDishCard(dish: dishes[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? CafeColors.terracotta : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : CafeColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDiscount(BuildContext context, CafeStore store) async {
    var categoryId = categoryFilter;
    var percent = 15.0;
    var activate = true;
    final percentController = TextEditingController(text: '15');
    final labelController = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: CafeColors.terracotta, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.percent, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(context.l10n.catalogApplyDiscountPromo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(context.l10n.catalogTargetCategory, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        key: ValueKey(categoryId),
                        initialValue: categoryId,
                        items: [
                          DropdownMenuItem(value: null, child: Text(context.l10n.catalogAllCategories)),
                          ...store.orderedCategories.map(
                            (category) => DropdownMenuItem(value: category.id, child: Text(category.nameEn)),
                          ),
                        ],
                        onChanged: (value) => setModal(() => categoryId = value),
                      ),
                      const SizedBox(height: 14),
                      Text(context.l10n.catalogDiscountRate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: percentController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => percent = double.tryParse(value) ?? percent,
                        decoration: const InputDecoration(suffixText: '%'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [10, 15, 20, 25].map((rate) {
                          final selected = percent.round() == rate;
                          return ChoiceChip(
                            label: Text('$rate%'),
                            selected: selected,
                            selectedColor: CafeColors.terracotta,
                            labelStyle: TextStyle(color: selected ? Colors.white : CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 12),
                            onSelected: (_) {
                              percent = rate.toDouble();
                              percentController.text = '$rate';
                              setModal(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(context.l10n.catalogPromoLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      TextField(controller: labelController, decoration: InputDecoration(hintText: context.l10n.catalogPromoLabelHint)),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: activate,
                        onChanged: (value) => setModal(() => activate = value),
                        title: Text(context.l10n.catalogActivateImmediately, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Text(context.l10n.catalogActivateImmediatelyDesc, style: const TextStyle(fontSize: 12)),
                        activeTrackColor: CafeColors.terracotta,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await store.applyCategoryDiscount(
                              categoryId: categoryId,
                              percent: double.tryParse(percentController.text) ?? percent,
                              activate: activate,
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(context.l10n.catalogApplyDiscount),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    percentController.dispose();
    labelController.dispose();
  }
}

class _DiscountDishCard extends StatefulWidget {
  const _DiscountDishCard({required this.dish});

  final MenuItem dish;

  @override
  State<_DiscountDishCard> createState() => _DiscountDishCardState();
}

class _DiscountDishCardState extends State<_DiscountDishCard> {
  late final TextEditingController percentController;

  @override
  void initState() {
    super.initState();
    percentController = TextEditingController(text: _percentText(widget.dish.discountPercent));
  }

  @override
  void didUpdateWidget(covariant _DiscountDishCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dish.discountPercent != widget.dish.discountPercent) {
      percentController.text = _percentText(widget.dish.discountPercent);
    }
  }

  String _percentText(double value) => value == 0 ? '' : value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  @override
  void dispose() {
    percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final dish = widget.dish;
    final category = store.categories.where((item) => item.id == dish.categoryId);
    return SoftCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DishPhoto(path: dish.imageUrl, size: 56, radius: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CafeColors.key,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CafeColors.line),
                        ),
                        child: Text(category.first.nameEn.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
                      ),
                    Text(dish.displayName(store.locale), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(store.currency.format(dish.salePrice), style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: dish.hasDiscount ? const Color(0xFFFDF1EB) : CafeColors.key,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dish.hasDiscount ? CafeColors.terracotta.withValues(alpha: 0.25) : CafeColors.line),
                ),
                child: Text(
                  dish.hasDiscount ? context.l10n.catalogPercentOff('${dish.discountPercent.round()}') : context.l10n.catalogNoPromo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: dish.hasDiscount ? CafeColors.terracotta : CafeColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 18),
          Row(
            children: [
              Text(context.l10n.catalogDiscount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CafeColors.inkMuted)),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: percentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, suffixText: '%', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  onEditingComplete: () {
                    final percent = double.tryParse(percentController.text) ?? 0;
                    store.setDishDiscount(dish, percent: percent, applied: dish.discountApplied);
                  },
                  onSubmitted: (value) {
                    final percent = double.tryParse(value) ?? 0;
                    store.setDishDiscount(dish, percent: percent, applied: dish.discountApplied);
                  },
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Checkbox(
                    value: dish.discountApplied,
                    activeColor: CafeColors.terracotta,
                    onChanged: (value) {
                      final percent = double.tryParse(percentController.text) ?? dish.discountPercent;
                      store.setDishDiscount(dish, percent: percent, applied: value ?? false);
                    },
                  ),
                  Text(context.l10n.catalogApply, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final cashierName = TextEditingController();
  final cashierPin = TextEditingController();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  bool applyToQr = true;

  @override
  void dispose() {
    cashierName.dispose();
    cashierPin.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        Text(context.l10n.navSettings, style: CafeTheme.display.copyWith(fontSize: 36)),
        const SizedBox(height: 18),
        const AdminBrandSettings(),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.catalogSystemLanguage, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              Text(context.l10n.catalogSystemLanguageDesc, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _lang(store, 'en', context.l10n.catalogEnglishUs, context.l10n.catalogLangDefault)),
                  const SizedBox(width: 12),
                  Expanded(child: _lang(store, 'ar', 'العربية', context.l10n.catalogLangRegional)),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: applyToQr,
                onChanged: (value) => setState(() => applyToQr = value),
                title: Text(context.l10n.catalogApplyLanguageToQr, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {},
                  child: Text(context.l10n.catalogSaveLanguage),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.catalogChangePassword, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: currentPassword, obscureText: true, decoration: InputDecoration(labelText: context.l10n.catalogCurrentPassword)),
              const SizedBox(height: 8),
              TextField(controller: newPassword, obscureText: true, decoration: InputDecoration(labelText: context.l10n.catalogNewPassword)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => context.mounted ? ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.catalogPasswordUpdated))) : null,
                  child: Text(context.l10n.catalogUpdatePassword),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.catalogCashierStaffAccess, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              if (store.cashiers.isEmpty) EmptyHint(context.l10n.noCashiers),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: store.cashiers
                    .map(
                      (member) => Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CafeColors.key,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CafeColors.line),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: CafeColors.peach,
                              child: Text(member.initials, style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                            IconButton(
                              onPressed: () => store.deleteCashier(member.id),
                              icon: const Icon(Icons.delete_outline, size: 18, color: CafeColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(controller: cashierName, decoration: InputDecoration(hintText: context.l10n.catalogCashierNameHint, labelText: context.l10n.catalogCashierName)),
              const SizedBox(height: 8),
              TextField(
                controller: cashierPin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.l10n.catalogCashierPinLabel),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    if (cashierName.text.trim().isEmpty || cashierPin.text.length != 4) return;
                    await store.addCashier(name: cashierName.text, pin: cashierPin.text);
                    cashierName.clear();
                    cashierPin.clear();
                  },
                  child: Text(context.l10n.catalogSaveCashier),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lang(CafeStore store, String code, String title, String badge) {
    final selected = store.locale == code;
    return InkWell(
      onTap: () => store.setLocale(code),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? CafeColors.terracotta : CafeColors.line, width: selected ? 2 : 1),
          color: CafeColors.key,
        ),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 8),
            Text(badge, style: const TextStyle(color: CafeColors.terracotta, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? CafeColors.terracotta : CafeColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
