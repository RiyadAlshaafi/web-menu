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

/// Receipt numbers for one month and/or daily order numbers for one day that the server set
/// aside for this device. Either range may be missing: each is reserved only when running short.
class NumberBlock {
  NumberBlock({
    required this.yearMonth,
    this.next,
    this.last,
    this.dayKey,
    this.dayNext,
    this.dayLast,
  });

  factory NumberBlock.fromJson(Map<String, dynamic> json) => NumberBlock(
    yearMonth: json['year_month'] as String,
    next: json['next'] as int?,
    last: json['last'] as int?,
    dayKey: json['day_key'] as String?,
    dayNext: json['day_next'] as int?,
    dayLast: json['day_last'] as int?,
  );

  final String yearMonth;
  int? next;
  final int? last;
  final String? dayKey;
  int? dayNext;
  final int? dayLast;

  /// Receipt numbers left in this block.
  int get remaining => next == null || last == null ? 0 : last! - next! + 1;

  /// Order numbers left for [dayKey].
  int get dayRemaining => dayNext == null || dayLast == null ? 0 : dayLast! - dayNext! + 1;

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

/// What to do with an upload that threw instead of answering.
enum UploadError {
  /// The server could not be reached: wait and retry, keeping order.
  network,

  /// The sign-in behind the upload ended: ask for a sign-in, keep the item.
  signIn,

  /// The server already has this change (a retry overlapped the first upload): it is done.
  duplicate,

  /// The server refused the data itself; a retry would get the same answer.
  refused,

  /// Anything else (server busy, unknown error): keep the item and retry later.
  retryLater,
}

/// Sorts an upload error so a saved sale is never set aside just because something went wrong.
UploadError classifyUploadError(Object error) {
  if (isNetworkError(error)) return UploadError.network;
  final text = '$error';
  final code = RegExp(r'code: ([0-9A-Z]+)').firstMatch(text)?.group(1);
  if (code == 'PGRST301' || code == 'PGRST303' || text.contains('JWT expired')) {
    return UploadError.signIn;
  }
  if (code == '23505' && text.contains('client_id')) return UploadError.duplicate;
  if (code != null && (code.startsWith('22') || code.startsWith('23') || code == 'P0001')) return UploadError.refused;
  return UploadError.retryLater;
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

  /// This app's version, sent with the heartbeat so the developer screen sees every till's version.
  String appVersion = '';

  /// The oldest app version the server still accepts (from the last heartbeat), or null if unknown.
  String? minAppVersion;

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
    unassignedCount = pending.where((item) => _unassigned(item) && item.kind != 'shift_open').length;
    failedCount = (await store.failed()).length;
    onChange?.call();
  }

  static bool _unassigned(OutboxItem item) {
    final params = item.payload['params'];
    return params is Map && params.containsKey('p_cashier_id') && params['p_cashier_id'] == null;
  }

