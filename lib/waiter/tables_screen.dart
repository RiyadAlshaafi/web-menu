import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../lan/lan_protocol.dart';
import '../models/models.dart';
import '../theme/cafe_theme.dart';
import 'order_screen.dart';
import 'waiter_motion.dart';
import 'waiter_state.dart';

export 'waiter_motion.dart' show WaiterLanguageButton;

/// The floor: one big tile per table. Tapping a table opens its order screen.
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    final l10n = context.l10n;
    final surfaces = CafeSurfaces.of(context);
    return Scaffold(
      backgroundColor: surfaces.background,
      body: Column(
        children: [
          _FloorHeader(waiter: waiter),
          AnimatedSize(
            duration: CafeMotion.medium,
            curve: CafeMotion.easeOut,
            child: Column(
              children: [
                if (!waiter.connected) const ReconnectingBanner(),
                if (waiter.ordersPaused) const OrdersPausedBanner(),
                _AlertSlot(alerts: waiter.alerts),
                if (waiter.sentOrders.isNotEmpty) _SentStrip(orders: waiter.sentOrders),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: surfaces.button,
              onRefresh: waiter.refresh,
              child: waiter.tables.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: waiter.connected
                              ? Text(l10n.waiterNoTables, style: const TextStyle(color: CafeColors.inkMuted))
                              : CircularProgressIndicator(color: surfaces.button),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: waiter.tables.length,
                      itemBuilder: (context, index) => EntranceRise(
                        key: ValueKey(waiter.tables[index].id),
                        index: index,
                        child: _TableTile(table: waiter.tables[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cafe's colour band: name, language, and how many tables are free, eating or want the bill.
class _FloorHeader extends StatelessWidget {
  const _FloorHeader({required this.waiter});

  final WaiterController waiter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final surfaces = CafeSurfaces.of(context);
    final ink = surfaces.onHeader;
    int count(TableStatus status) => waiter.tables.where((table) => table.status == status).length;
    return Container(
      decoration: brandGradient(surfaces, radius: const BorderRadius.vertical(bottom: Radius.circular(28))),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.waiterTables,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          waiter.hub?.cafeName ?? 'Tawla',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.4),
                        ),
                      ],
                    ),
                  ),
                  const _SoundButton(),
                  const WaiterLanguageButton(),
                  _TillMenu(color: ink),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(
                    count: count(TableStatus.free),
                    label: l10n.waiterTableFree,
                    dot: CafeColors.success,
                    ink: ink,
                  ),
                  _CountChip(
                    count: count(TableStatus.dining),
                    label: l10n.waiterTableDining,
                    dot: const Color(0xFF7FB3D5),
                    ink: ink,
                  ),
                  _CountChip(
                    count: count(TableStatus.billRequested),
                    label: l10n.waiterTableBill,
                    dot: const Color(0xFFF2A65A),
                    ink: ink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.label, required this.dot, required this.ink});

  final int count;
  final String label;
  final Color dot;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: ink.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          BumpText(
            '$count',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: ink.withValues(alpha: 0.85), fontWeight: FontWeight.w600, fontSize: 13),
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
    final surfaces = CafeSurfaces.of(context);
    final inCart = context.select<WaiterController, int>((waiter) => waiter.cartCount(table.id));
    final alert = context.select<WaiterController, WaiterAlertKind?>((waiter) => waiter.alertFor(table.id));
    final (color, label, icon) = switch (table.status) {
      TableStatus.free => (CafeColors.success, l10n.waiterTableFree, Icons.event_seat_outlined),
      TableStatus.dining => (surfaces.header, l10n.waiterTableDining, Icons.restaurant),
      TableStatus.billRequested => (CafeColors.terracotta, l10n.waiterTableBill, Icons.receipt_long),
    };
    return Semantics(
      button: true,
      label: '${l10n.cashierTableNumber(table.number)}, $label',
      child: PressScale(
        child: ShakeAlert(
          color: alert == null ? null : _alertColor(alert),
          radius: 22,
          child: AnimatedContainer(
            duration: CafeMotion.medium,
            curve: CafeMotion.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: inCart > 0 ? surfaces.button : Colors.transparent, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _openTable(context, table.id),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      end: -18,
                      bottom: -18,
                      child: Icon(icon, size: 96, color: color.withValues(alpha: 0.07)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Pill(text: label, color: color),
                              const Spacer(),
                              if (inCart > 0) _CartBadge(count: inCart, color: surfaces.button, ink: surfaces.onButton),
                            ],
                          ),
                          const Spacer(),
                          ExcludeSemantics(
                            child: Text(
                              table.number,
                              style: const TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                color: CafeColors.ink,
                                height: 1,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (table.items > 0)
                            Text(
                              '${l10n.waiterItems(table.items)} · ${waiter.money.format(table.total)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CafeColors.inkMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          if (alert != null) _AlertLine(kind: alert),
                          if (table.waiting > 0)
                            Row(
                              children: [
                                PulseDot(color: surfaces.buttonInk, size: 7),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    l10n.waiterTableWaiting(table.waiting),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: surfaces.buttonInk,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

Color _alertColor(WaiterAlertKind kind) => switch (kind) {
  WaiterAlertKind.ready => CafeColors.success,
  WaiterAlertKind.call => CafeColors.alert,
  WaiterAlertKind.bill => const Color(0xFFE08A1E),
};

IconData _alertIcon(WaiterAlertKind kind) => switch (kind) {
  WaiterAlertKind.ready => Icons.room_service,
  WaiterAlertKind.call => Icons.notifications_active,
  WaiterAlertKind.bill => Icons.receipt_long,
};

String _alertText(BuildContext context, WaiterAlert alert) => switch (alert.kind) {
  WaiterAlertKind.ready => context.l10n.waiterAlertReady(alert.tableNumber),
  WaiterAlertKind.call => context.l10n.waiterAlertCall(alert.tableNumber),
  WaiterAlertKind.bill => context.l10n.waiterAlertBill(alert.tableNumber),
};

/// Opens a table's order screen and counts its alert as seen.
void _openTable(BuildContext context, String tableId) {
  final waiter = context.read<WaiterController>()..acknowledge(tableId);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: waiter,
        child: OrderScreen(tableId: tableId),
      ),
    ),
  );
}

/// Short coloured line on the tile saying what the table needs.
class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.kind});

  final WaiterAlertKind kind;

  @override
  Widget build(BuildContext context) {
    final color = _alertColor(kind);
    final text = switch (kind) {
      WaiterAlertKind.ready => context.l10n.cashierReadyToServe,
      WaiterAlertKind.call => context.l10n.cashierCallStaff,
      WaiterAlertKind.bill => context.l10n.cashierBillRequest,
    };
    return Row(
      children: [
        Icon(_alertIcon(kind), size: 15, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Shows the most urgent alert (a bill, then a call, then food) and slides it away when it is
/// answered; the next one takes its place. Others wait behind a "+N more" count, so a busy
/// floor never fills the screen with banners.
class _AlertSlot extends StatelessWidget {
  const _AlertSlot({required this.alerts});

  final List<WaiterAlert> alerts;

  @override
  Widget build(BuildContext context) {
    WaiterAlert? top;
    for (final alert in alerts) {
      if (top == null || alert.kind.index > top.kind.index) top = alert;
    }
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : CafeMotion.quick,
      switchInCurve: CafeMotion.easeOut,
      switchOutCurve: CafeMotion.easeOut,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: top == null
          ? const SizedBox(key: ValueKey('no-alert'), width: double.infinity)
          : _AlertBanner(key: ValueKey(top.key), alert: top, more: alerts.length - 1),
    );
  }
}

/// Banner for one alert; tapping it opens that table.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({super.key, required this.alert, required this.more});

  final WaiterAlert alert;
  final int more;

  @override
  Widget build(BuildContext context) {
    final color = _alertColor(alert.kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openTable(context, alert.tableId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(_alertIcon(alert.kind), color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _alertText(context, alert),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        context.l10n.waiterAlertGo,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (more > 0)
                  Text(
                    context.l10n.waiterAlertMore(more),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                IconButton(
                  tooltip: context.l10n.waiterClose,
                  onPressed: () => context.read<WaiterController>().acknowledge(alert.tableId),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns the alert beeps on this phone on or off.
class _SoundButton extends StatelessWidget {
  const _SoundButton();

  @override
  Widget build(BuildContext context) {
    final on = context.select<WaiterController, bool>((waiter) => waiter.soundOn);
    final ink = CafeSurfaces.of(context).onHeader;
    final l10n = context.l10n;
    return IconButton(
      tooltip: on ? l10n.waiterSoundOn : l10n.waiterSoundOff,
      onPressed: () => context.read<WaiterController>().setSoundOn(!on),
      icon: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CafeMotion.quick,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: animation, curve: CafeMotion.easeOut)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(on ? Icons.volume_up : Icons.volume_off, key: ValueKey(on), color: ink),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count, required this.color, required this.ink});

  final int count;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket, size: 14, color: ink),
          const SizedBox(width: 4),
          BumpText(
            '$count',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
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
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: CafeColors.readableOn(color, [Colors.white]),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// The last orders this phone sent and whether the cashier accepted them.
class _SentStrip extends StatelessWidget {
  const _SentStrip({required this.orders});

  final List<SentOrder> orders;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => EntranceRise(
          key: ValueKey(orders[index].id),
          index: index,
          child: _SentChip(order: orders[index]),
        ),
      ),
    );
  }
}

class _SentChip extends StatelessWidget {
  const _SentChip({required this.order});

  final SentOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final surfaces = CafeSurfaces.of(context);
    final (color, label) = switch (order.status) {
      WaiterOrderStatus.pending => (surfaces.buttonInk, l10n.waiterStatusPending),
      WaiterOrderStatus.accepted => (CafeColors.success, l10n.waiterStatusAccepted),
      WaiterOrderStatus.refused => (CafeColors.alert, l10n.waiterStatusRefused),
    };
    final Widget mark = switch (order.status) {
      WaiterOrderStatus.pending => PulseDot(color: color, size: 8),
      WaiterOrderStatus.accepted => Icon(Icons.check_circle, size: 18, color: color),
      WaiterOrderStatus.refused => Icon(Icons.cancel, size: 18, color: color),
    };
    return AnimatedContainer(
      duration: CafeMotion.medium,
      curve: CafeMotion.easeOut,
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: CafeMotion.medium,
            child: KeyedSubtree(key: ValueKey(order.status), child: mark),
          ),
          const SizedBox(width: 6),
          Text(
            '${l10n.cashierTableNumber(order.tableNumber)} · $label',
            style: TextStyle(fontWeight: FontWeight.w700, color: CafeColors.ink.withValues(alpha: 0.9)),
          ),
        ],
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

/// The till has no internet: the waiter must tell the cashier in person until it is back.
class OrdersPausedBanner extends StatelessWidget {
  const OrdersPausedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6DD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CafeColors.terracotta.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: CafeColors.terracottaDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.waiterOrdersPaused,
              style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.terracottaDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _TillMenu extends StatelessWidget {
  const _TillMenu({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: Icon(Icons.more_vert, color: color),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          onTap: () => context.read<WaiterController>().forgetTill(),
          child: Text(context.l10n.waiterChangeCafe),
        ),
      ],
    );
  }
}
