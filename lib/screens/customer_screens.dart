import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';

class CustomerShell {
  static Widget nav(BuildContext context, String tableId, String current) {
    Widget item(IconData icon, String label, String path) {
      final active = current == path;
      return InkWell(
        onTap: () => context.go(path),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? CafeColors.terracottaDark : CafeColors.inkMuted),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? CafeColors.terracottaDark : CafeColors.inkMuted,
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: CafeColors.terracottaDark, shape: BoxShape.circle),
              ),
          ],
        ),
      );
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: CafeColors.cream.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: Color(0x66E6E2DC))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          item(Icons.restaurant_menu, context.l10n.guestNavMenu, '/t/$tableId'),
          item(Icons.receipt_long, context.l10n.guestTableBill, '/t/$tableId/cart'),
          InkWell(
            onTap: () {
              context.read<CafeStore>().callStaff(tableId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.guestRequestSent)),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.room_service_outlined, size: 22, color: CafeColors.inkMuted),
                const SizedBox(height: 2),
                Text(context.l10n.guestCallStaff, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CafeColors.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget phone({required Widget child}) {
    return Scaffold(
      backgroundColor: CafeColors.cream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    );
  }
}

class CustomerMenuScreen extends StatefulWidget {
  const CustomerMenuScreen({super.key, required this.tableSlug});
  final String tableSlug;

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  String? categoryId;
  bool chefsOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(widget.tableSlug);
    if (table == null) {
      return CustomerShell.phone(
        child: Column(
          children: [
            _guestHeader(CafeTable(id: 'missing', number: widget.tableSlug, qrSlug: widget.tableSlug)),
            Expanded(child: EmptyHint(context.l10n.noTables)),
            CustomerShell.nav(context, widget.tableSlug, '/t/${widget.tableSlug}'),
          ],
        ),
      );
    }

    final items = store.liveMenu.where((item) {
      if (chefsOnly) return item.featured;
      if (categoryId == null) return true;
      return item.categoryId == categoryId;
    }).toList();
    final featured = store.liveMenu.where((item) => item.featured).toList();
    final grouped = <String, List<MenuItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final cartCount = store.cartFor(table.id).itemCount;

