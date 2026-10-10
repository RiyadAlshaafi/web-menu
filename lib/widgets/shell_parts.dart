import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_ext.dart';
import '../navigation/app_sections.dart';
import '../theme/cafe_theme.dart';

/// Pieces shared by the cashier and admin side menus, so both read the same.

/// Connection state at the top of the cashier menu: green when the till is syncing live,
/// peach when it is working offline.
class SyncStatusStrip extends StatelessWidget {
  const SyncStatusStrip({super.key, required this.disconnected, this.compact = false});

  final bool disconnected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = disconnected ? const Color(0xFFFBE7DD) : const Color(0xFFEAF3E6);
    final border = disconnected ? const Color(0xFFF3C2B3) : const Color(0xFFCFE3C8);
    final fg = disconnected ? CafeColors.terracottaDark : const Color(0xFF2F5228);
    final dot = disconnected ? CafeColors.terracotta : CafeColors.success;
    final state = disconnected ? context.l10n.syncOffline : context.l10n.syncOnline;
    final dotWidget = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: dot,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.18), spreadRadius: 4)],
      ),
    );
    if (compact) {
      return Tooltip(
        message: '${context.l10n.syncLiveTitle} · $state',
        child: Semantics(label: '${context.l10n.syncLiveTitle}, $state', child: Center(child: Padding(padding: const EdgeInsets.all(8), child: dotWidget))),
      );
    }
    return Semantics(
      liveRegion: true,
      label: '${context.l10n.syncLiveTitle}, $state',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
          child: Row(
            children: [
              dotWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.syncLiveTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                    Text(state, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One entry in the side menu. The active entry gets a soft tint of the cafe's button colour.
class ShellNavItem extends StatelessWidget {
  const ShellNavItem({super.key, required this.section, required this.active, this.compact = false, this.badge});

  final AppSection section;
  final bool active;
  final bool compact;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    final darkSidebar = surfaces.onSidebar != CafeColors.ink;
    final activeBg = darkSidebar ? surfaces.button : Color.alphaBlend(surfaces.button.withValues(alpha: 0.22), surfaces.sidebar);
    final activeFg = darkSidebar ? surfaces.onButton : Color.lerp(surfaces.button, Colors.black, 0.3)!;
    final idleFg = darkSidebar ? surfaces.onSidebar : const Color(0xFF3E4A50);
    final fg = active ? activeFg : idleFg;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: section.label(context),
          child: Material(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go(section.path),
              child: SizedBox(height: 52, child: Center(child: Icon(section.icon, color: fg, semanticLabel: section.label(context)))),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: active,
        button: true,
        child: Material(
          color: active ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.go(section.path),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Icon(section.icon, size: 20, color: fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.label(context).replaceAll('\n', ' '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w600, color: fg),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Text(badge!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: fg)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed-in person at the bottom of the side menu, with a clear log-out button.
class ShellProfileCard extends StatelessWidget {
  const ShellProfileCard({
    super.key,
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.onLogOut,
    this.compact = false,
  });

  final String initials;
  final String name;
  final String subtitle;
  final VoidCallback onLogOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logOut = Tooltip(
      message: context.l10n.navLogOut,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: CafeSurfaces.of(context).buttonInk)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onLogOut,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.logout, size: 20, color: CafeSurfaces.of(context).buttonInk, semanticLabel: context.l10n.navLogOut),
          ),
        ),
      ),
    );
    if (compact) return Center(child: logOut);
    final deep = CafeSurfaces.of(context).header;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: deep,
            child: Text(initials, style: TextStyle(color: CafeColors.contrastOn(deep), fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CafeColors.ink)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF56606A))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          logOut,
        ],
      ),
    );
  }
}

/// Page frame shared by the cashier and admin consoles: the header runs the full width,
/// and the side menu sits under it with a hairline between menu and page.
class ShellFrame extends StatelessWidget {
  const ShellFrame({
    super.key,
    required this.header,
    required this.rail,
    required this.drawer,
    required this.drawerWidth,
    required this.body,
    this.banners = const [],
  });

  final Widget header;
  final Widget rail;
  final bool drawer;
  final double drawerWidth;
  final Widget body;
  final List<Widget> banners;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return Scaffold(
      backgroundColor: surfaces.background,
      drawer: drawer ? Drawer(width: drawerWidth, shape: const RoundedRectangleBorder(), child: rail) : null,
      body: Column(
        children: [
          header,
          ...banners,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!drawer)
                  DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: const BoxDecoration(border: BorderDirectional(end: BorderSide(color: CafeColors.line))),
                    child: rail,
                  ),
                Expanded(child: ColoredBox(color: surfaces.background, child: body)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
