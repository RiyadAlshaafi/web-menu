part of '../cashier_screens.dart';

class QuickTakeoutScreen extends StatefulWidget {
  const QuickTakeoutScreen({super.key});

  @override
  State<QuickTakeoutScreen> createState() => _QuickTakeoutScreenState();
}

class _QuickTakeoutScreenState extends State<QuickTakeoutScreen> {
  final search = TextEditingController();
  final lines = <OrderLine>[];
  String? categoryId;
  String? paymentTypeId;
  var paying = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  double get total => lines.fold<double>(0, (sum, line) => sum + line.total);

  int _inTicket(String menuItemId) =>
      lines.where((line) => line.menuItemId == menuItemId).fold<int>(0, (sum, line) => sum + line.qty);

  /// Whether one more of [menuItemId] fits in what is left of its stock.
  bool _canAddOne(CafeStore store, String menuItemId) {
    final item = store.menuItems.where((item) => item.id == menuItemId).firstOrNull;
    return item == null || item.canSellMore(_inTicket(menuItemId));
  }

  /// A tap on a dish adds it as it comes; its choices are changed from the ticket line.
  void _add(CafeStore store, MenuItem item) {
    if (item.soldOut || !item.available || !item.canSellMore(_inTicket(item.id))) return;
    final existing = lines.where((line) => line.menuItemId == item.id && line.choices.isEmpty);
    setState(() {
      if (existing.isEmpty) {
        lines.add(item.lineWith(locale: store.locale));
      } else {
        existing.first.qty += 1;
      }
    });
  }

  /// Holding a dish card: pick its choices first, then it goes on the ticket.
  Future<void> _addWithChoices(CafeStore store, MenuItem item) async {
    if (item.soldOut || !item.available) return;
    final on = await showDishChoicesSheet(
      context,
      item: item,
      onIds: item.defaultOnIds,
      locale: store.locale,
      money: store.currency.format,
    );
    if (on == null || !mounted || !item.canSellMore(_inTicket(item.id))) return;
    final line = item.lineWith(locale: store.locale, onIds: on);
    setState(() {
      final twin = lines.where((other) => other.mergeKey == line.mergeKey);
      if (twin.isEmpty) {
        lines.add(line);
      } else {
        twin.first.qty += 1;
      }
    });
  }

  Future<void> _editChoices(CafeStore store, OrderLine line) async {
    final item = store.menuItems.where((item) => item.id == line.menuItemId).firstOrNull;
    if (item == null || !store.hasChoices(item)) return;
    final on = await showDishChoicesSheet(
      context,
      item: item,
      onIds: onIdsFor(item.options, line.choices),
      locale: store.locale,
      money: store.currency.format,
    );
    if (on == null || !mounted) return;
    setState(() => replaceLineChoices(lines, line, item.lineWith(locale: store.locale, onIds: on, qty: line.qty)));
  }

