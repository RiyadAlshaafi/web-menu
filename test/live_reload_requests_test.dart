import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every request the app sends to Supabase, as "GET restaurants" or "POST rpc/has_any_admin".
final requests = <String>[];

http.Response _answer(http.Request request) {
  final path = request.url.path.replaceFirst('/rest/v1/', '');
  requests.add('${request.method} $path');
  const json = {'content-type': 'application/json'};
  final body = switch (path) {
    'rpc/has_any_admin' => 'true',
    'restaurants' => '{"name":"Cafe"}',
    _ => '[]',
  };
  return http.Response(body, 200, headers: json, request: request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-key',
      httpClient: MockClient((request) async => _answer(request)),
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
    );
    db.useInitialisedClient();
    db.restaurantId = 'cafe-1';
    db.cashierToken = 'till-token';
  });

  setUp(requests.clear);

  test('a sales ping reloads only sales data, with far fewer requests', () async {
    await db.refreshFromDisk();
    expect(db.loadedOnce, isTrue);

    requests.clear();
    await db.refreshFromDisk(liveOnly: true);
    final live = List.of(requests);

    requests.clear();
    await db.refreshFromDisk(liveOnly: true, salesOnly: true);
    final sales = List.of(requests);

    expect(sales.length, lessThan(live.length), reason: 'live: $live\nsales: $sales');
    for (final skipped in ['GET restaurants', 'GET menu_items', 'GET payment_types', 'GET expense_categories', 'POST rpc/has_any_admin']) {
      expect(sales, isNot(contains(skipped)), reason: '$skipped is not sales data');
    }
    for (final kept in ['GET orders', 'GET payments', 'GET shifts', 'GET carts', 'GET dining_tables']) {
      expect(sales.any((r) => r.startsWith(kept)), isTrue, reason: '$kept must still reload: $sales');
    }
    // ignore: avoid_print
    print('requests per reload: live ${live.length}, sales-only ${sales.length}');
  });

  test('a menu change still reloads the menu', () async {
    await db.refreshFromDisk(liveOnly: true);
    expect(requests, contains('GET menu_items'));
  });
}
