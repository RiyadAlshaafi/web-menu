import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import '../models/models.dart';

enum AuthKind { none, admin, cashier }

class CafeStore extends ChangeNotifier {
  CafeStore(this.db);

  final AppDatabase db;
  final currency = NumberFormat.currency(symbol: '€');

  late Map<String, dynamic> cafe;
  String locale = 'en';
  AdminAccount? admin;
  List<Cashier> cashiers = [];
  List<CafeTable> tables = [];
  List<MenuCategory> categories = [];
  List<MenuItem> menuItems = [];
  List<CafeOrder> orders = [];
  Map<String, CartState> carts = {};
  List<Payment> payments = [];
  List<CashShift> shifts = [];
  List<StaffCall> calls = [];

  AuthKind authKind = AuthKind.none;
  Cashier? currentCashier;
  CashShift? currentShift;

  String selectedCashierId = '';
  String pinBuffer = '';
  String? loginError;
  String? adminError;

  String otpEmail = '';
  DateTime? otpSentAt;
  DateTime? otpResendAt;
  bool otpVerified = false;
  int otpSecondsLeft = 0;
  Timer? _liveSync;
  String _syncStamp = '';

  Future<void> load() async {
    await db.init();
    cafe = db.cafe;
    locale = db.locale;
    admin = db.admin;
    cashiers = db.cashiers;
    tables = db.tables;
    categories = db.categories;
    menuItems = db.menuItems;
    orders = db.orders;
    carts = db.carts;
    payments = db.payments;
    shifts = db.shifts;
    calls = db.calls;
    _syncStamp = _stamp();
    if (db.rememberAdmin && admin != null) {
      authKind = AuthKind.admin;
    }
    notifyListeners();
    startLiveSync();
  }

