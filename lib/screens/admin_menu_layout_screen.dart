import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../navigation/app_sections.dart';
import '../report_error.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/tawla_ui.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  final categoryName = TextEditingController();
  String? inspectingId;

  @override
  void dispose() {
    categoryName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final categories = store.orderedCategories;
    final inspecting = categories.where((item) => item.id == inspectingId).firstOrNull ?? categories.firstOrNull;

    final tree = TawlaPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EyebrowLabel(context.l10n.layoutSequencingHeading, color: CafeColors.ink),
          const SizedBox(height: 2),
          Text(context.l10n.layoutReorderHint, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
          const SizedBox(height: 12),
          for (var i = 0; i < categories.length; i++)
            Padding(
              key: ValueKey(categories[i].id),
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryRow(
                category: categories[i],
                selected: categories[i].id == inspecting?.id,
                onTap: () => setState(() => inspectingId = categories[i].id),
                onMoveUp: i > 0 ? () => store.reorderCategories(i, i - 1) : null,
                onMoveDown: i < categories.length - 1 ? () => store.reorderCategories(i, i + 1) : null,
              ),
            ),
          const Divider(height: 12, color: TawlaTokens.hairline),
          const SizedBox(height: 8),
          EyebrowLabel(context.l10n.layoutNewCategoryLabel, color: CafeColors.ink),
          const SizedBox(height: 8),
          TextField(
            controller: categoryName,
            decoration: InputDecoration(hintText: context.l10n.layoutCategoryNameHint),
            onSubmitted: (_) => _createCategory(store),
          ),
          const SizedBox(height: 8),
          OutlineAction(label: context.l10n.layoutCreateCategory, height: 44, expanded: true, onPressed: () => _createCategory(store)),
        ],
      ),
    );

    final inspector = inspecting == null
        ? TawlaPanel(child: EmptyHint(context.l10n.layoutNoCategorySelected))
        : _CategoryInspector(key: ValueKey(inspecting.id), category: inspecting);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.layoutTitle,
                style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width, min: 22, max: 26), fontWeight: FontWeight.w700),
              ),
            ),
            TerracottaButton(
              expanded: false,
              height: 48,
              label: context.l10n.layoutSaveMenu,
              onPressed: () async {
                await store.persistLayout();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.layoutSavedSnack)));
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 860) {
              return Column(children: [tree, const SizedBox(height: 18), inspector]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: (constraints.maxWidth * 0.35).clamp(300.0, 420.0), child: tree),
                const SizedBox(width: 18),
                Expanded(child: inspector),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _createCategory(CafeStore store) async {
    final name = categoryName.text.trim();
    if (name.isEmpty) return;
    final spotlight = name.toLowerCase().contains('special');
    await store.addCategory(name, name, spotlight: spotlight);
    categoryName.clear();
    if (!mounted) return;
    setState(() => inspectingId = store.orderedCategories.isEmpty ? null : store.orderedCategories.last.id);
  }
}

