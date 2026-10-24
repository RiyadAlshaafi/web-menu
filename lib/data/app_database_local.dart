part of 'app_database.dart';

/// Offline mode: the same data the server keeps online, saved in a SQLite file on this PC
/// ([LocalStateStore]). Each method here stands in for one server call, with the same rules
/// (numbering, shift totals, PIN lockout), so the screens work unchanged without any internet.
extension AppDatabaseLocal on AppDatabase {
  LocalStateStore get _store => _localStore!;

  // ------------------------------------------------------------------ load

  void _loadLocal() {
    restaurantId = _localCafeId;
    final cafe = _store.readDoc('cafe');
    if (cafe is Map) _cafe = {..._cafe, ...Map<String, dynamic>.from(cafe)};
    _locale = _store.readDoc('locale') as String? ?? 'en';
    final admin = _localAdminDoc();
    anyAdmin = admin != null;
    _rememberAdmin = admin?['remember'] as bool? ?? false;
    _admin = admin != null && _rememberAdmin ? _localAdminAccount(admin) : null;
    _cashiers = [
      for (final row in _docRows('cashiers'))
        if (row['active'] as bool? ?? true) Cashier.fromJson(row),
    ];
    _tables = [for (final row in _docRows('tables')) CafeTable.fromJson(row)];
    _categories = [for (final row in _docRows('categories')) MenuCategory.fromJson(row)];
    _kitchens = [for (final row in _docRows('kitchens')) Kitchen.fromJson(row)];
    _menuItems = [for (final row in _docRows('menuItems')) MenuItem.fromJson(row)];
    _paymentTypes = [for (final row in _docRows('paymentTypes')) _paymentTypeFromLocal(row)];
    _expenseCategories = [for (final row in _docRows('expenseCategories')) _expenseCategoryFromLocal(row)];
    if (_paymentTypes.isEmpty && _expenseCategories.isEmpty) _seedLocal();
    _orders = [for (final row in _store.readRecords('orders')) CafeOrder.fromJson(row)];
    _payments = [for (final row in _store.readRecords('payments')) _paymentFromLocal(row)]
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    _shifts = [for (final row in _store.readRecords('shifts')) CashShift.fromJson(row)]
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    _expenses = [for (final row in _store.readRecords('expenses')) _expenseFromLocal(row)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _carts = {
      for (final row in _docRows('carts')) row['tableId'] as String: CartState.fromJson(row),
    };
    _calls = [];
    salesHasMore = false;
    loadedOnce = true;
  }

  /// First start: the same payment methods and expense types a new online cafe gets.
  void _seedLocal() {
    _paymentTypes = [
      PaymentType(id: Secrets.id(), nameEn: 'Cash', nameAr: 'نقداً', enabled: true, sortOrder: 0),
      PaymentType(id: Secrets.id(), nameEn: 'Card', nameAr: 'بطاقة', enabled: true, sortOrder: 1),
      PaymentType(id: Secrets.id(), nameEn: 'Bank Transfer', nameAr: 'تحويل مصرفي', enabled: true, sortOrder: 2),
      PaymentType(id: Secrets.id(), nameEn: 'Mobile Wallet', nameAr: 'محفظة', enabled: true, sortOrder: 3),
    ];
    _expenseCategories = [
      ExpenseCategory(id: Secrets.id(), nameEn: 'Café Expense', nameAr: 'مصروف المقهى', enabled: true, sortOrder: 0),
      ExpenseCategory(id: Secrets.id(), nameEn: 'Cash Withdrawal', nameAr: 'سحب نقدي', enabled: true, sortOrder: 1),
    ];
    _saveLocalCatalog();
  }

  List<Map<String, dynamic>> _docRows(String key) => [
    for (final row in (_store.readDoc(key) as List? ?? const [])) Map<String, dynamic>.from(row as Map),
  ];

  /// Closes this PC's local database and leaves offline mode (Windows keeps open files locked).
  void closeLocal() {
    _localStore?.close();
    _localStore = null;
    localCashierId = null;
  }

  // ------------------------------------------------------------------ save

  /// Saves the small collections (menu, settings, cashiers, payment and expense types) whole.
  void _saveLocalCatalog() {
    _store.transaction(() {
      _store.writeDoc('cafe', _cafe);
      _store.writeDoc('locale', _locale);
      _store.writeDoc('tables', [for (final t in _tables) {...t.toJson(), 'archived': t.archived}]);
      _store.writeDoc('categories', [for (final c in _categories) c.toJson()]);
      _store.writeDoc('kitchens', [for (final k in _kitchens) k.toJson()]);
      _store.writeDoc('menuItems', [for (final m in _menuItems) m.toJson()]);
      _store.writeDoc('paymentTypes', [for (final p in _paymentTypes) _paymentTypeToLocal(p)]);
      _store.writeDoc('expenseCategories', [for (final e in _expenseCategories) _expenseCategoryToLocal(e)]);
      _saveLocalCashierRows();
    });
  }

  /// Cashier rows keep removed cashiers (inactive) so old receipts still name them.
  void _saveLocalCashierRows() {
    final saved = {for (final row in _docRows('cashiers')) row['id'] as String: row};
    for (final cashier in _cashiers) {
      saved[cashier.id] = {...?saved[cashier.id], ...cashier.toJson()};
    }
    _store.writeDoc('cashiers', saved.values.toList());
  }

  // ------------------------------------------------------------------ admin

  Map<String, dynamic>? _localAdminDoc() {
    final doc = _store.readDoc('admin');
    return doc is Map ? Map<String, dynamic>.from(doc) : null;
  }

  AdminAccount _localAdminAccount(Map<String, dynamic> doc) =>
      AdminAccount(email: doc['email'] as String, displayName: doc['displayName'] as String? ?? 'Admin');

  /// Creates the one admin of this PC. Returns an error code, or null.
  String? createLocalAdmin({required String email, required String password}) {
    if (_localAdminDoc() != null) return 'admin_exists';
    final salt = Secrets.publicId(16);
    _store.writeDoc('admin', {
      'email': email,
      'displayName': 'Admin',
      'salt': salt,
      'hash': _localHash(password, salt),
      'remember': false,
    });
    anyAdmin = true;
    _admin = AdminAccount(email: email);
    return null;
  }

  /// Whether [email] and [password] match this PC's admin; signs them in when they do.
  bool signInLocalAdmin({required String email, required String password, required bool remember}) {
    final doc = _localAdminDoc();
    if (doc == null || (doc['email'] as String).toLowerCase() != email.trim().toLowerCase()) return false;
    if (_localHash(password, doc['salt'] as String) != doc['hash']) return false;
    _store.writeDoc('admin', {...doc, 'remember': remember});
    _rememberAdmin = remember;
    _admin = _localAdminAccount(doc);
    return true;
  }

  /// Changes the admin password after checking [current]. Returns false when [current] is wrong.
  bool changeLocalAdminPassword({required String current, required String next}) {
    final doc = _localAdminDoc();
    if (doc == null || _localHash(current, doc['salt'] as String) != doc['hash']) return false;
    final salt = Secrets.publicId(16);
    _store.writeDoc('admin', {...doc, 'salt': salt, 'hash': _localHash(next, salt)});
    return true;
  }

  /// The admin's email, shown when a forgotten password is reset; null when there is no admin.
  String? get localAdminEmail => _localAdminDoc()?['email'] as String?;

  /// Ids of setup reset tickets already used on this PC, so a copied ticket cannot be used twice.
  Set<String> get usedLocalAdminResets => {
    for (final nonce in (_store.readDoc('adminResets') as List? ?? const [])) nonce as String,
  };

  /// Forgotten password: sets [next] from a setup reset ticket ([nonce]) without the old one.
  /// Only the admin's password changes; sales, menu and settings stay. Returns false when there
  /// is no admin or the ticket was already used.
  bool resetLocalAdminPassword({required String nonce, required String next}) {
    final doc = _localAdminDoc();
    final used = usedLocalAdminResets;
    if (doc == null || used.contains(nonce)) return false;
    final salt = Secrets.publicId(16);
    _store.transaction(() {
      _store.writeDoc('admin', {
        ...doc,
        'salt': salt,
        'hash': _localHash(next, salt),
        'remember': false,
        'resetAt': DateTime.now().toUtc().toIso8601String(),
      });
      _store.writeDoc('adminResets', [...used, nonce]);
    });
    _rememberAdmin = false;
    return true;
  }

  void signOutLocalAdmin() {
    final doc = _localAdminDoc();
    if (doc != null) _store.writeDoc('admin', {...doc, 'remember': false});
    _rememberAdmin = false;
    _admin = null;
  }

  // ------------------------------------------------------------------ cashiers

  String _localCreateCashier(String name, String pin, String initials, String role) {
    final cashier = Cashier(id: Secrets.id(), name: name, initials: initials, role: role);
    final salt = Secrets.publicId(16);
    _cashiers = [..._cashiers, cashier];
    _store.transaction(() {
      _saveLocalCashierRows();
      if (!cashier.canSignIn) return;
      final pins = _localPins();
      pins[cashier.id] = {'salt': salt, 'hash': _localHash(pin, salt), 'failed': 0};
      _store.writeDoc('cashierPins', pins);
    });
    return cashier.id;
  }

  Map<String, dynamic> _localPins() {
    final doc = _store.readDoc('cashierPins');
    return doc is Map ? Map<String, dynamic>.from(doc) : <String, dynamic>{};
  }

  /// Same answer shape and lockout as the server's cashier_login: 5 wrong PINs lock 15 minutes.
  Map<String, dynamic> _localLoginCashier(String cashierId, String pin) {
    final pins = _localPins();
    final saved = pins[cashierId];
    if (saved is! Map || !_cashiers.any((c) => c.id == cashierId)) return {'ok': false};
    final entry = Map<String, dynamic>.from(saved);
    final lockedUntil = DateTime.tryParse(entry['lockedUntil'] as String? ?? '');
    final now = DateTime.now().toUtc();
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      return {'ok': false, 'code': 'locked', 'retry_after_seconds': lockedUntil.difference(now).inSeconds};
    }
    if (_localHash(pin, entry['salt'] as String) != entry['hash']) {
      final failed = (entry['failed'] as int? ?? 0) + 1;
      pins[cashierId] = {
        ...entry,
        'failed': failed >= _maxPinTries ? 0 : failed,
        'lockedUntil': failed >= _maxPinTries ? now.add(_pinLock).toIso8601String() : null,
      };
      _store.writeDoc('cashierPins', pins);
      return {'ok': false};
    }
    pins[cashierId] = {...entry, 'failed': 0, 'lockedUntil': null};
    _store.writeDoc('cashierPins', pins);
    localCashierId = cashierId;
    restaurantId = _localCafeId;
    return {'ok': true, 'restaurant_id': _localCafeId};
  }

