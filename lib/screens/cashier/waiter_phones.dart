part of '../cashier_screens.dart';

/// On the till: phones asking to be allowed. A waiter order held on the hub (offline till) shows
/// in the new-order list instead, with the same toast a guest's new order gets.
class WaiterHubBanner extends StatefulWidget {
  const WaiterHubBanner({super.key});

  @override
  State<WaiterHubBanner> createState() => _WaiterHubBannerState();
}

class _WaiterHubBannerState extends State<WaiterHubBanner> {
  final Set<String> _toasted = {};

  void _toastNew(List<WaiterOrder> orders) {
    final fresh = orders.where((order) => _toasted.add(order.id)).toList();
    if (fresh.isEmpty) return;
    final l10n = context.l10n;
    final where = {for (final order in fresh) l10n.cashierTableNumber(order.tableNumber)}.join(', ');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.cashierNewOrderToast(where))),
            ],
          ),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.read<CafeStore>().waiterHub;
    if (hub == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        _toastNew(hub.pendingOrders);
        final asks = hub.pairRequests;
        if (asks.isEmpty) return const SizedBox.shrink();
        return Material(
          color: CafeColors.peach,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final ask in asks) _PairRow(hub: hub, request: ask)],
          ),
        );
      },
    );
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({required this.icon, required this.title, required this.actions});

  final IconData icon;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CafeColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.ink)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({required this.hub, required this.request});

  final WaiterHub hub;
  final PairRequest request;

  @override
  Widget build(BuildContext context) {
    return _BannerRow(
      icon: Icons.phone_android,
      title: context.l10n.waiterPairAsk(request.deviceName),
      actions: [
        TextButton(
          onPressed: () => hub.answerPair(request, allow: false),
          child: Text(context.l10n.waiterDeny),
        ),
        const SizedBox(width: 6),
        FilledButton(
          onPressed: () => hub.answerPair(request, allow: true),
          child: Text(context.l10n.waiterAllow),
        ),
      ],
    );
  }
}

/// Sends the waiter's dishes to the table's bill and prints them in the kitchen.
Future<void> acceptWaiterOrder(BuildContext context, WaiterHub hub, WaiterOrder order) async {
  final store = context.read<CafeStore>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final result = await hub.accept(order);
  if (!context.mounted) return;
  final error = result.error;
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorText(error))));
    return;
  }
  final orderId = result.orderId;
  if (orderId != null) printKitchenRounds(context, store, orderId);
  messenger.showSnackBar(SnackBar(content: Text(l10n.waiterOrderAccepted(l10n.cashierTableNumber(order.tableNumber)))));
}

/// Header button that lists the allowed waiter phones, so the cashier can remove a lost one.
class WaiterPhonesButton extends StatelessWidget {
  const WaiterPhonesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.read<CafeStore>().waiterHub;
    if (hub == null) return const SizedBox.shrink();
    return HeaderAction(
      icon: Icons.phone_android,
      tooltip: context.l10n.waiterPhones,
      onPressed: () => showDialog<void>(context: context, builder: (_) => _WaiterPhonesDialog(hub: hub)),
    );
  }
}

class _WaiterPhonesDialog extends StatelessWidget {
  const _WaiterPhonesDialog({required this.hub});

  final WaiterHub hub;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.waiterPhones),
      content: SizedBox(
        width: 380,
        child: ListenableBuilder(
          listenable: hub,
          builder: (context, _) {
            final phones = hub.devices;
            if (phones.isEmpty) return Text(context.l10n.waiterPhonesEmpty);
            return ListView(
              shrinkWrap: true,
              children: [
                for (final phone in phones)
                  ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(phone.name),
                    subtitle: Text(context.l10n.waiterPhoneLastSeen(formatTripoliDateTime(phone.lastSeen))),
                    trailing: TextButton(
                      onPressed: () => hub.forget(phone.id),
                      child: Text(context.l10n.waiterPhoneRemove),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.waiterClose)),
      ],
    );
  }
}
