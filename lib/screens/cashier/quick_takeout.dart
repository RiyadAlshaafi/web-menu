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

  void _add(CafeStore store, MenuItem item) {
    if (item.soldOut || !item.available) return;
    final existing = lines.where((line) => line.menuItemId == item.id);
    setState(() {
      if (existing.isEmpty) {
        lines.add(
          OrderLine(
            menuItemId: item.id,
            name: item.displayName(store.locale),
            qty: 1,
            unitPrice: item.salePrice,
            listUnitPrice: item.price,
          ),
        );
      } else {
        existing.first.qty += 1;
      }
    });
  }

  Future<void> _pay(CafeStore store) async {
    if (paying || lines.isEmpty) return;
    setState(() => paying = true);
    final known = store.payments.map((payment) => payment.id).toSet();
    final error = await store.checkoutTakeout(
      lines: [
        for (final line in lines)
          OrderLine(
            menuItemId: line.menuItemId,
            name: line.name,
            qty: line.qty,
            unitPrice: line.unitPrice,
            listUnitPrice: line.listUnitPrice,
          ),
      ],
      paymentTypeId: paymentTypeId ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id),
    );
    if (!mounted) return;
    setState(() => paying = false);
    if (error != null) {
      final message = switch (error) {
        'in_flight' => context.l10n.quickTakeoutBusy,
        _ => error,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (store.autoPrintReceipt) {
      final added = store.payments.where((payment) => !known.contains(payment.id));
      final payment = added.isEmpty ? null : added.first;
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
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 124,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: dishes.length,
                        itemBuilder: (context, index) {
                          final item = dishes[index];
                          final inTicket = lines.where((line) => line.menuItemId == item.id).fold<int>(0, (sum, line) => sum + line.qty);
                          return _TakeoutDishButton(
                            category: categoryNames[item.categoryId] ?? '',
                            name: item.displayName(store.locale),
                            description: item.description,
                            price: store.currency.format(item.salePrice),
                            count: inTicket,
                            enabled: item.available && !item.soldOut,
                            onTap: () => _add(store, item),
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
                                          Expanded(child: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
                                          _stepButton(Icons.remove, () => setState(() {
                                            line.qty -= 1;
                                            if (line.qty <= 0) lines.remove(line);
                                          })),
                                          SizedBox(
                                            width: 36,
                                            child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                          ),
                                          _stepButton(Icons.add, () => setState(() => line.qty += 1)),
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
        style: IconButton.styleFrom(backgroundColor: CafeColors.creamDark, foregroundColor: CafeColors.ink),
        icon: Icon(icon, size: 18),
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
  });

  final String category;
  final String name;
  final String description;
  final String price;
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    final picked = count > 0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$name, $price',
      value: picked ? '$count' : null,
      excludeSemantics: true,
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
            ],
          ),
        ),
      ),
    );
  }
}
