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
      child: Selector<WaiterController, String>(
        selector: (_, waiter) => waiter.locale,
        builder: (context, locale, _) => MaterialApp(
          title: 'Tawla Waiter',
          debugShowCheckedModeBanner: false,
          theme: CafeTheme.light,
          locale: Locale(locale),
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
      duration: CafeMotion.medium,
      child: ready ? const TablesScreen() : const ConnectScreen(),
    );
  }
}
