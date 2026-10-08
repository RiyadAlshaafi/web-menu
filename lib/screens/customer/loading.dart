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
              GuestCafeBadge(size: 76, background: surfaces.header, foreground: surfaces.onHeader),
              const SizedBox(height: 12),
              Text(context.watch<CafeStore>().cafeName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 22),
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4, color: surfaces.button)),
              const SizedBox(height: 14),
              Text(context.l10n.guestLoadingTable, style: const TextStyle(color: GuestTokens.muted)),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2, size: 48, color: surfaces.button),
                    const SizedBox(height: 12),
                    Text(context.l10n.guestQrInvalid, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(context.l10n.guestQrInvalidHint, textAlign: TextAlign.center, style: const TextStyle(color: GuestTokens.muted)),
                    const SizedBox(height: 20),
                    GuestPrimaryButton(label: context.l10n.guestRetry, onPressed: onRetry),
                  ],
                ),
              ),
            ),
            const PoweredByTawla(),
          ],
        ),
      ),
    );
  }
}

class GuestLanguageScreen extends StatefulWidget {
  const GuestLanguageScreen({super.key, required this.onChoose, this.tableNumber});

  final ValueChanged<String> onChoose;
  final String? tableNumber;

  @override
  State<GuestLanguageScreen> createState() => _GuestLanguageScreenState();
}

class _GuestLanguageScreenState extends State<GuestLanguageScreen> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final surfaces = CafeSurfaces.of(context);
    final code = selected ?? store.guestLocale;
    return CustomerShell.phone(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuestCafeBadge(size: 76, background: surfaces.header, foreground: surfaces.onHeader),
              const SizedBox(height: 10),
              Text(store.cafeName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              if (widget.tableNumber != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: CafeColors.line),
                    ),
                    child: Text(context.l10n.guestTableNumber(widget.tableNumber!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(context.l10n.guestChooseLanguage, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _option('en', 'English', code)),
                  const SizedBox(width: 10),
                  Expanded(child: _option('ar', 'العربية', code)),
                ],
              ),
              const Spacer(),
              GuestPrimaryButton(label: context.l10n.guestOpenMenu, onPressed: () => widget.onChoose(code)),
              const SizedBox(height: 16),
              const PoweredByTawla(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(String value, String label, String current) {
    final active = value == current;
    final accent = CafeSurfaces.of(context).button;
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: () => setState(() => selected = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? GuestTokens.softAccent : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? accent : GuestTokens.border, width: 2),
          ),
          child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CafeColors.ink)),
        ),
      ),
    );
  }
}
