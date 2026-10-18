part of '../cashier_screens.dart';

/// Offline tables: the cashier adds dishes to one table's bill (an open tab). The dishes wait in
/// the table's cart until "Add to the table's bill"; the bill is settled later from the floor.
class TableOrderScreen extends StatefulWidget {
  const TableOrderScreen({super.key, required this.tableId});

  final String tableId;

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  final search = TextEditingController();
  String? categoryId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _send(CafeStore store, CafeTable table) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    try {
      await store.sendCartToKitchen(table.id);
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorText(error.message))));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.tableOrderSent(l10n.cashierTableNumber(table.number)))));
    router.go('/pos/tables');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tables.where((item) => item.id == widget.tableId && !item.archived).firstOrNull;
    if (table == null) return EmptyHint(context.l10n.noTables);
    final cart = store.cartFor(table.id);
    final order = store.openOrderFor(table.id);
    final sending = store.isSendingOrder(table.id);
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

    final catalog = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageSearchField(controller: search, hint: context.l10n.quickTakeoutSearch, onChanged: (_) => setState(() {})),
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
              final inCart = cart.lines.where((line) => line.menuItemId == item.id).fold<int>(0, (sum, line) => sum + line.qty);
              return _TakeoutDishButton(
                category: categoryNames[item.categoryId] ?? '',
                name: item.displayName(store.locale),
                description: item.description,
                price: store.currency.format(item.salePrice),
                count: inCart,
                enabled: item.available && !item.soldOut && !sending,
                onTap: () => store.addToCart(table.id, item),
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
              Expanded(child: PanelTitle(context.l10n.cashierTableNumber(table.number), size: 18)),
              TextButton.icon(
                onPressed: () => context.go('/pos/tables'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(context.l10n.tableOrderBack),
              ),
            ],
          ),
          if (order != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.tableOrderOnTab('${order.itemCount}', store.currency.format(store.tabSubtotal(table.id))),
              style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: CafeColors.line),
          Expanded(
            child: cart.lines.isEmpty
                ? EmptyHint(context.l10n.tableOrderEmpty)
                : ListView(
                    children: [
                      for (final line in cart.lines)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.hairline))),
                          child: Row(
                            children: [
                              Expanded(child: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
                              _stepButton(Icons.remove, sending ? null : () => store.setCartQty(table.id, line.menuItemId, line.qty - 1)),
                              SizedBox(
                                width: 36,
                                child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              ),
                              _stepButton(Icons.add, sending ? null : () => store.setCartQty(table.id, line.menuItemId, line.qty + 1)),
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(context.l10n.guestTotalDue, style: const TextStyle(color: TawlaTokens.muted, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                store.currency.format(cart.total),
                style: CafeTheme.display.copyWith(fontSize: 28, fontWeight: FontWeight.w700, color: CafeSurfaces.of(context).header),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: cart.lines.isEmpty || sending ? null : () => _send(store, table),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(context.l10n.tableOrderSend, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
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
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton.filled(onPressed: onPressed, icon: Icon(icon, size: 18)),
    );
  }
}
