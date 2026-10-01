part of '../cashier_screens.dart';

String _customerPayLabel(BuildContext context, CafeStore store, CafeOrder order) {
  final id = order.paymentTypeId;
  if (id == null || id.isEmpty) return context.l10n.cashierCustomerPayNone;
  return context.l10n.cashierCustomerPay(store.typeName(id));
}

List<Widget> _orderLineRows(BuildContext context, CafeStore store, CafeOrder order) {
  final rounds = order.latestRound;
  return [
    for (var round = 1; round <= rounds; round++) ...[
      if (rounds > 1)
        Padding(
          padding: EdgeInsets.only(top: round == 1 ? 0 : 6, bottom: 4),
          child: Text(
            context.l10n.orderRound(round),
            style: const TextStyle(color: CafeColors.terracotta, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ),
      ...order.linesInRound(round).map(
            (line) {
              final dish = store.menuItems.where((item) => item.id == line.menuItemId);
              return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('${line.qty}×  ${line.name}', style: const TextStyle(color: CafeColors.ink)),
                  if (dish.isNotEmpty)
                    IconButton(
                      tooltip: dish.first.available ? context.l10n.cashierMarkUnavailable : context.l10n.cashierMarkAvailable,
                      onPressed: () => store.setItemAvailable(dish.first.id, !dish.first.available),
                      icon: Icon(dish.first.available ? Icons.block : Icons.check_circle_outline, color: CafeSurfaces.of(context).button, size: 18),
                    ),
                  TextButton(
                    onPressed: () async {
                      final error = await store.refuseOrderLine(order, line);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error ?? context.l10n.cashierItemRefused)),
                      );
                    },
                    child: Text(context.l10n.cashierRefuse),
                  ),
                  const Spacer(),
                  Text(store.currency.format(line.total)),
                ],
              ),
            );
            },
          ),
    ],
  ];
}

class _ArrivalFlash extends StatefulWidget {
  const _ArrivalFlash({required this.arrivedAt, required this.child});

  final DateTime? arrivedAt;
  final Widget child;

  @override
  State<_ArrivalFlash> createState() => _ArrivalFlashState();
}

class _ArrivalFlashState extends State<_ArrivalFlash> with SingleTickerProviderStateMixin {
  late final AnimationController fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final Animation<double> tint = CurvedAnimation(parent: fade, curve: const Interval(0.3, 1.0, curve: CafeMotion.easeInOut));

  @override
  void initState() {
    super.initState();
    final at = widget.arrivedAt;
    if (at != null && DateTime.now().difference(at) < const Duration(seconds: 20)) {
      fade.forward(from: 0);
    } else {
      fade.value = 1;
    }
  }

  @override
  void dispose() {
    fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tint,
      builder: (context, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0x33BA5333), const Color(0x00BA5333), tint.value),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
