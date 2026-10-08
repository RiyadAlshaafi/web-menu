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
            GuestHeader(table: CafeTable(id: 'missing', number: tableSlug, qrSlug: tableSlug)),
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
          GuestHeader(table: table),
          RefusalNotice(tableId: table.id),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                if (order == null && cart.lines.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 48), child: EmptyHint(context.l10n.noOrders))
                else ...[
                  if (order != null) ...[
                    GuestCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GuestEyebrow(context.l10n.guestLiveTab),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.l10n.guestSentToKitchenAt(formatTripoliTime(order.createdAt)),
                                  textAlign: TextAlign.end,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: GuestTokens.muted, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(context.l10n.guestOrderNumber(store.shiftTicket(order)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                          const SizedBox(height: 16),
                          _status(context, order.status),
                          if (order.status.index <= OrderStatus.preparing.index) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              decoration: BoxDecoration(color: GuestTokens.softAccent, borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                context.l10n.guestKitchenPreparing,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.45, color: CafeColors.terracottaDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (cart.lines.isNotEmpty) ...[
                    GuestCard(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.guestNewAdditions, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GuestTokens.muted)),
                          const SizedBox(height: 6),
                          ...cart.lines.map((line) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: GuestTokens.hairline))),
                              child: Row(
                                children: [
                                  Expanded(child: Text(store.guestLineName(line), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                                  _blockedOr(
                                    context,
                                    store,
                                    IconButton(
                                      onPressed: store.canPlaceOrder ? () => store.setCartQty(table.id, line.menuItemId, line.qty - 1) : null,
                                      icon: Icon(Icons.remove, size: 18, color: store.canPlaceOrder ? CafeColors.ink : GuestTokens.muted),
                                    ),
                                  ),
                                  Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  _blockedOr(
                                    context,
                                    store,
                                    IconButton(
                                      onPressed: store.canPlaceOrder ? () => store.setCartQty(table.id, line.menuItemId, line.qty + 1) : null,
                                      icon: Icon(Icons.add, size: 18, color: store.canPlaceOrder ? CafeColors.ink : GuestTokens.muted),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(store.guestCurrency.format(line.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  GuestCard(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(context.l10n.guestTicketSummary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GuestTokens.muted)),
                        ),
                        ...?order?.lines.map((line) => _line(store, line)),
                        ...cart.lines.map((line) => _line(store, line)),
                        Container(
                          padding: const EdgeInsets.only(top: 10),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: CafeColors.line))),
                          child: Row(
                            children: [
                              Expanded(child: Text(context.l10n.guestKitchenTicketTotal, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                              Text(
                                store.guestCurrency.format(store.tabSubtotal(table.id) + cart.total),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CafeSurfaces.of(context).header),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GuestOutlineButton(
                          label: context.l10n.guestCallServer,
                          onPressed: () {
                            if (!store.guestOrderingOpen) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestOrderingPaused)));
                              return;
                            }
                            store.callStaff(table.id);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestRequestSent)));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GuestPrimaryButton(
                          height: 52,
                          label: context.l10n.guestRequestBill,
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

  Widget _line(CafeStore store, OrderLine line) {
    return GuestTicketLine(qty: line.qty, name: store.guestLineName(line), amount: store.guestCurrency.format(line.total));
  }

  /// Received → Preparing → Ready → Served, joined by a line that fills as the order moves.
  Widget _status(BuildContext context, OrderStatus status) {
    final labels = [
      context.l10n.guestStatusReceived,
      context.l10n.guestStatusPreparing,
      context.l10n.guestStatusReady,
      context.l10n.guestStatusServed,
    ];
    final accent = CafeSurfaces.of(context).button;
    final current = status.index.clamp(0, 3);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(4, (index) {
        final reached = index <= current;
        final done = index < current;
        return Expanded(
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Container(height: 3, color: index == 0 ? Colors.transparent : (reached ? accent : GuestTokens.border))),
                        Expanded(child: Container(height: 3, color: index == 3 ? Colors.transparent : (index < current ? accent : GuestTokens.border))),
                      ],
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: reached ? accent : GuestTokens.stepIdle,
                        shape: BoxShape.circle,
                        boxShadow: index == current && !done ? [BoxShadow(color: accent.withValues(alpha: 0.18), spreadRadius: 4)] : null,
                      ),
                      child: done
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: reached ? CafeColors.ink : const Color(0xFF6B7A83)),
              ),
            ],
          ),
        );
      }),
    );
  }
}
