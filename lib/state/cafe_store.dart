import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import '../device_location.dart';
import '../models/models.dart';
import '../money.dart';
import '../report_error.dart';
import '../takeout_receipt.dart';
import '../theme/cafe_theme.dart';

part 'cafe_store_settings.dart';
part 'cafe_store_catalog.dart';
part 'cafe_store_orders.dart';
part 'cafe_store_payments.dart';
part 'cafe_store_location.dart';

enum AuthKind { none, admin, cashier }

enum GuestLocationStatus { off, checking, allowed, tooFar, denied, unavailable }

class CafeStore extends ChangeNotifier {
  CafeStore(this.db);

  final AppDatabase db;
  CafeMoney get currency => CafeMoney(locale);

  /// Prices on guest screens follow the language the guest picked.
  CafeMoney get guestCurrency => CafeMoney(guestLocale);

  late Map<String, dynamic> cafe;
  String locale = 'en';
  String? guestLocaleOverride;
  AdminAccount? admin;
  List<Cashier> cashiers = [];
  List<CafeTable> tables = [];
  List<MenuCategory> categories = [];
  List<MenuItem> menuItems = [];
  List<CafeOrder> orders = [];
  Map<String, CartState> carts = {};
  List<Payment> payments = [];
  List<PaymentType> paymentTypes = [];
  List<ExpenseCategory> expenseCategories = [];
  List<CashShift> shifts = [];
  List<ShiftExpense> expenses = [];
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
  /// Fingerprint of local state, computed lazily so mutations stay cheap.
  String? _syncStampCache;
  String get _syncStamp => _syncStampCache ??= _stamp();
  GuestLocationStatus guestLocation = GuestLocationStatus.off;
  DateTime? _guestNearUntil;
  double? _guestLat;
  double? _guestLng;
  double? _guestAccuracyM;
  bool _guestLocationStarted = false;
  bool _guestLocationBusy = false;
  bool _takeoutBusy = false;

  bool get canPlaceOrder =>
      guestLocation == GuestLocationStatus.off ||
      guestLocation == GuestLocationStatus.allowed;

  Future<void> load() async {
    await db.init();
    // Don't open on an empty app: give the first data load up to 15 seconds.
    await db.waitForFirstLoad(const Duration(seconds: 15));
    cafe = db.cafe;
    locale = db.locale;
    await _loadGuestLocale();
    admin = db.admin;
    cashiers = db.cashiers;
    tables = db.tables;
    categories = db.categories;
    menuItems = db.menuItems;
    orders = db.orders;
    carts = db.carts;
    payments = db.payments;
    paymentTypes = db.paymentTypes;
    expenseCategories = db.expenseCategories;
    shifts = db.shifts;
    expenses = db.expenses;
    calls = db.calls;
    _syncStampCache = null;
    if (db.adminFromOtherCafe) {
      // A saved session from another cafe must not reopen this device's cafe.
      await _dropForeignAdmin();
    } else if (db.rememberAdmin && admin != null) {
      authKind = AuthKind.admin;
    }
    notifyListeners();
    startLiveSync();
  }

  void startLiveSync() {
    _liveSync?.cancel();
    db.onLiveChange = () {
      unawaited(syncFromDisk());
    };
    db.startRealtime();
    // Realtime pushes changes; this poll is only a safety net if the channel drops.
    _liveSync = Timer.periodic(const Duration(seconds: 90), (_) {
      unawaited(syncFromDisk());
    });
  }

  void stopLiveSync() {
    _liveSync?.cancel();
    _liveSync = null;
    db.onLiveChange = null;
    db.stopRealtime();
  }

  @override
  void notifyListeners() {
    _syncStampCache = null;
    super.notifyListeners();
  }

  @override
  void dispose() {
    stopLiveSync();
    super.dispose();
  }

  String _cafeStamp(Map<String, dynamic> cafe, String locale) =>
      '$locale|${cafe['name']}|${cafe['logoUrl']}|${cafe['headerColor']}|${cafe['sidebarColor']}|${cafe['backgroundColor']}|${cafe['buttonColor']}';

  String _stamp() => _fingerprint(
    cafe: cafe,
    locale: locale,
    orders: orders,
    tables: tables,
    carts: carts,
    menu: menuItems,
    categories: categories,
    calls: calls,
    payments: payments,
    paymentTypes: paymentTypes,
    expenseCategories: expenseCategories,
    shifts: shifts,
    expenses: expenses,
  );

  int _pendingWrites = 0;
  final Map<String, String> _serviceBySlug = {};
  final Set<String> _sendingTables = {};
  final Set<String> _confirmingOrders = {};

