import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../time_format.dart';
import 'tawla_mark.dart';

/// The top bar shared by the admin and cashier shells so both look and behave
/// the same: menu button (only when the sidebar is a drawer), the section title
/// filling the left, and [actions] pinned to the far end.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.showMenu = false, this.actions = const []});

  final String title;
  final bool showMenu;
  final List<Widget> actions;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    final cafeName = context.select<CafeStore, String>((store) => store.cafeName);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final divider = Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: surfaces.onHeader.withValues(alpha: 0.3),
    );
    return Container(
      height: height,
      padding: EdgeInsetsDirectional.only(start: showMenu ? 8 : 24, end: 24),
      color: surfaces.header,
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu, color: surfaces.onHeader),
            )
          else
            const SizedBox.shrink(),
          if (wide) ...[
            TawlaLockup(color: surfaces.onHeader, size: 30),
            divider,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: surfaces.onHeader),
              ),
            ),
            divider,
          ] else ...[
            TawlaMark(size: 24, color: surfaces.onHeader),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.2, color: surfaces.onHeader),
              ),
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }
}

/// A quiet outlined button for the header bar, such as Customer View or the language switch.
class HeaderAction extends StatelessWidget {
  const HeaderAction({super.key, required this.icon, this.label, this.onPressed, this.tooltip});

  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fg = CafeSurfaces.of(context).onHeader;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 14),
        side: BorderSide(color: fg.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ],
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Wall clock for the header; ticks each second and stops with the widget.
class HeaderClock extends StatefulWidget {
  const HeaderClock({super.key});

  @override
  State<HeaderClock> createState() => _HeaderClockState();
}

class _HeaderClockState extends State<HeaderClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 16, color: surfaces.onHeader),
        const SizedBox(width: 6),
        Text(
          formatTripoliClock(DateTime.now()),
          style: TextStyle(fontWeight: FontWeight.w700, color: surfaces.onHeader),
        ),
      ],
    );
  }
}
