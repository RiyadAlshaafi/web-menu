import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../time_format.dart';
import '../report_error.dart';
import 'local_env.dart' if (dart.library.io) 'local_env_io.dart';
import 'sales_history.dart';

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
  bool _listening = false;
  bool _realtimeLive = false;
  bool _realtimeSeenDrop = false;
  int _epoch = 0;
  DateTime? _catalogAt;
  Timer? _liveRefresh;
  RealtimeChannel? _syncChannel;
  void Function()? onLiveChange;
  DateTime? _salesFrom;
  DateTime? _salesTo;
  int _salesLimit = salesPageSize;
  bool salesHasMore = false;
  String? restaurantId;
  String? cashierToken;
  String? guestSlug;
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

  /// Slot the developer tools are working on (sent as the x-dev-slot header).
  int? devSlot;

  Map<String, dynamic> _cafe = {
    'name': '',
    'serviceChargeRate': 0.10,
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
  String get databasePath => isConfigured ? 'supabase' : 'not configured';
  bool get isSqlite => false;
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
  Map<String, dynamic>? get otp => null;
  int get nextOrderId => 1001;

  Future<void> init({bool memory = false}) async {
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
      await _loadBoundSlot();
      _listen();
      await refreshFromDisk();
    } catch (error, stack) {
      reportError('supabase startup', error, stack);
    }
  }

  Future<void> _loadBoundSlot() async {
    int? slot;
    try {
      slot = (await SharedPreferences.getInstance()).getInt(_slotPrefKey);
    } catch (error, stack) {
      reportError('read device slot', error, stack);
    }
    slot ??= _defaultSlot > 0 ? _defaultSlot : null;
    if (slot != null) await _resolveBound(slot: slot);
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
      return '$error';
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
    guestSlug = null;
    anyAdmin = false;
    _cafe = {'name': '', 'serviceChargeRate': 0.10, 'taxRate': 0, 'autoPrintReceipt': true};
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
    _syncChannel = null;
    _listening = false;
    _realtimeLive = false;
    _realtimeSeenDrop = false;
    if (channel != null) {
      client?.removeChannel(channel);
    }
  }

  void _emitLive() {
    final hook = onLiveChange;
    if (hook != null) {
      hook();
    } else {
      refreshFromDisk(liveOnly: true);
    }
  }

  void _listen() {
    if (_listening || client == null) return;
    try {
      _listening = true;
      void scheduleLive() {
        _liveRefresh?.cancel();
        _liveRefresh = Timer(const Duration(milliseconds: 300), _emitLive);
      }

      _syncChannel = client!
          .channel('cafe-sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_lines',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'carts',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cart_lines',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'staff_calls',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'menu_items',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'dining_tables',
            callback: (_) => scheduleLive(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shift_expenses',
            callback: (_) => scheduleLive(),
          )
          .subscribe((status, _) {
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
    } catch (error, stack) {
      _listening = false;
      _syncChannel = null;
      reportError('realtime setup', error, stack);
    }
  }

  void _applyHeaders() {
    final current = client;
    if (current == null) return;
    final headers = Map<String, String>.from(current.headers)
      ..remove('x-qr-slug')
      ..remove('x-cashier-token')
      ..remove('x-dev-slot');
    if (devSlot != null) headers['x-dev-slot'] = '$devSlot';
    if (guestSlug != null) headers['x-qr-slug'] = guestSlug!;
    if (cashierToken != null) headers['x-cashier-token'] = cashierToken!;
    current.headers = headers;
  }

  Future<void> setGuestSlug(String? slug) async {
    guestSlug = slug == null || slug.isEmpty ? null : slug;
    _applyHeaders();
    await refreshFromDisk();
  }

  Future<void>? _refreshInFlight;
  bool _refreshRerun = false;
  bool _refreshRerunFull = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// Reloads data, one run at a time. A call that arrives while a load is
  /// running does not start a second, racing load: it queues one more run that
  /// starts after the current one and returns a future covering both. That
  /// keeps an older, slower load from overwriting newer data, and guarantees a
  /// caller that just wrote something reads it back.
  Future<void> refreshFromDisk({bool liveOnly = false}) {
    if (client == null) return Future<void>.value();
    final running = _refreshInFlight;
    if (running != null) {
      _refreshRerun = true;
      if (!liveOnly) _refreshRerunFull = true;
      return running;
    }
    final run = _runRefreshes(liveOnly).whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = run;
    return run;
  }

  Future<void> _runRefreshes(bool liveOnly) async {
    var live = liveOnly;
    do {
      _refreshRerun = false;
      final catalogFresh =
          _catalogAt != null &&
          DateTime.now().difference(_catalogAt!) < const Duration(seconds: 60);
      var failed = false;
      try {
        await _refreshFromDisk(liveOnly: live && catalogFresh);
      } catch (error, stack) {
        failed = true;
        reportError('supabase refresh', error, stack);
      }
      _afterRefresh(failed: failed);
      live = !_refreshRerunFull;
      _refreshRerunFull = false;
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
          'name, locale, service_charge_rate, tax_rate, logo_url, header_color, sidebar_color, background_color, button_color, auto_print_receipt',
        )
        .eq('id', id)
        .maybeSingle();
    if (restaurant == null) return;
    _locale = restaurant['locale'] as String? ?? 'en';
    _cafe = {
      'name': restaurant['name'] ?? '',
      'logoUrl': restaurant['logo_url'] ?? '',
      'headerColor': restaurant['header_color'] ?? '',
      'sidebarColor': restaurant['sidebar_color'] ?? '',
      'backgroundColor': restaurant['background_color'] ?? '',
      'buttonColor': restaurant['button_color'] ?? '',
      'serviceChargeRate':
          (restaurant['service_charge_rate'] as num?)?.toDouble() ?? 0.10,
      'taxRate': (restaurant['tax_rate'] as num?)?.toDouble() ?? 0,
      'autoPrintReceipt': restaurant['auto_print_receipt'] as bool? ?? true,
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

  Future<void> _refreshFromDisk({bool liveOnly = false}) async {
    final epoch = _epoch;
    final watch = Stopwatch()..start();
    _applyHeaders();
    final user = client!.auth.currentUser;
    final opened = await Future.wait<dynamic>([
      client!.rpc(
        'has_any_admin',
        params: (restaurantId ?? boundRestaurantId) == null
            ? null
            : {'p_restaurant_id': restaurantId ?? boundRestaurantId},
      ),
      if (user != null)
        client!
            .from('profiles')
            .select('restaurant_id, display_name')
            .eq('id', user.id)
            .maybeSingle()
      else
        Future<dynamic>.value(null),
      client!.from('dining_tables').select(),
    ]);
    if (epoch != _epoch) return;
    anyAdmin = opened[0] as bool? ?? false;
    final profile = opened[1] as Map<String, dynamic>?;
    final tableList = opened[2] as List;
    if (user != null) {
      restaurantId = profile?['restaurant_id'] as String?;
      _admin = AdminAccount(
        email: user.email ?? '',
        passwordHash: '',
        passwordSalt: '',
        displayName: profile?['display_name'] as String? ?? 'Admin',
      );
      _rememberAdmin = true;
    } else if (cashierToken == null) {
      _admin = null;
      _rememberAdmin = false;
    }
    final guest =
        guestSlug != null &&
        cashierToken == null &&
        client!.auth.currentUser == null;
    restaurantId ??= boundRestaurantId;
    if (restaurantId == null && boundSlot == null && tableList.isNotEmpty) {
      // Only an unlinked device falls back to whatever table is visible.
      restaurantId = tableList.first['restaurant_id'] as String?;
    }
    if (restaurantId == null && guestSlug == null) {
      _tables = [];
      _categories = [];
      _menuItems = [];
      _orders = [];
      _carts = {};
      _payments = [];
      _shifts = [];
      _expenses = [];
      _calls = [];
      return;
    }
    if (epoch != _epoch) return;
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
          ),
        )
        .toList();
    final previousImages = {
      for (final item in _menuItems) item.id: item.imageUrl,
    };
    final guestTableId = guest
        ? _tables
              .where((table) => table.qrSlug == guestSlug)
              .map((table) => table.id)
              .firstOrNull
        : null;
    final staffed = !guest && (client!.auth.currentUser != null || cashierToken != null);
    final historyFrom = _salesFrom ?? salesHistoryCutoff(DateTime.now());
    Future<List<dynamic>> loadCarts() async {
      final query = client!.from('carts').select('*, cart_lines(*)');
      if (!guest) return await query as List;
      if (guestTableId == null) return const [];
      return await query.eq('table_id', guestTableId) as List;
    }

    final batch = await Future.wait<dynamic>([
      _loadRestaurant(),
      liveOnly ? Future<dynamic>.value(null) : client!.from('menu_categories').select(),
      liveOnly
          ? client!.from('menu_items').select(
              'id, name_it, name_en, description, price, category_id, available, sold_out, featured, sort_order, discount_percent, discount_applied',
            )
          : client!.from('menu_items').select(),
      loadCarts(),
      guest ? Future<dynamic>.value(null) : client!.from('staff_calls').select(),
      guest
          ? Future<dynamic>.value(null)
          : _selectOrEmpty(client!.from('payment_types').select().order('sort_order'), 'payment types'),
      guest
          ? Future<dynamic>.value(null)
          : _selectOrEmpty(client!.from('expense_categories').select().order('sort_order'), 'expense categories'),
      guest ? Future<dynamic>.value(null) : client!.from('shift_expenses').select().order('created_at'),
      guest
          ? (guestTableId == null ? Future<dynamic>.value(<CafeOrder>[]) : _loadOpenOrdersForTable(guestTableId))
          : _loadOrders(historyFrom, const {}),
      staffed ? client!.from('shifts').select() : Future<dynamic>.value(null),
      (!liveOnly && !guest)
          ? client!.rpc(
              'list_pos_cashiers',
              params: restaurantId == null ? null : {'p_restaurant_id': restaurantId},
            )
          : Future<dynamic>.value(null),
      staffed ? _selectPayments(historyFrom, _salesTo, _salesLimit) : Future<dynamic>.value(null),
    ]);
    if (epoch != _epoch) return;
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
          pinHash: '',
          pinSalt: '',
          initials: map['initials'] as String? ?? 'C',
        );
      }).toList();
    }
    final itemRows = batch[2] as List;
    _menuItems = itemRows
        .map(
          (row) => MenuItem(
            id: row['id'] as String,
            nameIt: row['name_it'] as String? ?? '',
            nameEn: row['name_en'] as String? ?? '',
            description: row['description'] as String? ?? '',
            price: (row['price'] as num).toDouble(),
            categoryId: row['category_id'] as String,
            imageUrl: liveOnly
                ? (previousImages[row['id'] as String] ?? '')
                : (row['image_url'] as String? ?? ''),
            available: row['available'] as bool? ?? true,
            soldOut: row['sold_out'] as bool? ?? false,
            featured: row['featured'] as bool? ?? false,
            sortOrder: row['sort_order'] as int? ?? 0,
            discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
            discountApplied: row['discount_applied'] as bool? ?? false,
          ),
        )
        .toList();
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
                ),
              )
              .toList(),
        ),
    };
    if (guest) {
      _calls = [];
      _orders = (batch[8] as List).cast<CafeOrder>();
      _payments = [];
      _shifts = [];
      _expenses = [];
      salesHasMore = false;
    } else {
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
      final typeRows = batch[5] as List?;
      _paymentTypes = typeRows == null
          ? []
          : typeRows
                .map(
                  (row) => PaymentType(
                    id: row['id'] as String,
                    nameEn: row['name_en'] as String? ?? '',
                    nameAr: row['name_ar'] as String? ?? '',
                    enabled: row['enabled'] as bool? ?? true,
                    sortOrder: row['sort_order'] as int? ?? 0,
                    archived: row['archived'] as bool? ?? false,
                  ),
                )
                .toList();
      final expenseCategoryRows = batch[6] as List?;
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
      _orders = (batch[8] as List).cast<CafeOrder>();
      if (staffed) {
        final expenseRows = batch[7] as List;
        _expenses = expenseRows
            .map((row) => _mapExpense(Map<String, dynamic>.from(row as Map)))
            .toList();
        final paymentRows = batch[11] as List;
        if (epoch != _epoch) return;
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
        _shifts = shiftRows
            .map(
              (row) => CashShift(
                id: row['id'] as String,
                cashierId: row['cashier_id'] as String,
                openedAt: DateTime.parse(row['opened_at'] as String),
                closedAt: row['closed_at'] == null
                    ? null
                    : DateTime.parse(row['closed_at'] as String),
                openingCash: (row['opening_cash'] as num?)?.toDouble() ?? 0,
                cashSales: (row['cash_sales'] as num?)?.toDouble() ?? 0,
                cashRefunds: (row['cash_refunds'] as num?)?.toDouble() ?? 0,
                cashAdjustments:
                    (row['cash_adjustments'] as num?)?.toDouble() ?? 0,
                actualCash: (row['actual_cash'] as num?)?.toDouble(),
                transactionCount: row['transaction_count'] as int? ?? 0,
              ),
            )
            .toList();
      } else {
        _payments = [];
        _shifts = [];
        _expenses = [];
        salesHasMore = false;
      }
    }
    if (kDebugMode) {
      debugPrint('refreshFromDisk ${watch.elapsedMilliseconds}ms liveOnly=$liveOnly');
    }
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
        final paymentId = row['payment_id'] as String;
        changes
            .putIfAbsent(paymentId, () => [])
            .add(
              PaymentMethodChange(
                id: row['id'] as String,
                paymentId: paymentId,
                oldTypeId: row['old_type_id'] as String?,
                newTypeId: row['new_type_id'] as String?,
                actorName: row['actor_name'] as String? ?? '',
                actorRole: row['actor_role'] as String? ?? '',
                createdAt: DateTime.parse(row['created_at'] as String),
              ),
            );
      }
    }
    return changes;
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
      tableId: row['table_id'] as String,
      totalDue: (row['total_due'] as num).toDouble(),
      cashReceived: (row['cash_received'] as num).toDouble(),
      changeDue: (row['change_due'] as num).toDouble(),
      cashierId: row['cashier_id'] as String,
      shiftId: row['shift_id'] as String,
      paidAt: DateTime.parse(row['paid_at'] as String),
      paymentTypeId: row['payment_type_id'] as String?,
      yearMonth: row['year_month'] as String?,
      shiftOrderNumber: (row['shift_order_number'] as num?)?.toInt(),
      monthlyOrderNumber: (row['monthly_order_number'] as num?)?.toInt(),
      shiftDisplayNumber: row['shift_display_number'] as String?,
      monthlyDisplayNumber: row['monthly_display_number'] as String?,
      changes: history,
    );
  }

  Future<List<CafeOrder>> _loadOpenOrdersForTable(String tableId) async {
    final rows = await client!
        .from('orders')
        .select('*, order_lines(*)')
        .eq('table_id', tableId)
        .neq('status', 'paid');
    return [
      for (final row in rows as List)
        _mapOrder(Map<String, dynamic>.from(row as Map)),
    ];
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
      tableId: row['table_id'] as String,
      tableNumber: table.isEmpty ? '' : table.first.number,
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
        );
      }).toList(),
    );
  }

  Future<int> takeNextOrderId() async => nextOrderId;
  Future<void> writeOtp(Map<String, dynamic>? value) async {}
  Future<void> writeRememberAdmin(bool value) async => _rememberAdmin = value;
  Future<void> writeAdmin(AdminAccount? admin) async => _admin = admin;

  Future<void> writeAutoPrintReceipt(bool value) async {
    _cafe = {..._cafe, 'autoPrintReceipt': value};
    if (client == null || restaurantId == null) return;
    await client!.from('restaurants').update({'auto_print_receipt': value}).eq('id', restaurantId!);
  }

  Future<void> writeLocale(String locale) async {
    _locale = locale;
    if (client == null || restaurantId == null) return;
    await client!
        .from('restaurants')
        .update({'locale': locale})
        .eq('id', restaurantId!);
  }

  Future<void> writeCafe(Map<String, dynamic> cafe) async {
    _cafe = Map<String, dynamic>.from(cafe);
    if (client == null || restaurantId == null) return;
    await client!
        .from('restaurants')
        .update({
          'name': cafe['name'] ?? '',
          'logo_url': cafe['logoUrl'] ?? '',
          'header_color': cafe['headerColor'] ?? '',
          'sidebar_color': cafe['sidebarColor'] ?? '',
          'background_color': cafe['backgroundColor'] ?? '',
          'button_color': cafe['buttonColor'] ?? '',
          'service_charge_rate': cafe['serviceChargeRate'] ?? 0.10,
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
    if (client == null) {
      return {'ok': false, 'error': 'Supabase is not configured.'};
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
      return {'ok': false, 'error': '$error'};
    }
  }

  Future<String?> settleCash(
    String tableId,
    double cashReceived, {
    bool applyService = true,
    String? paymentTypeId,
  }) async {
    if (client == null) return 'Supabase is not configured.';
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
      return '$error';
    }
  }

  Future<String?> clearTestLogs(
    String scope, {
    required String cashierId,
  }) async {
    if (scope != 'cashier' && scope != 'shift') return 'unknown scope';
    if (client == null) {
      if (scope == 'cashier') {
        _payments.removeWhere((payment) => payment.cashierId == cashierId);
        for (final shift in _shifts.where(
          (shift) => shift.cashierId == cashierId,
        )) {
          final rows = _payments.where(
            (payment) => payment.shiftId == shift.id,
          );
          shift.cashSales = rows.fold<double>(
            0,
            (sum, payment) => sum + payment.totalDue,
          );
          shift.transactionCount = rows.length;
        }
      } else {
        _payments.clear();
        for (final shift in _shifts) {
          shift.cashSales = 0;
          shift.transactionCount = 0;
        }
      }
      for (final order in _orders.where(
        (order) => order.status != OrderStatus.paid,
      )) {
        order.shiftOrderNumber = null;
        order.yearMonth = null;
      }
      return null;
    }
    _applyHeaders();
    final raw = await client!.rpc(
      'clear_test_logs',
      params: {'p_scope': scope},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] == true) {
      await refreshFromDisk();
      return null;
    }
    return result['error'] as String? ?? 'Logs were not cleared.';
  }

  Future<String?> assignShiftOrderNumber(String orderId) async {
    if (client == null) return 'Supabase is not configured.';
    _applyHeaders();
    final raw = await client!.rpc(
      'assign_shift_order_number',
      params: {'p_order_id': orderId},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] == true) return null;
    return result['error'] as String? ?? 'Order number was not assigned.';
  }

  Future<String?> setTablePaymentType(String qrSlug, String typeId) async {
    if (client == null) return 'Supabase is not configured.';
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
    if (client == null) return 'Supabase is not configured.';
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
    if (client == null || restaurantId == null) {
      return 'Supabase is not configured.';
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
      return '$error';
    }
  }

  Future<String?> savePaymentType(PaymentType type) async {
    if (client == null) return 'Supabase is not configured.';
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
      return '$error';
    }
  }

  Future<String?> deletePaymentType(String id) async {
    if (client == null) return 'Supabase is not configured.';
    try {
      await client!.from('payment_types').delete().eq('id', id);
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('delete payment type', error, stackTrace);
      return '$error';
    }
  }

  Future<String?> addExpenseCategory(String nameEn, String nameAr) async {
    if (client == null || restaurantId == null) {
      return 'Supabase is not configured.';
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
      return '$error';
    }
  }

  Future<String?> saveExpenseCategory(ExpenseCategory category) async {
    if (client == null) return 'Supabase is not configured.';
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
      return '$error';
    }
  }

  Future<String?> deleteExpenseCategory(String id) async {
    if (client == null) return 'Supabase is not configured.';
    try {
      await client!.from('expense_categories').delete().eq('id', id);
      await refreshFromDisk();
      return null;
    } catch (error, stackTrace) {
      reportError('delete expense category', error, stackTrace);
      return '$error';
    }
  }

  Future<void> writeCashiers(List<Cashier> items) async {
    _cashiers = items;
    if (client == null || restaurantId == null || client!.auth.currentUser == null) {
      return;
    }
    final keep = items.map((item) => item.id).toSet();
    final existing = await client!.from('cashiers').select('id');
    for (final row in existing as List) {
      if (!keep.contains(row['id'])) {
        await client!.from('cashiers').delete().eq('id', row['id'] as String);
      }
    }
  }

  Future<void> writeTables(List<CafeTable> items) async {
    _tables = items;
    if (client == null || restaurantId == null) return;
    for (final item in items) {
      await client!.from('dining_tables').upsert({
        'id': item.id,
        'restaurant_id': restaurantId,
        'number': item.number,
        'qr_slug': item.qrSlug,
        'zone': item.zone,
        'seats': item.seats,
        'status': item.status.name,
        'guests': item.guests,
      });
    }
    await _deleteMissing(
      'dining_tables',
      items.map((item) => item.id).toList(),
    );
  }

  Future<void> writeCategories(List<MenuCategory> items) async {
    _categories = items;
    if (client == null || restaurantId == null) return;
    for (final item in items) {
      await client!.from('menu_categories').upsert({
        'id': item.id,
        'restaurant_id': restaurantId,
        'name_en': item.nameEn,
        'name_ar': item.nameAr,
        'sort_order': item.sortOrder,
        'spotlight': item.spotlight,
        'visible': item.visible,
      });
    }
    await _deleteMissing(
      'menu_categories',
      items.map((item) => item.id).toList(),
    );
  }

  Future<void> writeMenuItems(List<MenuItem> items) async {
    _menuItems = items;
    if (client == null || restaurantId == null) return;
    for (final item in items) {
      final image = await _storeImage(item.id, item.imageUrl);
      item.imageUrl = image;
      await client!.from('menu_items').upsert({
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
      });
    }
    await _deleteMissing('menu_items', items.map((item) => item.id).toList());
  }

  Future<void> writeOrders(List<CafeOrder> items) async {
    _epoch++;
    _orders = items;
    if (client == null || restaurantId == null) return;
    for (final item in items) {
      if (item.status == OrderStatus.paid) continue;
      await client!.from('orders').upsert({
        'id': item.id,
        'restaurant_id': restaurantId,
        'table_id': item.tableId,
        'status': item.status.name,
        'notes': item.notes,
        'cashier_id': item.cashierId,
        'created_at': item.createdAt.toIso8601String(),
      });
      await client!.from('order_lines').delete().eq('order_id', item.id);
      if (item.lines.isEmpty) continue;
      await client!
          .from('order_lines')
          .insert(
            item.lines
                .map(
                  (line) => {
                    'order_id': item.id,
                    'restaurant_id': restaurantId,
                    'menu_item_id': line.menuItemId.isEmpty
                        ? null
                        : line.menuItemId,
                    'name': line.name,
                    'qty': line.qty,
                    'unit_price': line.unitPrice,
                    'list_unit_price': line.listUnitPrice ?? line.unitPrice,
                    'round': line.round,
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> _cartWrites = Future.value();

  Future<void> writeCarts(Map<String, CartState> carts) {
    final next = _cartWrites.then((_) => _writeCarts(carts));
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
      return 'Supabase is not configured.';
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
    if (client == null) return {'ok': false, 'error': 'Supabase is not configured.'};
    try {
      _applyHeaders();
      final raw = await client!.rpc(name, params: {'p_password': password, ...?extra});
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {'ok': false, 'error': 'Unexpected response from $name.'};
    } catch (error, stackTrace) {
      reportError(name, error, stackTrace);
      return {'ok': false, 'error': '$error'};
    }
  }

  Future<String?> quickTakeoutReceipt(List<OrderLine> lines, String? paymentTypeId) async {
    if (client == null) return 'Supabase is not configured.';
    _applyHeaders();
    try {
      final raw = await client!.rpc(
        'quick_takeout_receipt',
        params: {
          'p_lines': [
            for (final line in lines)
              if (line.menuItemId.isNotEmpty && line.qty > 0)
                {'menu_item_id': line.menuItemId, 'qty': line.qty},
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
      return '$error';
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
    if (client == null) return 'Supabase is not configured.';
    await _cartWrites;
    _applyHeaders();
    final cart = _carts[tableId];
    final params = <String, dynamic>{
      'p_qr_slug': qrSlug ?? guestSlug,
      'p_lines': [
        for (final line in cart?.lines ?? const <OrderLine>[])
          if (line.menuItemId.isNotEmpty && line.qty > 0)
            {'menu_item_id': line.menuItemId, 'qty': line.qty},
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
      return result['error'] as String? ?? 'Order was not sent.';
    }
    await refreshFromDisk();
    return null;
  }

  Future<void> _writeCarts(Map<String, CartState> carts) async {
    _epoch++;
    _carts = carts;
    if (client == null || restaurantId == null) return;
    for (final cart in carts.values) {
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
                  },
                )
                .toList(),
          );
    }
  }

  ShiftExpense _mapExpense(Map<String, dynamic> row) => ShiftExpense(
    id: row['id'] as String,
    shiftId: row['shift_id'] as String,
    cashierId: row['cashier_id'] as String,
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
      return '$error';
    }
  }

  Future<String?> editShiftExpense({
    required String id,
    required String categoryId,
    required double amount,
    required String description,
  }) async {
    if (client == null) return 'Supabase is not configured.';
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
      return '$error';
    }
  }

  Future<void> writePayments(List<Payment> items) async => _payments = items;
  Future<void> writeShifts(List<CashShift> items) async {
    _shifts = items;
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

  Future<void> updateTableStatus(CafeTable table) async {
    final index = _tables.indexWhere((item) => item.id == table.id);
    if (index >= 0) _tables[index] = table;
    if (client == null || restaurantId == null) return;
    await client!
        .from('dining_tables')
        .update({'status': table.status.name, 'guests': table.guests})
        .eq('id', table.id);
  }

  Future<void> writeCalls(List<StaffCall> items) async {
    _calls = items;
    if (client == null || restaurantId == null) return;
    for (final item in items) {
      await client!.from('staff_calls').upsert({
        'id': item.id,
        'restaurant_id': restaurantId,
        'table_id': item.tableId,
        'kind': item.kind,
        'resolved': item.resolved,
        'created_at': item.createdAt.toIso8601String(),
      });
    }
  }

  Future<void> _deleteMissing(String table, List<String> keep) async {
    if (client == null) return;
    final rows = await client!.from(table).select('id');
    for (final row in rows as List) {
      final id = row['id'] as String;
      if (!keep.contains(id)) await client!.from(table).delete().eq('id', id);
    }
  }

  Future<String?> setItemAvailable(String itemId, bool available) async {
    if (client == null) return 'Supabase is not configured.';
    final match = _menuItems.where((item) => item.id == itemId);
    final previous = match.isEmpty ? null : match.first.available;
    if (match.isNotEmpty) match.first.available = available;
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
      return '$error';
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

  Future<void> confirmOrderRefusal(String orderId) async {
    if (client == null) return;
    await client!.rpc('confirm_order_refusal', params: {'p_order_id': orderId});
    final match = _orders.where((order) => order.id == orderId);
    if (match.isNotEmpty) {
      match.first.awaitingCustomerConfirmation = false;
      match.first.refusalNotice = '';
    }
  }

  Future<String> storeLogo(String value) => _storeImage('logo', value);

  Future<String> _storeImage(String itemId, String value) async {
    if (client == null || restaurantId == null || !value.startsWith('data:')) {
      return value;
    }
    final comma = value.indexOf(',');
    if (comma < 0) return value;
    final meta = value.substring(5, comma);
    final bytes = base64Decode(value.substring(comma + 1));
    final ext = meta.contains('png') ? 'png' : 'jpg';
    final path = '$restaurantId/$itemId.$ext';
    await client!.storage
        .from('menu-images')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            upsert: true,
            contentType: meta.split(';').first,
          ),
        );
    return client!.storage.from('menu-images').getPublicUrl(path);
  }
}

class Secrets {
  static final _random = Random.secure();

  static String salt([int length = 16]) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String value, String salt) => value;

  static String publicId([int length = 12]) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  static String otpCode() =>
      List.generate(6, (_) => _random.nextInt(10)).join();

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