  /// Removes offline shifts that never got a cashier and hold no sales or expenses, so an empty
  /// offline session can't hold up the queue. Returns how many were removed.
  Future<int> dropIdleUnassignedShifts() async {
    final pending = await store.pending();
    if (pending.any((item) => _unassigned(item) && item.kind != 'shift_open')) return 0;
    var removed = 0;
    for (final item in pending.where((item) => _unassigned(item) && item.kind == 'shift_open')) {
      await store.remove(item.id);
      removed++;
    }
    if (removed > 0) await _recount();
    return removed;
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
        for (final key in ['payment', 'order', 'expense', 'shift']) {
          final entry = copy[key];
          if (entry is Map) {
            copy[key] = {
              ...Map<String, dynamic>.from(entry),
              'cashierId': cashierId,
              if (cashierName != null && key != 'order' && key != 'shift') 'cashierName': cashierName,
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

  /// Reserves more numbers while online so the next sales can still be numbered offline. Asks
  /// only for what is short: [monthCount] receipt numbers when fewer than [monthBelow] are left
  /// this month, and [dayCount] order numbers when fewer than [dayBelow] are left today. Small day
  /// blocks keep the shared daily order numbers close together across tills.
  Future<void> topUp({int monthBelow = 15, int monthCount = 50, int dayBelow = 3, int dayCount = 10}) async {
    final today = tripoliDayKey(_clock());
    final month = today.substring(0, 4);
    final monthLeft = _blocks.where((b) => b.yearMonth == month).fold(0, (sum, b) => sum + b.remaining);
    final dayLeft = _blocks.where((b) => b.dayKey == today).fold(0, (sum, b) => sum + b.dayRemaining);
    final wantMonth = monthLeft < monthBelow ? monthCount : 0;
    final wantDay = dayLeft < dayBelow ? dayCount : 0;
    if (wantMonth == 0 && wantDay == 0) return;
    try {
      final raw = await rpc('reserve_receipt_numbers', {'p_month_count': wantMonth, 'p_day_count': wantDay});
      final answer = Map<String, dynamic>.from(raw as Map);
      if (answer['ok'] != true) {
        if ('${answer['error']}'.contains('session expired')) _requireSignIn();
        return;
      }
      // Numbers from an earlier month are kept only until they run out; new sales prefer this month.
      _blocks.add(
        NumberBlock(
          yearMonth: answer['year_month'] as String,
          next: answer['first'] as int?,
          last: answer['last'] as int?,
          dayKey: answer['day_key'] as String?,
          dayNext: answer['day_first'] as int?,
          dayLast: answer['day_last'] as int?,
        ),
      );
      _dropSpent(today);
      await _saveBlocks();
      _setOnline(true);
    } catch (error) {
      if (isNetworkError(error)) _setOnline(false);
    }
  }

  /// Forgets blocks with nothing left to give (day numbers from an earlier day count as nothing).
  void _dropSpent(String today) {
    _blocks.removeWhere((b) => b.remaining <= 0 && (b.dayKey != today || b.dayRemaining <= 0));
  }

  /// Takes the next reserved receipt number, saving it as used before the sale is shown.
  Future<ReservedNumber?> takeNumber() async {
    final today = tripoliDayKey(_clock());
    final month = today.substring(0, 4);
    _dropSpent(today);
    final monthly = _blocks.where((b) => b.remaining > 0).toList();
    if (monthly.isEmpty) return null;
    final block = monthly.firstWhere((b) => b.yearMonth == month, orElse: () => monthly.first);
    final number = block.next!;
    block.next = number + 1;
    int? day;
    final dayBlock = _blocks.where((b) => b.dayKey == today && b.dayRemaining > 0).firstOrNull;
    if (dayBlock != null) {
      day = dayBlock.dayNext!;
      dayBlock.dayNext = day + 1;
    }
    _dropSpent(today);
    await _saveBlocks();
    return ReservedNumber(yearMonth: block.yearMonth, monthly: number, dayKey: today, day: day);
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
      final raw = await rpc('cashier_heartbeat_v2', {'p_app_version': appVersion});
      final ok = raw is Map && raw['ok'] == true;
      if (ok && raw['min_app_version'] is String && raw['min_app_version'] != minAppVersion) {
        minAppVersion = raw['min_app_version'] as String;
        onChange?.call();
      }
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
            await _done(item);
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
          switch (classifyUploadError(error)) {
            case UploadError.network:
              _setOnline(false);
              await store.noteAttempt(item.id, '$error');
            case UploadError.signIn:
              _requireSignIn();
              await store.noteAttempt(item.id, '$error');
            case UploadError.duplicate:
              await _done(item);
              uploaded++;
              continue;
            case UploadError.refused:
              // The server ran the upload and refused the data; keep it aside for review.
              await store.markFailed(item.id, '$error');
              continue;
            case UploadError.retryLater:
              await store.noteAttempt(item.id, '$error');
          }
          // Stop here so later items never go up before this one.
          break;
        }
      }
    } finally {
      flushing = false;
      await _recount();
    }
    return uploaded;
  }

  /// The server has [item]: drop it from the queue and remember it, so it can be confirmed again
  /// before an app update.
  Future<void> _done(OutboxItem item) async {
    final amount = switch (item.kind) {
      'takeout' => ((item.payload['local'] as Map?)?['payment'] as Map?)?['totalDue'],
      'expense' => (item.payload['params'] as Map?)?['p_amount'],
      _ => null,
    };
    await store.remove(item.id);
    if (amount is num) {
      await store.recordSent(
        SentRecord(id: item.id, kind: item.kind, amount: amount.toDouble(), sentAt: _clock().toUtc()),
      );
    }
  }

  /// Puts refused items back in the queue to try again (after the cause was fixed). Each keeps
  /// its original place, so a retried sale still uploads before a later shift close.
  Future<void> retryFailed() async {
    await store.requeueFailed();
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
