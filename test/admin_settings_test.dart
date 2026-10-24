import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/features/app_feature.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_catalog_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

/// Records what the settings screen asks the server to do, and answers with [passwordError].
class _SettingsStore extends CafeStore {
  _SettingsStore() : super(AppDatabase.instance) {
    cafe = {'name': 'Test Cafe'};
    cashiers = [Cashier(id: 'c1', name: 'Sara Ali', initials: 'SA')];
  }

  final added = <(String, String)>[];
  final deleted = <String>[];
  final passwordChanges = <(String, String)>[];
  String? passwordError;

  @override
  Future<void> addCashier({required String name, String pin = '', String role = StaffJob.cashier}) async {
    added.add((name, pin));
    cashiers = [...cashiers, Cashier(id: 'c${cashiers.length + 1}', name: name, initials: 'N')];
    notifyListeners();
  }

  @override
  Future<String?> deleteCashier(String id) async {
    deleted.add(id);
    cashiers = cashiers.where((c) => c.id != id).toList();
    notifyListeners();
    return null;
  }

  @override
  Future<String?> changeAdminPassword({required String current, required String next}) async {
    passwordChanges.add((current, next));
    return passwordError;
  }
}

Finder _field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );

Finder inDialog(String label) => find.descendant(of: find.byType(Dialog), matching: find.text(label));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a cashier is saved only with a name and a 4-digit PIN', (tester) async {
    final store = _SettingsStore();
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));

    await tester.enterText(find.widgetWithText(TextField, l10n.catalogCashierNameHint), 'Omar');
    await tester.enterText(find.widgetWithText(TextField, '••••'), '123');
    await tapVisible(tester, find.text(l10n.catalogSaveCashier));
    expect(store.added, isEmpty, reason: 'a 3-digit PIN is not enough');

    await tester.enterText(find.widgetWithText(TextField, '••••'), '1234');
    await tapVisible(tester, find.text(l10n.catalogSaveCashier));
    expect(store.added, [('Omar', '1234')]);
    expect(find.text('Omar'), findsOneWidget);
  });

  testWidgets('removing a cashier asks first', (tester) async {
    final store = _SettingsStore();
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));
    final removeSara = find.descendant(
      of: find.ancestor(of: find.text('Sara Ali'), matching: find.byType(Row)).first,
      matching: find.text(l10n.commonRemove),
    );

    await tapVisible(tester, removeSara);
    expect(find.text(l10n.catalogDeleteCashierMessage('Sara Ali')), findsOneWidget);
    await tapVisible(tester, inDialog(l10n.commonCancel));
    expect(store.deleted, isEmpty);

    await tapVisible(tester, removeSara);
    await tapVisible(tester, inDialog(l10n.catalogDeleteCashierConfirm));
    expect(store.deleted, ['c1']);
    expect(find.text('Sara Ali'), findsNothing);
  });

  testWidgets('the language is saved only after choosing a different one', (tester) async {
    final store = _SettingsStore();
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));

    final save = find.ancestor(of: find.text(l10n.catalogSaveLanguage), matching: find.bySubtype<ButtonStyleButton>());
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull, reason: 'English is already the language');

    await tapVisible(tester, find.text('العربية'));
    expect(store.locale, 'en', reason: 'choosing is not saving');
    await tapVisible(tester, save);
    expect(store.locale, 'ar');
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull, reason: 'nothing left to save');
  });

  testWidgets('a refused password change shows why and keeps what was typed', (tester) async {
    final store = _SettingsStore()..passwordError = 'Current password is wrong.';
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));

    await tester.enterText(_field(l10n.catalogCurrentPassword), 'old');
    await tester.enterText(_field(l10n.catalogNewPassword), 'NewPass1!');
    await tapVisible(tester, find.text(l10n.catalogUpdatePassword));

    expect(store.passwordChanges, [('old', 'NewPass1!')]);
    expect(find.text('Current password is wrong.'), findsOneWidget);
    expect(tester.widget<TextField>(_field(l10n.catalogNewPassword)).controller!.text, 'NewPass1!');
  });

  testWidgets('a successful password change confirms and clears both fields', (tester) async {
    final store = _SettingsStore();
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));

    await tester.enterText(_field(l10n.catalogCurrentPassword), 'old');
    await tester.enterText(_field(l10n.catalogNewPassword), 'NewPass1!');
    await tapVisible(tester, find.text(l10n.catalogUpdatePassword));

    expect(find.text(l10n.catalogPasswordUpdated), findsOneWidget);
    expect(tester.widget<TextField>(_field(l10n.catalogCurrentPassword)).controller!.text, isEmpty);
    expect(tester.widget<TextField>(_field(l10n.catalogNewPassword)).controller!.text, isEmpty);
  });

  testWidgets('the printers & kitchens card shows even with the kitchen feature off', (tester) async {
    final store = _SettingsStore()..features = FeatureSet.fromKeys(const ['tables']);
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));
    await tester.pump();

    expect(find.text(l10n.printersKitchensTitle), findsOneWidget);
    expect(find.text(l10n.kitchensTitle), findsNothing);
    // The auto-print switch moved here from Ordering, so it shows once.
    expect(find.text(l10n.adminAutoPrintReceipt), findsOneWidget);
  });

  testWidgets('the admin sees the guest menu address read-only, and saving cafe info keeps it', (tester) async {
    final store = _SettingsStore()..cafe = {'name': 'Test Cafe', 'publicMenuUrl': 'https://menu.example.com'};
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));

    expect(find.text(l10n.catalogPublicMenuUrl), findsOneWidget);
    expect(find.widgetWithText(SelectableText, 'https://menu.example.com'), findsOneWidget);
    expect(find.text(l10n.catalogPublicMenuUrlReadOnly), findsOneWidget);
    expect(find.widgetWithText(TextField, l10n.catalogPublicMenuUrlHint), findsNothing, reason: 'no field to type an address');

    await tester.enterText(find.widgetWithText(TextField, 'Test Cafe'), 'New Name');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text(l10n.catalogSaveCompany));
    expect(store.cafe['name'], 'New Name');
    expect(store.cafe['publicMenuUrl'], 'https://menu.example.com');
  });

  testWidgets('a cafe without its own address shows the default one', (tester) async {
    final store = _SettingsStore();
    await pumpAdminScreen(tester, const AdminSettingsScreen(), store, size: const Size(1600, 2200));

    expect(find.widgetWithText(SelectableText, defaultGuestMenuUrl), findsOneWidget);
    expect(find.text(l10n.catalogPublicMenuUrlDefault), findsOneWidget);
  });
}
