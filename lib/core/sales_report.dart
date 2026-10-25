import '../models/models.dart';
import 'ledger.dart';
import 'money.dart';
import 'time_format.dart';

/// The longest range the server reports on at once, in days.
const maxReportDays = 366;

/// The Tripoli days a summary covers for the dates picked on a screen: the picked range (an
/// open start is a year back, an open end today), else this month so far. At most
/// [maxReportDays].
({DateTime from, DateTime to}) reportDaysFor(SummaryWindow window, {DateTime? now}) {
  final local = toTripoli(now ?? DateTime.now());
  final today = DateTime(local.year, local.month, local.day);
  final to = window.to ?? today;
  var from = window.from ?? DateTime(to.year - 1, to.month, to.day);
  if (from.isAfter(to)) from = to;
  if (to.difference(from).inDays > maxReportDays) from = to.subtract(const Duration(days: maxReportDays));
  return (from: from, to: to);
}

/// Sales taken with one payment type in a report's range.
class ReportMethod {
  const ReportMethod({required this.id, required this.nameEn, required this.nameAr, required this.count, required this.total});

  final String? id;
  final String nameEn;
  final String nameAr;
  final int count;
  final double total;

  String label(String locale) => locale == 'ar' && nameAr.isNotEmpty ? nameAr : nameEn;
}

/// Expenses of one type for one employee ([employeeId] null: no employee) in a report's range.
/// [typeId] is the expense type; [typeKey] is the same, or 'cafe' / 'withdrawal' for old rows of
/// a cafe without those types.
class ReportExpenseGroup {
  const ReportExpenseGroup({
    required this.typeKey,
    required this.typeId,
    required this.typeEn,
    required this.typeAr,
    required this.employeeId,
    required this.employee,
    required this.count,
    required this.total,
  });

  final String typeKey;
  final String? typeId;
  final String typeEn;
  final String typeAr;
  final String? employeeId;
  final String employee;
  final int count;
  final double total;
}

/// One dish sold in a report's range: [id] null when the dish was deleted from the menu.
class ReportDish {
  const ReportDish({required this.id, required this.name, required this.qty, required this.total});

  final String? id;

  /// The name saved on the sale; screens show the dish's current name when it is still on the menu.
  final String name;
  final int qty;
  final double total;
}

/// How many best and slow sellers the report lists.
const reportTopDishes = 5;

/// A summary line: what it is, how many and how much.
typedef ReportLine = ({String? id, String nameEn, String nameAr, int count, double total});

/// The admin's summary of a range of Tripoli calendar days ([from] and [to] both included):
/// sales, sales by payment type, voids, and expenses by type and by employee. Online it comes
/// from the server (admin_sales_report); on an offline till it is worked out from every sale
/// and expense saved on this PC ([SalesReport.fromRows]). Never from the recent sales the app
/// has loaded. Voided sales count only as voids; voided expenses never count; an edited expense
/// counts once (editing voids the old copy).
class SalesReport {
  const SalesReport({
    required this.from,
    required this.to,
    required this.salesCount,
    required this.salesTotal,
    required this.voidCount,
    required this.voidTotal,
    required this.methods,
    required this.expenses,
    this.dishes,
  });

  final DateTime from;
  final DateTime to;
  final int salesCount;
  final double salesTotal;
  final int voidCount;
  final double voidTotal;
  final List<ReportMethod> methods;
  final List<ReportExpenseGroup> expenses;

  /// Dishes sold, the most sold first; null when the server could not say (older server), so
  /// the report leaves best and slow sellers out instead of calling every dish unsold.
  final List<ReportDish>? dishes;

  /// The same report with [dishes].
  SalesReport withDishes(List<ReportDish>? dishes) => SalesReport(
        from: from,
        to: to,
        salesCount: salesCount,
        salesTotal: salesTotal,
        voidCount: voidCount,
        voidTotal: voidTotal,
        methods: methods,
        expenses: expenses,
        dishes: dishes,
      );

  /// The [count] most sold dishes.
  List<ReportDish> bestSellers({int count = reportTopDishes}) => (dishes ?? const <ReportDish>[]).take(count).toList();