  String? _localDeactivateCashier(String id) {
    final rows = _docRows('cashiers');
    _cashiers = _cashiers.where((item) => item.id != id).toList();
    _store.writeDoc('cashiers', [
      for (final row in rows) row['id'] == id ? {...row, 'active': false} : row,
    ]);
    return null;
  }

  // ------------------------------------------------------------------ payment & expense types

  String? _localAddPaymentType(String nameEn, String nameAr) {
    final sort = _paymentTypes.fold<int>(0, (max, t) => t.sortOrder > max ? t.sortOrder : max) + 1;
    _paymentTypes = [
      ..._paymentTypes,
      PaymentType(id: Secrets.id(), nameEn: nameEn, nameAr: nameAr, enabled: true, sortOrder: sort),
    ];
    _saveLocalCatalog();
    return null;
  }

  String? _localSavePaymentType(PaymentType type) {
    _paymentTypes = [for (final t in _paymentTypes) t.id == type.id ? type : t];
    _saveLocalCatalog();
    return null;
  }

  /// A method already used on a receipt is archived instead, like the server's history rule.
  String? _localDeletePaymentType(String id) {
    final used = _payments.any((p) => p.paymentTypeId == id);
    _paymentTypes = used
        ? [
            for (final t in _paymentTypes)
              if (t.id == id) (t..archived = true) else t,
          ]
        : _paymentTypes.where((t) => t.id != id).toList();
    _saveLocalCatalog();
    return null;
  }

