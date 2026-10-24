import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @noTables.
  ///
  /// In en, this message translates to:
  /// **'No tables have been created yet.'**
  String get noTables;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No active orders.'**
  String get noOrders;

  /// No description provided for @noCashiers.
  ///
  /// In en, this message translates to:
  /// **'No cashiers have been created yet.'**
  String get noCashiers;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactions;

  /// No description provided for @insufficientCash.
  ///
  /// In en, this message translates to:
  /// **'Insufficient cash.'**
  String get insufficientCash;

  /// No description provided for @createCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a category first.'**
  String get createCategoryFirst;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @navMenuCatalogLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu Catalog &\nLayout'**
  String get navMenuCatalogLabel;

  /// No description provided for @navMenuCatalog.
  ///
  /// In en, this message translates to:
  /// **'Menu Catalog & Layout'**
  String get navMenuCatalog;

  /// No description provided for @navDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get navDiscounts;

  /// No description provided for @navTablesQr.
  ///
  /// In en, this message translates to:
  /// **'Tables & QR Hub'**
  String get navTablesQr;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navSalesLog.
  ///
  /// In en, this message translates to:
  /// **'Sales Log'**
  String get navSalesLog;

  /// No description provided for @navDishAvailability.
  ///
  /// In en, this message translates to:
  /// **'Dish availability'**
  String get navDishAvailability;

  /// No description provided for @dishSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search dishes'**
  String get dishSearchHint;

  /// No description provided for @dishFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dishFilterAll;

  /// No description provided for @dishFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dishFilterActive;

  /// No description provided for @dishFilterInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get dishFilterInactive;

  /// No description provided for @dishAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get dishAllCategories;

  /// No description provided for @dishInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get dishInactive;

  /// No description provided for @dishActivateAll.
  ///
  /// In en, this message translates to:
  /// **'Activate all'**
  String get dishActivateAll;

  /// No description provided for @dishDeactivateAll.
  ///
  /// In en, this message translates to:
  /// **'Deactivate all'**
  String get dishDeactivateAll;

  /// No description provided for @dishBulkTitle.
  ///
  /// In en, this message translates to:
  /// **'Update this category?'**
  String get dishBulkTitle;

  /// No description provided for @dishBulkMessage.
  ///
  /// In en, this message translates to:
  /// **'This changes every dish in {category}.'**
  String dishBulkMessage(String category);

  /// No description provided for @salesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search table, cashier, or transaction'**
  String get salesSearchHint;

  /// No description provided for @salesDateFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get salesDateFrom;

  /// No description provided for @salesDateTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get salesDateTo;

  /// No description provided for @salesAllCashiers.
  ///
  /// In en, this message translates to:
  /// **'All cashiers'**
  String get salesAllCashiers;

  /// No description provided for @salesAllTables.
  ///
  /// In en, this message translates to:
  /// **'All tables'**
  String get salesAllTables;

  /// No description provided for @salesAllMethods.
  ///
  /// In en, this message translates to:
  /// **'All methods'**
  String get salesAllMethods;

  /// No description provided for @salesExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get salesExportCsv;

  /// No description provided for @salesExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get salesExportPdf;

  /// No description provided for @salesReceiptNo.
  ///
  /// In en, this message translates to:
  /// **'Receipt No.'**
  String get salesReceiptNo;

  /// No description provided for @salesOrderNo.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get salesOrderNo;

  /// No description provided for @salesReceiptLine.
  ///
  /// In en, this message translates to:
  /// **'Receipt No. {number}'**
  String salesReceiptLine(String number);

  /// No description provided for @salesColWhen.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get salesColWhen;

  /// No description provided for @salesColTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get salesColTable;

  /// No description provided for @salesColCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get salesColCashier;

  /// No description provided for @salesColItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get salesColItems;

  /// No description provided for @salesColSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get salesColSubtotal;

  /// No description provided for @salesColDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get salesColDiscount;

  /// No description provided for @salesColTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get salesColTotal;

  /// No description provided for @salesColMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get salesColMethod;

  /// No description provided for @salesColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get salesColStatus;

  /// No description provided for @salesPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get salesPaid;

  /// No description provided for @salesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sales match these filters.'**
  String get salesEmpty;

  /// No description provided for @salesPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String salesPage(int page, int pages);

  /// No description provided for @navQuickTakeout.
  ///
  /// In en, this message translates to:
  /// **'Quick Takeout'**
  String get navQuickTakeout;

  /// No description provided for @quickTakeoutSearch.
  ///
  /// In en, this message translates to:
  /// **'Search a dish'**
  String get quickTakeoutSearch;

  /// No description provided for @quickTakeoutAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get quickTakeoutAll;

  /// No description provided for @quickTakeoutEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap a dish to start the ticket.'**
  String get quickTakeoutEmpty;

  /// No description provided for @quickTakeoutPay.
  ///
  /// In en, this message translates to:
  /// **'Take payment'**
  String get quickTakeoutPay;

  /// No description provided for @quickTakeoutBusy.
  ///
  /// In en, this message translates to:
  /// **'That receipt is already being saved.'**
  String get quickTakeoutBusy;

  /// No description provided for @quickTakeoutPaid.
  ///
  /// In en, this message translates to:
  /// **'Takeout paid.'**
  String get quickTakeoutPaid;

  /// No description provided for @navLiveAlerts.
  ///
  /// In en, this message translates to:
  /// **'Live Alerts & Queue'**
  String get navLiveAlerts;

  /// No description provided for @navFloorOverview.
  ///
  /// In en, this message translates to:
  /// **'Floor Overview'**
  String get navFloorOverview;

  /// No description provided for @navShiftSales.
  ///
  /// In en, this message translates to:
  /// **'Shift Sales & Logs'**
  String get navShiftSales;

  /// No description provided for @errAdminExists.
  ///
  /// In en, this message translates to:
  /// **'Admin already exists.'**
  String get errAdminExists;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get errInvalidEmail;

  /// No description provided for @errPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords must match exactly.'**
  String get errPasswordsMismatch;

  /// No description provided for @errWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must include 8+ characters, a capital letter, a number, and a special symbol.'**
  String get errWeakPassword;

  /// No description provided for @errNoAdmin.
  ///
  /// In en, this message translates to:
  /// **'No admin account exists yet.'**
  String get errNoAdmin;

  /// No description provided for @errNoAdminForCafe.
  ///
  /// In en, this message translates to:
  /// **'No admin found for this cafe.'**
  String get errNoAdminForCafe;

  /// No description provided for @errBadCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get errBadCredentials;

  /// No description provided for @errBadCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code.'**
  String get errBadCode;

  /// No description provided for @errVerifyCodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Verify the safe code first.'**
  String get errVerifyCodeFirst;

  /// No description provided for @errSelectCashier.
  ///
  /// In en, this message translates to:
  /// **'Select a cashier profile.'**
  String get errSelectCashier;

  /// No description provided for @errEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit PIN.'**
  String get errEnterPin;

  /// No description provided for @errPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PIN does not match {name}.'**
  String errPinMismatch(String name);

  /// No description provided for @errPinLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs for {name}. Try again in {minutes} min.'**
  String errPinLocked(String name, int minutes);

  /// No description provided for @errCashierSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in as a cashier first.'**
  String get errCashierSignInFirst;

  /// No description provided for @errNoOpenBill.
  ///
  /// In en, this message translates to:
  /// **'This table has no open bill.'**
  String get errNoOpenBill;

  /// No description provided for @errNoOpenShift.
  ///
  /// In en, this message translates to:
  /// **'No open shift.'**
  String get errNoOpenShift;

  /// No description provided for @errUnpaidOrdersOpen.
  ///
  /// In en, this message translates to:
  /// **'Some tables still have unpaid orders. Settle them before closing the shift.'**
  String get errUnpaidOrdersOpen;

  /// No description provided for @authGuestCashier.
  ///
  /// In en, this message translates to:
  /// **'Guest Cashier'**
  String get authGuestCashier;

  /// No description provided for @authPosTerminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale\nTerminal'**
  String get authPosTerminalSubtitle;

  /// No description provided for @authSwitchToAdminSignIn.
  ///
  /// In en, this message translates to:
  /// **'Switch to Admin Sign In'**
  String get authSwitchToAdminSignIn;

  /// No description provided for @authCashierSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier Sign In'**
  String get authCashierSignInTitle;

  /// No description provided for @authCashierSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select cashier profile and enter 4-digit PIN'**
  String get authCashierSignInSubtitle;

  /// No description provided for @authAuthenticatingAs.
  ///
  /// In en, this message translates to:
  /// **'Authenticating as '**
  String get authAuthenticatingAs;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authPosFooter.
  ///
  /// In en, this message translates to:
  /// **'{cafe}  •  Tawla POS'**
  String authPosFooter(String cafe);

  /// No description provided for @authPinClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get authPinClear;

  /// No description provided for @authStaffPos.
  ///
  /// In en, this message translates to:
  /// **'Staff POS  →'**
  String get authStaffPos;

  /// No description provided for @authCreateAdminAccess.
  ///
  /// In en, this message translates to:
  /// **'Create Admin Access'**
  String get authCreateAdminAccess;

  /// No description provided for @authAdminSignIn.
  ///
  /// In en, this message translates to:
  /// **'Admin Sign In'**
  String get authAdminSignIn;

  /// No description provided for @authManagerEmail.
  ///
  /// In en, this message translates to:
  /// **'Manager Email'**
  String get authManagerEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authForgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordLink;

  /// No description provided for @authCreateStrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a strong password'**
  String get authCreateStrongPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get authRepeatPassword;

  /// No description provided for @authKeepSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get authKeepSignedIn;

  /// No description provided for @authCreateAccessCta.
  ///
  /// In en, this message translates to:
  /// **'Create Access  →'**
  String get authCreateAccessCta;

  /// No description provided for @authSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign In  →'**
  String get authSignInCta;

  /// No description provided for @authHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authHaveAccountSignIn;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a New Admin Password'**
  String get authResetTitle;

  /// No description provided for @authResetBody.
  ///
  /// In en, this message translates to:
  /// **'The setup unlocked a one-time password reset for {email}. Sales, menu and settings stay as they are.'**
  String authResetBody(String email);

  /// No description provided for @authResetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authResetNewPassword;

  /// No description provided for @authResetCta.
  ///
  /// In en, this message translates to:
  /// **'Save New Password  →'**
  String get authResetCta;

  /// No description provided for @authResetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This password reset has expired or was already used. Run the setup again to get a new one.'**
  String get authResetUnavailable;

  /// No description provided for @authResetReady.
  ///
  /// In en, this message translates to:
  /// **'The admin password can be reset now.'**
  String get authResetReady;

  /// No description provided for @authResetOpen.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get authResetOpen;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get authForgotPasswordTitle;

  /// No description provided for @authForgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the safe code to change your password'**
  String get authForgotPasswordSubtitle;

  /// No description provided for @authSafeCodeSent.
  ///
  /// In en, this message translates to:
  /// **'A security safe code was sent to the registered manager device / email.'**
  String get authSafeCodeSent;

  /// No description provided for @authDidntReceive.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive it?  '**
  String get authDidntReceive;

  /// No description provided for @authResendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend safe code ({time})'**
  String authResendCodeIn(String time);

  /// No description provided for @authResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend safe code'**
  String get authResendCode;

  /// No description provided for @authVerifyCodeCta.
  ///
  /// In en, this message translates to:
  /// **'Verify Code & Continue  →'**
  String get authVerifyCodeCta;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'←  Back to Sign In'**
  String get authBackToSignIn;

  /// No description provided for @authForgotFooter.
  ///
  /// In en, this message translates to:
  /// **'Station #POS-01   •   256-Bit Cryptographic Vault'**
  String get authForgotFooter;

  /// No description provided for @authHospitalityCoreAdmin.
  ///
  /// In en, this message translates to:
  /// **'HOSPITALITY CORE • ADMIN'**
  String get authHospitalityCoreAdmin;

  /// No description provided for @authSetNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get authSetNewPasswordTitle;

  /// No description provided for @authSetNewPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password to regain access to your admin account and management console.'**
  String get authSetNewPasswordSubtitle;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPassword;

  /// No description provided for @authConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get authConfirmNewPassword;

  /// No description provided for @authPasswordsMustMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords must match exactly'**
  String get authPasswordsMustMatch;

  /// No description provided for @authPasswordRequirements.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD REQUIREMENTS'**
  String get authPasswordRequirements;

  /// No description provided for @authReqMinLength.
  ///
  /// In en, this message translates to:
  /// **'8+ characters'**
  String get authReqMinLength;

  /// No description provided for @authReqNumber.
  ///
  /// In en, this message translates to:
  /// **'At least 1 number'**
  String get authReqNumber;

  /// No description provided for @authReqCapital.
  ///
  /// In en, this message translates to:
  /// **'Capital letter'**
  String get authReqCapital;

  /// No description provided for @authReqSymbol.
  ///
  /// In en, this message translates to:
  /// **'Special symbol'**
  String get authReqSymbol;

  /// No description provided for @authUpdatePasswordCta.
  ///
  /// In en, this message translates to:
  /// **'Update Password & Continue  →'**
  String get authUpdatePasswordCta;

  /// No description provided for @authReturnToStaffSignIn.
  ///
  /// In en, this message translates to:
  /// **'←  Return to Staff Sign In'**
  String get authReturnToStaffSignIn;

  /// No description provided for @authChangePasswordFooter.
  ///
  /// In en, this message translates to:
  /// **'{cafe}  •  Tawla {version}'**
  String authChangePasswordFooter(String cafe, String version);

  /// No description provided for @adminConsoleLabel.
  ///
  /// In en, this message translates to:
  /// **'ADMIN CONSOLE'**
  String get adminConsoleLabel;

  /// No description provided for @adminDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminDefaultName;

  /// No description provided for @adminGeneralManager.
  ///
  /// In en, this message translates to:
  /// **'General Manager'**
  String get adminGeneralManager;

  /// No description provided for @adminCustomerView.
  ///
  /// In en, this message translates to:
  /// **'Customer View'**
  String get adminCustomerView;

  /// No description provided for @adminSearchTableHint.
  ///
  /// In en, this message translates to:
  /// **'Search table or zone...'**
  String get adminSearchTableHint;

  /// No description provided for @adminAddTableButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add Table'**
  String get adminAddTableButton;

  /// No description provided for @adminRegenerateQr.
  ///
  /// In en, this message translates to:
  /// **'Regenerate QR'**
  String get adminRegenerateQr;

  /// No description provided for @adminRegenerateAllQr.
  ///
  /// In en, this message translates to:
  /// **'Regenerate all QR codes'**
  String get adminRegenerateAllQr;

  /// No description provided for @adminTableNumber.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String adminTableNumber(String number);

  /// No description provided for @adminTableAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get adminTableAvailable;

  /// No description provided for @adminTableOccupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get adminTableOccupied;

  /// No description provided for @adminScanToOrderPay.
  ///
  /// In en, this message translates to:
  /// **'Scan to Order & Pay'**
  String get adminScanToOrderPay;

  /// No description provided for @adminNoAppInstall.
  ///
  /// In en, this message translates to:
  /// **'No app install required'**
  String get adminNoAppInstall;

  /// No description provided for @adminPrintStandCard.
  ///
  /// In en, this message translates to:
  /// **'Print Stand Card (PDF)'**
  String get adminPrintStandCard;

  /// No description provided for @adminAddTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get adminAddTableTitle;

  /// No description provided for @adminTableNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Table number / name'**
  String get adminTableNumberLabel;

  /// No description provided for @adminCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCreate;

  /// No description provided for @adminDeleteTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Table?'**
  String get adminDeleteTableTitle;

  /// No description provided for @adminDeleteTableMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this table? It will be removed from the floor plan, QR codes and ordering. Its past receipts and sales history are kept.'**
  String get adminDeleteTableMessage;

  /// No description provided for @adminDeleteTableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Table'**
  String get adminDeleteTableConfirm;

  /// No description provided for @layoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu Layout & Display Editor'**
  String get layoutTitle;

  /// No description provided for @layoutSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Menu layout saved.'**
  String get layoutSavedSnack;

  /// No description provided for @layoutSaveMenu.
  ///
  /// In en, this message translates to:
  /// **'Save Menu Layout'**
  String get layoutSaveMenu;

  /// No description provided for @layoutSequencingHeading.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY SEQUENCING & DISHES TREE'**
  String get layoutSequencingHeading;

  /// No description provided for @layoutReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Use arrows to reorder'**
  String get layoutReorderHint;

  /// No description provided for @layoutCategoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Category Name (e.g. Bevande & Wines, Desserts)'**
  String get layoutCategoryNameHint;

  /// No description provided for @layoutCreateCategory.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get layoutCreateCategory;

  /// No description provided for @layoutSpotlight.
  ///
  /// In en, this message translates to:
  /// **'SPOTLIGHT'**
  String get layoutSpotlight;

  /// No description provided for @layoutOneDish.
  ///
  /// In en, this message translates to:
  /// **'1 Dish'**
  String get layoutOneDish;

  /// No description provided for @layoutDishCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Dishes'**
  String layoutDishCount(String count);

  /// No description provided for @layoutCurrentlyInspecting.
  ///
  /// In en, this message translates to:
  /// **'Currently Inspecting'**
  String get layoutCurrentlyInspecting;

  /// No description provided for @layoutAddDish.
  ///
  /// In en, this message translates to:
  /// **'Add Dish'**
  String get layoutAddDish;

  /// No description provided for @layoutDishesInCategory.
  ///
  /// In en, this message translates to:
  /// **'DISHES IN {category} ({count} ACTIVE)'**
  String layoutDishesInCategory(String category, String count);

  /// No description provided for @layoutDeleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category?'**
  String get layoutDeleteCategoryTitle;

  /// No description provided for @layoutDeleteCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this category? This action cannot be undone and will permanently remove it and its associated items from the menu system.'**
  String get layoutDeleteCategoryMessage;

  /// No description provided for @layoutDeleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get layoutDeleteCategoryConfirm;

  /// No description provided for @layoutHeroCard.
  ///
  /// In en, this message translates to:
  /// **'HERO CARD'**
  String get layoutHeroCard;

  /// No description provided for @layoutActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get layoutActive;

  /// No description provided for @layoutHero.
  ///
  /// In en, this message translates to:
  /// **'Hero'**
  String get layoutHero;

  /// No description provided for @layoutList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get layoutList;

  /// No description provided for @layoutDeleteDishTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete dish?'**
  String get layoutDeleteDishTitle;

  /// No description provided for @layoutDeleteDishMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the digital menu?'**
  String layoutDeleteDishMessage(String name);

  /// No description provided for @layoutAddNewDish.
  ///
  /// In en, this message translates to:
  /// **'Add New Dish'**
  String get layoutAddNewDish;

  /// No description provided for @layoutAddDishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter dish details to add to digital menu catalog.'**
  String get layoutAddDishSubtitle;

  /// No description provided for @layoutDishNameAr.
  ///
  /// In en, this message translates to:
  /// **'ARABIC NAME *'**
  String get layoutDishNameAr;

  /// No description provided for @layoutDishNameArHint.
  ///
  /// In en, this message translates to:
  /// **'اسم الطبق بالعربية'**
  String get layoutDishNameArHint;

  /// No description provided for @layoutDishNameEn.
  ///
  /// In en, this message translates to:
  /// **'ENGLISH NAME *'**
  String get layoutDishNameEn;

  /// No description provided for @layoutDishNameEnHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Truffle tagliolini'**
  String get layoutDishNameEnHint;

  /// No description provided for @layoutPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'PRICE (LYD) *'**
  String get layoutPriceLabel;

  /// No description provided for @layoutDishPictureLabel.
  ///
  /// In en, this message translates to:
  /// **'DISH PICTURE'**
  String get layoutDishPictureLabel;

  /// No description provided for @layoutImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image must be 10MB or smaller.'**
  String get layoutImageTooLarge;

  /// No description provided for @layoutUploadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Click or drag image to upload'**
  String get layoutUploadPrompt;

  /// No description provided for @layoutUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Optional · JPG, PNG up to 10MB'**
  String get layoutUploadHint;

  /// No description provided for @layoutEnterDishName.
  ///
  /// In en, this message translates to:
  /// **'Enter a dish name.'**
  String get layoutEnterDishName;

  /// No description provided for @layoutSaveAndAddDish.
  ///
  /// In en, this message translates to:
  /// **'Save & Add Dish'**
  String get layoutSaveAndAddDish;

  /// No description provided for @layoutSaveDish.
  ///
  /// In en, this message translates to:
  /// **'Save Dish'**
  String get layoutSaveDish;

  /// No description provided for @layoutSaveDishError.
  ///
  /// In en, this message translates to:
  /// **'Could not save dish: {error}'**
  String layoutSaveDishError(String error);

  /// No description provided for @catalogNewDiscount.
  ///
  /// In en, this message translates to:
  /// **'New Discount'**
  String get catalogNewDiscount;

  /// No description provided for @catalogAllCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'All Categories ({count})'**
  String catalogAllCategoriesCount(String count);

  /// No description provided for @catalogSearchDishesHint.
  ///
  /// In en, this message translates to:
  /// **'Search dishes...'**
  String get catalogSearchDishesHint;

  /// No description provided for @catalogNoDishesHint.
  ///
  /// In en, this message translates to:
  /// **'No dishes yet. Add dishes from Menu Layout, then apply discounts here.'**
  String get catalogNoDishesHint;

  /// No description provided for @catalogApplyDiscountPromo.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount Promo'**
  String get catalogApplyDiscountPromo;

  /// No description provided for @catalogTargetCategory.
  ///
  /// In en, this message translates to:
  /// **'TARGET CATEGORY'**
  String get catalogTargetCategory;

  /// No description provided for @catalogAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get catalogAllCategories;

  /// No description provided for @catalogDiscountRate.
  ///
  /// In en, this message translates to:
  /// **'DISCOUNT RATE (%)'**
  String get catalogDiscountRate;

  /// No description provided for @catalogPromoLabel.
  ///
  /// In en, this message translates to:
  /// **'PROMO LABEL / DESCRIPTION (OPTIONAL)'**
  String get catalogPromoLabel;

  /// No description provided for @catalogPromoLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Happy Hour Special'**
  String get catalogPromoLabelHint;

  /// No description provided for @catalogActivateImmediately.
  ///
  /// In en, this message translates to:
  /// **'Activate Immediately'**
  String get catalogActivateImmediately;

  /// No description provided for @catalogActivateImmediatelyDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync instantly to active tables and digital order catalog'**
  String get catalogActivateImmediatelyDesc;

  /// No description provided for @catalogApplyDiscount.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount'**
  String get catalogApplyDiscount;

  /// No description provided for @catalogPercentOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Off'**
  String catalogPercentOff(String percent);

  /// No description provided for @catalogNoPromo.
  ///
  /// In en, this message translates to:
  /// **'No Promo'**
  String get catalogNoPromo;

  /// No description provided for @catalogDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get catalogDiscount;

  /// No description provided for @catalogApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get catalogApply;

  /// No description provided for @catalogCompanyInfo.
  ///
  /// In en, this message translates to:
  /// **'Company / Cafe Info'**
  String get catalogCompanyInfo;

  /// No description provided for @catalogCafeName.
  ///
  /// In en, this message translates to:
  /// **'Cafe name'**
  String get catalogCafeName;

  /// No description provided for @catalogPublicMenuUrl.
  ///
  /// In en, this message translates to:
  /// **'Guest menu address (used in table QR codes)'**
  String get catalogPublicMenuUrl;

  /// No description provided for @catalogPublicMenuUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://menu.your-cafe.ly'**
  String get catalogPublicMenuUrlHint;

  /// No description provided for @catalogChooseLogo.
  ///
  /// In en, this message translates to:
  /// **'Choose logo'**
  String get catalogChooseLogo;

  /// No description provided for @catalogRemoveLogo.
  ///
  /// In en, this message translates to:
  /// **'Remove logo'**
  String get catalogRemoveLogo;

  /// No description provided for @catalogSaveCompany.
  ///
  /// In en, this message translates to:
  /// **'Save cafe info'**
  String get catalogSaveCompany;

  /// No description provided for @catalogAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance / Theme Colors'**
  String get catalogAppearance;

  /// No description provided for @catalogHeaderColor.
  ///
  /// In en, this message translates to:
  /// **'Header color'**
  String get catalogHeaderColor;

  /// No description provided for @catalogSidebarColor.
  ///
  /// In en, this message translates to:
  /// **'Sidebar color'**
  String get catalogSidebarColor;

  /// No description provided for @catalogBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get catalogBackgroundColor;

  /// No description provided for @catalogButtonColor.
  ///
  /// In en, this message translates to:
  /// **'Button color'**
  String get catalogButtonColor;

  /// No description provided for @catalogSaveColors.
  ///
  /// In en, this message translates to:
  /// **'Save colors'**
  String get catalogSaveColors;

  /// No description provided for @catalogResetColors.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get catalogResetColors;

  /// No description provided for @catalogSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System Language'**
  String get catalogSystemLanguage;

  /// No description provided for @catalogSystemLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the default language for the admin portal and customer digital menus.'**
  String get catalogSystemLanguageDesc;

  /// No description provided for @catalogEnglishUs.
  ///
  /// In en, this message translates to:
  /// **'English (US)'**
  String get catalogEnglishUs;

  /// No description provided for @catalogLangDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get catalogLangDefault;

  /// No description provided for @catalogLangRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get catalogLangRegional;

  /// No description provided for @catalogSaveLanguage.
  ///
  /// In en, this message translates to:
  /// **'Save Language'**
  String get catalogSaveLanguage;

  /// No description provided for @catalogChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get catalogChangePassword;

  /// No description provided for @catalogCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get catalogCurrentPassword;

  /// No description provided for @catalogNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get catalogNewPassword;

  /// No description provided for @catalogPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get catalogPasswordUpdated;

  /// No description provided for @catalogUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get catalogUpdatePassword;

  /// No description provided for @catalogCashierStaffAccess.
  ///
  /// In en, this message translates to:
  /// **'Cashier & Staff Access'**
  String get catalogCashierStaffAccess;

  /// No description provided for @catalogCashierNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Luca Neri'**
  String get catalogCashierNameHint;

  /// No description provided for @catalogCashierName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get catalogCashierName;

  /// No description provided for @catalogStaffRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get catalogStaffRoleLabel;

  /// No description provided for @expensePaidTo.
  ///
  /// In en, this message translates to:
  /// **'Paid to'**
  String get expensePaidTo;

  /// No description provided for @staffRoleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get staffRoleCashier;

  /// No description provided for @staffRoleChef.
  ///
  /// In en, this message translates to:
  /// **'Chef'**
  String get staffRoleChef;

  /// No description provided for @staffRoleServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get staffRoleServer;

  /// No description provided for @staffRoleCleaner.
  ///
  /// In en, this message translates to:
  /// **'Cleaner'**
  String get staffRoleCleaner;

  /// No description provided for @catalogCashierPinLabel.
  ///
  /// In en, this message translates to:
  /// **'4-digit secret passcode'**
  String get catalogCashierPinLabel;

  /// No description provided for @catalogSaveCashier.
  ///
  /// In en, this message translates to:
  /// **'Save Staff Member'**
  String get catalogSaveCashier;

  /// No description provided for @cashierLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get cashierLanguage;

  /// No description provided for @cashierRole.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashierRole;

  /// No description provided for @cashierSoloCashier.
  ///
  /// In en, this message translates to:
  /// **'Solo Cashier'**
  String get cashierSoloCashier;

  /// No description provided for @cashierAssistanceCalls.
  ///
  /// In en, this message translates to:
  /// **'Assistance Calls'**
  String get cashierAssistanceCalls;

  /// No description provided for @cashierCallsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Calls'**
  String cashierCallsCount(String count);

  /// No description provided for @cashierNeedsAttend.
  ///
  /// In en, this message translates to:
  /// **'Needs Attend'**
  String get cashierNeedsAttend;

  /// No description provided for @cashierIncomingOrders.
  ///
  /// In en, this message translates to:
  /// **'Incoming Orders'**
  String get cashierIncomingOrders;

  /// No description provided for @cashierOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Orders'**
  String cashierOrdersCount(String count);

  /// No description provided for @cashierNeedsAccept.
  ///
  /// In en, this message translates to:
  /// **'Needs Accept'**
  String get cashierNeedsAccept;

  /// No description provided for @cashierBillOutRequests.
  ///
  /// In en, this message translates to:
  /// **'Bill Out Requests'**
  String get cashierBillOutRequests;

  /// No description provided for @cashierCheckoutsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Checkouts'**
  String cashierCheckoutsCount(String count);

  /// No description provided for @cashierDueNow.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get cashierDueNow;

  /// No description provided for @cashierFilterAllAlerts.
  ///
  /// In en, this message translates to:
  /// **'All Alerts ({count})'**
  String cashierFilterAllAlerts(String count);

  /// No description provided for @cashierFilterCallStaff.
  ///
  /// In en, this message translates to:
  /// **'Call Staff ({count})'**
  String cashierFilterCallStaff(String count);

  /// No description provided for @cashierFilterNewOrders.
  ///
  /// In en, this message translates to:
  /// **'New Orders ({count})'**
  String cashierFilterNewOrders(String count);

  /// No description provided for @cashierFilterBillRequests.
  ///
  /// In en, this message translates to:
  /// **'Bill Requests ({count})'**
  String cashierFilterBillRequests(String count);

  /// No description provided for @cashierInstantAlerts.
  ///
  /// In en, this message translates to:
  /// **'Instant Alerts'**
  String get cashierInstantAlerts;

  /// No description provided for @cashierBillRequest.
  ///
  /// In en, this message translates to:
  /// **'Bill Request'**
  String get cashierBillRequest;

  /// No description provided for @cashierItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String cashierItemsCount(String count);

  /// No description provided for @cashierSettleBill.
  ///
  /// In en, this message translates to:
  /// **'Settle Bill'**
  String get cashierSettleBill;

  /// No description provided for @cashierCallStaff.
  ///
  /// In en, this message translates to:
  /// **'Call Staff'**
  String get cashierCallStaff;

  /// No description provided for @cashierAssistanceRequested.
  ///
  /// In en, this message translates to:
  /// **'Assistance requested'**
  String get cashierAssistanceRequested;

  /// No description provided for @cashierAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get cashierAttended;

  /// No description provided for @cashierClearTable.
  ///
  /// In en, this message translates to:
  /// **'Clear table'**
  String get cashierClearTable;

  /// No description provided for @cashierClearTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear table {number}?'**
  String cashierClearTableTitle(String number);

  /// No description provided for @cashierClearTableBody.
  ///
  /// In en, this message translates to:
  /// **'This cancels every order on this table that is not paid yet, empties its cart and frees the table. Paid sales are not touched. Are you sure?'**
  String get cashierClearTableBody;

  /// No description provided for @cashierClearTableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, clear table'**
  String get cashierClearTableConfirm;

  /// No description provided for @cashierClearTableDone.
  ///
  /// In en, this message translates to:
  /// **'Table {number} is clear'**
  String cashierClearTableDone(String number);

  /// No description provided for @cashierNewOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get cashierNewOrder;

  /// No description provided for @cashierAcceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Accept Order'**
  String get cashierAcceptOrder;

  /// No description provided for @cashierTableShort.
  ///
  /// In en, this message translates to:
  /// **'T-{number}'**
  String cashierTableShort(String number);

  /// No description provided for @cashierTableNumber.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String cashierTableNumber(String number);

  /// No description provided for @cashierOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String cashierOrderNumber(String id);

  /// No description provided for @orderRound.
  ///
  /// In en, this message translates to:
  /// **'Round {round}'**
  String orderRound(int round);

  /// No description provided for @cashierTotalToCharge.
  ///
  /// In en, this message translates to:
  /// **'Total to Charge'**
  String get cashierTotalToCharge;

  /// No description provided for @cashierCustomerPay.
  ///
  /// In en, this message translates to:
  /// **'Customer wants to pay: {name}'**
  String cashierCustomerPay(String name);

  /// No description provided for @cashierSettleCloseBill.
  ///
  /// In en, this message translates to:
  /// **'Settle & Close Bill ({amount})'**
  String cashierSettleCloseBill(String amount);

  /// No description provided for @cashierAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cashierAmount;

  /// No description provided for @cashierSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get cashierSubtotal;

  /// No description provided for @cashierApplyServiceCharge.
  ///
  /// In en, this message translates to:
  /// **'Apply service charge'**
  String get cashierApplyServiceCharge;

  /// No description provided for @cashierReadyToServe.
  ///
  /// In en, this message translates to:
  /// **'Ready to Serve'**
  String get cashierReadyToServe;

  /// No description provided for @cashierMarkServed.
  ///
  /// In en, this message translates to:
  /// **'Mark served'**
  String get cashierMarkServed;

  /// No description provided for @cashierWaitingForBill.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Bill'**
  String get cashierWaitingForBill;

  /// No description provided for @cashierPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get cashierPrintReceipt;

  /// No description provided for @cashierPrintChit.
  ///
  /// In en, this message translates to:
  /// **'Print Chit'**
  String get cashierPrintChit;

  /// No description provided for @cashierSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get cashierSettled;

  /// No description provided for @cashierActiveTables.
  ///
  /// In en, this message translates to:
  /// **'{active} / {total} Active'**
  String cashierActiveTables(String active, String total);

  /// No description provided for @cashierServiceCharge.
  ///
  /// In en, this message translates to:
  /// **'Service charge ({percent}%)'**
  String cashierServiceCharge(String percent);

  /// No description provided for @cashierBillRequestedBadge.
  ///
  /// In en, this message translates to:
  /// **'BILL REQUESTED'**
  String get cashierBillRequestedBadge;

  /// No description provided for @cashierDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-in'**
  String get cashierDineIn;

  /// No description provided for @cashierElapsedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String cashierElapsedMinutes(String minutes);

  /// No description provided for @cashierOrderItemsCount.
  ///
  /// In en, this message translates to:
  /// **'Order items ({count})'**
  String cashierOrderItemsCount(String count);

  /// No description provided for @cashierTotalPayable.
  ///
  /// In en, this message translates to:
  /// **'Total Payable'**
  String get cashierTotalPayable;

  /// No description provided for @cashierActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This action is not available on this register.'**
  String get cashierActionUnavailable;

  /// No description provided for @cashierRefuse.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get cashierRefuse;

  /// No description provided for @cashierItemRefused.
  ///
  /// In en, this message translates to:
  /// **'Item removed — marked as unavailable'**
  String get cashierItemRefused;

  /// No description provided for @cashierWaitingCustomerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the table to confirm the updated order.'**
  String get cashierWaitingCustomerConfirm;

  /// No description provided for @cashierSettleAnyway.
  ///
  /// In en, this message translates to:
  /// **'Settle anyway'**
  String get cashierSettleAnyway;

  /// No description provided for @cashierSettleAnywayMessage.
  ///
  /// In en, this message translates to:
  /// **'The customer has not confirmed the updated order. Settle anyway?'**
  String get cashierSettleAnywayMessage;

  /// No description provided for @cashierMarkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Mark unavailable'**
  String get cashierMarkUnavailable;

  /// No description provided for @cashierMarkAvailable.
  ///
  /// In en, this message translates to:
  /// **'Mark available'**
  String get cashierMarkAvailable;

  /// No description provided for @cashierColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cashierColStatus;

  /// No description provided for @cashierColActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get cashierColActions;

  /// No description provided for @cashierAvgTicket.
  ///
  /// In en, this message translates to:
  /// **'Avg ticket {amount}'**
  String cashierAvgTicket(String amount);

  /// No description provided for @cashierFloorAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String cashierFloorAll(String count);

  /// No description provided for @cashierFloorOccupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied ({count})'**
  String cashierFloorOccupied(String count);

  /// No description provided for @cashierFloorBillDue.
  ///
  /// In en, this message translates to:
  /// **'Bill Due ({count})'**
  String cashierFloorBillDue(String count);

  /// No description provided for @cashierFloorAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available ({count})'**
  String cashierFloorAvailable(String count);

  /// No description provided for @cashierStatusCleanReady.
  ///
  /// In en, this message translates to:
  /// **'Clean & Ready'**
  String get cashierStatusCleanReady;

  /// No description provided for @cashierStatusBillRequested.
  ///
  /// In en, this message translates to:
  /// **'Bill Requested'**
  String get cashierStatusBillRequested;

  /// No description provided for @cashierStatusStaffCall.
  ///
  /// In en, this message translates to:
  /// **'Staff Call'**
  String get cashierStatusStaffCall;

  /// No description provided for @cashierStatusDining.
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get cashierStatusDining;

  /// No description provided for @cashierAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get cashierAvailable;

  /// No description provided for @cashierTotalShiftGrossSales.
  ///
  /// In en, this message translates to:
  /// **'Total Shift Gross Sales'**
  String get cashierTotalShiftGrossSales;

  /// No description provided for @cashierSettledOrders.
  ///
  /// In en, this message translates to:
  /// **'Settled Orders'**
  String get cashierSettledOrders;

  /// No description provided for @cashierActivePendingBalance.
  ///
  /// In en, this message translates to:
  /// **'Active Pending Balance'**
  String get cashierActivePendingBalance;

  /// No description provided for @cashierColOrderTable.
  ///
  /// In en, this message translates to:
  /// **'Receipt & Table'**
  String get cashierColOrderTable;

  /// No description provided for @cashierColTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get cashierColTime;

  /// No description provided for @cashierColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cashierColAmount;

  /// No description provided for @cashierActualCashCounted.
  ///
  /// In en, this message translates to:
  /// **'Actual Cash Counted'**
  String get cashierActualCashCounted;

  /// No description provided for @cashierCloseRegister.
  ///
  /// In en, this message translates to:
  /// **'Close Register / End Shift'**
  String get cashierCloseRegister;

  /// No description provided for @cashierDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference: {amount}'**
  String cashierDifference(String amount);

  /// No description provided for @guestStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get guestStatusReceived;

  /// No description provided for @guestStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get guestStatusPreparing;

  /// No description provided for @guestStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get guestStatusReady;

  /// No description provided for @guestStatusServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get guestStatusServed;

  /// No description provided for @guestPaid.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get guestPaid;

  /// No description provided for @guestTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due'**
  String get guestTotalDue;

  /// No description provided for @navCashierLog.
  ///
  /// In en, this message translates to:
  /// **'Cashier Log & Shift'**
  String get navCashierLog;

  /// No description provided for @cashierLogScope.
  ///
  /// In en, this message translates to:
  /// **'Your transactions. Filter them by shift.'**
  String get cashierLogScope;

  /// No description provided for @salesAllShifts.
  ///
  /// In en, this message translates to:
  /// **'All shifts'**
  String get salesAllShifts;

  /// No description provided for @payTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment types'**
  String get payTypesTitle;

  /// No description provided for @payTypesHint.
  ///
  /// In en, this message translates to:
  /// **'Customers choose from the enabled types. Disabling one keeps past sales.'**
  String get payTypesHint;

  /// No description provided for @payTypeNameEn.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get payTypeNameEn;

  /// No description provided for @payTypeNameAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get payTypeNameAr;

  /// No description provided for @payTypeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add type'**
  String get payTypeAdd;

  /// No description provided for @cashierWaitingServed.
  ///
  /// In en, this message translates to:
  /// **'Waiting for order to be served'**
  String get cashierWaitingServed;

  /// No description provided for @cashierSettleAnywayNotServed.
  ///
  /// In en, this message translates to:
  /// **'The customer has not confirmed the updated order, and it has not been marked served. Mark it served before settling.'**
  String get cashierSettleAnywayNotServed;

  /// No description provided for @payChanged.
  ///
  /// In en, this message translates to:
  /// **'Payment method changed from {oldName} to {newName} by {name} at {time}'**
  String payChanged(String oldName, String newName, String name, String time);

  /// No description provided for @staffOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get staffOpening;

  /// No description provided for @guestRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get guestRetry;

  /// No description provided for @serviceTakeout.
  ///
  /// In en, this message translates to:
  /// **'Takeout'**
  String get serviceTakeout;

  /// No description provided for @payDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String payDeleteTitle(String name);

  /// No description provided for @payDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Past sales using this method will keep showing it.'**
  String get payDeleteMessage;

  /// No description provided for @payTypeSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get payTypeSave;

  /// No description provided for @salesLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get salesLoadMore;

  /// No description provided for @cafeLocationRequire.
  ///
  /// In en, this message translates to:
  /// **'Require guests to be near the cafe to order'**
  String get cafeLocationRequire;

  /// No description provided for @cafeLocationUseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get cafeLocationUseCurrent;

  /// No description provided for @cafeLocationLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get cafeLocationLatitude;

  /// No description provided for @cafeLocationLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get cafeLocationLongitude;

  /// No description provided for @cafeLocationRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius (meters)'**
  String get cafeLocationRadius;

  /// No description provided for @cafeLocationSave.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get cafeLocationSave;

  /// No description provided for @cafeLocationGpsNote.
  ///
  /// In en, this message translates to:
  /// **'GPS can be off by 20 to 50 m indoors.'**
  String get cafeLocationGpsNote;

  /// No description provided for @cafeLocationNeedPoint.
  ///
  /// In en, this message translates to:
  /// **'Save a latitude and longitude before turning this on.'**
  String get cafeLocationNeedPoint;

  /// No description provided for @cafeLocationRadiusRange.
  ///
  /// In en, this message translates to:
  /// **'Radius must be between 30 and 500 meters.'**
  String get cafeLocationRadiusRange;

  /// No description provided for @cafeLocationReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this device\'s location.'**
  String get cafeLocationReadFailed;

  /// No description provided for @cafeLocationSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the cafe location.'**
  String get cafeLocationSaveFailed;

  /// No description provided for @cafeLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Cafe location saved.'**
  String get cafeLocationSaved;

  /// No description provided for @adminAutoPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Automatically print receipt after payment'**
  String get adminAutoPrintReceipt;

  /// No description provided for @adminAutoPrintReceiptHint.
  ///
  /// In en, this message translates to:
  /// **'Opens the print dialog when a dine-in or takeout sale is settled.'**
  String get adminAutoPrintReceiptHint;

  /// No description provided for @receiptThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you'**
  String get receiptThankYou;

  /// No description provided for @receiptPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'The sale was saved, but the receipt could not be printed.'**
  String get receiptPrintFailed;

  /// No description provided for @guestLocationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get guestLocationRetry;

  /// No description provided for @cashierAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense / Cash Out'**
  String get cashierAddExpense;

  /// No description provided for @cashierExpenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cashierExpenseAmount;

  /// No description provided for @cashierExpenseDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cashierExpenseDescription;

  /// No description provided for @cashierExpenseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cashierExpenseAdd;

  /// No description provided for @cashierExpenseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose who was paid, enter an amount greater than 0, and describe the expense.'**
  String get cashierExpenseInvalid;

  /// No description provided for @cashierExpenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense recorded.'**
  String get cashierExpenseSaved;

  /// No description provided for @expenseType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get expenseType;

  /// No description provided for @expenseTypeCafe.
  ///
  /// In en, this message translates to:
  /// **'Café Expense'**
  String get expenseTypeCafe;

  /// No description provided for @expenseTypeWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Cash Withdrawal'**
  String get expenseTypeWithdrawal;

  /// No description provided for @expenseCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense categories'**
  String get expenseCategoriesTitle;

  /// No description provided for @expenseCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Cashiers pick from the enabled categories when recording a cash-out. Past rows keep the name even if you delete a category.'**
  String get expenseCategoriesHint;

  /// No description provided for @expenseCategoryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Past cash-outs using this category will keep showing its name.'**
  String get expenseCategoryDeleteMessage;

  /// No description provided for @expenseEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get expenseEdit;

  /// No description provided for @expenseEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get expenseEdited;

  /// No description provided for @expenseLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get expenseLogged;

  /// No description provided for @expenseOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original entry'**
  String get expenseOriginal;

  /// No description provided for @expenseOriginalMissing.
  ///
  /// In en, this message translates to:
  /// **'The original entry is no longer on this device.'**
  String get expenseOriginalMissing;

  /// No description provided for @cashierExpenseNotEditable.
  ///
  /// In en, this message translates to:
  /// **'Only a cash-out from your open shift can be edited.'**
  String get cashierExpenseNotEditable;

  /// No description provided for @navWages.
  ///
  /// In en, this message translates to:
  /// **'Wages / Expenses'**
  String get navWages;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @summaryThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get summaryThisMonth;

  /// No description provided for @summarySelectedRange.
  ///
  /// In en, this message translates to:
  /// **'Selected Range'**
  String get summarySelectedRange;

  /// No description provided for @summaryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get summaryToday;

  /// No description provided for @summarySales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get summarySales;

  /// No description provided for @summaryExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get summaryExpenses;

  /// No description provided for @summaryNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get summaryNet;

  /// No description provided for @dashboardRecentSales.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get dashboardRecentSales;

  /// No description provided for @dashboardRecentExpenses.
  ///
  /// In en, this message translates to:
  /// **'Recent Expenses'**
  String get dashboardRecentExpenses;

  /// No description provided for @dashboardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashboardViewAll;

  /// No description provided for @expenseAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get expenseAllTypes;

  /// No description provided for @expenseColId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get expenseColId;

  /// No description provided for @expenseColWhen.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get expenseColWhen;

  /// No description provided for @expenseColCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get expenseColCashier;

  /// No description provided for @expenseColType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get expenseColType;

  /// No description provided for @expenseColDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expenseColDescription;

  /// No description provided for @expenseColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseColAmount;

  /// No description provided for @authSetupCode.
  ///
  /// In en, this message translates to:
  /// **'Setup code'**
  String get authSetupCode;

  /// No description provided for @authSetupCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Code from your provider'**
  String get authSetupCodeHint;

  /// No description provided for @authDeviceNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This device is not linked to a cafe yet. Ask your provider to link it from the developer tools.'**
  String get authDeviceNotLinked;

  /// No description provided for @authSetupCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The setup code is not valid for this cafe.'**
  String get authSetupCodeInvalid;

  /// No description provided for @adminDeleteTableBusy.
  ///
  /// In en, this message translates to:
  /// **'This table has an open order. Settle or cancel it before deleting the table.'**
  String get adminDeleteTableBusy;

  /// No description provided for @adminRegenerateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace QR code?'**
  String get adminRegenerateConfirmTitle;

  /// No description provided for @adminRegenerateConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The QR code already printed for this table will stop working. Print the new one and put it on the table.'**
  String get adminRegenerateConfirmMessage;

  /// No description provided for @adminRegenerateAllConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Every QR code already printed for your tables will stop working. You will need to print and place all the new ones.'**
  String get adminRegenerateAllConfirmMessage;

  /// No description provided for @adminRegenerateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get adminRegenerateConfirm;

  /// No description provided for @catalogCurrentPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'The current password is not correct.'**
  String get catalogCurrentPasswordWrong;

  /// No description provided for @catalogDeleteCashierTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove cashier?'**
  String get catalogDeleteCashierTitle;

  /// No description provided for @catalogDeleteCashierMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be able to sign in. Their past sales stay in the records.'**
  String catalogDeleteCashierMessage(String name);

  /// No description provided for @catalogDeleteCashierConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get catalogDeleteCashierConfirm;

  /// No description provided for @guestOrderingPaused.
  ///
  /// In en, this message translates to:
  /// **'Ordering is paused right now because the cashier is offline. You can still browse the menu.'**
  String get guestOrderingPaused;

  /// No description provided for @offlineWaiting.
  ///
  /// In en, this message translates to:
  /// **'Offline — {count} waiting to upload'**
  String offlineWaiting(int count);

  /// No description provided for @offlineUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {count}…'**
  String offlineUploading(int count);

  /// No description provided for @offlineNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'{count} saved item(s) could not be uploaded'**
  String offlineNeedsReview(int count);

  /// No description provided for @offlineNoNumbers.
  ///
  /// In en, this message translates to:
  /// **'No receipt numbers are reserved on this device. Connect to the internet once to continue selling offline.'**
  String get offlineNoNumbers;

  /// No description provided for @offlineOnlyTakeout.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Only quick takeout and expenses work until the connection returns.'**
  String get offlineOnlyTakeout;

  /// No description provided for @offlinePendingNumber.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get offlinePendingNumber;

  /// No description provided for @offlineUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Offline (no cashier yet)'**
  String get offlineUnassigned;

  /// No description provided for @offlineCloseShiftNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'This shift was started offline. It can be closed after the connection returns and a cashier takes it.'**
  String get offlineCloseShiftNeedsConnection;

  /// No description provided for @offlineStartTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineStartTitle;

  /// No description provided for @offlineStartBody.
  ///
  /// In en, this message translates to:
  /// **'You can keep selling quick takeout and recording expenses. Everything is saved on this device and uploaded when the connection returns.'**
  String get offlineStartBody;

  /// No description provided for @offlineStartButton.
  ///
  /// In en, this message translates to:
  /// **'Use offline'**
  String get offlineStartButton;

  /// No description provided for @offlineNeverOnline.
  ///
  /// In en, this message translates to:
  /// **'This device has not been online yet, so it has no saved menu. Connect to the internet once to use offline mode.'**
  String get offlineNeverOnline;

  /// No description provided for @offlineReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'The connection is back'**
  String get offlineReconnectTitle;

  /// No description provided for @offlineReconnectBody.
  ///
  /// In en, this message translates to:
  /// **'{count} receipt(s) and expense(s) were made offline. Which cashier do they belong to?'**
  String offlineReconnectBody(int count);

  /// No description provided for @offlineReconnectPin.
  ///
  /// In en, this message translates to:
  /// **'That cashier enters their PIN to upload them.'**
  String get offlineReconnectPin;

  /// No description provided for @offlineReconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Assign and upload'**
  String get offlineReconnectButton;

  /// No description provided for @offlineReconnectLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get offlineReconnectLater;

  /// No description provided for @offlineReconnectBanner.
  ///
  /// In en, this message translates to:
  /// **'The connection is back. Choose the cashier for the offline receipts to upload them.'**
  String get offlineReconnectBanner;

  /// No description provided for @offlineAssignBanner.
  ///
  /// In en, this message translates to:
  /// **'{count} receipt(s) made offline have no cashier yet. Choose who they belong to and they will upload.'**
  String offlineAssignBanner(int count);

  /// No description provided for @offlineAssignButton.
  ///
  /// In en, this message translates to:
  /// **'Choose cashier'**
  String get offlineAssignButton;

  /// No description provided for @offlineSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this on the device ({error}). Nothing was recorded; please try again.'**
  String offlineSaveFailed(String error);

  /// No description provided for @offlineSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to upload {count} saved item(s). Your session expired.'**
  String offlineSignInAgain(int count);

  /// No description provided for @offlineSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has expired. Sign in again to keep working and uploading.'**
  String get offlineSessionExpired;

  /// No description provided for @adminRequireCashierOnline.
  ///
  /// In en, this message translates to:
  /// **'Pause guest ordering when no cashier is online'**
  String get adminRequireCashierOnline;

  /// No description provided for @adminRequireCashierOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Guests can still read the menu, but cannot order, call staff or ask for the bill while no signed-in cashier device is connected. Turn this on once every till runs the updated app.'**
  String get adminRequireCashierOnlineHint;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer accepted. Install the update to keep working.'**
  String get updateRequiredBody;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Update {version} is ready'**
  String updateReady(String version);

  /// No description provided for @updateInstallNow.
  ///
  /// In en, this message translates to:
  /// **'Install now'**
  String get updateInstallNow;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Checking data and installing…'**
  String get updateInstalling;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading an update…'**
  String get updateDownloading;

  /// No description provided for @updateReadyAfterSignOut.
  ///
  /// In en, this message translates to:
  /// **'Update {version} is ready. It installs from the sign-in screen.'**
  String updateReadyAfterSignOut(String version);

  /// No description provided for @updateSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'Before installing, every sale is checked with the server and this till\'s data is backed up.'**
  String get updateSafetyNote;

  /// No description provided for @updateBlockSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign out first. Updates install from the sign-in screen.'**
  String get updateBlockSignedIn;

  /// No description provided for @updateBlockOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server, so the uploads can\'t be checked. Try again when online.'**
  String get updateBlockOffline;

  /// No description provided for @updateBlockPending.
  ///
  /// In en, this message translates to:
  /// **'Some sales are still waiting to upload. Sign in so they upload, then sign out and update.'**
  String get updateBlockPending;

  /// No description provided for @updateBlockFailed.
  ///
  /// In en, this message translates to:
  /// **'The server refused some uploads. Check them before updating.'**
  String get updateBlockFailed;

  /// No description provided for @updateBlockServerMissing.
  ///
  /// In en, this message translates to:
  /// **'The server is missing receipts or expenses from this till, so the update did not install.'**
  String get updateBlockServerMissing;

  /// No description provided for @updateBlockDownload.
  ///
  /// In en, this message translates to:
  /// **'The update could not be downloaded or failed its safety check. It will try again.'**
  String get updateBlockDownload;

  /// No description provided for @updateBlockBackup.
  ///
  /// In en, this message translates to:
  /// **'This till\'s data could not be backed up, so the update did not install.'**
  String get updateBlockBackup;

  /// No description provided for @updateNoticeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated to {version}. All sales were checked with the server.'**
  String updateNoticeUpdated(String version);

  /// No description provided for @updateNoticeNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'The update did not install. Nothing was changed.'**
  String get updateNoticeNotInstalled;

  /// No description provided for @updateNoticeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Updated, but the server and this till disagree about some sales. Contact support before closing the shift.'**
  String get updateNoticeMismatch;

  /// No description provided for @updateBackupAt.
  ///
  /// In en, this message translates to:
  /// **'Backup: {path}'**
  String updateBackupAt(String path);

  /// No description provided for @navLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get navLogOut;

  /// No description provided for @syncLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Register Sync'**
  String get syncLiveTitle;

  /// No description provided for @syncOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get syncOnline;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// No description provided for @cashierViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get cashierViewCart;

  /// No description provided for @cashierCartTitle.
  ///
  /// In en, this message translates to:
  /// **'{table} cart'**
  String cashierCartTitle(String table);

  /// No description provided for @cashierConfirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get cashierConfirmPayment;

  /// No description provided for @cashierCustomerPayment.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s payment'**
  String get cashierCustomerPayment;

  /// No description provided for @cashierChosenByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Chosen by the customer at the table'**
  String get cashierChosenByCustomer;

  /// No description provided for @cashierChangedByCashier.
  ///
  /// In en, this message translates to:
  /// **'Changed by cashier · customer chose {name}'**
  String cashierChangedByCashier(String name);

  /// No description provided for @cashierChangeMethod.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get cashierChangeMethod;

  /// No description provided for @cashierTapOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an order to see what they ordered.'**
  String get cashierTapOrderHint;

  /// No description provided for @dishActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{active} of {total} active'**
  String dishActiveCount(int active, int total);

  /// No description provided for @salesReceiptsTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} receipts · {total}'**
  String salesReceiptsTotal(int count, String total);

  /// No description provided for @dashboardSettledReceipts.
  ///
  /// In en, this message translates to:
  /// **'{count} settled receipts'**
  String dashboardSettledReceipts(int count);

  /// No description provided for @dashboardExpensesCaption.
  ///
  /// In en, this message translates to:
  /// **'Wages, supplies and cash-outs'**
  String get dashboardExpensesCaption;

  /// No description provided for @dashboardNetCaption.
  ///
  /// In en, this message translates to:
  /// **'Sales minus expenses'**
  String get dashboardNetCaption;

  /// No description provided for @dashboardSalesVsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Sales vs expenses'**
  String get dashboardSalesVsExpenses;

  /// No description provided for @dashboardChartBar.
  ///
  /// In en, this message translates to:
  /// **'{day}: sales {sales}, expenses {expenses}'**
  String dashboardChartBar(String day, String sales, String expenses);

  /// No description provided for @catalogActivePromos.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PROMOS'**
  String get catalogActivePromos;

  /// No description provided for @catalogNoActivePromos.
  ///
  /// In en, this message translates to:
  /// **'No promos are running.'**
  String get catalogNoActivePromos;

  /// No description provided for @catalogRemovePromo.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get catalogRemovePromo;

  /// No description provided for @catalogEditDishDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount for {dish}'**
  String catalogEditDishDiscount(String dish);

  /// No description provided for @layoutNoCategorySelected.
  ///
  /// In en, this message translates to:
  /// **'Choose a category on the left to see its dishes.'**
  String get layoutNoCategorySelected;

  /// No description provided for @layoutRenameCategory.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get layoutRenameCategory;

  /// No description provided for @layoutShowOnMenu.
  ///
  /// In en, this message translates to:
  /// **'Show on the menu'**
  String get layoutShowOnMenu;

  /// No description provided for @layoutMoveEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get layoutMoveEarlier;

  /// No description provided for @layoutMoveLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get layoutMoveLater;

  /// No description provided for @layoutEditDish.
  ///
  /// In en, this message translates to:
  /// **'Edit dish'**
  String get layoutEditDish;

  /// No description provided for @layoutNewCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW CATEGORY'**
  String get layoutNewCategoryLabel;

  /// No description provided for @settingsOrderingTitle.
  ///
  /// In en, this message translates to:
  /// **'Ordering & receipts'**
  String get settingsOrderingTitle;

  /// No description provided for @cafeLocationRequireHint.
  ///
  /// In en, this message translates to:
  /// **'Guests outside the radius can still browse the menu.'**
  String get cafeLocationRequireHint;

  /// No description provided for @catalogCashierPinMasked.
  ///
  /// In en, this message translates to:
  /// **'PIN ••••'**
  String get catalogCashierPinMasked;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @catalogLogoPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'LOGO'**
  String get catalogLogoPlaceholder;

  /// No description provided for @catalogPreviewButton.
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get catalogPreviewButton;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @payTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment type'**
  String get payTypeLabel;

  /// No description provided for @cashierCashOut.
  ///
  /// In en, this message translates to:
  /// **'Cash out'**
  String get cashierCashOut;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Cafe POS & QR ordering'**
  String get brandTagline;

  /// No description provided for @adminSaveQrPng.
  ///
  /// In en, this message translates to:
  /// **'Save QR image'**
  String get adminSaveQrPng;

  /// No description provided for @devPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer password'**
  String get devPasswordTitle;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @errNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The app is not connected to its server. Contact your provider.'**
  String get errNotConfigured;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check the internet connection and try again.'**
  String get errNetwork;

  /// No description provided for @errResetEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'The reset email could not be sent. Try again in a minute.'**
  String get errResetEmailFailed;

  /// No description provided for @errPasswordNotChanged.
  ///
  /// In en, this message translates to:
  /// **'The password was not changed. Try again.'**
  String get errPasswordNotChanged;

  /// No description provided for @authConfirmEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm the account from the email we sent, then sign in.'**
  String get authConfirmEmailFirst;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errGeneric;

  /// No description provided for @errSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again.'**
  String get errSessionExpired;

  /// No description provided for @errSignInAsCashier.
  ///
  /// In en, this message translates to:
  /// **'Sign in as a cashier first.'**
  String get errSignInAsCashier;

  /// No description provided for @errLineNotFound.
  ///
  /// In en, this message translates to:
  /// **'That dish is no longer on the order.'**
  String get errLineNotFound;

  /// No description provided for @errCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'The cart is empty.'**
  String get errCartEmpty;

  /// No description provided for @cashierNewOrderToast.
  ///
  /// In en, this message translates to:
  /// **'New order: {where}'**
  String cashierNewOrderToast(String where);

  /// No description provided for @tableOrderOpen.
  ///
  /// In en, this message translates to:
  /// **'Open table'**
  String get tableOrderOpen;

  /// No description provided for @tableOrderAddDishes.
  ///
  /// In en, this message translates to:
  /// **'Add dishes'**
  String get tableOrderAddDishes;

  /// No description provided for @tableOrderSend.
  ///
  /// In en, this message translates to:
  /// **'Add to the table\'s bill'**
  String get tableOrderSend;

  /// No description provided for @tableOrderSent.
  ///
  /// In en, this message translates to:
  /// **'Added to {table}.'**
  String tableOrderSent(String table);

  /// No description provided for @tableOrderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap dishes to add them to this table.'**
  String get tableOrderEmpty;

  /// No description provided for @tableOrderOnTab.
  ///
  /// In en, this message translates to:
  /// **'Already on the bill: {count} items, {total}'**
  String tableOrderOnTab(String count, String total);

  /// No description provided for @tableOrderBack.
  ///
  /// In en, this message translates to:
  /// **'Back to floor'**
  String get tableOrderBack;

  /// No description provided for @dishChoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'INGREDIENTS & EXTRAS'**
  String get dishChoicesTitle;

  /// No description provided for @dishChoicesHint.
  ///
  /// In en, this message translates to:
  /// **'Guests tap the dish to change these. The + button adds it as it comes.'**
  String get dishChoicesHint;

  /// No description provided for @dishChoicesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient or extra'**
  String get dishChoicesAdd;

  /// No description provided for @dishChoiceIngredient.
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get dishChoiceIngredient;

  /// No description provided for @dishChoiceTopping.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get dishChoiceTopping;

  /// No description provided for @dishChoiceInByDefault.
  ///
  /// In en, this message translates to:
  /// **'In the dish by default'**
  String get dishChoiceInByDefault;

  /// No description provided for @dishChoiceNameAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic name'**
  String get dishChoiceNameAr;

  /// No description provided for @dishChoiceNameEn.
  ///
  /// In en, this message translates to:
  /// **'English name'**
  String get dishChoiceNameEn;

  /// No description provided for @dishChoicePrice.
  ///
  /// In en, this message translates to:
  /// **'Price when added (0 = free)'**
  String get dishChoicePrice;

  /// No description provided for @dishChoiceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get dishChoiceRemove;

  /// No description provided for @dishChoicesIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get dishChoicesIngredients;

  /// No description provided for @dishChoicesExtras.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get dishChoicesExtras;

  /// No description provided for @dishChoicesApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get dishChoicesApply;

  /// No description provided for @dishChoicesTapLine.
  ///
  /// In en, this message translates to:
  /// **'Tap a line to change its ingredients.'**
  String get dishChoicesTapLine;

  /// No description provided for @dishChoiceWithout.
  ///
  /// In en, this message translates to:
  /// **'No {name}'**
  String dishChoiceWithout(String name);

  /// No description provided for @dishChoicesHoldCard.
  ///
  /// In en, this message translates to:
  /// **'choose ingredients and extras'**
  String get dishChoicesHoldCard;

  /// No description provided for @voidSale.
  ///
  /// In en, this message translates to:
  /// **'Void sale'**
  String get voidSale;

  /// No description provided for @voidSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this sale?'**
  String get voidSaleTitle;

  /// No description provided for @voidSaleMessage.
  ///
  /// In en, this message translates to:
  /// **'Use this when the customer left after paying. The sale stays in the log marked VOID and stops counting in sales and the drawer. Give back any cash yourself.'**
  String get voidSaleMessage;

  /// No description provided for @voidReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get voidReasonLabel;

  /// No description provided for @voidReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Customer left, food was late'**
  String get voidReasonHint;

  /// No description provided for @voidConfirm.
  ///
  /// In en, this message translates to:
  /// **'Void sale'**
  String get voidConfirm;

  /// No description provided for @voidDone.
  ///
  /// In en, this message translates to:
  /// **'Sale voided'**
  String get voidDone;

  /// No description provided for @voidStatus.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get voidStatus;

  /// No description provided for @voidReasonLine.
  ///
  /// In en, this message translates to:
  /// **'Void reason: {reason}'**
  String voidReasonLine(String reason);

  /// No description provided for @voidNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only the cashier who took this sale can void it, while their shift is open.'**
  String get voidNotAllowed;

  /// No description provided for @voidAlreadyDone.
  ///
  /// In en, this message translates to:
  /// **'This sale is already voided.'**
  String get voidAlreadyDone;

  /// No description provided for @voidReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a reason for the void.'**
  String get voidReasonRequired;

  /// No description provided for @voidWaitForSync.
  ///
  /// In en, this message translates to:
  /// **'This sale hasn\'t reached the server yet. Wait until it syncs, then void it.'**
  String get voidWaitForSync;

  /// No description provided for @navStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get navStock;

  /// No description provided for @stockHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off \"No limit\" and type how many are left. Every sale lowers the number, and at 0 the dish is sold out.'**
  String get stockHelp;

  /// No description provided for @stockNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get stockNoLimit;

  /// No description provided for @stockLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String stockLeft(int count);

  /// No description provided for @stockSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get stockSoldOut;

  /// No description provided for @stockQtyHint.
  ///
  /// In en, this message translates to:
  /// **'How many'**
  String get stockQtyHint;

  /// No description provided for @stockSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get stockSave;

  /// No description provided for @stockInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type a whole number from 0 to 100000.'**
  String get stockInvalid;

  /// No description provided for @stockSaved.
  ///
  /// In en, this message translates to:
  /// **'Stock saved for {dish}'**
  String stockSaved(String dish);

  /// No description provided for @kitchensTitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchens'**
  String get kitchensTitle;

  /// No description provided for @kitchensHint.
  ///
  /// In en, this message translates to:
  /// **'Add a kitchen for each place that cooks (pizza oven, grill, bar) and tick the categories it makes. Each kitchen gets a ticket with only its own dishes. Dishes from unticked categories go to the first kitchen.'**
  String get kitchensHint;

  /// No description provided for @kitchensAdd.
  ///
  /// In en, this message translates to:
  /// **'Add kitchen'**
  String get kitchensAdd;

  /// No description provided for @kitchensAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New kitchen'**
  String get kitchensAddTitle;

  /// No description provided for @kitchensEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit kitchen'**
  String get kitchensEditTitle;

  /// No description provided for @kitchensName.
  ///
  /// In en, this message translates to:
  /// **'Kitchen name'**
  String get kitchensName;

  /// No description provided for @kitchensCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories it makes'**
  String get kitchensCategories;

  /// No description provided for @kitchensNowIn.
  ///
  /// In en, this message translates to:
  /// **'Now in {kitchen}; ticking moves it here'**
  String kitchensNowIn(String kitchen);

  /// No description provided for @kitchensPrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer on this till'**
  String get kitchensPrinter;

  /// No description provided for @kitchensPrinterMain.
  ///
  /// In en, this message translates to:
  /// **'Main kitchen printer'**
  String get kitchensPrinterMain;

  /// No description provided for @kitchensPrintsOn.
  ///
  /// In en, this message translates to:
  /// **'Prints on: {printer}'**
  String kitchensPrintsOn(String printer);

  /// No description provided for @kitchensFirst.
  ///
  /// In en, this message translates to:
  /// **'{name} (first: gets unticked categories)'**
  String kitchensFirst(String name);

  /// No description provided for @kitchensNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories ticked'**
  String get kitchensNoCategories;

  /// No description provided for @kitchensSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get kitchensSave;

  /// No description provided for @kitchensDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String kitchensDeleteTitle(String name);

  /// No description provided for @kitchensDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Its categories go to the first kitchen. Tickets already printed are not changed.'**
  String get kitchensDeleteMessage;

  /// No description provided for @printersKitchensTitle.
  ///
  /// In en, this message translates to:
  /// **'Printers & kitchens'**
  String get printersKitchensTitle;

  /// No description provided for @settingsScopeThisTill.
  ///
  /// In en, this message translates to:
  /// **'This till · saved on this device only'**
  String get settingsScopeThisTill;

  /// No description provided for @printersTitle.
  ///
  /// In en, this message translates to:
  /// **'Printers'**
  String get printersTitle;

  /// No description provided for @printersHint.
  ///
  /// In en, this message translates to:
  /// **'Pick this till\'s printers. The kitchen printer prints each new order for the kitchen: order number, dishes, how many and toppings, no prices. The cashier printer prints receipts without asking.'**
  String get printersHint;

  /// No description provided for @printersWindowsOnly.
  ///
  /// In en, this message translates to:
  /// **'Printers are picked on the Windows till. Open these settings there.'**
  String get printersWindowsOnly;

  /// No description provided for @printersRefresh.
  ///
  /// In en, this message translates to:
  /// **'Look for printers again'**
  String get printersRefresh;

  /// No description provided for @printersKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen printer'**
  String get printersKitchen;

  /// No description provided for @printersKitchenNone.
  ///
  /// In en, this message translates to:
  /// **'None (no kitchen tickets)'**
  String get printersKitchenNone;

  /// No description provided for @printersReceipt.
  ///
  /// In en, this message translates to:
  /// **'Cashier printer (receipts)'**
  String get printersReceipt;

  /// No description provided for @printersReceiptNone.
  ///
  /// In en, this message translates to:
  /// **'None (ask each time)'**
  String get printersReceiptNone;

  /// No description provided for @printersMissing.
  ///
  /// In en, this message translates to:
  /// **'{name} (not connected)'**
  String printersMissing(String name);

  /// No description provided for @printersTestKitchen.
  ///
  /// In en, this message translates to:
  /// **'Print a test kitchen ticket'**
  String get printersTestKitchen;

  /// No description provided for @printersTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test ticket sent to the kitchen printer.'**
  String get printersTestSent;

  /// No description provided for @kitchenPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'The kitchen ticket did not print. Check the kitchen printer in Settings.'**
  String get kitchenPrintFailed;

  /// No description provided for @kitchenPrintFailedAt.
  ///
  /// In en, this message translates to:
  /// **'The ticket for {kitchens} did not print. Check its printer in Settings.'**
  String kitchenPrintFailedAt(String kitchens);

  /// No description provided for @kitchenTicketTitle.
  ///
  /// In en, this message translates to:
  /// **'KITCHEN'**
  String get kitchenTicketTitle;

  /// No description provided for @kitchenTicketAdded.
  ///
  /// In en, this message translates to:
  /// **'ADDED TO THE ORDER'**
  String get kitchenTicketAdded;

  /// No description provided for @kitchenTestDish.
  ///
  /// In en, this message translates to:
  /// **'Test dish'**
  String get kitchenTestDish;

  /// No description provided for @printersLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking for printers…'**
  String get printersLooking;

  /// No description provided for @printersReceiptHint.
  ///
  /// In en, this message translates to:
  /// **'Pick this till\'s cashier printer. Receipts then print on it without asking.'**
  String get printersReceiptHint;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback to your provider'**
  String get feedbackTitle;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Found a problem or have an idea? Tell us. Every message is read.'**
  String get feedbackHint;

  /// No description provided for @feedbackKindProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get feedbackKindProblem;

  /// No description provided for @feedbackKindIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get feedbackKindIdea;

  /// No description provided for @feedbackKindQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get feedbackKindQuestion;

  /// No description provided for @feedbackKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get feedbackKindOther;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSend;

  /// No description provided for @feedbackSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you, your message was sent.'**
  String get feedbackSent;

  /// No description provided for @feedbackEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a message first.'**
  String get feedbackEmpty;

  /// No description provided for @feedbackTooMany.
  ///
  /// In en, this message translates to:
  /// **'You have sent the most messages allowed today. Try again tomorrow.'**
  String get feedbackTooMany;

  /// No description provided for @feedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message. Check the connection and try again.'**
  String get feedbackFailed;

  /// No description provided for @expenseEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee (optional)'**
  String get expenseEmployee;

  /// No description provided for @expenseEmployeeNone.
  ///
  /// In en, this message translates to:
  /// **'No employee'**
  String get expenseEmployeeNone;

  /// No description provided for @takeoutScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Takeout screen'**
  String get takeoutScreenTitle;

  /// No description provided for @takeoutLayoutSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get takeoutLayoutSave;

  /// No description provided for @takeoutLayoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Takeout screen saved.'**
  String get takeoutLayoutSaved;

  /// No description provided for @takeoutLayoutSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the takeout screen. Check the connection and try again.'**
  String get takeoutLayoutSaveFailed;

  /// No description provided for @takeoutLayoutClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get takeoutLayoutClassic;

  /// No description provided for @takeoutLayoutClassicHint.
  ///
  /// In en, this message translates to:
  /// **'All dishes at once, with a bar on top to filter by category.'**
  String get takeoutLayoutClassicHint;

  /// No description provided for @takeoutLayoutCards.
  ///
  /// In en, this message translates to:
  /// **'Category cards'**
  String get takeoutLayoutCards;

  /// No description provided for @takeoutLayoutCardsHint.
  ///
  /// In en, this message translates to:
  /// **'White cards with a picture for each category; tap one to see its dishes.'**
  String get takeoutLayoutCardsHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
