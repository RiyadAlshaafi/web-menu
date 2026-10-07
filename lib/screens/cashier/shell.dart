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
    final view = context.select<CafeStore, ({String initials, String? name, int tables, int occupied, int alerts, String? sales, bool offline})>((store) {
      final staff = store.currentCashier;
      final dining = store.diningTables;
      final sales = store.currentShift?.cashSales ?? store.openShift?.cashSales ?? 0;
      return (
        offline: store.offlineSession,
        initials: staff?.initials ?? 'C',
        name: staff?.name ?? (store.offlineSession ? context.l10n.offlineUnassigned : null),
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
              // In a short window the menu scrolls instead of cutting off its last entries.
              child: ScrollWhenShort(
                minHeight: 600,
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
                      if (!view.offline || item.path == '/pos/takeout' || item.path == '/pos/shifts')
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
                const OfflineStatusBanner(),
                Expanded(
                  child: ColoredBox(
                    color: surfaces.background,
                    // A short or narrow window scrolls the page instead of cutting its bottom off;
                    // narrow windows stack the cards, which needs more height.
                    child: ScrollWhenShort(minHeightOf: (c) => c.maxWidth < 900 ? 900 : 680, child: child),
                  ),
                ),
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

/// Shows when the till is offline, how many saved items wait to upload, and any the server refused.
/// When the connection returns during an offline session it asks which cashier takes the work.
class OfflineStatusBanner extends StatefulWidget {
  const OfflineStatusBanner({super.key});

  @override
  State<OfflineStatusBanner> createState() => _OfflineStatusBannerState();
}

class _OfflineStatusBannerState extends State<OfflineStatusBanner> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final s = context.select<CafeStore, ({bool offline, int pending, int failed, bool reconnect, bool assign, int count, bool expired})>(
      (store) => (
        offline: store.isOffline,
        pending: store.offline?.pendingCount ?? 0,
        failed: store.offline?.failedCount ?? 0,
        reconnect: store.reconnectPending && store.offlineSession,
        assign: store.needsCashierForOfflineWork,
        count: store.unassignedOfflineCount,
        expired: store.sessionExpired,
      ),
    );
    if ((s.reconnect || s.assign) && !_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showClaimOfflineDialog(context, needPin: s.reconnect);
      });
    }
    if (!s.reconnect && !s.assign) _asked = false;
    if (s.expired) {
      return Material(
        color: const Color(0xFFF6DADA),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.lock_clock, size: 18, color: CafeColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.pending > 0 ? context.l10n.offlineSignInAgain(s.pending) : context.l10n.offlineSessionExpired, style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.ink)),
              ),
              FilledButton(
                onPressed: () {
                  context.read<CafeStore>().signOut();
                  context.go('/login');
                },
                child: Text(context.l10n.authSignIn),
              ),
            ],
          ),
        ),
      );
    }
    if (s.assign) {
      return Material(
        color: const Color(0xFFE8F0E4),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.person_search, size: 18, color: CafeColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.l10n.offlineAssignBanner(s.count), style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.ink)),
              ),
              FilledButton(
                onPressed: () => showClaimOfflineDialog(context, needPin: false),
                child: Text(context.l10n.offlineAssignButton),
              ),
            ],
          ),
        ),
      );
    }
    if (s.reconnect) {
      return Material(
        color: const Color(0xFFE8F0E4),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_done, size: 18, color: CafeColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.l10n.offlineReconnectBanner, style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.ink)),
              ),
              FilledButton(
                onPressed: () => showClaimOfflineDialog(context),
                child: Text(context.l10n.offlineReconnectButton),
              ),
            ],
          ),
        ),
      );
    }
    if (!s.offline && s.pending == 0 && s.failed == 0) return const SizedBox.shrink();
    final lines = <String>[
      if (s.offline) context.l10n.offlineOnlyTakeout,
      if (s.offline && s.pending > 0) context.l10n.offlineWaiting(s.pending),
      if (!s.offline && s.pending > 0) context.l10n.offlineUploading(s.pending),
      if (s.failed > 0) context.l10n.offlineNeedsReview(s.failed),
    ];
    return Material(
      color: s.failed > 0 ? const Color(0xFFF6DADA) : CafeColors.peach,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(s.offline ? Icons.cloud_off : Icons.cloud_upload, size: 18, color: CafeColors.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(lines.join('  •  '), style: const TextStyle(fontWeight: FontWeight.w700, color: CafeColors.ink)),
            ),
            if (s.failed > 0 && !s.offline)
              TextButton(
                onPressed: () => context.read<CafeStore>().retryFailedUploads(),
                child: Text(context.l10n.guestLocationRetry),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks which cashier the offline receipts belong to. In an offline session ([needPin]) that
/// cashier's PIN signs them in; when a cashier is already signed in, choosing is enough.
Future<void> showClaimOfflineDialog(BuildContext context, {bool needPin = true}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<CafeStore>(),
      child: _ClaimOfflineDialog(needPin: needPin),
    ),
  );
}

class _ClaimOfflineDialog extends StatefulWidget {
  const _ClaimOfflineDialog({required this.needPin});

  final bool needPin;

  @override
  State<_ClaimOfflineDialog> createState() => _ClaimOfflineDialogState();
}

class _ClaimOfflineDialogState extends State<_ClaimOfflineDialog> {
  final pin = TextEditingController();
  late String? cashierId = widget.needPin ? null : context.read<CafeStore>().currentCashier?.id;
  String? error;
  bool busy = false;

  bool get _ready => cashierId != null && (!widget.needPin || pin.text.length == 4) && !busy;

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> _submit(CafeStore store) async {
    final id = cashierId;
    if (id == null || !_ready) return;
    setState(() {
      busy = true;
      error = null;
    });
    final failure = widget.needPin ? await store.claimOfflineWork(id, pin.text) : await store.assignOfflineWork(id);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        busy = false;
        error = failure;
        pin.clear();
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final staff = store.cashiers.where((c) => c.active).toList();
    return AlertDialog(
      title: Text(context.l10n.offlineReconnectTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.offlineReconnectBody(store.unassignedOfflineCount)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final member in staff)
                    ListTile(
                      dense: true,
                      selected: member.id == cashierId,
                      leading: Icon(member.id == cashierId ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                      title: Text(member.name),
                      onTap: busy ? null : () => setState(() => cashierId = member.id),
                    ),
                ],
              ),
            ),
            if (widget.needPin) ...[
              const SizedBox(height: 8),
              Text(context.l10n.offlineReconnectPin, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
              TextField(
                controller: pin,
                enabled: !busy && cashierId != null,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(store),
              ),
            ],
            if (error != null) Text(error!, style: const TextStyle(color: CafeColors.alert, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.offlineReconnectLater),
        ),
        FilledButton(
          onPressed: _ready ? () => _submit(store) : null,
          child: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.l10n.offlineReconnectButton),
        ),
      ],
    );
  }
}

enum _AlertFilter { all, calls, orders, bills, ready }

