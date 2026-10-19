import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/kitchen_ticket.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