    return CustomerShell.phone(
      child: Column(
        children: [
          _guestHeader(table),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1A9A3C1D),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(context.l10n.guestTableNumber(table.number), style: const TextStyle(color: CafeColors.terracottaDark, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(context.l10n.guestDineInOrder, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(context.l10n.guestMenuTitle, style: CafeTheme.display.copyWith(fontSize: MediaQuery.sizeOf(context).width < 420 ? 20 : 24)),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: CafeColors.creamDark, shape: BoxShape.circle),
                          child: const Icon(Icons.tune, color: CafeColors.inkMuted, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      children: [
                        _catChip(context.l10n.guestChefsSpecials, chefsOnly, () => setState(() {
                          chefsOnly = true;
                          categoryId = null;
                        })),
                        ...store.guestCategories.map(
                          (category) => _catChip(
                            category.label(store.locale),
                            !chefsOnly && categoryId == category.id,
                            () => setState(() {
                              chefsOnly = false;
                              categoryId = category.id;
                            }),
                          ),
                        ),
                        if (store.guestCategories.isNotEmpty)
                          _catChip(context.l10n.guestCategoryAll, !chefsOnly && categoryId == null, () => setState(() {
                            chefsOnly = false;
                            categoryId = null;
                          })),
                      ],
                    ),
                  ),
                ),
                if (store.liveMenu.isEmpty)
                  SliverFillRemaining(child: EmptyHint(context.l10n.noMenu))
                else ...[
                  if (featured.isNotEmpty && (chefsOnly || categoryId == null))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(context.l10n.guestChefsSpecials, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                const Spacer(),
                                Text(context.l10n.guestSpotlight, style: const TextStyle(color: CafeColors.terracottaDark, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _featured(store, table.id, featured.first),
                          ],
                        ),
                      ),
                    ),
                  ...store.guestCategories.where((category) => grouped.containsKey(category.id)).map((category) {
                    final dishes = grouped[category.id]!;
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(category.label(store.locale), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                const Spacer(),
                                Text(context.l10n.guestItemCount('${dishes.length}'), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...dishes.map((item) => _row(store, table.id, item)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              ],
            ),
          ),
          if (cartCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Material(
                color: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: Color(0x1A9A3C1D), borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: const Icon(Icons.receipt, color: CafeColors.terracottaDark, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.guestCartItemCount('$cartCount'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            Text(store.currency.format(store.cartFor(table.id).total), style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/t/${widget.tableSlug}/cart'),
                        child: Text(context.l10n.guestViewOrder, style: const TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w700)),
                      ),
                      FilledButton(
                        onPressed: store.isSendingOrder(table.id)
                            ? null
                            : () async {
                                final sent = await confirmAndSendOrder(context, store, table.id);
                                if (sent && context.mounted) context.go('/t/${widget.tableSlug}/cart');
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: CafeColors.terracottaDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: store.isSendingOrder(table.id)
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(context.l10n.guestOrderButton),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          CustomerShell.nav(context, widget.tableSlug, '/t/${widget.tableSlug}'),
        ],
      ),
    );
  }

  Widget _guestHeader(CafeTable table) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xE6FDF9F2),
        border: Border(bottom: BorderSide(color: Color(0x66E6E2DC))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x1A9A3C1D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant, color: CafeColors.terracottaDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cafe Italiano', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: CafeColors.terracottaDark, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(context.l10n.guestTableDineIn(table.number), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(20)),
            child: Text(context.l10n.guestTableNumber(table.number), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CafeColors.inkMuted)),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? CafeColors.terracottaDark : CafeColors.creamDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(color: selected ? Colors.white : CafeColors.inkMuted, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _featured(CafeStore store, String tableId, MenuItem item) {
    return SoftCard(
      radius: 12,
      padding: EdgeInsets.zero,
      onTap: () => _showDish(store, tableId, item),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
                    return DishPhoto(path: item.imageUrl, size: 192, width: width, radius: 0);
                  },
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: CafeColors.terracottaDark, borderRadius: BorderRadius.circular(20)),
                    child: Text(context.l10n.guestChefsPick, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(20)),
                    child: _price(store, item),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(child: Text(item.displayName(store.locale), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  _add(store, tableId, item),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _row(CafeStore store, String tableId, MenuItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 12,
        padding: const EdgeInsets.all(12),
        onTap: () => _showDish(store, tableId, item),
        child: Row(
          children: [
            DishPhoto(path: item.imageUrl, size: 96, radius: 8),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayName(store.locale), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Flexible(child: _price(store, item, fontSize: 18)),
                      const Spacer(),
                      _add(store, tableId, item),
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

  Widget _price(CafeStore store, MenuItem item, {double fontSize = 14}) {
    if (!item.hasDiscount) {
      return Text(
        store.currency.format(item.salePrice),
        style: TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800, fontSize: fontSize),
      );
    }
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          store.currency.format(item.price),
          style: TextStyle(
            color: CafeColors.inkMuted,
            fontWeight: FontWeight.w600,
            fontSize: fontSize * 0.85,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Text(
          store.currency.format(item.salePrice),
          style: TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800, fontSize: fontSize),
        ),
      ],
    );
  }

  Widget _add(CafeStore store, String tableId, MenuItem item) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filled(
        onPressed: () => store.addToCart(tableId, item),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(backgroundColor: CafeColors.creamDark, foregroundColor: CafeColors.terracottaDark),
        icon: const Icon(Icons.add, size: 18),
      ),
    );
  }

  Future<void> _showDish(CafeStore store, String tableId, MenuItem item) async {
    var qty = 1;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CafeColors.line, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
                      return DishPhoto(path: item.imageUrl, size: 192, width: width, radius: 12);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(item.displayName(store.locale), style: CafeTheme.display.copyWith(fontSize: 24))),
                      _price(store, item, fontSize: 18),
                    ],
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(item.description, style: const TextStyle(color: CafeColors.inkMuted, height: 1.4)),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.guestQuantity, style: const TextStyle(fontSize: 11, letterSpacing: 0.8, color: CafeColors.inkMuted, fontWeight: FontWeight.w600)),
                          Text(context.l10n.guestPortionServing, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            IconButton(onPressed: () => setModal(() => qty = qty > 1 ? qty - 1 : 1), icon: const Icon(Icons.remove, size: 16)),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
                            IconButton(onPressed: () => setModal(() => qty += 1), icon: const Icon(Icons.add, size: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TerracottaButton(
                    label: context.l10n.guestAddToOrder(store.currency.format(item.salePrice * qty)),
                    onPressed: () {
                      for (var i = 0; i < qty; i++) {
                        store.addToCart(tableId, item);
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<bool> confirmAndSendOrder(BuildContext context, CafeStore store, String tableId, {String? menuRoute}) async {
  if (store.isSendingOrder(tableId) || !store.tryBeginOrderConfirm(tableId)) return false;
  try {
    final cart = store.cartFor(tableId);
    if (cart.lines.isEmpty) return false;
    final table = store.tableById(tableId);
    final lines = [
      for (final line in cart.lines)
        OrderLine(menuItemId: line.menuItemId, name: line.name, qty: line.qty, unitPrice: line.unitPrice),
    ];
    final qty = {for (final line in lines) line.menuItemId: line.qty};
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var sending = false;
        return StatefulBuilder(
          builder: (context, setLocal) {
            final visible = lines.where((line) => (qty[line.menuItemId] ?? 0) > 0).toList();
            final subtotal = visible.fold<double>(0, (sum, line) => sum + line.unitPrice * (qty[line.menuItemId] ?? 0));
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Material(
                color: CafeColors.paper,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: CafeColors.line, borderRadius: BorderRadius.circular(4))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: CafeColors.peach, borderRadius: BorderRadius.circular(20)),
                                        child: Text(context.l10n.guestTableNumber(table.number), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: CafeColors.terracottaDark)),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text(context.l10n.guestDineInOrder, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(context.l10n.guestConfirmOrderTitle, style: CafeTheme.display.copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.guestCloseReview,
                              onPressed: sending ? null : () => Navigator.pop(sheetContext, false),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          children: [
                            Text(context.l10n.guestItemsInOrder('${visible.fold<int>(0, (sum, line) => sum + (qty[line.menuItemId] ?? 0))}'), style: const TextStyle(color: CafeColors.inkMuted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                            const SizedBox(height: 8),
                            ...visible.map((line) {
                              final count = qty[line.menuItemId] ?? line.qty;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(16)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            Text(store.currency.format(line.unitPrice * count), style: const TextStyle(fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              onPressed: sending || count <= 0 ? null : () => setLocal(() => qty[line.menuItemId] = count - 1),
                                              icon: const Icon(Icons.remove, size: 16),
                                            ),
                                            Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              onPressed: sending ? null : () => setLocal(() => qty[line.menuItemId] = count + 1),
                                              icon: const Icon(Icons.add, size: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(context.l10n.guestSubtotal, style: const TextStyle(color: CafeColors.inkMuted)),
                                      const Spacer(),
                                      Text(store.currency.format(subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(context.l10n.guestTotalDue, style: const TextStyle(fontWeight: FontWeight.w800)),
                                            Text(context.l10n.guestBilledToTable(table.number), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Text(store.currency.format(subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: CafeColors.terracotta)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: sending
                                    ? null
                                    : () async {
                                        if (sending || store.isSendingOrder(tableId)) return;
                                        sending = true;
                                        setLocal(() {});
                                        final navigator = Navigator.of(sheetContext);
                                        for (final line in lines) {
                                          store.setCartQty(tableId, line.menuItemId, qty[line.menuItemId] ?? line.qty);
                                        }
                                        if (store.cartFor(tableId).lines.isEmpty) {
                                          navigator.pop(false);
                                          return;
                                        }
                                        await store.sendCartToKitchen(tableId);
                                        navigator.pop(true);
                                      },
                                style: FilledButton.styleFrom(backgroundColor: CafeColors.terracottaDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.restaurant, size: 18),
                                label: Text(sending ? context.l10n.guestSendingOrder : context.l10n.guestConfirmSendKitchen),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: sending
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext, false);
                                      if (menuRoute != null && context.mounted) context.go(menuRoute);
                                    },
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: Text(context.l10n.guestModifyOrder),
                            ),
                          ],
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
    return sent ?? false;
  } finally {
    store.endOrderConfirm(tableId);
  }
}

class CustomerCartScreen extends StatelessWidget {
  const CustomerCartScreen({super.key, required this.tableSlug});
  final String tableSlug;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(tableSlug);
    if (table == null) {
      return CustomerShell.phone(
        child: Column(
          children: [
            _cartHeader(context, CafeTable(id: 'missing', number: tableSlug, qrSlug: tableSlug)),
            Expanded(child: EmptyHint(context.l10n.noTables)),
            CustomerShell.nav(context, tableSlug, '/t/$tableSlug/cart'),
          ],
        ),
      );
    }
    final order = store.openOrderFor(table.id);
    final cart = store.cartFor(table.id);

    return CustomerShell.phone(
      child: Column(
        children: [
          _cartHeader(context, table),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Row(
                  children: [
                    Text(context.l10n.guestTableBill, style: CafeTheme.display.copyWith(fontSize: 30, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: CafeColors.peach, borderRadius: BorderRadius.circular(20)),
                      child: Text(context.l10n.guestLiveTab, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (order == null && cart.lines.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 48), child: EmptyHint(context.l10n.noOrders))
                else ...[
                  if (order != null) ...[
                    const SizedBox(height: 12),
                    SoftCard(
                      radius: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.guestOrderNumber(order.id), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          Text(context.l10n.guestTableNumber(table.number), style: const TextStyle(color: CafeColors.inkMuted)),
                          Text(context.l10n.guestSentToKitchenAt(DateFormat.Hm().format(order.createdAt)), style: const TextStyle(color: CafeColors.inkMuted)),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(12)),
                            child: Text(context.l10n.guestKitchenPreparing, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 16),
                          _status(context, order.status),
                        ],
                      ),
                    ),
                  ],
                  if (cart.lines.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(context.l10n.guestNewAdditions, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    SoftCard(
                      radius: 12,
                      child: Column(
                        children: cart.lines.map((line) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                IconButton(
                                  onPressed: () => store.setCartQty(table.id, line.menuItemId, line.qty - 1),
                                  icon: const Icon(Icons.remove, size: 16),
                                ),
                                Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                IconButton(
                                  onPressed: () => store.setCartQty(table.id, line.menuItemId, line.qty + 1),
                                  icon: const Icon(Icons.add, size: 16),
                                ),
                                Text(store.currency.format(line.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SoftCard(
                    radius: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.guestTicketSummary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 10),
                        ...?order?.lines.map((line) => _line(store, line)),
                        ...cart.lines.map((line) => _line(store, line)),
                        const Divider(),
                        Row(
                          children: [
                            Text(context.l10n.guestKitchenTicketTotal, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            MoneyText(store.currency.format(store.tabSubtotal(table.id)), style: const TextStyle(fontSize: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            store.callStaff(table.id);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestRequestSent)));
                          },
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(context.l10n.guestCallServer),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await store.requestBill(table.id);
                            if (context.mounted) context.go('/t/$tableSlug/bill');
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: Text(context.l10n.guestRequestBill),
                        ),
                      ),
                    ],
                  ),
                  if (cart.lines.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TerracottaButton(
                      label: store.isSendingOrder(table.id)
                          ? context.l10n.guestSendingOrder
                          : context.l10n.guestPlaceOrder(store.currency.format(cart.total)),
                      onPressed: store.isSendingOrder(table.id) ? null : () => confirmAndSendOrder(context, store, table.id, menuRoute: '/t/$tableSlug'),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(context.l10n.guestOrdersSentInstantly, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
                    ),
                  ],
                ],
              ],
            ),
          ),
          CustomerShell.nav(context, tableSlug, '/t/$tableSlug/cart'),
        ],
      ),
    );
  }

  Widget _cartHeader(BuildContext context, CafeTable table) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xE6FDF9F2),
        border: Border(bottom: BorderSide(color: Color(0x66E6E2DC))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0x1A9A3C1D), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.restaurant, color: CafeColors.terracottaDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cafe Italiano', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(context.l10n.guestTableDineIn(table.number), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(CafeStore store, OrderLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('${line.qty}×', style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(child: Text(line.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(store.currency.format(line.total), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _status(BuildContext context, OrderStatus status) {
    final labels = [
      context.l10n.guestStatusReceived,
      context.l10n.guestStatusPreparing,
      context.l10n.guestStatusReady,
      context.l10n.guestStatusServed,
    ];
    const icons = [Icons.check, Icons.sync, Icons.dinner_dining, Icons.table_restaurant];
    final current = status.index.clamp(0, 3);
    return Row(
      children: List.generate(4, (index) {
        final active = index <= current;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: active ? CafeColors.terracotta : CafeColors.line,
                child: Icon(index < current ? Icons.check : icons[index], size: 14, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(labels[index], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? CafeColors.terracotta : CafeColors.inkMuted)),
            ],
          ),
        );
      }),
    );
  }
}

class CustomerBillScreen extends StatelessWidget {
  const CustomerBillScreen({super.key, required this.tableSlug});
  final String tableSlug;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(tableSlug);
    if (table == null) {
      return CustomerShell.phone(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xE6FDF9F2),
                border: Border(bottom: BorderSide(color: Color(0x66E6E2DC))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0x1A9A3C1D), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.restaurant, color: CafeColors.terracottaDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Cafe Italiano', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
            Expanded(child: EmptyHint(context.l10n.noTables)),
            CustomerShell.nav(context, tableSlug, '/t/$tableSlug/cart'),
          ],
        ),
      );
    }
    final order = store.openOrderFor(table.id);
    final subtotal = store.tabSubtotal(table.id);
    final service = store.serviceCharge(subtotal);
    final total = store.tabTotal(table.id);
    final paid = order == null && store.cartFor(table.id).lines.isEmpty && table.status == TableStatus.free;

    return CustomerShell.phone(
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xE6FDF9F2),
              border: Border(bottom: BorderSide(color: Color(0x66E6E2DC))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0x1A9A3C1D), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.restaurant, color: CafeColors.terracottaDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cafe Italiano', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(context.l10n.guestTableDineIn(table.number), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (order != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(20)),
                    child: Text(context.l10n.guestOrderNumber(order.id), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                SoftCard(
                  radius: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(context.l10n.guestFinalTab, style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                          const Spacer(),
                          const Icon(Icons.point_of_sale, color: CafeColors.terracotta),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(context.l10n.guestOrderSummary, style: CafeTheme.display.copyWith(fontSize: 28)),
                      Text(
                        '${context.l10n.guestTableNumber(table.number)}  •  ${DateFormat.jm().format(DateTime.now())}${order == null ? '' : '  •  ${context.l10n.guestRefNumber(order.id)}'}',
                        style: const TextStyle(color: CafeColors.inkMuted),
                      ),
                      const SizedBox(height: 16),
                      if (paid)
                        Column(
                          children: [
                            const Icon(Icons.check_circle, color: CafeColors.success, size: 48),
                            const SizedBox(height: 8),
                            Text(context.l10n.guestPaid, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, color: CafeColors.success)),
                            Text(context.l10n.guestPaymentSuccessful, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                            Text(context.l10n.guestThankYou, style: const TextStyle(color: CafeColors.inkMuted)),
                          ],
                        )
                      else if (order == null && store.cartFor(table.id).lines.isEmpty)
                        EmptyHint(context.l10n.noOrders)
                      else ...[
                        ...?order?.lines.map((line) => _row(store, line)),
                        ...store.cartFor(table.id).lines.map((line) => _row(store, line)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              _kv(context.l10n.guestSubtotal, store.currency.format(subtotal)),
                              _kv(context.l10n.guestServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.currency.format(service)),
                              _kv(context.l10n.guestVatIncluded, store.currency.format(0)),
                              const SizedBox(height: 8),
                              _kv(context.l10n.guestTotalDue, store.currency.format(total), big: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TerracottaButton(
                  label: context.l10n.guestWannaCheckIn,
                  onPressed: () => store.requestBill(table.id),
                ),
              ],
            ),
          ),
          CustomerShell.nav(context, tableSlug, '/t/$tableSlug/cart'),
        ],
      ),
    );
  }

  Widget _row(CafeStore store, OrderLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(8)),
            child: Text('${line.qty}×', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(store.currency.format(line.total), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: big ? FontWeight.w800 : FontWeight.w500, fontSize: big ? 16 : 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 18 : 13, color: big ? CafeColors.terracottaDark : CafeColors.ink)),
        ],
      ),
    );
  }
}
