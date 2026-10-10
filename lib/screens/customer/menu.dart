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
    final hasTable = context.select<CafeStore, bool>((store) => store.tableBySlug(widget.tableSlug) != null);
    if (!hasTable) {
      return CustomerShell.phone(
        context,
        child: Column(
          children: [
            GuestHeader(
              table: CafeTable(id: 'missing', number: widget.tableSlug, qrSlug: widget.tableSlug),
            ),
            Expanded(child: EmptyHint(context.l10n.noTables)),
            Builder(builder: (context) => CustomerShell.nav(context, widget.tableSlug, '/t/${widget.tableSlug}')),
          ],
        ),
      );
    }

    return CustomerShell.phone(
      context,
      child: Column(
        children: [
          Builder(
            builder: (context) {
              context.select<CafeStore, String>((store) {
                final table = store.tableBySlug(widget.tableSlug);
                return '${store.cafeName}\u0001${table?.number ?? ''}\u0001${table == null ? '' : store.serviceForTable(table.id)}';
              });
              return GuestHeader(table: context.read<CafeStore>().tableBySlug(widget.tableSlug)!);
            },
          ),
          Builder(
            builder: (context) {
              context.select<CafeStore, (GuestLocationStatus, bool)>((store) => (store.guestLocation, store.guestOrderingOpen));
              return _locationBanner(context.read<CafeStore>());
            },
          ),
          Builder(
            builder: (context) {
              final id = context.select<CafeStore, String>((store) => store.tableBySlug(widget.tableSlug)?.id ?? '');
              if (id.isEmpty) return const SizedBox.shrink();
              return RefusalNotice(tableId: id);
            },
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                context.select<CafeStore, String>((store) => store.guestScrollRevision(widget.tableSlug));
                final store = context.read<CafeStore>();
                final table = store.tableBySlug(widget.tableSlug)!;
                return _dishScroll(store, table);
              },
            ),
          ),
          Builder(builder: (context) => _cartBar(context)),
          Builder(builder: (context) => CustomerShell.nav(context, widget.tableSlug, '/t/${widget.tableSlug}')),
        ],
      ),
    );
  }

  Widget _dishScroll(CafeStore store, CafeTable table) {
    final menu = store.guestMenu;
    final items = menu.where((item) {
      if (chefsOnly) return item.featured;
      if (categoryId == null) return true;
      return item.categoryId == categoryId;
    }).toList();
    final featured = menu.where((item) => item.featured).toList();
    final grouped = <String, List<MenuItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final sections = store.guestCategories.where((category) => grouped.containsKey(category.id)).toList();
    // Category headings only help when the list mixes categories.
    final showHeadings = sections.length > 1;
    if (!_loggedPaint) {
      _loggedPaint = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmFirstPhotos(items);
      });
    }

    return CustomScrollView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(480),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Text(
              context.l10n.guestMenuTitle,
              style: TextStyle(fontSize: MediaQuery.sizeOf(context).width < 360 ? 21 : 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: CafeColors.ink),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                if (store.guestCategories.isNotEmpty)
                  _catChip(
                    context.l10n.guestCategoryAll,
                    !chefsOnly && categoryId == null,
                    () => setState(() {
                      chefsOnly = false;
                      categoryId = null;
                    }),
                  ),
                _catChip(
                  context.l10n.guestChefsSpecials,
                  chefsOnly,
                  () => setState(() {
                    chefsOnly = true;
                    categoryId = null;
                  }),
                ),
                ...store.guestCategories.map(
                  (category) => _catChip(
                    category.label(store.guestLocale),
                    !chefsOnly && categoryId == category.id,
                    () => setState(() {
                      chefsOnly = false;
                      categoryId = category.id;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (menu.isEmpty)
          SliverFillRemaining(child: EmptyHint(context.l10n.noMenu))
        else ...[
          if (featured.isNotEmpty && (chefsOnly || categoryId == null))
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 4), child: _featured(store, table.id, featured.first)),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(
                context.l10n.guestItemCount('${items.length}'),
                style: const TextStyle(color: GuestTokens.muted, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ...sections.expand((category) {
            final dishes = grouped[category.id]!;
            return [
              if (showHeadings)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Text(
                      category.label(store.guestLocale),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CafeColors.ink),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: dishes.length,
                  itemBuilder: (context, index) {
                    final row = RepaintBoundary(child: _row(store, table.id, dishes[index]));
                    if (index >= 6) return row;
                    // Keyed by dish so a row scrolled away and back does not replay it.
                    return FadeSlideIn(
                      id: dishes[index].id,
                      delay: Duration(milliseconds: 40 * index),
                      child: row,
                    );
                  },
                ),
              ),
            ];
          }),
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 24), child: PoweredByTawla()),
          ),
        ],
      ],
    );
  }

  Widget _cartBar(BuildContext context) {
    final stamp = context.select<CafeStore, String>((store) {
      final table = store.tableBySlug(widget.tableSlug);
      if (table == null) return '';
      final cart = store.cartFor(table.id);
      return '${cart.itemCount}|${cart.total}|${store.isSendingOrder(table.id)}|${store.canPlaceOrder}|${store.guestLocation.name}';
    });
    final store = context.read<CafeStore>();
    final table = store.tableBySlug(widget.tableSlug);
    if (table == null || stamp.isEmpty) return const SizedBox.shrink();
    final cart = store.cartFor(table.id);
    final cartCount = cart.itemCount;
    return AnimatedSwitcher(
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
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: _blockedOr(context, store, _viewOrderBar(store, table.id, cartCount, cart.total))),
            )
          : const SizedBox.shrink(key: ValueKey('cart-bar-empty')),
    );
  }

  /// The bar, in the cafe's button colour, that opens "Verify Your Order".
  Widget _viewOrderBar(CafeStore store, String tableId, int count, double total) {
    final sending = store.isSendingOrder(tableId);
    final enabled = store.canPlaceOrder && !sending;
    final surfaces = CafeSurfaces.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fill = store.canPlaceOrder ? surfaces.button : scheme.onSurface.withValues(alpha: 0.12);
    final onFill = store.canPlaceOrder ? surfaces.onButton : scheme.onSurface.withValues(alpha: 0.38);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled
              ? () async {
                  final sent = await confirmAndSendOrder(context, store, tableId);
                  if (!mounted || !sent) return;
                  context.go('/t/${widget.tableSlug}/cart');
                }
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: CafeMotion.quick,
                      switchInCurve: CafeMotion.easeOut,
                      switchOutCurve: CafeMotion.easeOut.flipped,
                      layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                      child: Text(
                        '${context.l10n.guestCartItemCount('$count')} · ${store.guestCurrency.format(total)}',
                        key: ValueKey('cart-$count-$total'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: onFill, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (sending)
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: onFill))
                  else ...[
                    Text(
                      context.l10n.guestViewOrder,
                      style: TextStyle(
                        color: onFill,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: onFill, size: 22),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _warmFirstPhotos(List<MenuItem> items) {
    if (!mounted) return;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final edge = (96 * ratio).round();
    var warmed = 0;
    for (final item in items) {
      if (warmed >= 4) return;
      final url = item.imageUrl.trim();
      if (!url.startsWith('http')) continue;
      precacheImage(ResizeImage.resizeIfNeeded(edge, edge, NetworkImage(url)), context);
      warmed++;
    }
  }

  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    final surfaces = CafeSurfaces.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? surfaces.button : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? surfaces.button : GuestTokens.border, width: 1.5),
            ),
            child: Text(
              label,
              style: TextStyle(color: selected ? surfaces.onButton : CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featured(CafeStore store, String tableId, MenuItem item) {
    final open = store.canOrderItem(item);
    final category = store.guestCategories.where((category) => category.id == item.categoryId);
    return ScrollFriendlyTap(
      onTap: () => _showDish(store, tableId, item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x141B3A4B), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
                    return DishPhoto(path: item.imageUrl, size: 150, width: width, radius: 0);
                  },
                ),
                PositionedDirectional(start: 12, top: 12, child: _badge(context.l10n.guestSpotlight)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName(store.guestLocale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: open ? CafeColors.ink : GuestTokens.muted, decoration: open ? null : TextDecoration.lineThrough),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          open ? (category.isEmpty ? context.l10n.guestChefsSpecials : category.first.label(store.guestLocale)) : context.l10n.cashierNotAvailable,
                          style: TextStyle(color: open ? GuestTokens.muted : CafeSurfaces.of(context).button, fontSize: 13, fontWeight: open ? FontWeight.w400 : FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _price(store, item, fontSize: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: CafeSurfaces.of(context).button, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: CafeSurfaces.of(context).onButton, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      ),
    );
  }

  Widget _row(CafeStore store, String tableId, MenuItem item) {
    final open = store.canOrderItem(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: ScrollFriendlyTap(
                onTap: () => _showDish(store, tableId, item),
                child: Row(
                  children: [
                    DishPhoto(path: item.imageUrl, size: 68, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName(store.guestLocale),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: open ? CafeColors.ink : GuestTokens.muted, decoration: open ? null : TextDecoration.lineThrough),
                          ),
                          const SizedBox(height: 3),
                          if (open)
                            _price(store, item, fontSize: 15)
                          else
                            Text(
                              context.l10n.cashierNotAvailable,
                              style: TextStyle(color: CafeSurfaces.of(context).button, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The list rebuilds only when the menu changes, so the count listens to the cart itself.
            Builder(
              builder: (context) {
                final inCart = context.select<CafeStore, int>((store) => store.cartFor(tableId).lines.where((line) => line.menuItemId == item.id).fold<int>(0, (sum, line) => sum + line.qty));
                if (inCart == 0) return const SizedBox.shrink();
                final surfaces = CafeSurfaces.of(context);
                return Container(
                  margin: const EdgeInsetsDirectional.only(start: 8),
                  constraints: const BoxConstraints(minWidth: 26),
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: surfaces.header, borderRadius: BorderRadius.circular(13)),
                  child: Text(
                    '$inCart',
                    style: TextStyle(color: surfaces.onHeader, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            _add(store, tableId, item),
          ],
        ),
      ),
    );
  }

  Widget _price(CafeStore store, MenuItem item, {double fontSize = 14}) {
    final navy = CafeSurfaces.of(context).header;
    if (!item.hasDiscount) {
      return Text(
        store.guestCurrency.format(item.salePrice),
        style: TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: fontSize),
      );
    }
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          store.guestCurrency.format(item.price),
          style: TextStyle(color: GuestTokens.muted, fontWeight: FontWeight.w600, fontSize: fontSize * 0.85, decoration: TextDecoration.lineThrough),
        ),
        Text(
          store.guestCurrency.format(item.salePrice),
          style: TextStyle(color: CafeSurfaces.of(context).button, fontWeight: FontWeight.w800, fontSize: fontSize),
        ),
      ],
    );
  }

  Widget _locationBanner(CafeStore store) {
    final message = guestLocationMessage(context, store);
    if (message == null) return const SizedBox.shrink();
    final retry = store.guestLocation == GuestLocationStatus.denied || store.guestLocation == GuestLocationStatus.unavailable || store.guestLocation == GuestLocationStatus.tooFar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: GuestTokens.softAccent,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w700, height: 1.35),
              ),
              if (store.guestLocation == GuestLocationStatus.denied) ...[
                const SizedBox(height: 4),
                Text(context.l10n.guestLocationIosHint, style: const TextStyle(color: GuestTokens.muted, fontSize: 12, height: 1.3)),
              ],
              if (retry) ...[
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => store.refreshGuestLocation(widget.tableSlug, force: true),
                  child: Text(
                    store.guestLocation == GuestLocationStatus.denied ? context.l10n.guestLocationAllow : context.l10n.guestLocationRetry,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _add(CafeStore store, String tableId, MenuItem item) {
    final open = store.canOrderItem(item);
    final blocked = open && !store.canPlaceOrder;
    final button = SizedBox(
      width: 44,
      height: 44,
      child: IconButton.filled(
        tooltip: item.displayName(store.guestLocale),
        onPressed: open && !blocked ? () => store.addToCart(tableId, item) : null,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.add, size: 22),
      ),
    );
    final control = !blocked
        ? button
        : GestureDetector(
            onTap: () => showGuestLocationBlock(context, store),
            child: IgnorePointer(child: button),
          );
    return Listener(behavior: HitTestBehavior.opaque, onPointerDown: (_) => ScrollFriendlyTap.claimPointer(context), child: control);
  }

  Future<void> _showDish(CafeStore store, String tableId, MenuItem item) async {
    if (!store.canOrderItem(item)) return;
    var qty = 1;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GuestTokens.page,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => guestLocalized(
        store,
        context,
        Builder(
          builder: (context) {
            final surfaces = CafeSurfaces.of(context);
            final name = item.displayName(store.guestLocale);
            final otherName = item.displayName(store.guestLocale == 'ar' ? 'en' : 'ar');
            return StatefulBuilder(
              builder: (context, setModal) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
                              return DishPhoto(path: item.imageUrl, size: 200, width: width, radius: 0);
                            },
                          ),
                          PositionedDirectional(
                            top: 12,
                            end: 12,
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: CafeColors.ink, size: 20),
                              ),
                            ),
                          ),
                          if (item.featured) PositionedDirectional(start: 14, bottom: 14, child: _badge(context.l10n.guestChefsPick)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
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
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CafeColors.ink),
                                      ),
                                      if (otherName != name) ...[const SizedBox(height: 2), Text(otherName, style: const TextStyle(fontSize: 15, color: GuestTokens.muted))],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(padding: const EdgeInsets.only(top: 4), child: _price(store, item, fontSize: 18)),
                              ],
                            ),
                            if (item.description.isNotEmpty) ...[const SizedBox(height: 10), Text(item.description, style: const TextStyle(color: GuestTokens.muted, height: 1.45))],
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n.guestQuantity,
                                          style: const TextStyle(fontSize: 12, letterSpacing: 1.4, color: GuestTokens.muted, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(context.l10n.guestPortionServing, style: const TextStyle(fontSize: 13, color: GuestTokens.muted)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: IconButton.outlined(
                                      onPressed: () => setModal(() => qty = qty > 1 ? qty - 1 : 1),
                                      style: IconButton.styleFrom(side: BorderSide(color: surfaces.buttonInk, width: 1.5)),
                                      icon: const Icon(Icons.remove, size: 20),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      '$qty',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: IconButton.filled(
                                      onPressed: () => setModal(() => qty += 1),
                                      icon: const Icon(Icons.add, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _blockedOr(
                              context,
                              store,
                              GuestPrimaryButton(
                                height: 58,
                                label: context.l10n.guestAddToOrder(store.guestCurrency.format(item.salePrice * qty)),
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
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
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
        OrderLine(
          menuItemId: line.menuItemId,
          name: line.name,
          qty: line.qty,
          unitPrice: line.unitPrice,
          listUnitPrice: line.listUnitPrice,
        ),
    ];
    final qty = {for (final line in lines) line.menuItemId: line.qty};
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => guestLocalized(store, sheetContext, Builder(builder: (sheetContext) {
        var sending = false;
        return StatefulBuilder(
          builder: (context, setLocal) {
            final visible = lines.where((line) => (qty[line.menuItemId] ?? 0) > 0).toList();
            final subtotal = visible.fold<double>(0, (sum, line) => sum + line.unitPrice * (qty[line.menuItemId] ?? 0));
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x261B3A4B), blurRadius: 24, offset: Offset(0, 8))],
                ),
                child: Material(
                color: CafeColors.paper,
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
                                            Text(store.guestLineName(line), style: const TextStyle(fontWeight: FontWeight.w700)),
                                            Text(store.guestCurrency.format(line.unitPrice * count), style: const TextStyle(fontWeight: FontWeight.w800)),
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
                                      Text(store.guestCurrency.format(subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                                      Text(store.guestCurrency.format(subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: CafeColors.terracotta)),
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
                              height: 52,
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
                                icon: sending ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CafeSurfaces.of(context).onButton)) : const Icon(Icons.restaurant, size: 18),
                                label: Text(
                                  sending ? context.l10n.guestSendingOrder : context.l10n.guestConfirmSendKitchen,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: sending
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext, false);
                                      if (menuRoute != null && context.mounted) context.go(menuRoute);
                                    },
                              icon: const Icon(Icons.arrow_back, size: 16),
                              label: Text(context.l10n.guestModifyOrder, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            );
          },
        );
      })),
    );
    return sent ?? false;
  } finally {
    store.endOrderConfirm(tableId);
  }
}

