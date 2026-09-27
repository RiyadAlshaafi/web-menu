import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl {
    final uri = Uri.tryParse(_rawSupabaseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    return uri.origin;
  }

  bool _ready = false;
  bool _listening = false;
  int _epoch = 0;
  DateTime? _catalogAt;
  Timer? _liveRefresh;
  String? restaurantId;
  String? cashierToken;
  String? guestSlug;
  bool anyAdmin = false;

  Map<String, dynamic> _cafe = {'name': '', 'serviceChargeRate': 0.10, 'taxRate': 0};
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
  List<CashShift> _shifts = [];
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
  List<CashShift> get shifts => List<CashShift>.from(_shifts);
  List<StaffCall> get calls => List<StaffCall>.from(_calls);
  Map<String, dynamic>? get otp => null;
  int get nextOrderId => 1001;

  Future<void> init({bool memory = false}) async {
    if (!isConfigured || memory) {
      _clear();
      return;
    }
    try {
      if (!_ready) {
        await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
        _ready = true;
      }
      _listen();
      await refreshFromDisk();
    } catch (error, stack) {
      debugPrint('Supabase startup failed: $error\n$stack');
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
    _cafe = {'name': '', 'serviceChargeRate': 0.10, 'taxRate': 0};
    _locale = 'en';
    _admin = null;
    _cashiers = [];
    _tables = [];
    _categories = [];
    _menuItems = [];
    _orders = [];
    _carts = {};
    _payments = [];
    _shifts = [];
    _calls = [];
  }

  void _listen() {
    if (_listening || client == null) return;
    try {
      _listening = true;
      void scheduleLive() {
        _liveRefresh?.cancel();
        _liveRefresh = Timer(const Duration(milliseconds: 400), () {
          refreshFromDisk(liveOnly: true);
        });
      }

      client!
          .channel('cafe-sync')
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'orders', callback: (_) => scheduleLive())
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'dining_tables', callback: (_) => scheduleLive())
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'staff_calls', callback: (_) => scheduleLive())
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'payments', callback: (_) => scheduleLive())
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'carts', callback: (_) => scheduleLive())
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'cart_lines', callback: (_) => scheduleLive())
          .subscribe();
    } catch (error, stack) {
      _listening = false;
      debugPrint('Realtime setup failed: $error\n$stack');
    }
  }

  void _applyHeaders() {
    final current = client;
    if (current == null) return;
    final headers = Map<String, String>.from(current.headers)
      ..remove('x-qr-slug')
      ..remove('x-cashier-token');
    if (guestSlug != null) headers['x-qr-slug'] = guestSlug!;
    if (cashierToken != null) headers['x-cashier-token'] = cashierToken!;
    current.headers = headers;
  }

  Future<void> setGuestSlug(String? slug) async {
    guestSlug = slug == null || slug.isEmpty ? null : slug;
    _applyHeaders();
    await refreshFromDisk();
  }

  Future<void> refreshFromDisk({bool liveOnly = false}) async {
    if (client == null) return;
    final catalogFresh = _catalogAt != null && DateTime.now().difference(_catalogAt!) < const Duration(seconds: 60);
    try {
      await _refreshFromDisk(liveOnly: liveOnly && catalogFresh);
    } catch (error, stack) {
      debugPrint('Supabase refresh failed: $error\n$stack');
    }
  }

  Future<void> _refreshFromDisk({bool liveOnly = false}) async {
    final epoch = _epoch;
    _applyHeaders();
    anyAdmin = await client!.rpc('has_any_admin') as bool? ?? false;
    final user = client!.auth.currentUser;
    if (user != null) {
      final profile = await client!.from('profiles').select('restaurant_id, display_name').eq('id', user.id).maybeSingle();
      restaurantId = profile?['restaurant_id'] as String?;
      _admin = AdminAccount(email: user.email ?? '', passwordHash: '', passwordSalt: '', displayName: profile?['display_name'] as String? ?? 'Admin');
      _rememberAdmin = true;
    } else if (cashierToken == null) {
      _admin = null;
      _rememberAdmin = false;
    }
    if (!liveOnly && restaurantId != null) {
      final restaurant = await client!.from('restaurants').select().eq('id', restaurantId!).maybeSingle();
      if (restaurant != null) {
        _locale = restaurant['locale'] as String? ?? 'en';
        _cafe = {
          'name': restaurant['name'] ?? '',
          'serviceChargeRate': (restaurant['service_charge_rate'] as num?)?.toDouble() ?? 0.10,
          'taxRate': (restaurant['tax_rate'] as num?)?.toDouble() ?? 0,
        };
      }
    }
    if (!liveOnly) {
      final staffRaw = await client!.rpc(
        'list_pos_cashiers',
        params: restaurantId == null ? null : {'p_restaurant_id': restaurantId},
      );
      final staff = staffRaw is List ? staffRaw : <dynamic>[];
      _cashiers = staff.map((row) {
        final map = row as Map<String, dynamic>;
        return Cashier(id: map['id'] as String, name: map['name'] as String, pinHash: '', pinSalt: '', initials: map['initials'] as String? ?? 'C');
      }).toList();
    }
    if (restaurantId == null && guestSlug == null) {
      _tables = [];
      _categories = [];
      _menuItems = [];
      _orders = [];
      _carts = {};
      _payments = [];
      _shifts = [];
      _calls = [];
      return;
    }
    final tableRows = await client!.from('dining_tables').select();
    final tableList = tableRows as List;
    if (restaurantId == null && tableList.isNotEmpty) {
      restaurantId = tableList.first['restaurant_id'] as String?;
    }
    if (epoch != _epoch) return;
    _tables = tableList.map((row) => CafeTable(
          id: row['id'] as String,
          number: row['number'] as String,
          qrSlug: row['qr_slug'] as String,
          zone: row['zone'] as String? ?? 'Main Floor',
          seats: row['seats'] as int? ?? 4,
          status: TableStatus.values.firstWhere((value) => value.name == row['status'], orElse: () => TableStatus.free),
          guests: row['guests'] as int? ?? 0,
        )).toList();
    if (!liveOnly) {
    final categoryRows = await client!.from('menu_categories').select();
    _categories = (categoryRows as List).map((row) => MenuCategory(
          id: row['id'] as String,
          nameEn: row['name_en'] as String? ?? '',
          nameAr: row['name_ar'] as String? ?? '',
          sortOrder: row['sort_order'] as int? ?? 0,
          spotlight: row['spotlight'] as bool? ?? false,
          visible: row['visible'] as bool? ?? true,
        )).toList();
    final itemRows = await client!.from('menu_items').select();
    _menuItems = (itemRows as List).map((row) => MenuItem(
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
        )).toList();
      _catalogAt = DateTime.now();
    }
    if (epoch != _epoch) return;
    final orderRows = await client!.from('orders').select('*, order_lines(*)');
    _orders = (orderRows as List).map((row) {
      final table = _tables.where((item) => item.id == row['table_id']);
      return CafeOrder(
        id: row['id'] as String,
        tableId: row['table_id'] as String,
        tableNumber: table.isEmpty ? '' : table.first.number,
        status: OrderStatus.values.firstWhere((value) => value.name == row['status'], orElse: () => OrderStatus.received),
        createdAt: DateTime.parse(row['created_at'] as String),
        notes: row['notes'] as String? ?? '',
        cashierId: row['cashier_id'] as String?,
        lines: ((row['order_lines'] as List?) ?? []).map((line) => OrderLine(
              menuItemId: line['menu_item_id'] as String? ?? '',
              name: line['name'] as String? ?? '',
              qty: (line['qty'] as num?)?.toInt() ?? 1,
              unitPrice: (line['unit_price'] as num?)?.toDouble() ?? 0,
            )).toList(),
      );
    }).toList();
    final cartRows = await client!.from('carts').select('*, cart_lines(*)');
    _carts = {
      for (final row in cartRows as List)
        row['table_id'] as String: CartState(
          tableId: row['table_id'] as String,
          lines: ((row['cart_lines'] as List?) ?? []).map((line) => OrderLine(
                menuItemId: line['menu_item_id'] as String? ?? '',
                name: line['name'] as String? ?? '',
                qty: (line['qty'] as num?)?.toInt() ?? 1,
                unitPrice: (line['unit_price'] as num?)?.toDouble() ?? 0,
              )).toList(),
        ),
    };
    final callRows = await client!.from('staff_calls').select();
    _calls = (callRows as List).map((row) {
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
    if (client!.auth.currentUser != null || cashierToken != null) {
      final paymentRows = await client!.from('payments').select();
      _payments = (paymentRows as List).map((row) => Payment(
            id: row['id'] as String,
            orderId: row['order_id'] as String,
            tableId: row['table_id'] as String,
            totalDue: (row['total_due'] as num).toDouble(),
            cashReceived: (row['cash_received'] as num).toDouble(),
            changeDue: (row['change_due'] as num).toDouble(),
            cashierId: row['cashier_id'] as String,
            shiftId: row['shift_id'] as String,
            paidAt: DateTime.parse(row['paid_at'] as String),
          )).toList();
      final shiftRows = await client!.from('shifts').select();
      _shifts = (shiftRows as List).map((row) => CashShift(
            id: row['id'] as String,
            cashierId: row['cashier_id'] as String,
            openedAt: DateTime.parse(row['opened_at'] as String),
            closedAt: row['closed_at'] == null ? null : DateTime.parse(row['closed_at'] as String),
            openingCash: (row['opening_cash'] as num?)?.toDouble() ?? 0,
            cashSales: (row['cash_sales'] as num?)?.toDouble() ?? 0,
            cashRefunds: (row['cash_refunds'] as num?)?.toDouble() ?? 0,
            cashAdjustments: (row['cash_adjustments'] as num?)?.toDouble() ?? 0,
            actualCash: (row['actual_cash'] as num?)?.toDouble(),
            transactionCount: row['transaction_count'] as int? ?? 0,
          )).toList();
    } else {
      _payments = [];
      _shifts = [];
    }
  }

  Future<int> takeNextOrderId() async => nextOrderId;
  Future<void> writeOtp(Map<String, dynamic>? value) async {}
  Future<void> writeRememberAdmin(bool value) async => _rememberAdmin = value;
  Future<void> writeAdmin(AdminAccount? admin) async => _admin = admin;

  Future<void> writeLocale(String locale) async {
    _locale = locale;
    if (client == null || restaurantId == null) return;
    await client!.from('restaurants').update({'locale': locale}).eq('id', restaurantId!);
  }

  Future<void> writeCafe(Map<String, dynamic> cafe) async {
    _cafe = Map<String, dynamic>.from(cafe);
    if (client == null || restaurantId == null) return;
    await client!.from('restaurants').update({
      'name': cafe['name'] ?? '',
      'service_charge_rate': cafe['serviceChargeRate'] ?? 0.10,
      'tax_rate': cafe['taxRate'] ?? 0,
      'locale': _locale,
    }).eq('id', restaurantId!);
  }

  Future<String?> createCashier({required String name, required String pin, required String initials}) async {
    if (client == null) return null;
    final id = await client!.rpc('create_cashier', params: {'p_name': name, 'p_pin': pin, 'p_initials': initials});
    await refreshFromDisk();
    return id as String?;
  }

  Future<Map<String, dynamic>> loginCashier(String cashierId, String pin) async {
    if (client == null) return {'ok': false, 'error': 'Supabase is not configured.'};
    try {
      final raw = await client!.rpc('cashier_login', params: {'p_cashier_id': cashierId, 'p_pin': pin});
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] == true) {
        cashierToken = result['token'] as String?;
        restaurantId = result['restaurant_id'] as String?;
        _applyHeaders();
        await refreshFromDisk();
      }
      return result;
    } catch (error) {
      return {'ok': false, 'error': '$error'};
    }
  }

  Future<String?> settleCash(String tableId, double cashReceived, {bool applyService = true}) async {
    if (client == null) return 'Supabase is not configured.';
    _applyHeaders();
    final raw = await client!.rpc('settle_cash', params: {
      'p_table_id': tableId,
      'p_cash_received': cashReceived,
      'p_apply_service': applyService,
    });
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['ok'] == true) {
      await refreshFromDisk();
      return null;
    }
    return result['error'] as String? ?? 'Payment failed.';
  }

  Future<void> writeCashiers(List<Cashier> items) async {
    _cashiers = items;
    if (client == null || restaurantId == null || client!.auth.currentUser == null) return;
    final keep = items.map((item) => item.id).toSet();
    final existing = await client!.from('cashiers').select('id');
    for (final row in existing as List) {
      if (!keep.contains(row['id'])) await client!.from('cashiers').delete().eq('id', row['id'] as String);
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
    await _deleteMissing('dining_tables', items.map((item) => item.id).toList());
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
    await _deleteMissing('menu_categories', items.map((item) => item.id).toList());
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
      await client!.from('order_lines').insert(item.lines.map((line) => {
            'order_id': item.id,
            'restaurant_id': restaurantId,
            'menu_item_id': line.menuItemId.isEmpty ? null : line.menuItemId,
            'name': line.name,
            'qty': line.qty,
            'unit_price': line.unitPrice,
          }).toList());
    }
  }

  Future<void> writeCarts(Map<String, CartState> carts) async {
    _epoch++;
    _carts = carts;
    if (client == null || restaurantId == null) return;
    for (final cart in carts.values) {
      await client!.from('carts').upsert({'table_id': cart.tableId, 'restaurant_id': restaurantId});
      await client!.from('cart_lines').delete().eq('table_id', cart.tableId);
      if (cart.lines.isEmpty) continue;
      await client!.from('cart_lines').insert(cart.lines.map((line) => {
            'table_id': cart.tableId,
            'restaurant_id': restaurantId,
            'menu_item_id': line.menuItemId.isEmpty ? null : line.menuItemId,
            'name': line.name,
            'qty': line.qty,
            'unit_price': line.unitPrice,
          }).toList());
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
    await _deleteMissing('staff_calls', items.map((item) => item.id).toList());
  }

  Future<void> _deleteMissing(String table, List<String> keep) async {
    if (client == null) return;
    final rows = await client!.from(table).select('id');
    for (final row in rows as List) {
      final id = row['id'] as String;
      if (!keep.contains(id)) await client!.from(table).delete().eq('id', id);
    }
  }

  Future<String> _storeImage(String itemId, String value) async {
    if (client == null || restaurantId == null || !value.startsWith('data:')) return value;
    final comma = value.indexOf(',');
    if (comma < 0) return value;
    final meta = value.substring(5, comma);
    final bytes = base64Decode(value.substring(comma + 1));
    final ext = meta.contains('png') ? 'png' : 'jpg';
    final path = '$restaurantId/$itemId.$ext';
    await client!.storage.from('menu-images').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(upsert: true, contentType: meta.split(';').first),
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

  static String otpCode() => List.generate(6, (_) => _random.nextInt(10)).join();

  static String id([String prefix = 'id']) {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static bool validPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }
}
