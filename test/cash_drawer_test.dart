import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/cash_drawer.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Payment _sale(String? type) => Payment(
      id: 'p1',
      orderId: 'o1',
      tableId: '',
      totalDue: 10,
      cashReceived: 10,
      changeDue: 0,
      cashierId: 'c1',
      shiftId: 's1',
      paidAt: DateTime.utc(2026, 10, 25),
      paymentTypeId: type,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<(String, List<int>)> sent;
  late bool printerWorks;

  CafeStore store() => CafeStore(AppDatabase.instance)
    ..paymentTypes = [
      PaymentType(id: 'cash', nameEn: 'Cash', nameAr: 'نقداً', enabled: true, sortOrder: 0),
      PaymentType(id: 'card', nameEn: 'Card', nameAr: 'بطاقة', enabled: true, sortOrder: 1),
    ];

  setUp(() {
    sent = [];
    printerWorks = true;
    CashDrawer.sendRaw = (printer, bytes) async {
      sent.add((printer, bytes));
      return printerWorks;
    };
  });

  test('a cash sale sends the ESC/POS open pulse to the cashier printer', () async {
    SharedPreferences.setMockInitialValues({'receiptPrinterUrl': 'POS-80', 'openCashDrawer': true});

    final opened = await CashDrawer.afterSale(store(), _sale('cash'));

    expect(opened, isTrue);
    expect(sent.single.$1, 'POS-80');
    expect(sent.single.$2, [0x1B, 0x70, 0x00, 0x19, 0xFA]);
  });

  test('a sale with no payment type counts as cash', () async {
    SharedPreferences.setMockInitialValues({'receiptPrinterUrl': 'POS-80', 'openCashDrawer': true});

    await CashDrawer.afterSale(store(), _sale(null));

    expect(sent, hasLength(1));
  });

  test('a card sale leaves the drawer shut', () async {
    SharedPreferences.setMockInitialValues({'receiptPrinterUrl': 'POS-80', 'openCashDrawer': true});

    expect(await CashDrawer.afterSale(store(), _sale('card')), isTrue);
    expect(sent, isEmpty);
  });

  test('switched off (the default), nothing is sent', () async {
    SharedPreferences.setMockInitialValues({'receiptPrinterUrl': 'POS-80'});

    expect(await CashDrawer.afterSale(store(), _sale('cash')), isTrue);
    expect(sent, isEmpty);
  });

  test('no cashier printer or a printer that refuses reports the drawer did not open', () async {
    SharedPreferences.setMockInitialValues({'openCashDrawer': true});
    expect(await CashDrawer.afterSale(store(), _sale('cash')), isFalse);

    SharedPreferences.setMockInitialValues({'receiptPrinterUrl': 'POS-80', 'openCashDrawer': true});
    printerWorks = false;
    expect(await CashDrawer.afterSale(store(), _sale('cash')), isFalse);
  });
}