  String? _localAddExpenseCategory(String nameEn, String nameAr) {
    final sort = _expenseCategories.fold<int>(0, (max, t) => t.sortOrder > max ? t.sortOrder : max) + 1;
    _expenseCategories = [
      ..._expenseCategories,
      ExpenseCategory(id: Secrets.id(), nameEn: nameEn, nameAr: nameAr, enabled: true, sortOrder: sort),
    ];
    _saveLocalCatalog();
    return null;
  }

  String? _localSaveExpenseCategory(ExpenseCategory category) {
    _expenseCategories = [for (final c in _expenseCategories) c.id == category.id ? category : c];
    _saveLocalCatalog();
    return null;
  }

  /// A type already used by an expense is switched off instead of deleted.
  String? _localDeleteExpenseCategory(String id) {
    final used = _expenses.any((e) => e.categoryId == id);
    _expenseCategories = used
        ? [
            for (final c in _expenseCategories)
              if (c.id == id) (c..enabled = false) else c,
          ]
        : _expenseCategories.where((c) => c.id != id).toList();
    _saveLocalCatalog();
    return null;
  }

  // ------------------------------------------------------------------ sales

  /// The cashier's open shift, opened at sign-in by the store.
  CashShift? get _localOpenShift {
    final cashierId = localCashierId;
    if (cashierId == null) return null;
    return _shifts.where((s) => s.isOpen && s.cashierId == cashierId).firstOrNull;
  }

