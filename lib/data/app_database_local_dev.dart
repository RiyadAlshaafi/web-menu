part of 'app_database.dart';

/// Offline mode: the developer tools, working on this PC's local database. Each case stands in for
/// the server function of the same name (supabase/migrations) and answers in the same shape. The
/// developer password was already checked when the screen opened; this PC has no slots or tills.
extension AppDatabaseLocalDev on AppDatabase {
  Map<String, dynamic> _localDevCall(String name, Map<String, dynamic>? extra) {
    final Map<String, dynamic> result;
    switch (name) {
      case 'dev_reset_admin':
        result = _localDevResetAdmin();
      case 'dev_export_logs':
        return _localDevExportLogs();
      case 'dev_import_logs':
        result = _localDevImportLogs(extra);
      case 'dev_wipe_logs':
        result = _localDevWipeLogs();
      case 'dev_wipe_menu':
        result = _localDevWipeMenu();
      default:
        return {'ok': false, 'error': 'The offline version has no $name.'};
    }
    if (result['ok'] == true) _loadLocal();
    return result;
  }

  /// Removes the admin only, so the next start asks for a new PIN. Sales, menu and settings stay.
  Map<String, dynamic> _localDevResetAdmin() {
    _store.writeDoc('admin', null);
    return {'ok': true, 'removed': 1};
  }

  Map<String, dynamic> _localDevExportLogs() {
    final orders = {for (final row in _store.readRecords('orders')) row['id'] as String: CafeOrder.fromJson(row)};
    final payments = [for (final row in _store.readRecords('payments')) _paymentFromLocal(row)]
      ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
    final expenses = [for (final row in _store.readRecords('expenses')) _expenseFromLocal(row)]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return {
      'ok': true,
      'payments': [
        for (final payment in payments)
          {
            'id': payment.id,
            'paid_at': payment.paidAt.toIso8601String(),
            'total_due': payment.totalDue,
            'cash_received': payment.cashReceived,
            'change_due': payment.changeDue,
            'shift_display_number': payment.shiftDisplayNumber,
            'monthly_display_number': payment.monthlyDisplayNumber,
            'service_type': orders[payment.orderId]?.serviceType ?? (payment.isTakeout ? 'takeout' : 'dine_in'),
            'table_number': payment.tableNumber,
            'lines': [
              for (final line in orders[payment.orderId]?.lines ?? const <OrderLine>[])
                {'name': line.name, 'qty': line.qty, 'unit_price': line.unitPrice},
            ],
          },
      ],
      'expenses': [
        for (final expense in expenses)
          {
            'id': expense.id,
            'created_at': expense.createdAt.toIso8601String(),
            'amount': expense.amount,
            'description': expense.description,
            'kind': expense.kind,
            'paid_to_cafe': expense.paidToCafe,
          },
      ],
    };
  }

  /// Adds the backup as new rows, like the server: everything is checked first, receipts go to the
  /// first cashier and the latest shift, and a takeout needs no table.
  Map<String, dynamic> _localDevImportLogs(Map<String, dynamic>? extra) {
    final receipts = [for (final row in (extra?['p_receipts'] as List? ?? const [])) Map<String, dynamic>.from(row as Map)];
    final expenses = [for (final row in (extra?['p_expenses'] as List? ?? const [])) Map<String, dynamic>.from(row as Map)];
    if (receipts.isEmpty && expenses.isEmpty) return {'ok': false, 'error': 'The file has headers but no rows to import.'};
    for (final receipt in receipts) {
      if (receipt['service'] != 'takeout' && _localDevTable(receipt['table'] as String?) == null) {
        return {'ok': false, 'error': 'No table named ${receipt['table'] ?? ''}.'};
      }
    }
    for (final expense in expenses) {
      if ((double.tryParse(expense['amount'] as String? ?? '') ?? 0) <= 0) {
        return {'ok': false, 'error': 'An expense amount must be greater than zero.'};
      }
    }
    final cashier = _cashiers.firstOrNull;
    if (cashier == null) return {'ok': false, 'error': 'Add a cashier before importing logs.'};
    _store.transaction(() {
      var shift = _shifts.firstOrNull;
      if (shift == null) {
        final now = DateTime.now().toUtc();
        shift = CashShift(id: Secrets.id(), cashierId: cashier.id, openedAt: now, closedAt: now, openingCash: 0);
        _store.putRecords('shifts', [shift.toJson()]);
      }
      for (final receipt in receipts) {
        _localDevImportReceipt(receipt, cashier, shift.id);
      }
      for (final expense in expenses) {
        _localDevImportExpense(expense, cashier, shift.id);
      }
    });
    return {'ok': true, 'receipts': receipts.length, 'expenses': expenses.length};
  }

