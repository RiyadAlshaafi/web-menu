part of '../cashier_screens.dart';

class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  _AlertFilter filter = _AlertFilter.all;
  String? selectedOrderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final orders = store.liveOrders();
    final calls = store.openCalls.where((call) => call.kind != 'bill').toList();
    final bills = store.billTables;
    CafeOrder? selected = orders.where((order) => order.id == selectedOrderId).firstOrNull;
    selected ??= bills.isEmpty ? null : store.openOrderFor(bills.first.id);
    selected ??= orders.isEmpty ? null : orders.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final cards = [
                _stat(
                  context.l10n.cashierAssistanceCalls,
                  context.l10n.cashierCallsCount('${calls.length}'),
                  calls.isEmpty ? context.l10n.noCalls : calls.map((call) => context.l10n.cashierTableShort(call.tableNumber)).join(' • '),
                  Icons.notifications_active_outlined,
                  expand: !stacked,
                ),
                _stat(
                  context.l10n.cashierIncomingOrders,
                  context.l10n.cashierOrdersCount('${orders.length}'),
                  orders.isEmpty ? context.l10n.noOrders : orders.map((order) => context.l10n.cashierTableShort(order.tableNumber)).join(' • '),
                  Icons.restaurant_outlined,
                  expand: !stacked,
                ),
                _stat(
                  context.l10n.cashierBillOutRequests,
                  context.l10n.cashierCheckoutsCount('${bills.length}'),
                  bills.isEmpty
                      ? context.l10n.noBills
                      : bills.map((table) => '${context.l10n.cashierTableShort(table.number)} ${store.currency.format(store.tabTotal(table.id))}').join(' • '),
                  Icons.receipt_long_outlined,
                  expand: !stacked,
                ),
              ];
              if (stacked) {
                return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card)]);
              }
              return Row(children: cards);
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(context.l10n.cashierFilterAllAlerts('${calls.length + orders.length + bills.length}'), filter == _AlertFilter.all, () => setState(() => filter = _AlertFilter.all)),
              _chip(context.l10n.cashierFilterCallStaff('${calls.length}'), filter == _AlertFilter.calls, () => setState(() => filter = _AlertFilter.calls)),
              _chip(context.l10n.cashierFilterNewOrders('${orders.length}'), filter == _AlertFilter.orders, () => setState(() => filter = _AlertFilter.orders)),
              _chip(context.l10n.cashierFilterBillRequests('${bills.length}'), filter == _AlertFilter.bills, () => setState(() => filter = _AlertFilter.bills)),
              _chip(context.l10n.cashierReadyToServe, filter == _AlertFilter.ready, () => setState(() => filter = _AlertFilter.ready)),
              Text(context.l10n.cashierInstantAlerts, style: const TextStyle(color: CafeColors.inkMuted, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 980;
                final alerts = ListView(
                    children: [
                      if (store.activeTables.isEmpty)
                        SoftCard(radius: 16, child: EmptyHint(context.l10n.noTables))
                      else if (orders.isEmpty && calls.isEmpty && bills.isEmpty)
                        SoftCard(radius: 16, child: EmptyHint(context.l10n.noOrders))
                      else ...[
                        if (filter == _AlertFilter.all || filter == _AlertFilter.bills)
                          ...bills.map((table) {
                            final order = store.openOrderFor(table.id);
                            return _alert(
                              id: 'bill-${table.id}',
                              arrivedAt: store.openCalls.where((c) => c.kind == 'bill' && c.tableId == table.id).firstOrNull?.createdAt,
                              table: table.number,
                              title: context.l10n.cashierBillRequest,
                              body: order == null ? context.l10n.noOrders : context.l10n.cashierItemsCount('${order.itemCount}'),
                              time: order?.createdAt,
                              amount: store.tabTotal(table.id),
                              action: context.l10n.cashierSettleBill,
                              icon: Icons.payments_outlined,
                              onTap: () => showCashSettleDialog(context, store, table.id),
                              onAction: () => showCashSettleDialog(context, store, table.id),
                            );
                          }),
                        if (filter == _AlertFilter.all || filter == _AlertFilter.calls)
                          ...calls.map(
                            (call) => _alert(
                              id: 'call-${call.id}',
                              arrivedAt: call.createdAt,
                              table: store.openOrderFor(call.tableId)?.serviceType == 'takeout'
                                  ? context.l10n.serviceTakeout
                                  : call.tableNumber,
                              title: context.l10n.cashierCallStaff,
                              body: context.l10n.cashierAssistanceRequested,
                              time: call.createdAt,
                              action: context.l10n.cashierAttended,
                              icon: Icons.done,
                              onTap: () => store.resolveCall(call.id),
                              onAction: () => store.resolveCall(call.id),
                            ),
                          ),
                        if (filter == _AlertFilter.all || filter == _AlertFilter.orders || filter == _AlertFilter.ready)
                          ...orders.where((order) => filter != _AlertFilter.ready || order.status == OrderStatus.ready).map(
                            (order) {
                              final next = order.status.next;
                              return _alert(
                                id: 'order-${order.id}',
                                table: order.serviceType == 'takeout' ? context.l10n.serviceTakeout : order.tableNumber,
                                title: context.l10n.cashierOrderNumber(store.shiftTicket(order)),
                                body: [
                                  _orderStatusLabel(context, order.status),
                                  if (order.latestRound > 1) context.l10n.orderRound(order.latestRound),
                                  order.linesInRound(order.latestRound).map((line) => '${line.qty}× ${line.name}').join(', '),
                                ].join(' · '),
                                time: order.createdAt,
                                amount: order.subtotal,
                                action: next == null ? null : _nextStatusAction(context, next),
                                icon: Icons.room_service_outlined,
                                onTap: () => setState(() => selectedOrderId = order.id),
                                onAction: next == null
                                    ? null
                                    : () {
                                        store.setOrderStatus(order.id, next);
                                        setState(() => selectedOrderId = order.id);
                                      },
                              );
                            },
                          ),
                      ],
                    ],
                );
                final side = Column(
                  children: [
                    Expanded(
                      child: SoftCard(
                        radius: 16,
                        child: selected == null ? EmptyHint(context.l10n.noOrders) : _detail(context, store, selected),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(context.l10n.cashierQuickTableStatus('${store.diningTables.length}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.4))),
                              Text(
                                context.l10n.cashierActiveTables(
                                  '${store.diningTables.where((table) => table.status != TableStatus.free).length}',
                                  '${store.diningTables.length}',
                                ),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CafeColors.inkMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (store.diningTables.isEmpty)
                            EmptyHint(context.l10n.noTables)
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: store.diningTables.map((table) {
                                final due = store.tabTotal(table.id);
                                final bill = table.status == TableStatus.billRequested;
                                final calling = store.openCalls.any((call) => call.tableId == table.id);
                                final label = table.status == TableStatus.free
                                    ? context.l10n.cashierFree
                                    : calling
                                        ? context.l10n.cashierCall
                                        : bill
                                            ? '${context.l10n.cashierBillRequest} ${store.currency.format(due)}'
                                            : store.currency.format(due);
                                return SizedBox(
                                  width: 78,
                                  child: SoftCard(
                                    radius: 12,
                                    padding: const EdgeInsets.all(8),
                                    selected: bill || calling || table.status != TableStatus.free,
                                    onTap: () => context.go('/pos/tables'),
                                    child: Column(
                                      children: [
                                        Text(context.l10n.cashierTableShort(table.number), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                        Text(
                                          label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 10, color: table.status == TableStatus.free ? CafeColors.success : CafeColors.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
                if (stack) {
                  return Column(
                    children: [
                      Expanded(flex: 3, child: alerts),
                      const SizedBox(height: 12),
                      SizedBox(height: (constraints.maxHeight * 0.42).clamp(220, 360), child: side),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: alerts),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: (constraints.maxWidth * 0.34).clamp(260, 360),
                      child: side,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _orderStatusLabel(BuildContext context, OrderStatus status) {
    return switch (status) {
      OrderStatus.received => context.l10n.guestStatusReceived,
      OrderStatus.preparing => context.l10n.guestStatusPreparing,
      OrderStatus.ready => context.l10n.guestStatusReady,
      OrderStatus.served => context.l10n.guestStatusServed,
      OrderStatus.paid => context.l10n.guestPaid,
    };
  }

  String _nextStatusAction(BuildContext context, OrderStatus next) {
    return switch (next) {
      OrderStatus.preparing => context.l10n.cashierAcceptOrder,
      OrderStatus.ready => context.l10n.cashierReadyToServe,
      OrderStatus.served => context.l10n.cashierMarkServed,
      OrderStatus.received || OrderStatus.paid => context.l10n.cashierAcceptOrder,
    };
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? CafeSurfaces.of(context).button : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? CafeSurfaces.of(context).button : CafeColors.line),
          ),
          child: Text(label, style: TextStyle(color: selected ? CafeSurfaces.of(context).onButton : CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, String detail, IconData icon, {bool expand = true}) {
    final card = Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SoftCard(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: CafeColors.inkMuted, fontWeight: FontWeight.w700))),
                Icon(icon, size: 18, color: CafeColors.terracotta),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: CafeTheme.display.copyWith(fontSize: 26)),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
          ],
        ),
      ),
    );
    return expand ? Expanded(child: card) : card;
  }

  Widget _alert({
    required Object id,
    DateTime? arrivedAt,
    required String table,
    required String title,
    required String body,
    required IconData icon,
    DateTime? time,
    double? amount,
    String? action,
    required VoidCallback onTap,
    VoidCallback? onAction,
  }) {
    return Padding(
      key: ValueKey(id),
      padding: const EdgeInsets.only(bottom: 8),
      child: _ArrivalFlash(
        arrivedAt: arrivedAt,
        child: SoftCard(
          radius: 16,
          padding: const EdgeInsets.all(12),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: CafeColors.terracotta, borderRadius: BorderRadius.circular(8)),
                child: Text(context.l10n.cashierTableNumber(table), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time == null ? title : '$title • ${context.l10n.cashierElapsedMinutes('${DateTime.now().difference(time).inMinutes}')}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (amount != null) MoneyText(context.read<CafeStore>().currency.format(amount)),
              if (action != null && onAction != null) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(icon, size: 16),
                  label: Text(action),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, CafeStore store, CafeOrder order) {
    final subtotal = store.tabSubtotal(order.tableId);
    final service = store.serviceCharge(subtotal);
    final total = store.tabTotal(order.tableId);
    final waiting = store.tableById(order.tableId).status == TableStatus.billRequested;
    final method = order.paymentTypeId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            order.serviceType == 'takeout'
                ? '${context.l10n.serviceTakeout}  ${context.l10n.cashierOrderNumber(store.shiftTicket(order))}'
                : '${context.l10n.cashierTableNumber(order.tableNumber)}  ${context.l10n.cashierOrderNumber(store.shiftTicket(order))}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        Text(_orderStatusLabel(context, order.status), style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        if (waiting)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x1ABA5333), borderRadius: BorderRadius.circular(8)),
              child: Text(context.l10n.cashierWaitingForBill, style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ),
        const SizedBox(height: 12),
        Text(context.l10n.cashierItemsToSettle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(right: 4),
            children: _orderLineRows(context, store, order),
          ),
        ),
        const Divider(),
        _cashKv(context.l10n.cashierSubtotal, store.currency.format(subtotal)),
        _cashKv(context.l10n.cashierServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.currency.format(service)),
        _cashKv(context.l10n.cashierTotalToCharge, store.currency.format(total)),
        if (method != null && method.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.l10n.cashierCustomerPay(store.typeName(method)),
              style: const TextStyle(color: CafeColors.inkMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        const SizedBox(height: 12),
        if (order.status != OrderStatus.served)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.l10n.cashierWaitingServed, style: TextStyle(color: CafeSurfaces.of(context).button, fontWeight: FontWeight.w700)),
          ),
        if (order.awaitingCustomerConfirmation)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.l10n.cashierWaitingCustomerConfirm, style: TextStyle(color: CafeSurfaces.of(context).button, fontWeight: FontWeight.w700)),
          ),
        if (order.awaitingCustomerConfirmation)
          TextButton(
            onPressed: () async {
              final served = order.status == OrderStatus.served;
              final ok = await showCafeConfirmDialog(
                context,
                title: context.l10n.cashierSettleAnyway,
                message: served ? context.l10n.cashierSettleAnywayMessage : context.l10n.cashierSettleAnywayNotServed,
                confirm: context.l10n.cashierSettleAnyway,
              );
              if (ok && served && context.mounted) showCashSettleDialog(context, store, order.tableId, ignoreCustomerConfirm: true);
            },
            child: Text(context.l10n.cashierSettleAnyway),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cashierUnavailable(context),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(context.l10n.cashierPrintReceipt),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cashierUnavailable(context),
                icon: const Icon(Icons.call_split, size: 16),
                label: Text(context.l10n.cashierSplitBill),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