  /// The [count] least sold dishes of [menu] (unsold ones first, as 0), leaving out the best
  /// sellers so a short menu does not list a dish twice. Empty when [dishes] is unknown.
  List<ReportDish> slowSellers(List<MenuItem> menu, String locale, {int count = reportTopDishes}) {
    final sold = dishes;
    if (sold == null) return const [];
    final best = {for (final dish in bestSellers()) dish.id};
    final byId = {for (final dish in sold) dish.id: dish};
    final rows = [
      for (final item in menu)
        if (!best.contains(item.id)) byId[item.id] ?? ReportDish(id: item.id, name: item.displayName(locale), qty: 0, total: 0),
    ]..sort((a, b) => a.qty != b.qty ? a.qty.compareTo(b.qty) : a.total.compareTo(b.total));
    return rows.take(count).toList();
  }

  double get expensesTotal => expenses.fold(0, (sum, group) => sum + group.total);

  /// Sales minus expenses, for the whole cafe.
  double get net => salesTotal - expensesTotal;

  bool get isEmpty => salesCount == 0 && voidCount == 0 && expenses.isEmpty;

  /// Expenses of the types and employees the filters keep, as the Wages / Expenses cards show.
  double expensesWhere({EmployeeFilter employee = const AllEmployees(), String? typeId}) => expenses
      .where((group) => employee.matchesEmployee(group.employeeId) && (typeId == null || group.typeId == typeId))
      .fold(0, (sum, group) => sum + group.total);

  /// Expenses by type, the largest first.
  List<ReportLine> get expensesByType => _merge(expenses, (group) => (group.typeKey, group.typeId, group.typeEn, group.typeAr));

  /// Expenses by employee, the largest first; the line with a null id is "no employee".
  List<ReportLine> get expensesByEmployee => _merge(expenses, (group) => (group.employeeId ?? '', group.employeeId, group.employee, group.employee));

  static List<ReportLine> _merge(List<ReportExpenseGroup> groups, (String, String?, String, String) Function(ReportExpenseGroup) by) {
    final merged = <String, ReportLine>{};
    for (final group in groups) {
      final (key, id, nameEn, nameAr) = by(group);
      final seen = merged[key];
      merged[key] = (
        id: id,
        nameEn: seen?.nameEn ?? nameEn,
        nameAr: seen?.nameAr ?? nameAr,
        count: (seen?.count ?? 0) + group.count,
        total: (seen?.total ?? 0) + group.total,
      );
    }
    return merged.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    double money(Object? value) => (value as num?)?.toDouble() ?? 0;
    int count(Object? value) => (value as num?)?.toInt() ?? 0;
    List<Map<String, dynamic>> rows(Object? value) => [
          if (value is List)
            for (final row in value)
              if (row is Map) Map<String, dynamic>.from(row),
        ];
    return SalesReport(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      salesCount: count(json['sales_count']),
      salesTotal: money(json['sales_total']),
      voidCount: count(json['void_count']),
      voidTotal: money(json['void_total']),
      methods: [
        for (final row in rows(json['by_method']))
          ReportMethod(
            id: row['id'] as String?,
            nameEn: row['name_en'] as String? ?? '',
            nameAr: row['name_ar'] as String? ?? '',
            count: count(row['count']),
            total: money(row['total']),
          ),
      ],
      expenses: [
        for (final row in rows(json['expenses']))
          ReportExpenseGroup(
            typeKey: row['type_key'] as String? ?? '',
            typeId: row['type_id'] as String?,
            typeEn: row['type_en'] as String? ?? '',
            typeAr: row['type_ar'] as String? ?? '',
            employeeId: row['employee_id'] as String?,
            employee: row['employee'] as String? ?? '',
            count: count(row['count']),
            total: money(row['total']),
          ),
      ],
    );
  }

  /// The dishes in an admin_dish_sales answer.
  static List<ReportDish> dishesFromJson(Object? value) => [
        if (value is List)
          for (final row in value)
            if (row is Map)
              ReportDish(
                id: row['id'] as String?,
                name: row['name'] as String? ?? '',
                qty: (row['qty'] as num?)?.toInt() ?? 0,
                total: (row['total'] as num?)?.toDouble() ?? 0,
              ),
      ];

