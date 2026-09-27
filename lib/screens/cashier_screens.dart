import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../navigation/app_sections.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final arabic = store.locale == 'ar';
    return PopupMenuButton<String>(
      tooltip: context.l10n.cashierLanguage,
      onSelected: (code) => store.setLocale(code),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: 'en', checked: !arabic, child: const Text('English')),
        CheckedPopupMenuItem(value: 'ar', checked: arabic, child: const Text('العربية')),
      ],
      child: IgnorePointer(
        child: GhostChip(label: arabic ? 'العربية' : 'EN', icon: Icons.language, onTap: () {}),
      ),
    );
  }
}

class CashierShell extends StatelessWidget {
  const CashierShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final staff = store.currentCashier;
    final occupied = store.tables.where((table) => table.status != TableStatus.free).length;
    final sales = store.currentShift?.cashSales ?? store.openShift?.cashSales ?? 0;
    final section = AppSections.forCashier(location);
    final compact = AppSections.compact(MediaQuery.sizeOf(context).width);
    final railWidth = compact ? 84.0 : 250.0;

    return Scaffold(
      backgroundColor: CafeColors.cream,
      body: Row(
        children: [
          Material(
            color: Colors.white,
            child: SizedBox(
              width: railWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: CafeColors.terracotta, borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Icon(section.icon, color: Colors.white, size: 20),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 8),
                          Expanded(child: CafeLogo(size: 0, showWordmark: true, compact: true, subtitle: context.l10n.cashierPosTerminal)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0E4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 8, color: CafeColors.success),
                          const SizedBox(width: 6),
                          Text(context.l10n.cashierSoloShiftLive, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F7A45))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(context.l10n.cashierAllInOne, style: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: CafeColors.inkMuted)),
                    const SizedBox(height: 10),
                    _nav(
                      context,
                      AppSections.cashier[0],
                      location == '/pos',
                      compact,
                      badge: '${store.openCalls.length + store.liveOrders().length}',
                    ),
                    _nav(
                      context,
                      AppSections.cashier[1],
                      location.startsWith('/pos/tables'),
                      compact,
                      badge: store.tables.isEmpty ? null : '$occupied/${store.tables.length}',
                    ),
                    _nav(
                      context,
                      AppSections.cashier[2],
                      location.startsWith('/pos/shifts'),
                      compact,
                      badge: sales == 0 ? null : store.currency.format(sales),
                    ),
                    const Spacer(),
                    SoftCard(
                      padding: const EdgeInsets.all(10),
                      radius: 16,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: CafeColors.terracottaSoft,
                            child: Text(staff?.initials ?? 'C', style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staff?.name ?? context.l10n.cashierRole, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(context.l10n.cashierSoloCashier, style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              store.signOut();
                              context.go('/login');
                            },
                            icon: const Icon(Icons.logout, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, AppSection section, bool active, bool compact, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        selected: active,
        selectedTileColor: CafeColors.terracotta,
        selectedColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(section.icon),
        title: compact ? null : Text(section.label(context), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        trailing: badge == null
            ? null
            : Text(badge, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: active ? Colors.white : CafeColors.inkMuted)),
        onTap: () => context.go(section.path),
      ),
    );
  }
}

enum _AlertFilter { all, calls, orders, bills, ready }

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
    final clock = DateFormat('HH:mm:ss').format(DateTime.now());
    CafeOrder? selected = orders.where((order) => order.id == selectedOrderId).firstOrNull;
    selected ??= bills.isEmpty ? null : store.openOrderFor(bills.first.id);
    selected ??= orders.isEmpty ? null : orders.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: CafeColors.success),
              const SizedBox(width: 8),
              Text(context.l10n.cashierStationFrontCounter, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width, min: 18, max: 22))),
              const Spacer(),
              GhostChip(label: clock, icon: Icons.schedule),
              const SizedBox(width: 8),
              const LanguageButton(),
              const SizedBox(width: 8),
              GhostChip(label: context.l10n.cashierAudioOn, icon: Icons.volume_up_outlined),
            ],
          ),
          const SizedBox(height: 16),
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
                      if (store.tables.isEmpty)
                        SoftCard(radius: 16, child: EmptyHint(context.l10n.noTables))
                      else if (orders.isEmpty && calls.isEmpty && bills.isEmpty)
                        SoftCard(radius: 16, child: EmptyHint(context.l10n.noOrders))
                      else ...[
                        if (filter == _AlertFilter.all || filter == _AlertFilter.bills)
                          ...bills.map((table) {
                            final order = store.openOrderFor(table.id);
                            return _alert(
                              table: table.number,
                              title: context.l10n.cashierBillRequest,
                              body: order == null ? context.l10n.noOrders : context.l10n.cashierItemsCount('${order.itemCount}'),
                              time: order?.createdAt,
                              amount: store.tabTotal(table.id),
                              action: context.l10n.cashierSettleBill,
                              icon: Icons.payments_outlined,
                              onTap: () => showCashSettleDialog(context, store, table.id),
                            );
                          }),
                        if (filter == _AlertFilter.all || filter == _AlertFilter.calls)
                          ...calls.map(
                            (call) => _alert(
                              table: call.tableNumber,
                              title: context.l10n.cashierCallStaff,
                              body: context.l10n.cashierAssistanceRequested,
                              time: call.createdAt,
                              action: context.l10n.cashierAttended,
                              icon: Icons.done,
                              onTap: () => store.resolveCall(call.id),
                            ),
                          ),
                        if (filter == _AlertFilter.all || filter == _AlertFilter.orders || filter == _AlertFilter.ready)
                          ...orders.where((order) => filter != _AlertFilter.ready || order.status == OrderStatus.ready).map(
                            (order) => _alert(
                              table: order.tableNumber,
                              title: context.l10n.cashierNewOrder,
                              body: order.lines.map((line) => '${line.qty}× ${line.name}').join(', '),
                              time: order.createdAt,
                              amount: order.subtotal,
                              action: context.l10n.cashierReadyToServe,
                              icon: Icons.room_service_outlined,
                              onTap: () {
                                store.setOrderStatus(order.id, OrderStatus.ready);
                                setState(() => selectedOrderId = order.id);
                              },
                            ),
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
                              Expanded(child: Text(context.l10n.cashierQuickTableStatus('${store.tables.length}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.4))),
                              Text(
                                context.l10n.cashierActiveTables(
                                  '${store.tables.where((table) => table.status != TableStatus.free).length}',
                                  '${store.tables.length}',
                                ),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CafeColors.inkMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (store.tables.isEmpty)
                            EmptyHint(context.l10n.noTables)
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: store.tables.map((table) {
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

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? CafeColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? CafeColors.ink : CafeColors.line),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
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
    required String table,
    required String title,
    required String body,
    required String action,
    required IconData icon,
    DateTime? time,
    double? amount,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(action),
              style: FilledButton.styleFrom(
                backgroundColor: CafeColors.terracotta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, CafeStore store, CafeOrder order) {
    final subtotal = store.tabSubtotal(order.tableId);
    final service = store.serviceCharge(subtotal);
    final total = store.tabTotal(order.tableId);
    final waiting = store.tableById(order.tableId).status == TableStatus.billRequested;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${context.l10n.cashierTableNumber(order.tableNumber)}  ${context.l10n.cashierOrderNumber(order.id)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
        ...order.lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text('${line.qty}×  ${line.name}'),
                const Spacer(),
                Text(store.currency.format(line.total)),
              ],
            ),
          ),
        ),
        const Divider(),
        _cashKv(context.l10n.cashierSubtotal, store.currency.format(subtotal)),
        _cashKv(context.l10n.cashierServiceCharge('${(store.serviceChargeRate * 100).round()}'), store.currency.format(service)),
        _cashKv(context.l10n.cashierTotalToCharge, store.currency.format(total)),
        const SizedBox(height: 12),
        TerracottaButton(
          label: context.l10n.cashierSettleCloseBill(store.currency.format(total)),
          onPressed: () => showCashSettleDialog(context, store, order.tableId),
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

Future<void> showCashSettleDialog(BuildContext context, CafeStore store, String tableId) async {
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
                      activeColor: CafeColors.terracotta,
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
  return Row(
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

enum _FloorFilter { all, occupied, billDue, callStaff, available }

class CashierFloorScreen extends StatefulWidget {
  const CashierFloorScreen({super.key});

  @override
  State<CashierFloorScreen> createState() => _CashierFloorScreenState();
}

class _CashierFloorScreenState extends State<CashierFloorScreen> {
  _FloorFilter filter = _FloorFilter.all;
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final callIds = store.openCalls.map((call) => call.tableId).toSet();
    final tables = store.tables.where((table) {
      switch (filter) {
        case _FloorFilter.all:
          return true;
        case _FloorFilter.occupied:
          return table.status != TableStatus.free;
        case _FloorFilter.billDue:
          return table.status == TableStatus.billRequested;
        case _FloorFilter.callStaff:
          return callIds.contains(table.id);
        case _FloorFilter.available:
          return table.status == TableStatus.free;
      }
    }).toList();
    selectedId ??= tables.isEmpty ? null : tables.first.id;
    final selected = store.tables.where((table) => table.id == selectedId);
    final table = selected.isEmpty ? null : selected.first;
    final order = table == null ? null : store.openOrderFor(table.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.cashierFloorManagement, style: const TextStyle(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.cashierFloorOverviewTitle, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width))),
              Text(context.l10n.cashierTablesCount('${store.tables.length}'), style: const TextStyle(fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
              GhostChip(label: DateFormat('HH:mm:ss').format(DateTime.now()), icon: Icons.schedule),
              const LanguageButton(),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _floorChip(context.l10n.cashierFloorAll('${store.tables.length}'), filter == _FloorFilter.all, () => setState(() => filter = _FloorFilter.all)),
              _floorChip(context.l10n.cashierFloorOccupied('${store.tables.where((item) => item.status != TableStatus.free).length}'), filter == _FloorFilter.occupied, () => setState(() => filter = _FloorFilter.occupied)),
              _floorChip(context.l10n.cashierFloorBillDue('${store.billTables.length}'), filter == _FloorFilter.billDue, () => setState(() => filter = _FloorFilter.billDue)),
              _floorChip(context.l10n.cashierFilterCallStaff('${store.openCalls.length}'), filter == _FloorFilter.callStaff, () => setState(() => filter = _FloorFilter.callStaff)),
              _floorChip(context.l10n.cashierFloorAvailable('${store.tables.where((item) => item.status == TableStatus.free).length}'), filter == _FloorFilter.available, () => setState(() => filter = _FloorFilter.available)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: store.tables.isEmpty
                ? SoftCard(radius: 16, child: EmptyHint(context.l10n.noTables))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 980;
                      final grid = GridView.count(
                        crossAxisCount: AppSections.columnsFor(constraints.maxWidth, max: 3),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.35,
                        children: tables.map((item) {
                            final due = store.tabTotal(item.id);
                            final calling = callIds.contains(item.id);
                            final statusLabel = item.status == TableStatus.free
                                ? context.l10n.cashierStatusCleanReady
                                : item.status == TableStatus.billRequested
                                    ? context.l10n.cashierStatusBillRequested
                                    : calling
                                        ? context.l10n.cashierStatusStaffCall
                                        : context.l10n.cashierStatusDining;
                            return SoftCard(
                              radius: 16,
                              selected: item.id == selectedId,
                              onTap: () {
                                setState(() => selectedId = item.id);
                                if (item.status == TableStatus.billRequested) {
                                  showCashSettleDialog(context, store, item.id);
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(context.l10n.cashierTableNumber(item.number), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      const Spacer(),
                                      Text(statusLabel, style: TextStyle(fontSize: 11, color: item.status == TableStatus.free ? CafeColors.success : CafeColors.terracottaDark, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  Text(item.status == TableStatus.free ? context.l10n.cashierAvailable : context.l10n.cashierDiningActive, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
                                  const Spacer(),
                                  MoneyText(store.currency.format(due)),
                                ],
                              ),
                            );
                          }).toList(),
                      );
                      final inspector = SizedBox(
                        width: stack ? double.infinity : (constraints.maxWidth * 0.32).clamp(260, 340),
                        height: stack ? 280 : null,
                        child: SoftCard(
                          radius: 16,
                          child: table == null
                              ? EmptyHint(context.l10n.noTables)
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.l10n.cashierTableNumber(table.number), style: CafeTheme.display.copyWith(fontSize: 24)),
                                    Text(
                                      switch (table.status) {
                                        TableStatus.free => context.l10n.cashierFree,
                                        TableStatus.dining => context.l10n.cashierStatusDining,
                                        TableStatus.billRequested => context.l10n.cashierBillPending,
                                      },
                                      style: const TextStyle(color: CafeColors.inkMuted)),
                                    const SizedBox(height: 12),
                                    if (order == null)
                                      EmptyHint(context.l10n.noOrders)
                                    else ...[
                                      ...order.lines.map(
                                        (line) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              Text('${line.qty}×  ${line.name}'),
                                              const Spacer(),
                                              Text(store.currency.format(line.total)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Divider(),
                                      Row(
                                        children: [
                                          Text(context.l10n.cashierTotalPayable, style: const TextStyle(fontWeight: FontWeight.w800)),
                                          const Spacer(),
                                          MoneyText(store.currency.format(store.tabTotal(table.id))),
                                        ],
                                      ),
                                    ],
                                    const Spacer(),
                                    TerracottaButton(
                                      label: context.l10n.cashierSettleCloseBill(store.currency.format(store.tabTotal(table.id))),
                                      onPressed: table.status == TableStatus.billRequested || (order != null)
                                          ? () => showCashSettleDialog(context, store, table.id)
                                          : null,
                                    ),
                                  ],
                                ),
                        ),
                      );
                      if (stack) {
                        return Column(
                          children: [
                            Expanded(child: grid),
                            const SizedBox(height: 12),
                            inspector,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: grid),
                          const SizedBox(width: 12),
                          inspector,
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _floorChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? CafeColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? CafeColors.ink : CafeColors.line),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }
}

class CashierShiftsScreen extends StatefulWidget {
  const CashierShiftsScreen({super.key});

  @override
  State<CashierShiftsScreen> createState() => _CashierShiftsScreenState();
}

class _CashierShiftsScreenState extends State<CashierShiftsScreen> {
  final counted = TextEditingController();

  @override
  void dispose() {
    counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final shift = store.currentShift ?? store.openShift;
    final sales = shift?.cashSales ?? 0;
    final txs = shift?.transactionCount ?? 0;
    final pending = store.billTables.fold<double>(0, (sum, table) => sum + store.tabTotal(table.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.cashierSoloStationSync, style: const TextStyle(letterSpacing: 0.8, fontSize: 11, fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.cashierShiftSalesTitle, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width))),
              GhostChip(label: DateFormat('HH:mm:ss').format(DateTime.now()), icon: Icons.schedule),
              const LanguageButton(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sim_card_download_outlined, size: 16),
                label: Text(context.l10n.cashierExportSummary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final cards = [
                _mini(context.l10n.cashierTotalShiftGrossSales, store.currency.format(sales), expand: !stacked),
                _mini(
                  context.l10n.cashierSettledOrders,
                  '$txs',
                  detail: txs == 0 ? null : context.l10n.cashierAvgTicket(store.currency.format(sales / txs)),
                  expand: !stacked,
                ),
                _mini(
                  context.l10n.cashierActivePendingBalance,
                  store.currency.format(pending),
                  detail: store.billTables.isEmpty
                      ? null
                      : store.billTables.map((table) => '${context.l10n.cashierTableShort(table.number)} ${store.currency.format(store.tabTotal(table.id))}').join(' • '),
                  expand: !stacked,
                ),
              ];
              if (stacked) {
                return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card)]);
              }
              return Row(children: cards);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 980;
                final ledger = SoftCard(
                    radius: 16,
                    child: store.payments.isEmpty
                        ? EmptyHint(context.l10n.noTransactions)
                        : ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(context.l10n.cashierColOrderTable, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 64, child: Text(context.l10n.cashierColTime, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 80, child: Text(context.l10n.cashierColAmount, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 72, child: Text(context.l10n.cashierColStatus, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 88, child: Text(context.l10n.cashierColActions, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                  ],
                                ),
                              ),
                              ...store.payments.map((payment) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '#${payment.orderId}  •  ${context.l10n.cashierTableShort(store.tableById(payment.tableId).number)}',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      SizedBox(width: 64, child: Text(DateFormat.Hm().format(payment.paidAt))),
                                      SizedBox(
                                        width: 80,
                                        child: Text(store.currency.format(payment.totalDue), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Text(context.l10n.cashierSettled, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: CafeColors.success)),
                                      ),
                                      SizedBox(
                                        width: 88,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () => _cashierUnavailable(context),
                                            icon: const Icon(Icons.print_outlined, size: 14),
                                            label: Text(context.l10n.cashierPrintChit, style: const TextStyle(fontSize: 11)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                );
                final till = SoftCard(
                    radius: 16,
                    child: shift == null
                        ? EmptyHint(context.l10n.errNoOpenShift)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(color: Color(0x1ABA5333), borderRadius: BorderRadius.all(Radius.circular(8))),
                                    child: const Icon(Icons.account_balance_wallet_outlined, color: CafeColors.terracotta, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(context.l10n.cashierTillBalance, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                                    child: Text(context.l10n.cashierActive, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: context.l10n.cashierOpeningFloat,
                                  hintText: store.currency.format(shift.openingCash),
                                ),
                                onSubmitted: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null) store.setOpeningCash(parsed);
                                },
                              ),
                              const SizedBox(height: 10),
                              _row(context.l10n.cashierOpeningFloatRow, store.currency.format(shift.openingCash)),
                              _row(context.l10n.cashierCashCollected, store.currency.format(shift.cashSales)),
                              _row(context.l10n.cashierCardDigitalPayments, store.currency.format(0)),
                              const Divider(),
                              _row(context.l10n.cashierExpectedInDrawer, store.currency.format(shift.expectedCash), strong: true),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(12), border: Border.all(color: CafeColors.line)),
                                child: Text(
                                  context.l10n.cashierToleranceNote,
                                  style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted, height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: counted,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: context.l10n.cashierActualCashCounted),
                              ),
                              const SizedBox(height: 10),
                              TerracottaButton(
                                label: context.l10n.cashierCloseRegister,
                                onPressed: () async {
                                  final actual = double.tryParse(counted.text) ?? 0;
                                  await store.closeShift(actualCash: actual);
                                  if (context.mounted) {
                                    final diff = actual - shift.expectedCash;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(context.l10n.cashierDifference(store.currency.format(diff)))),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  child: Text(context.l10n.cashierMidShiftChit),
                                ),
                              ),
                            ],
                          ),
                );
                if (stack) {
                  return Column(
                    children: [
                      Expanded(child: ledger),
                      const SizedBox(height: 12),
                      SizedBox(height: (constraints.maxHeight * 0.52).clamp(280, 420), child: till),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: ledger),
                    const SizedBox(width: 12),
                    SizedBox(width: (constraints.maxWidth * 0.34).clamp(260, 360), child: till),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, {String? detail, bool expand = true}) {
    final card = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SoftCard(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
            Text(value, style: CafeTheme.display.copyWith(fontSize: 24)),
            if (detail != null) Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
          ],
        ),
      ),
    );
    return expand ? Expanded(child: card) : card;
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: strong ? CafeColors.ink : CafeColors.inkMuted, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: strong ? 18 : 13,
              color: strong ? CafeColors.terracotta : CafeColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
