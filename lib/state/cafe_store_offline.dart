part of 'cafe_store.dart';

/// Offline support for the cashier app: takeout sales, expenses and shift changes are saved on the
/// device first and uploaded in order whenever the server answers. Only the desktop app keeps a
/// local outbox; the web keeps its old online-only behaviour.
extension CafeStoreOffline on CafeStore {
  /// Whether this install saves cashier work locally before uploading it.
  bool get offlineEnabled => offline != null;

  /// Server is unreachable right now (desktop only; the web always reports online).
  bool get isOffline => offline != null && !offline!.online;

  Future<void> _initOffline() async {
    if (kIsWeb) return;
    try {
      final store = await OutboxStore.open(AppDatabase.supabaseUrl);
      final sync = OfflineSync(store: store, rpc: db.callRpc);
      await sync.init();
      sync.onChange = notifyListeners;
      offline = sync;
      await _reloadLocalItems();
    } catch (error, stackTrace) {
      // Without a local file the app still works online exactly as before.
      reportError('offline outbox', error, stackTrace);
      offline = null;
    }
  }

  /// Rereads the not-yet-uploaded items so they keep showing on screen. Both lists are read
  /// first and swapped in at once, so a refresh in between never sees an empty list.
  Future<void> _reloadLocalItems() async {
    final sync = offline;
    if (sync == null) return;
    final pending = await sync.pendingItems();
    final failed = await sync.failedItems();
    _localItems
      ..clear()
      ..addAll(pending)
      ..addAll(failed.where((item) => !pending.any((p) => p.id == item.id)));
  }

  /// Shows a just-saved item; a reload that already picked it up is not doubled.
  void _keepLocal(OutboxItem item) {
    if (_localItems.any((existing) => existing.id == item.id)) return;
    _localItems.add(item);
  }

  /// Adds unsent local sales, expenses and shift changes on top of what the server sent.
  void _mergeLocalItems() {
    if (_localItems.isEmpty) return;
    final paymentIds = payments.map((p) => p.id).toSet();
    final orderIds = orders.map((o) => o.id).toSet();
    final expenseIds = expenses.map((e) => e.id).toSet();
    final shiftIds = shifts.map((s) => s.id).toSet();
    for (final item in _localItems) {
      final local = item.payload['local'];
      if (local is! Map) continue;
      final data = Map<String, dynamic>.from(local);
      switch (item.kind) {
        case 'takeout':
          final payment = Payment.fromJson(Map<String, dynamic>.from(data['payment'] as Map));
          final order = CafeOrder.fromJson(Map<String, dynamic>.from(data['order'] as Map));
          if (!paymentIds.contains(payment.id)) payments = [...payments, payment];
          if (!orderIds.contains(order.id)) orders = [...orders, order];
        case 'expense':
          final expense = _expenseFromJson(Map<String, dynamic>.from(data['expense'] as Map));
          if (!expenseIds.contains(expense.id)) expenses = [expense, ...expenses];
        case 'shift_open':
          final shift = CashShift.fromJson(Map<String, dynamic>.from(data['shift'] as Map));
          if (!shiftIds.contains(shift.id)) shifts = [shift, ...shifts];
        case 'shift_close':
          final id = data['shift_id'] as String;
          for (final shift in shifts.where((s) => s.id == id && s.isOpen)) {
            shift
              ..closedAt = DateTime.parse(data['closed_at'] as String)
              ..actualCash = (data['actual_cash'] as num).toDouble();
          }
      }
    }
  }

