import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/kitchen_ticket.dart';
import 'package:menu_web_v1/printing/receipt_print.dart';
import 'package:menu_web_v1/printing/receipt_settings.dart';
import 'package:menu_web_v1/printing/slip.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

/// The page width a PDF was laid out for, in points (57 mm roll: 161.57; 80 mm roll: 226.77).
String _pageWidth(Uint8List bytes) {
  final text = String.fromCharCodes(bytes);
  final box = RegExp(r'/MediaBox\[0 0 ([0-9.]+)').firstMatch(text);
  return box!.group(1)!;
}

/// Every text on the slip, in order (pairs as "label | value").
List<String> _texts(List<SlipLine> lines) => [
      for (final line in lines)
        switch (line) {
          SlipText(:final text) => text,
          SlipPair(:final label, :final value) => '$label | $value',
          SlipLogo() => '[logo]',
          SlipDivider() || SlipGap() => null,
        },
    ].whereType<String>().toList();

CafeStore _store() {
  final store = CafeStore(AppDatabase.instance)
    ..cafe = {'name': 'Caffè Roma', 'serviceChargeRate': 0.10, 'logoUrl': 'data:image/png;base64,AAAA'}
    ..locale = 'en';
  store.orders.add(CafeOrder(
    id: 'o1',
    tableId: 't1',
    tableNumber: '4',
    status: OrderStatus.paid,
    createdAt: DateTime.utc(2026, 10, 24, 9),
    lines: [
      OrderLine(
        menuItemId: 'pizza',
        name: 'Margherita',
        qty: 2,
        unitPrice: 9,
        listUnitPrice: 10,
        choices: const [LineChoice(id: 'onion', nameAr: 'بصل', nameEn: 'Onion', on: false)],
      ),
    ],
  ));
  return store;
}

