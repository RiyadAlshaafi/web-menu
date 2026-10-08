part of '../customer_screens.dart';

/// Colours of the Tawla guest pages: a warm cream page with white cards.
class GuestTokens {
  static const page = CafeColors.cream;
  static const muted = Color(0xFF56606A);
  static const border = Color(0xFFE3DED5);
  static const hairline = Color(0xFFF1EDE7);
  static const softAccent = Color(0xFFFFF4EF);
  static const stepIdle = Color(0xFFD8D2C6);
}

/// Up to two capital letters from the cafe name, used where there is no logo.
String cafeInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return '';
  final letters = words.take(2).map((word) => word.characters.first).join();
  return letters.toUpperCase();
}

/// The cafe's logo in a circle, or its initials when there is no logo.
class GuestCafeBadge extends StatelessWidget {
  const GuestCafeBadge({super.key, required this.size, required this.background, required this.foreground});

  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final logo = store.logoUrl;
    final initials = Text(
      cafeInitials(store.cafeName),
      style: TextStyle(color: foreground, fontSize: size * 0.33, fontWeight: FontWeight.w800),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: logo.startsWith('http')
          ? Image.network(
              logo,
              width: size,
              height: size,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initials,
            )
          : initials,
    );
  }
}

/// Navy bar at the top of every guest page: cafe badge, cafe name and table.
class GuestHeader extends StatelessWidget {
  const GuestHeader({super.key, required this.table});

  final CafeTable table;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final surfaces = CafeSurfaces.of(context);
    final takeout = table.id != 'missing' && store.serviceForTable(table.id) == 'takeout';
    final subtitle = takeout
        ? '${context.l10n.guestTableNumber(table.number)} • ${context.l10n.serviceTakeout}'
        : context.l10n.guestTableDineIn(table.number);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: guestHeaderDecoration(context),
      child: Row(
        children: [
          GuestCafeBadge(size: 42, background: surfaces.onHeader.withValues(alpha: 0.16), foreground: surfaces.onHeader),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.cafeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: surfaces.onHeader),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: surfaces.onHeader.withValues(alpha: 0.78))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Powered by Tawla" at the foot of the guest pages.
class PoweredByTawla extends StatelessWidget {
  const PoweredByTawla({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(context.l10n.guestPoweredBy, style: const TextStyle(fontSize: 12, color: GuestTokens.muted)),
        const SizedBox(width: 6),
        const Directionality(textDirection: TextDirection.ltr, child: TawlaLockup(size: 18)),
      ],
    );
  }
}

/// White card with large rounded corners, the main surface of the guest pages.
class GuestCard extends StatelessWidget {
  const GuestCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: child,
    );
  }
}

/// Small spaced capitals in the button colour, such as "LIVE TAB".
class GuestEyebrow extends StatelessWidget {
  const GuestEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: CafeSurfaces.of(context).button),
    );
  }
}

/// One "2× Cappuccino 10.000 LYD" line with a hairline above it.
class GuestTicketLine extends StatelessWidget {
  const GuestTicketLine({super.key, required this.qty, required this.name, required this.amount});

  final int qty;
  final String name;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: GuestTokens.hairline))),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('$qty×', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 8),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}

/// Full-width button in the cafe's button colour, as on the guest design.
class GuestPrimaryButton extends StatelessWidget {
  const GuestPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 56, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: surfaces.button,
          foregroundColor: surfaces.onButton,
          disabledBackgroundColor: CafeColors.terracottaSoft,
          disabledForegroundColor: surfaces.onButton,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: surfaces.onButton))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                ],
              ),
      ),
    );
  }
}

/// White button with a soft border, the secondary action next to [GuestPrimaryButton].
class GuestOutlineButton extends StatelessWidget {
  const GuestOutlineButton({super.key, required this.label, required this.onPressed, this.height = 52});

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: CafeColors.ink,
          side: const BorderSide(color: GuestTokens.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
