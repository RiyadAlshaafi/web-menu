part of '../customer_screens.dart';

class CustomerShell {
  static Widget nav(BuildContext context, String tableId, String current) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(tableId);
    final hasOrder = table != null && store.openOrderFor(table.id) != null;
    final accent = CafeSurfaces.of(context).button;
    Widget item(IconData icon, String label, {bool active = false, bool enabled = true, required VoidCallback onTap}) {
      final color = !enabled ? GuestTokens.muted.withValues(alpha: 0.45) : (active ? accent : GuestTokens.muted);
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CafeColors.line)),
      ),
      child: Row(
        children: [
          item(
            Icons.chrome_reader_mode_outlined,
            context.l10n.guestNavMenu,
            active: current == '/t/$tableId',
            onTap: () => context.go('/t/$tableId'),
          ),
          item(
            Icons.receipt_outlined,
            context.l10n.guestTableBill,
            active: current == '/t/$tableId/cart',
            enabled: hasOrder,
            onTap: () {
              if (!hasOrder) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestOrderFirst)));
                return;
              }
              context.go('/t/$tableId/cart');
            },
          ),
          item(
            Icons.notifications_none_outlined,
            context.l10n.guestCallStaff,
            onTap: () {
              if (table == null) return;
              if (!store.guestOrderingOpen) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestOrderingPaused)));
                return;
              }
              store.callStaff(table.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.guestRequestSent)),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget phone(BuildContext context, {required Widget child}) {
    return Scaffold(
      backgroundColor: GuestTokens.page,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    );
  }
}