Payment _payment({bool voided = false}) => Payment(
      id: 'p1',
      orderId: 'o1',
      tableId: 't1',
      tableNumber: '4',
      totalDue: 19.8,
      cashReceived: 20,
      changeDue: 0.2,
      cashierId: 'c1',
      cashierName: 'Sara',
      shiftId: 's1',
      paidAt: DateTime.utc(2026, 10, 24, 9, 30),
      monthlyDisplayNumber: '2610001',
      shiftOrderNumber: 3,
      paymentTypeNameEn: 'Cash',
      voidedAt: voided ? DateTime.utc(2026, 10, 24, 10) : null,
      voidReason: voided ? 'wrong table' : null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('receipt settings', () {
    test('an empty value means the defaults, which print as before', () {
      const defaults = ReceiptSettings();
      expect(ReceiptSettings.fromJson(null), defaults);
      expect(ReceiptSettings.fromJson(const {}), defaults);
      expect(defaults.showCashier, isFalse, reason: 'receipts had no cashier line before');
    });

    test('saved values come back exactly; wrong types fall back and long text is cut', () {
      const custom = ReceiptSettings(header: 'Via Roma 1', footer: 'Grazie', showCashier: true, showLogo: false, showTable: false);
      expect(ReceiptSettings.fromJson(custom.toJson()), custom);
      final odd = ReceiptSettings.fromJson({'showLogo': 'yes', 'header': 42, 'footer': 'x' * 500});
      expect(odd.showLogo, isTrue);
      expect(odd.header, '');
      expect(odd.footer.length, ReceiptSettings.maxTextLength);
    });

    test('the store saves them in the cafe settings, which every till reads', () async {
      final store = _store();
      await store.saveReceiptSettings(const ReceiptSettings(footer: 'See you'));
      expect(store.receiptSettings.footer, 'See you');
      expect((store.cafe['receiptSettings'] as Map)['footer'], 'See you');
      expect(AppDatabase.instance.cafe['receiptSettings'], store.cafe['receiptSettings']);
    });
  });

  group('the receipt builder', () {
    test('with the defaults it prints what receipts always had', () {
      final store = _store();
      final texts = _texts(receiptSlip(store, ReceiptData.ofSale(store, _payment()), l10n));
      expect(texts.first, '[logo]');
      expect(texts, containsAll(['Caffè Roma', '${l10n.salesReceiptNo} 2610001', l10n.cashierOrderNumber(store.orderNumber(3)), l10n.cashierTableShort('4'), l10n.receiptThankYou]));
      expect(texts, contains(startsWith('2  Margherita')));
      expect(texts, contains(startsWith(l10n.salesColDiscount)));
      expect(texts, contains(startsWith(l10n.cashierServiceCharge('10'))));
      expect(texts, contains('${l10n.salesColMethod} Cash'));
      expect(texts.any((text) => text.contains('Onion')), isTrue, reason: 'choices show');
      expect(texts, isNot(contains(l10n.receiptCashierLine('Sara'))));
    });

    test('each setting shows or hides its line, and header and footer replace the defaults', () {
      final store = _store();
      const look = ReceiptSettings(
        showCafeName: false,
        showLogo: false,
        header: 'Via Roma 1\nTel 091 000',
        footer: 'Grazie!',
        showOrderNumber: false,
        showTable: false,
        showDate: false,
        showCashier: true,
        showChoices: false,
        showDiscount: false,
        showServiceCharge: false,
        showPaymentMethod: false,
      );
      final texts = _texts(receiptSlip(store, ReceiptData.ofSale(store, _payment()), l10n, settings: look));
      expect(texts, isNot(contains('[logo]')));
      expect(texts, isNot(contains('Caffè Roma')));
      expect(texts.take(2), ['Via Roma 1', 'Tel 091 000']);
      expect(texts, contains(l10n.receiptCashierLine('Sara')));
      expect(texts.last, 'Grazie!');
      for (final hidden in [l10n.cashierOrderNumber(store.orderNumber(3)), l10n.cashierTableShort('4'), l10n.receiptThankYou, '${l10n.salesColMethod} Cash']) {
        expect(texts, isNot(contains(hidden)));
      }
      expect(texts.any((text) => text.startsWith(l10n.salesColDiscount)), isFalse);
      expect(texts.any((text) => text.startsWith(l10n.cashierServiceCharge('10'))), isFalse);
      expect(texts.any((text) => text.contains('Onion')), isFalse);
      // The money lines always stay.
      expect(texts, contains(startsWith(l10n.cashierTotalPayable)));
    });

    test('a voided sale prints the VOID banner and the reason', () {
      final store = _store();
      final texts = _texts(receiptSlip(store, ReceiptData.ofSale(store, _payment(voided: true)), l10n));
      expect(texts, containsAll([l10n.voidStatus.toUpperCase(), l10n.voidReasonLine('wrong table')]));
    });

    test('the takeout sample has no table and no service charge', () {
      final store = _store();
      final data = ReceiptData.sample(store, l10n, takeout: true);
      final texts = _texts(receiptSlip(store, data, l10n));
      expect(texts, contains(l10n.serviceTakeout));
      expect(data.service, 0);
      expect(texts.any((text) => text.startsWith(l10n.cashierServiceCharge('10'))), isFalse);
    });

    for (final (mm, width) in [(58, '161.5748'), (80, '226.77165')]) {
      // The test cafe's logo is broken data: it is left off, and the receipt still prints.
      test('the receipt and the kitchen ticket are laid out for $mm mm paper', () async {
        final store = _store();
        final receipt = await receiptPdfBytes(store, _payment(), l10n, paperMm: mm);
        final ticket = await kitchenTicketPdf(
          l10n: l10n,
          number: '3',
          where: l10n.cashierTableShort('4'),
          added: false,
          at: DateTime.utc(2026, 10, 24),
          lines: store.orders.single.lines,
          kitchen: 'Pizza oven',
          paperMm: mm,
        );
        for (final bytes in [receipt, ticket]) {
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
          expect(_pageWidth(bytes), width);
        }
      });
    }
  });

  group('paper width on this till', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => TillPrinters.send = TillPrinters.printPdf);

    test('each printer keeps its own width; one never set is 80 mm', () async {
      await TillPrinters.savePaperWidth('usb://kitchen', 58);
      await TillPrinters.savePaperWidth('usb://kitchen', 99);
      expect(await TillPrinters.paperWidthOf('usb://kitchen'), 58, reason: 'an unknown width is ignored');
      expect(await TillPrinters.paperWidthOf('usb://receipt'), 80);
      expect(await TillPrinters.paperWidthOf(null), 80);
    });

    test('a kitchen ticket is built for the width the printer is given', () async {
      SharedPreferences.setMockInitialValues({'kitchenPrinterUrl': 'usb://kitchen'});
      final built = <String>[];
      TillPrinters.send = (printerUrl, {required name, required build}) async {
        built.add(_pageWidth(await build(58)));
        return KitchenPrintResult.printed;
      };
      final store = _store()..menuItems = [MenuItem(id: 'pizza', nameIt: '', nameEn: 'Margherita', price: 10, categoryId: 'c')];
      final payment = _payment();
      final report = await TillPrinters.printTakeout(store, payment, store.orders.single.lines, l10n);
      expect(report.result, KitchenPrintResult.printed);
      expect(built, ['161.5748']);
    });
  });
}
