import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../lan/lan_protocol.dart';
import '../models/models.dart';
import '../theme/cafe_theme.dart';
import 'order_screen.dart';
import 'waiter_state.dart';

/// The floor: one big tile per table. Tapping a table opens its order screen.
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: CafeColors.cream,
      appBar: AppBar(
        backgroundColor: CafeColors.defaultHeader,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(waiter.hub?.cafeName ?? 'Tawla', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(l10n.waiterTables, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: const [WaiterLanguageButton(), _TillMenu()],
      ),
      body: Column(
        children: [
          if (!waiter.connected) const ReconnectingBanner(),
          if (waiter.sentOrders.isNotEmpty) _SentStrip(orders: waiter.sentOrders),
          Expanded(
            child: RefreshIndicator(
              onRefresh: waiter.refresh,
              child: waiter.tables.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: waiter.connected
                              ? Text(l10n.waiterNoTables, style: const TextStyle(color: CafeColors.inkMuted))
                              : const CircularProgressIndicator(),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: waiter.tables.length,
                      itemBuilder: (context, index) => _TableTile(table: waiter.tables[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({required this.table});

  final WaiterTable table;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final waiter = context.read<WaiterController>();
    final inCart = context.select<WaiterController, int>((waiter) => waiter.cartCount(table.id));
    final (color, label) = switch (table.status) {
      TableStatus.free => (CafeColors.success, l10n.waiterTableFree),
      TableStatus.dining => (CafeColors.defaultHeader, l10n.waiterTableDining),
      TableStatus.billRequested => (CafeColors.terracotta, l10n.waiterTableBill),
    };
    return Semantics(
      button: true,
      label: '${l10n.cashierTableNumber(table.number)}, $label',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider.value(value: waiter, child: OrderScreen(tableId: table.id)),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border(top: BorderSide(color: color, width: 6)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Pill(text: label, color: color),
                    const Spacer(),
                    if (inCart > 0) const Icon(Icons.shopping_basket, size: 20, color: CafeColors.terracotta),
                  ],
                ),
                const Spacer(),
                ExcludeSemantics(
                  child: Text(
                    table.number,
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: CafeColors.ink, height: 1),
                  ),
                ),
                const Spacer(),
                if (table.items > 0)
                  Text(
                    '${l10n.waiterItems(table.items)} · ${waiter.money.format(table.total)}',
                    style: const TextStyle(color: CafeColors.inkMuted, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                if (table.waiting > 0)
                  Text(
                    l10n.waiterTableWaiting(table.waiting),
                    style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

/// The last orders this phone sent and whether the cashier accepted them.
class _SentStrip extends StatelessWidget {
  const _SentStrip({required this.orders});

  final List<SentOrder> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final order = orders[index];
          final (color, icon, label) = switch (order.status) {
            WaiterOrderStatus.pending => (CafeColors.terracotta, Icons.hourglass_top, l10n.waiterStatusPending),
            WaiterOrderStatus.accepted => (CafeColors.success, Icons.check_circle, l10n.waiterStatusAccepted),
            WaiterOrderStatus.refused => (CafeColors.alert, Icons.cancel, l10n.waiterStatusRefused),
          };
          return Chip(
            avatar: Icon(icon, size: 18, color: color),
            label: Text('${l10n.cashierTableNumber(order.tableNumber)} · $label'),
            backgroundColor: Colors.white,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          );
        },
      ),
    );
  }
}

class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CafeColors.peach,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.l10n.waiterReconnecting, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class WaiterLanguageButton extends StatelessWidget {
  const WaiterLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    final arabic = waiter.locale == 'ar';
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
      onPressed: () => waiter.setLocale(arabic ? 'en' : 'ar'),
      child: Text(arabic ? 'EN' : 'ع', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }
}

class _TillMenu extends StatelessWidget {
  const _TillMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          onTap: () => context.read<WaiterController>().forgetTill(),
          child: Text(context.l10n.waiterChangeCafe),
        ),
      ],
    );
  }
}
