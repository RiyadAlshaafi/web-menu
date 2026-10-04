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

  /// Sample greeting
  ///
  /// In en, this message translates to:
  /// **'Hello World'**
  String get helloWorld;

  /// Welcome line shown when a locale is active
  ///
  /// In en, this message translates to:
  /// **'Welcome to Café Italiano'**
  String get welcomeMessage;

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

  /// No description provided for @noCalls.
  ///
  /// In en, this message translates to:
  /// **'No assistance calls.'**
  String get noCalls;

  /// No description provided for @noBills.
  ///
  /// In en, this message translates to:
  /// **'No pending bill requests.'**
  String get noBills;

  /// No description provided for @noMenu.
  ///
  /// In en, this message translates to:
  /// **'No menu items available.'**
  String get noMenu;

  /// No description provided for @menuSoon.
  ///
  /// In en, this message translates to:
  /// **'Menu coming soon'**
  String get menuSoon;

  /// No description provided for @noSales.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded yet.'**
  String get noSales;

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

  /// No description provided for @salesAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get salesAllStatuses;

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

  /// No description provided for @salesColId.
  ///
  /// In en, this message translates to:
  /// **'Receipt No.'**
  String get salesColId;

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

  /// No description provided for @salesColTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get salesColTax;

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

  /// No description provided for @salesOwnOnly.
  ///
  /// In en, this message translates to:
  /// **'Showing your sales only.'**
  String get salesOwnOnly;

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

  /// No description provided for @quickTakeoutNeedTable.
  ///
  /// In en, this message translates to:
  /// **'Add a table named Takeout in Tables & QR, then try again.'**
  String get quickTakeoutNeedTable;

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
  /// **'No open bill for this table.'**
  String get errNoOpenBill;

  /// No description provided for @guestOrderFirst.
  ///
  /// In en, this message translates to:
  /// **'Place an order first.'**
  String get guestOrderFirst;

  /// No description provided for @guestBillAfterServed.
  ///
  /// In en, this message translates to:
  /// **'You can request the bill after the waiter marks your order served.'**
  String get guestBillAfterServed;

  /// No description provided for @errNoOpenShift.
  ///
  /// In en, this message translates to:
  /// **'No open shift.'**
  String get errNoOpenShift;

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
  /// **'Café Italiano POS System  •  Terminal Station 04  •  Secure Hospitality Gateway'**
  String get authPosFooter;

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
  /// **'© Café Italiano Firenze 1984   •   Terminal Auth Gateway v4.9'**
  String get authChangePasswordFooter;

  /// No description provided for @adminConsoleLabel.
  ///
  /// In en, this message translates to:
  /// **'ADMIN CONSOLE'**
  String get adminConsoleLabel;

  /// No description provided for @adminManagementHeading.
  ///
  /// In en, this message translates to:
  /// **'MANAGEMENT'**
  String get adminManagementHeading;

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

  /// No description provided for @adminWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get adminWorkspace;

  /// No description provided for @adminTerminalBadge.
  ///
  /// In en, this message translates to:
  /// **'●  Terminal #01  ·  Secure Node'**
  String get adminTerminalBadge;

  /// No description provided for @adminCustomerView.
  ///
  /// In en, this message translates to:
  /// **'Customer View'**
  String get adminCustomerView;

  /// No description provided for @adminFloorOrderingHeading.
  ///
  /// In en, this message translates to:
  /// **'FLOOR & ORDERING'**
  String get adminFloorOrderingHeading;

  /// No description provided for @adminTablesQrHub.
  ///
  /// In en, this message translates to:
  /// **'Tables & QR Hub'**
  String get adminTablesQrHub;

  /// No description provided for @adminStations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get adminStations;

  /// No description provided for @adminSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get adminSessions;

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
  /// **'Do you want to delete this table? This action cannot be undone and will permanently remove it from the floor plan and ordering system.'**
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

  /// No description provided for @layoutClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get layoutClose;

  /// No description provided for @layoutNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get layoutNewCategory;

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

  /// No description provided for @layoutItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String layoutItemCount(String count);

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

  /// No description provided for @layoutDropDishHint.
  ///
  /// In en, this message translates to:
  /// **'Drop dish here to reorder or reassign to {category}'**
  String layoutDropDishHint(String category);

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

  /// No description provided for @layoutDishNameLabel.
  ///
  /// In en, this message translates to:
  /// **'DISH NAME (ITALIAN / ENGLISH) *'**
  String get layoutDishNameLabel;

  /// No description provided for @layoutDishNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Pappardelle ai Funghi Porcini'**
  String get layoutDishNameHint;

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
  /// **'PRICE (€ EUR) *'**
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
  /// **'Public menu URL'**
  String get catalogPublicMenuUrl;

  /// No description provided for @catalogPublicMenuUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-cafe.vercel.app'**
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

  /// No description provided for @catalogApplyLanguageToQr.
  ///
  /// In en, this message translates to:
  /// **'Apply language to customer QR menus automatically'**
  String get catalogApplyLanguageToQr;

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
  /// **'Cashier name'**
  String get catalogCashierName;

  /// No description provided for @catalogCashierPinLabel.
  ///
  /// In en, this message translates to:
  /// **'4-digit secret passcode'**
  String get catalogCashierPinLabel;

  /// No description provided for @catalogSaveCashier.
  ///
  /// In en, this message translates to:
  /// **'Save Cashier'**
  String get catalogSaveCashier;

  /// No description provided for @cashierLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get cashierLanguage;

  /// No description provided for @cashierPosTerminal.
  ///
  /// In en, this message translates to:
  /// **'POS TERMINAL 01'**
  String get cashierPosTerminal;

  /// No description provided for @cashierSoloShiftLive.
  ///
  /// In en, this message translates to:
  /// **'Solo Shift Live'**
  String get cashierSoloShiftLive;

  /// No description provided for @cashierAllInOne.
  ///
  /// In en, this message translates to:
  /// **'ALL-IN-ONE'**
  String get cashierAllInOne;

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

  /// No description provided for @cashierStationFrontCounter.
  ///
  /// In en, this message translates to:
  /// **'Station 1: Front Counter'**
  String get cashierStationFrontCounter;

  /// No description provided for @cashierAudioOn.
  ///
  /// In en, this message translates to:
  /// **'Audio On'**
  String get cashierAudioOn;

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

  /// No description provided for @cashierQuickTableStatus.
  ///
  /// In en, this message translates to:
  /// **'Quick Table Status ({count})'**
  String cashierQuickTableStatus(String count);

  /// No description provided for @cashierTableShort.
  ///
  /// In en, this message translates to:
  /// **'T-{number}'**
  String cashierTableShort(String number);

  /// No description provided for @cashierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get cashierFree;

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

  /// No description provided for @cashierActiveBillOutRequest.
  ///
  /// In en, this message translates to:
  /// **'Active Bill Out Request  •  Table {number}'**
  String cashierActiveBillOutRequest(String number);

  /// No description provided for @cashierItemsToSettle.
  ///
  /// In en, this message translates to:
  /// **'Items to Settle'**
  String get cashierItemsToSettle;

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

  /// No description provided for @cashierCashPayment.
  ///
  /// In en, this message translates to:
  /// **'Cash Payment'**
  String get cashierCashPayment;

  /// No description provided for @cashierTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due'**
  String get cashierTotalDue;

  /// No description provided for @cashierCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash Received'**
  String get cashierCashReceived;

  /// No description provided for @cashierChangeDue.
  ///
  /// In en, this message translates to:
  /// **'Change Due'**
  String get cashierChangeDue;

  /// No description provided for @cashierConfirmCash.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cash'**
  String get cashierConfirmCash;

  /// No description provided for @cashierOrderItems.
  ///
  /// In en, this message translates to:
  /// **'Order items'**
  String get cashierOrderItems;

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

  /// No description provided for @cashierIncludesSurcharge.
  ///
  /// In en, this message translates to:
  /// **'Includes service charge'**
  String get cashierIncludesSurcharge;

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

  /// No description provided for @cashierSplitBill.
  ///
  /// In en, this message translates to:
  /// **'Split Bill'**
  String get cashierSplitBill;

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
  /// **'Service charge ({percent})'**
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

  /// No description provided for @guestItemRemoved.
  ///
  /// In en, this message translates to:
  /// **'Item removed: {name} — currently unavailable.'**
  String guestItemRemoved(String name);

  /// No description provided for @guestConfirmRequestBill.
  ///
  /// In en, this message translates to:
  /// **'Confirm and request bill'**
  String get guestConfirmRequestBill;

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

  /// No description provided for @cashierNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get cashierNotAvailable;

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

  /// No description provided for @cashierCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get cashierCall;

  /// No description provided for @cashierFloorManagement.
  ///
  /// In en, this message translates to:
  /// **'FLOOR MANAGEMENT'**
  String get cashierFloorManagement;

  /// No description provided for @cashierFloorOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Floor Overview & Tables'**
  String get cashierFloorOverviewTitle;

  /// No description provided for @cashierTablesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} TABLES'**
  String cashierTablesCount(String count);

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

  /// No description provided for @cashierDiningActive.
  ///
  /// In en, this message translates to:
  /// **'Dining active'**
  String get cashierDiningActive;

  /// No description provided for @cashierBillPending.
  ///
  /// In en, this message translates to:
  /// **'Bill pending'**
  String get cashierBillPending;

  /// No description provided for @cashierSoloStationSync.
  ///
  /// In en, this message translates to:
  /// **'SOLO STATION  •  Live Register Sync'**
  String get cashierSoloStationSync;

  /// No description provided for @cashierShiftSalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Sales & Register Logs'**
  String get cashierShiftSalesTitle;

  /// No description provided for @cashierExportSummary.
  ///
  /// In en, this message translates to:
  /// **'Export Summary (PDF/CSV)'**
  String get cashierExportSummary;

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

  /// No description provided for @cashierTillBalance.
  ///
  /// In en, this message translates to:
  /// **'Till Balance & Drawer #01'**
  String get cashierTillBalance;

  /// No description provided for @cashierActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get cashierActive;

  /// No description provided for @cashierOpeningFloat.
  ///
  /// In en, this message translates to:
  /// **'Opening Float'**
  String get cashierOpeningFloat;

  /// No description provided for @cashierOpeningFloatRow.
  ///
  /// In en, this message translates to:
  /// **'Opening Float:'**
  String get cashierOpeningFloatRow;

  /// No description provided for @cashierCashCollected.
  ///
  /// In en, this message translates to:
  /// **'Cash Collected:'**
  String get cashierCashCollected;

  /// No description provided for @cashierCardDigitalPayments.
  ///
  /// In en, this message translates to:
  /// **'Card / Digital Payments:'**
  String get cashierCardDigitalPayments;

  /// No description provided for @cashierExpectedInDrawer.
  ///
  /// In en, this message translates to:
  /// **'Expected in Drawer:'**
  String get cashierExpectedInDrawer;

  /// No description provided for @cashierToleranceNote.
  ///
  /// In en, this message translates to:
  /// **'Counting discrepancy tolerance is ±€2.00. Please ensure all dining table chits are settled before closing register.'**
  String get cashierToleranceNote;

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

  /// No description provided for @cashierMidShiftChit.
  ///
  /// In en, this message translates to:
  /// **'Mid-Shift Cash Count Chit'**
  String get cashierMidShiftChit;

  /// No description provided for @guestNavMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get guestNavMenu;

  /// No description provided for @guestTableBill.
  ///
  /// In en, this message translates to:
  /// **'Table Bill'**
  String get guestTableBill;

  /// No description provided for @guestRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get guestRequestSent;

  /// No description provided for @guestCallStaff.
  ///
  /// In en, this message translates to:
  /// **'Call Staff'**
  String get guestCallStaff;

  /// No description provided for @guestTableNumber.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String guestTableNumber(String number);

  /// No description provided for @guestDineInOrder.
  ///
  /// In en, this message translates to:
  /// **'Dine-in Order'**
  String get guestDineInOrder;

  /// No description provided for @guestMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Mezzogiorno Menu'**
  String get guestMenuTitle;

  /// No description provided for @guestChefsSpecials.
  ///
  /// In en, this message translates to:
  /// **'Chef\'s Specials'**
  String get guestChefsSpecials;

  /// No description provided for @guestCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get guestCategoryAll;

  /// No description provided for @guestSpotlight.
  ///
  /// In en, this message translates to:
  /// **'Spotlight'**
  String get guestSpotlight;

  /// No description provided for @guestItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String guestItemCount(String count);

  /// No description provided for @guestCartItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items • Cart'**
  String guestCartItemCount(String count);

  /// No description provided for @guestViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View Order'**
  String get guestViewOrder;

  /// No description provided for @guestOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get guestOrderButton;

  /// No description provided for @guestConfirmOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Order'**
  String get guestConfirmOrderTitle;

  /// No description provided for @guestItemsInOrder.
  ///
  /// In en, this message translates to:
  /// **'Items in order ({count})'**
  String guestItemsInOrder(String count);

  /// No description provided for @guestConfirmSendKitchen.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Send to Kitchen'**
  String get guestConfirmSendKitchen;

  /// No description provided for @guestModifyOrder.
  ///
  /// In en, this message translates to:
  /// **'Modify Order & Back to Menu'**
  String get guestModifyOrder;

  /// No description provided for @guestBilledToTable.
  ///
  /// In en, this message translates to:
  /// **'Billed to table {table}'**
  String guestBilledToTable(String table);

  /// No description provided for @guestCloseReview.
  ///
  /// In en, this message translates to:
  /// **'Close review'**
  String get guestCloseReview;

  /// No description provided for @guestSendingOrder.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get guestSendingOrder;

  /// No description provided for @guestTableDineIn.
  ///
  /// In en, this message translates to:
  /// **'Table {number} • Dine-in'**
  String guestTableDineIn(String number);

  /// No description provided for @guestChefsPick.
  ///
  /// In en, this message translates to:
  /// **'CHEF\'S PICK'**
  String get guestChefsPick;

  /// No description provided for @guestQuantity.
  ///
  /// In en, this message translates to:
  /// **'QUANTITY'**
  String get guestQuantity;

  /// No description provided for @guestPortionServing.
  ///
  /// In en, this message translates to:
  /// **'Portion serving'**
  String get guestPortionServing;

  /// No description provided for @guestAddToOrder.
  ///
  /// In en, this message translates to:
  /// **'Add to Order • {amount}'**
  String guestAddToOrder(String amount);

  /// No description provided for @guestLiveTab.
  ///
  /// In en, this message translates to:
  /// **'Live Tab'**
  String get guestLiveTab;

  /// No description provided for @guestOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String guestOrderNumber(String id);

  /// No description provided for @guestSentToKitchenAt.
  ///
  /// In en, this message translates to:
  /// **'Sent to the hearth at {time}'**
  String guestSentToKitchenAt(String time);

  /// No description provided for @guestKitchenPreparing.
  ///
  /// In en, this message translates to:
  /// **'Kitchen is preparing your order\nEstimated delivery in 10–15 mins'**
  String get guestKitchenPreparing;

  /// No description provided for @guestNewAdditions.
  ///
  /// In en, this message translates to:
  /// **'New Additions'**
  String get guestNewAdditions;

  /// No description provided for @guestTicketSummary.
  ///
  /// In en, this message translates to:
  /// **'Ticket Summary'**
  String get guestTicketSummary;

  /// No description provided for @guestKitchenTicketTotal.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Ticket Total'**
  String get guestKitchenTicketTotal;

  /// No description provided for @guestCallServer.
  ///
  /// In en, this message translates to:
  /// **'Call Server'**
  String get guestCallServer;

  /// No description provided for @guestRequestBill.
  ///
  /// In en, this message translates to:
  /// **'Request Bill'**
  String get guestRequestBill;

  /// No description provided for @guestPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order • {amount}'**
  String guestPlaceOrder(String amount);

  /// No description provided for @guestOrdersSentInstantly.
  ///
  /// In en, this message translates to:
  /// **'Orders are sent instantly to the kitchen'**
  String get guestOrdersSentInstantly;

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

  /// No description provided for @guestFinalTab.
  ///
  /// In en, this message translates to:
  /// **'Final Tab'**
  String get guestFinalTab;

  /// No description provided for @guestOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get guestOrderSummary;

  /// No description provided for @guestRefNumber.
  ///
  /// In en, this message translates to:
  /// **'Ref #{id}'**
  String guestRefNumber(String id);

  /// No description provided for @guestPaid.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get guestPaid;

  /// No description provided for @guestPaymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get guestPaymentSuccessful;

  /// No description provided for @guestThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for dining with Cafe Italiano!'**
  String get guestThankYou;

  /// No description provided for @guestSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get guestSubtotal;

  /// No description provided for @guestServiceCharge.
  ///
  /// In en, this message translates to:
  /// **'Service Charge ({percent}%)'**
  String guestServiceCharge(String percent);

  /// No description provided for @guestVatIncluded.
  ///
  /// In en, this message translates to:
  /// **'Hospitality & VAT (Included)'**
  String get guestVatIncluded;

  /// No description provided for @guestTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due'**
  String get guestTotalDue;

  /// No description provided for @guestWannaCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Wanna Check In'**
  String get guestWannaCheckIn;

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

  /// No description provided for @payTypeInUse.
  ///
  /// In en, this message translates to:
  /// **'This type is already used on a sale. Disable it instead of deleting it.'**
  String get payTypeInUse;

  /// No description provided for @payChoose.
  ///
  /// In en, this message translates to:
  /// **'How will you pay?'**
  String get payChoose;

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

  /// No description provided for @guestLoadingTable.
  ///
  /// In en, this message translates to:
  /// **'Loading your table...'**
  String get guestLoadingTable;

  /// No description provided for @staffOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening...'**
  String get staffOpening;

  /// No description provided for @guestQrInvalid.
  ///
  /// In en, this message translates to:
  /// **'This QR code doesn\'t match a table.'**
  String get guestQrInvalid;

  /// No description provided for @guestQrInvalidHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the cafe for a new code.'**
  String get guestQrInvalidHint;

  /// No description provided for @guestRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get guestRetry;

  /// No description provided for @guestChooseService.
  ///
  /// In en, this message translates to:
  /// **'How are you ordering?'**
  String get guestChooseService;

  /// No description provided for @guestChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get guestChooseLanguage;

  /// No description provided for @guestDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-in'**
  String get guestDineIn;

  /// No description provided for @guestDineInHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll serve this table.'**
  String get guestDineInHint;

  /// No description provided for @guestTakeout.
  ///
  /// In en, this message translates to:
  /// **'Takeout'**
  String get guestTakeout;

  /// No description provided for @guestTakeoutHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll pick it up. This table stays free.'**
  String get guestTakeoutHint;

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

  /// No description provided for @clearCashierLog.
  ///
  /// In en, this message translates to:
  /// **'Clear cashier log'**
  String get clearCashierLog;

  /// No description provided for @clearCashierLogConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes your sales from the cashier log and restarts today\'s ticket numbers so you can test again.'**
  String get clearCashierLogConfirm;

  /// No description provided for @clearShiftSales.
  ///
  /// In en, this message translates to:
  /// **'Clear shift sales & logs'**
  String get clearShiftSales;

  /// No description provided for @clearShiftSalesConfirm.
  ///
  /// In en, this message translates to:
  /// **'This clears the register log, resets shift totals, and restarts today\'s ticket numbers so you can test again.'**
  String get clearShiftSalesConfirm;

  /// No description provided for @clearLogsDone.
  ///
  /// In en, this message translates to:
  /// **'Cleared.'**
  String get clearLogsDone;

  /// No description provided for @salesLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get salesLoadMore;

  /// No description provided for @cafeLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cafe location'**
  String get cafeLocationTitle;

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

  /// No description provided for @guestLocationTooFar.
  ///
  /// In en, this message translates to:
  /// **'You\'re too far from the cafe to order. You can still browse the menu.'**
  String get guestLocationTooFar;

  /// No description provided for @guestLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is needed to place an order. You can still browse the menu.'**
  String get guestLocationDenied;

  /// No description provided for @guestLocationAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get guestLocationAllow;

  /// No description provided for @guestLocationIosHint.
  ///
  /// In en, this message translates to:
  /// **'On iPhone, turn location back on in the browser\'s site settings.'**
  String get guestLocationIosHint;

  /// No description provided for @guestLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read your location. You can still browse the menu.'**
  String get guestLocationUnavailable;

  /// No description provided for @guestLocationRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get guestLocationRetry;

  /// No description provided for @guestLocationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your location…'**
  String get guestLocationChecking;

  /// No description provided for @cashierAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense / Cash Out'**
  String get cashierAddExpense;

  /// No description provided for @cashierExpenseFor.
  ///
  /// In en, this message translates to:
  /// **'Paid To / Expense For'**
  String get cashierExpenseFor;

  /// No description provided for @cashierExpenseCafe.
  ///
  /// In en, this message translates to:
  /// **'Café'**
  String get cashierExpenseCafe;

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