/// One category in the sequencing list: name, dish count and the move arrows.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.selected, required this.onTap, this.onMoveUp, this.onMoveDown});

  final MenuCategory category;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CafeStore>();
    final count = store.dishesIn(category.id).length;
    final button = CafeSurfaces.of(context).button;
    final buttonInk = CafeSurfaces.of(context).buttonInk;
    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) => Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: onPressed == null ? TawlaTokens.hairline : buttonInk)),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onPressed,
              child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 18, color: onPressed == null ? TawlaTokens.border : buttonInk)),
            ),
          ),
        );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFFFFF4EF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? button : TawlaTokens.border, width: selected ? 1.4 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(category.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CafeColors.ink)),
                          ),
                          if (category.spotlight) ...[
                            const SizedBox(width: 6),
                            StatusBadge(context.l10n.layoutSpotlight, tone: BadgeTone.terracotta),
                          ],
                          if (!category.visible) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.visibility_off_outlined, size: 16, color: TawlaTokens.muted),
                          ],
                        ],
                      ),
                      Text(
                        count == 1 ? context.l10n.layoutOneDish : context.l10n.layoutDishCount('$count'),
                        style: const TextStyle(fontSize: 12, color: TawlaTokens.muted),
                      ),
                    ],
                  ),
                ),
                arrow(Icons.keyboard_arrow_up, context.l10n.layoutMoveEarlier, onMoveUp),
                const SizedBox(width: 6),
                arrow(Icons.keyboard_arrow_down, context.l10n.layoutMoveLater, onMoveDown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-hand panel: the chosen category's settings and its dishes as cards.
class _CategoryInspector extends StatefulWidget {
  const _CategoryInspector({super.key, required this.category});

  final MenuCategory category;

  @override
  State<_CategoryInspector> createState() => _CategoryInspectorState();
}

class _CategoryInspectorState extends State<_CategoryInspector> {
  late final TextEditingController nameController = TextEditingController(text: widget.category.nameEn);
  bool renaming = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _rename(CafeStore store) {
    final value = nameController.text.trim();
    if (value.isEmpty) return;
    store.saveCategory(
      widget.category
        ..nameEn = value
        ..nameAr = value,
    );
    setState(() => renaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final category = widget.category;
    final dishes = store.dishesIn(category.id);
    return TawlaPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EyebrowLabel(context.l10n.layoutCurrentlyInspecting, color: CafeColors.ink),
                    const SizedBox(height: 2),
                    if (renaming)
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: nameController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixIcon: IconButton(
                              tooltip: context.l10n.layoutRenameCategory,
                              icon: Icon(Icons.check, color: CafeSurfaces.of(context).buttonInk),
                              onPressed: () => _rename(store),
                            ),
                          ),
                          onSubmitted: (_) => _rename(store),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Flexible(child: Text(category.nameEn, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CafeColors.ink))),
                          IconButton(
                            tooltip: context.l10n.layoutRenameCategory,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => renaming = true),
                            icon: Icon(Icons.edit_outlined, size: 16, color: CafeSurfaces.of(context).buttonInk),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: context.l10n.layoutShowOnMenu,
                child: Switch(value: category.visible, onChanged: (value) => store.saveCategory(category..visible = value)),
              ),
              const SizedBox(width: 6),
              IconAction(
                icon: Icons.delete_outline,
                tooltip: context.l10n.layoutDeleteCategoryConfirm,
                danger: true,
                size: 44,
                onPressed: () => _confirmDeleteCategory(context, store, category),
              ),
              const SizedBox(width: 8),
              NavyButton(label: context.l10n.layoutAddDish, icon: Icons.add, height: 44, onPressed: () => showAddDishDialog(context, store, categoryId: category.id)),
            ],
          ),
          const SizedBox(height: 14),
          EyebrowLabel(
            context.l10n.layoutDishesInCategory(category.nameEn.toUpperCase(), '${dishes.where((item) => item.available).length}'),
            color: CafeColors.ink,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 220).floor().clamp(1, 3);
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < dishes.length; i++)
                    SizedBox(
                      key: ValueKey(dishes[i].id),
                      width: width,
                      child: _DishCard(
                        dish: dishes[i],
                        onMoveEarlier: i > 0 ? () => store.reorderDishes(category.id, i, i - 1) : null,
                        onMoveLater: i < dishes.length - 1 ? () => store.reorderDishes(category.id, i, i + 1) : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
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

/// A dish in the inspector: photo, names, price, the Hero/List choice and delete.
class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, this.onMoveEarlier, this.onMoveLater});

  final MenuItem dish;
  final VoidCallback? onMoveEarlier;
  final VoidCallback? onMoveLater;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CafeStore>();
    final surfaces = CafeSurfaces.of(context);
    final hero = dish.featured;
    Widget overlayButton(IconData icon, String tooltip, VoidCallback? onPressed) => Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.white.withValues(alpha: onPressed == null ? 0.5 : 0.92),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 18, color: onPressed == null ? TawlaTokens.muted : surfaces.buttonInk)),
            ),
          ),
        );
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: hero ? surfaces.button : TawlaTokens.border, width: hero ? 1.4 : 1),
      ),
      child: InkWell(
        onTap: () => showAddDishDialog(context, store, existing: dish, categoryId: dish.categoryId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(builder: (context, c) => DishPhoto(path: dish.imageUrl, size: 112, width: c.maxWidth, radius: 0)),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: StatusBadge(
                      dish.available ? context.l10n.layoutActive : context.l10n.dishInactive,
                      tone: dish.available ? BadgeTone.success : BadgeTone.neutral,
                    ),
                  ),
                  if (hero)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: surfaces.button, borderRadius: BorderRadius.circular(12)),
                        child: Text(context.l10n.layoutHeroCard, style: TextStyle(color: surfaces.onButton, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      ),
                    ),
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    child: Row(
                      children: [
                        overlayButton(Icons.chevron_left, context.l10n.layoutMoveEarlier, onMoveEarlier),
                        const SizedBox(width: 6),
                        overlayButton(Icons.chevron_right, context.l10n.layoutMoveLater, onMoveLater),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(dish.nameEn.isEmpty ? dish.nameIt : dish.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CafeColors.ink)),
                  if (dish.nameIt.isNotEmpty && dish.nameIt != dish.nameEn)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(dish.nameIt, textDirection: TextDirection.rtl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted)),
                    ),
                  const SizedBox(height: 8),
                  Text(store.currency.format(dish.price), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: surfaces.header)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _segment(context, context.l10n.layoutHero, hero, () => store.saveMenuItem(dish..featured = true)),
                            _segment(context, context.l10n.layoutList, !hero, () => store.saveMenuItem(dish..featured = false)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconAction(icon: Icons.edit_outlined, tooltip: context.l10n.layoutEditDish, onPressed: () => showAddDishDialog(context, store, existing: dish, categoryId: dish.categoryId)),
                      const SizedBox(width: 6),
                      IconAction(icon: Icons.delete_outline, tooltip: context.l10n.commonDelete, danger: true, onPressed: () => _confirmDelete(context, store)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, String label, bool selected, VoidCallback onTap) {
    final surfaces = CafeSurfaces.of(context);
    final fg = selected ? surfaces.buttonInk : TawlaTokens.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: selected ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
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

  final nameAr = TextEditingController(text: existing?.nameIt ?? '');
  final nameEn = TextEditingController(text: existing?.nameEn ?? '');
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
                    Text(context.l10n.layoutDishNameAr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameAr,
                      decoration: InputDecoration(
                        hintText: context.l10n.layoutDishNameArHint,
                        fillColor: const Color(0xFFFBF6F0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.layoutDishNameEn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameEn,
                      decoration: InputDecoration(
                        hintText: context.l10n.layoutDishNameEnHint,
                        fillColor: const Color(0xFFFBF6F0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.layoutPriceLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: Localizations.localeOf(context).languageCode == 'ar' ? 'د.ل  ' : 'LYD  ',
                        hintText: '18.500',
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
                        } catch (error, stackTrace) {
                          reportError('menu photo', error, stackTrace);
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
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(context.l10n.commonCancel, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final arabic = nameAr.text.trim();
                            final english = nameEn.text.trim();
                            if (arabic.isEmpty || english.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.l10n.layoutEnterDishName)),
                              );
                              return;
                            }
                            final italian = arabic;
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
    nameAr.dispose();
    nameEn.dispose();
    price.dispose();
    return;
  }
  final host = context;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    nameAr.dispose();
    nameEn.dispose();
    price.dispose();
    if (!host.mounted) return;
    try {
      await store.saveMenuItem(saved);
    } catch (error, stackTrace) {
      reportError('save dish layout', error, stackTrace);
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
