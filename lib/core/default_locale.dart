import 'package:flutter/foundation.dart';

/// The language the apps use until the owner (or waiter) picks one.
const String appLocale = 'ar';

/// [appLocale], except that tests written in English set it to 'en' (test/flutter_test_config.dart).
@visibleForTesting
String defaultLocaleForTests = appLocale;

String get defaultLocale => defaultLocaleForTests;
