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
                  calls.isEmpty ? null : context.l10n.cashierNeedsAttend,
                  Icons.notifications_none_outlined,
                  _AlertTone.call,
                  expand: !stacked,
                ),
                _stat(
                  context.l10n.cashierIncomingOrders,
                  context.l10n.cashierOrdersCount('${orders.length}'),
                  orders.any((order) => order.status == OrderStatus.received) ? context.l10n.cashierNeedsAccept : null,
                  Icons.receipt_outlined,
                  _AlertTone.order,
                  expand: !stacked,
                ),
                _stat(
                  context.l10n.cashierBillOutRequests,
                  context.l10n.cashierCheckoutsCount('${bills.length}'),
                  bills.isEmpty ? null : context.l10n.cashierDueNow,
                  Icons.payments_outlined,
                  _AlertTone.bill,
                  expand: !stacked,
                ),
              ];
              if (stacked) {
                return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: card)]);
              }
              return Row(children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 16), cards[i]]]);
            },
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: PanelTitle(context.l10n.cashierInstantAlerts, size: 18),
                ),
                FilterPill(label: context.l10n.cashierFilterAllAlerts('${calls.length + orders.length + bills.length}'), selected: filter == _AlertFilter.all, onTap: () => setState(() => filter = _AlertFilter.all)),
                FilterPill(label: context.l10n.cashierFilterCallStaff('${calls.length}'), selected: filter == _AlertFilter.calls, onTap: () => setState(() => filter = _AlertFilter.calls)),
                FilterPill(label: context.l10n.cashierFilterNewOrders('${orders.length}'), selected: filter == _AlertFilter.orders, onTap: () => setState(() => filter = _AlertFilter.orders)),
                FilterPill(label: context.l10n.cashierFilterBillRequests('${bills.length}'), selected: filter == _AlertFilter.bills, onTap: () => setState(() => filter = _AlertFilter.bills)),
                FilterPill(label: context.l10n.cashierReadyToServe, selected: filter == _AlertFilter.ready, onTap: () => setState(() => filter = _AlertFilter.ready)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 980;
                final alerts = ListView(
                    children: [
                      if (store.activeTables.isEmpty)
                        TawlaPanel(child: EmptyHint(context.l10n.noTables))
                      else if (orders.isEmpty && calls.isEmpty && bills.isEmpty)
                        TawlaPanel(child: EmptyHint(context.l10n.noOrders))
                      else ...[
                        if (filter == _AlertFilter.all || filter == _AlertFilter.bills)
                          ...bills.map((table) {
                            final order = store.openOrderFor(table.id);
                            final method = order?.paymentTypeId;
                            final arrived = store.openCalls.where((c) => c.kind == 'bill' && c.tableId == table.id).firstOrNull?.createdAt;
                            return _alert(
                              id: 'bill-${table.id}',
                              tone: _AlertTone.bill,
                              arrivedAt: arrived,
                              table: table.number,
                              badge: context.l10n.cashierBillRequest,
                              detail: order == null ? null : context.l10n.cashierOrderNumber(store.shiftTicket(order)),
                              body: order == null
                                  ? context.l10n.noOrders
                                  : method != null && method.isNotEmpty
                                      ? context.l10n.cashierCustomerPay(store.typeName(method))
                                      : context.l10n.cashierItemsCount('${order.itemCount}'),
                              time: arrived ?? order?.createdAt,
                              amount: store.tabTotal(table.id),
                              action: context.l10n.cashierSettleBill,
                              onTap: () => showCashSettleDialog(context, store, table.id),
                              onAction: () => showCashSettleDialog(context, store, table.id),
                            );
                          }),
                        if (filter == _AlertFilter.all || filter == _AlertFilter.calls)
                          ...calls.map(
                            (call) => _alert(
                              id: 'call-${call.id}',
                              tone: _AlertTone.call,
                              arrivedAt: call.createdAt,
                              table: call.tableNumber,
                              takeout: store.openOrderFor(call.tableId)?.serviceType == 'takeout',
                              badge: context.l10n.cashierCallStaff,
                              body: context.l10n.cashierAssistanceRequested,
                              time: call.createdAt,
                              action: context.l10n.cashierAttended,
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
                                tone: order.status == OrderStatus.ready ? _AlertTone.ready : _AlertTone.order,
                                table: order.tableNumber,
                                takeout: order.serviceType == 'takeout',
                                badge: order.status == OrderStatus.received
                                    ? context.l10n.cashierNewOrder
                                    : order.status == OrderStatus.ready
                                        ? context.l10n.cashierReadyToServe
                                        : _orderStatusLabel(context, order.status),
                                detail: [
                                  context.l10n.cashierOrderNumber(store.shiftTicket(order)),
                                  if (order.latestRound > 1) context.l10n.orderRound(order.latestRound),
                                ].join(' · '),
                                body: order.linesInRound(order.latestRound).map((line) => '${line.qty}× ${line.name}').join(', '),
                                time: order.createdAt,
                                amount: order.subtotal,
                                action: next == null ? null : _nextStatusAction(context, next),
                                selected: order.id == selected?.id,
                                onTap: () => setState(() => selectedOrderId = order.id),
                                onAction: next == null
                                    ? null
                                    : () async {
                                        setState(() => selectedOrderId = order.id);
                                        final error = await store.setOrderStatus(order.id, next);
                                        if (error == null || !context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
                                      },
                              );
                            },
                          ),
                      ],
                    ],
                );
                final side = TawlaPanel(
                  child: selected == null
                      ? EmptyHint(orders.isEmpty && bills.isEmpty ? context.l10n.noOrders : context.l10n.cashierTapOrderHint)
                      : _detail(context, store, selected),
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
                    const SizedBox(width: 16),
                    SizedBox(
                      width: (constraints.maxWidth * 0.34).clamp(280, 380),
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

  Widget _stat(String label, String value, String? badge, IconData icon, _AlertTone tone, {bool expand = true}) {
    final (_, soft, ink) = tone.colors;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F1B3A4B), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: ink, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: CafeColors.ink)),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)),
              child: Text(badge, style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
    return expand ? Expanded(child: card) : card;
  }

  Widget _alert({
    required Object id,
    required _AlertTone tone,
    DateTime? arrivedAt,
    required String table,
    bool takeout = false,
    required String badge,
    String? detail,
    required String body,
    DateTime? time,
    double? amount,
    String? action,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onAction,
  }) {
    final (strong, soft, ink) = tone.colors;
    final navy = CafeSurfaces.of(context).header;
    final store = context.read<CafeStore>();
    final fresh = arrivedAt != null && DateTime.now().difference(arrivedAt) < const Duration(minutes: 2);
    final tile = Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: strong, borderRadius: BorderRadius.circular(14)),
          child: takeout
              ? const Icon(Icons.work_outline, color: Colors.white, size: 24)
              : Text(
                  context.l10n.cashierTableShort(table),
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
        ),
        if (time != null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.cashierElapsedMinutes('${DateTime.now().difference(time).inMinutes}'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TawlaTokens.muted),
          ),
        ],
      ],
    );
    final header = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)),
          child: Center(
            widthFactor: 1,
            child: Text(badge.toUpperCase(), style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
        Text(takeout ? context.l10n.serviceTakeout : context.l10n.cashierTableNumber(table), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (detail != null && detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted)),
      ],
    );
    final hasFooter = amount != null || (action != null && onAction != null);
    return Padding(
      key: ValueKey(id),
      padding: const EdgeInsets.only(bottom: 10),
      child: _ArrivalFlash(
        arrivedAt: arrivedAt,
        child: Material(
          color: selected ? CafeColors.card : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: selected
                ? BorderSide(color: navy, width: 2)
                : fresh
                    ? BorderSide(color: strong, width: 2)
                    : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tile,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            header,
                            const SizedBox(height: 8),
                            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFF3E4A50))),
                          ],
                        ),
                      ),
                      if (tone != _AlertTone.call) const Icon(Icons.chevron_right, color: TawlaTokens.muted),
                    ],
                  ),
                  if (hasFooter)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 72, top: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: amount == null
                                ? const SizedBox.shrink()
                                : Text(store.currency.format(amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
                          ),
                          if (action != null && onAction != null)
                            SizedBox(
                              height: 44,
                              child: FilledButton(
                                onPressed: onAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: strong,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, CafeStore store, CafeOrder order) {
    final subtotal = store.tabSubtotal(order.tableId);
    final service = store.serviceCharge(subtotal);
    final total = store.tabTotal(order.tableId);
    // Takeout orders have no table.
    final waiting = store.tables.where((t) => t.id == order.tableId).firstOrNull?.status == TableStatus.billRequested;
    final method = order.paymentTypeId;
    final next = order.status.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _AlertTone.order.colors.$1, borderRadius: BorderRadius.circular(12)),
              child: order.serviceType == 'takeout'
                  ? const Icon(Icons.work_outline, color: Colors.white, size: 20)
                  : Text(context.l10n.cashierTableShort(order.tableNumber), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.serviceType == 'takeout' ? context.l10n.serviceTakeout : context.l10n.cashierTableNumber(order.tableNumber),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  Text(
                    [
                      context.l10n.cashierOrderNumber(store.shiftTicket(order)),
                      if (order.latestRound > 1) context.l10n.orderRound(order.latestRound),
                    ].join(' · '),
                    style: const TextStyle(color: TawlaTokens.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            StatusBadge(_orderStatusLabel(context, order.status), tone: BadgeTone.navy),
          ],
        ),
        if (waiting)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0x1ABA5333), borderRadius: BorderRadius.circular(8)),
              child: Text(context.l10n.cashierWaitingForBill, style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: CafeColors.line),
        const SizedBox(height: 14),
        EyebrowLabel(context.l10n.cashierOrderItemsCount('${order.itemCount}')),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(right: 4),
            children: _orderLineRows(context, store, order),
          ),
        ),
        const Divider(),
        _cashKv(context.l10n.cashierSubtotal, store.currency.format(subtotal)),
        _cashKv(context.l10n.cashierServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.currency.format(service)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(context.l10n.cashierTotalToCharge, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            Text(
              store.currency.format(total),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: -0.5, color: CafeSurfaces.of(context).header),
            ),
          ],
        ),
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
        if (next != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final error = await store.setOrderStatus(order.id, next);
                if (error == null || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
              },
              style: FilledButton.styleFrom(
                backgroundColor: (order.status == OrderStatus.ready ? _AlertTone.ready : _AlertTone.order).colors.$1,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_nextStatusAction(context, next), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => _cashierUnavailable(context),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: Text(context.l10n.cashierPrintReceipt),
          ),
        ),
      ],
    );
  }
}

/// Colour family of an alert: the strong tile colour, the soft badge background and the badge text.
enum _AlertTone {
  call,
  order,
  bill,
  ready;

  (Color, Color, Color) get colors => switch (this) {
        _AlertTone.call => (const Color(0xFFBA5333), const Color(0xFFFFE6DD), const Color(0xFF9A3C1D)),
        _AlertTone.order => (const Color(0xFF2F6F8F), const Color(0xFFE1EEF5), const Color(0xFF1F5873)),
        _AlertTone.bill => (const Color(0xFF95600F), const Color(0xFFFBEFD8), const Color(0xFF7A4E0C)),
        _AlertTone.ready => (const Color(0xFF4F7A45), const Color(0xFFE4EEDF), const Color(0xFF2F5228)),
      };
}
