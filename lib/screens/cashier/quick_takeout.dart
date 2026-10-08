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
    final button = CafeSurfaces.of(context).button;

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
                    TextField(
                      controller: search,
                      decoration: InputDecoration(
                        hintText: context.l10n.quickTakeoutSearch,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _pill(context.l10n.quickTakeoutAll, categoryId == null, button, () => setState(() => categoryId = null)),
                          for (final category in categories) ...[
                            const SizedBox(width: 8),
                            _pill(
                              category.label(store.locale),
                              categoryId == category.id,
                              button,
                              () => setState(() => categoryId = category.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 132,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: dishes.length,
                        itemBuilder: (context, index) {
                          final item = dishes[index];
                          final inTicket = lines.where((line) => line.menuItemId == item.id).fold<int>(0, (sum, line) => sum + line.qty);
                          return _TakeoutDishButton(
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
                          Text(context.l10n.navQuickTakeout, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: button.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n.serviceTakeout,
                              style: TextStyle(color: button, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                          const Spacer(),
                          if (lines.isNotEmpty)
                            Text(
                              context.l10n.cashierItemsCount('${lines.fold<int>(0, (sum, line) => sum + line.qty)}'),
                              style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13),
                            ),
                        ],
                      ),
                      const Divider(height: 20),
                      const SizedBox(height: 8),
                      Expanded(
                        child: lines.isEmpty
                            ? EmptyHint(context.l10n.quickTakeoutEmpty)
                            : ListView(
                                children: [
                                  for (final line in lines)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          IconButton(
                                            onPressed: () => setState(() {
                                              line.qty -= 1;
                                              if (line.qty <= 0) lines.remove(line);
                                            }),
                                            icon: const Icon(Icons.remove, size: 18),
                                          ),
                                          Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                          IconButton(
                                            onPressed: () => setState(() => line.qty += 1),
                                            icon: const Icon(Icons.add, size: 18),
                                          ),
                                          SizedBox(
                                            width: 72,
                                            child: Text(store.currency.format(line.total), textAlign: TextAlign.right),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: paymentTypeId ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id),
                        decoration: InputDecoration(labelText: context.l10n.expenseType),
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
                          Text(context.l10n.guestTotalDue, style: const TextStyle(color: CafeColors.inkMuted, fontWeight: FontWeight.w600)),
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
                    Expanded(flex: 8, child: catalog),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: ticket),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, Color button, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? button : CafeColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? button : CafeColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : CafeColors.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A dish on the takeout counter. The whole card is the button; a badge shows how many are on the ticket.
class _TakeoutDishButton extends StatelessWidget {
  const _TakeoutDishButton({
    required this.name,
    required this.description,
    required this.price,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

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
          side: BorderSide(color: picked ? surfaces.button : CafeColors.line, width: picked ? 2 : 1.5),
        ),
        elevation: enabled ? 1 : 0,
        shadowColor: const Color(0x331B3A4B),
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