  Future<void> syncFromDisk() async {
    if (_pendingWrites > 0) return;
    await db.refreshFromDisk(liveOnly: true);
    final next = _stampFromDb();
    if (next != _syncStamp) {
      _hydrateOperational();
      _syncStampCache = next;
      notifyListeners();
    }
    await ensureShiftNumbers();
  }

  bool _assigningNumbers = false;

  Future<void> ensureShiftNumbers() async {
    if (_assigningNumbers || authKind != AuthKind.cashier) return;
    final ids = orders
        .where(
          (order) =>
              order.status != OrderStatus.paid &&
              order.shiftOrderNumber == null,
        )
        .map((order) => order.id)
        .toList();
    if (ids.isEmpty) return;
    _assigningNumbers = true;
    try {
      for (final id in ids) {
        final error = await db.assignShiftOrderNumber(id);
        if (_sessionExpired(error)) return;
      }
      await db.refreshFromDisk(liveOnly: true);
      _hydrateOperational();
      _syncStampCache = null;
      notifyListeners();
    } finally {
      _assigningNumbers = false;
    }
  }

  String _stampFromDb() => _fingerprint(
    cafe: db.cafe,
    locale: db.locale,
    orders: db.orders,
    tables: db.tables,
    carts: db.carts,
    menu: db.menuItems,
    categories: db.categories,
    calls: db.calls,
    payments: db.payments,
    paymentTypes: db.paymentTypes,
    expenseCategories: db.expenseCategories,
    shifts: db.shifts,
    expenses: db.expenses,
  );

