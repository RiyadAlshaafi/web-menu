import '../data/error_codes.dart';
import 'app_localizations.dart';

/// Turns an error the data layer or the server returned into text for the
/// screen, in the app's language.
extension ErrorText on AppLocalizations {
  String errorText(String raw) {
    switch (raw) {
      case ErrorCodes.notConfigured:
        return errNotConfigured;
      case ErrorCodes.network:
        return errNetwork;
      case ErrorCodes.failed:
        return errGeneric;
      case ErrorCodes.lineNotFound:
        return errLineNotFound;
      case ErrorCodes.cartEmpty:
        return errCartEmpty;
      case 'session expired, sign in again':
        return errSessionExpired;
      case 'no open bill':
        return errNoOpenBill;
      case 'no open shift':
        return errNoOpenShift;
      case 'sign in as a cashier first':
        return errSignInAsCashier;
    }
    // Other server answers are English fallback sentences; in Arabic show
    // a translated general message rather than English text.
    return localeName == 'en' ? raw : errGeneric;
  }
}
