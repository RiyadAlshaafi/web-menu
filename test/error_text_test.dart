import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/data/error_codes.dart';
import 'package:menu_web_v1/l10n/l10n_ext.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('error codes become translated messages', () {
    expect(ar.errorText(ErrorCodes.network), ar.errNetwork);
    expect(en.errorText(ErrorCodes.notConfigured), en.errNotConfigured);
    expect(
      ar.errorText('session expired, sign in again'),
      ar.errSessionExpired,
    );
  });

  test(
    'unknown English server text is kept in English and hidden in Arabic',
    () {
      expect(en.errorText('Payment failed.'), 'Payment failed.');
      expect(ar.errorText('Payment failed.'), ar.errGeneric);
    },
  );
}
