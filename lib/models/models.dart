enum OrderStatus {
  received,
  preparing,
  ready,
  served,
  paid;

  /// The next kitchen step. Paid and served do not skip ahead.
  OrderStatus? get next => switch (this) {
        OrderStatus.received => OrderStatus.preparing,
        OrderStatus.preparing => OrderStatus.ready,
        OrderStatus.ready => OrderStatus.served,
        OrderStatus.served || OrderStatus.paid => null,
      };
}

enum TableStatus { free, dining, billRequested }

enum StaffRole { admin, cashier }

class AdminAccount {
  AdminAccount({
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    this.displayName = 'Admin',
  });

  final String email;
  String passwordHash;
  String passwordSalt;
  String displayName;

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        email: json['email'] as String,
        passwordHash: json['passwordHash'] as String,
        passwordSalt: json['passwordSalt'] as String,
        displayName: json['displayName'] as String? ?? 'Admin',
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'displayName': displayName,
      };
}

class Cashier {
  Cashier({
    required this.id,
    required this.name,
    required this.pinHash,
    required this.pinSalt,
    required this.initials,
    this.active = true,
  });

  final String id;
  String name;
  String pinHash;
  String pinSalt;
  String initials;
  bool active;

  factory Cashier.fromJson(Map<String, dynamic> json) => Cashier(
        id: json['id'] as String,
        name: json['name'] as String,
        pinHash: json['pinHash'] as String,
        pinSalt: json['pinSalt'] as String,
        initials: json['initials'] as String,
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'initials': initials,
        'active': active,
      };
}

class MenuCategory {
  MenuCategory({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.sortOrder = 0,
    this.spotlight = false,
    this.visible = true,
  });

  final String id;
  String nameEn;
  String nameAr;
  int sortOrder;
  bool spotlight;
  bool visible;

  String label(String locale) => locale == 'ar' ? nameAr : nameEn;

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
        id: json['id'] as String,
        nameEn: json['nameEn'] as String? ?? json['name'] as String? ?? '',
        nameAr: json['nameAr'] as String? ?? json['nameEn'] as String? ?? '',
        sortOrder: json['sortOrder'] as int? ?? 0,
        spotlight: json['spotlight'] as bool? ?? false,
        visible: json['visible'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'sortOrder': sortOrder,
        'spotlight': spotlight,
        'visible': visible,
      };
}

class MenuItem {
  MenuItem({
    required this.id,
    required this.nameIt,
    required this.nameEn,
    required this.price,
    required this.categoryId,
    this.description = '',
    this.imageUrl = '',
    this.available = true,
    this.soldOut = false,
    this.featured = false,
    this.sortOrder = 0,
    this.discountPercent = 0,
    this.discountApplied = false,
  });

  final String id;
  String nameIt;
  String nameEn;
  String description;
  double price;
  String categoryId;
  String imageUrl;
  bool available;
  bool soldOut;
  bool featured;
  int sortOrder;
  double discountPercent;
  bool discountApplied;

  bool get hasDiscount => discountApplied && discountPercent > 0;
  double get salePrice => hasDiscount ? (price * (100 - discountPercent) / 100) : price;

  String displayName(String locale) =>
      locale == 'en' || nameIt.isEmpty ? (nameEn.isEmpty ? nameIt : nameEn) : nameIt;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        nameIt: json['nameIt'] as String? ?? '',
        nameEn: json['nameEn'] as String? ?? json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        categoryId: json['categoryId'] as String,
        imageUrl: json['imageUrl'] as String? ?? '',
        available: json['available'] as bool? ?? true,
        soldOut: json['soldOut'] as bool? ?? false,
        featured: json['featured'] as bool? ?? false,
        sortOrder: json['sortOrder'] as int? ?? 0,
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
        discountApplied: json['discountApplied'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameIt': nameIt,
        'nameEn': nameEn,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        'imageUrl': imageUrl,
        'available': available,
        'soldOut': soldOut,
        'featured': featured,
        'sortOrder': sortOrder,
        'discountPercent': discountPercent,
        'discountApplied': discountApplied,
      };
}

class CafeTable {
  CafeTable({
    required this.id,
    required this.number,
    required this.qrSlug,
    this.zone = 'Main Floor',
    this.seats = 4,
    this.status = TableStatus.free,
    this.guests = 0,
  });

  final String id;
  String number;
  String qrSlug;
  String zone;
  int seats;
  TableStatus status;
  int guests;

  factory CafeTable.fromJson(Map<String, dynamic> json) => CafeTable(
        id: json['id'] as String,
        number: json['number'] as String,
        qrSlug: json['qrSlug'] as String,
        zone: json['zone'] as String? ?? 'Main Floor',
        seats: json['seats'] as int? ?? 4,
        status: TableStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => TableStatus.free,
        ),
        guests: json['guests'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'qrSlug': qrSlug,
        'zone': zone,
        'seats': seats,
        'status': status.name,
        'guests': guests,
      };
}

class OrderLine {
  OrderLine({
    required this.menuItemId,
    required this.name,
    required this.qty,
    required this.unitPrice,
  });

  final String menuItemId;
  final String name;
  int qty;
  final double unitPrice;

  double get total => qty * unitPrice;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        menuItemId: json['menuItemId'] as String,
        name: json['name'] as String,
        qty: json['qty'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'menuItemId': menuItemId,
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
      };
}

