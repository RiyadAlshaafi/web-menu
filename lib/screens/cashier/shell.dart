part of '../cashier_screens.dart';

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final arabic = context.select<CafeStore, bool>((store) => store.locale == 'ar');
    return PopupMenuButton<String>(
      tooltip: context.l10n.cashierLanguage,
      onSelected: (code) => context.read<CafeStore>().setLocale(code),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: 'en', checked: !arabic, child: const Text('English')),
        CheckedPopupMenuItem(value: 'ar', checked: arabic, child: const Text('العربية')),
      ],
      child: IgnorePointer(
        child: GhostChip(label: arabic ? 'العربية' : 'EN', icon: Icons.language, onTap: () {}),
      ),
    );
  }
}

class CashierShell extends StatelessWidget {
  const CashierShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    // Rebuild the rail only when what it shows changes, not on every store tick.
    final view = context.select<CafeStore, ({String initials, String? name, int tables, int occupied, int alerts, String? sales})>((store) {
      final staff = store.currentCashier;
      final dining = store.diningTables;
      final sales = store.currentShift?.cashSales ?? store.openShift?.cashSales ?? 0;
      return (
        initials: staff?.initials ?? 'C',
        name: staff?.name,
        tables: dining.length,
        occupied: dining.where((table) => table.status != TableStatus.free).length,
        alerts: store.openCalls.length + store.liveOrders().length,
        sales: sales == 0 ? null : store.currency.format(sales),
      );
    });
    final store = context.read<CafeStore>();
    final section = AppSections.forCashier(location);
    final width = MediaQuery.sizeOf(context).width;
    final drawer = AppSections.useDrawer(width);
    final compact = AppSections.compact(width) && !drawer;
    final railWidth = drawer ? 280.0 : (AppSections.compact(width) ? 84.0 : 250.0);

    final surfaces = CafeSurfaces.of(context);
    final rail = Material(
            color: surfaces.sidebar,
            child: SizedBox(
              width: railWidth,
              child: Padding(
                padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 18, compact ? 8 : 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: CafeColors.terracotta, borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Icon(section.icon, color: Colors.white, size: 20),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 8),
                          Expanded(child: CafeLogo(size: 0, showWordmark: true, compact: true, subtitle: context.l10n.cashierPosTerminal)),
                        ],
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0E4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.circle, size: 8, color: CafeColors.success),
                            const SizedBox(width: 6),
                            Text(context.l10n.cashierSoloShiftLive, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F7A45))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(context.l10n.cashierAllInOne, style: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: CafeColors.inkMuted)),
                    ],
                    const SizedBox(height: 10),
                    for (final item in AppSections.cashier)
                      _nav(
                        context,
                        item,
                        item.matches(location),
                        compact,
                        badge: switch (item.path) {
                          '/pos' => '${view.alerts}',
                          '/pos/tables' => view.tables == 0 ? null : '${view.occupied}/${view.tables}',
                          '/pos/shifts' => view.sales,
                          _ => null,
                        },
                      ),
                    const Spacer(),
                    if (compact)
                      IconButton(
                        tooltip: context.l10n.cashierRole,
                        onPressed: () {
                          store.signOut();
                          context.go('/login');
                        },
                        icon: const Icon(Icons.logout, size: 18),
                      )
                    else
                      SoftCard(
                        padding: const EdgeInsets.all(10),
                        radius: 16,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: CafeColors.terracottaSoft,
                              child: Text(view.initials, style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(view.name ?? context.l10n.cashierRole, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(context.l10n.cashierSoloCashier, style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                store.signOut();
                                context.go('/login');
                              },
                              icon: const Icon(Icons.logout, size: 18),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
    return Scaffold(
      backgroundColor: surfaces.background,
      drawer: drawer ? Drawer(width: 280, child: rail) : null,
      body: Row(
        children: [
          if (!drawer) rail,
          Expanded(
            child: Column(
              children: [
                AppHeader(
                  title: section.crumb(context),
                  showMenu: drawer,
                  actions: const [HeaderClock(), LanguageButton()],
                ),
                Expanded(child: ColoredBox(color: surfaces.background, child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, AppSection section, bool active, bool compact, {String? badge}) {
    if (compact) {
      return IconButton(
        tooltip: section.label(context),
        onPressed: () => context.go(section.path),
        icon: Icon(section.icon, color: active ? CafeSurfaces.of(context).button : CafeColors.inkMuted),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        selected: active,
        selectedTileColor: CafeSurfaces.of(context).button,
        selectedColor: CafeSurfaces.of(context).onButton,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(section.icon),
        title: compact ? null : Text(section.label(context), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        trailing: badge == null
            ? null
            : Text(badge, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: active ? Colors.white : CafeColors.inkMuted)),
        onTap: () => context.go(section.path),
      ),
    );
  }
}

enum _AlertFilter { all, calls, orders, bills, ready }

