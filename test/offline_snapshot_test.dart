import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';

void main() {
  test('the saved menu copy reloads exactly, so the till can start offline', () {
    final db = AppDatabase.instance;
    final saved = {
      'restaurantId': 'r1',
      'boundSlot': 1,
      'boundRestaurantId': 'r1',
      'boundSlug': 'cafe-1',
      'boundHasAdmin': true,
      'anyAdmin': true,
      'cafe': {'name': 'Test Cafe', 'serviceChargeRate': 0.1, 'taxRate': 0, 'autoPrintReceipt': true},
      'locale': 'ar',
      'tables': [
        {'id': 't1', 'number': 'Takeout', 'qrSlug': 'abc', 'zone': 'Main Floor', 'seats': 1, 'status': 'free', 'guests': 0, 'archived': false},
        {'id': 't2', 'number': '1', 'qrSlug': 'def', 'zone': 'Main Floor', 'seats': 4, 'status': 'free', 'guests': 0, 'archived': true},
      ],
      'categories': [
        {'id': 'c1', 'nameEn': 'Food', 'nameAr': 'طعام', 'sortOrder': 1, 'spotlight': false, 'visible': true},
      ],
      'menuItems': [
        {
          'id': 'm1', 'nameIt': 'Margherita', 'nameEn': 'Margherita', 'description': '', 'price': 9.0,
          'categoryId': 'c1', 'imageUrl': '', 'available': true, 'soldOut': false, 'featured': false,
          'sortOrder': 1, 'discountPercent': 10.0, 'discountApplied': true,
        },
      ],
      'paymentTypes': [
        {'id': 'p1', 'nameEn': 'Cash', 'nameAr': 'نقداً', 'enabled': true, 'sortOrder': 0, 'archived': false},
      ],
      'expenseCategories': [
        {'id': 'e1', 'nameEn': 'Supplies', 'nameAr': 'مستلزمات', 'enabled': true, 'sortOrder': 0},
      ],
      'cashiers': [
        {'id': 'k1', 'name': 'Sara', 'initials': 'S'},
      ],
    };
    db.applyOfflineSnapshot(Map<String, dynamic>.from(jsonDecode(jsonEncode(saved)) as Map));
    expect(jsonDecode(jsonEncode(db.offlineSnapshot())), saved);
    expect(db.menuItems.single.salePrice, closeTo(8.1, 1e-9));
    expect(db.tables.where((t) => t.archived).single.number, '1');
    expect(db.loadedOnce, isTrue);
    // nothing from the last session's sales is carried into an offline start
    expect(db.payments, isEmpty);
    expect(db.orders, isEmpty);
  });
}
