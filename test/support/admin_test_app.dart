import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/screens/admin_receipt_editor.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';
import 'package:provider/provider.dart';

/// The pages admin screens link to. Each shows its own path, so a test can see where a tap went.
const linkedPages = ['/admin/sales', '/admin/wages', '/admin/password', '/admin/login', '/login'];

/// Shows [screen] at `/` on a large desktop window, with the app's theme, both languages and the
/// pages it links to.
Future<void> pumpAdminScreen(WidgetTester tester, Widget screen, CafeStore store, {Size size = const Size(1600, 1400)}) async {
  // Drawing a PDF page needs the printing plugin, and its spinner never settles: show a label.
  ReceiptEditorCard.preview = testPrintPreview;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<CafeStore>.value(
      value: store,
      child: MaterialApp.router(
        theme: CafeTheme.light,
        locale: Locale(store.locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => Scaffold(body: screen)),
          for (final path in linkedPages) GoRoute(path: path, builder: (_, _) => Text('page $path')),
        ]),
      ),
    ),
  );
  await tester.pump();
  ignoreOverflow(tester);
}

/// The test font is wider than the real one, so some rows overflow. Those errors are dropped;
/// anything else still fails the test.
void ignoreOverflow(WidgetTester tester) {
  for (Object? error = tester.takeException(); error != null; error = tester.takeException()) {
    if (error is FlutterError && error.toString().contains('overflowed')) continue;
    throw error;
  }
}

/// Taps [finder] after scrolling it into view, then lets the frame settle.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  ignoreOverflow(tester);
}

/// Stands in for a printout preview: names it and its page width in mm (58 mm paper is a 57 mm
/// roll), and records each preview built so a test can lay it out.
final builtPreviews = <({String label, double widthMm, Future<Uint8List> Function() build})>[];

Widget testPrintPreview({required String label, required PdfPageFormat format, required Future<Uint8List> Function() build}) {
  final widthMm = (format.width / PdfPageFormat.mm).roundToDouble();
  builtPreviews.add((label: label, widthMm: widthMm, build: build));
  return SizedBox(width: 200, height: 40, child: Text('preview $label ${widthMm.round()}mm'));
}