  Future<void> _pay(CafeStore store) async {
    if (paying || lines.isEmpty) return;
    setState(() => paying = true);
    final known = store.payments.map((payment) => payment.id).toSet();
    final sold = [for (final line in lines) line.withQty(line.qty)];
    final error = await store.checkoutTakeout(
      lines: [
        for (final line in lines) line.withQty(line.qty),
      ],
      paymentTypeId: paymentTypeId ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id),
    );
    if (!mounted) return;
    setState(() => paying = false);
    if (error != null) {
      final message = switch (error) {
        'in_flight' => context.l10n.quickTakeoutBusy,
        _ => context.l10n.errorText(error),
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final added = store.payments.where((payment) => !known.contains(payment.id));
    final paid = added.isEmpty ? null : added.first;
    if (paid != null) printKitchenTakeout(context, store, paid, sold);
    if (store.autoPrintReceipt) {
      final payment = paid;
      if (payment != null) {
        unawaited(showReceiptPrint(store, payment, context.l10n).catchError((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.receiptPrintFailed)));
        }));
      }
    }
    setState(lines.clear);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.quickTakeoutPaid)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final needle = search.text.trim().toLowerCase();
    final cardsLayout = store.takeoutCards;
    final categories = store.categories.where((item) => item.visible).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final dishes = store.menuItems.where((item) {
      if (categoryId != null && item.categoryId != categoryId) return false;
      if (needle.isEmpty) return true;
      return item.displayName(store.locale).toLowerCase().contains(needle) ||
          item.description.toLowerCase().contains(needle);
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final categoryNames = {for (final category in store.categories) category.id: category.label(store.locale)};

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Dishes on the left and the cart on the right keep Pay in view; only a really narrow
                // window stacks them.
                final stacked = constraints.maxWidth < 760;
                final catalog = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageSearchField(
                      controller: search,
                      hint: context.l10n.quickTakeoutSearch,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    if (!cardsLayout)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterPill(label: context.l10n.quickTakeoutAll, selected: categoryId == null, onTap: () => setState(() => categoryId = null)),
                            for (final category in categories) ...[
                              const SizedBox(width: 8),
                              FilterPill(
                                label: category.label(store.locale),
                                selected: categoryId == category.id,
                                onTap: () => setState(() => categoryId = category.id),
                              ),
                            ],
                          ],
                        ),
                      )
                    // Cards layout: inside a category one button goes back to the cards.
                    else if (categoryId != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilterPill(
                          label: '${context.l10n.quickTakeoutAll}  ·  ${categoryNames[categoryId] ?? ''}',
                          selected: true,
                          onTap: () => setState(() => categoryId = null),
                        ),
                      ),
                    SizedBox(height: !cardsLayout || categoryId != null ? 14 : 0),
                    Expanded(
                      child: cardsLayout && categoryId == null && needle.isEmpty
                          ? GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisExtent: 124,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final count = store.menuItems.where((item) => item.categoryId == category.id).length;
                                return _TakeoutCategoryCard(
                                  name: category.label(store.locale),
                                  imageUrl: category.imageUrl,
                                  count: count,
                                  onTap: () => setState(() => categoryId = category.id),
                                );
                              },
                            )
                          : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 124,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: dishes.length,
                        itemBuilder: (context, index) {
                          final item = dishes[index];
                          final inTicket = _inTicket(item.id);
                          return _TakeoutDishButton(
                            category: categoryNames[item.categoryId] ?? '',
                            name: item.displayName(store.locale),
                            description: item.description,
                            price: store.currency.format(item.salePrice),
                            count: inTicket,
                            enabled: item.available && !item.soldOut && item.canSellMore(inTicket),
                            onTap: () => _add(store, item),
                            onHold: store.hasChoices(item) ? () => _addWithChoices(store, item) : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
                final ticket = SoftCard(
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          PanelTitle(context.l10n.navQuickTakeout, size: 18),
                          const SizedBox(width: 8),
                          StatusBadge(context.l10n.serviceTakeout, tone: BadgeTone.navy),
                          const Spacer(),
                          if (lines.isNotEmpty)
                            Text(
                              context.l10n.cashierItemsCount('${lines.fold<int>(0, (sum, line) => sum + line.qty)}'),
                              style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: CafeColors.line),
                      Expanded(
                        child: lines.isEmpty
                            ? EmptyHint(context.l10n.quickTakeoutEmpty)
                            : ListView(
                                children: [
                                  for (final line in lines)
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.hairline))),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TicketLineName(
                                              line: line,
                                              locale: store.locale,
                                              editable: store.menuItems.any((item) => item.id == line.menuItemId && store.hasChoices(item)),
                                              onTap: () => _editChoices(store, line),
                                            ),
                                          ),
                                          _stepButton(Icons.remove, () => setState(() {
                                            line.qty -= 1;
                                            if (line.qty <= 0) lines.remove(line);
                                          })),
                                          SizedBox(
                                            width: 36,
                                            child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                          ),
                                          _stepButton(Icons.add, () {
                                            if (_canAddOne(store, line.menuItemId)) setState(() => line.qty += 1);
                                          }),
                                          SizedBox(
                                            width: 92,
                                            child: Text(store.currency.format(line.total), textAlign: TextAlign.end, style: const TextStyle(fontSize: 14)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      EyebrowLabel(context.l10n.payTypeLabel),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: paymentTypeId ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id),
                        items: [
                          for (final type in store.enabledPaymentTypes)
                            DropdownMenuItem(value: type.id, child: Text(type.label(store.locale))),
                        ],
                        onChanged: paying ? null : (value) => setState(() => paymentTypeId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(context.l10n.guestTotalDue, style: const TextStyle(color: TawlaTokens.muted, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(store.currency.format(total), style: CafeTheme.display.copyWith(fontSize: 28, fontWeight: FontWeight.w700, color: CafeSurfaces.of(context).header)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: lines.isEmpty || paying ? null : () => _pay(store),
                          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: Text(context.l10n.quickTakeoutPay, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                );
                if (stacked) {
                  // The cart's fixed parts (title, payment type, total, Pay) take about 230 px, so it
                  // always gets at least 340 px: otherwise the list of items in the cart has no room
                  // and the cashier can't see what was added.
                  final ticketHeight = (constraints.maxHeight * 0.42).clamp(340.0, 460.0);
                  return Column(
                    children: [
                      Expanded(child: catalog),
                      const SizedBox(height: 12),
                      SizedBox(height: ticketHeight, child: ticket),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: catalog),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: ticket),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

/// A white category card on the takeout counter; tapping it shows that category's dishes.
class _TakeoutCategoryCard extends StatelessWidget {
  const _TakeoutCategoryCard({required this.name, required this.imageUrl, required this.count, required this.onTap});

  final String name;
  final String imageUrl;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: CafeColors.paper,
        elevation: 1,
        shadowColor: const Color(0x221B3A4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              if (imageUrl.isNotEmpty) DishPhoto(path: imageUrl, size: 124, width: 90, radius: 0),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.25, color: CafeColors.ink),
                      ),
                      const Spacer(),
                      Text('$count', style: const TextStyle(color: TawlaTokens.muted, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dish on the takeout counter. The whole card is the button; a badge shows how many are on the ticket.
class _TakeoutDishButton extends StatelessWidget {
  const _TakeoutDishButton({
    required this.category,
    required this.name,
    required this.description,
    required this.price,
    required this.count,
    required this.enabled,
    required this.onTap,
    this.onHold,
  });

  /// How long a cashier holds a dish to open its ingredients and extras.
  static const holdDuration = Duration(seconds: 1);

  final String category;
  final String name;
  final String description;
  final String price;
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  /// Set when the dish has ingredients or extras: holding the card opens them.
  final VoidCallback? onHold;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    final picked = count > 0;
    final hold = enabled ? onHold : null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$name, $price',
      value: picked ? '$count' : null,
      onLongPressHint: hold == null ? null : context.l10n.dishChoicesHoldCard,
      onLongPress: hold,
      excludeSemantics: true,
      child: RawGestureDetector(
        gestures: {
          if (hold != null)
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: holdDuration),
              (recognizer) => recognizer.onLongPress = () {
                HapticFeedback.mediumImpact();
                hold();
              },
            ),
        },
        child: Material(
        color: enabled ? CafeColors.paper : CafeColors.creamDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: picked ? BorderSide(color: surfaces.button, width: 1.5) : BorderSide.none,
        ),
        elevation: enabled ? 1 : 0,
        shadowColor: const Color(0x221B3A4B),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsetsDirectional.only(end: picked ? 30 : 0),
                        child: Text(
                          category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: TawlaTokens.muted),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Padding(
                      padding: EdgeInsetsDirectional.only(end: picked ? 30 : 0),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.25, color: enabled ? CafeColors.ink : CafeColors.inkMuted),
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
                    ],
                    const Spacer(),
                    Text(price, style: TextStyle(color: surfaces.header, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
              if (picked)
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: surfaces.button, borderRadius: BorderRadius.circular(13)),
                    child: Text('$count', style: TextStyle(color: surfaces.onButton, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              if (onHold != null)
                PositionedDirectional(
                  bottom: 12,
                  end: 12,
                  child: Icon(Icons.tune, size: 18, color: enabled ? surfaces.buttonInk : CafeColors.inkMuted),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
