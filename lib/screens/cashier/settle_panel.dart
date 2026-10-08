part of '../cashier_screens.dart';

Future<void> showCashSettleDialog(BuildContext context, CafeStore store, String tableId, {bool ignoreCustomerConfirm = false}) async {
  final order = store.openOrderFor(tableId);
  if (order == null || order.status != OrderStatus.served || (order.awaitingCustomerConfirmation && !ignoreCustomerConfirm)) {
    final parts = <String>[
      if (order == null || order.status != OrderStatus.served) context.l10n.cashierWaitingServed,
      if (order != null && order.awaitingCustomerConfirmation) context.l10n.cashierWaitingCustomerConfirm,
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parts.join('\n'))));
    return;
  }
  final host = context;
  final navigator = Navigator.of(context, rootNavigator: true);
  var applyService = store.serviceChargeRate > 0;
  // The customer picks how to pay at the table; the cashier only changes it when they pay differently.
  final customerChoice = order.paymentTypeId;
  String? chosenType = customerChoice ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id);
  var changing = false;
  var busy = false;
  String? failure;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final table = store.tableById(tableId);
          final order = store.openOrderFor(tableId);
          // Only what was sent to the kitchen is charged; unsent cart dishes
          // are cleared at settlement without being billed.
          final lines = <OrderLine>[...?order?.lines];
          final subtotal = store.tabSubtotal(tableId);
          final due = store.chargeTotal(subtotal, applyService: applyService);
          final minutes = order == null ? 0 : DateTime.now().difference(order.createdAt).inMinutes;
          return Dialog(
            backgroundColor: CafeColors.paper,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(context.l10n.cashierTableNumber(table.number), style: CafeTheme.display.copyWith(fontSize: 26))),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    if (table.status == TableStatus.billRequested)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0x1ABA5333), borderRadius: BorderRadius.circular(8)),
                        child: Text(context.l10n.cashierBillRequestedBadge, style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.4)),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${table.zone}  •  ${context.l10n.cashierDineIn}  •  ${context.l10n.cashierElapsedMinutes('$minutes')}',
                      style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Text(context.l10n.cashierOrderItemsCount('${lines.fold<int>(0, (sum, line) => sum + line.qty)}'), style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(context.l10n.cashierAmount, style: const TextStyle(fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: lines
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(8)),
                                      child: Text('${line.qty}×', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    Text(store.currency.format(line.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const Divider(),
                    _cashKv(context.l10n.cashierSubtotal, store.currency.format(subtotal)),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: applyService,
                      activeColor: CafeSurfaces.of(context).button,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.l10n.cashierApplyServiceCharge),
                      subtitle: Text(store.currency.format(store.serviceCharge(subtotal))),
                      onChanged: (value) => setState(() => applyService = value ?? false),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: CafeSurfaces.of(context).background, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(context.l10n.cashierAmount, style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.inkMuted)),
                          ),
                          Text(
                            store.currency.format(due),
                            style: CafeTheme.display.copyWith(fontSize: 28, fontWeight: FontWeight.w800, color: CafeSurfaces.of(context).header),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CustomerPaymentBox(
                      label: chosenType == null ? '—' : store.typeName(chosenType!),
                      note: customerChoice == null || chosenType == customerChoice
                          ? context.l10n.cashierChosenByCustomer
                          : context.l10n.cashierChangedByCashier(store.typeName(customerChoice)),
                      cash: chosenType != null && (store.typeName(chosenType!).toLowerCase().contains('cash') || store.typeName(chosenType!).contains('نقد')),
                      changing: changing,
                      onChange: busy ? null : () => setState(() => changing = !changing),
                    ),
                    if (changing) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in store.enabledPaymentTypes)
                            ChoiceChip(
                              label: Text(type.label(store.locale)),
                              selected: type.id == chosenType,
                              onSelected: (_) => setState(() {
                                chosenType = type.id;
                                changing = false;
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (failure != null) ...[
                      const SizedBox(height: 8),
                      Text(failure!, style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: busy
                            ? null
                            : () async {
                                setState(() => busy = true);
                                final orderId = store.openOrderFor(tableId)?.id;
                                final error = await store.settleCash(
                                  tableId: tableId,
                                  cashReceived: due,
                                  applyService: applyService,
                                  paymentTypeId: chosenType,
                                );
                                if (error != null) {
                                  if (error == 'session expired, sign in again') {
                                    navigator.pop();
                                    return;
                                  }
                                  failure = error;
                                  busy = false;
                                  if (context.mounted) setState(() {});
                                  return;
                                }
                                navigator.pop();
                                final payment = store.paymentForOrder(orderId);
                                if (!store.autoPrintReceipt || payment == null || !host.mounted) return;
                                unawaited(showReceiptPrint(store, payment, host.l10n).catchError((_) {
                                  if (!host.mounted) return;
                                  ScaffoldMessenger.of(host).showSnackBar(SnackBar(content: Text(host.l10n.receiptPrintFailed)));
                                }));
                              },
                        child: busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                [
                                  context.l10n.cashierConfirmPayment,
                                  store.currency.format(due),
                                  if (chosenType != null) store.typeName(chosenType!),
                                ].join('  ·  '),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
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
}

void _cashierUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.cashierActionUnavailable)));
}

Widget _cashKv(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

enum _FloorFilter { all, occupied, billDue, callStaff, available }


/// How the customer said they will pay, as picked on their phone. "Change" is only for when they
/// end up paying another way at the counter.
class _CustomerPaymentBox extends StatelessWidget {
  const _CustomerPaymentBox({
    required this.label,
    required this.note,
    required this.cash,
    required this.changing,
    required this.onChange,
  });

  final String label;
  final String note;
  final bool cash;
  final bool changing;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final button = CafeSurfaces.of(context).button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.cashierCustomerPayment.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: CafeColors.inkMuted),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(button.withValues(alpha: 0.07), CafeColors.paper),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: button, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: button, borderRadius: BorderRadius.circular(10)),
                child: Icon(cash ? Icons.payments_outlined : Icons.credit_card, color: CafeSurfaces.of(context).onButton),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CafeColors.ink)),
                    Text(note, style: const TextStyle(fontSize: 12, color: CafeColors.inkMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onChange,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: CafeColors.ink,
                  side: const BorderSide(color: Color(0xFFE3DED5), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(context.l10n.cashierChangeMethod, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
