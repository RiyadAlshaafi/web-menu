part of '../cashier_screens.dart';

class CashierFloorScreen extends StatefulWidget {
  const CashierFloorScreen({super.key});

  @override
  State<CashierFloorScreen> createState() => _CashierFloorScreenState();
}

class _CashierFloorScreenState extends State<CashierFloorScreen> {
  _FloorFilter filter = _FloorFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final dining = store.diningTables;
    final callIds = store.openCalls.map((call) => call.tableId).toSet();
    final occupied = dining.where((item) => item.status != TableStatus.free).length;
    final tables = dining.where((table) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterPill(label: context.l10n.cashierFloorAll('${dining.length}'), selected: filter == _FloorFilter.all, onTap: () => setState(() => filter = _FloorFilter.all)),
                    FilterPill(label: context.l10n.cashierFloorOccupied('$occupied'), selected: filter == _FloorFilter.occupied, onTap: () => setState(() => filter = _FloorFilter.occupied)),
                    FilterPill(label: context.l10n.cashierFloorBillDue('${store.billTables.length}'), selected: filter == _FloorFilter.billDue, onTap: () => setState(() => filter = _FloorFilter.billDue)),
                    FilterPill(label: context.l10n.cashierFilterCallStaff('${store.openCalls.length}'), selected: filter == _FloorFilter.callStaff, onTap: () => setState(() => filter = _FloorFilter.callStaff)),
                    FilterPill(label: context.l10n.cashierFloorAvailable('${dining.length - occupied}'), selected: filter == _FloorFilter.available, onTap: () => setState(() => filter = _FloorFilter.available)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.l10n.cashierActiveTables('$occupied', '${dining.length}'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TawlaTokens.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: dining.isEmpty
                ? TawlaPanel(child: EmptyHint(context.l10n.noTables))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000
                          ? 4
                          : constraints.maxWidth >= 720
                              ? 3
                              : constraints.maxWidth >= 460
                                  ? 2
                                  : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 190,
                        ),
                        itemCount: tables.length,
                        itemBuilder: (context, index) => _tableCard(context, store, tables[index], callIds.contains(tables[index].id)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(BuildContext context, CafeStore store, CafeTable item, bool calling) {
    final order = store.openOrderFor(item.id);
    final free = item.status == TableStatus.free;
    final billDue = item.status == TableStatus.billRequested;
    final (tileColor, badgeTone, statusLabel) = free
        ? (CafeColors.creamDark, BadgeTone.success, context.l10n.cashierAvailable)
        : billDue
            ? (const Color(0xFF95600F), BadgeTone.amber, context.l10n.cashierStatusBillRequested)
            : calling
                ? (CafeColors.terracotta, BadgeTone.terracotta, context.l10n.cashierStatusStaffCall)
                : (const Color(0xFF2F6F8F), BadgeTone.navy, context.l10n.cashierStatusDining);
    final navy = CafeSurfaces.of(context).header;
    Widget action;
    if (billDue) {
      action = _cardButton(context.l10n.cashierSettleBill, const Color(0xFF95600F), () => showCashSettleDialog(context, store, item.id));
    } else if (calling) {
      action = _cardButton(context.l10n.cashierAttended, CafeColors.terracotta, () {
        for (final call in store.openCalls.where((call) => call.tableId == item.id).toList()) {
          store.resolveCall(call.id);
        }
      });
    } else if (order != null) {
      action = SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: () => _showCart(context, store, item),
          style: OutlinedButton.styleFrom(
            foregroundColor: CafeColors.ink,
            side: const BorderSide(color: TawlaTokens.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
          label: Text(context.l10n.cashierViewCart, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
    } else if (!free) {
      action = const SizedBox.shrink();
    } else {
      action = Row(
        children: [
          const Icon(Icons.check, size: 16, color: CafeColors.success),
          const SizedBox(width: 8),
          Text(context.l10n.cashierStatusCleanReady, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tileColor, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  context.l10n.cashierTableShort(item.number),
                  maxLines: 1,
                  style: TextStyle(color: free ? TawlaTokens.muted : Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.cashierTableNumber(item.number), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    StatusBadge(statusLabel, tone: badgeTone),
                  ],
                ),
              ),
              if (order != null)
                Text(
                  context.l10n.cashierElapsedMinutes('${DateTime.now().difference(order.createdAt).inMinutes}'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TawlaTokens.muted),
                ),
            ],
          ),
          const Spacer(),
          if (order != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.cashierOrderItemsCount('${order.itemCount}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: TawlaTokens.muted),
                    ),
                  ),
                  Text(store.currency.format(store.tabTotal(item.id)), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: navy)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          action,
        ],
      ),
    );
  }

  Widget _cardButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  /// What the table has ordered so far, without leaving the floor view. Items can be refused
  /// here and the bill settled, since the floor has no side panel.
  void _showCart(BuildContext context, CafeStore store, CafeTable table) {
    if (store.openOrderFor(table.id) == null) return;
    final floorContext = context;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Builder(
          builder: (context) {
            final store = context.watch<CafeStore>();
            final order = store.openOrderFor(table.id);
            return AlertDialog(
              title: Text(context.l10n.cashierCartTitle(context.l10n.cashierTableNumber(table.number))),
              content: SizedBox(
                width: 420,
                child: order == null
                    ? EmptyHint(context.l10n.noOrders)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${context.l10n.cashierOrderNumber(store.shiftTicket(order))}  ·  ${context.l10n.cashierItemsCount('${order.itemCount}')}',
                            style: const TextStyle(color: TawlaTokens.muted),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: ListView(shrinkWrap: true, children: _orderLineRows(context, store, order)),
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Text(context.l10n.cashierTotalPayable, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const Spacer(),
                              Text(
                                store.currency.format(store.tabTotal(table.id)),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CafeSurfaces.of(context).header),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              actions: [
                OutlineAction(
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  height: 44,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                if (order != null)
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      showCashSettleDialog(floorContext, store, table.id);
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: Text(context.l10n.cashierSettleCloseBill(store.currency.format(store.tabTotal(table.id)))),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
