// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get helloWorld => 'Hello World';

  @override
  String get welcomeMessage => 'Welcome to Café Italiano';

  @override
  String get noTables => 'No tables have been created yet.';

  @override
  String get noOrders => 'No active orders.';

  @override
  String get noCalls => 'No assistance calls.';

  @override
  String get noBills => 'No pending bill requests.';

  @override
  String get noMenu => 'No menu items available.';

  @override
  String get menuSoon => 'Menu coming soon';

  @override
  String get noSales => 'No sales recorded yet.';

  @override
  String get noCashiers => 'No cashiers have been created yet.';

  @override
  String get noTransactions => 'No transactions yet.';

  @override
  String get insufficientCash => 'Insufficient cash.';

  @override
  String get createCategoryFirst => 'Create a category first.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get navMenuCatalogLabel => 'Menu Catalog &\nLayout';

  @override
  String get navMenuCatalog => 'Menu Catalog & Layout';

  @override
  String get navDiscounts => 'Discounts';

  @override
  String get navTablesQr => 'Tables & QR Hub';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLiveAlerts => 'Live Alerts & Queue';

  @override
  String get navFloorOverview => 'Floor Overview';

  @override
  String get navShiftSales => 'Shift Sales & Logs';

  @override
  String get errAdminExists => 'Admin already exists.';

  @override
  String get errInvalidEmail => 'Enter a valid email.';

  @override
  String get errPasswordsMismatch => 'Passwords must match exactly.';

  @override
  String get errWeakPassword =>
      'Password must include 8+ characters, a capital letter, a number, and a special symbol.';

  @override
  String get errNoAdmin => 'No admin account exists yet.';

  @override
  String get errBadCredentials => 'Invalid email or password.';

  @override
  String get errBadCode => 'Invalid or expired code.';

  @override
  String get errVerifyCodeFirst => 'Verify the safe code first.';

  @override
  String get errSelectCashier => 'Select a cashier profile.';

  @override
  String get errEnterPin => 'Enter the 4-digit PIN.';

  @override
  String errPinMismatch(String name) {
    return 'PIN does not match $name.';
  }

  @override
  String errPinLocked(String name, int minutes) {
    return 'Too many wrong PINs for $name. Try again in $minutes min.';
  }

  @override
  String get errCashierSignInFirst => 'Sign in as a cashier first.';

  @override
  String get errNoOpenBill => 'No open bill for this table.';

  @override
  String get guestOrderFirst => 'Place an order first.';

  @override
  String get guestBillAfterServed =>
      'You can request the bill after the waiter marks your order served.';

  @override
  String get errNoOpenShift => 'No open shift.';

  @override
  String get authGuestCashier => 'Guest Cashier';

  @override
  String get authPosTerminalSubtitle => 'Point of Sale\nTerminal';

  @override
  String get authSwitchToAdminSignIn => 'Switch to Admin Sign In';

  @override
  String get authCashierSignInTitle => 'Cashier Sign In';

  @override
  String get authCashierSignInSubtitle =>
      'Select cashier profile and enter 4-digit PIN';

  @override
  String get authAuthenticatingAs => 'Authenticating as ';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authPosFooter =>
      'Café Italiano POS System  •  Terminal Station 04  •  Secure Hospitality Gateway';

  @override
  String get authPinClear => 'Clear';

  @override
  String get authStaffPos => 'Staff POS  →';

  @override
  String get authCreateAdminAccess => 'Create Admin Access';

  @override
  String get authAdminSignIn => 'Admin Sign In';

  @override
  String get authManagerEmail => 'Manager Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authCreateStrongPassword => 'Create a strong password';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authRepeatPassword => 'Repeat password';

  @override
  String get authKeepSignedIn => 'Keep me signed in';

  @override
  String get authCreateAccessCta => 'Create Access  →';

  @override
  String get authSignInCta => 'Sign In  →';

  @override
  String get authHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get authForgotPasswordTitle => 'Forgot Password';

  @override
  String get authForgotPasswordSubtitle =>
      'Enter the safe code to change your password';

  @override
  String get authSafeCodeSent =>
      'A security safe code was sent to the registered manager device / email.';

  @override
  String get authDidntReceive => 'Didn\'t receive it?  ';

  @override
  String authResendCodeIn(String time) {
    return 'Resend safe code ($time)';
  }

  @override
  String get authResendCode => 'Resend safe code';

  @override
  String get authVerifyCodeCta => 'Verify Code & Continue  →';

  @override
  String get authBackToSignIn => '←  Back to Sign In';

  @override
  String get authForgotFooter =>
      'Station #POS-01   •   256-Bit Cryptographic Vault';

  @override
  String get authHospitalityCoreAdmin => 'HOSPITALITY CORE • ADMIN';

  @override
  String get authSetNewPasswordTitle => 'Set New Password';

  @override
  String get authSetNewPasswordSubtitle =>
      'Enter your new password to regain access to your admin account and management console.';

  @override
  String get authNewPassword => 'New Password';

  @override
  String get authConfirmNewPassword => 'Confirm New Password';

  @override
  String get authPasswordsMustMatch => 'Passwords must match exactly';

  @override
  String get authPasswordRequirements => 'PASSWORD REQUIREMENTS';

  @override
  String get authReqMinLength => '8+ characters';

  @override
  String get authReqNumber => 'At least 1 number';

  @override
  String get authReqCapital => 'Capital letter';

  @override
  String get authReqSymbol => 'Special symbol';

  @override
  String get authUpdatePasswordCta => 'Update Password & Continue  →';

  @override
  String get authReturnToStaffSignIn => '←  Return to Staff Sign In';

  @override
  String get authChangePasswordFooter =>
      '© Café Italiano Firenze 1984   •   Terminal Auth Gateway v4.9';

  @override
  String get adminConsoleLabel => 'ADMIN CONSOLE';

  @override
  String get adminManagementHeading => 'MANAGEMENT';

  @override
  String get adminDefaultName => 'Admin';

  @override
  String get adminGeneralManager => 'General Manager';

  @override
  String get adminWorkspace => 'Workspace';

  @override
  String get adminTerminalBadge => '●  Terminal #01  ·  Secure Node';

  @override
  String get adminCustomerView => 'Customer View';

  @override
  String get adminFloorOrderingHeading => 'FLOOR & ORDERING';

  @override
  String get adminTablesQrHub => 'Tables & QR Hub';

  @override
  String get adminStations => 'Stations';

  @override
  String get adminSessions => 'Sessions';

  @override
  String get adminSearchTableHint => 'Search table or zone...';

  @override
  String get adminAddTableButton => '+ Add Table';

  @override
  String adminTableNumber(String number) {
    return 'Table $number';
  }

  @override
  String get adminTableAvailable => 'Available';

  @override
  String get adminTableOccupied => 'Occupied';

  @override
  String get adminScanToOrderPay => 'Scan to Order & Pay';

  @override
  String get adminNoAppInstall => 'No app install required';

  @override
  String get adminPrintStandCard => 'Print Stand Card (PDF)';

  @override
  String get adminAddTableTitle => 'Add Table';

  @override
  String get adminTableNumberLabel => 'Table number / name';

  @override
  String get adminCreate => 'Create';

  @override
  String get adminDeleteTableTitle => 'Delete Table?';

  @override
  String get adminDeleteTableMessage =>
      'Do you want to delete this table? This action cannot be undone and will permanently remove it from the floor plan and ordering system.';

  @override
  String get adminDeleteTableConfirm => 'Delete Table';

  @override
  String get layoutTitle => 'Menu Layout & Display Editor';

  @override
  String get layoutSavedSnack => 'Menu layout saved.';

  @override
  String get layoutSaveMenu => 'Save Menu Layout';

  @override
  String get layoutSequencingHeading => 'CATEGORY SEQUENCING & DISHES TREE';

  @override
  String get layoutReorderHint => 'Use arrows to reorder';

  @override
  String get layoutClose => 'Close';

  @override
  String get layoutNewCategory => 'New Category';

  @override
  String get layoutCategoryNameHint =>
      'Enter Category Name (e.g. Bevande & Wines, Desserts)';

  @override
  String get layoutCreateCategory => 'Create Category';

  @override
  String get layoutSpotlight => 'SPOTLIGHT';

  @override
  String get layoutOneDish => '1 Dish';

  @override
  String layoutDishCount(String count) {
    return '$count Dishes';
  }

  @override
  String layoutItemCount(String count) {
    return '$count items';
  }

  @override
  String get layoutCurrentlyInspecting => 'Currently Inspecting';

  @override
  String get layoutAddDish => 'Add Dish';

  @override
  String layoutDishesInCategory(String category, String count) {
    return 'DISHES IN $category ($count ACTIVE)';
  }

  @override
  String layoutDropDishHint(String category) {
    return 'Drop dish here to reorder or reassign to $category';
  }

  @override
  String get layoutDeleteCategoryTitle => 'Delete Category?';

  @override
  String get layoutDeleteCategoryMessage =>
      'Do you want to delete this category? This action cannot be undone and will permanently remove it and its associated items from the menu system.';

  @override
  String get layoutDeleteCategoryConfirm => 'Delete Category';

  @override
  String get layoutHeroCard => 'HERO CARD';

  @override
  String get layoutActive => 'Active';

  @override
  String get layoutHero => 'Hero';

  @override
  String get layoutList => 'List';

  @override
  String get layoutDeleteDishTitle => 'Delete dish?';

  @override
  String layoutDeleteDishMessage(String name) {
    return 'Remove $name from the digital menu?';
  }

  @override
  String get layoutAddNewDish => 'Add New Dish';

  @override
  String get layoutAddDishSubtitle =>
      'Enter dish details to add to digital menu catalog.';

  @override
  String get layoutDishNameLabel => 'DISH NAME (ITALIAN / ENGLISH) *';

  @override
  String get layoutDishNameHint => 'e.g., Pappardelle ai Funghi Porcini';

  @override
  String get layoutPriceLabel => 'PRICE (€ EUR) *';

  @override
  String get layoutDishPictureLabel => 'DISH PICTURE';

  @override
  String get layoutImageTooLarge => 'Image must be 10MB or smaller.';

  @override
  String get layoutUploadPrompt => 'Click or drag image to upload';

  @override
  String get layoutUploadHint => 'Optional · JPG, PNG up to 10MB';

  @override
  String get layoutEnterDishName => 'Enter a dish name.';

  @override
  String get layoutSaveAndAddDish => 'Save & Add Dish';

  @override
  String get layoutSaveDish => 'Save Dish';

  @override
  String layoutSaveDishError(String error) {
    return 'Could not save dish: $error';
  }

  @override
  String get catalogNewDiscount => 'New Discount';

  @override
  String catalogAllCategoriesCount(String count) {
    return 'All Categories ($count)';
  }

  @override
  String get catalogSearchDishesHint => 'Search dishes...';

  @override
  String get catalogNoDishesHint =>
      'No dishes yet. Add dishes from Menu Layout, then apply discounts here.';

  @override
  String get catalogApplyDiscountPromo => 'Apply Discount Promo';

  @override
  String get catalogTargetCategory => 'TARGET CATEGORY';

  @override
  String get catalogAllCategories => 'All Categories';

  @override
  String get catalogDiscountRate => 'DISCOUNT RATE (%)';

  @override
  String get catalogPromoLabel => 'PROMO LABEL / DESCRIPTION (OPTIONAL)';

  @override
  String get catalogPromoLabelHint => 'e.g. Happy Hour Special';

  @override
  String get catalogActivateImmediately => 'Activate Immediately';

  @override
  String get catalogActivateImmediatelyDesc =>
      'Sync instantly to active tables and digital order catalog';

  @override
  String get catalogApplyDiscount => 'Apply Discount';

  @override
  String catalogPercentOff(String percent) {
    return '$percent% Off';
  }

  @override
  String get catalogNoPromo => 'No Promo';

  @override
  String get catalogDiscount => 'Discount';

  @override
  String get catalogApply => 'Apply';

  @override
  String get catalogCompanyInfo => 'Company / Cafe Info';

  @override
  String get catalogCafeName => 'Cafe name';

  @override
  String get catalogPublicMenuUrl => 'Public menu URL';

  @override
  String get catalogPublicMenuUrlHint => 'https://your-cafe.vercel.app';

  @override
  String get catalogChooseLogo => 'Choose logo';

  @override
  String get catalogRemoveLogo => 'Remove logo';

  @override
  String get catalogSaveCompany => 'Save cafe info';

  @override
  String get catalogAppearance => 'Appearance / Theme Colors';

  @override
  String get catalogHeaderColor => 'Header color';

  @override
  String get catalogSidebarColor => 'Sidebar color';

  @override
  String get catalogBackgroundColor => 'Background color';

  @override
  String get catalogButtonColor => 'Button color';

  @override
  String get catalogSaveColors => 'Save colors';

  @override
  String get catalogResetColors => 'Reset to default';

  @override
  String get catalogSystemLanguage => 'System Language';

  @override
  String get catalogSystemLanguageDesc =>
      'Choose the default language for the admin portal and customer digital menus.';

  @override
  String get catalogEnglishUs => 'English (US)';

  @override
  String get catalogLangDefault => 'Default';

  @override
  String get catalogLangRegional => 'Regional';

  @override
  String get catalogApplyLanguageToQr =>
      'Apply language to customer QR menus automatically';

  @override
  String get catalogSaveLanguage => 'Save Language';

  @override
  String get catalogChangePassword => 'Change Password';

  @override
  String get catalogCurrentPassword => 'Current Password';

  @override
  String get catalogNewPassword => 'New Password';

  @override
  String get catalogPasswordUpdated => 'Password updated.';

  @override
  String get catalogUpdatePassword => 'Update Password';

  @override
  String get catalogCashierStaffAccess => 'Cashier & Staff Access';

  @override
  String get catalogCashierNameHint => 'e.g. Luca Neri';

  @override
  String get catalogCashierName => 'Cashier name';

  @override
  String get catalogCashierPinLabel => '4-digit secret passcode';

  @override
  String get catalogSaveCashier => 'Save Cashier';

  @override
  String get cashierLanguage => 'Language';

  @override
  String get cashierPosTerminal => 'POS TERMINAL 01';

  @override
  String get cashierSoloShiftLive => 'Solo Shift Live';

  @override
  String get cashierAllInOne => 'ALL-IN-ONE';

  @override
  String get cashierRole => 'Cashier';

  @override
  String get cashierSoloCashier => 'Solo Cashier';

  @override
  String get cashierStationFrontCounter => 'Station 1: Front Counter';

  @override
  String get cashierAudioOn => 'Audio On';

  @override
  String get cashierAssistanceCalls => 'Assistance Calls';

  @override
  String cashierCallsCount(String count) {
    return '$count Calls';
  }

  @override
  String get cashierNeedsAttend => 'Needs Attend';

  @override
  String get cashierIncomingOrders => 'Incoming Orders';

  @override
  String cashierOrdersCount(String count) {
    return '$count Orders';
  }

  @override
  String get cashierNeedsAccept => 'Needs Accept';

  @override
  String get cashierBillOutRequests => 'Bill Out Requests';

  @override
  String cashierCheckoutsCount(String count) {
    return '$count Checkouts';
  }

  @override
  String get cashierDueNow => 'Due now';

  @override
  String cashierFilterAllAlerts(String count) {
    return 'All Alerts ($count)';
  }

  @override
  String cashierFilterCallStaff(String count) {
    return 'Call Staff ($count)';
  }

  @override
  String cashierFilterNewOrders(String count) {
    return 'New Orders ($count)';
  }

  @override
  String cashierFilterBillRequests(String count) {
    return 'Bill Requests ($count)';
  }

  @override
  String get cashierInstantAlerts => 'Instant Alerts';

  @override
  String get cashierBillRequest => 'Bill Request';

  @override
  String cashierItemsCount(String count) {
    return '$count items';
  }

  @override
  String get cashierSettleBill => 'Settle Bill';

  @override
  String get cashierCallStaff => 'Call Staff';

  @override
  String get cashierAssistanceRequested => 'Assistance requested';

  @override
  String get cashierAttended => 'Attended';

  @override
  String get cashierNewOrder => 'New Order';

  @override
  String get cashierAcceptOrder => 'Accept Order';

  @override
  String cashierQuickTableStatus(String count) {
    return 'Quick Table Status ($count)';
  }

  @override
  String cashierTableShort(String number) {
    return 'T-$number';
  }

  @override
  String get cashierFree => 'Free';

  @override
  String cashierTableNumber(String number) {
    return 'Table $number';
  }

  @override
  String cashierOrderNumber(String id) {
    return 'Order #$id';
  }

  @override
  String cashierActiveBillOutRequest(String number) {
    return 'Active Bill Out Request  •  Table $number';
  }

  @override
  String get cashierItemsToSettle => 'Items to Settle';

  @override
  String orderRound(int round) {
    return 'Round $round';
  }

  @override
  String get cashierTotalToCharge => 'Total to Charge';

  @override
  String cashierSettleCloseBill(String amount) {
    return 'Settle & Close Bill ($amount)';
  }

  @override
  String get cashierCashPayment => 'Cash Payment';

  @override
  String get cashierTotalDue => 'Total Due';

  @override
  String get cashierCashReceived => 'Cash Received';

  @override
  String get cashierChangeDue => 'Change Due';

  @override
  String get cashierConfirmCash => 'Confirm Cash';

  @override
  String get cashierOrderItems => 'Order items';

  @override
  String get cashierAmount => 'Amount';

  @override
  String get cashierSubtotal => 'Subtotal';

  @override
  String get cashierIncludesSurcharge => 'Includes service charge';

  @override
  String get cashierApplyServiceCharge => 'Apply service charge';

  @override
  String get cashierReadyToServe => 'Ready to Serve';

  @override
  String get cashierMarkServed => 'Mark served';

  @override
  String get cashierWaitingForBill => 'Waiting for Bill';

  @override
  String get cashierPrintReceipt => 'Print Receipt';

  @override
  String get cashierSplitBill => 'Split Bill';

  @override
  String get cashierPrintChit => 'Print Chit';

  @override
  String get cashierSettled => 'Settled';

  @override
  String cashierActiveTables(String active, String total) {
    return '$active / $total Active';
  }

  @override
  String cashierServiceCharge(String percent) {
    return 'Service charge ($percent)';
  }

  @override
  String get cashierBillRequestedBadge => 'BILL REQUESTED';

  @override
  String get cashierDineIn => 'Dine-in';

  @override
  String cashierElapsedMinutes(String minutes) {
    return '${minutes}m';
  }

  @override
  String cashierOrderItemsCount(String count) {
    return 'Order items ($count)';
  }

  @override
  String get cashierTotalPayable => 'Total Payable';

  @override
  String get cashierActionUnavailable =>
      'This action is not available on this register.';

  @override
  String get cashierColStatus => 'Status';

  @override
  String get cashierColActions => 'Quick Actions';

  @override
  String cashierAvgTicket(String amount) {
    return 'Avg ticket $amount';
  }

  @override
  String get cashierCall => 'Call';

  @override
  String get cashierFloorManagement => 'FLOOR MANAGEMENT';

  @override
  String get cashierFloorOverviewTitle => 'Floor Overview & Tables';

  @override
  String cashierTablesCount(String count) {
    return '$count TABLES';
  }

  @override
  String cashierFloorAll(String count) {
    return 'All ($count)';
  }

  @override
  String cashierFloorOccupied(String count) {
    return 'Occupied ($count)';
  }

  @override
  String cashierFloorBillDue(String count) {
    return 'Bill Due ($count)';
  }

  @override
  String cashierFloorAvailable(String count) {
    return 'Available ($count)';
  }

  @override
  String get cashierStatusCleanReady => 'Clean & Ready';

  @override
  String get cashierStatusBillRequested => 'Bill Requested';

  @override
  String get cashierStatusStaffCall => 'Staff Call';

  @override
  String get cashierStatusDining => 'Dining';

  @override
  String get cashierAvailable => 'Available';

  @override
  String get cashierDiningActive => 'Dining active';

  @override
  String get cashierBillPending => 'Bill pending';

  @override
  String get cashierSoloStationSync => 'SOLO STATION  •  Live Register Sync';

  @override
  String get cashierShiftSalesTitle => 'Shift Sales & Register Logs';

  @override
  String get cashierExportSummary => 'Export Summary (PDF/CSV)';

  @override
  String get cashierTotalShiftGrossSales => 'Total Shift Gross Sales';

  @override
  String get cashierSettledOrders => 'Settled Orders';

  @override
  String get cashierActivePendingBalance => 'Active Pending Balance';

  @override
  String get cashierColOrderTable => 'Order & Table';

  @override
  String get cashierColTime => 'Time';

  @override
  String get cashierColAmount => 'Amount';

  @override
  String get cashierTillBalance => 'Till Balance & Drawer #01';

  @override
  String get cashierActive => 'ACTIVE';

  @override
  String get cashierOpeningFloat => 'Opening Float';

  @override
  String get cashierOpeningFloatRow => 'Opening Float:';

  @override
  String get cashierCashCollected => 'Cash Collected:';

  @override
  String get cashierCardDigitalPayments => 'Card / Digital Payments:';

  @override
  String get cashierExpectedInDrawer => 'Expected in Drawer:';

  @override
  String get cashierToleranceNote =>
      'Counting discrepancy tolerance is ±€2.00. Please ensure all dining table chits are settled before closing register.';

  @override
  String get cashierActualCashCounted => 'Actual Cash Counted';

  @override
  String get cashierCloseRegister => 'Close Register / End Shift';

  @override
  String cashierDifference(String amount) {
    return 'Difference: $amount';
  }

  @override
  String get cashierMidShiftChit => 'Mid-Shift Cash Count Chit';

  @override
  String get guestNavMenu => 'Menu';

  @override
  String get guestTableBill => 'Table Bill';

  @override
  String get guestRequestSent => 'Request sent';

  @override
  String get guestCallStaff => 'Call Staff';

  @override
  String guestTableNumber(String number) {
    return 'Table $number';
  }

  @override
  String get guestDineInOrder => 'Dine-in Order';

  @override
  String get guestMenuTitle => 'Mezzogiorno Menu';

  @override
  String get guestChefsSpecials => 'Chef\'s Specials';

  @override
  String get guestCategoryAll => 'All';

  @override
  String get guestSpotlight => 'Spotlight';

  @override
  String guestItemCount(String count) {
    return '$count items';
  }

  @override
  String guestCartItemCount(String count) {
    return '$count items • Cart';
  }

  @override
  String get guestViewOrder => 'View Order';

  @override
  String get guestOrderButton => 'Order';

  @override
  String get guestConfirmOrderTitle => 'Verify Your Order';

  @override
  String guestItemsInOrder(String count) {
    return 'Items in order ($count)';
  }

  @override
  String get guestConfirmSendKitchen => 'Confirm & Send to Kitchen';

  @override
  String get guestModifyOrder => 'Modify Order & Back to Menu';

  @override
  String guestBilledToTable(String table) {
    return 'Billed to table $table';
  }

  @override
  String get guestCloseReview => 'Close review';

  @override
  String get guestSendingOrder => 'Sending…';

  @override
  String guestTableDineIn(String number) {
    return 'Table $number • Dine-in';
  }

  @override
  String get guestChefsPick => 'CHEF\'S PICK';

  @override
  String get guestQuantity => 'QUANTITY';

  @override
  String get guestPortionServing => 'Portion serving';

  @override
  String guestAddToOrder(String amount) {
    return 'Add to Order • $amount';
  }

  @override
  String get guestLiveTab => 'Live Tab';

  @override
  String guestOrderNumber(String id) {
    return 'Order #$id';
  }

  @override
  String guestSentToKitchenAt(String time) {
    return 'Sent to the hearth at $time';
  }

  @override
  String get guestKitchenPreparing =>
      'Kitchen is preparing your order\nEstimated delivery in 10–15 mins';

  @override
  String get guestNewAdditions => 'New Additions';

  @override
  String get guestTicketSummary => 'Ticket Summary';

  @override
  String get guestKitchenTicketTotal => 'Kitchen Ticket Total';

  @override
  String get guestCallServer => 'Call Server';

  @override
  String get guestRequestBill => 'Request Bill';

  @override
  String guestPlaceOrder(String amount) {
    return 'Place Order • $amount';
  }

  @override
  String get guestOrdersSentInstantly =>
      'Orders are sent instantly to the kitchen';

  @override
  String get guestStatusReceived => 'Received';

  @override
  String get guestStatusPreparing => 'Preparing';

  @override
  String get guestStatusReady => 'Ready';

  @override
  String get guestStatusServed => 'Served';

  @override
  String get guestFinalTab => 'Final Tab';

  @override
  String get guestOrderSummary => 'Order Summary';

  @override
  String guestRefNumber(String id) {
    return 'Ref #$id';
  }

  @override
  String get guestPaid => 'PAID';

  @override
  String get guestPaymentSuccessful => 'Payment Successful';

  @override
  String get guestThankYou => 'Thank you for dining with Cafe Italiano!';

  @override
  String get guestSubtotal => 'Subtotal';

  @override
  String guestServiceCharge(String percent) {
    return 'Service Charge ($percent%)';
  }

  @override
  String get guestVatIncluded => 'Hospitality & VAT (Included)';

  @override
  String get guestTotalDue => 'Total Due';

  @override
  String get guestWannaCheckIn => 'Wanna Check In';
}
