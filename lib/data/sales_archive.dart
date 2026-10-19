import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/money.dart' show toTripoli;

/// Where the archive Worker (archive-worker/) answers. The web app uses its own address, which
/// the Worker shares, so the browser needs no CORS; the Windows app calls the staff site.
const _archiveSite = String.fromEnvironment('ARCHIVE_URL', defaultValue: 'https://staff.tawla.ly');

Uri archiveBase() => kIsWeb ? Uri.base.replace(path: '', query: null, fragment: null) : Uri.parse(_archiveSite);

/// The months ('YYYY-MM', Tripoli time) that the instants [from]..[to] touch, oldest first.
List<String> monthsBetween(DateTime from, DateTime to) {
  final start = toTripoli(from);
  final end = toTripoli(to);
  final months = <String>[];
  var year = start.year;
  var month = start.month;
  while (year < end.year || (year == end.year && month <= end.month)) {
    months.add('$year-${month.toString().padLeft(2, '0')}');
    month++;
    if (month == 13) {
      month = 1;
      year++;
    }
  }
  return months;
}

/// The rows of archived months, in the database's own column format (one file per part).
class ArchivedSales {
  final payments = <Map<String, dynamic>>[];
  final changes = <Map<String, dynamic>>[];

  /// Orders with their lines under 'order_lines', as the live query returns them.
  final orders = <Map<String, dynamic>>[];
  final shifts = <Map<String, dynamic>>[];
  final expenses = <Map<String, dynamic>>[];

  /// Adds one archive file ({"format": "tawla-archive-v1", ...}).
  void addFile(Map<String, dynamic> file) {
    if (file['format'] != 'tawla-archive-v1') throw const FormatException('unknown archive format');
    List<Map<String, dynamic>> rows(String key) => [
      for (final row in (file[key] as List? ?? const [])) Map<String, dynamic>.from(row as Map),
    ];
    final lines = <String, List<Map<String, dynamic>>>{};
    for (final line in rows('order_lines')) {
      lines.putIfAbsent(line['order_id'] as String, () => []).add(line);
    }
    payments.addAll(rows('payments'));
    changes.addAll(rows('payment_method_changes'));
    orders.addAll([for (final order in rows('orders')) {...order, 'order_lines': lines[order['id']] ?? const []}]);
    shifts.addAll(rows('shifts'));
    expenses.addAll(rows('shift_expenses'));
  }
}

/// Reads archived months from the Worker with the admin's sign-in. Files never change, so each
/// month is fetched once per app run.
class SalesArchiveClient {
  SalesArchiveClient({http.Client? client, this.base}) : _given = client;

  final http.Client? _given;

  /// Made on first use, so starting the app opens no connection.
  late final http.Client _client = _given ?? http.Client();
  /// The Worker address; [archiveBase] when null.
  final Uri? base;
  final _months = <String, Future<ArchivedSales>>{};

  /// Every part of [month] for the cafe whose admin holds [accessToken].
  Future<ArchivedSales> month(String month, String accessToken) {
    final cached = _months[month];
    if (cached != null) return cached;
    final loading = _load(month, accessToken);
    _months[month] = loading;
    // A failed load is tried again next time.
    loading.catchError((Object _) {
      _months.remove(month);
      return ArchivedSales();
    });
    return loading;
  }

  /// Forgets loaded months (sign-out, another cafe).
  void clear() => _months.clear();

  Future<ArchivedSales> _load(String month, String accessToken) async {
    final sales = ArchivedSales();
    var parts = 1;
    for (var part = 0; part < parts; part++) {
      final url = (base ?? archiveBase()).resolve('/api/archive/$month/$part');
      final response = await _client.get(url, headers: {'Authorization': 'Bearer $accessToken'});
      if (response.statusCode != 200) {
        throw http.ClientException('archive $month part $part: HTTP ${response.statusCode}', url);
      }
      parts = int.tryParse(response.headers['x-archive-parts'] ?? '') ?? 1;
      sales.addFile(Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map));
    }
    return sales;
  }
}
