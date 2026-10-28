import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'lan_protocol.dart';
import 'waiter_devices.dart';

/// What the hub needs from the cashier's app: the menu, the floor and a way to send dishes.
abstract interface class WaiterHubHost {
  String get cafeName;
  String get locale;
  List<MenuCategory> get categories;
  List<MenuItem> get menuItems;

  /// Tables a waiter may order for (not archived, not the takeout counter).
  List<CafeTable> get waiterTables;
  CafeOrder? openOrderFor(String tableId);

  /// The admin's brand colours (header, sidebar, background, button) as hex, so phones match the till.
  Map<String, String> get brandColors;

  /// Whether the till can keep an order waiting for the cashier's Accept, the way a guest's QR
  /// order waits. The offline till cannot, so its waiter orders wait on the hub instead.
  bool get holdsOrders;

  /// Whether the till can put dishes on a table's bill right now. The online version cannot while
  /// it has no internet (it sells takeout only then), so waiter orders pause.
  bool get takesTableOrders;

  /// Where a till order is now; null when it is gone.
  OrderStatus? tillOrderStatus(String orderId);

  /// Sends [lines] to [tableId]'s bill. With [forAccept] the order arrives like a guest's QR
  /// order: it rings, shows as a new order and waits for the cashier's Accept.
  Future<({String? error, String? orderId})> sendWaiterLines(
    String tableId,
    List<OrderLine> lines, {
    bool forAccept = false,
  });

  /// Rings the new-order sound on the till.
  void ringNewOrder();

  /// Guest calls (staff or bill) nobody has answered yet.
  List<StaffCall> get openCalls;

  /// A dish for [tableId] is cooked and waits to be served.
  bool hasReadyFood(String tableId);
}

class HubRequest {
  const HubRequest({required this.method, required this.path, this.token, this.body});

  final String method;
  final String path;
  final String? token;

  /// The parsed JSON body; null when there was none or it was not a JSON object.
  final Map<String, dynamic>? body;
}