String? guestLocationMessage(BuildContext context, CafeStore store) {
  if (!store.guestOrderingOpen) return context.l10n.guestOrderingPaused;
  return switch (store.guestLocation) {
    GuestLocationStatus.tooFar => context.l10n.guestLocationTooFar,
    GuestLocationStatus.denied => context.l10n.guestLocationDenied,
    GuestLocationStatus.unavailable => context.l10n.guestLocationUnavailable,
    GuestLocationStatus.checking => context.l10n.guestLocationChecking,
    GuestLocationStatus.off || GuestLocationStatus.allowed => null,
  };
}

/// Bottom sheets open on the app's root navigator, above the guest page's
/// language override, so they would show the staff language. Re-apply the
/// guest's language and reading direction inside the sheet.
Widget guestLocalized(CafeStore store, BuildContext context, Widget child) {
  final code = store.guestLocale;
  return Localizations.override(
    context: context,
    locale: Locale(code),
    child: Directionality(
      textDirection: code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: child,
    ),
  );
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
  if (text.contains('cashier_offline')) {
    context.read<CafeStore>().guestOrderingClosed();
    return context.l10n.guestOrderingPaused;
  }
  if (text.contains('too_far')) return context.l10n.guestLocationTooFar;
  if (text.contains('location_required')) return context.l10n.guestLocationDenied;
  if (text.startsWith(AppDatabase.unavailableItemsError)) {
    return context.l10n.guestItemsUnavailable(text.substring(AppDatabase.unavailableItemsError.length));
  }
  if (text.contains('qty_too_large')) return context.l10n.guestQtyTooLarge;
  return text;
}