class CafeOrder {
  CafeOrder({
    required this.id,
    required this.tableId,
    required this.tableNumber,
    required this.status,
    required this.createdAt,
    required this.lines,
    this.notes = '',
    this.cashierId,
  });

  final String id;
  final String tableId;
  final String tableNumber;
  OrderStatus status;
  final DateTime createdAt;
  final List<OrderLine> lines;
  final String notes;
  String? cashierId;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.qty);
  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);

  factory CafeOrder.fromJson(Map<String, dynamic> json) => CafeOrder(
        id: json['id'] as String,
        tableId: json['tableId'] as String,
        tableNumber: json['tableNumber'] as String? ?? json['tableId'] as String,
        status: OrderStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => OrderStatus.received,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        notes: json['notes'] as String? ?? '',
        cashierId: json['cashierId'] as String?,
        lines: (json['lines'] as List<dynamic>)
            .map((line) => OrderLine.fromJson(line as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
        'cashierId': cashierId,
        'lines': lines.map((line) => line.toJson()).toList(),
      };
}

class CartState {
  CartState({required this.tableId, List<OrderLine>? lines}) : lines = lines ?? [];

  final String tableId;
  final List<OrderLine> lines;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.qty);
  double get total => lines.fold(0, (sum, line) => sum + line.total);

  factory CartState.fromJson(Map<String, dynamic> json) => CartState(
        tableId: json['tableId'] as String,
        lines: (json['lines'] as List<dynamic>? ?? [])
            .map((line) => OrderLine.fromJson(line as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'tableId': tableId,
        'lines': lines.map((line) => line.toJson()).toList(),
      };
}

class Payment {
  Payment({
    required this.id,
    required this.orderId,
    required this.tableId,
    required this.totalDue,
    required this.cashReceived,
    required this.changeDue,
    required this.cashierId,
    required this.shiftId,
    required this.paidAt,
  });

  final String id;
  final String orderId;
  final String tableId;
  final double totalDue;
  final double cashReceived;
  final double changeDue;
  final String cashierId;
  final String shiftId;
  final DateTime paidAt;
  String get method => 'CASH';

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        orderId: json['orderId'] as String,
        tableId: json['tableId'] as String,
        totalDue: (json['totalDue'] as num).toDouble(),
        cashReceived: (json['cashReceived'] as num).toDouble(),
        changeDue: (json['changeDue'] as num).toDouble(),
        cashierId: json['cashierId'] as String,
        shiftId: json['shiftId'] as String,
        paidAt: DateTime.parse(json['paidAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'tableId': tableId,
        'totalDue': totalDue,
        'cashReceived': cashReceived,
        'changeDue': changeDue,
        'cashierId': cashierId,
        'shiftId': shiftId,
        'paidAt': paidAt.toIso8601String(),
        'method': 'CASH',
      };
}

class CashShift {
  CashShift({
    required this.id,
    required this.cashierId,
    required this.openedAt,
    required this.openingCash,
    this.closedAt,
    this.cashSales = 0,
    this.cashRefunds = 0,
    this.cashAdjustments = 0,
    this.actualCash,
    this.transactionCount = 0,
  });

  final String id;
  final String cashierId;
  final DateTime openedAt;
  DateTime? closedAt;
  double openingCash;
  double cashSales;
  double cashRefunds;
  double cashAdjustments;
  double? actualCash;
  int transactionCount;

  bool get isOpen => closedAt == null;
  double get expectedCash => openingCash + cashSales - cashRefunds + cashAdjustments;
  double? get difference => actualCash == null ? null : actualCash! - expectedCash;

  factory CashShift.fromJson(Map<String, dynamic> json) => CashShift(
        id: json['id'] as String,
        cashierId: json['cashierId'] as String,
        openedAt: DateTime.parse(json['openedAt'] as String),
        closedAt: json['closedAt'] == null ? null : DateTime.parse(json['closedAt'] as String),
        openingCash: (json['openingCash'] as num?)?.toDouble() ?? 0,
        cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0,
        cashRefunds: (json['cashRefunds'] as num?)?.toDouble() ?? 0,
        cashAdjustments: (json['cashAdjustments'] as num?)?.toDouble() ?? 0,
        actualCash: (json['actualCash'] as num?)?.toDouble(),
        transactionCount: json['transactionCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cashierId': cashierId,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'openingCash': openingCash,
        'cashSales': cashSales,
        'cashRefunds': cashRefunds,
        'cashAdjustments': cashAdjustments,
        'actualCash': actualCash,
        'transactionCount': transactionCount,
      };
}

class StaffCall {
  StaffCall({
    required this.id,
    required this.tableId,
    required this.tableNumber,
    required this.createdAt,
    this.kind = 'assistance',
    this.resolved = false,
  });

  final String id;
  final String tableId;
  final String tableNumber;
  final DateTime createdAt;
  final String kind;
  bool resolved;

  factory StaffCall.fromJson(Map<String, dynamic> json) => StaffCall(
        id: json['id'] as String,
        tableId: json['tableId'] as String,
        tableNumber: json['tableNumber'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        kind: json['kind'] as String? ?? 'assistance',
        resolved: json['resolved'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind,
        'resolved': resolved,
      };
}
