import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/features/app_feature.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/export_pdfs.dart';
import 'package:menu_web_v1/screens/admin_receipt_editor.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

CafeStore _store() => CafeStore(AppDatabase.instance)
  ..cafe = {'name': 'Caffè Roma', 'serviceChargeRate': 0.1}
  ..locale = 'en'
  ..kitchens = [Kitchen(id: 'k1', name: 'Pizza oven', sortOrder: 0), Kitchen(id: 'k2', name: 'Bar', sortOrder: 1)];

Future<void> _pump(WidgetTester tester, CafeStore store) async {
  await pumpAdminScreen(tester, const SingleChildScrollView(child: ReceiptEditorCard()), store, size: const Size(1200, 2600));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    builtPreviews.clear();
  });

  testWidgets('cafe-wide and this-till settings are labelled apart; without a printer both widths show', (tester) async {
    await _pump(tester, _store());

    expect(find.text(l10n.settingsScopeWholeCafe.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.settingsScopeThisTill.toUpperCase()), findsOneWidget);
    // Tests run off Windows: no printers, so the note says printing uses the print dialog.
    expect(find.text(l10n.receiptPaperWeb), findsOneWidget);
    expect(find.text(l10n.receiptPreviewBothWidths), findsOneWidget);
    expect(find.text('preview slip-58 57mm'), findsOneWidget);
    expect(find.text('preview slip-80 80mm'), findsOneWidget);
  });

  testWidgets('a change shows in the preview at once and is saved for the whole cafe', (tester) async {
    final store = _store();
    await _pump(tester, store);
    final save = find.ancestor(of: find.text(l10n.receiptSave), matching: find.bySubtype<ButtonStyleButton>());
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull, reason: 'nothing changed yet');

    final before = builtPreviews.length;
    await tapVisible(tester, find.widgetWithText(FilterChip, l10n.receiptLineCashier));
    await tester.enterText(find.widgetWithText(TextField, l10n.receiptFooterHint(l10n.receiptThankYou)), 'Grazie!');
    await tester.pumpAndSettle();
    expect(builtPreviews.length, greaterThan(before), reason: 'the preview is drawn again with the draft');
    expect(store.receiptSettings.showCashier, isFalse, reason: 'not saved until Save');

    await tapVisible(tester, find.text(l10n.receiptSave));
    expect(store.receiptSettings.showCashier, isTrue);
    expect(store.receiptSettings.footer, 'Grazie!');
    expect(find.text(l10n.receiptSaved), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull, reason: 'saved, nothing left to save');
  });

  testWidgets('each kitchen has its own ticket preview; with the kitchen feature off there is none', (tester) async {
    await _pump(tester, _store());
    expect(find.widgetWithText(ChoiceChip, l10n.receiptPreviewKitchenOf('Pizza oven')), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, l10n.receiptPreviewKitchenOf('Bar')), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(ChoiceChip, l10n.receiptPreviewKitchenOf('Bar')));
    expect(find.text(l10n.receiptKitchenFixed), findsOneWidget);
    expect(find.text('preview slip-80 80mm'), findsOneWidget);

    builtPreviews.clear();
    await _pump(tester, _store()..features = FeatureSet.fromKeys(const ['tables', 'expenses']));
    expect(find.textContaining(l10n.receiptPreviewKitchenOf('')), findsNothing);
  });

  testWidgets('the PDF exports preview on A4 and the CSV only lists its columns', (tester) async {
    await _pump(tester, _store());

    await tapVisible(tester, find.widgetWithText(ChoiceChip, l10n.receiptPreviewSalesLog));
    expect(find.text('preview sales-log 297mm'), findsOneWidget, reason: 'A4 landscape');
    expect(find.text(l10n.receiptCsvColumns(salesLogCsvColumns(l10n).join(', '))), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(ChoiceChip, l10n.receiptPreviewExpenses));
    expect(find.text('preview wages 297mm'), findsOneWidget);
    expect(find.text(l10n.receiptCsvColumns(expensesCsvColumns.join(', '))), findsOneWidget);
  });

  testWidgets('the sales report has a preview too, at the cashier printer width', (tester) async {
    await _pump(tester, _store());

    await tapVisible(tester, find.widgetWithText(ChoiceChip, l10n.receiptPreviewReport));
    expect(find.text(l10n.receiptPreviewBothWidths), findsOneWidget, reason: 'no cashier printer in tests');
    expect(find.text('preview slip-58 57mm'), findsOneWidget);
    expect(find.text('preview slip-80 80mm'), findsOneWidget);
  });
}
