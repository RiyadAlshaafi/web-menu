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

class GuestLanguageScreen extends StatelessWidget {
  const GuestLanguageScreen({super.key, required this.onChoose});

  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final surfaces = CafeSurfaces.of(context);
    return CustomerShell.phone(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 36, 22, 22),
        child: Column(
          children: [
            const CafeLogo(size: 72, showWordmark: false),
            const SizedBox(height: 16),
            Text(store.cafeName, style: CafeTheme.display.copyWith(fontSize: 28, color: surfaces.onBackground)),
            const SizedBox(height: 8),
            Text(context.l10n.guestChooseLanguage, textAlign: TextAlign.center, style: TextStyle(color: surfaces.onBackground.withValues(alpha: 0.7))),
            const SizedBox(height: 28),
            SoftCard(
              onTap: () => onChoose('en'),
              child: const Text('English', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            ),
            const SizedBox(height: 12),
            SoftCard(
              onTap: () => onChoose('ar'),
              child: const Text('العربية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}
