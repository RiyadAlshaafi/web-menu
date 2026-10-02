part of '../customer_screens.dart';

class CustomerMenuScreen extends StatefulWidget {
  const CustomerMenuScreen({super.key, required this.tableSlug});
  final String tableSlug;

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  String? categoryId;
  bool chefsOnly = false;
  bool _loggedPaint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CafeStore>().refreshGuestLocation(widget.tableSlug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(widget.tableSlug);
    if (table == null) {
      return CustomerShell.phone(context,
        child: Column(
          children: [
            _guestHeader(CafeTable(id: 'missing', number: widget.tableSlug, qrSlug: widget.tableSlug)),
            Expanded(child: EmptyHint(context.l10n.noTables)),
            CustomerShell.nav(context, widget.tableSlug, '/t/${widget.tableSlug}'),
          ],
        ),
      );
    }

    final items = store.guestMenu.where((item) {
      if (chefsOnly) return item.featured;
      if (categoryId == null) return true;
      return item.categoryId == categoryId;
    }).toList();
    final featured = store.guestMenu.where((item) => item.featured).toList();
    final grouped = <String, List<MenuItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final cartCount = store.cartFor(table.id).itemCount;
    if (!_loggedPaint) {
      _loggedPaint = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // #region agent log
        agentLog('C', 'menu.dart:build', 'menu painted', {
          'rows': items.length,
          'httpImages': items.where((item) => item.imageUrl.startsWith('http')).length,
          'dataImages': items.where((item) => item.imageUrl.startsWith('data:')).length,
        });
        // #endregion
      });
    }

    return CustomerShell.phone(context,
      child: Column(
        children: [
          _guestHeader(table),
          _locationBanner(store),
          RefusalNotice(tableId: table.id),
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
                                  if (store.serviceForTable(table.id) != 'takeout') ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: CafeSurfaces.of(context).button.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(context.l10n.guestTableNumber(table.number), style: TextStyle(color: CafeSurfaces.of(context).button, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    store.serviceForTable(table.id) == 'takeout' ? context.l10n.serviceTakeout : context.l10n.guestDineInOrder,
                                    style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13),
                                  ),
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
                if (store.guestMenu.isEmpty)
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
                  ...store.guestCategories.where((category) => grouped.containsKey(category.id)).expand((category) {
                    final dishes = grouped[category.id]!;
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(category.label(store.locale), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const Spacer(),
                              Text(context.l10n.guestItemCount('${dishes.length}'), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: dishes.length,
                          itemBuilder: (context, index) => RepaintBoundary(child: _row(store, table.id, dishes[index])),
                        ),
                      ),
                    ];
                  }),
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: CafeMotion.medium,
            reverseDuration: const Duration(milliseconds: 200),
            switchInCurve: CafeMotion.easeOut,
            switchOutCurve: CafeMotion.easeOut.flipped,
            transitionBuilder: (child, animation) {
              final faded = FadeTransition(opacity: animation, child: child);
              if (MediaQuery.disableAnimationsOf(context)) return faded;
              return SizeTransition(sizeFactor: animation, alignment: AlignmentDirectional.bottomStart, child: faded);
            },
            child: cartCount > 0
                ? KeyedSubtree(
                    key: const ValueKey('cart-bar'),
                    child: Padding(
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
                                    AnimatedSwitcher(
                                      duration: CafeMotion.quick,
                                      switchInCurve: CafeMotion.easeOut,
                                      switchOutCurve: CafeMotion.easeOut.flipped,
                                      layoutBuilder: (current, previous) => Stack(
                                        alignment: AlignmentDirectional.centerStart,
                                        children: [...previous, ?current],
                                      ),
                                      child: Text(
                                        context.l10n.guestCartItemCount('$cartCount'),
                                        key: ValueKey('count-$cartCount'),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: CafeMotion.quick,
                                      switchInCurve: CafeMotion.easeOut,
                                      switchOutCurve: CafeMotion.easeOut.flipped,
                                      layoutBuilder: (current, previous) => Stack(
                                        alignment: AlignmentDirectional.centerStart,
                                        children: [...previous, ?current],
                                      ),
                                      child: Text(
                                        store.currency.format(store.cartFor(table.id).total),
                                        key: ValueKey(store.currency.format(store.cartFor(table.id).total)),
                                        style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: store.openOrderFor(table.id) == null
                                    ? null
                                    : () => context.go('/t/${widget.tableSlug}/cart'),
                                child: Text(context.l10n.guestViewOrder, style: const TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w700)),
                              ),
                              _orderButton(store, table.id),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('cart-bar-empty')),
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
      decoration: guestHeaderDecoration(context),
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
                Text(context.watch<CafeStore>().cafeName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CafeSurfaces.of(context).onHeader)),
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
            color: selected ? CafeSurfaces.of(context).button : CafeColors.creamDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? CafeSurfaces.of(context).button : CafeColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(color: selected ? CafeSurfaces.of(context).onButton : CafeColors.inkMuted, fontWeight: FontWeight.w600, fontSize: 12),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName(store.locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: store.canOrderItem(item) ? CafeColors.ink : CafeColors.inkMuted,
                            decoration: store.canOrderItem(item) ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        if (!store.canOrderItem(item))
                          Text(context.l10n.cashierNotAvailable, style: TextStyle(color: CafeSurfaces.of(context).button, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
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
                  Text(
                    item.displayName(store.locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: store.canOrderItem(item) ? CafeColors.ink : CafeColors.inkMuted,
                      decoration: store.canOrderItem(item) ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  if (!store.canOrderItem(item))
                    Text(context.l10n.cashierNotAvailable, style: TextStyle(color: CafeSurfaces.of(context).button, fontSize: 11, fontWeight: FontWeight.w800)),
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

  Widget _locationBanner(CafeStore store) {
    final message = guestLocationMessage(context, store);
    if (message == null) return const SizedBox.shrink();
    final retry = store.guestLocation == GuestLocationStatus.denied || store.guestLocation == GuestLocationStatus.unavailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: CafeColors.peach,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w700, height: 1.3)),
              if (store.guestLocation == GuestLocationStatus.denied) ...[
                const SizedBox(height: 4),
                Text(context.l10n.guestLocationIosHint, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12, height: 1.3)),
              ],
              if (retry) ...[
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: CafeSurfaces.of(context).button,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => store.refreshGuestLocation(widget.tableSlug, force: true),
                  child: Text(store.guestLocation == GuestLocationStatus.denied ? context.l10n.guestLocationAllow : context.l10n.guestLocationRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderButton(CafeStore store, String tableId) {
    final blocked = !store.canPlaceOrder;
    final sending = store.isSendingOrder(tableId);
    final button = FilledButton(
      onPressed: blocked || sending
          ? null
          : () async {
              final sent = await confirmAndSendOrder(context, store, tableId);
              if (!mounted || !sent) return;
              context.go('/t/${widget.tableSlug}/cart');
            },
      style: FilledButton.styleFrom(
        disabledBackgroundColor: CafeColors.line,
        disabledForegroundColor: CafeColors.inkMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: sending
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(context.l10n.guestOrderButton),
    );
    if (!blocked) return button;
    return GestureDetector(
      onTap: () => showGuestLocationBlock(context, store),
      child: IgnorePointer(child: button),
    );
  }

  Widget _add(CafeStore store, String tableId, MenuItem item) {
    final open = store.canOrderItem(item);
    final blocked = open && !store.canPlaceOrder;
    final button = SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filled(
        onPressed: open && !blocked ? () => store.addToCart(tableId, item) : null,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: open && !blocked ? CafeColors.creamDark : CafeColors.line,
          foregroundColor: open && !blocked ? CafeSurfaces.of(context).button : CafeColors.inkMuted,
          disabledBackgroundColor: CafeColors.line,
          disabledForegroundColor: CafeColors.inkMuted,
        ),
        icon: const Icon(Icons.add, size: 18),
      ),
    );
    if (!blocked) return button;
    return GestureDetector(
      onTap: () => showGuestLocationBlock(context, store),
      child: IgnorePointer(child: button),
    );
  }

  Future<void> _showDish(CafeStore store, String tableId, MenuItem item) async {
    if (!store.canOrderItem(item)) return;
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
                  _blockedOr(
                    context,
                    store,
                    TerracottaButton(
                      label: context.l10n.guestAddToOrder(store.currency.format(item.salePrice * qty)),
                      onPressed: store.canPlaceOrder
                          ? () {
                              for (var i = 0; i < qty; i++) {
                                store.addToCart(tableId, item);
                              }
                              Navigator.pop(context);
                            }
                          : null,
                    ),
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
                                        try {
                                          await store.sendCartToKitchen(tableId);
                                          navigator.pop(true);
                                        } catch (error, stackTrace) {
                                          final text = '$error';
                                          reportError('send cart', text.contains('p_lat') || text.contains('p_lng') ? 'order was not sent' : error, stackTrace);
                                          sending = false;
                                          setLocal(() {});
                                          if (sheetContext.mounted) {
                                            ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(guestOrderErrorText(sheetContext, error))));
                                          }
                                        }
                                      },
                                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

String? guestLocationMessage(BuildContext context, CafeStore store) {
  return switch (store.guestLocation) {
    GuestLocationStatus.tooFar => context.l10n.guestLocationTooFar,
    GuestLocationStatus.denied => context.l10n.guestLocationDenied,
    GuestLocationStatus.unavailable => context.l10n.guestLocationUnavailable,
    GuestLocationStatus.checking => context.l10n.guestLocationChecking,
    GuestLocationStatus.off || GuestLocationStatus.allowed => null,
  };
}

void showGuestLocationBlock(BuildContext context, CafeStore store) {
  final message = guestLocationMessage(context, store);
  if (message == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Widget _blockedOr(BuildContext context, CafeStore store, Widget child) {
  if (store.canPlaceOrder) return child;
  return GestureDetector(
    onTap: () => showGuestLocationBlock(context, store),
    child: IgnorePointer(child: child),
  );
}

String guestOrderErrorText(BuildContext context, Object error) {
  var text = '$error';
  const prefix = 'Bad state: ';
  if (text.startsWith(prefix)) text = text.substring(prefix.length);
  if (text.contains('too_far')) return context.l10n.guestLocationTooFar;
  if (text.contains('location_required')) return context.l10n.guestLocationDenied;
  return text;
}

