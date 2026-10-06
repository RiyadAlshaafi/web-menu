import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/cafe_theme.dart';
import '../time_format.dart';

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
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: surfaces.onHeader),
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
