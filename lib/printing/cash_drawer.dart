import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/report_error.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import 'cash_drawer_stub.dart' if (dart.library.io) 'cash_drawer_io.dart' as impl;
import 'kitchen_ticket.dart';

/// The cash drawer plugged into this till's cashier (receipt) printer. When switched on, it opens
/// after each cash sale. The switch belongs to this device, like its printers. Windows till only.
class CashDrawer {
  static const _enabledKey = 'openCashDrawer';

  /// ESC p 0 25 250: the standard ESC/POS pulse that opens a drawer on the printer's drawer port.
  static const openCommand = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  /// Sends raw bytes to a printer by its name; false when they did not go. Replaced in tests.
  @visibleForTesting
  static Future<bool> Function(String printer, List<int> bytes) sendRaw = impl.sendRaw;

  static Future<bool> enabled() async => (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  static Future<void> setEnabled(bool value) async => (await SharedPreferences.getInstance()).setBool(_enabledKey, value);

  /// Opens the drawer now; false when this till has no cashier printer or the printer refused.
  static Future<bool> open() async {
    final printer = (await TillPrinters.settings()).receipt;
    if (printer == null) return false;
    try {
      return await sendRaw(printer, openCommand);
    } catch (error, stackTrace) {
      reportError('open cash drawer on $printer', error, stackTrace);
      return false;
    }
  }

  /// After a sale: opens the drawer when it is switched on and [payment] was paid in cash.
  /// False only when it should have opened and did not.
  static Future<bool> afterSale(CafeStore store, Payment payment) async {
    if (!await enabled() || !store.isCashSale(payment)) return true;
    return open();
  }
}
