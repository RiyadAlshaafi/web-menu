part of 'cafe_store.dart';

extension CafeStoreCatalog on CafeStore {
  String guestScrollRevision(String tableSlug) {
    final table = tableBySlug(tableSlug);
    final buffer = StringBuffer()
      ..write(locale)
      ..write('|')
      ..write(canPlaceOrder)
      ..write('|')
      ..write(guestLocation.name)
      ..write('|')
      ..write(table == null ? '' : serviceForTable(table.id));
    for (final category in guestCategories) {
      buffer
        ..write(category.id)
        ..write(category.sortOrder)
        ..write(category.nameEn)
        ..write(category.nameAr)
        ..write(category.visible);
    }
    for (final item in menuItems) {
      buffer.write(item.syncKey);
    }
    return buffer.toString();
  }

  List<MenuItem> get guestMenu {
    final visibleIds = guestCategories.map((item) => item.id).toSet();
    final items = menuItems.where((item) => visibleIds.contains(item.categoryId)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  bool canOrderItem(MenuItem item) => item.available && !item.soldOut;

  Future<String?> setItemsAvailable(Iterable<String> ids, bool available) async {
    String? error;
    for (final id in ids) {
      error = await db.setItemAvailable(id, available);
      if (error != null) break;
    }
    notifyListeners();
    return error;
  }

  Future<String?> setItemAvailable(String itemId, bool available) async {
    final error = await db.setItemAvailable(itemId, available);
    notifyListeners();
    return error;
  }

  Future<String?> refuseOrderLine(CafeOrder order, OrderLine line) async {
    final name = line.name;
    order.lines.remove(line);
    await db.writeOrders(orders);
    await db.noteOrderRefusal(order.id, name);
    order.awaitingCustomerConfirmation = true;
    order.refusalNotice = order.refusalNotice.trim().isEmpty ? name : '${order.refusalNotice} $name';
    String? error;
    if (line.menuItemId.isNotEmpty) {
      error = await setItemAvailable(line.menuItemId, false);
    } else {
      notifyListeners();
    }
    return error;
  }

  Future<void> confirmRefusedOrder(String tableId) async {
    final order = openOrderFor(tableId);
    if (order == null) return;
    await db.confirmOrderRefusal(order.id);
    order.awaitingCustomerConfirmation = false;
    order.refusalNotice = '';
    await requestBill(tableId, force: true);
  }

  List<MenuItem> get liveMenu {
    final visibleIds = guestCategories.map((item) => item.id).toSet();
    final items = menuItems
        .where((item) => item.available && !item.soldOut && visibleIds.contains(item.categoryId))
        .toList()
      ..sort((a, b) {
        final category = a.sortOrder.compareTo(b.sortOrder);
        return category;
      });
    return items;
  }

  List<MenuItem> dishesIn(String categoryId) {
    final items = menuItems.where((item) => item.categoryId == categoryId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
  List<MenuCategory> get orderedCategories {
    final items = [...categories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  List<MenuCategory> get guestCategories =>
      orderedCategories.where((category) => category.visible).toList();

  Future<void> addCategory(String nameEn, String nameAr, {bool spotlight = false}) async {
    categories.add(
      MenuCategory(
        id: Secrets.id('cat'),
        nameEn: nameEn.trim(),
        nameAr: nameAr.trim().isEmpty ? nameEn.trim() : nameAr.trim(),
        sortOrder: categories.isEmpty ? 1 : categories.map((item) => item.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
        spotlight: spotlight,
      ),
    );
    await db.writeCategories(categories);
    notifyListeners();
  }

  Future<void> saveCategory(MenuCategory category) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index >= 0) categories[index] = category;
    await db.writeCategories(categories);
    notifyListeners();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final ordered = orderedCategories;
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    final item = ordered.removeAt(oldIndex);
    ordered.insert(newIndex.clamp(0, ordered.length), item);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i + 1;
    }
    categories = ordered;
    await db.writeCategories(categories);
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    categories.removeWhere((item) => item.id == id);
    menuItems.removeWhere((item) => item.categoryId == id);
    await db.writeCategories(categories);
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> saveMenuItem(MenuItem item) async {
    final index = menuItems.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      menuItems[index] = item;
    } else {
      if (item.sortOrder == 0) {
        final siblings = dishesIn(item.categoryId);
        item.sortOrder = siblings.isEmpty ? 1 : siblings.map((entry) => entry.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      }
      menuItems.add(item);
    }
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> reorderDishes(String categoryId, int oldIndex, int newIndex) async {
    final ordered = dishesIn(categoryId);
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    final item = ordered.removeAt(oldIndex);
    ordered.insert(newIndex.clamp(0, ordered.length), item);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i + 1;
    }
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> persistLayout() async {
    await db.writeCategories(categories);
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> setDishDiscount(MenuItem item, {required double percent, required bool applied}) async {
    item
      ..discountPercent = percent.clamp(0, 100)
      ..discountApplied = applied && percent > 0;
    await saveMenuItem(item);
  }

  Future<void> applyCategoryDiscount({
    required String? categoryId,
    required double percent,
    required bool activate,
  }) async {
    final rate = percent.clamp(0, 100).toDouble();
    for (final item in menuItems.where((dish) => categoryId == null || dish.categoryId == categoryId)) {
      item
        ..discountPercent = rate
        ..discountApplied = activate && rate > 0;
    }
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<void> deleteMenuItem(String id) async {
    menuItems.removeWhere((item) => item.id == id);
    await db.writeMenuItems(menuItems);
    notifyListeners();
  }

  Future<CafeTable> addTable(String number) async {
    final table = CafeTable(
      id: Secrets.id('tbl'),
      number: number.trim(),
      qrSlug: Secrets.publicId(),
    );
    tables.add(table);
    await db.writeTables(tables);
    notifyListeners();
    return table;
  }

  Future<void> regenerateTableQr(String id) async {
    final table = tableById(id);
    table.qrSlug = Secrets.publicId();
    await db.writeTables(tables);
    notifyListeners();
  }

  Future<void> regenerateAllTableQrs() async {
    for (final table in tables) {
      table.qrSlug = Secrets.publicId();
    }
    await db.writeTables(tables);
    notifyListeners();
  }

  Future<void> deleteTable(String id) async {
    tables.removeWhere((table) => table.id == id);
    await db.writeTables(tables);
    notifyListeners();
  }
}
