import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../lan/lan_protocol.dart';
import '../models/models.dart';
import '../theme/cafe_theme.dart';
import 'hub_client.dart';

enum WaiterPhase { starting, searching, choose, pairing, denied, noAnswer, ready }

enum SendOutcome { sent, unavailable, paused, failed }

/// One table as the waiter sees it.
class WaiterTable {
  const WaiterTable({
    required this.id,
    required this.number,
    required this.status,
    required this.items,
    required this.total,
    required this.waiting,
  });

  final String id;
  final String number;
  final TableStatus status;
  final int items;
  final double total;

  /// Waiter orders for this table the cashier has not answered yet.
  final int waiting;

  factory WaiterTable.fromJson(Map<String, dynamic> json) => WaiterTable(
    id: json['id'] as String,
    number: json['number'] as String? ?? '',
    status: TableStatus.values.firstWhere((value) => value.name == json['status'], orElse: () => TableStatus.free),
    items: (json['items'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    waiting: (json['waiting'] as num?)?.toInt() ?? 0,
  );
}

/// An order this phone sent, and what the cashier did with it.
class SentOrder {
  const SentOrder({required this.id, required this.tableNumber, required this.status, required this.items});

  final String id;
  final String tableNumber;
  final WaiterOrderStatus status;
  final int items;

  factory SentOrder.fromJson(Map<String, dynamic> json) => SentOrder(
    id: json['id'] as String,
    tableNumber: json['tableNumber'] as String? ?? '',
    status: WaiterOrderStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => WaiterOrderStatus.pending,
    ),
    items: (json['items'] as num?)?.toInt() ?? 0,
  );
}

/// A dish in the waiter's cart: which dish, how many, and which options are on (null: as it comes).
class WaiterLine {
  const WaiterLine({required this.item, required this.qty, this.onIds});

  final MenuItem item;
  final int qty;
  final Set<String>? onIds;

  OrderLine priced(String locale) => item.lineWith(locale: locale, onIds: onIds, qty: qty);

  String get key => '${item.id}#${onIds == null ? '' : (onIds!.toList()..sort()).join(',')}';

  WaiterLine withQty(int value) => WaiterLine(item: item, qty: value, onIds: onIds);
}

/// Everything the waiter phone knows: which till it talks to, the menu, the floor and the carts.
class WaiterController extends ChangeNotifier {
  WaiterController(this.client, {this.pollEvery = const Duration(seconds: 5)});

  final HubClient client;
  final Duration pollEvery;

  static const _deviceIdKey = 'waiter_device_id';
  static const _nameKey = 'waiter_device_name';
  static const _hubKey = 'waiter_hub';
  static const _tokenKey = 'waiter_token';
  static const _localeKey = 'waiter_locale';
  static const _brandKey = 'waiter_brand';

  /// Languages the waiter can pick on this phone, whatever language the till uses.
  static const languages = {'en': 'English', 'ar': 'العربية'};

  /// After this many failed refreshes in a row the phone looks for its till again, in case the
  /// PC got a new Wi-Fi address.
  static const _failuresBeforeSearch = 3;

  WaiterPhase phase = WaiterPhase.starting;
  String locale = 'en';

  /// The admin's colours from the till, so the phone looks like the rest of the cafe's system.
  CafeSurfaces surfaces = CafeSurfaces.defaults;
  String deviceName = '';
  String _deviceId = '';
  FoundHub? hub;
  String? _token;
  List<FoundHub> found = const [];
  List<MenuCategory> categories = const [];
  List<MenuItem> items = const [];
  List<WaiterTable> tables = const [];
  List<SentOrder> sentOrders = const [];
  bool connected = true;

  /// The till has no internet, so it cannot take table orders until it is back.
  bool ordersPaused = false;
  bool sending = false;
  int _failures = 0;
  Timer? _poll;
  final Map<String, List<WaiterLine>> _carts = {};

