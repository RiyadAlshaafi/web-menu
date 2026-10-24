import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/ledger.dart';
import 'package:menu_web_v1/core/sales_report.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/models/models.dart';
import 'package:menu_web_v1/printing/report_print.dart';
import 'package:menu_web_v1/printing/slip.dart';
import 'package:menu_web_v1/widgets/sales_report_dialog.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

Payment _sale(String id, double total, DateTime paidAt, {String? type, bool voided = false}) => Payment(
      id: id,
      orderId: 'o-$id',
      tableId: '',
      totalDue: total,
      cashReceived: total,
      changeDue: 0,
      cashierId: 'c1',
      shiftId: 's1',
      paidAt: paidAt,
      paymentTypeId: type,
      voidedAt: voided ? paidAt : null,
    );

ShiftExpense _expense(String id, double amount, DateTime at,
        {String? category, bool paidToCafe = true, String? paidTo, String? staff, bool voided = false, String? editedFrom}) =>
    ShiftExpense(
      id: id,
      shiftId: 's1',
      cashierId: 'c1',
      paidToCafe: paidToCafe,
      paidToCashierId: paidTo,
      staffId: staff,
      staffName: staff == null ? '' : 'Saved $staff',
      amount: amount,
      description: id,
      createdAt: at,
      categoryId: category,
      voided: voided,
      editedFrom: editedFrom,
    );

final _types = [
  PaymentType(id: 'cash', nameEn: 'Cash', nameAr: 'نقداً', enabled: true, sortOrder: 0),
  PaymentType(id: 'card', nameEn: 'Card', nameAr: 'بطاقة', enabled: true, sortOrder: 1),
];
final _categories = [
  ExpenseCategory(id: 'cafe', nameEn: 'Café Expense', nameAr: 'مصروف', enabled: true, sortOrder: 0),
  ExpenseCategory(id: 'wd', nameEn: 'Cash Withdrawal', nameAr: 'سحب', enabled: true, sortOrder: 1),
];
final _staff = [Cashier(id: 'c1', name: 'Sara', initials: 'S'), Cashier(id: 'chef', name: 'Omar', initials: 'O', role: StaffJob.chef)];

