import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/money.dart';
import 'package:menu_web_v1/core/sales_report.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/printing/report_print.dart';
import 'package:menu_web_v1/printing/slip.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/widgets/sales_report_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

/// Answers the report as the server would, and records the days asked for.
class _ReportStore extends CafeStore {
  _ReportStore() : super(AppDatabase.instance) {
    cafe = {'name': 'Caffè Roma'};
  }

  String? error;
  final asked = <(DateTime, DateTime)>[];

  @override
  Future<({SalesReport? report, String? error})> salesReport(DateTime from, DateTime to) async {
    asked.add((from, to));
    if (error != null) return (report: null, error: error);
    return (
      report: SalesReport(from: from, to: to, salesCount: 3, salesTotal: 42, voidCount: 0, voidTotal: 0, methods: const [], expenses: const []),
      error: null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<List<SlipLine>> sent;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    ReportPrinter.send = (lines, name) async {
      sent.add(lines);
      return ReportOutput.preview;
    };
  });
  tearDown(() => ReportPrinter.send = ReportPrinter.sendToTill);

  Future<void> open(WidgetTester tester, CafeStore store) async {
    await pumpAdminScreen(tester, const Center(child: PrintReportButton()), store);
    await tapVisible(tester, find.text(l10n.reportButton));
  }

  testWidgets('without a cashier printer the admin is told it opens the print preview', (tester) async {
    await open(tester, _ReportStore());

    expect(find.text(l10n.reportTitle), findsOneWidget);
    expect(find.text(l10n.reportGoesToPreview), findsOneWidget);
    expect(find.text(l10n.reportTripoliNote), findsOneWidget);
  });

  testWidgets('today prints the server totals for today in Tripoli time', (tester) async {
    final store = _ReportStore();
    await open(tester, store);

    await tapVisible(tester, find.text(l10n.reportPrint));

    final local = toTripoli(DateTime.now());
    final today = DateTime(local.year, local.month, local.day);
    expect(store.asked, [(today, today)]);
    expect(sent, hasLength(1));
    final texts = [for (final line in sent.single) if (line is SlipPair) '${line.label} | ${line.value}'];
    expect(texts, contains('${l10n.reportSales(3)} | ${store.currency.format(42)}'));
    expect(find.text(l10n.reportTitle), findsNothing, reason: 'the dialog closes');
  });

  testWidgets('a month covers it from the 1st', (tester) async {
    final store = _ReportStore();
    await open(tester, store);

    await tapVisible(tester, find.text(l10n.reportRangeMonth));
    await tapVisible(tester, find.text(l10n.reportPrint));

    expect(store.asked.single.$1.day, 1);
    expect(sent, hasLength(1));
  });

  testWidgets('from–to needs both days; nothing is fetched until then', (tester) async {
    final store = _ReportStore();
    await open(tester, store);

    await tapVisible(tester, find.text(l10n.reportRangeCustom));
    await tapVisible(tester, find.text(l10n.reportPrint));

    expect(find.text(l10n.reportPickDays), findsOneWidget);
    expect(store.asked, isEmpty);
    expect(sent, isEmpty);
  });

  testWidgets('when the totals can\'t be fetched it says why and prints nothing', (tester) async {
    final store = _ReportStore()..error = 'network';
    await open(tester, store);

    await tapVisible(tester, find.text(l10n.reportPrint));

    expect(find.textContaining(l10n.reportFailed('').trim()), findsOneWidget);
    expect(sent, isEmpty);
    expect(find.text(l10n.reportTitle), findsOneWidget, reason: 'the dialog stays open');
  });
}