  /// A paid takeout sale, numbered like the server does (monthly receipt number, shared daily
  /// order number, both in Tripoli time) and added to the shift's totals.
  String? _localQuickTakeout(List<OrderLine> lines, String? paymentTypeId) {
    final cashierId = localCashierId;
    final shift = _localOpenShift;
    if (cashierId == null || shift == null) return 'sign in as a cashier first';
    final orders = <CafeOrder>[];
    final payments = <Payment>[];
    final id = Secrets.id();
    final paidAt = DateTime.now().toUtc();
    final error = applyQuickTakeout(
      orders: orders,
      payments: payments,
      lines: lines,
      paymentTypeId: paymentTypeId,
      cashierId: cashierId,
      shiftId: shift.id,
      orderId: id,
      paymentId: id,
      paidAt: paidAt,
    );
    if (error != null) return error;
    final yymm = _tripoliKey(paidAt, withDay: false);
    final dayKey = _tripoliKey(paidAt, withDay: true);
    final type = _paymentTypes.where((t) => t.id == paymentTypeId).firstOrNull;
    final cashier = _cashiers.where((c) => c.id == cashierId).firstOrNull;
    final base = payments.single;
    _store.transaction(() {
      final day = _nextLocalNumber('day:$dayKey');
      final month = _nextLocalNumber('month:$yymm');
      final order = orders.single
        ..yearMonth = yymm
        ..shiftOrderNumber = day;
      final payment = Payment(
        id: base.id,
        orderId: base.orderId,
        tableId: '',
        isTakeout: true,
        cashierName: cashier?.name ?? '',
        paymentTypeNameEn: type?.nameEn,
        paymentTypeNameAr: type?.nameAr,
        totalDue: base.totalDue,
        cashReceived: base.totalDue,
        changeDue: 0,
        cashierId: cashierId,
        shiftId: shift.id,
        paidAt: paidAt,
        paymentTypeId: paymentTypeId,
        yearMonth: yymm,
        shiftOrderNumber: day,
        monthlyOrderNumber: month,
        shiftDisplayNumber: formatSaleNumber(yymm, day),
        monthlyDisplayNumber: formatSaleNumber(yymm, month),
      );
      shift
        ..cashSales += payment.totalDue
        ..transactionCount += 1;
      _store.putRecords('orders', [order.toJson()]);
      _store.putRecords('payments', [_paymentToLocal(payment)]);
      _store.putRecords('shifts', [shift.toJson()]);
      _orders = [..._orders, order];
      _payments = [payment, ..._payments];
      _localTakeStock(lines);
    });
    return null;
  }

  /// Lowers the stock of each dish in [lines], like the server's take_dish_stock trigger:
  /// never below 0, and at 0 the dish is sold out.
  void _localTakeStock(List<OrderLine> lines) {
    var changed = false;
    for (final line in lines) {
      if (line.qty <= 0) continue;
      for (final item in _menuItems.where((item) => item.id == line.menuItemId && item.stockQty != null)) {
        final left = item.stockQty! - line.qty;
        item.stockQty = left < 0 ? 0 : left;
        if (item.stockQty == 0) item.soldOut = true;
        changed = true;
      }
    }
    if (changed) _store.writeDoc('menuItems', [for (final m in _menuItems) m.toJson()]);
  }

  String? _localSetDishStock(String id, int? qty) {
    final item = _menuItems.where((item) => item.id == id).firstOrNull;
    if (item == null) return 'not_found';
    item.stockQty = qty;
    if (qty != null) item.soldOut = qty == 0;
    _saveLocalCatalog();
    return null;
  }

  /// Next value of a numbering counter (monthly receipts, daily orders, expenses).
  int _nextLocalNumber(String scope) {
    final counters = Map<String, dynamic>.from(_store.readDoc('counters') as Map? ?? const {});
    final next = (counters[scope] as int? ?? 0) + 1;
    counters[scope] = next;
    _store.writeDoc('counters', counters);
    return next;
  }