  CafeMoney get money => CafeMoney(locale);

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);
    locale = languages.containsKey(saved) ? saved! : 'en';
    _applyBrand(prefs.getString(_brandKey));
    deviceName = prefs.getString(_nameKey) ?? '';
    _deviceId = prefs.getString(_deviceIdKey) ?? '';
    if (_deviceId.isEmpty) {
      final random = Random.secure();
      _deviceId = List<String>.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_deviceIdKey, _deviceId);
    }
    final savedHub = prefs.getString(_hubKey);
    _token = prefs.getString(_tokenKey);
    if (savedHub != null && _token != null) {
      try {
        final json = jsonDecode(savedHub) as Map<String, dynamic>;
        hub = FoundHub(
          host: json['host'] as String,
          port: json['port'] as int,
          hubId: json['hubId'] as String,
          cafeName: json['cafe'] as String? ?? 'Tawla',
        );
      } on FormatException {
        hub = null;
      } on TypeError {
        hub = null;
      }
    }
    if (hub != null) {
      _becomeReady();
      return;
    }
    await search();
  }

  Future<void> setLocale(String value) async {
    if (!languages.containsKey(value) || value == locale) return;
    locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, value);
  }

  Future<void> search() async {
    phase = WaiterPhase.searching;
    notifyListeners();
    found = await client.discover();
    phase = WaiterPhase.choose;
    notifyListeners();
  }

  /// Asks [target] to allow this phone; the cashier answers on the till.
  Future<void> connect(FoundHub target, {required String name}) async {
    deviceName = name.trim();
    phase = WaiterPhase.pairing;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, deviceName);
    final reply = await client.send(
      target.host,
      target.port,
      'POST',
      '/pair',
      body: {'deviceId': _deviceId, 'deviceName': deviceName.isEmpty ? 'Waiter phone' : deviceName},
      timeout: LanProtocol.pairWait + const Duration(seconds: 10),
    );
    final token = reply.body['token'];
    if (!reply.ok || token is! String) {
      phase = reply.status == 403 ? WaiterPhase.denied : WaiterPhase.noAnswer;
      notifyListeners();
      return;
    }
    final hubId = reply.body['hubId'];
    final cafe = reply.body['cafe'];
    hub = FoundHub(
      host: target.host,
      port: target.port,
      hubId: hubId is String ? hubId : target.hubId,
      cafeName: cafe is String ? cafe : target.cafeName,
    );
    _token = token;
    await _saveHub();
    await prefs.setString(_tokenKey, token);
    _becomeReady();
  }

  /// For a Wi-Fi that blocks the search: the waiter types the till's address.
  Future<void> connectToAddress(String address, {required String name}) {
    final host = address.trim();
    return connect(
      FoundHub(host: host, port: LanProtocol.httpPort, hubId: '', cafeName: host),
      name: name,
    );
  }

  /// Leaves this till; the phone must be allowed again to come back.
  Future<void> forgetTill() async {
    _poll?.cancel();
    hub = null;
    _token = null;
    _carts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hubKey);
    await prefs.remove(_tokenKey);
    await search();
  }

  Future<void> _saveHub() async {
    final current = hub;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _hubKey,
      jsonEncode({'host': current.host, 'port': current.port, 'hubId': current.hubId, 'cafe': current.cafeName}),
    );
  }

  void _becomeReady() {
    phase = WaiterPhase.ready;
    connected = true;
    notifyListeners();
    _poll?.cancel();
    _poll = Timer.periodic(pollEvery, (_) => refresh());
    unawaited(refresh(withMenu: true));
  }

  Future<HubReply> _call(String method, String path, {Map<String, dynamic>? body}) async {
    final current = hub;
    if (current == null) return const HubReply(0);
    final reply = await client.send(current.host, current.port, method, path, token: _token, body: body);
    if (reply.status == 401) {
      // The cashier removed this phone.
      await forgetTill();
    } else if (reply.unreachable) {
      _markOffline();
    } else {
      _failures = 0;
      if (!connected) {
        connected = true;
        notifyListeners();
      }
    }
    return reply;
  }

  void _markOffline() {
    _failures++;
    if (connected) {
      connected = false;
      notifyListeners();
    }
    if (_failures % _failuresBeforeSearch == 0) unawaited(_findMovedTill());
  }

  /// The PC may have a new address after a restart; find it again by its id.
  Future<void> _findMovedTill() async {
    final current = hub;
    if (current == null || current.hubId.isEmpty) return;
    final again = await client.discover();
    final match = again.where((found) => found.hubId == current.hubId).firstOrNull;
    if (match == null || match.host == current.host) return;
    hub = FoundHub(host: match.host, port: match.port, hubId: current.hubId, cafeName: match.cafeName);
    await _saveHub();
    await refresh(withMenu: items.isEmpty);
  }

  Future<void> refresh({bool withMenu = false}) async {
    if (phase != WaiterPhase.ready) return;
    if (withMenu || items.isEmpty) await _loadMenu();
    final reply = await _call('GET', '/tables');
    if (!reply.ok) return;
    tables = [
      for (final table in reply.body['tables'] as List? ?? const [])
        WaiterTable.fromJson(Map<String, dynamic>.from(table as Map)),
    ];
    ordersPaused = reply.body['paused'] == true;
    sentOrders = [
      for (final order in reply.body['orders'] as List? ?? const [])
        SentOrder.fromJson(Map<String, dynamic>.from(order as Map)),
    ];
    notifyListeners();
  }

  Future<void> _loadMenu() async {
    final reply = await _call('GET', '/menu');
    if (!reply.ok) return;
    categories = [
      for (final category in reply.body['categories'] as List? ?? const [])
        MenuCategory.fromJson(Map<String, dynamic>.from(category as Map)),
    ];
    items = [
      for (final item in reply.body['items'] as List? ?? const [])
        MenuItem.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    final brand = reply.body['brand'];
    if (brand is Map) {
      final encoded = jsonEncode({
        for (final entry in brand.entries)
          if (entry.key is String && entry.value is String) entry.key: entry.value,
      });
      _applyBrand(encoded);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_brandKey, encoded);
    }
    final cafe = reply.body['cafe'];
    final current = hub;
    if (cafe is String && current != null && cafe != current.cafeName) {
      hub = FoundHub(host: current.host, port: current.port, hubId: current.hubId, cafeName: cafe);
      await _saveHub();
    }
    _dropGoneDishes();
    notifyListeners();
  }

  /// Reads the saved or fresh brand colours; anything unreadable keeps the default look.
  void _applyBrand(String? encoded) {
    if (encoded == null) return;
    try {
      final json = jsonDecode(encoded);
      if (json is! Map<String, dynamic>) return;
      final next = CafeSurfaces.fromCafe(json);
      bool same(Color a, Color b) => a.toARGB32() == b.toARGB32();
      // A new object only when a colour changed, so the app does not rebuild its theme every poll.
      if (same(next.header, surfaces.header) &&
          same(next.sidebar, surfaces.sidebar) &&
          same(next.background, surfaces.background) &&
          same(next.button, surfaces.button)) {
        return;
      }
      surfaces = next;
    } on FormatException {
      return;
    }
  }

  /// Cart lines whose dish left the menu or sold out are removed, so a send never fails on them;
  /// the rest take the dish's new price.
  void _dropGoneDishes() {
    final byId = {for (final item in items) item.id: item};
    for (final entry in _carts.entries) {
      final kept = [
        for (final line in entry.value)
          if (byId[line.item.id] case final fresh? when !fresh.soldOut)
            WaiterLine(item: fresh, qty: line.qty, onIds: line.onIds),
      ];
      entry.value
        ..clear()
        ..addAll(kept);
    }
  }

  WaiterTable? tableById(String id) => tables.where((table) => table.id == id).firstOrNull;

  List<WaiterLine> cartFor(String tableId) => List.unmodifiable(_carts[tableId] ?? const []);

  int cartCount(String tableId) => cartFor(tableId).fold(0, (sum, line) => sum + line.qty);

  double cartTotal(String tableId) => cartFor(tableId).fold(0, (sum, line) => sum + line.priced(locale).total);

  /// How many of [item] are in the table's cart, across option variants.
  int dishCount(String tableId, String itemId) =>
      cartFor(tableId).where((line) => line.item.id == itemId).fold(0, (sum, line) => sum + line.qty);

  void addDish(String tableId, MenuItem item, {Set<String>? onIds}) {
    if (item.soldOut || !item.canSellMore(dishCount(tableId, item.id))) return;
    final lines = _carts.putIfAbsent(tableId, () => []);
    final added = WaiterLine(item: item, qty: 1, onIds: onIds);
    final index = lines.indexWhere((line) => line.key == added.key);
    if (index < 0) {
      lines.add(added);
    } else if (lines[index].qty < LanProtocol.maxDishQty) {
      lines[index] = lines[index].withQty(lines[index].qty + 1);
    }
    notifyListeners();
  }

  void setLineQty(String tableId, String key, int qty) {
    final lines = _carts[tableId];
    if (lines == null) return;
    final index = lines.indexWhere((line) => line.key == key);
    if (index < 0) return;
    if (qty <= 0) {
      lines.removeAt(index);
    } else {
      final line = lines[index];
      final others = dishCount(tableId, line.item.id) - line.qty;
      final most = line.item.stockQty == null ? LanProtocol.maxDishQty : line.item.stockQty! - others;
      lines[index] = line.withQty(min(qty, min(most, LanProtocol.maxDishQty)));
    }
    notifyListeners();
  }

  /// Takes one of [itemId] off: the newest line of that dish first.
  void removeOneDish(String tableId, String itemId) {
    final lines = _carts[tableId];
    if (lines == null) return;
    final index = lines.lastIndexWhere((line) => line.item.id == itemId);
    if (index < 0) return;
    setLineQty(tableId, lines[index].key, lines[index].qty - 1);
  }

  Future<SendOutcome> sendOrder(String tableId) async {
    final lines = cartFor(tableId);
    if (lines.isEmpty || sending) return SendOutcome.failed;
    sending = true;
    notifyListeners();
    try {
      final reply = await _call(
        'POST',
        '/order',
        body: {
          'tableId': tableId,
          'lines': [
            for (final line in lines)
              {'itemId': line.item.id, 'qty': line.qty, if (line.onIds != null) 'onIds': line.onIds!.toList()},
          ],
        },
      );
      if (reply.ok) {
        _carts.remove(tableId);
        unawaited(refresh());
        return SendOutcome.sent;
      }
      if (reply.status == 409) {
        await _loadMenu();
        return SendOutcome.unavailable;
      }
      if (reply.body['error'] == 'orders_paused') {
        ordersPaused = true;
        return SendOutcome.paused;
      }
      return SendOutcome.failed;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
