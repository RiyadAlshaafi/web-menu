import 'dart:async';

import 'package:menu_web_v1/core/default_locale.dart';

/// The apps start in Arabic, but most tests look for English text, so they start in English.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  defaultLocaleForTests = 'en';
  await testMain();
}
