import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/kitchen_ticket.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One ticket sent to a printer in a test.
typedef _Sent = ({String? printer, String name});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('one ticket per kitchen', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late CafeStore store;
    late List<_Sent> sent;

    /// Printers that fail; every other printer prints.
    var broken = <String>{};

    const pizzaOven = Kitchen(id: 'k-pizza', name: 'Pizza oven');
    const bar = Kitchen(id: 'k-bar', name: 'Bar', sortOrder: 1);

    OrderLine line(String dish, int round) => OrderLine(menuItemId: dish, name: dish, qty: 1, unitPrice: 5, round: round);

    void order(List<OrderLine> lines) => store.orders = [
      CafeOrder(
        id: 'o1',
        tableId: 't1',
        tableNumber: '4',
        status: OrderStatus.received,
        createdAt: DateTime.utc(2026, 10, 24),
        lines: lines,
        shiftOrderNumber: 7,
      ),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sent = [];
      broken = {};
      TillPrinters.send = (printerUrl, {required name, required build}) async {
        sent.add((printer: printerUrl, name: name));
        return broken.contains(printerUrl) ? KitchenPrintResult.failed : KitchenPrintResult.printed;
      };
      store = CafeStore(AppDatabase.instance)
        ..categories = [
          MenuCategory(id: 'pizza', nameEn: 'Pizza', nameAr: 'Pizza', kitchenId: pizzaOven.id),
          MenuCategory(id: 'drinks', nameEn: 'Drinks', nameAr: 'Drinks', kitchenId: bar.id),
          MenuCategory(id: 'sweets', nameEn: 'Sweets', nameAr: 'Sweets'),
        ]
        ..menuItems = [
          MenuItem(id: 'margherita', nameIt: '', nameEn: 'Margherita', price: 20, categoryId: 'pizza'),
          MenuItem(id: 'juice', nameIt: '', nameEn: 'Juice', price: 5, categoryId: 'drinks'),
          MenuItem(id: 'cake', nameIt: '', nameEn: 'Cake', price: 8, categoryId: 'sweets'),
        ]
        ..kitchens = [bar, pizzaOven];
    });
    tearDown(() => TillPrinters.send = TillPrinters.printPdf);

    test('with no kitchen printer at all nothing prints', () async {
      order([line('margherita', 1)]);
      final report = await TillPrinters.printNewRounds(store, 'o1', l10n);
      expect(report.result, KitchenPrintResult.off);
      expect(sent, isEmpty);
    });

    test('each kitchen gets its own ticket on its own printer, in kitchen order', () async {
      await TillPrinters.saveKitchenPrinter(pizzaOven.id, 'Pizza XP-80');
      await TillPrinters.saveKitchenPrinter(bar.id, 'Bar XP-58');
      order([line('juice', 1), line('margherita', 1)]);

      final report = await TillPrinters.printNewRounds(store, 'o1', l10n);

      expect(report.failed, isEmpty);
      expect(sent.map((item) => item.printer), ['Pizza XP-80', 'Bar XP-58']);
    });

    test('a kitchen with no printer of its own uses the main kitchen printer', () async {
      await TillPrinters.saveKitchen('Main XP-80');
      await TillPrinters.saveKitchenPrinter(bar.id, 'Bar XP-58');
      order([line('cake', 1), line('juice', 1)]);

      await TillPrinters.printNewRounds(store, 'o1', l10n);

      // Cake's category has no kitchen, so it goes to the first kitchen (Pizza oven).
      expect(sent.map((item) => item.printer), ['Main XP-80', 'Bar XP-58']);
    });

    test('a round is printed once; only the new round goes out', () async {
      await TillPrinters.saveKitchen('Main XP-80');
      order([line('margherita', 1)]);
      await TillPrinters.printNewRounds(store, 'o1', l10n);
      order([line('margherita', 1), line('juice', 2)]);
      sent.clear();

      final report = await TillPrinters.printNewRounds(store, 'o1', l10n);

      expect(report.failed, isEmpty);
      expect(sent.map((item) => item.name), ['kitchen-o1-${bar.id}']);
      sent.clear();
      expect((await TillPrinters.printNewRounds(store, 'o1', l10n)).result, KitchenPrintResult.nothingNew);
      expect(sent, isEmpty);
    });

    test('only the kitchen whose printer failed is printed again, and it is named', () async {
      await TillPrinters.saveKitchenPrinter(pizzaOven.id, 'Pizza XP-80');
      await TillPrinters.saveKitchenPrinter(bar.id, 'Bar XP-58');
      broken = {'Bar XP-58'};
      order([line('margherita', 1), line('juice', 1)]);

      final first = await TillPrinters.printNewRounds(store, 'o1', l10n);
      expect(first.failed, ['Bar']);

      broken = {};
      sent.clear();
      final retry = await TillPrinters.printNewRounds(store, 'o1', l10n);
      expect(retry.failed, isEmpty);
      expect(sent.map((item) => item.printer), ['Bar XP-58']);
    });

    test('a cafe with no kitchens prints one ticket as before, and old printed rounds still count', () async {
      store.kitchens = [];
      await TillPrinters.saveKitchen('Main XP-80');
      order([line('margherita', 1), line('juice', 1)]);

      await TillPrinters.printNewRounds(store, 'o1', l10n);
      expect(sent.map((item) => item.name), ['kitchen-o1']);

      // Kitchens set up later: round 1 was already printed, so nothing prints again.
      store.kitchens = [bar, pizzaOven];
      sent.clear();
      expect((await TillPrinters.printNewRounds(store, 'o1', l10n)).result, KitchenPrintResult.nothingNew);
      expect(sent, isEmpty);
    });

    test('a quick takeout is split by kitchen too', () async {
      await TillPrinters.saveKitchen('Main XP-80');
      final payment = Payment(
        id: 'pay1',
        orderId: 'o2',
        tableId: '',
        totalDue: 25,
        cashReceived: 25,
        changeDue: 0,
        cashierId: 'c1',
        shiftId: 's1',
        paidAt: DateTime.utc(2026, 10, 24),
        isTakeout: true,
      );

      final report = await TillPrinters.printTakeout(store, payment, [line('juice', 1), line('margherita', 1)], l10n);

      expect(report.failed, isEmpty);
      expect(sent.map((item) => item.name), ['kitchen-pay1-${pizzaOven.id}', 'kitchen-pay1-${bar.id}']);
    });

    test('a ticket with the kitchen name is a valid PDF', () async {
      final Uint8List bytes = await kitchenTicketPdf(
        l10n: l10n,
        number: '7',
        where: l10n.cashierTableShort('4'),
        kitchen: 'Pizza oven',
        added: false,
        at: DateTime.utc(2026, 10, 24),
        lines: [line('margherita', 1)],
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  test('a kitchen ticket holds the dishes and their choices in Arabic and English', () async {
    for (final locale in const ['en', 'ar']) {
      final l10n = lookupAppLocalizations(Locale(locale));
      final bytes = await kitchenTicketPdf(
        l10n: l10n,
        number: '12',
        where: l10n.cashierTableShort('5'),
        added: true,
        at: DateTime.utc(2026, 10, 19, 12),
        lines: [
          OrderLine(
            menuItemId: 'pizza',
            name: 'مارغريتا',
            qty: 2,
            unitPrice: 20,
            choices: const [
              LineChoice(id: 'onion', nameAr: 'بصل', nameEn: 'Onion', on: false),
              LineChoice(id: 'cheese', nameAr: 'جبنة', nameEn: 'Extra cheese', on: true, price: 1.5),
            ],
          ),
          OrderLine(menuItemId: 'latte', name: 'Latte', qty: 1, unitPrice: 7),
        ],
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });

  test('no printers picked means no kitchen tickets and the receipt dialog', () async {
    SharedPreferences.setMockInitialValues({});
    final saved = await TillPrinters.settings();
    expect(saved.kitchen, isNull);
    expect(saved.receipt, isNull);
  });

  test('picked printers are kept for this till; None clears them', () async {
    SharedPreferences.setMockInitialValues({});
    await TillPrinters.saveKitchen('Kitchen XP-80');
    await TillPrinters.saveReceipt('Front EPSON');
    var saved = await TillPrinters.settings();
    expect(saved.kitchen, 'Kitchen XP-80');
    expect(saved.receipt, 'Front EPSON');
    await TillPrinters.saveKitchen(null);
    saved = await TillPrinters.settings();
    expect(saved.kitchen, isNull);
    expect(saved.receipt, 'Front EPSON');
  });
}
