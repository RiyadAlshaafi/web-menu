part of '../customer_screens.dart';

class CustomerBillScreen extends StatelessWidget {
  const CustomerBillScreen({super.key, required this.tableSlug});
  final String tableSlug;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(tableSlug);
    if (table == null) {
      return CustomerShell.phone(context,
        child: Column(
          children: [
            Container(
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
                  Text(context.watch<CafeStore>().cafeName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CafeSurfaces.of(context).onHeader)),
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

    return CustomerShell.phone(context,
      child: Column(
        children: [
          Container(
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
                if (order != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(20)),
                    child: Text(context.l10n.guestOrderNumber(store.shiftTicket(order)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
                        '${context.l10n.guestTableNumber(table.number)}  •  ${formatTripoliJm(DateTime.now())}${order == null ? '' : '  •  ${context.l10n.guestOrderNumber(store.shiftTicket(order))}'}',
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
                if (order != null && store.enabledPaymentTypes.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(order.paymentTypeId),
                    initialValue: store.enabledPaymentTypes.any((type) => type.id == order.paymentTypeId) ? order.paymentTypeId : null,
                    decoration: InputDecoration(
                      labelText: context.l10n.payChoose,
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: CafeSurfaces.of(context).button)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: CafeSurfaces.of(context).button, width: 2)),
                    ),
                    icon: Icon(Icons.keyboard_arrow_down, color: CafeSurfaces.of(context).button),
                    items: [
                      for (final type in store.enabledPaymentTypes)
                        DropdownMenuItem(value: type.id, child: Text(type.label(store.locale))),
                    ],
                    onChanged: (id) {
                      if (id != null) store.setTablePaymentType(table.id, id);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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

BoxDecoration guestHeaderDecoration(BuildContext context) {
  final surfaces = CafeSurfaces.of(context);
  return BoxDecoration(
    color: surfaces.header,
    border: Border(bottom: BorderSide(color: surfaces.onHeader.withValues(alpha: 0.18))),
  );
}

class RefusalNotice extends StatelessWidget {
  const RefusalNotice({super.key, required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final order = store.openOrderFor(tableId);
    if (order == null || !order.awaitingCustomerConfirmation) return const SizedBox.shrink();
    final button = CafeSurfaces.of(context).button;
    return Material(
      color: button.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.guestItemRemoved(order.refusalNotice), style: TextStyle(color: button, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => store.confirmRefusedOrder(tableId),
              child: Text(context.l10n.guestConfirmRequestBill),
            ),
          ],
        ),
      ),
    );
  }
}

