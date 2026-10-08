/// Short codes the data layer returns instead of raw exception text, so
/// screens can show a translated message (see `l10n/error_text.dart`). The
/// full error is still logged with reportError where it happens.
abstract final class ErrorCodes {
  /// The app was built without a server address or key.
  static const notConfigured = 'not_configured';

  /// The server could not be reached.
  static const network = 'network';

  /// The server answered with an error that has no code of its own.
  static const failed = 'failed';

  static const lineNotFound = 'line_not_found';
  static const cartEmpty = 'cart_empty';
}
