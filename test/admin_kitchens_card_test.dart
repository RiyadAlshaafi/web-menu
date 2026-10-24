import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/features/app_feature.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_printers_kitchens_card.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

CafeStore _store() => CafeStore(AppDatabase.instance)
  ..categories = [
    MenuCategory(id: 'pizza', nameEn: 'Pizza', nameAr: 'بيتزا', sortOrder: 1),
    MenuCategory(id: 'drinks', nameEn: 'Drinks', nameAr: 'مشروبات', sortOrder: 2),
  ]
  ..menuItems = []
  ..kitchens = [];

Finder _inDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);

/// Opens the add dialog, names the kitchen, ticks [categories] and saves.
Future<void> _add(WidgetTester tester, String name, List<String> categories) async {
  await tapVisible(tester, find.text('+ ${l10n.kitchensAdd}'));
  await tester.enterText(_inDialog(find.byType(TextField)), name);
  await tester.pump();
  for (final category in categories) {
    await tapVisible(tester, _inDialog(find.widgetWithText(CheckboxListTile, category)));
  }
  await tapVisible(tester, _inDialog(find.text(l10n.kitchensSave)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('adding a kitchen with ticked categories lists it with them', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);

    await _add(tester, 'Pizza oven', ['Pizza']);

    expect(store.kitchens.single.name, 'Pizza oven');
    expect(store.categoryIdsOf(store.kitchens.single.id), {'pizza'});
    expect(find.text(l10n.kitchensFirst('Pizza oven')), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
  });

  testWidgets('a kitchen needs a name before it can be saved', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);

    await tapVisible(tester, find.text('+ ${l10n.kitchensAdd}'));
    final save = tester.widget<FilledButton>(_inDialog(find.widgetWithText(FilledButton, l10n.kitchensSave)));
    expect(save.onPressed, isNull);
  });

  testWidgets('a category in another kitchen says so, and ticking it moves it', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);
    await _add(tester, 'Main', ['Pizza', 'Drinks']);

    await tapVisible(tester, find.text('+ ${l10n.kitchensAdd}'));
    expect(_inDialog(find.text(l10n.kitchensNowIn('Main'))), findsNWidgets(2));
    await tester.enterText(_inDialog(find.byType(TextField)), 'Bar');
    await tester.pump();
    await tapVisible(tester, _inDialog(find.widgetWithText(CheckboxListTile, 'Drinks')));
    await tapVisible(tester, _inDialog(find.text(l10n.kitchensSave)));

    final bar = store.kitchens.singleWhere((item) => item.name == 'Bar');
    final main = store.kitchens.singleWhere((item) => item.name == 'Main');
    expect(store.categoryIdsOf(bar.id), {'drinks'});
    expect(store.categoryIdsOf(main.id), {'pizza'});
  });

  testWidgets('deleting a kitchen asks first, then frees its categories', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);
    await _add(tester, 'Bar', ['Drinks']);

    await tapVisible(tester, find.byTooltip(l10n.commonDelete));
    expect(find.text(l10n.kitchensDeleteTitle('Bar')), findsOneWidget);
    await tapVisible(tester, find.descendant(of: find.byType(Dialog), matching: find.text(l10n.commonDelete)));

    expect(store.kitchens, isEmpty);
    expect(store.categories.every((item) => item.kitchenId == null), isTrue);
  });

  testWidgets('editing renames a kitchen and keeps its categories', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);
    await _add(tester, 'Pizza', ['Pizza']);

    await tapVisible(tester, find.byTooltip(l10n.commonEdit));
    expect(find.text(l10n.kitchensEditTitle), findsOneWidget);
    await tester.enterText(_inDialog(find.byType(TextField)), 'Pizza oven');
    await tester.pump();
    await tapVisible(tester, _inDialog(find.text(l10n.kitchensSave)));

    expect(store.kitchens.single.name, 'Pizza oven');
    expect(store.categoryIdsOf(store.kitchens.single.id), {'pizza'});
  });

  testWidgets('one card shows this till printers on top and the kitchens below', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);
    await tester.pump();

    expect(find.text(l10n.printersKitchensTitle), findsOneWidget);
    expect(find.text(l10n.settingsScopeThisTill.toUpperCase()), findsOneWidget);
    // Tests run off Windows, so the pickers give way to the note.
    expect(find.text(l10n.printersWindowsOnly), findsOneWidget);
    expect(find.text(l10n.kitchensTitle), findsOneWidget);
    final printers = tester.getTopLeft(find.text(l10n.printersWindowsOnly)).dy;
    expect(tester.getTopLeft(find.text(l10n.kitchensTitle)).dy, greaterThan(printers));
  });

  testWidgets('with the kitchen feature off the card still shows, without the kitchens', (tester) async {
    final store = _store()..features = FeatureSet.fromKeys(const ['tables']);
    await pumpAdminScreen(tester, const PrintersKitchensCard(), store);
    await tester.pump();

    expect(find.text(l10n.printersKitchensTitle), findsOneWidget);
    expect(find.text(l10n.printersWindowsOnly), findsOneWidget);
    expect(find.text(l10n.kitchensTitle), findsNothing);
    expect(find.text('+ ${l10n.kitchensAdd}'), findsNothing);
  });
}
