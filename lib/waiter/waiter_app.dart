import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../theme/cafe_theme.dart';
import 'connect_screen.dart';
import 'tables_screen.dart';
import 'waiter_state.dart';

/// The waiter phone app: find the till, pick a table, send dishes. Nothing else is reachable.
class WaiterApp extends StatelessWidget {
  const WaiterApp({super.key, required this.controller});

  final WaiterController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Selector<WaiterController, (String, CafeSurfaces)>(
        selector: (_, waiter) => (waiter.locale, waiter.surfaces),
        builder: (context, look, _) => MaterialApp(
          title: 'Tawla Waiter',
          debugShowCheckedModeBanner: false,
          theme: CafeTheme.forSurfaces(look.$2),
          locale: Locale(look.$1),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _WaiterHome(),
        ),
      ),
    );
  }
}

class _WaiterHome extends StatelessWidget {
  const _WaiterHome();

  @override
  Widget build(BuildContext context) {
    final ready = context.select<WaiterController, bool>((waiter) => waiter.phase == WaiterPhase.ready);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: CafeMotion.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(animation), child: child),
      ),
      child: ready ? const TablesScreen() : const ConnectScreen(),
    );
  }
}
