part of '../cashier_screens.dart';

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
      ...order.linesInRound(round).map((line) {
        final dish = store.menuItems.where((item) => item.id == line.menuItemId);
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8, end: 4),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(8)),
                child: Text('${line.qty}×', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(store.currency.format(line.total), style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (dish.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: dish.first.available ? context.l10n.cashierMarkUnavailable : context.l10n.cashierMarkAvailable,
                  onPressed: () => store.setItemAvailable(dish.first.id, !dish.first.available),
                  icon: Icon(dish.first.available ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  style: IconButton.styleFrom(foregroundColor: CafeSurfaces.of(context).buttonInk),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final error = await store.refuseOrderLine(order, line);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? context.l10n.cashierItemRefused)));
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ).merge(CafeButtons.destructiveOutlined),
                icon: const Icon(Icons.block, size: 15),
                label: Text(context.l10n.cashierRefuse, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      }),
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
  late final Animation<double> tint = CurvedAnimation(
    parent: fade,
    curve: const Interval(0.3, 1.0, curve: CafeMotion.easeInOut),
  );

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
        decoration: BoxDecoration(color: Color.lerp(const Color(0x33BA5333), const Color(0x00BA5333), tint.value), borderRadius: BorderRadius.circular(16)),
        child: child,
      ),
      child: widget.child,
    );
  }
}
