import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_menu_layout_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

CafeStore _store() {
  final store = CafeStore(AppDatabase.instance);
  store.categories = [
    MenuCategory(id: 'drinks', nameEn: 'Drinks', nameAr: 'مشروبات', sortOrder: 1),
    MenuCategory(id: 'food', nameEn: 'Food', nameAr: 'طعام', sortOrder: 2),
  ];
  store.menuItems = [
    MenuItem(id: 'tea', nameIt: 'Tea', nameEn: 'Tea', price: 5, categoryId: 'drinks', sortOrder: 1),
    MenuItem(id: 'coffee', nameIt: 'Coffee', nameEn: 'Coffee', price: 7, categoryId: 'drinks', sortOrder: 2),
  ];
  return store;
}

List<String> _order(CafeStore store) => [for (final c in store.orderedCategories) c.nameEn];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lists categories in menu order with their dish counts, and opens the first one', (tester) async {
    await pumpAdminScreen(tester, const AdminMenuScreen(), _store());

    expect(find.text(l10n.layoutDishCount('2')), findsOneWidget);
    expect(find.text(l10n.layoutDishCount('0')), findsOneWidget);
    expect(find.text('Tea'), findsWidgets, reason: 'the first category is open in the inspector');
    expect(find.text('Coffee'), findsWidgets);
  });

  testWidgets('the arrows move a category, and the first cannot move earlier', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminMenuScreen(), store);

    final earlier = find.byTooltip(l10n.layoutMoveEarlier);
    await tapVisible(tester, earlier.first);
    expect(_order(store), ['Drinks', 'Food'], reason: 'the top category has nowhere to go');

    await tapVisible(tester, find.byTooltip(l10n.layoutMoveLater).first);
    expect(_order(store), ['Food', 'Drinks']);
  });

  testWidgets('a new category is added at the end and opened', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminMenuScreen(), store);

    await tester.enterText(find.widgetWithText(TextField, l10n.layoutCategoryNameHint), 'Desserts');
    await tapVisible(tester, find.text(l10n.layoutCreateCategory));

    expect(_order(store), ['Drinks', 'Food', 'Desserts']);
    expect(find.text(l10n.layoutDishesInCategory('DESSERTS', '0')), findsOneWidget);
  });

  testWidgets('an empty name creates nothing', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminMenuScreen(), store);

    await tapVisible(tester, find.text(l10n.layoutCreateCategory));
    expect(store.categories, hasLength(2));
  });

  testWidgets('the switch hides a category from the guest menu', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminMenuScreen(), store);

    await tapVisible(tester, find.byType(Switch));
    expect(store.categories.firstWhere((c) => c.id == 'drinks').visible, isFalse);
    expect(store.guestCategories.map((c) => c.id), ['food']);
  });

  testWidgets('deleting a category asks first; cancel keeps it and confirm removes it with its dishes', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminMenuScreen(), store);

    await tapVisible(tester, find.byTooltip(l10n.layoutDeleteCategoryConfirm));
    expect(find.text(l10n.layoutDeleteCategoryTitle), findsOneWidget);
    await tapVisible(tester, find.text(l10n.commonCancel));
    expect(store.categories, hasLength(2));

    await tapVisible(tester, find.byTooltip(l10n.layoutDeleteCategoryConfirm));
    await tapVisible(tester, find.descendant(of: find.byType(Dialog), matching: find.text(l10n.layoutDeleteCategoryConfirm)));
    expect(_order(store), ['Food']);
    expect(store.menuItems, isEmpty);
  });
}
