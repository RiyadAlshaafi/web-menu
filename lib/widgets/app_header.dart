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
      padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
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
            const SizedBox(width: 6),
          if (wide) ...[
            TawlaLockup(color: surfaces.onHeader, size: 26),
            divider,
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: surfaces.onHeader),
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
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: surfaces.onHeader),
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
