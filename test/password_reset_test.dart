import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/app_database.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:menu_web_v1/screens/auth_screens.dart';
import 'package:menu_web_v1/state/cafe_store.dart';

import 'support/admin_test_app.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

/// Stands in for Supabase Auth: the reset email "sends", and [goodCode] is the emailed code.
/// The new-password rules are the store's own; only the final server update is skipped.
class _ResetStore extends CafeStore {
  _ResetStore() : super(AppDatabase.instance) {
    cafe = {'name': 'Test Cafe'};
  }

  static const goodCode = '123456';
  final emails = <String>[];
  final codes = <String>[];

  @override
  Future<String?> requestPasswordReset(String email) async {
    emails.add(email);
    return null;
  }

  @override
  Future<String?> verifyOtp(String code) async {
    codes.add(code);
    if (code != goodCode) return l10n.errBadCode;
    otpVerified = true;
    return null;
  }

  @override
  Future<String?> completePasswordReset({required String password, required String confirm}) async {
    final error = await super.completePasswordReset(password: password, confirm: confirm);
    // Every check passed when the only complaint left is that no server is set up.
    return error == l10n.errNotConfigured ? null : error;
  }
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  final boxes = find.byType(TextField);
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(boxes.at(i), code[i]);
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('forgot password', () {
    testWidgets('sends the code to the email from the sign-in page as soon as it opens', (tester) async {
      final store = _ResetStore();
      await pumpAdminScreen(tester, const ForgotPasswordScreen(email: 'owner@cafe.ly'), store);

      expect(store.emails, ['owner@cafe.ly']);
    });

    testWidgets('resend waits for the countdown, then sends again', (tester) async {
      final store = _ResetStore();
      await pumpAdminScreen(tester, const ForgotPasswordScreen(email: 'owner@cafe.ly'), store);

      await tester.tap(find.textContaining(l10n.authDidntReceive));
      await tester.pump();
      expect(store.emails, hasLength(1), reason: 'resend is locked while the countdown runs');

      await tester.pump(const Duration(seconds: 45));
      ignoreOverflow(tester);
      expect(find.textContaining(l10n.authResendCode), findsOneWidget);
      await tester.tap(find.textContaining(l10n.authDidntReceive));
      await tester.pump();
      expect(store.emails, hasLength(2));
    });

    testWidgets('a wrong code shows an error and stays on the page', (tester) async {
      final store = _ResetStore();
      await pumpAdminScreen(tester, const ForgotPasswordScreen(email: 'owner@cafe.ly'), store);

      await _typeCode(tester, '999999');
      await tapVisible(tester, find.text(l10n.authVerifyCodeCta));

      expect(store.codes, ['999999']);
      expect(find.text(l10n.errBadCode), findsOneWidget);
      expect(find.text('page /admin/password'), findsNothing);
    });

    testWidgets('the right code opens the new-password page', (tester) async {
      final store = _ResetStore();
      await pumpAdminScreen(tester, const ForgotPasswordScreen(email: 'owner@cafe.ly'), store);

      await _typeCode(tester, _ResetStore.goodCode);
      await tapVisible(tester, find.text(l10n.authVerifyCodeCta));

      expect(store.codes, [_ResetStore.goodCode]);
      expect(find.text('page /admin/password'), findsOneWidget);
    });
  });

  group('new password', () {
    Future<void> submit(WidgetTester tester, String password, String confirm) async {
      await tester.enterText(find.byType(TextField).at(0), password);
      await tester.enterText(find.byType(TextField).at(1), confirm);
      await tapVisible(tester, find.text(l10n.authUpdatePasswordCta));
    }

    testWidgets('is refused until the emailed code was checked', (tester) async {
      await pumpAdminScreen(tester, const ChangePasswordScreen(), _ResetStore());

      await submit(tester, 'NewPass1!', 'NewPass1!');
      expect(find.text(l10n.errVerifyCodeFirst), findsOneWidget);
    });

    testWidgets('must match and be strong enough', (tester) async {
      final store = _ResetStore()..otpVerified = true;
      await pumpAdminScreen(tester, const ChangePasswordScreen(), store);

      await submit(tester, 'NewPass1!', 'NewPass2!');
      expect(find.text(l10n.errPasswordsMismatch), findsOneWidget);

      await submit(tester, 'short', 'short');
      expect(find.text(l10n.errWeakPassword), findsOneWidget);
      expect(find.text('page /admin/login'), findsNothing);
    });

    testWidgets('a valid new password returns to the admin sign-in', (tester) async {
      final store = _ResetStore()..otpVerified = true;
      await pumpAdminScreen(tester, const ChangePasswordScreen(), store);

      await submit(tester, 'NewPass1!', 'NewPass1!');
      expect(find.text('page /admin/login'), findsOneWidget);
    });
  });
}
