import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/widgets/cafe_date_picker.dart';
import 'package:menu_web_v1/widgets/tawla_ui.dart';

Future<void> openPicker(
  WidgetTester tester,
  Widget Function(BuildContext) build, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(child: Builder(builder: build)),
      ),
    ),
  );
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'year and month navigation keep the selection until a day is applied',
    (tester) async {
      DateTime? applied;
      await openPicker(
        tester,
        (_) => DateBox(
          label: 'From',
          value: DateTime(2024, 11, 12),
          onPicked: (date) => applied = date,
        ),
      );
      await tapLabel(tester, 'From');
      await tapLabel(tester, '2024');
      await tapLabel(tester, '2022');
      await tapLabel(tester, 'November');
      await tapLabel(tester, 'Feb');
      expect(applied, isNull);
      await tapLabel(tester, '14');
      await tapLabel(tester, 'Apply');
      expect(applied, DateTime(2022, 2, 14));
    },
  );

  testWidgets('cancel preserves a filter and clear removes it', (tester) async {
    final original = DateTime(2024, 11, 12);
    DateTime? applied = original;
    await openPicker(
      tester,
      (_) => DateBox(
        label: 'From',
        value: original,
        onPicked: (date) => applied = date,
      ),
    );
    await tapLabel(tester, 'From');
    await tapLabel(tester, '14');
    await tapLabel(tester, 'Cancel');
    expect(applied, original);
    await tapLabel(tester, 'From');
    await tapLabel(tester, 'Clear date');
    expect(applied, isNull);
  });

  testWidgets('range selection can span months', (tester) async {
    CafeDateSelection? applied;
    await openPicker(
      tester,
      (context) => TextButton(
        onPressed: () async {
          applied = await showCafeDatePicker(
            context: context,
            range: DateTimeRange(
              start: DateTime(2024, 11, 9),
              end: DateTime(2024, 11, 15),
            ),
          );
        },
        child: const Text('Open'),
      ),
    );
    await tapLabel(tester, 'Open');
    await tapLabel(tester, '20');
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tapLabel(tester, '3');
    await tapLabel(tester, 'Apply');
    expect(applied, (
      start: DateTime(2024, 11, 20),
      end: DateTime(2024, 12, 3),
    ));
  });

  testWidgets('Arabic picker fits a narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openPicker(
      tester,
      (_) =>
          DateBox(label: 'من', value: DateTime(2024, 11, 12), onPicked: (_) {}),
      locale: const Locale('ar'),
    );
    await tapLabel(tester, 'من');
    await tapLabel(tester, 'نوفمبر');
    expect(tester.takeException(), isNull);
    expect(find.text('العودة إلى التقويم'), findsOneWidget);
  });
}
