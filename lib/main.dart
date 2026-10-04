import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'report_error.dart';
import 'models/models.dart';
import 'screens/admin_screens.dart' deferred as admin_ui;
import 'screens/auth_screens.dart' deferred as auth_ui;
import 'screens/cashier_screens.dart' deferred as cashier_ui;
import 'screens/customer_screens.dart';
import 'screens/sales_log_screen.dart' deferred as sales_ui;
import 'screens/dish_availability_screen.dart' deferred as dishes_ui;
import 'state/cafe_store.dart';
import 'theme/cafe_theme.dart';
import 'widgets/cafe_widgets.dart';

Future<void> _loadAuth() => auth_ui.loadLibrary();

Future<void> _loadCashier() => cashier_ui.loadLibrary();

Future<void> _loadAdmin() => admin_ui.loadLibrary();

Future<void> _loadPosDishes() => Future.wait([cashier_ui.loadLibrary(), dishes_ui.loadLibrary()]);

Future<void> _loadPosLog() => Future.wait([cashier_ui.loadLibrary(), sales_ui.loadLibrary()]);

Future<void> _loadAdminSales() => Future.wait([admin_ui.loadLibrary(), sales_ui.loadLibrary()]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final store = CafeStore(AppDatabase.instance);
  runApp(StaffBoot(store: store));
}

class StaffBoot extends StatefulWidget {
  const StaffBoot({super.key, required this.store});

  final CafeStore store;

  @override
  State<StaffBoot> createState() => _StaffBootState();
}

class _StaffBootState extends State<StaffBoot> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      await widget.store.load();
    } catch (error, stack) {
      reportError('startup', error, stack);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return CafeItalianoApp(store: widget.store);
    return const StaffOpeningApp();
  }
}

class StaffOpeningApp extends StatelessWidget {
  const StaffOpeningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CafeTheme.light,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: StaffOpeningBody()),
    );
  }
}

class StaffOpeningBody extends StatelessWidget {
  const StaffOpeningBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CafeLogo(size: 72, showWordmark: false),
          const SizedBox(height: 18),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(l10n?.staffOpening ?? 'Opening...', style: const TextStyle(color: CafeColors.inkMuted)),
        ],
      ),
    );
  }
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
  String? _surfaceStamp;
  ThemeData? _surfaceTheme;

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
        GoRoute(path: '/login', builder: (_, _) => DeferredView(load: _loadAuth, builder: () => auth_ui.PinLoginScreen())),
        GoRoute(path: '/admin/setup', builder: (_, _) => DeferredView(load: _loadAuth, builder: () => auth_ui.AdminAuthScreen(setup: true))),
        GoRoute(path: '/admin/login', builder: (_, _) => DeferredView(load: _loadAuth, builder: () => auth_ui.AdminAuthScreen())),
        GoRoute(
          path: '/admin/forgot',
          builder: (_, state) => DeferredView(
            load: _loadAuth,
            builder: () => auth_ui.ForgotPasswordScreen(email: state.extra as String? ?? ''),
          ),
        ),
        GoRoute(
          path: '/admin/password',
          builder: (_, _) => DeferredView(load: _loadAuth, builder: () => auth_ui.ChangePasswordScreen()),
        ),
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
          builder: (context, state, child) => DeferredView(
            load: _loadCashier,
            builder: () => cashier_ui.CashierShell(location: state.uri.path, child: child),
          ),
          routes: [
            GoRoute(
              path: '/pos/takeout',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadCashier, builder: () => cashier_ui.QuickTakeoutScreen()),
              ),
            ),
            GoRoute(
              path: '/pos',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadCashier, builder: () => cashier_ui.CashierDashboardScreen()),
              ),
            ),
            GoRoute(
              path: '/pos/tables',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadCashier, builder: () => cashier_ui.CashierFloorScreen()),
              ),
            ),
            GoRoute(
              path: '/pos/dishes',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadPosDishes, builder: () => dishes_ui.DishAvailabilityScreen()),
              ),
            ),
            GoRoute(
              path: '/pos/log',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadPosLog, builder: () => sales_ui.SalesLogScreen(ownSalesOnly: true)),
              ),
            ),
            GoRoute(path: '/pos/sales', redirect: (_, _) => '/pos/log'),
            GoRoute(
              path: '/pos/shifts',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadCashier, builder: () => cashier_ui.CashierShiftsScreen()),
              ),
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => DeferredView(
            load: _loadAdmin,
            builder: () => admin_ui.AdminShell(location: state.uri.path, child: child),
          ),
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminDashboardScreen()),
              ),
            ),
            GoRoute(
              path: '/admin/menu',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminMenuScreen()),
              ),
            ),
            GoRoute(
              path: '/admin/discounts',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminCategoriesScreen()),
              ),
            ),
            GoRoute(path: '/admin/categories', redirect: (_, _) => '/admin/discounts'),
            GoRoute(
              path: '/admin/tables',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminTablesScreen()),
              ),
            ),
            GoRoute(
              path: '/admin/sales',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdminSales, builder: () => sales_ui.SalesLogScreen()),
              ),
            ),
            GoRoute(
              path: '/admin/wages',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminWagesScreen()),
              ),
            ),
            GoRoute(path: '/admin/dishes', redirect: (_, _) => '/admin/menu'),
            GoRoute(
              path: '/admin/settings',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminSettingsScreen()),
              ),
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
          final stamp = context.select<CafeStore, String>((store) {
            final cafe = store.cafe;
            return '${cafe['headerColor']}|${cafe['sidebarColor']}|${cafe['backgroundColor']}|${cafe['buttonColor']}';
          });
          if (stamp != _surfaceStamp || _surfaceTheme == null) {
            _surfaceStamp = stamp;
            _surfaceTheme = CafeTheme.forSurfaces(CafeSurfaces.fromCafe(context.read<CafeStore>().cafe));
          }
          return Theme(
            data: _surfaceTheme!,
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
  bool _loading = true;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _missing = false;
    });
    await context.read<CafeStore>().ensureGuest(widget.slug);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _missing = context.read<CafeStore>().tableBySlug(widget.slug) == null;
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
      _load();
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    final store = _store;
    if (store == null || !mounted || _loading) return;
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

  Widget _localized(CafeStore store, Widget child) {
    final code = store.guestLocale;
    return Localizations.override(
      context: context,
      locale: Locale(code),
      child: Directionality(
        textDirection: code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    if (_loading) return _localized(store, const GuestLoadingScreen());
    final table = store.tableBySlug(widget.slug);
    if (_missing || table == null) return _localized(store, GuestQrError(onRetry: _load));
    if (store.guestLocaleOverride == null) {
      return _localized(
        store,
        GuestLanguageScreen(onChoose: (code) => store.setGuestLocale(code)),
      );
    }
    return _localized(store, widget.child);
  }
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

/// Loads a deferred library before building its screen. The download starts in
/// the constructor so a shell route can prefetch the chunk before this widget
/// is mounted.
class DeferredView extends StatefulWidget {
  DeferredView({super.key, required Future<void> Function() load, required this.builder})
      : ready = load(),
        reload = load;

  final Future<void> ready;
  final Future<void> Function() reload;
  final Widget Function() builder;

  @override
  State<DeferredView> createState() => _DeferredViewState();
}

class _DeferredViewState extends State<DeferredView> {
  late Future<void> _ready = widget.ready;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => setState(() => _ready = widget.reload()),
                child: Text(AppLocalizations.of(context)!.guestRetry),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: StaffOpeningBody());
        }
        return widget.builder();
      },
    );
  }
}
