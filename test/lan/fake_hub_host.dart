import 'package:menu_web_v1/lan/waiter_hub.dart';
import 'package:menu_web_v1/models/models.dart';

/// A till with two tables and three dishes; records what the hub sends on.
class FakeHost implements WaiterHubHost {
  final sent = <({String tableId, List<OrderLine> lines, bool forAccept})>[];
  int rings = 0;

  /// Online till: waiter orders wait in its new-order list like a guest's QR order.
  @override
  bool holdsOrders = false;

  /// False while the online till has no internet.
  @override
  bool takesTableOrders = true;

  /// Till order statuses the hub reads back.
  final tillStatuses = <String, OrderStatus>{};

  @override
  Map<String, String> get brandColors => const {'headerColor': '#123456', 'buttonColor': '#00AA55'};

  @override
  OrderStatus? tillOrderStatus(String orderId) => tillStatuses[orderId];

  @override
  String get cafeName => 'Caffe test';

  @override
  String get locale => 'en';

  @override
  final categories = [
    MenuCategory(id: 'coffee', nameEn: 'Coffee', nameAr: 'قهوة'),
    MenuCategory(id: 'hidden', nameEn: 'Hidden', nameAr: 'مخفي', visible: false),
  ];

  @override
  final menuItems = [
    MenuItem(id: 'latte', nameIt: 'Latte', nameEn: 'Latte', price: 7, categoryId: 'coffee'),
    MenuItem(
      id: 'pizza',
      nameIt: 'Pizza',
      nameEn: 'Pizza',
      price: 20,
      categoryId: 'coffee',
      options: const [DishOption(id: 'cheese', kind: DishOption.topping, nameAr: 'جبن', nameEn: 'Cheese', price: 3)],
    ),
    MenuItem(id: 'gone', nameIt: 'Gone', nameEn: 'Gone', price: 5, categoryId: 'coffee', soldOut: true),
    MenuItem(id: 'secret', nameIt: 'Secret', nameEn: 'Secret', price: 5, categoryId: 'hidden'),
  ];

  @override
  final waiterTables = [
    CafeTable(id: 't1', number: '1', qrSlug: 's1'),
    CafeTable(id: 't2', number: '2', qrSlug: 's2', status: TableStatus.dining),
  ];

  @override
  CafeOrder? openOrderFor(String tableId) => null;

  @override
  Future<({String? error, String? orderId})> sendWaiterLines(
    String tableId,
    List<OrderLine> lines, {
    bool forAccept = false,
  }) async {
    sent.add((tableId: tableId, lines: lines, forAccept: forAccept));
    if (forAccept) tillStatuses['order-1'] = OrderStatus.received;
    return (error: null, orderId: 'order-1');
  }

  @override
  void ringNewOrder() => rings++;
}