  /// `YYMM` (or `YYMMDD`) of [instant] in Tripoli time, as the server numbers sales.
  String _tripoliKey(DateTime instant, {required bool withDay}) {
    final t = toTripoli(instant);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.year % 100)}${two(t.month)}${withDay ? two(t.day) : ''}';
  }

  String? _localChangePaymentType(String paymentId, String typeId) {
    final payment = _payments.where((p) => p.id == paymentId).firstOrNull;
    if (payment == null) return 'not_found';
    final type = _paymentTypes.where((t) => t.id == typeId).firstOrNull;
    final changed = Payment(
      id: payment.id,
      orderId: payment.orderId,
      tableId: payment.tableId,
      tableNumber: payment.tableNumber,
      isTakeout: payment.isTakeout,
      cashierName: payment.cashierName,
      paymentTypeNameEn: type?.nameEn,
      paymentTypeNameAr: type?.nameAr,
      totalDue: payment.totalDue,
      cashReceived: payment.cashReceived,
      changeDue: payment.changeDue,
      cashierId: payment.cashierId,
      shiftId: payment.shiftId,
      paidAt: payment.paidAt,
      paymentTypeId: typeId,
      yearMonth: payment.yearMonth,
      shiftOrderNumber: payment.shiftOrderNumber,
      monthlyOrderNumber: payment.monthlyOrderNumber,
      shiftDisplayNumber: payment.shiftDisplayNumber,
      monthlyDisplayNumber: payment.monthlyDisplayNumber,
      voidedAt: payment.voidedAt,
      voidReason: payment.voidReason,
      changes: [
        ...payment.changes,
        PaymentMethodChange(
          id: Secrets.id(),
          paymentId: payment.id,
          oldTypeId: payment.paymentTypeId,
          newTypeId: typeId,
          actorName: _admin?.displayName ?? 'Admin',
          actorRole: 'admin',
          createdAt: DateTime.now().toUtc(),
        ),
      ],
    );
    _payments = [for (final p in _payments) p.id == paymentId ? changed : p];
    _store.putRecords('payments', [_paymentToLocal(changed)]);
    return null;
  }

  /// Like the server: the cashier's own sale on an open shift is marked void and leaves the
  /// shift's sales total. The order stays paid, so its table is not reopened.
  String? _localVoidPayment(String paymentId, String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return 'reason required';
    final payment = _payments.where((p) => p.id == paymentId && p.cashierId == localCashierId).firstOrNull;
    if (payment == null) return 'not_found';
    if (payment.isVoided) return 'already voided';
    final shift = _shifts.where((s) => s.id == payment.shiftId && s.isOpen).firstOrNull;
    if (shift == null) return 'shift closed';
    _store.transaction(() {
      payment
        ..voidedAt = DateTime.now().toUtc()
        ..voidReason = trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
      shift
        ..cashSales = max(0.0, _round2(shift.cashSales - payment.totalDue))
        ..transactionCount = max(0, shift.transactionCount - 1);
      _store.putRecords('payments', [_paymentToLocal(payment)]);
      _store.putRecords('shifts', [shift.toJson()]);
    });
    return null;
  }

  // ------------------------------------------------------------------ tables (open tabs)

  /// The table's unpaid order, newest first, like the server picks it.
  CafeOrder? _localOpenOrder(String tableId) {
    final open = _orders.where((o) => o.tableId == tableId && o.status != OrderStatus.paid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return open.firstOrNull;
  }

  void _saveLocalCarts() {
    _store.writeDoc('carts', [
      for (final cart in _carts.values)
        if (cart.lines.isNotEmpty) cart.toJson(),
    ]);
  }

  void _saveLocalTables() =>
      _store.writeDoc('tables', [for (final t in _tables) {...t.toJson(), 'archived': t.archived}]);

  /// The cashier sends the table's cart: its dishes join the open tab as a new round (or open
  /// one, with the shared daily order number). Cashier-entered dishes need no kitchen step, so
  /// the tab is ready to settle at once.
  String? _localSendTableCart(String tableId) {
    final table = _tables.where((t) => t.id == tableId && !t.archived).firstOrNull;
    if (table == null) return 'not_found';
    final lines = [
      for (final line in _carts[tableId]?.lines ?? const <OrderLine>[])
        if (line.menuItemId.isNotEmpty && line.qty > 0) line,
    ];
    if (lines.isEmpty) return ErrorCodes.cartEmpty;
    final unavailable = [
      for (final line in lines)
        if (!_menuItems.any((m) => m.id == line.menuItemId && m.available && !m.soldOut)) line.name,
    ];
    if (unavailable.isNotEmpty) return '${AppDatabase.unavailableItemsError}${unavailable.join(', ')}';
    final now = DateTime.now().toUtc();
    _store.transaction(() {
      var order = _localOpenOrder(tableId);
      if (order == null) {
        order = CafeOrder(
          id: Secrets.id(),
          tableId: tableId,
          tableNumber: table.number,
          status: OrderStatus.served,
          createdAt: now,
          lines: [],
          cashierId: localCashierId,
          yearMonth: _tripoliKey(now, withDay: false),
          shiftOrderNumber: _nextLocalNumber('day:${_tripoliKey(now, withDay: true)}'),
        );
        _orders = [..._orders, order];
      }
      final round = order.lines.isEmpty ? 1 : order.latestRound + 1;
      order
        ..status = OrderStatus.served
        ..lines.addAll([
          for (final line in lines)
            OrderLine(
              id: Secrets.id(),
              menuItemId: line.menuItemId,
              name: line.name,
              qty: line.qty,
              unitPrice: line.unitPrice,
              listUnitPrice: line.listUnitPrice,
              round: round,
              choices: line.choices,
            ),
        ]);
      table.status = TableStatus.dining;
      _carts = {..._carts}..remove(tableId);
      _store.putRecords('orders', [order.toJson()]);
      _saveLocalTables();
      _saveLocalCarts();
      _localTakeStock(lines);
    });
    return null;
  }

  /// Settles the table's tab like the server's settle_cash: dishes plus the cafe's service rate
  /// (when applied), rounded to 2 places; numbered with the monthly receipt counter and the tab's
  /// daily number; the table is freed and the shift's totals grow.
  String? _localSettleCash(String tableId, double cashReceived, {required bool applyService, String? paymentTypeId}) {
    final cashierId = localCashierId;
    final shift = _localOpenShift;
    if (cashierId == null || shift == null) return 'sign in as a cashier first';
    final order = _localOpenOrder(tableId);
    if (order == null) return 'no open bill';
    if (order.status != OrderStatus.served) return 'order is not served';
    final rate = (_cafe['serviceChargeRate'] as num?)?.toDouble() ?? 0;
    final subtotal = order.lines.fold<double>(0, (sum, line) => sum + line.total);
    final due = _round2(applyService ? subtotal * (1 + rate) : subtotal);
    if (cashReceived < due) return 'insufficient cash';
    final wanted = paymentTypeId ?? order.paymentTypeId;
    final type = _paymentTypes.where((t) => t.id == wanted).firstOrNull;
    final table = _tables.where((t) => t.id == tableId).firstOrNull;
    final cashier = _cashiers.where((c) => c.id == cashierId).firstOrNull;
    final paidAt = DateTime.now().toUtc();
    final yymm = _tripoliKey(paidAt, withDay: false);
    _store.transaction(() {
      final day = order.shiftOrderNumber ?? _nextLocalNumber('day:${_tripoliKey(paidAt, withDay: true)}');
      final month = _nextLocalNumber('month:$yymm');
      final payment = Payment(
        id: Secrets.id(),
        orderId: order.id,
        tableId: tableId,
        tableNumber: table?.number ?? order.tableNumber,
        cashierName: cashier?.name ?? '',
        paymentTypeNameEn: type?.nameEn,
        paymentTypeNameAr: type?.nameAr,
        totalDue: due,
        cashReceived: cashReceived,
        changeDue: _round2(cashReceived - due),
        cashierId: cashierId,
        shiftId: shift.id,
        paidAt: paidAt,
        paymentTypeId: type?.id,
        yearMonth: yymm,
        shiftOrderNumber: day,
        monthlyOrderNumber: month,
        shiftDisplayNumber: formatSaleNumber(order.yearMonth ?? yymm, day),
        monthlyDisplayNumber: formatSaleNumber(yymm, month),
      );
      order
        ..status = OrderStatus.paid
        ..paymentTypeId = type?.id
        ..shiftOrderNumber = day
        ..cashierId ??= cashierId;
      table
        ?..status = TableStatus.free
        ..guests = 0;
      shift
        ..cashSales += due
        ..transactionCount += 1;
      _store.putRecords('orders', [order.toJson()]);
      _store.putRecords('payments', [_paymentToLocal(payment)]);
      _store.putRecords('shifts', [shift.toJson()]);
      _saveLocalTables();
      _payments = [payment, ..._payments];
    });
    return null;
  }

  /// Takes one sent dish off an unpaid tab (a cashier's correction). A tab left with no dishes
  /// is removed and its table freed.
  String? _localRemoveOrderLine(String lineId) {
    final order = _orders
        .where((o) => o.status != OrderStatus.paid && o.lines.any((line) => line.id == lineId))
        .firstOrNull;
    if (order == null) return ErrorCodes.lineNotFound;
    order.lines.removeWhere((line) => line.id == lineId);
    _store.transaction(() {
      if (order.lines.isEmpty) {
        _orders = _orders.where((o) => o.id != order.id).toList();
        _store.deleteRecord('orders', order.id);
        final table = _tables.where((t) => t.id == order.tableId).firstOrNull;
        if (table != null && _localOpenOrder(table.id) == null) table.status = TableStatus.free;
        _saveLocalTables();
      } else {
        _store.putRecords('orders', [order.toJson()]);
      }
    });
    return null;
  }

  /// Frees a table whatever its state, like the server's cashier_clear_table: unpaid tabs are
  /// cancelled (paid history stays), the cart is emptied and the table's open calls are closed.
  String? _localClearTable(String tableId) {
    final table = _tables.where((t) => t.id == tableId && !t.archived).firstOrNull;
    if (table == null) return 'table not found';
    final unpaid = _orders.where((o) => o.tableId == tableId && o.status != OrderStatus.paid).toList();
    _store.transaction(() {
      _orders = _orders.where((o) => !unpaid.contains(o)).toList();
      for (final order in unpaid) {
        _store.deleteRecord('orders', order.id);
      }
      _carts = {..._carts}..remove(tableId);
      for (final call in _calls.where((c) => c.tableId == tableId)) {
        call.resolved = true;
      }
      table
        ..status = TableStatus.free
        ..guests = 0;
      _saveLocalTables();
      _saveLocalCarts();
    });
    return null;
  }

  /// The payment method picked for a table's tab before it is settled.
  String? _localSetTablePaymentType(String qrSlug, String typeId) {
    final table = _tables.where((t) => t.qrSlug == qrSlug).firstOrNull;
    final order = table == null ? null : _localOpenOrder(table.id);
    if (order == null) return 'no open bill';
    order.paymentTypeId = typeId;
    _store.putRecords('orders', [order.toJson()]);
    return null;
  }

  // ------------------------------------------------------------------ expenses

  String? _localAddExpense({
    required String shiftId,
    required String cashierId,
    required String categoryId,
    required bool paidToCafe,
    required String? paidToCashierId,
    required double amount,
    required String description,
    String? editedFrom,
  }) {
    final shift = _shifts.where((s) => s.id == shiftId && s.isOpen && s.cashierId == cashierId).firstOrNull;
    if (shift == null) return 'not_found';
    if (amount <= 0 || description.trim().isEmpty) return 'invalid';
    final category = _expenseCategories.where((c) => c.id == categoryId).firstOrNull;
    final cashier = _cashiers.where((c) => c.id == cashierId).firstOrNull;
    _store.transaction(() {
      final number = _nextLocalNumber('expense');
      final expense = ShiftExpense(
        id: Secrets.id(),
        shiftId: shiftId,
        cashierId: cashierId,
        cashierName: cashier?.name ?? '',
        paidToCafe: paidToCafe,
        paidToCashierId: paidToCafe ? null : paidToCashierId,
        paidToCashierName: paidToCafe ? '' : (cashier?.name ?? ''),
        amount: amount,
        description: description.trim(),
        createdAt: DateTime.now().toUtc(),
        editedFrom: editedFrom,
        displayNumber: 'E-${number.toString().padLeft(3, '0')}',
        categoryId: categoryId,
        categoryNameEn: category?.nameEn,
        categoryNameAr: category?.nameAr,
      );
      _store.putRecords('expenses', [_expenseToLocal(expense)]);
      _expenses = [expense, ..._expenses];
    });
    return null;
  }

  /// Like the server: the old expense is voided and a corrected copy (new number) replaces it.
  String? _localEditExpense({
    required String id,
    required String categoryId,
    required double amount,
    required String description,
  }) {
    final original = _expenses.where((e) => e.id == id && !e.voided && e.cashierId == localCashierId).firstOrNull;
    if (original == null) return 'not_found';
    if (!_shifts.any((s) => s.id == original.shiftId && s.isOpen)) return 'not_found';
    if (amount <= 0 || description.trim().isEmpty) return 'invalid';
    final withdrawal = _expenseCategories.where((c) => c.id == categoryId).firstOrNull?.nameEn == 'Cash Withdrawal';
    final voided = _copyExpense(original, voided: true);
    String? failure;
    _store.transaction(() {
      _store.putRecords('expenses', [_expenseToLocal(voided)]);
      failure = _localAddExpense(
        shiftId: original.shiftId,
        cashierId: original.cashierId,
        categoryId: categoryId,
        paidToCafe: !withdrawal,
        paidToCashierId: withdrawal ? original.cashierId : null,
        amount: amount,
        description: description,
        editedFrom: original.id,
      );
    });
    _expenses = [for (final e in _expenses) e.id == id ? voided : e];
    return failure;
  }

  ShiftExpense _copyExpense(ShiftExpense e, {required bool voided}) => ShiftExpense(
    id: e.id,
    shiftId: e.shiftId,
    cashierId: e.cashierId,
    cashierName: e.cashierName,
    paidToCafe: e.paidToCafe,
    paidToCashierId: e.paidToCashierId,
    paidToCashierName: e.paidToCashierName,
    amount: e.amount,
    description: e.description,
    createdAt: e.createdAt,
    kind: e.kind,
    voided: voided,
    editedFrom: e.editedFrom,
    displayNumber: e.displayNumber,
    categoryId: e.categoryId,
    categoryNameEn: e.categoryNameEn,
    categoryNameAr: e.categoryNameAr,
  );

  // ------------------------------------------------------------------ images

  /// Keeps a picked picture inside the local database, shrunk like the online upload.
  String _localImage(String value) {
    if (!value.startsWith('data:')) return value;
    final comma = value.indexOf(',');
    if (comma < 0) return value;
    final shrunk = shrinkImage(base64Decode(value.substring(comma + 1)));
    if (shrunk == null) return value;
    return 'data:${shrunk.contentType};base64,${base64Encode(shrunk.bytes)}';
  }
}

