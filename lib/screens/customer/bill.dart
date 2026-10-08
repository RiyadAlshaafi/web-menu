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
            GuestHeader(table: CafeTable(id: 'missing', number: tableSlug, qrSlug: tableSlug)),
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
    final navy = CafeSurfaces.of(context).header;

    return CustomerShell.phone(context,
      child: Column(
        children: [
          GuestHeader(table: table),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                GuestCard(
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
                                GuestEyebrow(context.l10n.guestFinalTab),
                                const SizedBox(height: 2),
                                Text(context.l10n.guestOrderSummary, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          if (order?.shiftOrderNumber != null)
                            Text(
                              context.l10n.guestRefNumber(store.shiftTicket(order!).replaceFirst('#', '')),
                              style: const TextStyle(color: GuestTokens.muted, fontSize: 13),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (paid)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle, color: CafeColors.success, size: 48),
                                const SizedBox(height: 8),
                                Text(context.l10n.guestPaid, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, color: CafeColors.success)),
                                Text(context.l10n.guestPaymentSuccessful, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                                Text(context.l10n.guestThankYou, textAlign: TextAlign.center, style: const TextStyle(color: GuestTokens.muted)),
                              ],
                            ),
                          ),
                        )
                      else if (order == null)
                        EmptyHint(context.l10n.noOrders)
                      else ...[
                        // The bill lists what was sent to the kitchen; dishes
                        // still in the cart are not charged.
                        ...order.lines.map(
                          (line) => GuestTicketLine(qty: line.qty, name: store.guestLineName(line), amount: store.guestCurrency.format(line.total)),
                        ),
                        const SizedBox(height: 2),
                        const _DashedLine(),
                        const SizedBox(height: 8),
                        _kv(context.l10n.guestSubtotal, store.guestCurrency.format(subtotal)),
                        _kv(context.l10n.guestServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.guestCurrency.format(service)),
                        _kv(context.l10n.guestVatIncluded, '—'),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(child: Text(context.l10n.guestTotalDue, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                            Text(store.guestCurrency.format(total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: navy)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (order != null && store.enabledPaymentTypes.isNotEmpty) ...[
                  Text(context.l10n.payChoose, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey(order.paymentTypeId),
                    initialValue: store.enabledPaymentTypes.any((type) => type.id == order.paymentTypeId) ? order.paymentTypeId : null,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: CafeColors.ink),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      hintText: context.l10n.guestPayLabel,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: GuestTokens.border, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: CafeSurfaces.of(context).button, width: 2),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, color: GuestTokens.muted),
                    items: [
                      for (final type in store.enabledPaymentTypes)
                        DropdownMenuItem(value: type.id, child: Text(type.label(store.guestLocale))),
                    ],
                    onChanged: (id) {
                      if (id != null) store.setTablePaymentType(table.id, id);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (order != null)
                  GuestPrimaryButton(
                    label: context.l10n.guestConfirmRequestBill,
                    onPressed: () async {
                      if (!store.canRequestBill(table.id)) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestBillAfterServed)));
                        return;
                      }
                      if (store.enabledPaymentTypes.isNotEmpty && order.paymentTypeId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.payChoose)));
                        return;
                      }
                      final error = await store.requestBill(table.id);
                      if (!context.mounted || error == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    },
                  ),
              ],
            ),
          ),
          CustomerShell.nav(context, tableSlug, '/t/$tableSlug/cart'),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: GuestTokens.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CafeColors.ink)),
        ],
      ),
    );
  }
}

/// The dashed rule between the bill lines and the totals.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 7).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 1.5), color: GuestTokens.stepIdle)),
          ),
        );
      },
    );
  }
}

BoxDecoration guestHeaderDecoration(BuildContext context) {
  final surfaces = CafeSurfaces.of(context);
  return BoxDecoration(color: surfaces.header);
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

