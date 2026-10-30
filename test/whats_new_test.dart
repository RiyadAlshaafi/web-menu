import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/update/whats_new.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const version = '2.8.5';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {'appName': 'Cafe POS', 'packageName': 'cafe_pos', 'version': version, 'buildNumber': '48'},
    );
  });

  // Each call starts from an empty screen, so the gate is new like on a real start.
  Future<void> pumpGate(WidgetTester tester, {required WhatsNewAudience audience, required bool updated}) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WhatsNewGate(key: ValueKey(audience), audience: audience, updated: updated, child: const Text('screen'))),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('every version with notes has them in English and Arabic', () {
    for (final entry in releaseNotes.entries) {
      expect(entry.value.keys, containsAll(['en', 'ar']), reason: entry.key);
    }
    expect(releaseNotesFor(version, 'fr'), same(releaseNotes[version]!['en']), reason: 'other languages fall back to English');
    expect(releaseNotesFor('0.0.1', 'en'), isNull);
  });

  testWidgets('an updated till sees the notes once, with what was added and fixed', (tester) async {
    await pumpGate(tester, audience: WhatsNewAudience.till, updated: true);
    expect(find.text("What's new in $version"), findsOneWidget);
    for (final line in [...releaseNotes[version]!['en']!.added, ...releaseNotes[version]!['en']!.fixed]) {
      expect(find.text(line), findsOneWidget);
    }
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text("What's new in $version"), findsNothing);

    await pumpGate(tester, audience: WhatsNewAudience.till, updated: true);
    expect(find.text("What's new in $version"), findsNothing, reason: 'shown once per version');
  });

  testWidgets('the admin gets their own once, after the till has seen it', (tester) async {
    await pumpGate(tester, audience: WhatsNewAudience.till, updated: true);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await pumpGate(tester, audience: WhatsNewAudience.admin, updated: true);
    expect(find.text("What's new in $version"), findsOneWidget);
  });

  testWidgets('a fresh install shows nothing, now or later for this version', (tester) async {
    await pumpGate(tester, audience: WhatsNewAudience.till, updated: false);
    expect(find.text("What's new in $version"), findsNothing);
    await pumpGate(tester, audience: WhatsNewAudience.till, updated: true);
    expect(find.text("What's new in $version"), findsNothing);
    expect(find.text('screen'), findsOneWidget);
  });
}
