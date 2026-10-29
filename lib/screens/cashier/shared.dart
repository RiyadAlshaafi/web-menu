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
                    if (line.choices.isNotEmpty) LineChoicesNote(line: line, locale: store.locale, emphasize: true),
                    Text(store.currency.format(line.total), style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (dish.isNotEmpty)
                IconButton(
                  tooltip: dish.first.available ? context.l10n.cashierMarkUnavailable : context.l10n.cashierMarkAvailable,
                  onPressed: () => store.setItemAvailable(dish.first.id, !dish.first.available),
                  icon: Icon(dish.first.available ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  style: IconButton.styleFrom(foregroundColor: CafeSurfaces.of(context).buttonInk),
                ),
              // Apart from the eye, so a finger meant for one does not hit the other.
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final sure = await showCafeConfirmDialog(
                    context,
                    title: context.l10n.cashierRefuseTitle(line.name),
                    message: context.l10n.cashierRefuseMessage,
                    confirm: context.l10n.cashierRefuse,
                  );
                  if (!sure || !context.mounted) return;
                  final error = await store.refuseOrderLine(order, line);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? context.l10n.cashierItemRefused)));
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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

/// A line's removed ingredients and added extras, under its name.
class LineChoicesNote extends StatelessWidget {
  const LineChoicesNote({super.key, required this.line, required this.locale, this.emphasize = false});

  final OrderLine line;
  final String locale;

  /// Kitchen rows show the changes in the accent colour so they are not missed.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Text(
      choicesText(line.choices, locale, without: context.l10n.dishChoiceWithout),
      style: TextStyle(
        color: emphasize ? CafeColors.terracotta : TawlaTokens.muted,
        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }
}

/// A ticket line's name and choices. When the dish has choices, tapping it opens them.
class TicketLineName extends StatelessWidget {
  const TicketLineName({super.key, required this.line, required this.locale, required this.editable, required this.onTap});

  final OrderLine line;
  final String locale;
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
            if (editable) ...[
              const SizedBox(width: 6),
              Icon(Icons.tune, size: 16, color: CafeSurfaces.of(context).buttonInk),
            ],
          ],
        ),
        if (line.choices.isNotEmpty) LineChoicesNote(line: line, locale: locale),
      ],
    );
    if (!editable) return content;
    return Semantics(
      button: true,
      hint: context.l10n.dishChoicesTapLine,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: content),
      ),
    );
  }
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

/// Sends what the kitchen has not seen of [orderId] to the kitchen printer, if this till has one.
/// The order is already saved, so a printer problem is only reported.
void printKitchenRounds(BuildContext context, CafeStore store, String orderId) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  unawaited(TillPrinters.printNewRounds(store, orderId, l10n).then((result) => _reportKitchenPrint(messenger, l10n, result)));
}

/// Kitchen ticket for a paid quick takeout of [lines].
void printKitchenTakeout(BuildContext context, CafeStore store, Payment payment, List<OrderLine> lines) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  unawaited(TillPrinters.printTakeout(store, payment, lines, l10n).then((result) => _reportKitchenPrint(messenger, l10n, result)));
}

/// Opens the cash drawer after a cash sale when this till has it switched on; says so when it
/// did not open, so the cashier opens it by key.
void openDrawerAfterSale(BuildContext context, CafeStore store, Payment payment) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  unawaited(CashDrawer.afterSale(store, payment).then((opened) {
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(l10n.cashDrawerFailed)));
  }));
}

void _reportKitchenPrint(ScaffoldMessengerState messenger, AppLocalizations l10n, KitchenPrintReport report) {
  final names = report.failed.where((name) => name.isNotEmpty).toList();
  if (report.failed.isEmpty) return;
  messenger.showSnackBar(
    SnackBar(content: Text(names.isEmpty ? l10n.kitchenPrintFailed : l10n.kitchenPrintFailedAt(names.join(', ')))),
  );
}
