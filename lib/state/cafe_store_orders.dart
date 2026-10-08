part of 'cafe_store.dart';

extension CafeStoreOrders on CafeStore {
  CafeTable? tableBySlug(String slug) {
    final matches = tables.where((table) => !table.archived && (table.qrSlug == slug || table.id == slug));
    return matches.isEmpty ? null : matches.first;
  }

  CafeTable tableById(String id) => tables.firstWhere((table) => table.id == id);

  /// A line's dish name in the guest's language. Lines keep the name they were
  /// added with (the cafe's language), so look the dish up again.
  String guestLineName(OrderLine line) {
    final match = menuItems.where((item) => item.id == line.menuItemId);
    return match.isEmpty ? line.name : match.first.displayName(guestLocale);
  }

  /// Tables that are still in use (not archived).
  List<CafeTable> get activeTables => tables.where((table) => !table.archived).toList();

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
    return tables.where((table) {
      if (!requested.contains(table.id)) return false;
      return openOrderFor(table.id)?.serviceType != 'takeout';
    }).toList();
  }

  String? serviceChoiceFor(String slug) => _serviceBySlug[slug];

  void chooseService(String slug, String type) {
    _serviceBySlug[slug] = type == 'takeout' ? 'takeout' : 'dine_in';
    notifyListeners();
  }

  String serviceForTable(String tableId) {
    final order = openOrderFor(tableId);
    if (order != null) return order.serviceType;
    final table = tables.where((item) => item.id == tableId);
    if (table.isEmpty) return 'dine_in';
    return _serviceBySlug[table.first.qrSlug] ?? _serviceBySlug[table.first.id] ?? 'dine_in';
  }

  bool orderIsTakeout(CafeOrder order) => order.serviceType == 'takeout';

  bool paymentIsTakeout(Payment payment) {
    final match = orders.where((order) => order.id == payment.orderId);
    return match.isNotEmpty && match.first.serviceType == 'takeout';
  }

  /// What the table owes: only lines sent to the kitchen. Dishes still in the
  /// cart were never ordered, so the bill and settlement leave them out.
  double tabSubtotal(String tableId) => openOrderFor(tableId)?.subtotal ?? 0;

  double serviceCharge(double subtotal) => subtotal * serviceChargeRate;

  /// One formula for the amount on screen and the amount sent to settlement.
  double chargeTotal(double subtotal, {bool applyService = true}) =>
      applyService ? subtotal + serviceCharge(subtotal) : subtotal;

  double tabTotal(String tableId, {bool applyService = true}) {
    return chargeTotal(tabSubtotal(tableId), applyService: applyService);
  }

  int tabItemCount(String tableId) =>
      (openOrderFor(tableId)?.itemCount ?? 0) + cartFor(tableId).itemCount;

  /// Most of one dish a single send may carry; the server refuses more.
  static const maxDishQty = 99;

  void addToCart(String tableId, MenuItem item) {
    if (item.soldOut || !item.available) return;
    final cart = cartFor(tableId);
    final existing = cart.lines.where((line) => line.menuItemId == item.id);
    if (existing.isNotEmpty && existing.first.qty >= maxDishQty) return;
    if (existing.isEmpty) {
      cart.lines.add(
        OrderLine(
          menuItemId: item.id,
          name: item.displayName(locale),
          qty: 1,
          unitPrice: item.salePrice,
          listUnitPrice: item.price,
        ),
      );
    } else {
      existing.first.qty += 1;
    }
    db.writeCarts(carts).whenComplete(_writeFinished);
    _pendingWrites += 1;
    notifyListeners();
  }

  void setCartQty(String tableId, String menuItemId, int qty) {
    qty = qty > maxDishQty ? maxDishQty : qty;
    final cart = cartFor(tableId);
    cart.lines.removeWhere((line) => line.menuItemId == menuItemId && qty <= 0);
    for (final line in cart.lines.where((line) => line.menuItemId == menuItemId)) {
      line.qty = qty;
    }
    _pendingWrites += 1;
    db.writeCarts(carts).whenComplete(_writeFinished);
    notifyListeners();
  }

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
    var dishesChanged = false;
    try {
      final table = tables.where((item) => item.id == tableId);
      final slug = table.isEmpty ? '' : table.first.qrSlug;
      final block = slug.isEmpty ? null : await prepareGuestOrderLocation(slug);
      if (block != null) throw StateError(block);
      final error = await db.sendTableCart(
        tableId,
        serviceType: serviceForTable(tableId),
        lat: guestLocation == GuestLocationStatus.allowed ? _guestLat : null,
        lng: guestLocation == GuestLocationStatus.allowed ? _guestLng : null,
        accuracyM: guestLocation == GuestLocationStatus.allowed ? _guestAccuracyM : null,
      );
      if (error == 'too_far' || error == 'location_required') {
        _clearGuestPoint();
        guestLocation = error == 'too_far' ? GuestLocationStatus.tooFar : GuestLocationStatus.denied;
        notifyListeners();
      }
      if (error != null && error.startsWith(AppDatabase.unavailableItemsError)) {
        dishesChanged = true;
      }
      if (error != null) throw StateError(error);
      _hydrateOperational();
    } finally {
      _writeFinished();
      _sendingTables.remove(tableId);
      // Reload the menu so the dishes the server refused show as unavailable.
      if (dishesChanged) unawaited(syncFromDisk());
    }
    notifyListeners();
    return openOrderFor(tableId);
  }

  List<CafeTable> get diningTables =>
      tables.where((table) => !table.archived && !isServiceCounter(table)).toList();

  Future<String?> checkoutTakeout({
    required List<OrderLine> lines,
    String? paymentTypeId,
  }) async {
    if (_takeoutBusy) return 'in_flight';
    if (lines.isEmpty) return l10n.cashierExpenseInvalid;
    final cashier = currentCashier;
    var shift = currentShift ?? openShift;
    // After a shift was closed on this device, the next sale opens a new one here too.
    if (shift == null && cashier != null && offlineEnabled) {
      try {
        shift = await _openLocalShift(cashier);
      } catch (error, stackTrace) {
        reportError('open local shift', error, stackTrace);
        return l10n.offlineSaveFailed('$error');
      }
    }
    // An offline session has no cashier yet; its sales are assigned when the connection returns.
    if ((cashier == null && !offlineSession) || shift == null) return l10n.errCashierSignInFirst;
    final ticket = [
      for (final line in lines)
        OrderLine(
          menuItemId: line.menuItemId,
          name: line.name,
          qty: line.qty,
          unitPrice: line.unitPrice,
          listUnitPrice: line.listUnitPrice,
        ),
    ];
    _takeoutBusy = true;
    notifyListeners();
    try {
      await Future<void>.delayed(Duration.zero);
      if (offlineEnabled) {
        try {
          return await _checkoutTakeoutLocal(
            ticket: ticket,
            paymentTypeId: paymentTypeId,
            cashier: cashier,
            shift: shift,
          );
        } catch (error, stackTrace) {
          // e.g. the local file is full or locked: tell the cashier instead of leaving Pay stuck.
          reportError('save takeout on device', error, stackTrace);
          return l10n.offlineSaveFailed('$error');
        }
      }
      if (cashier == null) return l10n.errCashierSignInFirst;
      if (db.client == null) {
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final error = applyQuickTakeout(
          orders: orders,
          payments: payments,
          lines: ticket,
          paymentTypeId: paymentTypeId,
          cashierId: cashier.id,
          shiftId: shift.id,
          orderId: 'takeout-$stamp',
          paymentId: 'pay-$stamp',
        );
        notifyListeners();
        return error;
      }
      final error = await db.quickTakeoutReceipt(ticket, paymentTypeId);
      if (error != null) return error;
      await syncFromDisk();
      return null;
    } finally {
      _takeoutBusy = false;
      notifyListeners();
    }
  }

  bool canRequestBill(String tableId) {
    final order = openOrderFor(tableId);
    return order != null && order.status == OrderStatus.served && cartFor(tableId).lines.isEmpty;
  }

  Future<String?> requestBill(String tableId, {bool force = false}) async {
    if (!force && !canRequestBill(tableId)) return null;
    final table = tableById(tableId);
    final takeout = serviceForTable(tableId) == 'takeout';
    if (!takeout) table.status = TableStatus.billRequested;
    final openBill = calls.any((call) => call.tableId == tableId && call.kind == 'bill' && !call.resolved);
    if (!openBill) {
      calls.add(
        StaffCall(
          id: Secrets.id(),
          tableId: tableId,
          tableNumber: takeout ? 'Takeout' : table.number,
          createdAt: DateTime.now(),
          kind: 'bill',
        ),
      );
    }
    notifyListeners();
    // One server call marks the table and opens the bill call, so a guest no
    // longer needs write access to the table row.
    final error = await db.requestBill(
      qrSlug: authKind == AuthKind.none ? table.qrSlug : null,
      tableId: authKind == AuthKind.none ? null : tableId,
    );
    if (error != null && error.contains('cashier_offline')) {
      guestOrderingClosed();
      return l10n.guestOrderingPaused;
    }
    if (error != null) return error;
    notifyListeners();
    return null;
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

  /// Moves an order one kitchen step. Shows the change at once and puts it
  /// back if the server refuses; returns the server's error, if any.
  Future<String?> setOrderStatus(String orderId, OrderStatus status) async {
    final order = orders.firstWhere((item) => item.id == orderId);
    if (order.status.next != status) return null;
    final previous = order.status;
    order.status = status;
    notifyListeners();
    final error = await db.setOrderStatus(orderId, status);
    if (error == null) return null;
    order.status = previous;
    if (!_sessionExpired(error)) notifyListeners();
    return error;
  }
}