/// Tripoli is UTC+2: 21:30 UTC on the 24th is 23:30 there (the 24th), 22:30 UTC is 00:30 on the
/// 25th, and 22:10 UTC on the 23rd is 00:10 on the 24th.
SalesReport _report(DateTime from, DateTime to) => SalesReport.fromRows(
      from: from,
      to: to,
      payments: [
        _sale('late', 20, DateTime.utc(2026, 10, 24, 21, 30), type: 'cash'),
        _sale('next', 8, DateTime.utc(2026, 10, 24, 22, 30), type: 'cash'),
        _sale('early', 15, DateTime.utc(2026, 10, 23, 22, 10), type: 'card'),
        _sale('void', 50, DateTime.utc(2026, 10, 24, 10), type: 'cash', voided: true),
      ],
      expenses: [
        _expense('milk', 10, DateTime.utc(2026, 10, 24, 9), category: 'cafe'),
        _expense('old row', 5, DateTime.utc(2026, 10, 24, 9, 30)),
        _expense('advance', 30, DateTime.utc(2026, 10, 24, 11), category: 'wd', paidToCafe: false, paidTo: 'c1'),
        _expense('voided', 99, DateTime.utc(2026, 10, 24, 12), category: 'cafe', voided: true),
        _expense('chef', 40, DateTime.utc(2026, 10, 24, 13), category: 'cafe', staff: 'chef', voided: true),
        _expense('chef fixed', 45, DateTime.utc(2026, 10, 24, 13, 5), category: 'cafe', staff: 'chef', editedFrom: 'chef'),
        _expense('gone', 12, DateTime.utc(2026, 10, 24, 14), category: 'cafe', staff: 'removed'),
        _expense('next day', 7, DateTime.utc(2026, 10, 24, 22, 30), category: 'cafe'),
      ],
      paymentTypes: _types,
      expenseCategories: _categories,
      staff: _staff,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final day = DateTime(2026, 10, 24);

  group('report numbers (offline till, same rules as the server)', () {
    test('a day is a Tripoli day: 23:30 and 00:10 count, 00:30 is the next day', () {
      final report = _report(day, day);
      expect(report.salesCount, 2);
      expect(report.salesTotal, 35);
      expect(_report(DateTime(2026, 10, 25), DateTime(2026, 10, 25)).salesTotal, 8);
    });

    test('voided sales count only as voids', () {
      final report = _report(day, day);
      expect(report.voidCount, 1);
      expect(report.voidTotal, 50);
      expect(report.methods.map((m) => (m.id, m.count, m.total)), [('cash', 1, 20.0), ('card', 1, 15.0)]);
    });

    test('voided expenses never count and an edited expense counts once', () {
      final report = _report(day, day);
      expect(report.expensesTotal, 10 + 5 + 30 + 45 + 12);
      expect(report.expensesByEmployee.firstWhere((line) => line.id == 'chef').total, 45);
    });

    test('expenses by type map old rows to the cafe type; by employee keeps removed staff by saved name', () {
      final report = _report(day, day);
      expect({for (final line in report.expensesByType) line.nameEn: line.total}, {'Café Expense': 72.0, 'Cash Withdrawal': 30.0});
      final people = {for (final line in report.expensesByEmployee) line.id: (line.nameEn, line.total)};
      expect(people['c1'], ('Sara', 30.0));
      expect(people['chef'], ('Omar', 45.0));
      expect(people['removed'], ('Saved removed', 12.0));
      expect(people[null], ('', 15.0), reason: 'no employee');
      expect(report.net, 35 - 102);
    });

    test('the card filters pick out an employee, no employee, or a type', () {
      final report = _report(day, day);
      expect(report.expensesWhere(employee: const OneEmployee('c1')), 30);
      expect(report.expensesWhere(employee: const NoEmployee()), 15);
      expect(report.expensesWhere(typeId: 'cafe'), 72);
      expect(report.expensesWhere(employee: const OneEmployee('chef'), typeId: 'wd'), 0);
    });

    test('an empty range is all zeros', () {
      final report = _report(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      expect(report.isEmpty, isTrue);
      expect((report.salesCount, report.salesTotal, report.voidCount, report.expensesTotal, report.net), (0, 0.0, 0, 0.0, 0.0));
    });

    test('the server report reads back the same way', () {
      final report = SalesReport.fromJson({
        'ok': true,
        'from': '2026-10-24',
        'to': '2026-10-24',
        'sales_count': 2,
        'sales_total': 35,
        'void_count': 1,
        'void_total': 50,
        'by_method': [
          {'id': 'cash', 'name_en': 'Cash', 'name_ar': 'نقداً', 'count': 1, 'total': 20},
        ],
        'expenses': [
          {'type_key': 'cafe', 'type_id': 'cafe', 'type_en': 'Café Expense', 'type_ar': 'مصروف', 'employee_id': null, 'employee': '', 'count': 2, 'total': 15},
          {'type_key': 'wd', 'type_id': 'wd', 'type_en': 'Cash Withdrawal', 'type_ar': 'سحب', 'employee_id': 'c1', 'employee': 'Sara', 'count': 1, 'total': 30.5},
        ],
      });
      expect(report.from, DateTime(2026, 10, 24));
      expect(report.salesTotal, 35);
      expect(report.expensesTotal, 45.5);
      expect(report.expensesWhere(employee: const OneEmployee('c1')), 30.5);
      expect(report.methods.single.label('ar'), 'نقداً');
    });
  });

  group('report days', () {
    final now = DateTime.utc(2026, 10, 24, 22, 30); // 00:30 on the 25th in Tripoli

    test('today is the Tripoli day, also just after local midnight', () {
      expect(reportRange(ReportRangeKind.today, now: now), (from: DateTime(2026, 10, 25), to: DateTime(2026, 10, 25)));
    });

    test('a month is every day of it, this month only up to today', () {
      expect(reportRange(ReportRangeKind.month, now: now, month: DateTime(2026, 9)), (from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)));
      expect(reportRange(ReportRangeKind.month, now: now, month: DateTime(2026, 10)), (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 25)));
      expect(reportRange(ReportRangeKind.month, now: now, month: DateTime(2026, 2))?.to, DateTime(2026, 2, 28));
    });

    test('from–to needs both days in order', () {
      expect(reportRange(ReportRangeKind.custom, now: now, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 3)),
          (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 3)));
      expect(reportRange(ReportRangeKind.custom, now: now, from: DateTime(2026, 10, 1)), isNull);
      expect(reportRange(ReportRangeKind.custom, now: now, from: DateTime(2026, 10, 3), to: DateTime(2026, 10, 1)), isNull);
    });

    test('the wages cards cover the picked days, else this month, at most a year', () {
      SummaryWindow picked(DateTime? from, DateTime? to) => SummaryWindow(from: from, to: to, monthly: false);
      expect(reportDaysFor(summaryWindow(now: now), now: now), (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 25)));
      expect(reportDaysFor(picked(DateTime(2026, 10, 1), DateTime(2026, 10, 24)), now: now), (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 24)));
      expect(reportDaysFor(picked(DateTime(2026, 10, 3), null), now: now).to, DateTime(2026, 10, 25), reason: 'an open end is today');
      expect(reportDaysFor(picked(null, DateTime(2026, 10, 24)), now: now).from, DateTime(2025, 10, 24));
      expect(reportDaysFor(picked(DateTime(2024, 1, 1), DateTime(2026, 10, 24)), now: now).from, DateTime(2025, 10, 23));
    });
  });

  group('the report printout', () {
    List<String> texts(List<SlipLine> lines) => [
          for (final line in lines)
            switch (line) {
              SlipText(:final text) => text,
              SlipPair(:final label, :final value) => '$label | $value',
              _ => null,
            },
        ].whereType<String>().toList();

    String money(double value) => value.toStringAsFixed(2);

    test('is a summary: sales and payment types, voids, expenses by type and employee, net', () {
      final lines = texts(reportSlip(
        report: _report(day, day),
        cafeName: 'Caffè Roma',
        rangeLabel: l10n.reportToday('2026-10-24'),
        printedAt: DateTime.utc(2026, 10, 24, 20),
        l10n: l10n,
        money: money,
      ));
      expect(lines.take(3), ['Caffè Roma', l10n.reportTitle, l10n.reportToday('2026-10-24')]);
      expect(
        lines,
        containsAll([
          '${l10n.reportSales(2)} | 35.00',
          '  ${l10n.reportCountOf('Cash', 1)} | 20.00',
          '  ${l10n.reportCountOf('Card', 1)} | 15.00',
          '${l10n.reportVoids(1)} | 50.00',
          '${l10n.reportExpenses} | 102.00',
          '  ${l10n.reportCountOf('Café Expense', 4)} | 72.00',
          '  ${l10n.reportCountOf(l10n.expenseNoEmployee, 2)} | 15.00',
          '  ${l10n.reportCountOf('Omar', 1)} | 45.00',
          '${l10n.reportNet} | -67.00',
        ]),
      );
      expect(lines.where((line) => line.contains('milk')), isEmpty, reason: 'no single receipts or expenses');
    });

    test('an empty range says so and prints zeros', () {
      final lines = texts(reportSlip(
        report: _report(DateTime(2026, 1, 1), DateTime(2026, 1, 1)),
        cafeName: 'Caffè Roma',
        rangeLabel: '2026-01-01',
        printedAt: DateTime.utc(2026, 1, 2),
        l10n: l10n,
        money: money,
      ));
      expect(lines, containsAll([l10n.reportEmpty, '${l10n.reportSales(0)} | 0.00', '${l10n.reportNet} | 0.00']));
    });

    for (final (mm, width) in [(58, '161.5748'), (80, '226.77165')]) {
      test('is laid out for $mm mm paper', () async {
        final bytes = await slipPdf(
          reportSlip(report: _report(day, day), cafeName: 'Caffè Roma', rangeLabel: 'x', printedAt: DateTime.utc(2026), l10n: l10n, money: money),
          paperMm: mm,
        );
        expect(RegExp(r'/MediaBox\[0 0 ([0-9.]+)').firstMatch(String.fromCharCodes(bytes))!.group(1), width);
      });
    }
  });
}
