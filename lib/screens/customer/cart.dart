part of '../customer_screens.dart';

class CustomerCartScreen extends StatelessWidget {
  const CustomerCartScreen({super.key, required this.tableSlug});
  final String tableSlug;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(tableSlug);
    if (table == null) {
      return CustomerShell.phone(context,
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

    return CustomerShell.phone(context,
      child: Column(
        children: [
          _cartHeader(context, table),
          RefusalNotice(tableId: table.id),
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
                          onPressed: store.canRequestBill(table.id)
                              ? () async {
                                  final error = await store.requestBill(table.id);
                                  if (!context.mounted) return;
                                  if (error != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                                    return;
                                  }
                                  context.go('/t/$tableSlug/bill');
                                }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestBillAfterServed)));
                                },
                          icon: const Icon(Icons.receipt_long),
                          label: Text(context.l10n.guestRequestBill),
                        ),
                      ),
                    ],
                  ),
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
      decoration: guestHeaderDecoration(context),
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
                Text(context.watch<CafeStore>().cafeName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CafeSurfaces.of(context).onHeader)),
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