const _localCafeId = 'local';

double _round2(double value) => (value * 100).round() / 100;
const _maxPinTries = 5;
const _pinLock = Duration(minutes: 15);
const _hashRounds = 20000;

/// Salted, repeated SHA-256 for local PINs and the admin password (no server to check them).
String _localHash(String secret, String salt) {
  var digest = sha256.convert(utf8.encode('$salt:$secret')).bytes;
  for (var i = 1; i < _hashRounds; i++) {
    digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
  }
  return base64Encode(digest);
}

Map<String, dynamic> _paymentTypeToLocal(PaymentType p) =>
    {'id': p.id, 'nameEn': p.nameEn, 'nameAr': p.nameAr, 'enabled': p.enabled, 'sortOrder': p.sortOrder, 'archived': p.archived};

PaymentType _paymentTypeFromLocal(Map<String, dynamic> r) => PaymentType(
  id: r['id'] as String,
  nameEn: r['nameEn'] as String? ?? '',
  nameAr: r['nameAr'] as String? ?? '',
  enabled: r['enabled'] as bool? ?? true,
  sortOrder: r['sortOrder'] as int? ?? 0,
  archived: r['archived'] as bool? ?? false,
);

Map<String, dynamic> _expenseCategoryToLocal(ExpenseCategory e) =>
    {'id': e.id, 'nameEn': e.nameEn, 'nameAr': e.nameAr, 'enabled': e.enabled, 'sortOrder': e.sortOrder};

