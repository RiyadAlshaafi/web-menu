import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'screens/admin_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/cashier_screens.dart';
import 'screens/customer_screens.dart';
import 'state/cafe_store.dart';
import 'theme/cafe_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final store = CafeStore(AppDatabase.instance);
  await store.load();
  runApp(CafeItalianoApp(store: store));
}

class CafeItalianoApp extends StatefulWidget {
  const CafeItalianoApp({super.key, required this.store});

  final CafeStore store;

  @override
  State<CafeItalianoApp> createState() => _CafeItalianoAppState();
}

class _CafeItalianoAppState extends State<CafeItalianoApp> {
  late final GoRouter router;
  late final _RouterRefresh routerRefresh;
  late String locale;

  @override
  void initState() {
    super.initState();
    locale = widget.store.locale;
    routerRefresh = _RouterRefresh(widget.store);
    widget.store.addListener(_onStore);
    router = GoRouter(
      initialLocation: widget.store.hasAdmin ? '/login' : '/admin/setup',
      refreshListenable: routerRefresh,
      redirect: (_, state) {
        final path = state.uri.path;
        final guest = path.startsWith('/t/');
        final auth = path == '/login' ||
            path.startsWith('/admin/login') ||
            path.startsWith('/admin/setup') ||
            path.startsWith('/admin/forgot') ||
            path.startsWith('/admin/password');
        if (guest || auth) return null;
        if (path.startsWith('/pos') && widget.store.authKind != AuthKind.cashier) {
          return '/login';
        }
        if (path.startsWith('/admin') && widget.store.authKind != AuthKind.admin) {
          return widget.store.hasAdmin ? '/admin/login' : '/admin/setup';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, _) => widget.store.hasAdmin ? '/login' : '/admin/setup'),
        GoRoute(path: '/login', builder: (_, _) => const PinLoginScreen()),
        GoRoute(path: '/admin/setup', builder: (_, _) => const AdminAuthScreen(setup: true)),
        GoRoute(path: '/admin/login', builder: (_, _) => const AdminAuthScreen()),
        GoRoute(
          path: '/admin/forgot',
          builder: (_, state) => ForgotPasswordScreen(email: state.extra as String? ?? ''),
        ),
        GoRoute(path: '/admin/password', builder: (_, _) => const ChangePasswordScreen()),
        GoRoute(
          path: '/t/:tableId',
          builder: (_, state) => GuestSession(
            slug: state.pathParameters['tableId']!,
            child: CustomerMenuScreen(tableSlug: state.pathParameters['tableId']!),
          ),
        ),
        GoRoute(
          path: '/t/:tableId/cart',
          builder: (_, state) => GuestSession(
            slug: state.pathParameters['tableId']!,
            child: CustomerCartScreen(tableSlug: state.pathParameters['tableId']!),
          ),
        ),
        GoRoute(
          path: '/t/:tableId/bill',
          builder: (_, state) => GuestSession(
            slug: state.pathParameters['tableId']!,
            child: CustomerBillScreen(tableSlug: state.pathParameters['tableId']!),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => CashierShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/pos', builder: (_, _) => const CashierDashboardScreen()),
            GoRoute(path: '/pos/tables', builder: (_, _) => const CashierFloorScreen()),
            GoRoute(path: '/pos/shifts', builder: (_, _) => const CashierShiftsScreen()),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/admin/menu', builder: (_, _) => const AdminMenuScreen()),
            GoRoute(path: '/admin/discounts', builder: (_, _) => const AdminCategoriesScreen()),
            GoRoute(path: '/admin/categories', redirect: (_, _) => '/admin/discounts'),
            GoRoute(path: '/admin/tables', builder: (_, _) => const AdminTablesScreen()),
            GoRoute(path: '/admin/settings', builder: (_, _) => const AdminSettingsScreen()),
          ],
        ),
      ],
    );
  }

  void _onStore() {
    if (!mounted || widget.store.locale == locale) return;
    setState(() => locale = widget.store.locale);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.store,
      child: MaterialApp.router(
        title: 'Café Italiano',
        debugShowCheckedModeBanner: false,
        theme: CafeTheme.light,
        locale: Locale(locale),
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
        routerConfig: router,
      ),
    );
  }
}

class GuestSession extends StatefulWidget {
  const GuestSession({super.key, required this.slug, required this.child});

  final String slug;
  final Widget child;

  @override
  State<GuestSession> createState() => _GuestSessionState();
}

class _GuestSessionState extends State<GuestSession> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CafeStore>().ensureGuest(widget.slug);
    });
  }

  @override
  void didUpdateWidget(covariant GuestSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) context.read<CafeStore>().ensureGuest(widget.slug);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// GoRouter must not refresh on every catalog save — that tears down overlays
/// and trips InheritedElement `_dependents.isEmpty` on Flutter web.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._store) {
    _auth = _store.authKind;
    _hasAdmin = _store.hasAdmin;
    _store.addListener(_handle);
  }

  final CafeStore _store;
  late AuthKind _auth;
  late bool _hasAdmin;

  void _handle() {
    if (_store.authKind == _auth && _store.hasAdmin == _hasAdmin) return;
    _auth = _store.authKind;
    _hasAdmin = _store.hasAdmin;
    notifyListeners();
  }

  @override
  void dispose() {
    _store.removeListener(_handle);
    super.dispose();
  }
}
