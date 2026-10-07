import 'dart:async';
import 'dart:convert';

import '../money.dart';
import 'outbox_store.dart';

/// Calls one server function and returns its JSON answer.
typedef RpcCall = Future<dynamic> Function(String name, Map<String, dynamic> params);

/// Receipt and order numbers a sale takes from this device's reserved blocks.
class ReservedNumber {
  const ReservedNumber({required this.yearMonth, required this.monthly, required this.dayKey, this.day});

  final String yearMonth;
  final int monthly;
  final String dayKey;

  /// Today's order number, or null when the reserved day block is from another day.
  final int? day;
}

/// A run of receipt numbers (and daily order numbers) the server set aside for this device.
class NumberBlock {
  NumberBlock({
    required this.yearMonth,
    required this.next,
    required this.last,
    required this.dayKey,
    required this.dayNext,
    required this.dayLast,
  });

  factory NumberBlock.fromJson(Map<String, dynamic> json) => NumberBlock(
    yearMonth: json['year_month'] as String,
    next: json['next'] as int,
    last: json['last'] as int,
    dayKey: json['day_key'] as String,
    dayNext: json['day_next'] as int,
    dayLast: json['day_last'] as int,
  );

  final String yearMonth;
  int next;
  final int last;
  final String dayKey;
  int dayNext;
  final int dayLast;

  int get remaining => last - next + 1;

  Map<String, dynamic> toJson() => {
    'year_month': yearMonth,
    'next': next,
    'last': last,
    'day_key': dayKey,
    'day_next': dayNext,
    'day_last': dayLast,
  };
}

/// Whether [error] means the server could not be reached, so the change should wait and retry.
bool isNetworkError(Object error) {
  if (error is TimeoutException) return true;
  final text = '$error';
  const signs = [
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Connection refused',
    'Connection closed',
    'Connection reset',
    'Connection timed out',
    'Network is unreachable',
    'HandshakeException',
    'XMLHttpRequest error',
    'Failed to fetch',
  ];
  return signs.any(text.contains);
}

/// Tripoli calendar day as the server writes it (YYMMDD).
String tripoliDayKey(DateTime instant) {
  final t = toTripoli(instant);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.year % 100)}${two(t.month)}${two(t.day)}';
}