  void _startCashierPulse() {
    _cashierPulse?.cancel();
    offline?.signedIn();
    unawaited(_pulse());
    _cashierPulse = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_pulse()));
  }

  void _stopCashierPulse() {
    _cashierPulse?.cancel();
    _cashierPulse = null;
  }

  /// Every 15 s: tell the server a cashier is here, upload waiting work, keep numbers in stock.
  Future<void> _pulse() async {
    if (authKind != AuthKind.cashier || db.client == null) return;
    final sync = offline;
    if (sync == null) {
      // Web cashier: only the presence signal that keeps guest ordering open.
      try {
        await db.callRpc('cashier_heartbeat', const {});
      } catch (error, stackTrace) {
        reportError('cashier heartbeat', error, stackTrace);
      }
      return;
    }
    final wasOffline = !sync.online;
    await sync.heartbeat();
    if (!sync.online) return;
    if (!offlineSession && await sync.dropIdleUnassignedShifts() > 0) await _reloadLocalItems();
    await _uploadNow();
    await sync.topUp();
    await _saveSnapshot();
    if (wasOffline) await syncFromDisk();
  }

  /// Uploads waiting items now and refreshes the screens if anything went up.
  Future<void> _uploadNow() async {
    final sync = offline;
    if (sync == null) return;
    final uploaded = await sync.flush();
    if (uploaded == 0 && sync.failedCount == _lastFailedCount) return;
    _lastFailedCount = sync.failedCount;
    await _reloadLocalItems();
    try {
      await db.refreshFromDisk(liveOnly: true);
    } catch (error, stackTrace) {
      reportError('refresh after upload', error, stackTrace);
    }
    _hydrateOperational();
    notifyListeners();
  }

  /// Opens a shift on this device when none is open (for example after closing one offline).
  Future<CashShift?> _openLocalShift(Cashier cashier) async {
    final sync = offline;
    if (sync == null) return null;
    final now = DateTime.now().toUtc();
    final shift = CashShift(id: Secrets.id(), cashierId: cashier.id, openedAt: now, openingCash: 0);
    final item = OutboxItem(
      id: Secrets.id(),
      kind: 'shift_open',
      createdAt: now,
      payload: {
        'params': {'p_client_id': shift.id, 'p_cashier_id': cashier.id, 'p_opened_at': now.toIso8601String()},
        'local': {'shift': shift.toJson()},
      },
    );
    await sync.enqueue(item);
    _keepLocal(item);
    shifts = [shift, ...shifts];
    currentShift = shift;
    return shift;
  }

  Future<String?> _checkoutTakeoutLocal({
    required List<OrderLine> ticket,
    required String? paymentTypeId,
    required Cashier? cashier,
    required CashShift shift,
  }) async {
    final sync = offline!;
    var number = await sync.takeNumber();
    if (number == null && sync.online) {
      await sync.topUp();
      number = await sync.takeNumber();
    }
    if (number == null) {
      if (!sync.online) return l10n.offlineNoNumbers;
      // Online but no numbers could be reserved: fall back to the plain online sale.
      final error = await db.quickTakeoutReceipt(ticket, paymentTypeId);
      if (error != null) return error;
      await syncFromDisk();
      return null;
    }
    final reserved = number;
    final id = Secrets.id();
    final paidAt = DateTime.now().toUtc();
    final localOrders = <CafeOrder>[];
    final localPayments = <Payment>[];
    final error = applyQuickTakeout(
      orders: localOrders,
      payments: localPayments,
      lines: ticket,
      paymentTypeId: paymentTypeId,
      cashierId: cashier?.id ?? '',
      shiftId: shift.id,
      orderId: id,
      paymentId: id,
      paidAt: paidAt,
    );
    if (error != null) return error;
    final type = paymentTypes.where((t) => t.id == paymentTypeId).firstOrNull;
    String label(int n) => '${reserved.yearMonth}${n.toString().padLeft(3, '0')}';
    final base = localPayments.single;
    final payment = Payment(
      id: base.id,
      orderId: base.orderId,
      tableId: base.tableId,
      isTakeout: true,
      cashierName: cashier?.name ?? l10n.offlineUnassigned,
      paymentTypeNameEn: type?.nameEn,
      paymentTypeNameAr: type?.nameAr,
      totalDue: base.totalDue,
      cashReceived: base.totalDue,
      changeDue: 0,
      cashierId: cashier?.id ?? '',
      shiftId: shift.id,
      paidAt: paidAt,
      paymentTypeId: paymentTypeId,
      yearMonth: reserved.yearMonth,
      shiftOrderNumber: reserved.day,
      monthlyOrderNumber: reserved.monthly,
      shiftDisplayNumber: reserved.day == null ? null : label(reserved.day!),
      monthlyDisplayNumber: label(reserved.monthly),
    );
    final order = localOrders.single
      ..yearMonth = reserved.yearMonth
      ..shiftOrderNumber = reserved.day;
    final item = OutboxItem(
      id: id,
      kind: 'takeout',
      createdAt: paidAt,
      payload: {
        'params': {
          'p_client_id': id,
          'p_cashier_id': cashier?.id,
          'p_shift_id': shift.id,
          'p_lines': [
            for (final line in order.lines)
              {
                'menu_item_id': line.menuItemId,
                'name': line.name,
                'qty': line.qty,
                'unit_price': line.unitPrice,
                'list_unit_price': line.listUnitPrice ?? line.unitPrice,
              },
          ],
          'p_payment_type_id': paymentTypeId,
          'p_paid_at': paidAt.toIso8601String(),
          'p_year_month': reserved.yearMonth,
          'p_monthly_no': reserved.monthly,
          'p_day_key': reserved.dayKey,
          'p_day_no': reserved.day,
        },
        'local': {'order': order.toJson(), 'payment': payment.toJson()},
      },
    );
    // Saved on the device before it is shown or printed, so a crash cannot lose it.
    await sync.enqueue(item);
    _keepLocal(item);
    orders = [...orders, order];
    payments = [...payments, payment];
    notifyListeners();
    unawaited(_uploadNow());
    return null;
  }

  Future<String?> _addExpenseLocal({
    required CashShift shift,
    required Cashier? cashier,
    required ExpenseCategory category,
    required double amount,
    required String description,
  }) async {
    final sync = offline!;
    final id = Secrets.id();
    final now = DateTime.now().toUtc();
    final withdrawal = category.nameEn == 'Cash Withdrawal';
    final name = cashier?.name ?? l10n.offlineUnassigned;
    final expense = ShiftExpense(
      id: id,
      shiftId: shift.id,
      cashierId: cashier?.id ?? '',
      cashierName: name,
      paidToCafe: !withdrawal,
      paidToCashierId: withdrawal ? cashier?.id : null,
      paidToCashierName: withdrawal ? name : '',
      amount: amount,
      description: description,
      createdAt: now,
      displayNumber: l10n.offlinePendingNumber,
      categoryId: category.id,
      categoryNameEn: category.nameEn,
      categoryNameAr: category.nameAr,
    );
    final item = OutboxItem(
      id: id,
      kind: 'expense',
      createdAt: now,
      payload: {
        'params': {
          'p_client_id': id,
          'p_cashier_id': cashier?.id,
          'p_shift_id': shift.id,
          'p_expense_category_id': category.id,
          'p_amount': amount,
          'p_description': description,
          'p_created_at': now.toIso8601String(),
        },
        'local': {'expense': _expenseToJson(expense)},
      },
    );
    await sync.enqueue(item);
    _keepLocal(item);
    expenses = [expense, ...expenses];
    notifyListeners();
    unawaited(_uploadNow());
    return null;
  }

  /// Closes the shift on the device and uploads the close after any sales still waiting.
  Future<String?> _closeShiftLocal(CashShift shift, Cashier cashier, double actualCash) async {
    final sync = offline!;
    final now = DateTime.now().toUtc();
    final item = OutboxItem(
      id: Secrets.id(),
      kind: 'shift_close',
      createdAt: now,
      payload: {
        'params': {
          'p_client_id': shift.id,
          'p_cashier_id': cashier.id,
          'p_actual_cash': actualCash,
          'p_closed_at': now.toIso8601String(),
        },
        'local': {'shift_id': shift.id, 'closed_at': now.toIso8601String(), 'actual_cash': actualCash},
      },
    );
    await sync.enqueue(item);
    _keepLocal(item);
    shift
      ..closedAt = now
      ..actualCash = actualCash;
    currentShift = null;
    notifyListeners();
    unawaited(_uploadNow());
    return null;
  }

  /// At startup: if the server can't be reached, load the saved copy so the till can run offline.
  Future<void> _checkConnectionAtStart() async {
    final sync = offline;
    if (sync == null || db.client == null) return;
    _savedSnapshot = await sync.store.readValue('snapshot');
    canStartOffline = _savedSnapshot != null;
    if (await db.serverReachable()) return;
    serverUnreachable = true;
    if (_savedSnapshot != null) {
      try {
        db.applyOfflineSnapshot(Map<String, dynamic>.from(jsonDecode(_savedSnapshot!) as Map));
        db.offlineMode = true;
      } catch (error, stackTrace) {
        reportError('read saved menu', error, stackTrace);
        canStartOffline = false;
      }
    }
    _startReconnectProbe();
  }

  /// Saves the menu and settings on this device (only when they changed) for an offline start.
  Future<void> _saveSnapshot() async {
    final sync = offline;
    if (sync == null || db.offlineMode || db.restaurantId == null || db.menuItems.isEmpty) return;
    final json = jsonEncode(db.offlineSnapshot());
    if (json == _savedSnapshot) return;
    await sync.store.writeValue('snapshot', json);
    _savedSnapshot = json;
    canStartOffline = true;
  }

  /// Starts selling without internet: takeout and expenses only, no cashier until the connection returns.
  /// The offline shift is saved for upload first, with no cashier yet; whoever is chosen after the
  /// connection returns gets the shift and everything sold on it.
  Future<void> startOfflineSession() async {
    if (!canStartOffline) return;
    db.offlineMode = true;
    stopLiveSync();
    _hydrateOperational();
    final now = DateTime.now().toUtc();
    final shift = CashShift(id: Secrets.id(), cashierId: '', openedAt: now, openingCash: 0);
    final sync = offline;
    if (sync != null) {
      final item = OutboxItem(
        id: Secrets.id(),
        kind: 'shift_open',
        createdAt: now,
        payload: {
          'params': {'p_client_id': shift.id, 'p_cashier_id': null, 'p_opened_at': now.toIso8601String()},
          'local': {'shift': shift.toJson()},
        },
      );
      try {
        await sync.enqueue(item);
        _keepLocal(item);
      } catch (error, stackTrace) {
        // Sales still upload; without this item the server falls back to the cashier's open shift.
        reportError('save offline shift', error, stackTrace);
      }
    }
    shifts = [shift, ...shifts];
    currentShift = shift;
    currentCashier = null;
    authKind = AuthKind.cashier;
    offlineSession = true;
    reconnectPending = false;
    offline?.online = false;
    _startReconnectProbe();
    notifyListeners();
  }

  void _startReconnectProbe() {
    _reconnectProbe?.cancel();
    _reconnectProbe = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!await db.serverReachable()) return;
      _reconnectProbe?.cancel();
      _reconnectProbe = null;
      await _onReconnected();
    });
  }

  Future<void> _onReconnected() async {
    serverUnreachable = false;
    db.offlineMode = false;
    offline?.online = true;
    try {
      await db.refreshFromDisk();
    } catch (error, stackTrace) {
      reportError('reload after reconnect', error, stackTrace);
    }
    final keep = currentShift;
    _hydrateOperational();
    if (offlineSession) {
      // Keep selling on the offline shift until a cashier claims the work.
      if (keep != null && !shifts.any((s) => s.id == keep.id)) shifts = [keep, ...shifts];
      currentShift = keep;
      reconnectPending = true;
    }
    notifyListeners();
  }

  /// Number of receipts and expenses made offline that still need a cashier.
  int get unassignedOfflineCount => offline?.unassignedCount ?? 0;

  /// A cashier is signed in online and offline work from an earlier session still has no cashier.
  bool get needsCashierForOfflineWork =>
      authKind == AuthKind.cashier && !offlineSession && !isOffline && unassignedOfflineCount > 0;

  /// Gives the offline work to [cashierId] (chosen by the signed-in cashier) and uploads it.
  Future<String?> assignOfflineWork(String cashierId) async {
    final sync = offline;
    if (sync == null) return null;
    final cashier = cashiers.where((item) => item.id == cashierId).firstOrNull;
    await sync.assignCashier(cashierId, cashierName: cashier?.name);
    await _reloadLocalItems();
    _hydrateOperational();
    notifyListeners();
    await _uploadNow();
    return null;
  }

  /// After the connection returns: [cashierId] signs in with [pin] and takes the offline work.
  Future<String?> claimOfflineWork(String cashierId, String pin) async {
    final sync = offline;
    if (sync == null) return null;
    db.offlineMode = false;
    final result = await db.loginCashier(cashierId, pin);
    if (result['ok'] != true) {
      final member = cashiers.where((item) => item.id == cashierId);
      final name = member.isEmpty ? '' : member.first.name;
      if (result['code'] == 'locked') {
        final seconds = (result['retry_after_seconds'] as num?)?.toInt() ?? 900;
        return l10n.errPinLocked(name, (seconds / 60).ceil());
      }
      return result['error'] as String? ?? l10n.errPinMismatch(name);
    }
    _hydrateOperational();
    final cashier = cashiers.where((item) => item.id == cashierId).firstOrNull;
    await sync.assignCashier(cashierId, cashierName: cashier?.name);
    await _reloadLocalItems();
    offlineSession = false;
    reconnectPending = false;
    selectedCashierId = cashierId;
    currentCashier = cashier;
    authKind = AuthKind.cashier;
    currentShift = null;
    try {
      await _ensureShift();
    } catch (error, stackTrace) {
      reportError('cashier shift after reconnect', error, stackTrace);
    }
    startLiveSync();
    _startCashierPulse();
    await _uploadNow();
    notifyListeners();
    return null;
  }

  /// Keeps [guestOrderingOpen] current for the guest page: checks now and every 15 seconds.
  void _watchGuestOrdering(String slug) {
    if (_guestOrderingSlug == slug && _guestOrderingPoll != null) return;
    _guestOrderingSlug = slug;
    _guestOrderingPoll?.cancel();
    unawaited(refreshGuestOrdering());
    _guestOrderingPoll = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(refreshGuestOrdering()));
  }

  /// Asks the server whether a cashier is online to take this table's orders.
  Future<void> refreshGuestOrdering() async {
    final slug = _guestOrderingSlug;
    if (slug == null || db.client == null) return;
    try {
      final open = await db.callRpc('guest_ordering_open', {'p_qr_slug': slug}) == true;
      if (open != guestOrderingOpen) {
        guestOrderingOpen = open;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      // Can't reach the server: leave the current state; sending will report the problem.
      reportError('guest ordering check', error, stackTrace);
    }
  }

  /// The server refused a guest action because no cashier is online.
  void guestOrderingClosed() {
    if (!guestOrderingOpen) return;
    guestOrderingOpen = false;
    notifyListeners();
  }

  /// Puts items the server refused back in the queue (after fixing the cause).
  Future<void> retryFailedUploads() async {
    await offline?.retryFailed();
    await _uploadNow();
  }
}

Map<String, dynamic> _expenseToJson(ShiftExpense e) => {
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
  'displayNumber': e.displayNumber,
  'categoryId': e.categoryId,
  'categoryNameEn': e.categoryNameEn,
  'categoryNameAr': e.categoryNameAr,
};

ShiftExpense _expenseFromJson(Map<String, dynamic> j) => ShiftExpense(
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
  displayNumber: j['displayNumber'] as String?,
  categoryId: j['categoryId'] as String?,
  categoryNameEn: j['categoryNameEn'] as String?,
  categoryNameAr: j['categoryNameAr'] as String?,
);

/// Runs a save on the device and turns a failure (full disk, locked file) into a message.
extension CafeStoreSafeSave on CafeStore {
  Future<String?> _guarded(String label, Future<String?> Function() save) async {
    try {
      return await save();
    } catch (error, stackTrace) {
      reportError(label, error, stackTrace);
      return l10n.offlineSaveFailed('$error');
    }
  }
}

extension CafeStoreSession on CafeStore {
  /// The cashier's 12-hour sign-in ended: the till can't upload or report in until they sign in again.
  bool get sessionExpired => authKind == AuthKind.cashier && !offlineSession && (offline?.needsSignIn ?? false);
}
