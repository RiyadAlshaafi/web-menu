import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../navigation/app_sections.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/cafe_widgets.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  bool creating = false;
  final categoryName = TextEditingController();
  String? inspectingId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    categoryName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final categories = store.orderedCategories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.layoutTitle, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width, min: 22, max: 36), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await store.persistLayout();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.layoutSavedSnack)),
                  );
                },
                icon: const Icon(Icons.save_outlined, size: 16),
                label: Text(context.l10n.layoutSaveMenu, style: const TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: CafeColors.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.l10n.layoutSequencingHeading,
                style: const TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: CafeColors.inkMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE6DC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(context.l10n.layoutReorderHint, style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => creating = !creating),
                icon: const Icon(Icons.add, size: 16, color: CafeColors.terracotta),
                label: Text(creating ? context.l10n.layoutClose : context.l10n.layoutNewCategory, style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                if (creating) _newCategoryForm(store),
                if (creating) const SizedBox(height: 12),
                if (categories.isNotEmpty)
                  Column(
                    children: [
                      for (var i = 0; i < categories.length; i++)
                        Padding(
                          key: ValueKey(categories[i].id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CategoryCard(
                            index: store.orderedCategories.indexOf(categories[i]),
                            category: categories[i],
                            inspecting: inspectingId == categories[i].id,
                            onInspect: () => setState(() {
                              inspectingId = inspectingId == categories[i].id ? null : categories[i].id;
                            }),
                            onAddDish: () => showAddDishDialog(context, store, categoryId: categories[i].id),
                            onMoveUp: i > 0 ? () => store.reorderCategories(i, i - 1) : null,
                            onMoveDown: i < categories.length - 1 ? () => store.reorderCategories(i, i + 1) : null,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _newCategoryForm(CafeStore store) {
    return DashedBorder(
      color: CafeColors.terracotta.withValues(alpha: 0.55),
      radius: 18,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CafeColors.peach,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.create_new_folder_outlined, color: CafeColors.terracotta, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: categoryName,
                decoration: InputDecoration(
                  hintText: context.l10n.layoutCategoryNameHint,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () async {
                if (categoryName.text.trim().isEmpty) return;
                final name = categoryName.text.trim();
                final spotlight = name.toLowerCase().contains('special');
                await store.addCategory(name, name, spotlight: spotlight);
                categoryName.clear();
                setState(() {
                  creating = store.categories.isEmpty;
                  inspectingId = store.categories.isEmpty ? null : store.orderedCategories.last.id;
                });
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text(context.l10n.layoutCreateCategory, style: const TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: CafeColors.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                creating = store.categories.isEmpty;
                categoryName.clear();
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: CafeColors.ink,
                side: const BorderSide(color: CafeColors.line),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(context.l10n.commonCancel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.index,
    required this.category,
    required this.inspecting,
    required this.onInspect,
    required this.onAddDish,
    this.onMoveUp,
    this.onMoveDown,
  });

  final int index;
  final MenuCategory category;
  final bool inspecting;
  final VoidCallback onInspect;
  final VoidCallback onAddDish;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  late final TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.category.nameEn);
  }

  @override
  void didUpdateWidget(covariant _CategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category.nameEn != widget.category.nameEn && nameController.text != widget.category.nameEn) {
      nameController.text = widget.category.nameEn;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<CafeStore>();
    final category = widget.category;
    final inspecting = widget.inspecting;
    final dishes = store.dishesIn(category.id);
    final preview = inspecting ? dishes : dishes.take(2).toList();

    return Material(
      color: inspecting ? const Color(0xFFFFF6F1) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: inspecting ? const Color(0xFFFFF6F1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: inspecting ? CafeColors.terracotta : const Color(0xFFE6E2DC),
            width: inspecting ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onMoveUp,
                        icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFFC4B8AE), size: 18),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onMoveDown,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC4B8AE), size: 18),
                      ),
                    ],
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: inspecting ? CafeColors.terracotta : CafeColors.peach,
                      borderRadius: BorderRadius.circular(inspecting ? 8 : 14),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                        color: inspecting ? Colors.white : CafeColors.terracottaDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (inspecting)
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CafeColors.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isEmpty) return;
                                  store.saveCategory(
                                    category
                                      ..nameEn = value.trim()
                                      ..nameAr = value.trim(),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (nameController.text.trim().isEmpty) return;
                                store.saveCategory(
                                  category
                                    ..nameEn = nameController.text.trim()
                                    ..nameAr = nameController.text.trim(),
                                );
                              },
                              icon: const Icon(Icons.check, size: 16, color: CafeColors.success),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: InkWell(
                        onTap: widget.onInspect,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                category.nameEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: widget.onInspect,
                              icon: const Icon(Icons.edit_outlined, size: 16, color: CafeColors.inkMuted),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (category.spotlight)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CafeColors.terracotta,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(context.l10n.layoutSpotlight, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                              ),
                            Text(
                              dishes.isEmpty
                                  ? ''
                                  : category.spotlight
                                      ? '• ${dishes.length == 1 ? context.l10n.layoutOneDish : context.l10n.layoutDishCount('${dishes.length}')}'
                                      : '• ${context.l10n.layoutItemCount('${dishes.length}')}',
                              style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (inspecting) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6E6DE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('● ${context.l10n.layoutCurrentlyInspecting}', style: const TextStyle(color: CafeColors.terracottaDark, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onAddDish,
                    icon: const Icon(Icons.add, size: 14),
                    label: Text(context.l10n.layoutAddDish, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: inspecting ? CafeColors.terracotta : const Color(0xFFF8EFEA),
                      foregroundColor: inspecting ? Colors.white : CafeColors.terracotta,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: category.visible,
                    activeTrackColor: CafeColors.terracotta,
                    onChanged: (value) => store.saveCategory(category..visible = value),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteCategory(context, store, category),
                    icon: const Icon(Icons.delete_outline, color: CafeColors.inkMuted),
                  ),
                ],
              ),
              if (inspecting) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      context.l10n.layoutDishesInCategory(
                        category.nameEn.toUpperCase(),
                        '${dishes.where((item) => item.available).length}',
                      ),
                      style: const TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: CafeColors.terracotta),
                    ),
                    const Spacer(),
                    Text(context.l10n.layoutReorderHint, style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
                  if (preview.isNotEmpty)
                    Column(
                      children: [
                        for (var i = 0; i < preview.length; i++)
                          Padding(
                            key: ValueKey(preview[i].id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DishRow(
                              dish: preview[i],
                              rank: inspecting ? i + 1 : null,
                              inspecting: inspecting,
                              onMoveUp: inspecting && i > 0
                                  ? () => store.reorderDishes(category.id, i, i - 1)
                                  : null,
                              onMoveDown: inspecting && i < preview.length - 1
                                  ? () => store.reorderDishes(category.id, i, i + 1)
                                  : null,
                            ),
                          ),
                      ],
                    ),
              if (inspecting) ...[
                const SizedBox(height: 4),
                DashedBorder(
                  color: const Color(0xFFD8CCC2),
                  radius: 14,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      '↓ ${context.l10n.layoutDropDishHint(category.nameEn)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(BuildContext context, CafeStore store, MenuCategory category) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.layoutDeleteCategoryTitle,
      message: context.l10n.layoutDeleteCategoryMessage,
      confirm: context.l10n.layoutDeleteCategoryConfirm,
    );
    if (ok) await store.deleteCategory(category.id);
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    this.rank,
    required this.inspecting,
    this.onMoveUp,
    this.onMoveDown,
  });

  final MenuItem dish;
  final int? rank;
  final bool inspecting;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CafeStore>();
    final selected = inspecting && dish.featured;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF4EE) : const Color(0xFFFBF7F2),
        borderRadius: BorderRadius.circular(14),
        border: selected ? Border.all(color: CafeColors.terracotta.withValues(alpha: 0.55), width: 1.2) : null,
      ),
      child: Row(
        children: [
          if (inspecting) ...[
            Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18, color: Color(0xFFC4B8AE)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFFC4B8AE)),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          DishPhoto(path: dish.imageUrl, size: 40, radius: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  dish.nameIt.isEmpty ? dish.nameEn : dish.nameIt,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                if (dish.featured && !inspecting)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: CafeColors.terracotta, borderRadius: BorderRadius.circular(5)),
                    child: Text(context.l10n.layoutHeroCard, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                if (rank != null && inspecting)
                  Text('#$rank', style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 12)),
                Text(
                  store.currency.format(dish.price),
                  style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!inspecting && dish.available)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(context.l10n.layoutActive, style: const TextStyle(color: CafeColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          if (inspecting) ...[
            _heroToggle(context, false, !dish.featured, () => store.saveMenuItem(dish..featured = false)),
            const SizedBox(width: 4),
            _heroToggle(context, true, dish.featured, () => store.saveMenuItem(dish..featured = true)),
          ],
          IconButton(
            onPressed: () => showAddDishDialog(context, store, existing: dish, categoryId: dish.categoryId),
            icon: const Icon(Icons.edit_outlined, size: 16, color: CafeColors.inkMuted),
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, store),
            icon: const Icon(Icons.delete_outline, size: 16, color: CafeColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _heroToggle(BuildContext context, bool hero, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? (hero ? CafeColors.terracotta : Colors.white) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected && hero ? CafeColors.terracotta : CafeColors.line),
          ),
          child: Text(
            hero ? context.l10n.layoutHero : context.l10n.layoutList,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected && hero ? Colors.white : CafeColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CafeStore store) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.layoutDeleteDishTitle,
      message: context.l10n.layoutDeleteDishMessage(dish.displayName(store.locale)),
      confirm: context.l10n.commonDelete,
    );
    if (ok) await store.deleteMenuItem(dish.id);
  }
}

Future<void> showAddDishDialog(
  BuildContext context,
  CafeStore store, {
  MenuItem? existing,
  String? categoryId,
}) async {
  if (store.categories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.createCategoryFirst)),
    );
    return;
  }

  final name = TextEditingController(
    text: existing == null
        ? ''
        : existing.nameIt.isEmpty || existing.nameIt == existing.nameEn
            ? existing.nameEn
            : '${existing.nameIt} / ${existing.nameEn}',
  );
  final price = TextEditingController(text: existing == null ? '' : existing.price.toStringAsFixed(2));
  var image = existing?.imageUrl ?? '';
  var selectedCategory = categoryId ?? existing?.categoryId ?? store.orderedCategories.first.id;

  final saved = await showDialog<MenuItem>(
    context: context,
    barrierColor: const Color(0x99000000),
    useRootNavigator: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModal) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: CafeColors.peach,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.restaurant, color: CafeColors.terracotta),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.layoutAddNewDish, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.layoutAddDishSubtitle,
                                style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(context.l10n.layoutDishNameLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        hintText: context.l10n.layoutDishNameHint,
                        fillColor: const Color(0xFFFBF6F0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.layoutPriceLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        prefixText: '€  ',
                        hintText: '18.50',
                        fillColor: Color(0xFFFBF6F0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.layoutDishPictureLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                            allowMultiple: false,
                          );
                          final file = result?.files.isNotEmpty == true ? result!.files.single : null;
                          final bytes = file?.bytes;
                          if (bytes == null || bytes.isEmpty) return;
                          if (bytes.length > 10 * 1024 * 1024) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.l10n.layoutImageTooLarge)),
                              );
                            }
                            return;
                          }
                          final mime = (file!.extension ?? 'jpg').toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
                          setModal(() => image = 'data:$mime;base64,${base64Encode(bytes)}');
                        } catch (_) {
                          // Photo is optional — cancelling the picker must not block saving.
                        }
                      },
                      child: DashedBorder(
                        color: const Color(0xFFD8CCC2),
                        radius: 16,
                        child: Container(
                          width: double.infinity,
                          height: 148,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF6F0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: image.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.cloud_upload_outlined, color: CafeColors.terracotta, size: 28),
                                    const SizedBox(height: 8),
                                    Text(context.l10n.layoutUploadPrompt, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(context.l10n.layoutUploadHint, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
                                  ],
                                )
                              : DishPhoto(path: image, size: 96, radius: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CafeColors.ink,
                            side: const BorderSide(color: CafeColors.line),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(context.l10n.commonCancel, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            if (name.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.l10n.layoutEnterDishName)),
                              );
                              return;
                            }
                            final parts = name.text.split('/');
                            final italian = parts.first.trim();
                            final english = parts.length > 1 ? parts.sublist(1).join('/').trim() : italian;
                            final item = existing ??
                                MenuItem(
                                  id: Secrets.id('dish'),
                                  nameIt: italian,
                                  nameEn: english,
                                  price: double.tryParse(price.text) ?? 0,
                                  categoryId: selectedCategory,
                                );
                            item
                              ..nameIt = italian
                              ..nameEn = english.isEmpty ? italian : english
                              ..price = double.tryParse(price.text) ?? item.price
                              ..imageUrl = image
                              ..categoryId = selectedCategory;
                            Navigator.pop(context, item);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(existing == null ? context.l10n.layoutSaveAndAddDish : context.l10n.layoutSaveDish, style: const TextStyle(fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: CafeColors.terracotta,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  if (saved == null) {
    name.dispose();
    price.dispose();
    return;
  }
  final host = context;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    name.dispose();
    price.dispose();
    if (!host.mounted) return;
    try {
      await store.saveMenuItem(saved);
    } catch (error) {
      if (host.mounted) {
        ScaffoldMessenger.of(host).showSnackBar(
          SnackBar(content: Text(host.l10n.layoutSaveDishError('$error'))),
        );
      }
    }
  });
}

class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = CafeColors.line,
    this.radius = 16,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) => oldDelegate.color != color;
}
