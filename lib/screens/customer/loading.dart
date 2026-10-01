part of '../customer_screens.dart';

class GuestLoadingScreen extends StatelessWidget {
  const GuestLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return CustomerShell.phone(
      context,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CafeLogo(size: 72, showWordmark: false),
              const SizedBox(height: 16),
              Text(context.watch<CafeStore>().cafeName, style: CafeTheme.display.copyWith(fontSize: 28, color: surfaces.onBackground)),
              const SizedBox(height: 22),
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4, color: surfaces.button)),
              const SizedBox(height: 14),
              Text(context.l10n.guestLoadingTable, style: TextStyle(color: surfaces.onBackground.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

class GuestQrError extends StatelessWidget {
  const GuestQrError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return CustomerShell.phone(
      context,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 48, color: surfaces.button),
              const SizedBox(height: 12),
              Text(context.l10n.guestQrInvalid, textAlign: TextAlign.center, style: CafeTheme.display.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text(context.l10n.guestQrInvalidHint, textAlign: TextAlign.center, style: TextStyle(color: surfaces.onBackground.withValues(alpha: 0.7))),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: Text(context.l10n.guestRetry)),
            ],
          ),
        ),
      ),
    );
  }
}

class GuestServiceScreen extends StatelessWidget {
  const GuestServiceScreen({super.key, required this.table, required this.onChoose});

  final CafeTable table;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final button = CafeSurfaces.of(context).button;
    return CustomerShell.phone(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.watch<CafeStore>().cafeName, style: TextStyle(color: CafeSurfaces.of(context).onBackground.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(context.l10n.guestChooseService, style: CafeTheme.display.copyWith(fontSize: 32)),
            const SizedBox(height: 6),
            Text(context.l10n.guestTableNumber(table.number), style: TextStyle(color: button, fontWeight: FontWeight.w800)),
            const SizedBox(height: 22),
            SoftCard(
              onTap: () => onChoose('dine_in'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant, color: button),
                  const SizedBox(height: 8),
                  Text(context.l10n.guestDineIn, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(context.l10n.guestDineInHint, style: const TextStyle(color: CafeColors.inkMuted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              onTap: () => onChoose('takeout'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shopping_bag_outlined, color: button),
                  const SizedBox(height: 8),
                  Text(context.l10n.guestTakeout, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(context.l10n.guestTakeoutHint, style: const TextStyle(color: CafeColors.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
