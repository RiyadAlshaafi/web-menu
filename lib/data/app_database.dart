import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import '../models/models.dart';
import '../printing/takeout_receipt.dart';
import '../offline/offline_sync.dart' show isNetworkError;
import '../core/time_format.dart';
import '../core/report_error.dart';
import 'error_codes.dart';
import 'image_shrink.dart';
import 'local_env.dart' if (dart.library.io) 'local_env_io.dart';
import 'local_state_store.dart';
import 'sales_archive.dart';
import 'sales_history.dart';

part 'app_database_local.dart';

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _compiledUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL'),
  );
  static const _compiledAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
        defaultValue: String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
      ),
    ),
  );
  static String _fileUrl = '';
  static String _fileAnonKey = '';

  static String get _rawSupabaseUrl {
    if (_compiledUrl.trim().isNotEmpty) return _compiledUrl.trim();
    return _fileUrl.trim();
  }

  static String get supabaseAnonKey {
    if (_compiledAnonKey.trim().isNotEmpty) return _compiledAnonKey.trim();
    return _fileAnonKey.trim();
  }

  static String get supabaseUrl {
    final uri = Uri.tryParse(_rawSupabaseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    return uri.origin;
  }

  bool _ready = false;

  /// Uses the already initialised Supabase client without the app's start-up loads (tests).
  @visibleForTesting
  void useInitialisedClient() => _ready = true;
  bool _listening = false;
  bool _realtimeLive = false;
  bool _realtimeSeenDrop = false;
  int _epoch = 0;
  DateTime? _catalogAt;
  Timer? _liveRefresh;
  RealtimeChannel? _syncChannel;
  RealtimeChannel? _pingChannel;
  /// Called after a change ping; [salesOnly] means only sales data changed (orders, carts,
  /// payments, shifts, tables), so the menu, settings and sign-in need no reload.
  void Function(bool salesOnly)? onLiveChange;

  /// Tables named by the pings since the last live reload; null in it means "unknown".
  final _dirtyTables = <String?>{};

  /// Whether the change-ping channel is connected, so the app may poll rarely.
  bool get liveConnected => _pingLive;
  bool _pingLive = false;

  /// Tables whose changes leave the menu, settings and sign-in as they were.
  static const _salesTables = {
    'orders', 'order_lines', 'carts', 'cart_lines', 'staff_calls', 'payments', 'shifts',
    'shift_expenses', 'dining_tables',
  };
  DateTime? _salesFrom;
  DateTime? _salesTo;

  /// Months the database no longer holds, read from the archive Worker for admins.
  SalesArchiveClient salesArchive = SalesArchiveClient();

  /// Stands in for the admin's sign-in token in tests.
  @visibleForTesting
  String? Function()? archiveTokenOverride;

  /// The chosen sales window reaches archived months that could not be loaded.
  bool salesArchiveFailed = false;
  int _salesLimit = salesPageSize;
  bool salesHasMore = false;
  String? restaurantId;
  String? cashierToken;

  /// Set in offline mode: everything is saved in a local database on this PC (see app_database_local.dart).
  LocalStateStore? _localStore;
  bool get isLocal => _localStore != null;

  /// The cashier signed in on this PC in offline mode (online the server knows it from the session).
  String? localCashierId;
  bool anyAdmin = false;

  /// Web builds for one existing cafe set this (`--dart-define=DEFAULT_SLOT=1`)
  /// so they keep working without anyone linking the browser first.
  static const _defaultSlot = int.fromEnvironment('DEFAULT_SLOT');
  static const _slotPrefKey = 'device_cafe_slot';

  /// The cafe slot (1-8) this install is linked to, and what the database said
  /// about it. The slot only decides which cafe's login and setup screens this
  /// device shows; real access still comes from sign-in, PIN token or QR slug.
  int? boundSlot;
  String? boundRestaurantId;
  String? boundSlug;
  bool boundHasAdmin = false;

  /// Whether the signed-in Supabase user is an admin of a different cafe than
  /// the one this device is linked to.
  bool adminFromOtherCafe = false;

  /// Slot the developer tools are working on (sent as the x-dev-slot header).
  int? devSlot;

  Map<String, dynamic> _cafe = {
    'name': '',
    'serviceChargeRate': 0.0,
    'taxRate': 0,
    'autoPrintReceipt': true,
  };
  String _locale = 'en';
  AdminAccount? _admin;
  bool _rememberAdmin = false;
  List<Cashier> _cashiers = [];
  List<CafeTable> _tables = [];
  List<MenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  List<CafeOrder> _orders = [];
  Map<String, CartState> _carts = {};
  List<Payment> _payments = [];
  List<PaymentType> _paymentTypes = [];
  List<ExpenseCategory> _expenseCategories = [];
  List<CashShift> _shifts = [];
  List<ShiftExpense> _expenses = [];
  List<StaffCall> _calls = [];

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  SupabaseClient? get client => _ready ? Supabase.instance.client : null;

  Map<String, dynamic> get cafe => Map<String, dynamic>.from(_cafe);
  String get locale => _locale;
  AdminAccount? get admin => _admin;
  bool get rememberAdmin => _rememberAdmin;
  List<Cashier> get cashiers => List<Cashier>.from(_cashiers);
  List<CafeTable> get tables => List<CafeTable>.from(_tables);
  List<MenuCategory> get categories => List<MenuCategory>.from(_categories);
  List<MenuItem> get menuItems => List<MenuItem>.from(_menuItems);
  List<CafeOrder> get orders => List<CafeOrder>.from(_orders);
  Map<String, CartState> get carts => Map<String, CartState>.from(_carts);
  List<Payment> get payments => List<Payment>.from(_payments);
  List<PaymentType> get paymentTypes => List<PaymentType>.from(_paymentTypes);
  List<ExpenseCategory> get expenseCategories =>
      List<ExpenseCategory>.from(_expenseCategories);
  List<CashShift> get shifts => List<CashShift>.from(_shifts);
  List<ShiftExpense> get expenses => List<ShiftExpense>.from(_expenses);
  List<StaffCall> get calls => List<StaffCall>.from(_calls);

  /// Offline mode: opens [store] (this PC's local database) instead of the server.
  Future<void> initLocal(LocalStateStore store) async {
    _clear();
    _localStore = store;
    _loadLocal();
  }

  /// [slot] is the cafe slot picked in setup; it wins over a link saved earlier on this device.
  Future<void> init({bool memory = false, int? slot}) async {
    if (memory) {
      _clear();
      return;
    }
    if (_compiledUrl.trim().isEmpty || _compiledAnonKey.trim().isEmpty) {
      final env = await loadLocalEnv();
      _fileUrl = env['SUPABASE_URL'] ?? env['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
      _fileAnonKey =
          env['SUPABASE_ANON_KEY'] ??
          env['SUPABASE_PUBLISHABLE_KEY'] ??
          env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'] ??
          env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
          '';
    }
    if (!isConfigured) {
      debugPrint(
        'Supabase is not configured. For Windows, put SUPABASE_URL and SUPABASE_ANON_KEY in .env or build with tool/build_windows.ps1.',
      );
      _clear();
      return;
    }
    try {
      if (!_ready) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
        _ready = true;
      }
      await _loadBoundSlot(installerSlot: slot);
      _listen();
      await refreshFromDisk();
    } catch (error, stack) {
      reportError('supabase startup', error, stack);
    }
  }

  Future<void> _loadBoundSlot({int? installerSlot}) async {
    int? slot;
    try {
      final prefs = await SharedPreferences.getInstance();
      slot = prefs.getInt(_slotPrefKey);
      if (installerSlot != null && installerSlot != slot) {
        slot = installerSlot;
        await prefs.setInt(_slotPrefKey, installerSlot);
      }
    } catch (error, stack) {
      reportError('read device slot', error, stack);
      slot ??= installerSlot;
    }
    slot ??= _defaultSlot > 0 ? _defaultSlot : null;
    if (slot == null) return;
    try {
      await _resolveBound(slot: slot);
    } catch (error, stack) {
      // E.g. the multi-cafe migration is not applied yet. Stay unlinked and
      // carry on loading instead of aborting startup.
      reportError('resolve cafe slot', error, stack);
    }
  }

  Future<void> _resolveBound({int? slot, String? slug}) async {
    if (client == null) return;
    final raw = slot != null
        ? await client!.rpc('restaurant_for_slot', params: {'p_slot': slot})
        : await client!.rpc('restaurant_for_slug', params: {'p_slug': slug});
    final rows = raw is List ? raw : const [];
    if (rows.isEmpty) {
      boundSlot = null;
      boundRestaurantId = null;
      boundSlug = null;
      boundHasAdmin = false;
      return;
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    boundSlot = (row['slot'] as num?)?.toInt() ?? slot;
    boundRestaurantId = row['id'] as String?;
    boundSlug = row['slug'] as String?;
    boundHasAdmin = row['has_admin'] as bool? ?? false;
  }

  /// Links this install to cafe [slot], remembers it, and reloads.
  Future<String?> bindSlot(int slot) async {
    try {
      await _resolveBound(slot: slot);
      if (boundRestaurantId == null) return 'That cafe slot does not exist.';
      await (await SharedPreferences.getInstance()).setInt(_slotPrefKey, slot);
      _epoch++;
      await refreshFromDisk();
      return null;
    } catch (error, stack) {
      reportError('bind slot', error, stack);
      return _errorCode(error);
    }
  }

  /// Links a browser session to the cafe at `/c/slug`.
  Future<bool> bindSlug(String slug) async {
    try {
      await _resolveBound(slug: slug);
      final slot = boundSlot;
      if (boundRestaurantId == null || slot == null) return false;
      await (await SharedPreferences.getInstance()).setInt(_slotPrefKey, slot);
      _epoch++;
      await refreshFromDisk();
      return true;
    } catch (error, stack) {
      reportError('bind slug', error, stack);
      return false;
    }
  }

  Future<void> resetEmpty() async {
    _clear();
    if (_ready) await client!.auth.signOut();
  }

  void _clear() {
    restaurantId = null;
    cashierToken = null;
    anyAdmin = false;
    adminFromOtherCafe = false;
    _cafe = {'name': '', 'serviceChargeRate': 0.0, 'taxRate': 0, 'autoPrintReceipt': true};
    _locale = 'en';
    _admin = null;
    _cashiers = [];
    _tables = [];
    _categories = [];
    _menuItems = [];
    _orders = [];
    _carts = {};
    _payments = [];
    _paymentTypes = [];
    _shifts = [];
    _expenses = [];
    _calls = [];
  }

  void startRealtime() => _listen();

  void stopRealtime() {
    _liveRefresh?.cancel();
    _liveRefresh = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    final channel = _syncChannel;
    final ping = _pingChannel;
    _syncChannel = null;
    _pingChannel = null;
    _pingLive = false;
    _dirtyTables.clear();
    _listening = false;
    _listenRestaurantId = null;
    _realtimeLive = false;
    _realtimeSeenDrop = false;
    if (channel != null) {
      client?.removeChannel(channel);
    }
    if (ping != null) {
      client?.removeChannel(ping);
    }
  }

  /// The broadcast topic this device hears change pings on (sent by the database, see
  /// migration 20261013100000_live_update_pings). A guest hears only its own table; cashier and
  /// admin devices hear their whole cafe. Pings carry no data: the app reloads through normal,
  /// policy-checked requests.
  static String liveTopic({required String restaurantId, String? guestSlug}) =>
      guestSlug != null && guestSlug.isNotEmpty ? 'guest:$guestSlug' : 'cafe:$restaurantId';

  void _emitLive() {
    // A ping names only the first table its change touched; sales tables change together.
    final salesOnly = _dirtyTables.isNotEmpty && _dirtyTables.every(_salesTables.contains);
    _dirtyTables.clear();
    final hook = onLiveChange;
    if (hook != null) {
      hook(salesOnly);
    } else {
      refreshFromDisk(liveOnly: true, salesOnly: salesOnly);
    }
  }

  /// The table a broadcast ping names ({"table": ...}, maybe wrapped in the message).
  static String? _pingTable(Map<String, dynamic> message) {
    final inner = message['payload'];
    final table = message['table'] ?? (inner is Map ? inner['table'] : null);
    return table is String ? table : null;
  }

  /// Tables whose changes refresh this device, all carrying `restaurant_id`.
  static const _liveTables = [
    'orders',
    'order_lines',
    'carts',
    'cart_lines',
    'staff_calls',
    'menu_items',
    'menu_categories',
    'dining_tables',
    'shift_expenses',
    'shifts',
    'payments',
    'payment_types',
    'expense_categories',
  ];

  /// The cafe the open realtime channels are for.
  String? _listenRestaurantId;

  /// Subscribes to this cafe's changes only. Without a cafe yet nothing is subscribed; [_relistenIfCafeChanged] opens the
  /// channel once the cafe is known.
  void _listen() {
    if (_listening || client == null) return;
    final rid = restaurantId ?? boundRestaurantId;
    if (rid == null) return;
    try {
      _listening = true;
      _listenRestaurantId = rid;
      void scheduleLive(String? table) {
        _dirtyTables.add(table);
        _liveRefresh?.cancel();
        _liveRefresh = Timer(const Duration(milliseconds: 300), _emitLive);
      }

      var channel = client!.channel('cafe-sync:$rid');
      for (final table in _liveTables) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: rid,
          ),
          callback: (change) => scheduleLive(change.table),
        );
      }
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'restaurants',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: rid,
        ),
        callback: (_) => scheduleLive('restaurants'),
      );
      // Row changes reach only signed-in admins: cashier and guest policies read request
      // headers, which Realtime never sets. Everyone gets the database's change pings below.
      _syncChannel = channel.subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          final reconnect = _realtimeSeenDrop;
          _realtimeSeenDrop = false;
          _realtimeLive = true;
          if (reconnect) _emitLive();
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          if (_realtimeLive) _realtimeSeenDrop = true;
          _realtimeLive = false;
        }
      });
      var pingDropped = false;
      _pingChannel = client!
          .channel(liveTopic(restaurantId: rid))
          .onBroadcast(event: 'change', callback: (message) => scheduleLive(_pingTable(message)))
          .subscribe((status, _) {
            _pingLive = status == RealtimeSubscribeStatus.subscribed;
            if (status == RealtimeSubscribeStatus.subscribed) {
              // Back after a drop: catch up on anything missed while disconnected.
              if (pingDropped) _emitLive();
              pingDropped = false;
            } else if (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              pingDropped = true;
            }
          });
    } catch (error, stack) {
      _listening = false;
      _syncChannel = null;
      _pingChannel = null;
      _listenRestaurantId = null;
        reportError('realtime setup', error, stack);
    }
  }

  /// Reopens the channel when the device's cafe changed (sign-in, relink), so it never listens to the wrong cafe.
  void _relistenIfCafeChanged() {
    if (onLiveChange == null && !_listening) return;
    final rid = restaurantId ?? boundRestaurantId;
    if (rid == _listenRestaurantId) return;
    stopRealtime();
    _listen();
  }

  void _applyHeaders() {
    final current = client;
    if (current == null) return;
    final headers = Map<String, String>.from(current.headers)
      ..remove('x-qr-slug')
      ..remove('x-cashier-token')
      ..remove('x-dev-slot');
    if (devSlot != null) headers['x-dev-slot'] = '$devSlot';
    if (cashierToken != null) headers['x-cashier-token'] = cashierToken!;
    current.headers = headers;
  }

  Future<void>? _refreshInFlight;
  bool _refreshRerun = false;
  bool _refreshRerunFull = false;
  bool _refreshRerunWide = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// Reloads data, one run at a time. A call that arrives while a load is
  /// running does not start a second, racing load: it queues one more run that
  /// starts after the current one and returns a future covering both. That
  /// keeps an older, slower load from overwriting newer data, and guarantees a
  /// caller that just wrote something reads it back.
  /// [salesOnly] (with [liveOnly]) reloads only orders, carts, payments, shifts and tables.
  Future<void> refreshFromDisk({bool liveOnly = false, bool salesOnly = false}) {
    if (client == null || offlineMode) return Future<void>.value();
    final running = _refreshInFlight;
    if (running != null) {
      _refreshRerun = true;
      if (!liveOnly) _refreshRerunFull = true;
      if (!salesOnly) _refreshRerunWide = true;
      return running;
    }
    final run = _runRefreshes(liveOnly, salesOnly).whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = run;
    return run;
  }

  Future<void> _runRefreshes(bool liveOnly, bool salesOnly) async {
    var live = liveOnly;
    var sales = liveOnly && salesOnly;
    var interrupted = 0;
    do {
      _refreshRerun = false;
      final catalogFresh =
          _catalogAt != null &&
          DateTime.now().difference(_catalogAt!) < const Duration(seconds: 60);
      var failed = false;
      var completed = true;
      try {
        // Sales-only needs the menu and settings loaded once; menu changes send their own ping.
        completed = sales && _catalogAt != null && loadedOnce
            ? await _refreshFromDisk(liveOnly: true, salesOnly: true)
            : await _refreshFromDisk(liveOnly: live && catalogFresh);
      } catch (error, stack) {
        failed = true;
        reportError('supabase refresh', error, stack);
      }
      if (!completed && interrupted < 3) {
        // A save landed mid-load and the results were dropped, which used to
        // leave screens empty or stale until the next live update. Let the
        // save finish, then load again.
        interrupted++;
        await _cartWrites.timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
        _refreshRerun = true;
        if (!live) _refreshRerunFull = true;
        if (!sales) _refreshRerunWide = true;
      }
      _afterRefresh(failed: failed);
      live = !_refreshRerunFull;
      sales = live && !_refreshRerunWide;
      _refreshRerunFull = false;
      _refreshRerunWide = false;
    } while (_refreshRerun);
  }

  /// A failed load used to leave the app empty until the next manual refresh.
  /// Retry with a growing delay (2s, 4s, 8s ... up to 30s), then tell the store
  /// there is new data once it finally succeeds.
  void _afterRefresh({required bool failed}) {
    if (!failed) {
      _retryTimer?.cancel();
      _retryTimer = null;
      if (_retryAttempt > 0) {
        _retryAttempt = 0;
        _emitLive();
      }
      return;
    }
    if (_retryTimer != null) return;
    final seconds = (2 << _retryAttempt.clamp(0, 4)).clamp(2, 30);
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      unawaited(refreshFromDisk());
    });
  }

  Future<void> _loadRestaurant() async {
    final id = restaurantId;
    if (id == null || client == null) return;
    final restaurant = await client!
        .from('restaurants')
        .select(
          'name, locale, service_charge_rate, tax_rate, logo_url, public_menu_url, header_color, sidebar_color, background_color, button_color, auto_print_receipt, require_cashier_online',
        )
        .eq('id', id)
        .maybeSingle();
    if (restaurant == null) return;
    _locale = restaurant['locale'] as String? ?? 'en';
    _cafe = {
      'name': restaurant['name'] ?? '',
      'logoUrl': restaurant['logo_url'] ?? '',
      'publicMenuUrl': restaurant['public_menu_url'] ?? '',
      'headerColor': restaurant['header_color'] ?? '',
      'sidebarColor': restaurant['sidebar_color'] ?? '',
      'backgroundColor': restaurant['background_color'] ?? '',
      'buttonColor': restaurant['button_color'] ?? '',
      'serviceChargeRate':
          (restaurant['service_charge_rate'] as num?)?.toDouble() ?? 0,
      'taxRate': (restaurant['tax_rate'] as num?)?.toDouble() ?? 0,
      'autoPrintReceipt': restaurant['auto_print_receipt'] as bool? ?? true,
      'requireCashierOnline': restaurant['require_cashier_online'] as bool? ?? false,
    };
  }

  Future<List<dynamic>?> _selectOrEmpty(Future<dynamic> query, String label) async {
    try {
      return await query as List;
    } catch (error, stackTrace) {
      reportError(label, error, stackTrace);
      return null;
    }
  }

  List<PaymentType> _mapPaymentTypes(List? rows) => rows == null
      ? []
      : [
          for (final row in rows)
            PaymentType(
              id: row['id'] as String,
              nameEn: row['name_en'] as String? ?? '',
              nameAr: row['name_ar'] as String? ?? '',
              enabled: row['enabled'] as bool? ?? true,
              sortOrder: row['sort_order'] as int? ?? 0,
              archived: row['archived'] as bool? ?? false,
            ),
        ];

  /// True once data has been loaded successfully at least once this run.
  bool loadedOnce = false;

  /// Retries the first load for up to [timeout] so the app does not open empty
  /// because of a slow or briefly failing network. Returns when data is loaded
  /// or time runs out; the normal retry loop keeps going afterwards.
  Future<void> waitForFirstLoad(Duration timeout) async {
    if (client == null) return;
    final deadline = DateTime.now().add(timeout);
    while (!loadedOnce && DateTime.now().isBefore(deadline)) {
      await refreshFromDisk();
      if (loadedOnce) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Who is signed in and which cafe this device shows, from the profile and table rows.
  void _applySignIn(User? user, Map<String, dynamic>? profile, List tableList) {
    final profileRestaurant = profile?['restaurant_id'] as String?;
    // A device linked to a cafe slot only accepts that cafe's admin; an admin
    // of another cafe must not sign in here (e.g. on an empty slot).
    adminFromOtherCafe =
        user != null &&
        boundRestaurantId != null &&
        profileRestaurant != boundRestaurantId;
    if (adminFromOtherCafe) {
      restaurantId = boundRestaurantId;
      _admin = null;
      _rememberAdmin = false;
    } else if (user != null) {
      restaurantId = profileRestaurant;
      _admin = AdminAccount(
        email: user.email ?? '',
        displayName: profile?['display_name'] as String? ?? 'Admin',
      );
      _rememberAdmin = true;
    } else if (cashierToken == null) {
      _admin = null;
      _rememberAdmin = false;
    }
    restaurantId ??= boundRestaurantId;
    if (restaurantId == null && boundSlot == null && tableList.isNotEmpty) {
      // Only an unlinked device falls back to whatever table is visible.
      restaurantId = tableList.first['restaurant_id'] as String?;
    }
  }

  /// Loads everything. Returns false when a local save happened mid-load and
  /// the (now stale) results were dropped, so the caller should load again.
  Future<bool> _refreshFromDisk({bool liveOnly = false, bool salesOnly = false}) async {
    final epoch = _epoch;
    final watch = Stopwatch()..start();
    _applyHeaders();
    final user = client!.auth.currentUser;
    final cafeId = restaurantId ?? boundRestaurantId;
    final opened = await Future.wait<dynamic>([
      // An unlinked device has no cafe whose admin it could sign in, so it
      // is sent to the setup screen, which asks for the device to be linked.
      salesOnly || cafeId == null
          ? Future<dynamic>.value(salesOnly ? anyAdmin : false)
          : client!.rpc('has_any_admin', params: {'p_restaurant_id': cafeId}),
      if (user != null && !salesOnly)
        client!
            .from('profiles')
            .select('restaurant_id, display_name')
            .eq('id', user.id)
            .maybeSingle()
      else
        Future<dynamic>.value(null),
      client!.from('dining_tables').select(),
    ]);
    if (epoch != _epoch) return false;
    anyAdmin = opened[0] as bool? ?? false;
    final profile = opened[1] as Map<String, dynamic>?;
    final tableList = opened[2] as List;
    if (!salesOnly) _applySignIn(user, profile, tableList);
    if (restaurantId == null) {
      _tables = [];
      _categories = [];
      _menuItems = [];
      _orders = [];
      _carts = {};
      _payments = [];
      _shifts = [];
      _expenses = [];
      _calls = [];
      loadedOnce = true; // Nothing to load for an unlinked device is still a result.
      return true;
    }
    if (epoch != _epoch) return false;
    _tables = tableList
        .map(
          (row) => CafeTable(
            id: row['id'] as String,
            number: row['number'] as String,
            qrSlug: row['qr_slug'] as String,
            zone: row['zone'] as String? ?? 'Main Floor',
            seats: row['seats'] as int? ?? 4,
            status: TableStatus.values.firstWhere(
              (value) => value.name == row['status'],
              orElse: () => TableStatus.free,
            ),
            guests: row['guests'] as int? ?? 0,
            archived: row['archived'] as bool? ?? false,
          ),
        )
        .toList();
    final staffed = client!.auth.currentUser != null || cashierToken != null;
    final historyFrom = _salesFrom ?? salesHistoryCutoff(DateTime.now());
    // Sales-only skips the cafe settings, menu, payment and expense types (index 0, 2, 5, 6).
    final batch = await Future.wait<dynamic>([
      salesOnly ? Future<dynamic>.value(null) : _loadRestaurant(),
      liveOnly ? Future<dynamic>.value(null) : client!.from('menu_categories').select(),
      salesOnly
          ? Future<dynamic>.value(null)
          : liveOnly
          ? client!.from('menu_items').select(
              'id, name_it, name_en, description, price, category_id, image_url, available, sold_out, featured, sort_order, discount_percent, discount_applied, options, stock_qty',
            )
          : client!.from('menu_items').select(),
      // Only carts that hold something; empty carts outnumber them and
      // change nothing on staff screens.
      client!.from('carts').select('*, cart_lines!inner(*)'),
      _selectCalls(),
      salesOnly
          ? Future<dynamic>.value(null)
          : _selectOrEmpty(client!.from('payment_types').select().order('sort_order', ascending: true), 'payment types'),
      salesOnly
          ? Future<dynamic>.value(null)
          : _selectOrEmpty(client!.from('expense_categories').select().order('sort_order', ascending: true), 'expense categories'),
      staffed
          ? client!
                .from('shift_expenses')
                .select()
                .gte('created_at', historyFrom.toUtc().toIso8601String())
                .order('created_at')
          : Future<dynamic>.value(null),
      _loadOrders(historyFrom, const {}),
      staffed ? _selectShifts(historyFrom) : Future<dynamic>.value(null),
      // An unlinked device has no cafe to list cashiers for.
      (!liveOnly && restaurantId != null)
          ? client!.rpc('list_pos_cashiers', params: {'p_restaurant_id': restaurantId})
          : Future<dynamic>.value(null),
      staffed ? _selectPayments(historyFrom, _salesTo, _salesLimit) : Future<dynamic>.value(null),
    ]);
    if (epoch != _epoch) return false;
    if (!liveOnly) {
      final categoryRows = batch[1] as List;
      _categories = categoryRows
          .map(
            (row) => MenuCategory(
              id: row['id'] as String,
              nameEn: row['name_en'] as String? ?? '',
              nameAr: row['name_ar'] as String? ?? '',
              sortOrder: row['sort_order'] as int? ?? 0,
              spotlight: row['spotlight'] as bool? ?? false,
              visible: row['visible'] as bool? ?? true,
            ),
          )
          .toList();
      final staffRaw = batch[10];
      final staff = staffRaw is List ? staffRaw : <dynamic>[];
      _cashiers = staff.map((row) {
        final map = row as Map<String, dynamic>;
        return Cashier(
          id: map['id'] as String,
          name: map['name'] as String,
          initials: map['initials'] as String? ?? 'C',
        );
      }).toList();
    }
    final itemRows = batch[2] as List?;
    if (itemRows != null) {
      _menuItems = itemRows
          .map(
            (row) => MenuItem(
              id: row['id'] as String,
              nameIt: row['name_it'] as String? ?? '',
              nameEn: row['name_en'] as String? ?? '',
              description: row['description'] as String? ?? '',
              price: (row['price'] as num).toDouble(),
              categoryId: row['category_id'] as String,
              imageUrl: row['image_url'] as String? ?? '',
              available: row['available'] as bool? ?? true,
              soldOut: row['sold_out'] as bool? ?? false,
              featured: row['featured'] as bool? ?? false,
              sortOrder: row['sort_order'] as int? ?? 0,
              discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
              discountApplied: row['discount_applied'] as bool? ?? false,
              options: parseJsonList(row['options'], DishOption.fromJson),
              stockQty: (row['stock_qty'] as num?)?.toInt(),
            ),
          )
          .toList();
    }
    if (!liveOnly) _catalogAt = DateTime.now();
    final cartRows = batch[3] as List;
    _carts = {
      for (final row in cartRows)
        row['table_id'] as String: CartState(
          tableId: row['table_id'] as String,
          lines: ((row['cart_lines'] as List?) ?? [])
              .map(
                (line) => OrderLine(
                  menuItemId: line['menu_item_id'] as String? ?? '',
                  name: line['name'] as String? ?? '',
                  qty: (line['qty'] as num?)?.toInt() ?? 1,
                  unitPrice: _asDouble(line['unit_price']) ?? 0,
                  listUnitPrice: _asDouble(line['list_unit_price']),
                  choices: parseJsonList(line['choices'], LineChoice.fromJson),
                ),
              )
              .toList(),
        ),
    };
    final callRows = batch[4] as List;
    _calls = callRows.map((row) {
      final table = _tables.where((item) => item.id == row['table_id']);
      return StaffCall(
        id: row['id'] as String,
        tableId: row['table_id'] as String,
        tableNumber: table.isEmpty ? '' : table.first.number,
        createdAt: DateTime.parse(row['created_at'] as String),
        kind: row['kind'] as String? ?? 'assistance',
        resolved: row['resolved'] as bool? ?? false,
      );
    }).toList();
    if (!salesOnly) _paymentTypes = _mapPaymentTypes(batch[5] as List?);
    final expenseCategoryRows = batch[6] as List?;
    if (!salesOnly) {
      _expenseCategories = expenseCategoryRows == null
          ? []
          : expenseCategoryRows
                .map(
                  (row) => ExpenseCategory(
                    id: row['id'] as String,
                    nameEn: row['name_en'] as String? ?? '',
                    nameAr: row['name_ar'] as String? ?? '',
                    enabled: row['enabled'] as bool? ?? true,
                    sortOrder: row['sort_order'] as int? ?? 0,
                  ),
                )
                .toList();
    }
    _orders = (batch[8] as List).cast<CafeOrder>();
    if (staffed) {
      final expenseRows = batch[7] as List;
      _expenses = expenseRows
          .map((row) => _mapExpense(Map<String, dynamic>.from(row as Map)))
          .toList();
      final paymentRows = batch[11] as List;
      if (epoch != _epoch) return false;
      salesHasMore = paymentRows.length >= _salesLimit;
      final paymentIds = [for (final row in paymentRows) row['id'] as String];
      final changes = await _changesFor(paymentIds);
      _payments = [
        for (final row in paymentRows)
          _mapPayment(Map<String, dynamic>.from(row as Map), changes),
      ];
      final missingOrders = _payments
          .map((payment) => payment.orderId)
          .where((id) => _orders.every((order) => order.id != id))
          .toSet();
      if (missingOrders.isNotEmpty) {
        final extra = await _ordersById(missingOrders);
        _orders = [..._orders, ...extra];
      }
      final shiftRows = batch[9] as List;
      _shifts = [for (final row in shiftRows) _mapShift(Map<String, dynamic>.from(row as Map))];
      if (_salesFrom != null) {
        if (!await _mergeArchive(historyFrom, _salesTo ?? DateTime.now(), epoch)) return false;
      } else {
        salesArchiveFailed = false;
      }
    } else {
      _payments = [];
      _shifts = [];
      _expenses = [];
      salesHasMore = false;
    }
    _rememberWritten();
    _relistenIfCafeChanged();
    loadedOnce = true;
    if (kDebugMode) {
      debugPrint('refreshFromDisk ${watch.elapsedMilliseconds}ms liveOnly=$liveOnly');
    }
    return true;
  }

  /// Open calls plus the last day of resolved ones; older calls are history
  /// nobody reads on a till.
  Future<List<dynamic>> _selectCalls() async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();
    return await client!
            .from('staff_calls')
            .select()
            .or('resolved.eq.false,created_at.gte.$since')
            .order('created_at', ascending: false)
            .limit(500)
        as List;
  }

  /// Open shifts plus those opened inside the sales window.
  Future<List<dynamic>> _selectShifts(DateTime from) async {
    return await client!
            .from('shifts')
            .select()
            .or('closed_at.is.null,opened_at.gte.${from.toUtc().toIso8601String()}')
            .order('opened_at', ascending: false)
        as List;
  }

  Future<void> loadMoreSales() async {
    if (client == null || !salesHasMore) return;
    _salesLimit += salesPageSize;
    await refreshFromDisk(liveOnly: true);
  }

  Future<void> alignSalesWindow({DateTime? from, DateTime? to}) async {
    if (client == null) return;
    final cutoff = salesHistoryCutoff(DateTime.now());
    final start = from == null ? null : tripoliDayStartUtc(from);
    final nextFrom = start != null && start.isBefore(cutoff) ? start : null;
    final nextTo = nextFrom != null && to != null ? tripoliDayEndUtc(to) : null;
    if (nextFrom == _salesFrom && nextTo == _salesTo) return;
    _salesFrom = nextFrom;
    _salesTo = nextTo;
    _salesLimit = salesPageSize;
    await refreshFromDisk(liveOnly: true);
  }

  Future<List<dynamic>> _selectPayments(
    DateTime from,
    DateTime? to,
    int limit,
  ) async {
    final fromIso = from.toUtc().toIso8601String();
    if (to == null) {
      return await client!
              .from('payments')
              .select()
              .gte('paid_at', fromIso)
              .order('paid_at', ascending: false)
              .range(0, limit - 1)
          as List;
    }
    return await client!
            .from('payments')
            .select()
            .gte('paid_at', fromIso)
            .lte('paid_at', to.toUtc().toIso8601String())
            .order('paid_at', ascending: false)
            .range(0, limit - 1)
        as List;
  }

  Future<Map<String, List<PaymentMethodChange>>> _changesFor(
    List<String> paymentIds,
  ) async {
    final changes = <String, List<PaymentMethodChange>>{};
    const chunk = 80;
    for (var start = 0; start < paymentIds.length; start += chunk) {
      final end = start + chunk > paymentIds.length
          ? paymentIds.length
          : start + chunk;
      final rows = await client!
          .from('payment_method_changes')
          .select()
          .inFilter('payment_id', paymentIds.sublist(start, end));
      for (final row in rows as List) {
        final change = _mapChange(Map<String, dynamic>.from(row as Map));
        changes.putIfAbsent(change.paymentId, () => []).add(change);
      }
    }
    return changes;
  }

  CashShift _mapShift(Map<String, dynamic> row) => CashShift(
    id: row['id'] as String,
    cashierId: row['cashier_id'] as String? ?? '',
    openedAt: DateTime.parse(row['opened_at'] as String),
    closedAt: row['closed_at'] == null ? null : DateTime.parse(row['closed_at'] as String),
    openingCash: (row['opening_cash'] as num?)?.toDouble() ?? 0,
    cashSales: (row['cash_sales'] as num?)?.toDouble() ?? 0,
    cashRefunds: (row['cash_refunds'] as num?)?.toDouble() ?? 0,
    cashAdjustments: (row['cash_adjustments'] as num?)?.toDouble() ?? 0,
    actualCash: (row['actual_cash'] as num?)?.toDouble(),
    transactionCount: row['transaction_count'] as int? ?? 0,
  );

  PaymentMethodChange _mapChange(Map<String, dynamic> row) => PaymentMethodChange(
    id: row['id'] as String,
    paymentId: row['payment_id'] as String,
    oldTypeId: row['old_type_id'] as String?,
    newTypeId: row['new_type_id'] as String?,
    actorName: row['actor_name'] as String? ?? '',
    actorRole: row['actor_role'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  /// Adds the archived months (moved out of the database, see tool/archive_months.sh) that the
  /// chosen sales window reaches. Only a signed-in admin can read them; if they can't be loaded
  /// the live rows stay and [salesArchiveFailed] is set. False when a newer load started meanwhile.
  Future<bool> _mergeArchive(DateTime from, DateTime to, int epoch) async {
    salesArchiveFailed = false;
    final token = archiveTokenOverride?.call() ?? client!.auth.currentSession?.accessToken;
    if (token == null) return true;
    final months = monthsBetween(from, to);
    try {
      final rows =
          await client!
                  .from('archived_months')
                  .select('year_month')
                  .gte('year_month', months.first)
                  .lte('year_month', months.last)
              as List;
      final archived = {for (final row in rows) row['year_month'] as String}.toList()..sort();
      final loaded = [for (final month in archived) await salesArchive.month(month, token)];
      if (epoch != _epoch) return false;
      for (final sales in loaded) {
        _addArchived(sales, from, to);
      }
    } catch (error, stack) {
      salesArchiveFailed = true;
      reportError('sales archive', error, stack);
    }
    return true;
  }

  /// Merges archived rows inside [from]..[to] that are not already loaded.
  void _addArchived(ArchivedSales sales, DateTime from, DateTime to) {
    bool inWindow(Object? at) {
      final time = DateTime.tryParse(at as String? ?? '');
      return time != null && !time.isBefore(from) && !time.isAfter(to);
    }

    final changes = <String, List<PaymentMethodChange>>{};
    for (final row in sales.changes) {
      final change = _mapChange(row);
      changes.putIfAbsent(change.paymentId, () => []).add(change);
    }
    final knownPayments = {for (final payment in _payments) payment.id};
    final added = [
      for (final row in sales.payments)
        if (inWindow(row['paid_at']) && !knownPayments.contains(row['id'])) _mapPayment(row, changes),
    ];
    _payments = [..._payments, ...added]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final wanted = {for (final payment in added) payment.orderId}..removeAll(_orders.map((order) => order.id));
    _orders = [
      ..._orders,
      for (final row in sales.orders)
        if (wanted.remove(row['id'])) _mapOrder(row),
    ];
    final knownShifts = {for (final shift in _shifts) shift.id};
    _shifts = [
      ..._shifts,
      for (final row in sales.shifts)
        if ((inWindow(row['opened_at']) || inWindow(row['closed_at'])) && knownShifts.add(row['id'] as String))
          _mapShift(row),
    ];
    final knownExpenses = {for (final expense in _expenses) expense.id};
    _expenses = [
      ..._expenses,
      for (final row in sales.expenses)
        if (inWindow(row['created_at']) && knownExpenses.add(row['id'] as String)) _mapExpense(row),
    ];
  }

  Payment _mapPayment(
    Map<String, dynamic> row,
    Map<String, List<PaymentMethodChange>> changes,
  ) {
    final id = row['id'] as String;
    final history = changes[id] ?? [];
    history.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Payment(
      id: id,
      orderId: row['order_id'] as String,
      tableId: row['table_id'] as String? ?? '',
      tableNumber: row['table_number'] as String? ?? '',
      isTakeout: row['is_takeout'] as bool? ?? false,
      cashierName: row['cashier_name'] as String? ?? '',
      paymentTypeNameEn: row['payment_type_name_en'] as String?,
      paymentTypeNameAr: row['payment_type_name_ar'] as String?,
      totalDue: (row['total_due'] as num).toDouble(),
      cashReceived: (row['cash_received'] as num).toDouble(),
      changeDue: (row['change_due'] as num).toDouble(),
      cashierId: row['cashier_id'] as String? ?? '',
      shiftId: row['shift_id'] as String,
      paidAt: DateTime.parse(row['paid_at'] as String),
      paymentTypeId: row['payment_type_id'] as String?,
      yearMonth: row['year_month'] as String?,
      shiftOrderNumber: (row['shift_order_number'] as num?)?.toInt(),
      monthlyOrderNumber: (row['monthly_order_number'] as num?)?.toInt(),
      shiftDisplayNumber: row['shift_display_number'] as String?,
      monthlyDisplayNumber: row['monthly_display_number'] as String?,
      voidedAt: DateTime.tryParse(row['voided_at'] as String? ?? ''),
      voidReason: row['void_reason'] as String?,
      changes: history,
    );
  }

  Future<List<CafeOrder>> _loadOrders(
    DateTime from,
    Set<String> extraIds,
  ) async {
    final openRows = await client!
        .from('orders')
        .select('*, order_lines(*)')
        .neq('status', 'paid');
    final paidRows = await client!
        .from('orders')
        .select('*, order_lines(*)')
        .eq('status', 'paid')
        .gte('created_at', from.toUtc().toIso8601String());
    final mapped = <String, CafeOrder>{};
    for (final row in [...openRows as List, ...paidRows as List]) {
      final order = _mapOrder(Map<String, dynamic>.from(row as Map));
      mapped[order.id] = order;
    }
    final missing = extraIds.where((id) => !mapped.containsKey(id)).toSet();
    for (final order in await _ordersById(missing)) {
      mapped[order.id] = order;
    }
    return mapped.values.toList();
  }

  Future<List<CafeOrder>> _ordersById(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await client!
        .from('orders')
        .select('*, order_lines(*)')
        .inFilter('id', ids.toList());
    return [
      for (final row in rows as List)
        _mapOrder(Map<String, dynamic>.from(row as Map)),
    ];
  }

  CafeOrder _mapOrder(Map<String, dynamic> row) {
    final table = _tables.where((item) => item.id == row['table_id']);
    return CafeOrder(
      id: row['id'] as String,
      tableId: row['table_id'] as String? ?? '',
      // The number saved with the order wins, so a deleted table can't blank or duplicate it.
      tableNumber: (row['table_number'] as String? ?? '').isNotEmpty
          ? row['table_number'] as String
          : (table.isEmpty ? '' : table.first.number),
      status: OrderStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => OrderStatus.received,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      notes: row['notes'] as String? ?? '',
      cashierId: row['cashier_id'] as String?,
      awaitingCustomerConfirmation:
          row['awaiting_customer_confirmation'] as bool? ?? false,
      refusalNotice: row['refusal_notice'] as String? ?? '',
      paymentTypeId: row['payment_type_id'] as String?,
      serviceType: row['service_type'] as String? ?? 'dine_in',
      yearMonth: row['year_month'] as String?,
      shiftOrderNumber: (row['shift_order_number'] as num?)?.toInt(),
      lines: ((row['order_lines'] as List?) ?? []).map((line) {
        final map = Map<String, dynamic>.from(line as Map);
        return OrderLine(
          menuItemId: map['menu_item_id'] as String? ?? '',
          name: map['name'] as String? ?? '',
          qty: (map['qty'] as num?)?.toInt() ?? 1,
          unitPrice: _asDouble(map['unit_price']) ?? 0,
          listUnitPrice: _asDouble(map['list_unit_price']),
          round: (map['round'] as num?)?.toInt() ?? 1,
          id: map['id'] as String?,
          choices: parseJsonList(map['choices'], LineChoice.fromJson),
        );
      }).toList(),
    );
  }

  Future<void> writeRememberAdmin(bool value) async => _rememberAdmin = value;

  void _saveLocalSettingsIfLocal() {
    if (isLocal) _saveLocalCatalog();
  }

  Future<void> writeAutoPrintReceipt(bool value) async {
    _cafe = {..._cafe, 'autoPrintReceipt': value};
    _saveLocalSettingsIfLocal();
    if (client == null || restaurantId == null) return;
    await client!.from('restaurants').update({'auto_print_receipt': value}).eq('id', restaurantId!);
  }

  Future<void> writeRequireCashierOnline(bool value) async {
    _cafe = {..._cafe, 'requireCashierOnline': value};
    _saveLocalSettingsIfLocal();
    if (client == null || restaurantId == null) return;
    await client!.from('restaurants').update({'require_cashier_online': value}).eq('id', restaurantId!);
  }

  Future<void> writeLocale(String locale) async {
    _locale = locale;
    _saveLocalSettingsIfLocal();
    if (client == null || restaurantId == null) return;
    await client!
        .from('restaurants')
        .update({'locale': locale})
        .eq('id', restaurantId!);
  }

  Future<void> writeCafe(Map<String, dynamic> cafe) async {
    _cafe = Map<String, dynamic>.from(cafe);
    _saveLocalSettingsIfLocal();
    if (client == null || restaurantId == null) return;
    await client!
        .from('restaurants')
        .update({
          'name': cafe['name'] ?? '',
          'logo_url': cafe['logoUrl'] ?? '',
          'public_menu_url': cafe['publicMenuUrl'] ?? '',
          'header_color': cafe['headerColor'] ?? '',
          'sidebar_color': cafe['sidebarColor'] ?? '',
          'background_color': cafe['backgroundColor'] ?? '',
          'button_color': cafe['buttonColor'] ?? '',
          'service_charge_rate': cafe['serviceChargeRate'] ?? 0,
          'tax_rate': cafe['taxRate'] ?? 0,
          'locale': _locale,
        })
        .eq('id', restaurantId!);
  }

  Future<String?> createCashier({
    required String name,
    required String pin,
    required String initials,
  }) async {
    if (isLocal) return _localCreateCashier(name, pin, initials);
    if (client == null) return null;
    final id = await client!.rpc(
      'create_cashier',
      params: {'p_name': name, 'p_pin': pin, 'p_initials': initials},
    );
    await refreshFromDisk();
    return id as String?;
  }

  Future<Map<String, dynamic>> loginCashier(
    String cashierId,
    String pin,
  ) async {
    if (isLocal) return _localLoginCashier(cashierId, pin);
    if (client == null) {
      return {'ok': false, 'error': ErrorCodes.notConfigured};
    }
    try {
      final raw = await client!.rpc(
        'cashier_login',
        params: {'p_cashier_id': cashierId, 'p_pin': pin},
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        cashierToken = result['token'] as String?;
        restaurantId = result['restaurant_id'] as String?;
        _applyHeaders();
        await refreshFromDisk();
      }
      return result;
    } catch (error, stackTrace) {
      reportError('cashier login', error, stackTrace);
      return {'ok': false, 'error': _errorCode(error)};
    }
  }

  Future<String?> settleCash(
    String tableId,
    double cashReceived, {
    bool applyService = true,
    String? paymentTypeId,
  }) async {
    if (isLocal) return _localSettleCash(tableId, cashReceived, applyService: applyService, paymentTypeId: paymentTypeId);
    if (client == null) return ErrorCodes.notConfigured;
    try {
      _applyHeaders();
      final raw = await client!.rpc(
        'settle_cash',
        params: {
          'p_table_id': tableId,
          'p_cash_received': cashReceived,
          'p_apply_service': applyService,
          'p_payment_type_id': paymentTypeId,
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        await refreshFromDisk();
        return null;
      }
      return result['error'] as String? ?? 'Payment failed.';
    } catch (error, stackTrace) {
      reportError('settle cash', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> assignShiftOrderNumber(String orderId) async {
    if (client == null) return ErrorCodes.notConfigured;
    _applyHeaders();
    final raw = await client!.rpc(
      'assign_shift_order_number',
      params: {'p_order_id': orderId},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] == true) return null;
    return result['error'] as String? ?? 'Order number was not assigned.';
  }

  /// Numbers several open orders in one call. Falls back to one call per
  /// order on a server that does not have the batch function yet.
  Future<String?> assignShiftOrderNumbers(List<String> orderIds) async {
    if (client == null) return ErrorCodes.notConfigured;
    if (orderIds.isEmpty) return null;
    _applyHeaders();
    try {
      final raw = await client!.rpc(
        'assign_shift_order_numbers',
        params: {'p_order_ids': orderIds},
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) return null;
      return result['error'] as String? ?? 'Order number was not assigned.';
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      for (final id in orderIds) {
        final failure = await assignShiftOrderNumber(id);
        if (failure == 'session expired, sign in again') return failure;
      }
      return null;
    }
  }

  Future<String?> setTablePaymentType(String qrSlug, String typeId) async {
    if (isLocal) return _localSetTablePaymentType(qrSlug, typeId);
    if (client == null) return ErrorCodes.notConfigured;
    _applyHeaders();
    final raw = await client!.rpc(
      'set_table_payment_type',
      params: {'p_qr_slug': qrSlug, 'p_type_id': typeId},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] == true) {
      await refreshFromDisk();
      return null;
    }
    return result['error'] as String? ?? 'Payment type was not saved.';
  }

  Future<String?> changePaymentType(String paymentId, String typeId) async {
    if (isLocal) return _localChangePaymentType(paymentId, typeId);
    if (client == null) return ErrorCodes.notConfigured;
    _applyHeaders();
    final raw = await client!.rpc(
      'change_payment_type',
      params: {'p_payment_id': paymentId, 'p_type_id': typeId},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] == true) {
      await refreshFromDisk();
      return null;
    }
    return result['error'] as String? ?? 'Payment type was not changed.';
  }

  Future<String?> addPaymentType(String nameEn, String nameAr) async {
    if (isLocal) return _localAddPaymentType(nameEn, nameAr);
    if (client == null || restaurantId == null) {
      return ErrorCodes.notConfigured;
    }
    final sort =
        _paymentTypes.fold<int>(
          0,
          (max, type) => type.sortOrder > max ? type.sortOrder : max,
        ) +
        1;
    try {
      await client!.from('payment_types').insert({
        'restaurant_id': restaurantId,
        'name_en': nameEn,
        'name_ar': nameAr,
        'sort_order': sort,
      });
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('add payment type', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> savePaymentType(PaymentType type) async {
    if (isLocal) return _localSavePaymentType(type);
    if (client == null) return ErrorCodes.notConfigured;
    try {
      await client!
          .from('payment_types')
          .update({
            'name_en': type.nameEn,
            'name_ar': type.nameAr,
            'enabled': type.enabled,
            'archived': type.archived,
          })
          .eq('id', type.id);
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('save payment type', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> deletePaymentType(String id) async {
    if (isLocal) return _localDeletePaymentType(id);
    if (client == null) return ErrorCodes.notConfigured;
    try {
      await client!.from('payment_types').delete().eq('id', id);
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('delete payment type', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> addExpenseCategory(String nameEn, String nameAr) async {
    if (isLocal) return _localAddExpenseCategory(nameEn, nameAr);
    if (client == null || restaurantId == null) {
      return ErrorCodes.notConfigured;
    }
    final sort =
        _expenseCategories.fold<int>(
          0,
          (max, type) => type.sortOrder > max ? type.sortOrder : max,
        ) +
        1;
    try {
      await client!.from('expense_categories').insert({
        'restaurant_id': restaurantId,
        'name_en': nameEn,
        'name_ar': nameAr,
        'sort_order': sort,
      });
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('add expense category', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> saveExpenseCategory(ExpenseCategory category) async {
    if (isLocal) return _localSaveExpenseCategory(category);
    if (client == null) return ErrorCodes.notConfigured;
    try {
      await client!
          .from('expense_categories')
          .update({
            'name_en': category.nameEn,
            'name_ar': category.nameAr,
            'enabled': category.enabled,
          })
          .eq('id', category.id);
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('save expense category', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> deleteExpenseCategory(String id) async {
    if (isLocal) return _localDeleteExpenseCategory(id);
    if (client == null) return ErrorCodes.notConfigured;
    try {
      await client!.from('expense_categories').delete().eq('id', id);
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('delete expense category', error, stackTrace);
      return _errorCode(error);
    }
  }

  /// Stops a cashier from signing in. Cashiers are never hard-deleted: their
  /// payments and shifts reference them, so a delete fails at the database.
  Future<String?> deactivateCashier(String id) async {
    if (isLocal) return _localDeactivateCashier(id);
    if (client == null || restaurantId == null || client!.auth.currentUser == null) {
      _cashiers = _cashiers.where((item) => item.id != id).toList();
      return null;
    }
    try {
      await client!.from('cashiers').update({'active': false}).eq('id', id);
      _cashiers = _cashiers.where((item) => item.id != id).toList();
      return null;
    } catch (error, stackTrace) {
      reportError('deactivate cashier', error, stackTrace);
      return _errorCode(error);
    }
  }

  /// Saves [changed] tables only. The live columns (status, guests) are left
  /// out on purpose: guests and cashiers change them, and an admin's copy may
  /// be stale. New rows get the database defaults.
  Future<void> writeTables(List<CafeTable> all, {required Iterable<CafeTable> changed}) async {
    _tables = all;
    _saveLocalSettingsIfLocal();
    final rows = [
      for (final item in changed)
        {
          'id': item.id,
          'restaurant_id': restaurantId,
          'number': item.number,
          'qr_slug': item.qrSlug,
          'zone': item.zone,
          'seats': item.seats,
          'archived': item.archived,
        },
    ];
    if (client == null || restaurantId == null || rows.isEmpty) return;
    // Tables are never hard-deleted: that would cascade to their receipts.
    await client!.from('dining_tables').upsert(rows);
  }

  /// Saves [changed] categories and deletes [deleted] ones, by id. Never
  /// deletes rows just because this device's copy of the list lacks them.
  Future<void> writeCategories(
    List<MenuCategory> all, {
    Iterable<MenuCategory> changed = const [],
    Iterable<String> deleted = const [],
  }) async {
    _categories = all;
    _saveLocalSettingsIfLocal();
    if (client == null || restaurantId == null) return;
    final rows = [
      for (final item in changed)
        {
          'id': item.id,
          'restaurant_id': restaurantId,
          'name_en': item.nameEn,
          'name_ar': item.nameAr,
          'sort_order': item.sortOrder,
          'spotlight': item.spotlight,
          'visible': item.visible,
        },
    ];
    if (rows.isNotEmpty) await client!.from('menu_categories').upsert(rows);
    final ids = deleted.toList();
    if (ids.isNotEmpty) await client!.from('menu_categories').delete().inFilter('id', ids);
  }

  /// Saves [changed] dishes and deletes [deleted] ones, by id. Never deletes
  /// rows just because this device's copy of the menu lacks them.
  Future<void> writeMenuItems(
    List<MenuItem> all, {
    Iterable<MenuItem> changed = const [],
    Iterable<String> deleted = const [],
  }) async {
    final previousImages = {
      for (final item in _menuItems) item.id: item.imageUrl,
    };
    _menuItems = all;
    if (isLocal) {
      for (final item in changed) {
        item.imageUrl = _localImage(item.imageUrl);
      }
      _saveLocalCatalog();
      return;
    }
    if (client == null || restaurantId == null) return;
    final rows = <Map<String, dynamic>>[];
    for (final item in changed) {
      final image = await _storeImage(
        item.id,
        item.imageUrl,
        previous: previousImages[item.id],
      );
      item.imageUrl = image;
      rows.add({
        'id': item.id,
        'restaurant_id': restaurantId,
        'category_id': item.categoryId,
        'name_it': item.nameIt,
        'name_en': item.nameEn,
        'description': item.description,
        'price': item.price,
        'image_url': image,
        'available': item.available,
        'sold_out': item.soldOut,
        'featured': item.featured,
        'sort_order': item.sortOrder,
        'discount_percent': item.discountPercent,
        'discount_applied': item.discountApplied,
        'options': item.options.map((option) => option.toJson()).toList(),
      });
    }
    if (rows.isNotEmpty) await client!.from('menu_items').upsert(rows);
    final ids = deleted.toList();
    if (ids.isNotEmpty) await client!.from('menu_items').delete().inFilter('id', ids);
  }

  /// Sets how many of dish [id] are left ([qty] null: no limit). Kept apart from
  /// [writeMenuItems], so saving an older copy of a dish never brings sold stock back.
  Future<String?> setDishStock(String id, int? qty) async {
    if (isLocal) return _localSetDishStock(id, qty);
    if (client == null) return ErrorCodes.notConfigured;
    final soldOut = qty == 0;
    try {
      await client!.from('menu_items').update({
        'stock_qty': qty,
        if (qty != null) 'sold_out': soldOut,
      }).eq('id', id);
    } on PostgrestException catch (error) {
      return _errorCode(error);
    }
    for (final item in _menuItems.where((item) => item.id == id)) {
      item.stockQty = qty;
      if (qty != null) item.soldOut = soldOut;
    }
    return null;
  }

  /// What the database is known to hold, so unchanged calls are not rewritten
  /// (the call list grows daily).
  final Map<String, bool> _callWritten = {};

  void _rememberWritten() {
    _callWritten
      ..clear()
      ..addEntries([for (final call in _calls) MapEntry(call.id, call.resolved)]);
  }

  Future<void> _cartWrites = Future.value();

  /// Keeps [carts] and saves them; with [tableId], only that table's cart goes to the server.
  Future<void> writeCarts(Map<String, CartState> carts, {String? tableId}) {
    final next = _cartWrites.then((_) => _writeCarts(carts, tableId: tableId));
    _cartWrites = next.catchError((Object error, StackTrace stackTrace) {
      reportError('write carts', error, stackTrace);
    });
    return next;
  }

  Future<Map<String, dynamic>> guestLocationRule(
    String qrSlug, {
    double? lat,
    double? lng,
    double? accuracyM,
  }) async {
    if (client == null) return const {'enabled': false, 'radius_m': 100};
    final params = <String, dynamic>{'p_qr_slug': qrSlug};
    if (lat != null && lng != null) {
      params['p_lat'] = lat;
      params['p_lng'] = lng;
      if (accuracyM != null) params['p_accuracy_m'] = accuracyM;
    }
    final raw = await client!.rpc('guest_location_rule', params: params);
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<({bool enabled, double? lat, double? lng, int radiusM})?>
  readCafeLocation() async {
    if (client == null || restaurantId == null) return null;
    final row = await client!
        .from('restaurants')
        .select(
          'location_check_enabled, location_lat, location_lng, location_radius_m',
        )
        .eq('id', restaurantId!)
        .maybeSingle();
    if (row == null) return null;
    return (
      enabled: row['location_check_enabled'] as bool? ?? false,
      lat: (row['location_lat'] as num?)?.toDouble(),
      lng: (row['location_lng'] as num?)?.toDouble(),
      radiusM: (row['location_radius_m'] as num?)?.toInt() ?? 100,
    );
  }

  Future<String?> writeCafeLocation({
    required bool enabled,
    double? lat,
    double? lng,
    required int radiusM,
  }) async {
    if (client == null || restaurantId == null) {
      return ErrorCodes.notConfigured;
    }
    try {
      final raw = await client!.rpc(
        'save_cafe_location',
        params: {
          'p_enabled': enabled,
          'p_lat': lat,
          'p_lng': lng,
          'p_radius_m': radiusM,
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) return null;
      return result['error'] as String? ?? 'save_failed';
    } catch (error, stackTrace) {
      reportError('save cafe location', error, stackTrace);
      return 'save_failed';
    }
  }

  /// Sends a message to the provider. Returns null once it is stored, otherwise the server's error
  /// text, or an error code when the call itself failed. Needs the server: an offline-only install
  /// has none.
  Future<String?> sendFeedback({required String kind, required String message, required String appVersion}) async {
    if (client == null || isLocal) return ErrorCodes.notConfigured;
    final result = await _rpcResult('send_feedback', 'send feedback', {
      'p_kind': kind,
      'p_message': message,
      'p_app_version': appVersion,
    });
    return _failure(result, ErrorCodes.failed);
  }

  Future<bool> checkDevAccess(String password) async {
    if (client == null) return false;
    try {
      final raw = await client!.rpc('check_dev_access', params: {'p_password': password});
      return raw == true;
    } catch (error, stackTrace) {
      reportError('dev access', error, stackTrace);
      return false;
    }
  }

  Future<Map<String, dynamic>?> devCall(String name, String password, [Map<String, dynamic>? extra]) async {
    if (client == null) return {'ok': false, 'error': ErrorCodes.notConfigured};
    try {
      _applyHeaders();
      final raw = await client!.rpc(name, params: {'p_password': password, ...?extra});
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {'ok': false, 'error': 'Unexpected response from $name.'};
    } catch (error, stackTrace) {
      reportError(name, error, stackTrace);
      return {'ok': false, 'error': _errorCode(error)};
    }
  }

  /// One line for an order RPC: the dish, its quantity and, when it has choices,
  /// every option that is on. The server prices the line from its own menu.
  Map<String, dynamic> _lineParams(OrderLine line) {
    final params = <String, dynamic>{'menu_item_id': line.menuItemId, 'qty': line.qty};
    if (line.choices.isEmpty) return params;
    final item = _menuItems.where((item) => item.id == line.menuItemId);
    if (item.isNotEmpty) params['on'] = onIdsFor(item.first.options, line.choices).toList();
    return params;
  }

  Future<String?> quickTakeoutReceipt(List<OrderLine> lines, String? paymentTypeId) async {
    if (isLocal) return _localQuickTakeout(lines, paymentTypeId);
    if (client == null) return ErrorCodes.notConfigured;
    _applyHeaders();
    try {
      final raw = await client!.rpc(
        'quick_takeout_receipt',
        params: {
          'p_lines': [
            for (final line in lines)
              if (line.menuItemId.isNotEmpty && line.qty > 0) _lineParams(line),
          ],
          'p_payment_type_id': paymentTypeId,
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        await refreshFromDisk();
        return null;
      }
      return result['error'] as String? ?? 'Payment failed.';
    } catch (error, stackTrace) {
      reportError('quick takeout', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> sendTableCart(
    String tableId, {
    String serviceType = 'dine_in',
    String? qrSlug,
    double? lat,
    double? lng,
    double? accuracyM,
  }) async {
    if (isLocal) {
      await _cartWrites;
      return _localSendTableCart(tableId);
    }
    if (client == null) return ErrorCodes.notConfigured;
    await _cartWrites;
    _applyHeaders();
    final cart = _carts[tableId];
    final params = <String, dynamic>{
      'p_qr_slug': qrSlug,
      'p_lines': [
        for (final line in cart?.lines ?? const <OrderLine>[])
          if (line.menuItemId.isNotEmpty && line.qty > 0) _lineParams(line),
      ],
      'p_service_type': serviceType,
    };
    if (lat != null && lng != null) {
      params['p_lat'] = lat;
      params['p_lng'] = lng;
      if (accuracyM != null) params['p_accuracy_m'] = accuracyM;
    }
    final raw = await client!.rpc('send_table_cart', params: params);
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] != true) {
      final error = result['error'] as String? ?? 'Order was not sent.';
      final items = result['items'];
      if (error == 'items_unavailable' && items is List) {
        return '$unavailableItemsError${items.join(', ')}';
      }
      return error;
    }
    await refreshFromDisk();
    return null;
  }

  Future<void> _writeCarts(Map<String, CartState> carts, {String? tableId}) async {
    _epoch++;
    _carts = carts;
    if (isLocal) {
      _saveLocalCarts();
      return;
    }
    if (client == null || restaurantId == null) return;
    for (final cart in carts.values) {
      if (tableId != null && cart.tableId != tableId) continue;
      await client!.from('carts').upsert({
        'table_id': cart.tableId,
        'restaurant_id': restaurantId,
      });
      await client!.from('cart_lines').delete().eq('table_id', cart.tableId);
      if (cart.lines.isEmpty) continue;
      await client!
          .from('cart_lines')
          .insert(
            cart.lines
                .map(
                  (line) => {
                    'table_id': cart.tableId,
                    'restaurant_id': restaurantId,
                    'menu_item_id': line.menuItemId.isEmpty
                        ? null
                        : line.menuItemId,
                    'name': line.name,
                    'qty': line.qty,
                    'unit_price': line.unitPrice,
                    'list_unit_price': line.listUnitPrice ?? line.unitPrice,
                    if (line.choices.isNotEmpty)
                      'choices': line.choices.map((choice) => choice.toJson()).toList(),
                  },
                )
                .toList(),
          );
    }
  }

  ShiftExpense _mapExpense(Map<String, dynamic> row) => ShiftExpense(
    id: row['id'] as String,
    shiftId: row['shift_id'] as String,
    cashierId: row['cashier_id'] as String? ?? '',
    cashierName: row['cashier_name'] as String? ?? '',
    paidToCashierName: row['paid_to_cashier_name'] as String? ?? '',
    paidToCashierId: row['paid_to_cashier_id'] as String?,
    paidToCafe: row['paid_to_cafe'] as bool? ?? false,
    amount: _asDouble(row['amount']) ?? 0,
    description: row['description'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String),
    kind: row['kind'] as String? ?? 'cash_out',
    voided: row['voided'] as bool? ?? false,
    editedFrom: row['edited_from'] as String?,
    displayNumber: row['display_number'] as String?,
    categoryId: row['expense_category_id'] as String?,
    categoryNameEn: row['category_name_en'] as String?,
    categoryNameAr: row['category_name_ar'] as String?,
  );

  Future<String?> addShiftExpense({
    required String shiftId,
    required String cashierId,
    required String categoryId,
    required bool paidToCafe,
    required String? paidToCashierId,
    required double amount,
    required String description,
  }) async {
    if (isLocal) {
      return _localAddExpense(
        shiftId: shiftId,
        cashierId: cashierId,
        categoryId: categoryId,
        paidToCafe: paidToCafe,
        paidToCashierId: paidToCashierId,
        amount: amount,
        description: description,
      );
    }
    final category = _expenseCategories.where((item) => item.id == categoryId);
    final expense = ShiftExpense(
      id: Secrets.id('expense'),
      shiftId: shiftId,
      cashierId: cashierId,
      paidToCafe: paidToCafe,
      paidToCashierId: paidToCafe ? null : paidToCashierId,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
      categoryId: categoryId,
      categoryNameEn: category.isEmpty ? null : category.first.nameEn,
      categoryNameAr: category.isEmpty ? null : category.first.nameAr,
    );
    if (client == null || restaurantId == null) {
      _expenses = [expense, ..._expenses];
      return null;
    }
    _applyHeaders();
    try {
      final raw = await client!.rpc(
        'record_cash_movement',
        params: {
          'p_shift_id': shiftId,
          'p_expense_category_id': categoryId,
          'p_amount': amount,
          'p_description': description,
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        await refreshFromDisk(liveOnly: true);
        return null;
      }
      return result['error'] as String? ?? 'not_found';
    } catch (error, stackTrace) {
      reportError('shift expense', error, stackTrace);
      return _errorCode(error);
    }
  }

  /// Voids the signed-in cashier's own paid sale on their open shift. Null on success.
  Future<String?> voidPayment(String paymentId, String reason) async {
    if (isLocal) return _localVoidPayment(paymentId, reason);
    if (client == null) return ErrorCodes.notConfigured;
    _applyHeaders();
    try {
      final raw = await client!.rpc(
        'void_payment',
        params: {'p_payment_id': paymentId, 'p_reason': reason},
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        await refreshFromDisk(liveOnly: true);
        return null;
      }
      return result['error'] as String? ?? 'not_found';
    } catch (error, stackTrace) {
      reportError('void payment', error, stackTrace);
      return _errorCode(error);
    }
  }

  Future<String?> editShiftExpense({
    required String id,
    required String categoryId,
    required double amount,
    required String description,
  }) async {
    if (isLocal) return _localEditExpense(id: id, categoryId: categoryId, amount: amount, description: description);
    if (client == null) return ErrorCodes.notConfigured;
    _applyHeaders();
    try {
      final raw = await client!.rpc(
        'edit_cash_movement',
        params: {
          'p_id': id,
          'p_expense_category_id': categoryId,
          'p_amount': amount,
          'p_description': description,
        },
      );
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        await refreshFromDisk(liveOnly: true);
        return null;
      }
      return result['error'] as String? ?? 'not_found';
    } catch (error, stackTrace) {
      reportError('edit cash movement', error, stackTrace);
      return _errorCode(error);
    }
  }

  /// Prefix of the error [sendTableCart] returns when dishes in the cart were
  /// switched off; the dish names follow it, comma separated.
  static const unavailableItemsError = 'items_unavailable:';

  /// While true the app runs from the saved copy and does not load from the server.
  bool offlineMode = false;

  /// Whether the server answers at all (any reply counts, even a refusal).
  Future<bool> serverReachable({Duration timeout = const Duration(seconds: 4)}) async {
    if (client == null) return false;
    try {
      await callRpc('guest_ordering_open', {'p_qr_slug': ''}, timeout: timeout);
      return true;
    } catch (error) {
      return !isNetworkError(error);
    }
  }

  /// What the till needs to start without internet: cafe, menu, tables, payment methods,
  /// expense types and cashier names. Saved on the device while online.
  Map<String, dynamic> offlineSnapshot() => {
    'restaurantId': restaurantId,
    'boundSlot': boundSlot,
    'boundRestaurantId': boundRestaurantId,
    'boundSlug': boundSlug,
    'boundHasAdmin': boundHasAdmin,
    'anyAdmin': anyAdmin,
    'cafe': _cafe,
    'locale': _locale,
    'tables': [for (final t in _tables) {...t.toJson(), 'archived': t.archived}],
    'categories': [for (final c in _categories) c.toJson()],
    'menuItems': [for (final m in _menuItems) m.toJson()],
    'paymentTypes': [
      for (final p in _paymentTypes)
        {'id': p.id, 'nameEn': p.nameEn, 'nameAr': p.nameAr, 'enabled': p.enabled, 'sortOrder': p.sortOrder, 'archived': p.archived},
    ],
    'expenseCategories': [
      for (final e in _expenseCategories)
        {'id': e.id, 'nameEn': e.nameEn, 'nameAr': e.nameAr, 'enabled': e.enabled, 'sortOrder': e.sortOrder},
    ],
    'cashiers': [for (final c in _cashiers) {'id': c.id, 'name': c.name, 'initials': c.initials}],
  };

  /// Loads a copy saved by [offlineSnapshot] so the till can open without internet.
  void applyOfflineSnapshot(Map<String, dynamic> s) {
    List<Map<String, dynamic>> rows(String key) =>
        [for (final row in (s[key] as List? ?? const [])) Map<String, dynamic>.from(row as Map)];
    restaurantId = s['restaurantId'] as String?;
    boundSlot = s['boundSlot'] as int?;
    boundRestaurantId = s['boundRestaurantId'] as String?;
    boundSlug = s['boundSlug'] as String?;
    boundHasAdmin = s['boundHasAdmin'] as bool? ?? false;
    anyAdmin = s['anyAdmin'] as bool? ?? false;
    _cafe = Map<String, dynamic>.from(s['cafe'] as Map? ?? const {});
    _locale = s['locale'] as String? ?? 'en';
    _tables = [for (final r in rows('tables')) CafeTable.fromJson(r)];
    _categories = [for (final r in rows('categories')) MenuCategory.fromJson(r)];
    _menuItems = [for (final r in rows('menuItems')) MenuItem.fromJson(r)];
    _paymentTypes = [
      for (final r in rows('paymentTypes'))
        PaymentType(
          id: r['id'] as String,
          nameEn: r['nameEn'] as String? ?? '',
          nameAr: r['nameAr'] as String? ?? '',
          enabled: r['enabled'] as bool? ?? true,
          sortOrder: r['sortOrder'] as int? ?? 0,
          archived: r['archived'] as bool? ?? false,
        ),
    ];
    _expenseCategories = [
      for (final r in rows('expenseCategories'))
        ExpenseCategory(
          id: r['id'] as String,
          nameEn: r['nameEn'] as String? ?? '',
          nameAr: r['nameAr'] as String? ?? '',
          enabled: r['enabled'] as bool? ?? true,
          sortOrder: r['sortOrder'] as int? ?? 0,
        ),
    ];
    _cashiers = [
      for (final r in rows('cashiers'))
        Cashier(id: r['id'] as String, name: r['name'] as String, initials: r['initials'] as String? ?? 'C'),
    ];
    _orders = [];
    _payments = [];
    _shifts = [];
    _expenses = [];
    _calls = [];
    _carts = {};
    loadedOnce = true;
  }

  /// Calls a server function with this device's headers, giving up after [timeout] so a dead
  /// connection never freezes the till. Throws on network failure (used by the offline uploader).
  Future<dynamic> callRpc(String name, Map<String, dynamic> params, {Duration timeout = const Duration(seconds: 10)}) {
    final current = client;
    if (current == null) throw StateError('Supabase is not configured.');
    _applyHeaders();
    return current.rpc(name, params: params).timeout(timeout);
  }

  /// Calls an RPC that answers `{ok, error, ...}`. Returns the answer, or an
  /// `{ok: false, error}` map when the call itself failed.
  Future<Map<String, dynamic>> _rpcResult(String name, String label, [Map<String, dynamic>? params]) async {
    _applyHeaders();
    try {
      final raw = await client!.rpc(name, params: params);
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {'ok': false, 'error': 'Unexpected response from $name.'};
    } catch (error, stackTrace) {
      reportError(label, error, stackTrace);
      return {'ok': false, 'error': _errorCode(error)};
    }
  }

  String? _failure(Map<String, dynamic> result, String fallback) =>
      result['ok'] == true ? null : (result['error'] as String? ?? fallback);

  /// Moves an order one kitchen step on the server. Only the status changes;
  /// the lines and their prices are not rewritten.
  Future<String?> setOrderStatus(String orderId, OrderStatus status) async {
    if (client == null) return null;
    _epoch++; // a load already running would bring back the old status
    final result = await _rpcResult(
      'set_order_status',
      'set order status',
      {'p_order_id': orderId, 'p_status': status.name},
    );
    return _failure(result, 'Order status was not saved.');
  }

  /// Removes one sent line (a refused dish) from an unpaid order.
  Future<String?> removeOrderLine(String lineId) async {
    if (isLocal) return _localRemoveOrderLine(lineId);
    if (client == null) return null;
    _epoch++; // a load already running would bring back the removed line
    final result = await _rpcResult('remove_order_line', 'remove order line', {'p_line_id': lineId});
    return _failure(result, 'The line was not removed.');
  }

  /// Asks for the bill: a guest passes the table's QR slug, staff the table id.
  Future<String?> requestBill({String? qrSlug, String? tableId}) async {
    if (client == null) return null;
    final result = await _rpcResult('request_bill', 'request bill', {
      'p_qr_slug': qrSlug,
      'p_table_id': tableId,
    });
    return _failure(result, 'The bill request was not sent.');
  }

  /// The signed-in cashier's open shift, opened on the server if needed.
  Future<({String? shiftId, String? error})> openShift() async {
    if (client == null) return (shiftId: null, error: null);
    final result = await _rpcResult('open_shift', 'open shift');
    return (shiftId: result['shift_id'] as String?, error: _failure(result, 'The shift was not opened.'));
  }

  Future<String?> setOpeningCash(double amount) async {
    if (client == null) return null;
    final result = await _rpcResult('set_opening_cash', 'set opening cash', {'p_amount': amount});
    return _failure(result, 'The opening float was not saved.');
  }

  Future<String?> closeShift(double actualCash) async {
    if (client == null) return null;
    final result = await _rpcResult('close_shift', 'close shift', {'p_actual_cash': actualCash});
    return _failure(result, 'The shift was not closed.');
  }

  /// Ends the cashier session [token] on the server. The token is sent on this
  /// request alone, so it still works after sign-out cleared it locally.
  Future<void> cashierLogout(String token) async {
    if (client == null) return;
    try {
      await client!.rpc('cashier_logout').setHeader('x-cashier-token', token);
    } catch (error, stackTrace) {
      reportError('cashier logout', error, stackTrace);
    }
  }

  Future<void> writeShifts(List<CashShift> items) async {
    _shifts = items;
    if (isLocal) {
      _localStore!.putRecords('shifts', [for (final item in items) item.toJson()]);
      return;
    }
    if (client == null || restaurantId == null) return;
    for (final item in items) {
      await client!.from('shifts').upsert({
        'id': item.id,
        'restaurant_id': restaurantId,
        'cashier_id': item.cashierId,
        'opened_at': item.openedAt.toIso8601String(),
        'closed_at': item.closedAt?.toIso8601String(),
        'opening_cash': item.openingCash,
        'cash_sales': item.cashSales,
        'cash_refunds': item.cashRefunds,
        'cash_adjustments': item.cashAdjustments,
        'actual_cash': item.actualCash,
        'transaction_count': item.transactionCount,
      });
    }
  }

  Future<void> writeCalls(List<StaffCall> items) async {
    _calls = items;
    if (client == null || restaurantId == null) return;
    for (final item in List<StaffCall>.of(items)) {
      if (_callWritten[item.id] == item.resolved) continue;
      await client!.from('staff_calls').upsert({
        'id': item.id,
        'restaurant_id': restaurantId,
        'table_id': item.tableId,
        'kind': item.kind,
        'resolved': item.resolved,
        'created_at': item.createdAt.toIso8601String(),
      });
      _callWritten[item.id] = item.resolved;
    }
  }

  Future<String?> setItemAvailable(String itemId, bool available) async {
    if (client == null && !isLocal) return ErrorCodes.notConfigured;
    final match = _menuItems.where((item) => item.id == itemId);
    final previous = match.isEmpty ? null : match.first.available;
    if (match.isNotEmpty) match.first.available = available;
    if (isLocal) {
      _saveLocalCatalog();
      return null;
    }
    try {
      await client!.rpc(
        'set_item_available',
        params: {'p_item_id': itemId, 'p_available': available},
      );
      return null;
    } catch (error, stackTrace) {
      reportError('set item available', error, stackTrace);
      if (match.isNotEmpty && previous != null) {
        match.first.available = previous;
      }
      return _errorCode(error);
    }
  }

  Future<void> noteOrderRefusal(String orderId, String itemName) async {
    if (client == null) return;
    await client!.rpc(
      'note_order_refusal',
      params: {'p_order_id': orderId, 'p_item_name': itemName},
    );
    final match = _orders.where((order) => order.id == orderId);
    if (match.isNotEmpty) {
      match.first.awaitingCustomerConfirmation = true;
      final notice = match.first.refusalNotice.trim();
      match.first.refusalNotice = notice.isEmpty
          ? itemName
          : '$notice $itemName';
    }
  }

  Future<String> storeLogo(String value) async =>
      isLocal ? _localImage(value) : _storeImage('logo', value, previous: _cafe['logoUrl'] as String?);

  /// Uploads a picked image (a data: URL) shrunk to [maxImageSide], under a
  /// new name each time so phones and the CDN never show the old picture,
  /// then removes [previous] from storage. Anything that is not a data: URL
  /// is already stored and is returned unchanged.
  Future<String> _storeImage(
    String itemId,
    String value, {
    String? previous,
  }) async {
    if (client == null || restaurantId == null || !value.startsWith('data:')) {
      return value;
    }
    final comma = value.indexOf(',');
    if (comma < 0) return value;
    final meta = value.substring(5, comma);
    final original = base64Decode(value.substring(comma + 1));
    final shrunk = shrinkImage(original);
    final bytes = shrunk?.bytes ?? original;
    final ext = shrunk?.extension ?? (meta.contains('png') ? 'png' : 'jpg');
    final contentType = shrunk?.contentType ?? meta.split(';').first;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$restaurantId/$itemId-$stamp.$ext';
    final bucket = client!.storage.from(_imageBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    final oldPath = _storedImagePath(previous);
    if (oldPath != null && oldPath != path) {
      try {
        await bucket.remove([oldPath]);
      } catch (error, stackTrace) {
        // A left-over file only costs storage; the new picture is saved.
        reportError('remove old image', error, stackTrace);
      }
    }
    return bucket.getPublicUrl(path);
  }

  static const _imageBucket = 'menu-images';

  /// The storage path of [url] when it is a picture this cafe stored, else null.
  String? _storedImagePath(String? url) {
    if (url == null || url.isEmpty || restaurantId == null) return null;
    const marker = '/object/public/$_imageBucket/';
    final at = url.indexOf(marker);
    if (at < 0) return null;
    final path = Uri.decodeComponent(
      url.substring(at + marker.length).split('?').first,
    );
    return path.startsWith('$restaurantId/') ? path : null;
  }
}

/// What a failed server call tells the screens; the details were logged.
String _errorCode(Object error) =>
    isNetworkError(error) ? ErrorCodes.network : ErrorCodes.failed;

class Secrets {
  static final _random = Random.secure();

  static String publicId([int length = 12]) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  static String id([String prefix = 'id']) {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static bool validPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }
}
