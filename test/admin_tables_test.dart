import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/screens/admin_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

CafeStore _store({String menuUrl = 'https://menu.example'}) {
  final store = CafeStore(AppDatabase.instance);
  store.cafe = {'name': 'Test Cafe', 'publicMenuUrl': menuUrl};
  store.tables = [
    CafeTable(id: 't1', number: '1', qrSlug: 'slug-one'),
    CafeTable(id: 't2', number: '2', qrSlug: 'slug-two'),
    CafeTable(id: 't3', number: '3', qrSlug: 'slug-old', archived: true),
  ];
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a QR code for each active table and hides deleted ones', (tester) async {
    await pumpAdminScreen(tester, const AdminTablesScreen(), _store());

    expect(find.text(l10n.adminTableNumber('1')), findsOneWidget);
    expect(find.text(l10n.adminTableNumber('2')), findsOneWidget);
    expect(find.text(l10n.adminTableNumber('3')), findsNothing);
    expect(find.byType(QrImageView), findsNWidgets(2));
    expect(find.text('/t/slug-one'), findsOneWidget);
  });

  test('table links are plain paths the guest app serves, not hash routes', () {
    expect(_store().guestLink('slug-one'), 'https://menu.example/t/slug-one');
    expect(_store(menuUrl: 'https://menu.example/').guestLink('slug-one'), 'https://menu.example/t/slug-one');
  });

  testWidgets('without a menu address there is no QR code to print', (tester) async {
    await pumpAdminScreen(tester, const AdminTablesScreen(), _store(menuUrl: ''));

    expect(find.byType(QrImageView), findsNothing);
    final print = tester.widget<Widget>(find.ancestor(of: find.text(l10n.adminPrintStandCard).first, matching: find.bySubtype<ButtonStyleButton>()).first);
    expect((print as ButtonStyleButton).onPressed, isNull);
  });

  testWidgets('search narrows the tables by number', (tester) async {
    await pumpAdminScreen(tester, const AdminTablesScreen(), _store());

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text(l10n.adminTableNumber('1')), findsNothing);
    expect(find.text(l10n.adminTableNumber('2')), findsOneWidget);
  });

  testWidgets('adding a table needs a number', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminTablesScreen(), store);

    await tapVisible(tester, find.text(l10n.adminAddTableButton));
    await tapVisible(tester, find.text(l10n.adminCreate));
    expect(store.activeTables, hasLength(2), reason: 'an empty number creates nothing');

    await tester.enterText(find.widgetWithText(TextField, l10n.adminTableNumberLabel), '9');
    await tapVisible(tester, find.text(l10n.adminCreate));
    expect(store.activeTables.map((t) => t.number), contains('9'));
    expect(find.text(l10n.adminTableNumber('9')), findsOneWidget);
  });

  testWidgets('a new QR code is made only after confirming, because the printed one stops working', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminTablesScreen(), store);

    await tapVisible(tester, find.text(l10n.adminRegenerateQr).first);
    await tapVisible(tester, find.text(l10n.commonCancel));
    expect(store.tables.first.qrSlug, 'slug-one');

    await tapVisible(tester, find.text(l10n.adminRegenerateQr).first);
    await tapVisible(tester, find.text(l10n.adminRegenerateConfirm));
    expect(store.tables.first.qrSlug, isNot('slug-one'));
    expect(store.tables[1].qrSlug, 'slug-two', reason: 'only the chosen table changes');
  });

  testWidgets('a table with an open order cannot be deleted', (tester) async {
    final store = _store();
    store.orders = [
      CafeOrder(id: 'o1', tableId: 't1', tableNumber: '1', status: OrderStatus.served, createdAt: DateTime.utc(2026, 10, 12), lines: []),
    ];
    await pumpAdminScreen(tester, const AdminTablesScreen(), store);

    await tapVisible(tester, find.byTooltip(l10n.commonDelete).first);
    expect(find.text(l10n.adminDeleteTableBusy), findsOneWidget);
    expect(store.tables.first.archived, isFalse);
  });

  testWidgets('deleting a free table archives it after confirming', (tester) async {
    final store = _store();
    await pumpAdminScreen(tester, const AdminTablesScreen(), store);

    await tapVisible(tester, find.byTooltip(l10n.commonDelete).first);
    await tapVisible(tester, find.text(l10n.adminDeleteTableConfirm));
    expect(store.tables.first.archived, isTrue, reason: 'kept for its receipts, just hidden');
    expect(find.text(l10n.adminTableNumber('1')), findsNothing);
  });
}
