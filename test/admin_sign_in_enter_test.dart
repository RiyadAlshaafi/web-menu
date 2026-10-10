import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/screens/auth_screens.dart';
import 'package:menu_web_v1/screens/dev_screen.dart';
import 'package:menu_web_v1/state/cafe_store.dart';
import 'package:provider/provider.dart';

class _RecordingStore extends CafeStore {
  _RecordingStore() : super(AppDatabase.instance) {
    cafe = {'name': 'Test Cafe'};
  }

  final signIns = <(String, String)>[];

  @override
  Future<String?> signInAdmin(String email, String password, {bool remember = false}) async {
    signIns.add((email, password));
    return 'stop here';
  }
}

Widget _app(Widget home, CafeStore store) => ChangeNotifierProvider<CafeStore>.value(
      value: store,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          GoRoute(path: '/admin/login', builder: (_, _) => const Text('admin login page')),
        ]),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Enter moves from email to password, then signs in once', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _RecordingStore();
    await tester.pumpWidget(_app(const AdminAuthScreen(), store));
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {} // test font is wider, so the header row overflows

    await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Secret1!');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(store.signIns, [('a@b.com', 'Secret1!')]);
  });

  testWidgets('the paste button fills the password field from the clipboard', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'from-history'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app(const AdminAuthScreen(), _RecordingStore()));
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {} // test font is wider, so the header row overflows

    await tester.tap(find.byIcon(Icons.content_paste));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, 'from-history');
  });

  testWidgets('the dev screen has a button that leaves to the admin login', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const DevScreen(password: 'x'), _RecordingStore()));
    await tester.pump();

    await tester.tap(find.text('Leave dev screen'));
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {} // test font is wider, so the header row overflows

    expect(find.text('admin login page'), findsOneWidget);
  });
}
