part of 'cafe_store.dart';

extension CafeStoreOrders on CafeStore {

  CafeTable tableById(String id) => tables.firstWhere((table) => table.id == id);

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

  String serviceForTable(String tableId) => openOrderFor(tableId)?.serviceType ?? 'dine_in';

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

  /// Most of one dish a single send may carry; the server refuses more.
  static const maxDishQty = 99;

  /// Adds one [item], as it comes or with [onIds] turned on; it joins a line with the same choices.
  void addToCart(String tableId, MenuItem item, {Set<String>? onIds}) {
    if (item.soldOut || !item.available) return;
    final cart = cartFor(tableId);
    if (!item.canSellMore(_dishCountIn(cart, item.id))) return;
    final added = item.lineWith(locale: locale, onIds: onIds);
    final existing = cart.lines.where((line) => line.mergeKey == added.mergeKey);
    if (existing.isNotEmpty && existing.first.qty >= maxDishQty) return;
    if (existing.isEmpty) {
      cart.lines.add(added);
    } else {
      existing.first.qty += 1;
    }
    _saveCarts(tableId);
  }

  /// Sets the quantity of the cart line whose [OrderLine.mergeKey] is [lineKey].
  void setCartQty(String tableId, String lineKey, int qty) {
    qty = qty > maxDishQty ? maxDishQty : qty;
    final cart = cartFor(tableId);
    final line = cart.lines.where((line) => line.mergeKey == lineKey).firstOrNull;
    final item = menuItems.where((item) => item.id == line?.menuItemId).firstOrNull;
    final left = item?.stockQty;
    if (line != null && left != null && qty > line.qty) {
      // Raise this line only as far as the dish's stock allows across the whole cart.
      final others = _dishCountIn(cart, line.menuItemId) - line.qty;
      final most = left - others;
      if (most <= line.qty) return;
      if (qty > most) qty = most;
    }
    cart.lines.removeWhere((line) => line.mergeKey == lineKey && qty <= 0);
    for (final line in cart.lines.where((line) => line.mergeKey == lineKey)) {
      line.qty = qty;
    }
    _saveCarts(tableId);
  }

  /// Gives the cart line [lineKey] the choices [onIds]; it merges with a line that already has them.
  void setCartLineChoices(String tableId, String lineKey, Set<String> onIds) {
    final cart = cartFor(tableId);
    final line = cart.lines.where((line) => line.mergeKey == lineKey).firstOrNull;
    final item = menuItems.where((item) => item.id == line?.menuItemId).firstOrNull;
    if (line == null || item == null) return;
    replaceLineChoices(cart.lines, line, item.lineWith(locale: locale, onIds: onIds, qty: line.qty));
    for (final merged in cart.lines.where((other) => other.qty > maxDishQty)) {
      merged.qty = maxDishQty;
    }
    _saveCarts(tableId);
  }

  /// Saves only [tableId]'s cart, so another till's cart for a different table is never overwritten.
  int _dishCountIn(CartState cart, String menuItemId) =>
      cart.lines.where((line) => line.menuItemId == menuItemId).fold<int>(0, (sum, line) => sum + line.qty);

  void _saveCarts(String tableId) {
    _pendingWrites += 1;
    db.writeCarts(carts, tableId: tableId).whenComplete(_writeFinished);
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
      final staff = authKind != AuthKind.none;
      final error = await db.sendTableCart(
        tableId,
        serviceType: serviceForTable(tableId),
        // A guest's table comes from the request header; staff name the table they opened.
        qrSlug: staff && slug.isNotEmpty ? slug : null,
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
      if (staff) await _acceptOwnOrder(tableId);
    } finally {
      _writeFinished();
      _sendingTables.remove(tableId);
      // Reload the menu so the dishes the server refused show as unavailable.
      if (dishesChanged) unawaited(syncFromDisk());
    }
    notifyListeners();
    return openOrderFor(tableId);
  }

  /// The cashier typed this order in: it skips the "accept" step and the new-order sound.
  Future<void> _acceptOwnOrder(String tableId) async {
    _alertNewOrders(exceptTableId: tableId);
    final order = openOrderFor(tableId);
    if (db.isLocal || order == null || order.status != OrderStatus.received) return;
    final error = await setOrderStatus(order.id, OrderStatus.preparing);
    if (error != null) reportError('accept own table order', StateError(error), StackTrace.current);
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
          choices: line.choices,
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
      if (db.client == null && !db.isLocal) {
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
    _learnRequests();
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

  /// Frees a table for good: unpaid orders are cancelled, the cart is emptied and the table goes
  /// back to free. A waiter's clear is refused while an order is unpaid. Needs the server (or this
  /// PC's own database); returns the error, if any.
  Future<String?> clearTable(String tableId) async {
    if (db.offlineMode) return ErrorCodes.network;
    final failure = authKind == AuthKind.waiter ? await db.waiterClearTable(tableId) : await db.clearTable(tableId);
    if (failure != null) {
      _sessionExpired(failure); // signs the cashier out when the session ended
      return failure;
    }
    await syncFromDisk();
    notifyListeners();
    return null;
  }

  /// Moves the tab and cart of [fromId] to [toId], or merges them into its tab. Needs the server
  /// (or this PC's own database); returns the error, if any.
  Future<String?> moveTable(String fromId, String toId) async {
    if (db.offlineMode) return ErrorCodes.network;
    final failure = await db.moveTable(fromId, toId);
    if (failure != null) {
      _sessionExpired(failure);
      return switch (failure) {
        'nothing to move' => l10n.moveTableNothing,
        'pick another table' || 'table not found' => l10n.moveTablePickOther,
        _ => failure,
      };
    }
    await syncFromDisk();
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
    _learnRequests();
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