/// Saves cashier changes on the device and uploads them, oldest first, whenever the server answers.
class OfflineSync {
  OfflineSync({required this.store, required this.rpc, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _blocksKey = 'number_blocks';
  static const _rpcByKind = {
    'takeout': 'sync_offline_takeout',
    'expense': 'sync_offline_expense',
    'shift_open': 'sync_offline_shift_open',
    'shift_close': 'sync_offline_shift_close',
  };

  final OutboxStore store;
  final RpcCall rpc;
  final DateTime Function() _clock;

  /// Last known state of the connection to the server.
  bool online = true;

  /// The cashier's session ended; uploads wait for the next sign-in.
  bool needsSignIn = false;
  bool flushing = false;
  int pendingCount = 0;
  int failedCount = 0;

  /// Items made while no cashier was signed in (offline start); they wait until one is chosen.
  int unassignedCount = 0;

  /// Called after anything above changes.
  void Function()? onChange;

  List<NumberBlock> _blocks = [];
  Future<void>? _flushRun;

  int get numbersLeft => _blocks.fold(0, (sum, block) => sum + block.remaining);

  Future<void> init() async {
    final saved = await store.readValue(_blocksKey);
    if (saved != null) {
      _blocks = [
        for (final raw in jsonDecode(saved) as List) NumberBlock.fromJson(Map<String, dynamic>.from(raw as Map)),
      ];
    }
    await _recount();
  }

  Future<void> _recount() async {
    final pending = await store.pending();
    pendingCount = pending.length;
    unassignedCount = pending.where(_unassigned).length;
    failedCount = (await store.failed()).length;
    onChange?.call();
  }

  static bool _unassigned(OutboxItem item) {
    final params = item.payload['params'];
    return params is Map && params.containsKey('p_cashier_id') && params['p_cashier_id'] == null;
  }

  /// Gives every unassigned item to [cashierId] so it can upload. Returns how many were assigned.
  Future<int> assignCashier(String cashierId, {String? cashierName}) async {
    var count = 0;
    for (final item in await store.pending()) {
      if (!_unassigned(item)) continue;
      final payload = Map<String, dynamic>.from(item.payload);
      payload['params'] = {...Map<String, dynamic>.from(payload['params'] as Map), 'p_cashier_id': cashierId};
      final local = payload['local'];
      if (local is Map) {
        final copy = Map<String, dynamic>.from(local);
        for (final key in ['payment', 'order', 'expense']) {
          final entry = copy[key];
          if (entry is Map) {
            copy[key] = {
              ...Map<String, dynamic>.from(entry),
              'cashierId': cashierId,
              if (cashierName != null && key != 'order') 'cashierName': cashierName,
            };
          }
        }
        payload['local'] = copy;
      }
      await store.updatePayload(item.id, payload);
      count++;
    }
    await _recount();
    return count;
  }

  void _setOnline(bool value) {
    if (online == value) return;
    online = value;
    onChange?.call();
  }

  Future<void> _saveBlocks() => store.writeValue(_blocksKey, jsonEncode([for (final b in _blocks) b.toJson()]));

  /// Reserves more numbers while online so the next sales can still be numbered offline.
  Future<void> topUp({int below = 15, int count = 50}) async {
    final month = tripoliDayKey(_clock()).substring(0, 4);
    final today = tripoliDayKey(_clock());
    final usable = _blocks.where((b) => b.remaining > 0 && b.yearMonth == month).fold(0, (sum, b) => sum + b.remaining);
    final dayLeft = _blocks.where((b) => b.dayKey == today).fold(0, (sum, b) => sum + (b.dayLast - b.dayNext + 1));
    if (usable >= below && dayLeft >= below) return;
    try {
      final raw = await rpc('reserve_receipt_numbers', {'p_count': count});
      final answer = Map<String, dynamic>.from(raw as Map);
      if (answer['ok'] != true) {
        if ('${answer['error']}'.contains('session expired')) _requireSignIn();
        return;
      }
      // Numbers from an earlier month are kept only until they run out; new sales prefer this month.
      _blocks.add(
        NumberBlock(
          yearMonth: answer['year_month'] as String,
          next: answer['first'] as int,
          last: answer['last'] as int,
          dayKey: answer['day_key'] as String,
          dayNext: answer['day_first'] as int,
          dayLast: answer['day_last'] as int,
        ),
      );
      _blocks.removeWhere((b) => b.remaining <= 0);
      await _saveBlocks();
      _setOnline(true);
    } catch (error) {
      if (isNetworkError(error)) _setOnline(false);
    }
  }

  /// Takes the next reserved receipt number, saving it as used before the sale is shown.
  Future<ReservedNumber?> takeNumber() async {
    _blocks.removeWhere((b) => b.remaining <= 0);
    if (_blocks.isEmpty) return null;
    final today = tripoliDayKey(_clock());
    final month = today.substring(0, 4);
    final block = _blocks.firstWhere((b) => b.yearMonth == month, orElse: () => _blocks.first);
    final monthly = block.next++;
    int? day;
    final dayBlock = _blocks.where((b) => b.dayKey == today && b.dayNext <= b.dayLast).firstOrNull;
    if (dayBlock != null) day = dayBlock.dayNext++;
    await _saveBlocks();
    return ReservedNumber(yearMonth: block.yearMonth, monthly: monthly, dayKey: today, day: day);
  }

  Future<void> enqueue(OutboxItem item) async {
    await store.add(item);
    await _recount();
  }

  Future<List<OutboxItem>> pendingItems() => store.pending();

  Future<List<OutboxItem>> failedItems() => store.failed();

  /// Tells the server a cashier is here, which keeps guest ordering open. Returns whether it answered.
  Future<bool> heartbeat() async {
    try {
      final raw = await rpc('cashier_heartbeat', const {});
      final ok = raw is Map && raw['ok'] == true;
      if (!ok && raw is Map && '${raw['error']}'.contains('session expired')) _requireSignIn();
      _setOnline(true);
      return ok;
    } catch (error) {
      if (isNetworkError(error)) _setOnline(false);
      return false;
    }
  }

  /// Uploads waiting changes in order. Stops at the first connection problem so order is kept.
  /// Returns how many were uploaded.
  Future<int> flush() {
    final running = _flushRun;
    if (running != null) return running.then((_) => 0);
    final completer = Completer<int>();
    _flushRun = completer.future.then((_) {});
    _flush().then(completer.complete, onError: completer.completeError).whenComplete(() => _flushRun = null);
    return completer.future;
  }

  Future<int> _flush() async {
    if (needsSignIn) return 0;
    flushing = true;
    onChange?.call();
    var uploaded = 0;
    try {
      for (final item in await store.pending()) {
        // Keep order: nothing after an unassigned item goes up before it is given a cashier.
        if (_unassigned(item)) break;
        final name = _rpcByKind[item.kind];
        if (name == null) {
          await store.markFailed(item.id, 'unknown kind ${item.kind}');
          continue;
        }
        final params = Map<String, dynamic>.from(item.payload['params'] as Map);
        try {
          final raw = await rpc(name, params);
          final answer = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'ok': false, 'error': 'bad answer'};
          _setOnline(true);
          if (answer['ok'] == true) {
            await store.remove(item.id);
            uploaded++;
            continue;
          }
          final error = '${answer['error'] ?? 'refused'}';
          if (error.contains('session expired')) {
            _requireSignIn();
            await store.noteAttempt(item.id, error);
            break;
          }
          await store.markFailed(item.id, error);
        } catch (error) {
          if (isNetworkError(error)) {
            _setOnline(false);
            await store.noteAttempt(item.id, '$error');
            break;
          }
          if (_isServerBusy(error)) {
            await store.noteAttempt(item.id, '$error');
            break;
          }
          // The server ran the upload and refused it (bad data); keep it aside for review.
          await store.markFailed(item.id, '$error');
        }
      }
    } finally {
      flushing = false;
      await _recount();
    }
    return uploaded;
  }

  bool _isServerBusy(Object error) {
    final text = '$error';
    return text.contains('503') || text.contains('502') || text.contains('504') || text.contains('PGRST000') ||
        text.contains('PGRST001') || text.contains('PGRST002');
  }

  /// Puts a refused item back in the queue to try again (after the cause was fixed).
  Future<void> retryFailed() async {
    for (final item in await store.failed()) {
      await store.remove(item.id);
      await store.add(
        OutboxItem(id: item.id, kind: item.kind, payload: item.payload, createdAt: item.createdAt),
      );
    }
    await _recount();
  }

  /// The server says the cashier session ended; tells the screen so it can ask for a sign-in.
  void _requireSignIn() {
    if (needsSignIn) return;
    needsSignIn = true;
    onChange?.call();
  }

  /// Clears the "sign in again" stop after a new cashier session starts.
  void signedIn() {
    needsSignIn = false;
    onChange?.call();
  }
}
