import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/sales_report.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/report_print.dart';
import 'package:menu_web_v1/printing/slip.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

Payment _sale(String order, {bool voided = false}) => Payment(
      id: 'p-$order',
      orderId: order,
      tableId: '',
      totalDue: 1,
      cashReceived: 1,
      changeDue: 0,
      cashierId: 'c1',
      shiftId: 's1',
      paidAt: DateTime.utc(2026, 10, 24, 9),
      voidedAt: voided ? DateTime.utc(2026, 10, 24, 10) : null,
    );

CafeOrder _order(String id, List<OrderLine> lines) =>
    CafeOrder(id: id, tableId: '', tableNumber: '', status: OrderStatus.served, createdAt: DateTime.utc(2026, 10, 24), lines: lines);

OrderLine _line(String dish, int qty, double price) => OrderLine(menuItemId: dish, name: 'Saved $dish', qty: qty, unitPrice: price);

MenuItem _dish(String id) => MenuItem(id: id, nameIt: id, nameEn: id, price: 1, categoryId: 'c');

final _menu = [for (final id in ['tea', 'cake', 'soup', 'juice', 'pie', 'bread', 'salad']) _dish(id)];

SalesReport _report({bool knowsDishes = true}) {
  final day = DateTime(2026, 10, 24);
  return SalesReport.fromRows(
    from: day,
    to: day,
    payments: [_sale('o1'), _sale('o1'), _sale('o2'), _sale('o3', voided: true)],
    expenses: const [],
    paymentTypes: const [],
    expenseCategories: const [],
    staff: const [],
    orders: knowsDishes
        ? [
            _order('o1', [_line('tea', 3, 2), _line('cake', 1, 5)]),
            _order('o2', [_line('tea', 2, 2), _line('juice', 1, 3), _line('', 4, 1)]),
            _order('o3', [_line('cake', 9, 5)]),
          ]
        : null,
  );
}

void main() {
  test('dishes sold count each paid order once and leave voided sales out', () {
    final dishes = _report().dishes!;

    expect(dishes.first.id, 'tea');
    expect(dishes.first.qty, 5, reason: 'o1 was paid twice but counts once');
    expect(dishes.first.total, 10);
    expect(dishes.where((dish) => dish.id == 'cake').single.qty, 1, reason: 'the voided o3 cakes do not count');
    expect(dishes.where((dish) => dish.id == null).single.name, 'Saved ', reason: 'a deleted dish keeps its saved name');
  });

  test('best sellers are the most sold; slow sellers start with dishes nobody bought', () {
    final report = _report();

    expect([for (final dish in report.bestSellers()) dish.id], ['tea', null, 'cake', 'juice']);
    final slow = report.slowSellers(_menu, 'en');
    expect([for (final dish in slow) dish.qty], everyElement(0), reason: 'unsold dishes come first');
    expect([for (final dish in slow) dish.id], isNot(contains('tea')), reason: 'a best seller is never also a slow seller');
  });

  test('when the server cannot say which dishes sold, there are no best or slow sellers', () {
    final report = _report(knowsDishes: false);

    expect(report.dishes, isNull);
    expect(report.slowSellers(_menu, 'en'), isEmpty, reason: 'not every dish should look unsold');
  });

  test('the printout lists best and slow sellers by their menu names', () {
    final lines = [
      for (final line in reportSlip(
        report: _report(),
        cafeName: 'Cafe',
        rangeLabel: 'x',
        printedAt: DateTime.utc(2026),
        l10n: l10n,
        money: (value) => value.toStringAsFixed(2),
        menu: _menu,
      ))
        if (line is SlipText) line.text else if (line is SlipPair) '${line.label} | ${line.value}',
    ];

    expect(lines, containsAllInOrder([l10n.reportBestSellers, '  ${l10n.reportDishLine(5, 'tea')} | 10.00', l10n.reportSlowSellers]));
  });

  test('the server dish list reads back', () {
    final dishes = SalesReport.dishesFromJson([
      {'id': 'tea', 'name': 'Tea', 'qty': 5, 'total': 10},
      {'id': null, 'name': 'Old soup', 'qty': 1, 'total': 4},
    ]);

    expect([for (final dish in dishes) (dish.id, dish.name, dish.qty, dish.total)], [('tea', 'Tea', 5, 10.0), (null, 'Old soup', 1, 4.0)]);
  });
}