ExpenseCategory _expenseCategoryFromLocal(Map<String, dynamic> r) => ExpenseCategory(
  id: r['id'] as String,
  nameEn: r['nameEn'] as String? ?? '',
  nameAr: r['nameAr'] as String? ?? '',
  enabled: r['enabled'] as bool? ?? true,
  sortOrder: r['sortOrder'] as int? ?? 0,
);

Map<String, dynamic> _paymentToLocal(Payment p) => {
  ...p.toJson(),
  'changes': [
    for (final c in p.changes)
      {
        'id': c.id,
        'oldTypeId': c.oldTypeId,
        'newTypeId': c.newTypeId,
        'actorName': c.actorName,
        'actorRole': c.actorRole,
        'createdAt': c.createdAt.toIso8601String(),
      },
  ],
};

Payment _paymentFromLocal(Map<String, dynamic> row) {
  final base = Payment.fromJson(row);
  base.changes.addAll([
    for (final c in (row['changes'] as List? ?? const []))
      PaymentMethodChange(
        id: (c as Map)['id'] as String,
        paymentId: base.id,
        oldTypeId: c['oldTypeId'] as String?,
        newTypeId: c['newTypeId'] as String?,
        actorName: c['actorName'] as String? ?? '',
        actorRole: c['actorRole'] as String? ?? 'admin',
        createdAt: DateTime.parse(c['createdAt'] as String),
      ),
  ]);
  return base;
}

