import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_database.dart';
import '../device_location.dart';
import '../models/models.dart';
import '../money.dart';
import '../report_error.dart';
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
  List<PaymentType> paymentTypes = [];
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
  GuestLocationStatus guestLocation = GuestLocationStatus.off;
  DateTime? _guestNearUntil;
  double? _guestLat;
  double? _guestLng;
  double? _guestAccuracyM;
  bool _guestLocationStarted = false;
  bool _guestLocationBusy = false;

  bool get canPlaceOrder => guestLocation == GuestLocationStatus.off || guestLocation == GuestLocationStatus.allowed;

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
    paymentTypes = db.paymentTypes;
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
    db.onLiveChange = () {
      unawaited(syncFromDisk());
    };
    db.startRealtime();
    _liveSync = Timer.periodic(const Duration(seconds: 30), (_) {
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
    _syncStamp = _stamp();
    super.notifyListeners();
  }

  @override
  void dispose() {
    stopLiveSync();
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
        'paymentTypes': paymentTypes.map((item) => '${item.id}${item.nameEn}${item.nameAr}${item.enabled}${item.archived}').toList(),
        'shifts': shifts.map((item) => item.toJson()).toList(),
      });

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
      _syncStamp = next;
      notifyListeners();
    }
    await ensureShiftNumbers();
  }

  bool _assigningNumbers = false;

  Future<void> ensureShiftNumbers() async {
    if (_assigningNumbers || authKind != AuthKind.cashier) return;
    final ids = orders.where((order) => order.status != OrderStatus.paid && order.shiftOrderNumber == null).map((order) => order.id).toList();
    if (ids.isEmpty) return;
    _assigningNumbers = true;
    try {
      for (final id in ids) {
        final error = await db.assignShiftOrderNumber(id);
        if (_sessionExpired(error)) return;
      }
      await db.refreshFromDisk(liveOnly: true);
      _hydrateOperational();
      _syncStamp = _stamp();
      notifyListeners();
    } finally {
      _assigningNumbers = false;
    }
  }

  String _stampFromDb() => jsonEncode({
        'orders': db.orders.map((item) => item.toJson()).toList(),
        'tables': db.tables.map((item) => item.toJson()).toList(),
        'carts': db.carts.map((key, value) => MapEntry(key, value.toJson())),
        'menu': db.menuItems.map((item) => item.toJson()).toList(),
        'categories': db.categories.map((item) => item.toJson()).toList(),
        'calls': db.calls.map((item) => item.toJson()).toList(),
        'payments': db.payments.map((item) => item.toJson()).toList(),
        'paymentTypes': db.paymentTypes.map((item) => '${item.id}${item.nameEn}${item.nameAr}${item.enabled}${item.archived}').toList(),
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
    paymentTypes = db.paymentTypes;
    shifts = db.shifts;
    calls = db.calls;
    if (currentShift != null) {
      final match = shifts.where((shift) => shift.id == currentShift!.id);
      currentShift = match.isEmpty ? currentShift : match.first;
    }
  }

  bool get hasAdmin => admin != null || db.anyAdmin;

  AppLocalizations get l10n => lookupAppLocalizations(Locale(locale));

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
    } on AuthException catch (error, stackTrace) {
      reportError('create admin', error, stackTrace);
      return error.message;
    } catch (error, stackTrace) {
      reportError('create admin', error, stackTrace);
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
    startLiveSync();
    notifyListeners();
    return null;
  }

  Future<String?> signInAdmin(String email, String password, {bool remember = false}) async {
    if (db.client == null) return 'Add SUPABASE_URL and SUPABASE_ANON_KEY before signing in.';
    try {
      await db.client!.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
    } on AuthException catch (error, stackTrace) {
      reportError('admin sign in', error, stackTrace);
      adminError = error.statusCode == '400' ? l10n.errBadCredentials : error.message;
      notifyListeners();
      return adminError;
    } catch (error, stackTrace) {
      reportError('admin sign in', error, stackTrace);
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
    startLiveSync();
    notifyListeners();
  }

  void signOut() {
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
  bool _validEmail(String value) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
}
