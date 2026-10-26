import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'lan/store_hub_host.dart';
import 'navigation/app_sections.dart';
import 'core/report_error.dart';
import 'screens/admin_screens.dart' deferred as admin_ui;
import 'screens/auth_screens.dart' deferred as auth_ui;
import 'screens/cashier_screens.dart' deferred as cashier_ui;
import 'screens/dev_screen.dart';
import 'screens/sales_log_screen.dart' deferred as sales_ui;
import 'screens/dish_availability_screen.dart' deferred as dishes_ui;
import 'state/cafe_store.dart';
import 'theme/cafe_theme.dart';
import 'widgets/tawla_mark.dart';

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
  WaiterHubLink.attach(store);
  // The opening screen below resets the browser address to '/', so remember
  // the page the visitor really asked for (a scanned table QR is /t/<slug>)
  // before anything can overwrite it.
  final initialRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  runApp(StaffBoot(store: store, initialRoute: initialRoute));
}

class StaffBoot extends StatefulWidget {
  const StaffBoot({super.key, required this.store, this.initialRoute = '/'});

  final CafeStore store;
  final String initialRoute;

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
    if (_ready) return TawlaApp(store: widget.store, initialRoute: widget.initialRoute);
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
          const TawlaLoader(size: 88),
          const SizedBox(height: 18),
          Text(l10n?.staffOpening ?? 'Opening...', style: const TextStyle(color: CafeColors.inkMuted)),
        ],
      ),
    );
  }
}

class TawlaApp extends StatefulWidget {
  const TawlaApp({super.key, required this.store, this.initialRoute = '/'});

  final CafeStore store;

  /// The address the app was opened with; '/' means "no specific page".
  final String initialRoute;

  @override
  State<TawlaApp> createState() => _TawlaAppState();
}

class _TawlaAppState extends State<TawlaApp> {
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
      initialLocation: widget.initialRoute.startsWith('/') && widget.initialRoute != '/'
          ? widget.initialRoute
          : (widget.store.hasAdmin ? '/login' : '/admin/setup'),
      refreshListenable: routerRefresh,
      redirect: (_, state) {
        final path = state.uri.path;
        // Guest table links belong to the guest web app (guest-web/); the staff app has no guest pages.
        if (path.startsWith('/t/')) return '/';
        final auth = path == '/login' ||
            path.startsWith('/admin/login') ||
            path.startsWith('/admin/setup') ||
            path.startsWith('/admin/forgot') ||
            path.startsWith('/admin/password');
        if (path == '/dev') {
          final key = state.extra;
          if (key is! String || key.isEmpty) return '/login';
          return null;
        }
        if (auth) return null;
        if (widget.store.authKind == AuthKind.waiter) return AppSections.waiterRedirect(path);
        if (path.startsWith('/pos') && widget.store.authKind != AuthKind.cashier) {
          return '/login';
        }
        // Offline (started without internet) only quick takeout and shift expenses work.
        if (widget.store.offlineSession && path.startsWith('/pos') && path != '/pos/takeout' && path != '/pos/shifts') {
          return '/pos/takeout';
        }
        if (path.startsWith('/admin') && widget.store.authKind != AuthKind.admin) {
          return widget.store.hasAdmin ? '/admin/login' : '/admin/setup';
        }
        // Pages of features not ticked in the installer open the first page that is.
        return AppSections.blockedRedirect(path, widget.store.features);
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, _) => widget.store.hasAdmin || widget.store.serverUnreachable ? '/login' : '/admin/setup',
        ),
        // /c/<cafe> links this browser to that cafe, then opens its sign-in.
        GoRoute(
          path: '/c/:slug',
          redirect: (_, state) async {
            await widget.store.linkDeviceToSlug(state.pathParameters['slug']!);
            return widget.store.hasAdmin ? '/login' : '/admin/setup';
          },
        ),
        GoRoute(
          path: '/c/:slug/admin',
          redirect: (_, state) async {
            await widget.store.linkDeviceToSlug(state.pathParameters['slug']!);
            return widget.store.hasAdmin ? '/admin/login' : '/admin/setup';
          },
        ),
        GoRoute(path: '/login', builder: (_, _) => DeferredView(load: _loadAuth, builder: () => auth_ui.PinLoginScreen())),
        // The developer password travels in state.extra on purpose, never in
        // the URL. A browser refresh loses it and the redirect above sends the
        // page back to /login, so the tools need the password again.
        GoRoute(
          path: '/dev',
          builder: (_, state) => DevScreen(password: state.extra as String),
        ),
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
            // The cashier adds dishes to a table's bill (online, guests can also order by QR).
            GoRoute(
              path: '/pos/tables/:id',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(
                  load: _loadCashier,
                  builder: () => cashier_ui.TableOrderScreen(tableId: state.pathParameters['id']!),
                ),
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
              path: '/admin/stock',
              pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey,
                child: DeferredView(load: _loadAdmin, builder: () => admin_ui.AdminStockScreen()),
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
        title: 'Tawla',
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