Map<String, dynamic> _expenseToLocal(ShiftExpense e) => {
  'id': e.id,
  'shiftId': e.shiftId,
  'cashierId': e.cashierId,
  'cashierName': e.cashierName,
  'paidToCafe': e.paidToCafe,
  'paidToCashierId': e.paidToCashierId,
  'paidToCashierName': e.paidToCashierName,
  'amount': e.amount,
  'description': e.description,
  'createdAt': e.createdAt.toIso8601String(),
  'kind': e.kind,
  'voided': e.voided,
  'editedFrom': e.editedFrom,
  'displayNumber': e.displayNumber,
  'categoryId': e.categoryId,
  'categoryNameEn': e.categoryNameEn,
  'categoryNameAr': e.categoryNameAr,
};

ShiftExpense _expenseFromLocal(Map<String, dynamic> j) => ShiftExpense(
  id: j['id'] as String,
  shiftId: j['shiftId'] as String,
  cashierId: j['cashierId'] as String,
  cashierName: j['cashierName'] as String? ?? '',
  paidToCafe: j['paidToCafe'] as bool,
  paidToCashierId: j['paidToCashierId'] as String?,
  paidToCashierName: j['paidToCashierName'] as String? ?? '',
  amount: (j['amount'] as num).toDouble(),
  description: j['description'] as String,
  createdAt: DateTime.parse(j['createdAt'] as String),
  kind: j['kind'] as String? ?? 'cash_out',
  voided: j['voided'] as bool? ?? false,
  editedFrom: j['editedFrom'] as String?,
  displayNumber: j['displayNumber'] as String?,
  categoryId: j['categoryId'] as String?,
  categoryNameEn: j['categoryNameEn'] as String?,
  categoryNameAr: j['categoryNameAr'] as String?,
);