  /// The same report worked out on an offline till from every sale and expense saved on it, with
  /// the server's rules (see the class comment and admin_sales_report).
  factory SalesReport.fromRows({
    required DateTime from,
    required DateTime to,
    required Iterable<Payment> payments,
    required Iterable<ShiftExpense> expenses,
    required List<PaymentType> paymentTypes,
    required List<ExpenseCategory> expenseCategories,
    required List<Cashier> staff,
    Iterable<CafeOrder>? orders,
  }) {
    bool inRange(DateTime instant) => inTripoliDateRange(instant, from: from, to: to);
    final sales = payments.where((payment) => inRange(payment.paidAt)).toList();
    final kept = sales.where((payment) => !payment.isVoided).toList();
    final voided = sales.where((payment) => payment.isVoided).toList();

    final methods = <String?, ReportMethod>{};
    for (final payment in kept) {
      final type = paymentTypes.where((item) => item.id == payment.paymentTypeId).firstOrNull;
      final seen = methods[payment.paymentTypeId];
      methods[payment.paymentTypeId] = ReportMethod(
        id: payment.paymentTypeId,
        nameEn: seen?.nameEn ?? type?.nameEn ?? payment.paymentTypeNameEn ?? '',
        nameAr: seen?.nameAr ?? type?.nameAr ?? payment.paymentTypeNameAr ?? '',
        count: (seen?.count ?? 0) + 1,
        total: (seen?.total ?? 0) + payment.totalDue,
      );
    }

    String? legacyType(bool paidToCafe) =>
        expenseCategories.where((item) => item.nameEn == (paidToCafe ? 'Café Expense' : 'Cash Withdrawal')).firstOrNull?.id;
    final groups = <(String, String?), ReportExpenseGroup>{};
    for (final expense in expenses) {
      if (expense.voided || !inRange(expense.createdAt)) continue;
      final typeId = expense.categoryId ?? legacyType(expense.paidToCafe);
      final typeKey = typeId ?? (expense.paidToCafe ? 'cafe' : 'withdrawal');
      final type = expenseCategories.where((item) => item.id == typeId).firstOrNull;
      final employeeId = expenseEmployeeId(expense);
      final person = staff.where((member) => member.id == employeeId).firstOrNull;
      final seen = groups[(typeKey, employeeId)];
      groups[(typeKey, employeeId)] = ReportExpenseGroup(
        typeKey: typeKey,
        typeId: typeId,
        typeEn: seen?.typeEn ?? type?.nameEn ?? expense.categoryNameEn ?? (expense.paidToCafe ? 'Café Expense' : 'Cash Withdrawal'),
        typeAr: seen?.typeAr ?? type?.nameAr ?? expense.categoryNameAr ?? '',
        employeeId: employeeId,
        employee: seen?.employee ?? person?.name ?? expense.employeeName,
        count: (seen?.count ?? 0) + 1,
        total: (seen?.total ?? 0) + expense.amount,
      );
    }

    return SalesReport(
      from: from,
      to: to,
      salesCount: kept.length,
      salesTotal: kept.fold(0, (sum, payment) => sum + payment.totalDue),
      voidCount: voided.length,
      voidTotal: voided.fold(0, (sum, payment) => sum + payment.totalDue),
      methods: methods.values.toList()..sort((a, b) => b.total.compareTo(a.total)),
      expenses: groups.values.toList()..sort((a, b) => b.total.compareTo(a.total)),
      dishes: orders == null ? null : dishesSold(orders, kept),
    );
  }

  /// Dishes on the orders of the [kept] sales, each order once, most sold first: the same
  /// rules as admin_dish_sales.
  static List<ReportDish> dishesSold(Iterable<CafeOrder> orders, Iterable<Payment> kept) {
    final paid = {for (final payment in kept) payment.orderId};
    final dishes = <String, ReportDish>{};
    for (final order in orders) {
      if (!paid.contains(order.id)) continue;
      for (final line in order.lines) {
        final id = line.menuItemId.isEmpty ? null : line.menuItemId;
        final key = id ?? '#${line.name}';
        final seen = dishes[key];
        dishes[key] = ReportDish(
          id: id,
          name: seen?.name ?? line.name,
          qty: (seen?.qty ?? 0) + line.qty,
          total: (seen?.total ?? 0) + line.total,
        );
      }
    }
    return dishes.values.toList()..sort((a, b) => a.qty != b.qty ? b.qty.compareTo(a.qty) : b.total.compareTo(a.total));
  }
}
