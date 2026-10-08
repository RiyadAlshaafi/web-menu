part of '../cashier_screens.dart';

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
    final dining = store.diningTables;
    final callIds = store.openCalls.map((call) => call.tableId).toSet();
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
              Text(context.l10n.cashierTablesCount('${dining.length}'), style: const TextStyle(fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _floorChip(context.l10n.cashierFloorAll('${dining.length}'), filter == _FloorFilter.all, () => setState(() => filter = _FloorFilter.all)),
              _floorChip(context.l10n.cashierFloorOccupied('${dining.where((item) => item.status != TableStatus.free).length}'), filter == _FloorFilter.occupied, () => setState(() => filter = _FloorFilter.occupied)),
              _floorChip(context.l10n.cashierFloorBillDue('${store.billTables.length}'), filter == _FloorFilter.billDue, () => setState(() => filter = _FloorFilter.billDue)),
              _floorChip(context.l10n.cashierFilterCallStaff('${store.openCalls.length}'), filter == _FloorFilter.callStaff, () => setState(() => filter = _FloorFilter.callStaff)),
              _floorChip(context.l10n.cashierFloorAvailable('${dining.where((item) => item.status == TableStatus.free).length}'), filter == _FloorFilter.available, () => setState(() => filter = _FloorFilter.available)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: dining.isEmpty
                ? SoftCard(radius: 16, child: EmptyHint(context.l10n.noTables))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 980;
                      final grid = GridView.count(
                        crossAxisCount: AppSections.columnsFor(constraints.maxWidth, max: 3),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.15,
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
                                  if (store.openOrderFor(item.id) != null)
                                    Text(
                                      context.l10n.cashierOrderNumber(store.shiftTicket(store.openOrderFor(item.id)!)),
                                      style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  const Spacer(),
                                  MoneyText(store.currency.format(due)),
                                  if (item.status == TableStatus.dining && store.openOrderFor(item.id) != null) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showCart(context, store, item),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: CafeColors.ink,
                                          side: const BorderSide(color: Color(0xFFE3DED5), width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                                        label: Text(context.l10n.cashierViewCart, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                  ],
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
                                    if (order != null)
                                      Text(context.l10n.cashierOrderNumber(store.shiftTicket(order)), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 12),
                                    if (order == null)
                                      EmptyHint(context.l10n.noOrders)
                                    else ...[
                                      ..._orderLineRows(context, store, order),
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
                                      onPressed: order == null
                                          ? null
                                          : () => showCashSettleDialog(context, store, table.id),
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

  /// What the table has ordered so far, without leaving the floor view.
  void _showCart(BuildContext context, CafeStore store, CafeTable table) {
    final order = store.openOrderFor(table.id);
    if (order == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final lines = order.lines;
        return AlertDialog(
          title: Text(context.l10n.cashierCartTitle(context.l10n.cashierTableNumber(table.number))),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${context.l10n.cashierOrderNumber(store.shiftTicket(order))}  ·  ${context.l10n.cashierItemsCount('${order.itemCount}')}',
                  style: const TextStyle(color: CafeColors.inkMuted),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final line in lines)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1EDE7)))),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(8)),
                                child: Text('${line.qty}×', style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(line.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text(store.currency.format(line.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
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
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        );
      },
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
            color: selected ? CafeSurfaces.of(context).button : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? CafeSurfaces.of(context).button : CafeColors.line),
          ),
          child: Text(label, style: TextStyle(color: selected ? CafeSurfaces.of(context).onButton : CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }
}

