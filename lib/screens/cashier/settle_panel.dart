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
  final controller = TextEditingController();
  final navigator = Navigator.of(context, rootNavigator: true);
  var applyService = store.serviceChargeRate > 0;
  String? failure;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final table = store.tableById(tableId);
          final order = store.openOrderFor(tableId);
          final lines = <OrderLine>[
            ...?order?.lines,
            ...store.cartFor(tableId).lines,
          ];
          final subtotal = store.tabSubtotal(tableId);
          final due = store.chargeTotal(subtotal, applyService: applyService);
          final received = double.tryParse(controller.text) ?? 0;
          final change = received - due;
          final minutes = order == null ? 0 : DateTime.now().difference(order.createdAt).inMinutes;
          return Dialog(
            backgroundColor: CafeColors.paper,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
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
                    _cashKv(context.l10n.cashierTotalPayable, store.currency.format(due)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: context.l10n.cashierCashReceived),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _cashKv(context.l10n.cashierChangeDue, change < 0 ? context.l10n.insufficientCash : store.currency.format(change)),
                    if (failure != null) ...[
                      const SizedBox(height: 8),
                      Text(failure!, style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(onPressed: () => navigator.pop(), child: Text(context.l10n.commonCancel)),
                        const Spacer(),
                        TerracottaButton(
                          expanded: false,
                          label: context.l10n.cashierSettleCloseBill(store.currency.format(due)),
                          onPressed: () async {
                            final error = await store.settleCash(
                              tableId: tableId,
                              cashReceived: received,
                              applyService: applyService,
                            );
                            if (error != null) {
                              if (error == 'session expired, sign in again') {
                                navigator.pop();
                                return;
                              }
                              failure = error;
                              if (context.mounted) setState(() {});
                              return;
                            }
                            navigator.pop();
                          },
                        ),
                      ],
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
  controller.dispose();
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