class HubResponse {
  const HubResponse(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  static HubResponse error(int status, String code) => HubResponse(status, {'error': code});
}

/// A phone asking to be allowed. It waits until the cashier answers or [LanProtocol.pairWait] ends.
class PairRequest {
  PairRequest({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;
  final Completer<bool> _answer = Completer<bool>();
}

/// An order a waiter sent; it waits on the till until the cashier accepts or refuses it.
class WaiterOrder {
  WaiterOrder({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.tableId,
    required this.tableNumber,
    required this.lines,
    required this.createdAt,
  });

  final String id;
  final String deviceId;
  final String deviceName;
  final String tableId;
  final String tableNumber;
  final List<OrderLine> lines;
  final DateTime createdAt;
  WaiterOrderStatus status = WaiterOrderStatus.pending;

  /// The till order it went into when it waits in the cashier's new-order list; null while it
  /// waits on the hub (offline till).
  String? tillOrderId;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.qty);
  double get total => lines.fold(0, (sum, line) => sum + line.total);
}

/// The cashier side of the waiter phones: who is allowed, which orders wait, and the answers
/// to every phone request. It has no sockets of its own (see hub_server.dart), so tests can
/// call [handle] directly.
class WaiterHub extends ChangeNotifier {
  WaiterHub({required this.host, required this.deviceStore, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      hubId = _randomId();

  final WaiterHubHost host;
  final WaiterDeviceStore deviceStore;
  final DateTime Function() _clock;

  /// Tells phones apart from another cafe's PC on the same Wi-Fi.
  final String hubId;

  /// Most phones that may wait for an answer at once, so nobody can flood the till with asks.
  static const maxPairRequests = 3;

  /// Old orders kept so phones can see what happened to theirs.
  static const keptOrders = 100;

  List<WaiterDevice> _devices = const [];
  final List<PairRequest> _pairRequests = [];
  final List<WaiterOrder> _orders = [];
  final Set<String> _accepting = {};
  bool _loaded = false;

  List<WaiterDevice> get devices => List.unmodifiable(_devices);
  List<PairRequest> get pairRequests => List.unmodifiable(_pairRequests);

  /// Orders waiting on the hub's own banner; orders already on the till wait in its new-order list.
  List<WaiterOrder> get pendingOrders => List.unmodifiable(
    _orders.where((order) => order.status == WaiterOrderStatus.pending && order.tillOrderId == null),
  );
  bool isAccepting(String orderId) => _accepting.contains(orderId);

  static String _randomId() {
    final random = Random.secure();
    return List<String>.generate(12, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  Future<void> load() async {
    if (_loaded) return;
    _devices = await deviceStore.load();
    _loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> discoveryAnswer() => {
    'tawla': 1,
    'cafe': host.cafeName,
    'port': LanProtocol.httpPort,
    'hubId': hubId,
  };

  Future<HubResponse> handle(HubRequest request) async {
    await load();
    final route = '${request.method} ${request.path}';
    if (route == 'POST /pair') return _pair(request.body);
    final device = _deviceFor(request.token);
    if (device == null) return HubResponse.error(401, 'not_allowed');
    return switch (route) {
      'GET /menu' => HubResponse(200, _menu()),
      'GET /tables' => HubResponse(200, _tables(device)),
      'POST /order' => await _order(device, request.body),
      _ => HubResponse.error(404, 'not_found'),
    };
  }

  WaiterDevice? _deviceFor(String? token) {
    if (token == null || token.isEmpty) return null;
    final hash = WaiterTokens.hash(token);
    final index = _devices.indexWhere((device) => device.tokenHash == hash);
    if (index < 0) return null;
    final seen = _devices[index].seenAt(_clock());
    _devices = [..._devices]..[index] = seen;
    return seen;
  }

  Future<HubResponse> _pair(Map<String, dynamic>? body) async {
    final deviceId = body?['deviceId'];
    final rawName = body?['deviceName'];
    if (deviceId is! String || deviceId.isEmpty || deviceId.length > 64) {
      return HubResponse.error(400, 'bad_request');
    }
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim().substring(0, min(rawName.trim().length, 40))
        : 'Waiter phone';
    final waiting = _pairRequests.where((request) => request.deviceId == deviceId).firstOrNull;
    if (waiting == null && _pairRequests.length >= maxPairRequests) return HubResponse.error(429, 'busy');
    final request = waiting ?? PairRequest(deviceId: deviceId, deviceName: name);
    if (waiting == null) {
      _pairRequests.add(request);
      host.ringNewOrder();
      notifyListeners();
    }
    final bool allowed;
    try {
      allowed = await request._answer.future.timeout(LanProtocol.pairWait);
    } on TimeoutException {
      _dropPairRequest(request);
      return HubResponse.error(408, 'no_answer');
    }
    if (!allowed) return HubResponse.error(403, 'denied');
    final token = WaiterTokens.create();
    _devices = [
      for (final device in _devices)
        if (device.id != deviceId) device,
      WaiterDevice(id: deviceId, name: name, tokenHash: WaiterTokens.hash(token), lastSeen: _clock()),
    ];
    await deviceStore.save(_devices);
    notifyListeners();
    return HubResponse(200, {'token': token, 'hubId': hubId, 'cafe': host.cafeName});
  }

  void _dropPairRequest(PairRequest request) {
    if (_pairRequests.remove(request)) notifyListeners();
  }

  void answerPair(PairRequest request, {required bool allow}) {
    _dropPairRequest(request);
    if (!request._answer.isCompleted) request._answer.complete(allow);
  }

  Future<void> forget(String deviceId) async {
    _devices = [
      for (final device in _devices)
        if (device.id != deviceId) device,
    ];
    await deviceStore.save(_devices);
    notifyListeners();
  }

  Map<String, dynamic> _menu() {
    final visible = [
      for (final category in host.categories)
        if (category.visible) category,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final ids = {for (final category in visible) category.id};
    final items = [
      for (final item in host.menuItems)
        if (item.available && ids.contains(item.categoryId)) item,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return {
      'cafe': host.cafeName,
      'brand': host.brandColors,
      'categories': [
        for (final category in visible)
          {'id': category.id, 'nameEn': category.nameEn, 'nameAr': category.nameAr, 'sortOrder': category.sortOrder},
      ],
      // No photos: a dish picture can be a large data URL and the waiter screen does not show it.
      'items': [
        for (final item in items)
          {
            'id': item.id,
            'nameIt': item.nameIt,
            'nameEn': item.nameEn,
            'price': item.price,
            'categoryId': item.categoryId,
            'soldOut': item.soldOut || item.stockQty == 0,
            'sortOrder': item.sortOrder,
            'discountPercent': item.discountPercent,
            'discountApplied': item.discountApplied,
            'options': [for (final option in item.options) option.toJson()],
            if (item.stockQty != null) 'stockQty': item.stockQty,
          },
      ],
    };
  }

  /// A till-held order counts as accepted once the cashier moved it past "received".
  void _followTillOrders() {
    for (final order in _orders) {
      final id = order.tillOrderId;
      if (id == null || order.status != WaiterOrderStatus.pending) continue;
      final status = host.tillOrderStatus(id);
      if (status != OrderStatus.received) order.status = WaiterOrderStatus.accepted;
    }
  }

  Map<String, dynamic> _tables(WaiterDevice device) {
    _followTillOrders();
    final pending = _orders.where((order) => order.status == WaiterOrderStatus.pending).toList();
    final calls = host.openCalls;
    return {
      'paused': !host.takesTableOrders,
      'tables': [
        for (final table in host.waiterTables)
          () {
            final order = host.openOrderFor(table.id);
            final call = calls.where((call) => call.tableId == table.id).firstOrNull;
            return {
              'id': table.id,
              'number': table.number,
              'zone': table.zone,
              'status': table.status.name,
              'items': order?.lines.fold<int>(0, (sum, line) => sum + line.qty) ?? 0,
              'total': order?.subtotal ?? 0,
              'waiting': pending.where((waiting) => waiting.tableId == table.id).length,
              'ready': host.hasReadyFood(table.id),
              if (call != null) 'call': call.kind,
            };
          }(),
      ],
      'orders': [
        for (final order in _orders.reversed.where((order) => order.deviceId == device.id).take(10))
          {'id': order.id, 'tableNumber': order.tableNumber, 'status': order.status.name, 'items': order.itemCount},
      ],
    };
  }

  Future<HubResponse> _order(WaiterDevice device, Map<String, dynamic>? body) async {
    final tableId = body?['tableId'];
    final rawLines = body?['lines'];
    if (tableId is! String || rawLines is! List || rawLines.isEmpty || rawLines.length > LanProtocol.maxLines) {
      return HubResponse.error(400, 'bad_request');
    }
    // Refused up front, so an order never waits for an Accept that cannot work.
    if (!host.takesTableOrders) return HubResponse.error(503, 'orders_paused');
    final table = host.waiterTables.where((table) => table.id == tableId).firstOrNull;
    if (table == null) return HubResponse.error(404, 'table_not_found');
    final lines = <OrderLine>[];
    final perDish = <String, int>{};
    for (final raw in rawLines) {
      if (raw is! Map) return HubResponse.error(400, 'bad_request');
      final itemId = raw['itemId'];
      final qty = raw['qty'];
      final rawOn = raw['onIds'];
      if (itemId is! String || qty is! int || qty < 1 || qty > LanProtocol.maxDishQty) {
        return HubResponse.error(400, 'bad_request');
      }
      final item = host.menuItems.where((item) => item.id == itemId).firstOrNull;
      if (item == null || !item.available || item.soldOut) return HubResponse.error(409, 'items_unavailable');
      Set<String>? onIds;
      if (rawOn != null) {
        if (rawOn is! List || rawOn.any((id) => id is! String)) return HubResponse.error(400, 'bad_request');
        onIds = rawOn.cast<String>().toSet();
        final known = {for (final option in item.options) option.id};
        if (!known.containsAll(onIds)) return HubResponse.error(400, 'bad_request');
      }
      perDish[item.id] = (perDish[item.id] ?? 0) + qty;
      if (!item.canSellMore(perDish[item.id]! - 1)) return HubResponse.error(409, 'items_unavailable');
      // Prices come from the till's own menu; the phone only says which dish and how many.
      final line = item.lineWith(locale: host.locale, onIds: onIds, qty: qty);
      final same = lines.where((other) => other.mergeKey == line.mergeKey).firstOrNull;
      if (same == null) {
        lines.add(line);
      } else {
        same.qty = min(same.qty + qty, LanProtocol.maxDishQty);
      }
    }
    final order = WaiterOrder(
      id: _randomId(),
      deviceId: device.id,
      deviceName: device.name,
      tableId: table.id,
      tableNumber: table.number,
      lines: lines,
      createdAt: _clock(),
    );
    if (host.holdsOrders) {
      // Like a guest's QR order: it goes to the till now and waits there for the cashier's Accept.
      final result = await host.sendWaiterLines(table.id, lines, forAccept: true);
      final error = result.error;
      if (error != null && error.startsWith('items_unavailable')) return HubResponse.error(409, 'items_unavailable');
      if (error != null || result.orderId == null) return HubResponse.error(503, 'not_sent');
      order.tillOrderId = result.orderId;
    } else {
      host.ringNewOrder();
    }
    _orders.add(order);
    if (_orders.length > keptOrders) _orders.removeAt(0);
    notifyListeners();
    return HubResponse(200, {'id': order.id});
  }

  /// Sends a waiting order to the table's bill. Returns the till order id, or the error.
  Future<({String? error, String? orderId})> accept(WaiterOrder order) async {
    if (order.status != WaiterOrderStatus.pending || !_accepting.add(order.id)) {
      return (error: null, orderId: null);
    }
    notifyListeners();
    try {
      final result = await host.sendWaiterLines(order.tableId, order.lines);
      if (result.error == null) order.status = WaiterOrderStatus.accepted;
      return result;
    } finally {
      _accepting.remove(order.id);
      notifyListeners();
    }
  }

  void refuse(WaiterOrder order) {
    if (order.status != WaiterOrderStatus.pending || _accepting.contains(order.id)) return;
    order.status = WaiterOrderStatus.refused;
    notifyListeners();
  }
}
