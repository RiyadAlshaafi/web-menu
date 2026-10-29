import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          // Status-bar icons follow the cafe's header colour, and the nav bar is see-through, so
          // the phone's own bars read as part of the app rather than a strip above it.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: waiterSystemBars(look.$2),
            child: child!,
          ),
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

/// Transparent system bars with icons that contrast with the header the status bar sits on.
SystemUiOverlayStyle waiterSystemBars(CafeSurfaces surfaces) {
  final dark = ThemeData.estimateBrightnessForColor(surfaces.header) == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