  CafeTable? _localDevTable(String? number) {
    final wanted = (number ?? '').trim().toLowerCase();
    return _tables.where((table) => table.number.trim().toLowerCase() == wanted).firstOrNull;
  }

  void _localDevImportReceipt(Map<String, dynamic> receipt, Cashier cashier, String shiftId) {
    final takeout = receipt['service'] == 'takeout';
    final table = takeout ? null : _localDevTable(receipt['table'] as String?);
    final paidAt = DateTime.parse(receipt['paid_at'] as String).toUtc();
    final total = double.parse(receipt['total_due'] as String);
    final order = CafeOrder(
      id: Secrets.id(),
      tableId: table?.id ?? '',
      tableNumber: table?.number ?? '',
      status: OrderStatus.paid,
      createdAt: paidAt,
      cashierId: cashier.id,
      serviceType: takeout ? 'takeout' : 'dine_in',
      yearMonth: _tripoliKey(paidAt, withDay: false),
      lines: [
        for (final line in (receipt['lines'] as List? ?? const []))
          OrderLine(
            id: Secrets.id(),
            menuItemId: '',
            name: line['name'] as String,
            qty: line['qty'] as int,
            unitPrice: double.parse(line['unit_price'] as String),
          ),
      ],
    );
    final payment = Payment(
      id: Secrets.id(),
      orderId: order.id,
      tableId: order.tableId,
      tableNumber: order.tableNumber,
      isTakeout: takeout,
      cashierName: cashier.name,
      totalDue: total,
      cashReceived: total,
      changeDue: 0,
      cashierId: cashier.id,
      shiftId: shiftId,
      paidAt: paidAt,
      yearMonth: order.yearMonth,
      shiftDisplayNumber: _blankToNull(receipt['receipt'] as String?),
      monthlyDisplayNumber: _blankToNull(receipt['monthly'] as String?),
    );
    _store.putRecords('orders', [order.toJson()]);
    _store.putRecords('payments', [_paymentToLocal(payment)]);
  }

  void _localDevImportExpense(Map<String, dynamic> expense, Cashier cashier, String shiftId) {
    final paidToCafe = expense['paid_to_cafe'] as bool;
    final row = ShiftExpense(
      id: Secrets.id(),
      shiftId: shiftId,
      cashierId: cashier.id,
      cashierName: cashier.name,
      paidToCafe: paidToCafe,
      paidToCashierId: paidToCafe ? null : cashier.id,
      paidToCashierName: paidToCafe ? '' : cashier.name,
      amount: double.parse(expense['amount'] as String),
      description: expense['description'] as String,
      createdAt: DateTime.parse(expense['created_at'] as String).toUtc(),
      kind: expense['kind'] as String? ?? 'cash_out',
      displayNumber: 'E-${_nextLocalNumber('expense').toString().padLeft(3, '0')}',
    );
    _store.putRecords('expenses', [_expenseToLocal(row)]);
  }

  /// Deletes every receipt, order and expense and restarts the numbering. Shifts stay. Tables that
  /// were waiting on a deleted order are freed.
  Map<String, dynamic> _localDevWipeLogs() {
    _store.transaction(() {
      for (final kind in const ['payments', 'orders', 'expenses']) {
        for (final row in _store.readRecords(kind)) {
          _store.deleteRecord(kind, row['id'] as String);
        }
      }
      _store.writeDoc('counters', <String, dynamic>{});
      for (final table in _tables) {
        table
          ..status = TableStatus.free
          ..guests = 0;
      }
      _saveLocalTables();
    });
    return {'ok': true};
  }

  /// Deletes every dish and category, and the carts that point at them. Receipts keep their text.
  Map<String, dynamic> _localDevWipeMenu() {
    _store.transaction(() {
      _store.writeDoc('menuItems', const <Object>[]);
      _store.writeDoc('categories', const <Object>[]);
      _store.writeDoc('carts', const <Object>[]);
    });
    return {'ok': true};
  }
}

String? _blankToNull(String? text) => text == null || text.isEmpty ? null : text;
