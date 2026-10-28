import '../models/models.dart';
import '../platform/alert_sound.dart';
import '../state/cafe_store.dart';
import 'hub_server.dart';
import 'waiter_devices.dart';
import 'waiter_hub.dart';

/// Lets the waiter hub read the till's menu and floor and send accepted orders through it.
class StoreHubHost implements WaiterHubHost {
  StoreHubHost(this.store);

  final CafeStore store;

  @override
  String get cafeName => store.cafeName;

  @override
  String get locale => store.locale;

  @override
  List<MenuCategory> get categories => store.categories;

  @override
  List<MenuItem> get menuItems => store.menuItems;

  @override
  List<CafeTable> get waiterTables => store.diningTables;

  @override
  CafeOrder? openOrderFor(String tableId) => store.openOrderFor(tableId);

  @override
  Map<String, String> get brandColors => {
    for (final key in const ['headerColor', 'sidebarColor', 'backgroundColor', 'buttonColor'])
      if (store.cafe[key] case final String hex when hex.isNotEmpty) key: hex,
  };

  @override
  bool get holdsOrders => !store.db.isLocal && !store.db.offlineMode;

  @override
  bool get takesTableOrders => store.db.isLocal || !(store.db.offlineMode || store.isOffline);

  @override
  OrderStatus? tillOrderStatus(String orderId) =>
      store.orders.where((order) => order.id == orderId).firstOrNull?.status;

  @override
  Future<({String? error, String? orderId})> sendWaiterLines(
    String tableId,
    List<OrderLine> lines, {
    bool forAccept = false,
  }) => store.sendWaiterLines(tableId, lines, forAccept: forAccept);

  @override
  void ringNewOrder() => playAlertSound(AlertKind.order);
}

/// Hosts waiter phones while a cashier is signed in at this desktop till, and stops when they
/// sign out, so phones never reach a till nobody is watching.
class WaiterHubLink {
  WaiterHubLink._(this.store, this.server);

  final CafeStore store;
  final HubServer server;

  /// Sets up waiter phones for [store]; does nothing where the till cannot host them (web).
  static WaiterHubLink? attach(CafeStore store, {WaiterDeviceStore? devices}) {
    final hub = WaiterHub(host: StoreHubHost(store), deviceStore: devices ?? PrefsWaiterDeviceStore());
    final server = HubServer(hub);
    if (!server.supported) return null;
    store.waiterHub = hub;
    final link = WaiterHubLink._(store, server);
    store.addListener(link._sync);
    link._sync();
    return link;
  }

  void _sync() {
    if (store.authKind == AuthKind.cashier) {
      if (!server.running) server.start();
    } else if (server.running) {
      server.stop();
    }
  }
}
