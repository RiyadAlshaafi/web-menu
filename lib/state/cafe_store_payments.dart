part of 'cafe_store.dart';

extension CafeStorePayments on CafeStore {
  CashShift? get openShift {
    final open = shifts.where((shift) => shift.isOpen).toList();
    return open.isEmpty ? null : open.first;
  }

  String saleNumber(Payment payment, {required bool perShift}) {
    if (perShift) {
      return cashierSaleNumber(
        yearMonth: payment.yearMonth,
        shiftOrderNumber: payment.shiftOrderNumber,
      );
    }
    return adminSaleNumber(
      yearMonth: payment.yearMonth,
      monthlyOrderNumber: payment.monthlyOrderNumber,
      monthlyDisplayNumber: payment.monthlyDisplayNumber,
    );
  }

  String receiptNumber(Payment payment) {
    if (payment.monthlyOrderNumber == null) {
      return payment.monthlyDisplayNumber ?? '—';
    }
    return formatReceiptNumber(payment.yearMonth, payment.monthlyOrderNumber);
  }

  String orderNumber(int? sequence) => formatOrderNumber(sequence);

  String shiftTicket(CafeOrder order) =>
      formatOrderNumber(order.shiftOrderNumber);

  String typeName(String? id) {
    if (id == null || id.isEmpty) return locale == 'ar' ? 'نقداً' : 'Cash';
    final match = paymentTypes.where((type) => type.id == id);
    return match.isEmpty
        ? (locale == 'ar' ? 'نقداً' : 'Cash')
        : match.first.label(locale);
  }

  List<PaymentType> get enabledPaymentTypes =>
      paymentTypes.where((type) => type.enabled && !type.archived).toList();

  Future<String?> _refreshAfter(Future<String?> action) async {
    final error = await action;
    _hydrateOperational();
    notifyListeners();
    return error;
  }

  Future<String?> setTablePaymentType(String tableId, String typeId) =>
      _refreshAfter(db.setTablePaymentType(tableById(tableId).qrSlug, typeId));

  Future<String?> changePaymentType(String paymentId, String typeId) =>
      _refreshAfter(db.changePaymentType(paymentId, typeId));

  Future<String?> addPaymentType(String nameEn, String nameAr) =>
      _refreshAfter(db.addPaymentType(nameEn, nameAr));

  Future<String?> savePaymentType(PaymentType type) =>
      _refreshAfter(db.savePaymentType(type));

  Future<String?> deletePaymentType(String id) {
    final used =
        payments.any((payment) => payment.paymentTypeId == id) ||
        orders.any((order) => order.paymentTypeId == id);
    final match = paymentTypes.where((type) => type.id == id);
    if (match.isEmpty) return Future.value(null);
    if (used) {
      final type = match.first;
      type
        ..archived = true
        ..enabled = false;
      return savePaymentType(type);
    }
    return _refreshAfter(db.deletePaymentType(id));
  }

  bool get salesHasMore => db.salesHasMore;

  Future<void> loadMoreSales() async {
    await db.loadMoreSales();
    _hydrateOperational();
    notifyListeners();
  }

  Future<void> alignSalesWindow({DateTime? from, DateTime? to}) async {
    await db.alignSalesWindow(from: from, to: to);
    _hydrateOperational();
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
    if (order.status != OrderStatus.served) return l10n.cashierWaitingServed;
    final due = tabTotal(tableId, applyService: applyService);
    if (cashReceived < due) return l10n.insufficientCash;
    final failure = await db.settleCash(
      tableId,
      cashReceived,
      applyService: applyService,
      paymentTypeId: openOrderFor(tableId)?.paymentTypeId,
    );
    if (failure != null) {
      if (_sessionExpired(failure)) return failure;
      if (failure == 'insufficient cash') return l10n.insufficientCash;
      if (failure == 'order is not served') return l10n.cashierWaitingServed;
      return failure;
    }
    await syncFromDisk();
    notifyListeners();
    return null;
  }

  Future<String?> clearTestLogs(String scope) async {
    final cashier = currentCashier;
    if (cashier == null) return l10n.errCashierSignInFirst;
    final failure = await db.clearTestLogs(scope, cashierId: cashier.id);
    if (failure != null) {
      if (failure == 'sign in as a cashier first') {
        return l10n.errCashierSignInFirst;
      }
      return failure;
    }
    await syncFromDisk();
    notifyListeners();
    return null;
  }

  double expectedDrawer(CashShift shift) {
    final cashIds = paymentTypes
        .where((type) => type.nameEn.toLowerCase() == 'cash')
        .map((type) => type.id)
        .toSet();
    final cashTaken = payments
        .where(
          (payment) =>
              payment.shiftId == shift.id &&
              (payment.paymentTypeId == null ||
                  cashIds.contains(payment.paymentTypeId)),
        )
        .fold<double>(0, (sum, payment) => sum + payment.totalDue);
    final cashPaidOut = expenses
        .where((expense) => expense.shiftId == shift.id && !expense.voided)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    return shift.drawerCash(cashTaken: cashTaken, cashPaidOut: cashPaidOut);
  }

  Future<String?> addShiftExpense({
    required bool paidToCafe,
    required String? paidToCashierId,
    required double amount,
    required String description,
  }) async {
    final shift = currentShift ?? openShift;
    final cashier = currentCashier;
    if (shift == null || cashier == null) return l10n.errNoOpenShift;
    if ((!paidToCafe && (paidToCashierId == null || paidToCashierId.isEmpty)) ||
        amount <= 0 ||
        description.trim().isEmpty) {
      return l10n.cashierExpenseInvalid;
    }
    await db.writeShifts(shifts);
    final failure = await db.addShiftExpense(
      shiftId: shift.id,
      cashierId: cashier.id,
      paidToCafe: paidToCafe,
      paidToCashierId: paidToCashierId,
      amount: amount,
      description: description.trim(),
    );
    if (failure != null) return _expenseError(failure);
    _hydrateOperational();
    _syncStamp = _stamp();
    notifyListeners();
    return null;
  }

  Future<String?> editShiftExpense({
    required ShiftExpense expense,
    required bool paidToCafe,
    required double amount,
    required String description,
  }) async {
    final shift = shifts.where((item) => item.id == expense.shiftId);
    final open = currentShift ?? openShift;
    final cashier = currentCashier;
    if (cashier == null ||
        open == null ||
        !open.isOpen ||
        open.id != expense.shiftId ||
        expense.cashierId != cashier.id ||
        expense.voided ||
        shift.isEmpty ||
        !shift.first.isOpen) {
      return l10n.cashierExpenseNotEditable;
    }
    final failure = await db.editShiftExpense(
      id: expense.id,
      paidToCafe: paidToCafe,
      amount: amount,
      description: description.trim(),
    );
    if (failure != null) return _expenseError(failure);
    _hydrateOperational();
    _syncStamp = _stamp();
    notifyListeners();
    return null;
  }

  String _expenseError(String failure) {
    if (failure == 'not_found') return l10n.cashierExpenseNotEditable;
    if (failure == 'sign in as a cashier first') return l10n.errCashierSignInFirst;
    if (failure == 'invalid') return l10n.cashierExpenseInvalid;
    return failure;
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
}
