import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/screens/admin_feedback_card.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

class _Store extends CafeStore {
  _Store() : super(AppDatabase.instance);
}

/// Stands in for the server and records what was sent.
class _Sender {
  _Sender(this.answer);

  String? answer;
  final sent = <(String, String)>[];

  Future<String?> call({required String kind, required String message}) async {
    sent.add((kind, message));
    return answer;
  }
}

Future<_Sender> _pump(WidgetTester tester, {String? answer}) async {
  final sender = _Sender(answer);
  await pumpAdminScreen(
    tester,
    SingleChildScrollView(child: FeedbackCard(send: sender.call)),
    _Store(),
  );
  return sender;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a message is sent with the chosen kind, and the box is cleared',
    (tester) async {
      final sender = await _pump(tester);

      await tester.tap(find.text(l10n.feedbackKindIdea));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        '  Please add a dark mode  ',
      );
      await tapVisible(tester, find.text(l10n.feedbackSend));

      expect(sender.sent, [
        ('idea', 'Please add a dark mode'),
      ], reason: 'the text is trimmed');
      expect(find.text(l10n.feedbackSent), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('the kind starts as a problem', (tester) async {
    final sender = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'The printer stops');
    await tapVisible(tester, find.text(l10n.feedbackSend));
    expect(sender.sent.single.$1, 'problem');
  });

  testWidgets('an empty message is not sent', (tester) async {
    final sender = await _pump(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tapVisible(tester, find.text(l10n.feedbackSend));

    expect(sender.sent, isEmpty);
    expect(find.text(l10n.feedbackEmpty), findsOneWidget);
  });

  testWidgets('the daily limit is explained and the text is kept', (
    tester,
  ) async {
    final sender = await _pump(tester, answer: 'too many today');
    await tester.enterText(find.byType(TextField), 'Another one');
    await tapVisible(tester, find.text(l10n.feedbackSend));

    expect(sender.sent, hasLength(1));
    expect(find.text(l10n.feedbackTooMany), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Another one',
    );
  });

  testWidgets(
    'any other failure says to check the connection and keeps the text',
    (tester) async {
      await _pump(tester, answer: 'network');
      await tester.enterText(find.byType(TextField), 'Hello');
      await tapVisible(tester, find.text(l10n.feedbackSend));

      expect(find.text(l10n.feedbackFailed), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hello',
      );
    },
  );
}
