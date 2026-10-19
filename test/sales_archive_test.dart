import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/data/sales_archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _json = {'content-type': 'application/json'};

/// One archive file as tool/archive_months.sh writes it (rows in the database's column format).
Map<String, Object?> _file(String paymentId, String paidAt, double total) => {
  'format': 'tawla-archive-v1',
  'payments': [
    {
      'id': paymentId,
      'order_id': 'order-$paymentId',
      'shift_id': 'shift-$paymentId',
      'total_due': total,
      'cash_received': total,
      'change_due': 0,
      'paid_at': paidAt,
      'is_takeout': true,
    },
  ],
  'payment_method_changes': <Object>[],
  'orders': [
    {'id': 'order-$paymentId', 'status': 'paid', 'created_at': paidAt, 'service_type': 'takeout'},
  ],
  'order_lines': [
    {'id': 'line-$paymentId', 'order_id': 'order-$paymentId', 'name': 'Tea', 'qty': 2, 'unit_price': total / 2},
  ],
  'shifts': [
    {'id': 'shift-$paymentId', 'opened_at': paidAt, 'closed_at': paidAt, 'opening_cash': 0, 'cash_sales': total},
  ],
  'shift_expenses': [
    {'id': 'expense-$paymentId', 'shift_id': 'shift-$paymentId', 'amount': 1, 'description': 'milk', 'created_at': paidAt},
  ],
};

final workerCalls = <http.Request>[];
var workerFails = false;

final worker = MockClient((request) async {
  workerCalls.add(request);
  if (workerFails) return http.Response('{}', 500, request: request);
  final body = switch (request.url.path) {
    '/api/archive/2026-05/0' => _file('p1', '2026-05-10T09:00:00Z', 10),
    '/api/archive/2026-05/1' => _file('p2', '2026-05-28T09:00:00Z', 6),
    _ => null,
  };
  if (body == null) return http.Response('{}', 404, request: request);
  return http.Response(jsonEncode(body), 200, headers: {..._json, 'x-archive-parts': '2'}, request: request);
});

final supabase = MockClient((request) async {
  final path = request.url.path.replaceFirst('/rest/v1/', '');
  final body = switch (path) {
    'archived_months' => '[{"year_month":"2026-05"}]',
    'restaurants' => '{"name":"Cafe"}',
    'rpc/has_any_admin' => 'true',
    _ => '[]',
  };
  return http.Response(body, 200, headers: _json, request: request);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
      httpClient: supabase,
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
    );
    db.useInitialisedClient();
    db.restaurantId = 'cafe-1';
    db.cashierToken = 'till-token';
    await db.refreshFromDisk();
  });

  setUp(() {
    workerCalls.clear();
    workerFails = false;
    db.salesArchive = SalesArchiveClient(client: worker, base: Uri.parse('https://staff.test'));
    db.archiveTokenOverride = () => 'admin.access.token';
  });

  test('months are counted in Tripoli time', () {
    expect(monthsBetween(DateTime.utc(2026, 4, 30, 23), DateTime.utc(2026, 6, 2)), ['2026-05', '2026-06']);
    expect(monthsBetween(DateTime.utc(2026, 11, 15), DateTime.utc(2027, 1, 3)), ['2026-11', '2026-12', '2027-01']);
  });

  test('picking old dates shows the archived sales, orders, shifts and expenses of that window', () async {
    await db.alignSalesWindow(from: DateTime.utc(2026, 5, 1), to: DateTime.utc(2026, 5, 20));

    expect(db.salesArchiveFailed, isFalse);
    expect(db.payments.map((p) => p.id), ['p1'], reason: 'p2 (May 28) is outside the chosen dates');
    expect(db.payments.single.totalDue, 10);
    expect(db.orders.where((o) => o.id == 'order-p1').single.lines.single.qty, 2);
    expect(db.shifts.map((s) => s.id), contains('shift-p1'));
    expect(db.expenses.map((e) => e.id), contains('expense-p1'));
    expect(workerCalls.map((r) => r.url.path), ['/api/archive/2026-05/0', '/api/archive/2026-05/1']);
    expect(workerCalls.first.headers['Authorization'], 'Bearer admin.access.token');
  });

  test('a month is fetched once and both parts are merged', () async {
    await db.alignSalesWindow(from: DateTime.utc(2026, 5, 1), to: DateTime.utc(2026, 5, 31));
    expect(db.payments.map((p) => p.id), ['p2', 'p1'], reason: 'newest first, like live sales');
    workerCalls.clear();
    await db.alignSalesWindow(from: DateTime.utc(2026, 5, 2), to: DateTime.utc(2026, 5, 31));
    expect(workerCalls, isEmpty, reason: 'archived files never change, so they are kept');
  });

  test('a failed archive keeps the screen working and says so', () async {
    workerFails = true;
    db.salesArchive = SalesArchiveClient(client: worker, base: Uri.parse('https://staff.test'));
    await db.alignSalesWindow(from: DateTime.utc(2026, 5, 3), to: DateTime.utc(2026, 5, 30));
    expect(db.salesArchiveFailed, isTrue);
    expect(db.payments, isEmpty);
  });

  test('a cashier (no admin sign-in) never calls the archive', () async {
    db.archiveTokenOverride = () => null;
    await db.alignSalesWindow(from: DateTime.utc(2026, 5, 4), to: DateTime.utc(2026, 5, 30));
    expect(workerCalls, isEmpty);
    expect(db.salesArchiveFailed, isFalse);
  });
}
