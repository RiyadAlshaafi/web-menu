import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/platform/app_window.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';
import 'package:menu_web_v1/widgets/app_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cafe_pos/window');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    AppWindow.debugSupported = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpButton(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: CafeTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: FullscreenButton())),
        ),
      );

  testWidgets('the full-screen button is hidden where there is no till window', (tester) async {
    AppWindow.debugSupported = false;
    await pumpButton(tester);
    expect(find.byType(HeaderAction), findsNothing);
  });

  testWidgets('a tap switches the till window out of full screen and back', (tester) async {
    AppWindow.debugSupported = true;
    var fullscreen = true;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'setFullscreen') fullscreen = call.arguments as bool;
      return fullscreen;
    });

    await pumpButton(tester);
    await tester.pump();
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget, reason: 'the till opens full screen');

    await tester.tap(find.byType(HeaderAction));
    await tester.pump();
    expect(calls.last.method, 'setFullscreen');
    expect(calls.last.arguments, isFalse);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);

    await tester.tap(find.byType(HeaderAction));
    await tester.pump();
    expect(calls.last.arguments, isTrue);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
  });
}