  String _fingerprint({
    required Map<String, dynamic> cafe,
    required String locale,
    required List<CafeOrder> orders,
    required List<CafeTable> tables,
    required Map<String, CartState> carts,
    required List<MenuItem> menu,
    required List<MenuCategory> categories,
    required List<StaffCall> calls,
    required List<Payment> payments,
    required List<PaymentType> paymentTypes,
    required List<ExpenseCategory> expenseCategories,
    required List<CashShift> shifts,
    required List<ShiftExpense> expenses,
  }) {
    final buffer = StringBuffer(_cafeStamp(cafe, locale));
    for (final item in menu) {
      buffer.write(item.syncKey);
    }
    for (final category in categories) {
      buffer
        ..write(category.id)
        ..write(category.visible)
        ..write(category.sortOrder)
        ..write(category.nameEn)
        ..write(category.nameAr);
    }
    for (final table in tables) {
      buffer
        ..write(table.id)
        ..write(table.status.name)
        ..write(table.guests)
        ..write(table.number)
        ..write(table.archived);
    }
    for (final order in orders) {
      buffer
        ..write(order.id)
        ..write(order.status.name)
        ..write(order.tableId)
        ..write(order.awaitingCustomerConfirmation)
        ..write(order.refusalNotice)
        ..write(order.paymentTypeId)
        ..write(order.serviceType);
      for (final line in order.lines) {
        buffer
          ..write(line.menuItemId)
          ..write(line.qty)
          ..write(line.unitPrice)
          ..write(line.listUnitPrice)
          ..write(line.round);
      }
    }
    for (final cart in carts.values) {
      buffer.write(cart.tableId);
      for (final line in cart.lines) {
        buffer
          ..write(line.menuItemId)
          ..write(line.qty)
          ..write(line.unitPrice)
          ..write(line.listUnitPrice);
      }
    }
    for (final call in calls) {
      buffer
        ..write(call.id)
        ..write(call.resolved)
        ..write(call.kind);
    }
    for (final payment in payments) {
      buffer
        ..write(payment.id)
        ..write(payment.totalDue)
        ..write(payment.paymentTypeId)
        ..write(payment.changes.length);
    }
    for (final type in paymentTypes) {
      buffer
        ..write(type.id)
        ..write(type.enabled)
        ..write(type.archived)
        ..write(type.nameEn)
        ..write(type.nameAr);
    }
    for (final category in expenseCategories) {
      buffer
        ..write(category.id)
        ..write(category.enabled)
        ..write(category.nameEn)
        ..write(category.nameAr);
    }
    for (final shift in shifts) {
      buffer
        ..write(shift.id)
        ..write(shift.isOpen)
        ..write(shift.cashSales)
        ..write(shift.closedAt);
    }
    for (final expense in expenses) {
      buffer
        ..write(expense.id)
        ..write(expense.shiftId)
        ..write(expense.amount)
        ..write(expense.description)
        ..write(expense.paidToCafe)
        ..write(expense.paidToCashierId)
        ..write(expense.voided)
        ..write(expense.editedFrom)
        ..write(expense.displayNumber)
        ..write(expense.categoryId)
        ..write(expense.categoryNameEn)
        ..write(expense.categoryNameAr);
    }
    return buffer.toString();
  }

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
    paymentTypes = db.paymentTypes;
    expenseCategories = db.expenseCategories;
    shifts = db.shifts;
    expenses = db.expenses;
    calls = db.calls;
    if (currentShift != null) {
      final match = shifts.where((shift) => shift.id == currentShift!.id);
      currentShift = match.isEmpty ? currentShift : match.first;
    }
  }

  bool get hasAdmin => admin != null || db.anyAdmin;

  /// The cafe slot (1-8) this install is linked to, or null if unlinked.
  int? get deviceSlot => db.boundSlot;

  /// Links this install to cafe [slot] and reloads that cafe's data.
  Future<String?> linkDeviceToSlot(int slot) async {
    if (authKind != AuthKind.none) signOut();
    final error = await db.bindSlot(slot);
    if (error == null) _afterRelink();
    return error;
  }

  /// Links this browser to the cafe at `/c/slug`. Returns whether it worked.
  Future<bool> linkDeviceToSlug(String slug) async {
    if (authKind != AuthKind.none) signOut();
    final ok = await db.bindSlug(slug);
    if (ok) _afterRelink();
    return ok;
  }

  void _afterRelink() {
    _hydrateOperational();
    _syncStampCache = null;
    notifyListeners();
  }

  String get guestLocale => guestLocaleOverride ?? locale;

  AppLocalizations get l10n => lookupAppLocalizations(Locale(locale));

  AppLocalizations get guestL10n => lookupAppLocalizations(Locale(guestLocale));

  /// The guest's language is asked on every scan (each fresh page load) and kept
  /// only for that visit; a choice saved on the phone used to skip the question.
  Future<void> _loadGuestLocale() async {}

  Future<void> setGuestLocale(String value) async {
    if (value != 'en' && value != 'ar') return;
    guestLocaleOverride = value;
    notifyListeners();
  }

  /// Whether this install is linked to one of the cafe slots.
  bool get deviceLinked => db.boundSlot != null;

  Future<String?> createAdmin({
    required String email,
    required String password,
    required String confirm,
    String setupCode = '',
  }) async {
    if (admin != null) return l10n.errAdminExists;
    if (db.boundSlot == null) return l10n.authDeviceNotLinked;
    final trimmed = email.trim().toLowerCase();
    if (!_validEmail(trimmed)) return l10n.errInvalidEmail;
    if (password != confirm) return l10n.errPasswordsMismatch;
    if (!Secrets.validPassword(password)) return l10n.errWeakPassword;
    if (db.client == null) {
      return 'Add SUPABASE_URL and SUPABASE_ANON_KEY before creating an admin.';
    }
    final AuthResponse response;
    try {
      response = await db.client!.auth.signUp(
        email: trimmed,
        password: password,
        data: {'slot': db.boundSlot, 'setup_code': setupCode.trim().toUpperCase()},
      );
    } on AuthException catch (error, stackTrace) {
      reportError('create admin', error, stackTrace);
      // Supabase hides the database's own message behind a generic one when
      // the slot/code check rejects the signup.
      if (error.message.contains('Database error')) return l10n.authSetupCodeInvalid;
      return error.message;
    } catch (error, stackTrace) {
      reportError('create admin', error, stackTrace);
      return 'Could not reach Supabase: $error';
    }
    if (response.session == null) {
      await db.refreshFromDisk();
      _afterRelink();
      return 'Confirm the account from the email Supabase sent, then sign in. In Supabase Auth, turn off Confirm email if you want to enter immediately.';
    }
    await db.refreshFromDisk();
    _hydrateOperational();
    _syncStampCache = null;
    admin = db.admin;
    authKind = AuthKind.admin;
    startLiveSync();
    notifyListeners();
    return null;
  }

  Future<String?> signInAdmin(
    String email,
    String password, {
    bool remember = false,
  }) async {
    if (db.client == null) {
      return 'Add SUPABASE_URL and SUPABASE_ANON_KEY before signing in.';
    }
    try {
      await db.client!.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (error, stackTrace) {
      reportError('admin sign in', error, stackTrace);
      adminError = error.statusCode == '400'
          ? l10n.errBadCredentials
          : error.message;
      notifyListeners();
      return adminError;
    } catch (error, stackTrace) {
      reportError('admin sign in', error, stackTrace);
      adminError = 'Could not reach Supabase: $error';
      notifyListeners();
      return adminError;
    }
    await db.refreshFromDisk();
    if (db.adminFromOtherCafe) {
      // Supabase accepted the password, but this admin belongs to another
      // cafe slot. Drop the session so this device's cafe stays locked.
      await _dropForeignAdmin();
      adminError = l10n.errNoAdminForCafe;
      notifyListeners();
      return adminError;
    }
    // Copy the signed-in data (sales, expenses, orders...) to the screens, not
    // just the admin's name; otherwise the dashboard keeps the empty pre-login
    // data until the next live update.
    _hydrateOperational();
    _syncStampCache = null;
    admin = db.admin;
    if (admin == null) {
      adminError = l10n.errNoAdmin;
      notifyListeners();
      return adminError;
    }
    authKind = AuthKind.admin;
    adminError = null;
    await db.writeRememberAdmin(remember);
    startLiveSync();
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
      await db.client!.auth.verifyOTP(
        email: otpEmail,
        token: code,
        type: OtpType.recovery,
      );
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
    currentCashier =
        cashiers.where((item) => item.id == selectedCashierId).firstOrNull ??
        cashiers.firstOrNull;
    authKind = AuthKind.cashier;
    pinBuffer = '';
    loginError = null;
    try {
      await _ensureShift();
    } catch (error, stackTrace) {
      reportError('cashier shift', error, stackTrace);
      loginError = '$error';
      notifyListeners();
      return false;
    }
    await ensureShiftNumbers();
    if (authKind != AuthKind.cashier) return false;
    startLiveSync();
    notifyListeners();
    return true;
  }

  Future<void> _ensureShift() async {
    final cashier = currentCashier;
    if (cashier == null) return;
    if (db.client != null) {
      // The server finds or opens this cashier's shift, so a device never
      // writes shift totals of its own.
      final opened = await db.openShift();
      final shiftId = opened.shiftId;
      if (opened.error != null || shiftId == null) {
        throw StateError(opened.error ?? 'The shift was not opened.');
      }
      await db.refreshFromDisk(liveOnly: true);
      _hydrateOperational();
      currentShift = shifts.where((shift) => shift.id == shiftId).firstOrNull ??
          CashShift(id: shiftId, cashierId: cashier.id, openedAt: DateTime.now(), openingCash: 0);
      return;
    }
    final existing = shifts.where(
      (shift) => shift.isOpen && shift.cashierId == cashier.id,
    );
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
    if (db.guestSlug == slug && tables.any((table) => !table.archived && table.qrSlug == slug)) {
      return;
    }
    await db.setGuestSlug(slug);
    _hydrateOperational();
    startLiveSync();
    notifyListeners();
  }

  Future<void> _dropForeignAdmin() async {
    try {
      await db.client?.auth.signOut();
    } catch (error, stackTrace) {
      reportError('sign out foreign admin', error, stackTrace);
    }
    await db.refreshFromDisk();
    _hydrateOperational();
    admin = null;
    authKind = AuthKind.none;
  }

  void signOut() {
    final token = db.cashierToken;
    if (token != null) unawaited(db.cashierLogout(token));
    authKind = AuthKind.none;
    currentCashier = null;
    currentShift = null;
    pinBuffer = '';
    db.cashierToken = null;
    stopLiveSync();
    db.client?.auth.signOut();
    notifyListeners();
  }

  bool _sessionExpired(String? error) {
    if (error != 'session expired, sign in again') return false;
    loginError = error;
    signOut();
    return true;
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
    final id = await db.createCashier(
      name: name.trim(),
      pin: pin,
      initials: initials.isEmpty ? 'C' : initials,
    );
    if (id == null) return;
    await syncFromDisk();
    notifyListeners();
  }

  /// Removes a cashier from the sign-in screen. The row stays (deactivated)
  /// because their past payments and shifts point at it.
  Future<String?> deleteCashier(String id) async {
    final error = await db.deactivateCashier(id);
    if (error != null) return error;
    cashiers.removeWhere((item) => item.id == id);
    notifyListeners();
    return null;
  }

  /// Changes the signed-in admin's password after checking the current one.
  Future<String?> changeAdminPassword({required String current, required String next}) async {
    final client = db.client;
    final email = client?.auth.currentUser?.email ?? admin?.email ?? '';
    if (client == null || email.isEmpty) return l10n.errNoAdmin;
    if (!Secrets.validPassword(next)) return l10n.errWeakPassword;
    try {
      await client.auth.signInWithPassword(email: email, password: current);
    } on AuthException catch (error, stackTrace) {
      reportError('change password check', error, stackTrace);
      return l10n.catalogCurrentPasswordWrong;
    } catch (error, stackTrace) {
      reportError('change password check', error, stackTrace);
      return 'Could not reach Supabase: $error';
    }
    try {
      await client.auth.updateUser(UserAttributes(password: next));
    } on AuthException catch (error, stackTrace) {
      reportError('change password', error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      reportError('change password', error, stackTrace);
      return 'Could not reach Supabase: $error';
    }
    return null;
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
}
