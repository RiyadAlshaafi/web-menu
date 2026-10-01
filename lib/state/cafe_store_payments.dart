part of 'cafe_store.dart';

extension CafeStorePayments on CafeStore {
  CashShift? get openShift {
    final open = shifts.where((shift) => shift.isOpen).toList();
    return open.isEmpty ? null : open.first;
  }
  String saleNumber(Payment payment, {required bool perShift}) {
    if (perShift) {
      return cashierSaleNumber(yearMonth: payment.yearMonth, shiftOrderNumber: payment.shiftOrderNumber);
    }
    return adminSaleNumber(
      yearMonth: payment.yearMonth,
      monthlyOrderNumber: payment.monthlyOrderNumber,
      monthlyDisplayNumber: payment.monthlyDisplayNumber,
    );
  }

  String shiftTicket(CafeOrder order) {
    final n = order.shiftOrderNumber;
    if (n == null) return '…';
    return formatSaleNumber('0000', n).substring(4);
  }

  String typeName(String? id) {
    if (id == null || id.isEmpty) return locale == 'ar' ? 'نقداً' : 'Cash';
    final match = paymentTypes.where((type) => type.id == id);
    return match.isEmpty ? (locale == 'ar' ? 'نقداً' : 'Cash') : match.first.label(locale);
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

  Future<String?> addPaymentType(String nameEn, String nameAr) => _refreshAfter(db.addPaymentType(nameEn, nameAr));

  Future<String?> savePaymentType(PaymentType type) => _refreshAfter(db.savePaymentType(type));

  Future<String?> deletePaymentType(String id) {
    final used = payments.any((payment) => payment.paymentTypeId == id) || orders.any((order) => order.paymentTypeId == id);
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
      if (failure == 'sign in as a cashier first') return l10n.errCashierSignInFirst;
      return failure;
    }
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
}