  void startLiveSync() {
    _liveSync?.cancel();
    _liveSync = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(syncFromDisk());
    });
  }

  @override
  void notifyListeners() {
    _syncStamp = _stamp();
    super.notifyListeners();
  }

  @override
  void dispose() {
    _liveSync?.cancel();
    super.dispose();
  }

  String _stamp() => jsonEncode({
        'orders': orders.map((item) => item.toJson()).toList(),
        'tables': tables.map((item) => item.toJson()).toList(),
        'carts': carts.map((key, value) => MapEntry(key, value.toJson())),
        'menu': menuItems.map((item) => item.toJson()).toList(),
        'categories': categories.map((item) => item.toJson()).toList(),
        'calls': calls.map((item) => item.toJson()).toList(),
        'payments': payments.map((item) => item.toJson()).toList(),
        'shifts': shifts.map((item) => item.toJson()).toList(),
      });

  int _pendingWrites = 0;

  Future<void> syncFromDisk() async {
    if (_pendingWrites > 0) return;
    await db.refreshFromDisk(liveOnly: true);
    final next = _stampFromDb();
    if (next == _syncStamp) return;
    _hydrateOperational();
    _syncStamp = next;
    notifyListeners();
  }

  String _stampFromDb() => jsonEncode({
        'orders': db.orders.map((item) => item.toJson()).toList(),
        'tables': db.tables.map((item) => item.toJson()).toList(),
        'carts': db.carts.map((key, value) => MapEntry(key, value.toJson())),
        'menu': db.menuItems.map((item) => item.toJson()).toList(),
        'categories': db.categories.map((item) => item.toJson()).toList(),
        'calls': db.calls.map((item) => item.toJson()).toList(),
        'payments': db.payments.map((item) => item.toJson()).toList(),
        'shifts': db.shifts.map((item) => item.toJson()).toList(),
      });

  void _hydrateOperational() {
    cafe = db.cafe;
    locale = db.locale;
    admin = db.admin;
    cashiers = db.cashiers;
    tables = db.tables;
    categories = db.categories;
    menuItems = db.menuItems;
    orders = db.orders;
    carts = db.carts;
    payments = db.payments;
    shifts = db.shifts;
    calls = db.calls;
    if (currentShift != null) {
      final match = shifts.where((shift) => shift.id == currentShift!.id);
      currentShift = match.isEmpty ? currentShift : match.first;
    }
  }

  bool get hasAdmin => admin != null || db.anyAdmin;
  String get databasePath => db.databasePath;
  bool get isSqlite => db.isSqlite;
  double get serviceChargeRate => (cafe['serviceChargeRate'] as num?)?.toDouble() ?? 0.10;
  double get taxRate => (cafe['taxRate'] as num?)?.toDouble() ?? 0;

  List<MenuItem> get liveMenu {
    final visibleIds = guestCategories.map((item) => item.id).toSet();
    final items = menuItems
        .where((item) => item.available && !item.soldOut && visibleIds.contains(item.categoryId))
        .toList()
      ..sort((a, b) {
        final category = a.sortOrder.compareTo(b.sortOrder);
        return category;
      });
    return items;
  }

  List<MenuItem> dishesIn(String categoryId) {
    final items = menuItems.where((item) => item.categoryId == categoryId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  CafeTable? tableBySlug(String slug) {
    final matches = tables.where((table) => table.qrSlug == slug || table.id == slug || table.number == slug);
    return matches.isEmpty ? null : matches.first;
  }

  CafeTable tableById(String id) => tables.firstWhere((table) => table.id == id);

  CartState cartFor(String tableId) =>
      carts.putIfAbsent(tableId, () => CartState(tableId: tableId));

  CafeOrder? openOrderFor(String tableId) {
    final open = orders
        .where((order) => order.tableId == tableId && order.status != OrderStatus.paid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return open.isEmpty ? null : open.first;
  }

  List<CafeOrder> liveOrders() =>
      orders.where((order) => order.status != OrderStatus.paid).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<StaffCall> get openCalls => calls.where((call) => !call.resolved).toList();

  List<CafeTable> get billTables {
    final requested = <String>{
      for (final table in tables)
        if (table.status == TableStatus.billRequested) table.id,
      for (final call in openCalls)
        if (call.kind == 'bill') call.tableId,
    };
    return tables.where((table) => requested.contains(table.id)).toList();
  }

  double tabSubtotal(String tableId) =>
      (openOrderFor(tableId)?.subtotal ?? 0) + cartFor(tableId).total;

  double serviceCharge(double subtotal) => subtotal * serviceChargeRate;

  /// One formula for the amount on screen and the amount sent to settlement.
  double chargeTotal(double subtotal, {bool applyService = true}) =>
      applyService ? subtotal + serviceCharge(subtotal) : subtotal;

  double tabTotal(String tableId, {bool applyService = true}) {
    return chargeTotal(tabSubtotal(tableId), applyService: applyService);
  }

  int tabItemCount(String tableId) =>
      (openOrderFor(tableId)?.itemCount ?? 0) + cartFor(tableId).itemCount;

  CashShift? get openShift {
    final open = shifts.where((shift) => shift.isOpen).toList();
    return open.isEmpty ? null : open.first;
  }

  AppLocalizations get l10n => lookupAppLocalizations(Locale(locale));

  Future<void> setLocale(String value) async {
    locale = value;
    await db.writeLocale(value);
    notifyListeners();
  }

  Future<String?> createAdmin({
    required String email,
    required String password,
    required String confirm,
  }) async {
    if (admin != null) return l10n.errAdminExists;
    final trimmed = email.trim().toLowerCase();
    if (!_validEmail(trimmed)) return l10n.errInvalidEmail;
    if (password != confirm) return l10n.errPasswordsMismatch;
    if (!Secrets.validPassword(password)) return l10n.errWeakPassword;
    if (db.client == null) return 'Add SUPABASE_URL and SUPABASE_ANON_KEY before creating an admin.';
    final AuthResponse response;
    try {
      response = await db.client!.auth.signUp(email: trimmed, password: password);
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return 'Could not reach Supabase: $error';
    }
    if (response.session == null) {
      await db.refreshFromDisk();
      notifyListeners();
      return 'Confirm the account from the email Supabase sent, then sign in. In Supabase Auth, turn off Confirm email if you want to enter immediately.';
    }
    await db.refreshFromDisk();
    admin = db.admin;
    authKind = AuthKind.admin;
    notifyListeners();
    return null;
  }

  Future<String?> signInAdmin(String email, String password, {bool remember = false}) async {
    if (db.client == null) return 'Add SUPABASE_URL and SUPABASE_ANON_KEY before signing in.';
    try {
      await db.client!.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
    } on AuthException catch (error) {
      adminError = error.statusCode == '400' ? l10n.errBadCredentials : error.message;
      notifyListeners();
      return adminError;
    } catch (error) {
      adminError = 'Could not reach Supabase: $error';
      notifyListeners();
      return adminError;
    }
    await db.refreshFromDisk();
    admin = db.admin;
    if (admin == null) {
      adminError = l10n.errNoAdmin;
      notifyListeners();
      return adminError;
    }
    authKind = AuthKind.admin;
    adminError = null;
    await db.writeRememberAdmin(remember);
    notifyListeners();
    return null;
  }

  Future<void> requestPasswordReset(String email) async {
    otpEmail = email.trim().toLowerCase();
    otpVerified = false;
    otpSentAt = DateTime.now();
    otpResendAt = DateTime.now().add(const Duration(seconds: 44));
    if (db.client != null) {
      await db.client!.auth.resetPasswordForEmail(otpEmail);
    }
    notifyListeners();
  }

  bool get canResendOtp =>
      otpResendAt == null || DateTime.now().isAfter(otpResendAt!);

  Future<String?> verifyOtp(String code) async {
    if (db.client == null) return l10n.errBadCode;
    try {
      await db.client!.auth.verifyOTP(email: otpEmail, token: code, type: OtpType.recovery);
    } on AuthException {
      return l10n.errBadCode;
    }
    otpVerified = true;
    notifyListeners();
    return null;
  }

  Future<String?> completePasswordReset({
    required String password,
    required String confirm,
  }) async {
    if (!otpVerified) return l10n.errVerifyCodeFirst;
    if (password != confirm) return l10n.errPasswordsMismatch;
    if (!Secrets.validPassword(password)) return l10n.errWeakPassword;
    if (db.client == null) return l10n.errNoAdmin;
    await db.client!.auth.updateUser(UserAttributes(password: password));
    otpVerified = false;
    notifyListeners();
    return null;
  }

  void selectCashier(String id) {
    selectedCashierId = id;
    loginError = null;
    notifyListeners();
  }

  void enterPinDigit(String digit) {
    if (pinBuffer.length >= 4) return;
    pinBuffer += digit;
    loginError = null;
    notifyListeners();
  }

  void clearPin() {
    pinBuffer = '';
    notifyListeners();
  }

  void deletePin() {
    if (pinBuffer.isEmpty) return;
    pinBuffer = pinBuffer.substring(0, pinBuffer.length - 1);
    notifyListeners();
  }

  Future<bool> signInCashier() async {
    if (selectedCashierId.isEmpty) {
      loginError = l10n.errSelectCashier;
      notifyListeners();
      return false;
    }
    if (pinBuffer.length != 4) {
      loginError = l10n.errEnterPin;
      notifyListeners();
      return false;
    }
    final result = await db.loginCashier(selectedCashierId, pinBuffer);
    if (result['ok'] != true) {
      final member = cashiers.where((item) => item.id == selectedCashierId);
      final name = member.isEmpty ? '' : member.first.name;
      if (result['code'] == 'locked') {
        final seconds = (result['retry_after_seconds'] as num?)?.toInt() ?? 900;
        loginError = l10n.errPinLocked(name, (seconds / 60).ceil());
      } else {
        loginError = result['error'] as String? ?? l10n.errPinMismatch(name);
      }
      pinBuffer = '';
      notifyListeners();
      return false;
    }
    await syncFromDisk();
    currentCashier = cashiers.where((item) => item.id == selectedCashierId).firstOrNull ?? cashiers.firstOrNull;
    authKind = AuthKind.cashier;
    pinBuffer = '';
    loginError = null;
    try {
      await _ensureShift();
    } catch (error) {
      loginError = '$error';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<void> _ensureShift() async {
    final cashier = currentCashier;
    if (cashier == null) return;
    final existing = shifts.where((shift) => shift.isOpen && shift.cashierId == cashier.id);
    if (existing.isNotEmpty) {
      currentShift = existing.first;
      return;
    }
    currentShift = CashShift(
      id: Secrets.id('shift'),
      cashierId: cashier.id,
      openedAt: DateTime.now(),
      openingCash: 0,
    );
    shifts.insert(0, currentShift!);
    await db.writeShifts(shifts);
  }

  Future<void> ensureGuest(String slug) async {
    if (db.guestSlug == slug && tables.any((table) => table.qrSlug == slug)) return;
    await db.setGuestSlug(slug);
    _hydrateOperational();
    notifyListeners();
  }

  void signOut() {
    authKind = AuthKind.none;
    currentCashier = null;
    currentShift = null;
    pinBuffer = '';
    db.cashierToken = null;
    db.client?.auth.signOut();
    notifyListeners();
  }

  Future<void> addCashier({required String name, required String pin}) async {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    final id = await db.createCashier(name: name.trim(), pin: pin, initials: initials.isEmpty ? 'C' : initials);
    if (id == null) return;
    await syncFromDisk();
    notifyListeners();
  }

  Future<void> deleteCashier(String id) async {
    cashiers.removeWhere((item) => item.id == id);
    await db.writeCashiers(cashiers);
    notifyListeners();
  }

  Future<CafeTable> addTable(String number) async {
    final slug = number.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final table = CafeTable(
      id: Secrets.id('tbl'),
      number: number.trim(),
      qrSlug: slug.isEmpty ? Secrets.id('t') : slug,
    );
    tables.add(table);
    await db.writeTables(tables);
    notifyListeners();
    return table;
  }

  Future<void> deleteTable(String id) async {
    tables.removeWhere((table) => table.id == id);
    await db.writeTables(tables);
    notifyListeners();
  }

  List<MenuCategory> get orderedCategories {
    final items = [...categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  List<MenuCategory> get guestCategories =>
      orderedCategories.where((category) => category.visible).toList();

  Future<void> addCategory(String nameEn, String nameAr, {bool spotlight = false}) async {
    categories.add(
      MenuCategory(
        id: Secrets.id('cat'),
        nameEn: nameEn.trim(),
        nameAr: nameAr.trim().isEmpty ? nameEn.trim() : nameAr.trim(),
        sortOrder: categories.isEmpty ? 1 : categories.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
        spotlight: spotlight,
      ),
    );
    await db.writeCategories(categories);
    notifyListeners();
  }

  Future<void> saveCategory(MenuCategory category) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index >= 0) categories[index] = category;
    await db.writeCategories(categories);
    notifyListeners();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final ordered = orderedCategories;
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    final item = ordered.removeAt(oldIndex);
    ordered.insert(newIndex.clamp(0, ordered.length), item);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i + 1;
    }
    categories = ordered;
    await db.writeCategories(categories);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    categories.removeWhere((item) => item.id == id);
    menuItems.removeWhere((item) => item.categoryId == id);
    await db.writeCategories(categories);
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> saveMenuItem(MenuItem item) async {
    final index = menuItems.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      menuItems[index] = item;
    } else {
      if (item.sortOrder == 0) {
        final siblings = dishesIn(item.categoryId);
        item.sortOrder = siblings.isEmpty ? 1 : siblings.map((entry) => entry.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      }
      menuItems.add(item);
    }
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> reorderDishes(String categoryId, int oldIndex, int newIndex) async {
    final ordered = dishesIn(categoryId);
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    final item = ordered.removeAt(oldIndex);
    ordered.insert(newIndex.clamp(0, ordered.length), item);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i + 1;
    }
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> persistLayout() async {
    await db.writeCategories(categories);
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> setDishDiscount(MenuItem item, {required double percent, required bool applied}) async {
    item
      ..discountPercent = percent.clamp(0, 100)
      ..discountApplied = applied && percent > 0;
    await saveMenuItem(item);
  }

  Future<void> applyCategoryDiscount({
    required String? categoryId,
    required double percent,
    required bool activate,
  }) async {
    final rate = percent.clamp(0, 100).toDouble();
    for (final item in menuItems.where((dish) => categoryId == null || dish.categoryId == categoryId)) {
      item
        ..discountPercent = rate
        ..discountApplied = activate && rate > 0;
    }
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> deleteMenuItem(String id) async {
    menuItems.removeWhere((item) => item.id == id);
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  void addToCart(String tableId, MenuItem item) {
    if (item.soldOut || !item.available) return;
    final cart = cartFor(tableId);
    final existing = cart.lines.where((line) => line.menuItemId == item.id);
    if (existing.isEmpty) {
      cart.lines.add(
        OrderLine(
          menuItemId: item.id,
          name: item.displayName(locale),
          qty: 1,
          unitPrice: item.salePrice,
        ),
      );
    } else {
      existing.first.qty += 1;
    }
    db.writeCarts(carts).whenComplete(() {
      if (_pendingWrites > 0) _pendingWrites -= 1;
    });
    _pendingWrites += 1;
    notifyListeners();
  }

  void setCartQty(String tableId, String menuItemId, int qty) {
    final cart = cartFor(tableId);
    cart.lines.removeWhere((line) => line.menuItemId == menuItemId && qty <= 0);
    for (final line in cart.lines.where((line) => line.menuItemId == menuItemId)) {
      line.qty = qty;
    }
    _pendingWrites += 1;
    db.writeCarts(carts).whenComplete(() {
      if (_pendingWrites > 0) _pendingWrites -= 1;
    });
    notifyListeners();
  }

  final Set<String> _sendingTables = {};
  final Set<String> _confirmingOrders = {};

  bool isSendingOrder(String tableId) => _sendingTables.contains(tableId);

  bool tryBeginOrderConfirm(String tableId) {
    if (_sendingTables.contains(tableId)) return false;
    return _confirmingOrders.add(tableId);
  }

  void endOrderConfirm(String tableId) => _confirmingOrders.remove(tableId);

  Future<CafeOrder?> sendCartToKitchen(String tableId) async {
    if (!_sendingTables.add(tableId)) return openOrderFor(tableId);
    notifyListeners();
    if (cartFor(tableId).lines.isEmpty) {
      _sendingTables.remove(tableId);
      notifyListeners();
      return openOrderFor(tableId);
    }
    _pendingWrites += 1;
    try {
      final error = await db.sendTableCart(tableId);
      if (error != null) throw StateError(error);
      _hydrateOperational();
    } finally {
      if (_pendingWrites > 0) _pendingWrites -= 1;
      _sendingTables.remove(tableId);
    }
    notifyListeners();
    return openOrderFor(tableId);
  }

  Future<void> requestBill(String tableId) async {
    if (cartFor(tableId).lines.isNotEmpty) {
      try {
        await sendCartToKitchen(tableId);
      } catch (error, stack) {
        debugPrint('Kitchen send before bill request failed: $error\n$stack');
      }
    }
    if (openOrderFor(tableId) == null) return;
    final table = tableById(tableId);
    table.status = TableStatus.billRequested;
    final openBill = calls.any((call) => call.tableId == tableId && call.kind == 'bill' && !call.resolved);
    if (!openBill) {
      calls.add(
        StaffCall(
          id: Secrets.id(),
          tableId: tableId,
          tableNumber: table.number,
          createdAt: DateTime.now(),
          kind: 'bill',
        ),
      );
    }
    try {
      await db.updateTableStatus(table);
    } catch (error, stack) {
      debugPrint('Table bill status was not saved: $error\n$stack');
    }
    await db.writeCalls(calls);
    notifyListeners();
  }

  Future<void> callStaff(String tableId, {String kind = 'assistance'}) async {
    calls.add(
      StaffCall(
        id: Secrets.id('call'),
        tableId: tableId,
        tableNumber: tableById(tableId).number,
        createdAt: DateTime.now(),
        kind: kind,
      ),
    );
    await db.writeCalls(calls);
    notifyListeners();
  }

  Future<void> resolveCall(String id) async {
    final match = calls.where((call) => call.id == id);
    if (match.isEmpty) return;
    match.first.resolved = true;
    await db.writeCalls(calls);
    notifyListeners();
  }

  void setOrderStatus(String orderId, OrderStatus status) {
    final order = orders.firstWhere((item) => item.id == orderId);
    if (order.status.next != status) return;
    order.status = status;
    db.writeOrders(orders);
    notifyListeners();
  }

  Future<String?> settleCash({
    required String tableId,
    required double cashReceived,
    bool applyService = true,
  }) async {
    final cashier = currentCashier;
    final shift = currentShift ?? openShift;
    if (cashier == null || shift == null) return l10n.errCashierSignInFirst;
    final order = openOrderFor(tableId);
    if (order == null) return l10n.errNoOpenBill;
    final due = tabTotal(tableId, applyService: applyService);
    if (cashReceived < due) return l10n.insufficientCash;
    final failure = await db.settleCash(tableId, cashReceived, applyService: applyService);
    if (failure != null) return failure == 'insufficient cash' ? l10n.insufficientCash : failure;
    await syncFromDisk();
    notifyListeners();
    return null;
  }

  Future<String?> closeShift({required double actualCash}) async {
    final shift = currentShift ?? openShift;
    if (shift == null) return l10n.errNoOpenShift;
    shift
      ..actualCash = actualCash
      ..closedAt = DateTime.now();
    await db.writeShifts(shifts);
    currentShift = null;
    notifyListeners();
    return null;
  }

  Future<void> setOpeningCash(double value) async {
    final shift = currentShift ?? openShift;
    if (shift == null) return;
    shift.openingCash = value;
    await db.writeShifts(shifts);
    notifyListeners();
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
}
