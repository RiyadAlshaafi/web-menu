import 'package:flutter/foundation.dart';

void reportError(String where, Object error, [StackTrace? stackTrace]) {
  final message = '$error'.replaceAll(RegExp(r'https?://\S+'), '[url]');
  final trace = stackTrace == null ? '' : '\n$stackTrace';
  debugPrint('[$where] error: $message$trace');
}
