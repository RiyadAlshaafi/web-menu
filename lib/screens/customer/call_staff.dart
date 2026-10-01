part of '../customer_screens.dart';

class CustomerShell {
  static Widget nav(BuildContext context, String tableId, String current) {
    final store = context.watch<CafeStore>();
    final table = store.tableBySlug(tableId);
    final hasOrder = table != null && store.openOrderFor(table.id) != null;
    Widget item(IconData icon, String label, String path, {bool enabled = true}) {
      final active = current == path;
      return InkWell(
        onTap: () {
          if (!enabled) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.guestOrderFirst)));
            return;
          }
          context.go(path);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: !enabled ? CafeColors.line : (active ? CafeSurfaces.of(context).button : CafeColors.inkMuted)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: !enabled ? CafeColors.line : (active ? CafeSurfaces.of(context).button : CafeColors.inkMuted),
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: CafeSurfaces.of(context).button, shape: BoxShape.circle),
              ),
          ],
        ),
      );
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: CafeSurfaces.of(context).sidebar,
        border: const Border(top: BorderSide(color: Color(0x66E6E2DC))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          item(Icons.restaurant_menu, context.l10n.guestNavMenu, '/t/$tableId'),
          item(Icons.receipt_long, context.l10n.guestTableBill, '/t/$tableId/cart', enabled: hasOrder),
          InkWell(
            onTap: () {
              if (table == null) return;
              store.callStaff(table.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.guestRequestSent)),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.room_service_outlined, size: 22, color: CafeColors.inkMuted),
                const SizedBox(height: 2),
                Text(context.l10n.guestCallStaff, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CafeColors.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget phone(BuildContext context, {required Widget child}) {
    return Scaffold(
      backgroundColor: CafeSurfaces.of(context).background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: child,
        ),
      ),
    );
  }
}

