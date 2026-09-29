import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'models/models.dart';
import 'screens/admin_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/cashier_screens.dart';
import 'screens/customer_screens.dart';
import 'screens/sales_log_screen.dart';
import 'screens/dish_availability_screen.dart';
import 'state/cafe_store.dart';
import 'theme/cafe_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final store = CafeStore(AppDatabase.instance);
  try {
    await store.load();
  } catch (error, stack) {
    debugPrint('Startup failed: $error\n$stack');
  }
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
        if (guest) {
          final slug = state.pathParameters['tableId'] ??
              (path.startsWith('/t/') && path.length > 3 ? path.split('/')[2] : null);
          if (slug != null && slug.isNotEmpty && (path.endsWith('/cart') || path.endsWith('/bill'))) {
            final table = widget.store.tableBySlug(slug);
            if (table != null && widget.store.openOrderFor(table.id) == null) {
              return '/t/$slug';
            }
          }
          return null;
        }
        if (auth) return null;
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
            GoRoute(
              path: '/pos',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const CashierDashboardScreen()),
            ),
            GoRoute(
              path: '/pos/tables',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const CashierFloorScreen()),
            ),
            GoRoute(
              path: '/pos/dishes',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const DishAvailabilityScreen()),
            ),
            GoRoute(
              path: '/pos/sales',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const SalesLogScreen(ownSalesOnly: true)),
            ),
            GoRoute(
              path: '/pos/shifts',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const CashierShiftsScreen()),
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/admin/menu',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const AdminMenuScreen()),
            ),
            GoRoute(
              path: '/admin/discounts',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const AdminCategoriesScreen()),
            ),
            GoRoute(path: '/admin/categories', redirect: (_, _) => '/admin/discounts'),
            GoRoute(
              path: '/admin/tables',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const AdminTablesScreen()),
            ),
            GoRoute(
              path: '/admin/sales',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const SalesLogScreen()),
            ),
            GoRoute(
              path: '/admin/dishes',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const DishAvailabilityScreen()),
            ),
            GoRoute(
              path: '/admin/settings',
              pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const AdminSettingsScreen()),
            ),
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
          final surfaces = CafeSurfaces.fromCafe(context.watch<CafeStore>().cafe);
          return Theme(
            data: CafeTheme.forSurfaces(surfaces),
            child: Directionality(
              textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
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
  CafeStore? _store;
  bool _sawOpenOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CafeStore>().ensureGuest(widget.slug);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<CafeStore>();
    if (_store == store) return;
    _store?.removeListener(_onStore);
    _store = store;
    store.addListener(_onStore);
  }

  @override
  void didUpdateWidget(covariant GuestSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _sawOpenOrder = false;
      context.read<CafeStore>().ensureGuest(widget.slug);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    final store = _store;
    if (store == null || !mounted) return;
    final table = store.tableBySlug(widget.slug);
    if (table == null) return;
    if (store.openOrderFor(table.id) != null) {
      _sawOpenOrder = true;
      return;
    }
    if (!_sawOpenOrder || table.status != TableStatus.free) return;
    if (store.cartFor(table.id).lines.isNotEmpty) return;
    _sawOpenOrder = false;
    final path = GoRouterState.of(context).uri.path;
    final menu = '/t/${widget.slug}';
    if (path == menu) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(menu);
    });
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
