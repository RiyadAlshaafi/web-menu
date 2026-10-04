// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get helloWorld => 'مرحباً بالعالم';

  @override
  String get welcomeMessage => 'مرحباً بك في كافيه إيطاليانو';

  @override
  String get noTables => 'لم يتم إنشاء طاولات بعد.';

  @override
  String get noOrders => 'لا توجد طلبات نشطة.';

  @override
  String get noCalls => 'لا توجد طلبات مساعدة.';

  @override
  String get noBills => 'لا توجد طلبات فاتورة.';

  @override
  String get noMenu => 'لا توجد عناصر في القائمة.';

  @override
  String get menuSoon => 'القائمة قريباً';

  @override
  String get noSales => 'لا توجد مبيعات بعد.';

  @override
  String get noCashiers => 'لم يتم إنشاء صناديق بعد.';

  @override
  String get noTransactions => 'لا توجد معاملات بعد.';

  @override
  String get insufficientCash => 'النقد غير كافٍ.';

  @override
  String get createCategoryFirst => 'أنشئ تصنيفاً أولاً.';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonDelete => 'حذف';

  @override
  String get navMenuCatalogLabel => 'كتالوج القائمة\nوالتخطيط';

  @override
  String get navMenuCatalog => 'كتالوج القائمة والتخطيط';

  @override
  String get navDiscounts => 'الخصومات';

  @override
  String get navTablesQr => 'الطاولات ورموز QR';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navSalesLog => 'سجل المبيعات';

  @override
  String get navDishAvailability => 'توفر الأطباق';

  @override
  String get dishSearchHint => 'ابحث عن طبق';

  @override
  String get dishFilterAll => 'الكل';

  @override
  String get dishFilterActive => 'نشط';

  @override
  String get dishFilterInactive => 'غير نشط';

  @override
  String get dishAllCategories => 'كل الفئات';

  @override
  String get dishInactive => 'غير نشط';

  @override
  String get dishActivateAll => 'تفعيل الكل';

  @override
  String get dishDeactivateAll => 'إيقاف الكل';

  @override
  String get dishBulkTitle => 'تحديث هذه الفئة؟';

  @override
  String dishBulkMessage(String category) {
    return 'سيغيّر هذا كل أطباق $category.';
  }

  @override
  String get salesSearchHint => 'ابحث بالطاولة أو الكاشير أو رقم العملية';

  @override
  String get salesDateFrom => 'من';

  @override
  String get salesDateTo => 'إلى';

  @override
  String get salesAllCashiers => 'كل الكاشيرية';

  @override
  String get salesAllTables => 'كل الطاولات';

  @override
  String get salesAllMethods => 'كل طرق الدفع';

  @override
  String get salesAllStatuses => 'كل الحالات';

  @override
  String get salesExportCsv => 'تصدير CSV';

  @override
  String get salesExportPdf => 'تصدير PDF';

  @override
  String get salesColId => 'رقم الإيصال';

  @override
  String get salesReceiptNo => 'رقم الإيصال';

  @override
  String get salesOrderNo => 'رقم الطلب';

  @override
  String salesReceiptLine(String number) {
    return 'رقم الإيصال $number';
  }

  @override
  String get salesColWhen => 'التاريخ والوقت';

  @override
  String get salesColTable => 'الطاولة';

  @override
  String get salesColCashier => 'الكاشير';

  @override
  String get salesColItems => 'الأصناف';

  @override
  String get salesColSubtotal => 'المجموع';

  @override
  String get salesColDiscount => 'الخصم';

  @override
  String get salesColTax => 'الضريبة';

  @override
  String get salesColTotal => 'الإجمالي';

  @override
  String get salesColMethod => 'الدفع';

  @override
  String get salesColStatus => 'الحالة';

  @override
  String get salesPaid => 'مدفوع';

  @override
  String get salesEmpty => 'لا توجد مبيعات مطابقة.';

  @override
  String get salesOwnOnly => 'تُعرض مبيعاتك فقط.';

  @override
  String salesPage(int page, int pages) {
    return 'صفحة $page من $pages';
  }

  @override
  String get navQuickTakeout => 'طلب سفري سريع';

  @override
  String get quickTakeoutSearch => 'ابحث عن طبق';

  @override
  String get quickTakeoutAll => 'الكل';

  @override
  String get quickTakeoutEmpty => 'اضغط طبقاً لبدء التذكرة.';

  @override
  String get quickTakeoutPay => 'تحصيل الدفع';

  @override
  String get quickTakeoutNeedTable =>
      'أضف طاولة باسم Takeout من الطاولات ورمز QR، ثم أعد المحاولة.';

  @override
  String get quickTakeoutPaid => 'تم دفع طلب السفري.';

  @override
  String get navLiveAlerts => 'التنبيهات والطابور المباشر';

  @override
  String get navFloorOverview => 'نظرة عامة على الصالة';

  @override
  String get navShiftSales => 'مبيعات وسجلات الوردية';

  @override
  String get errAdminExists => 'حساب المدير موجود بالفعل.';

  @override
  String get errInvalidEmail => 'أدخل بريداً إلكترونياً صالحاً.';

  @override
  String get errPasswordsMismatch => 'يجب أن تتطابق كلمتا المرور تماماً.';

  @override
  String get errWeakPassword =>
      'يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل وحرف كبير ورقم ورمز خاص.';

  @override
  String get errNoAdmin => 'لا يوجد حساب مدير بعد.';

  @override
  String get errBadCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errBadCode => 'الرمز غير صالح أو منتهي الصلاحية.';

  @override
  String get errVerifyCodeFirst => 'تحقق من رمز الأمان أولاً.';

  @override
  String get errSelectCashier => 'اختر ملف أمين الصندوق.';

  @override
  String get errEnterPin => 'أدخل رمز PIN المكوّن من 4 أرقام.';

  @override
  String errPinMismatch(String name) {
    return 'رمز PIN لا يطابق $name.';
  }

  @override
  String errPinLocked(String name, int minutes) {
    return 'محاولات PIN خاطئة كثيرة لـ $name. حاول مرة أخرى بعد $minutes دقيقة.';
  }

  @override
  String get errCashierSignInFirst => 'سجّل الدخول كأمين صندوق أولاً.';

  @override
  String get errNoOpenBill => 'لا توجد فاتورة مفتوحة لهذه الطاولة.';

  @override
  String get guestOrderFirst => 'اطلب أولاً.';

  @override
  String get guestBillAfterServed =>
      'يمكنك طلب الفاتورة بعد أن يعلّم النادل الطلب كمقدَّم.';

  @override
  String get errNoOpenShift => 'لا توجد وردية مفتوحة.';

  @override
  String get authGuestCashier => 'كاشير ضيف';

  @override
  String get authPosTerminalSubtitle => 'نقطة البيع\nالطرفية';

  @override
  String get authSwitchToAdminSignIn => 'التبديل إلى دخول المسؤول';

  @override
  String get authCashierSignInTitle => 'دخول الكاشير';

  @override
  String get authCashierSignInSubtitle =>
      'اختر ملف الكاشير وأدخل رمز PIN المكوّن من 4 أرقام';

  @override
  String get authAuthenticatingAs => 'جارٍ التحقق باسم ';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authPosFooter =>
      'نظام نقاط البيع Café Italiano  •  المحطة الطرفية 04  •  بوابة ضيافة آمنة';

  @override
  String get authPinClear => 'مسح';

  @override
  String get authStaffPos => 'نقطة بيع الموظفين  ←';

  @override
  String get authCreateAdminAccess => 'إنشاء حساب المسؤول';

  @override
  String get authAdminSignIn => 'دخول المسؤول';

  @override
  String get authManagerEmail => 'البريد الإلكتروني للمدير';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authForgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get authCreateStrongPassword => 'أنشئ كلمة مرور قوية';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authRepeatPassword => 'أعد إدخال كلمة المرور';

  @override
  String get authKeepSignedIn => 'إبقائي مسجلاً للدخول';

  @override
  String get authCreateAccessCta => 'إنشاء الحساب  ←';

  @override
  String get authSignInCta => 'تسجيل الدخول  ←';

  @override
  String get authHaveAccountSignIn => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get authForgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get authForgotPasswordSubtitle =>
      'أدخل رمز الأمان لتتمكن من تغيير كلمة المرور';

  @override
  String get authSafeCodeSent =>
      'تم إرسال رمز أمان إلى جهاز المدير المسجل أو بريده الإلكتروني.';

  @override
  String get authDidntReceive => 'لم يصلك الرمز؟  ';

  @override
  String authResendCodeIn(String time) {
    return 'إعادة إرسال رمز الأمان ($time)';
  }

  @override
  String get authResendCode => 'إعادة إرسال رمز الأمان';

  @override
  String get authVerifyCodeCta => 'تحقق من الرمز وتابع  ←';

  @override
  String get authBackToSignIn => '→  العودة إلى تسجيل الدخول';

  @override
  String get authForgotFooter => 'المحطة #POS-01   •   خزنة مشفرة 256 بت';

  @override
  String get authHospitalityCoreAdmin => 'منصة الضيافة • المسؤول';

  @override
  String get authSetNewPasswordTitle => 'تعيين كلمة مرور جديدة';

  @override
  String get authSetNewPasswordSubtitle =>
      'أدخل كلمة المرور الجديدة لاستعادة الوصول إلى حساب المسؤول ولوحة الإدارة.';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة';

  @override
  String get authConfirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get authPasswordsMustMatch => 'يجب أن تتطابق كلمتا المرور تماماً';

  @override
  String get authPasswordRequirements => 'متطلبات كلمة المرور';

  @override
  String get authReqMinLength => '8 أحرف أو أكثر';

  @override
  String get authReqNumber => 'رقم واحد على الأقل';

  @override
  String get authReqCapital => 'حرف كبير';

  @override
  String get authReqSymbol => 'رمز خاص';

  @override
  String get authUpdatePasswordCta => 'تحديث كلمة المرور والمتابعة  ←';

  @override
  String get authReturnToStaffSignIn => '→  العودة إلى دخول الموظفين';

  @override
  String get authChangePasswordFooter =>
      '© Café Italiano فلورنسا 1984   •   بوابة مصادقة الطرفية v4.9';

  @override
  String get adminConsoleLabel => 'لوحة الإدارة';

  @override
  String get adminManagementHeading => 'الإدارة';

  @override
  String get adminDefaultName => 'المدير';

  @override
  String get adminGeneralManager => 'المدير العام';

  @override
  String get adminWorkspace => 'مساحة العمل';

  @override
  String get adminTerminalBadge => '●  الجهاز رقم 01  ·  اتصال آمن';

  @override
  String get adminCustomerView => 'واجهة العميل';

  @override
  String get adminFloorOrderingHeading => 'الصالة والطلبات';

  @override
  String get adminTablesQrHub => 'مركز الطاولات ورموز QR';

  @override
  String get adminStations => 'المحطات';

  @override
  String get adminSessions => 'الجلسات';

  @override
  String get adminSearchTableHint => 'ابحث عن طاولة أو منطقة...';

  @override
  String get adminAddTableButton => '+ إضافة طاولة';

  @override
  String get adminRegenerateQr => 'إعادة إنشاء رمز QR';

  @override
  String get adminRegenerateAllQr => 'إعادة إنشاء كل رموز QR';

  @override
  String adminTableNumber(String number) {
    return 'طاولة $number';
  }

  @override
  String get adminTableAvailable => 'متاحة';

  @override
  String get adminTableOccupied => 'مشغولة';

  @override
  String get adminScanToOrderPay => 'امسح الرمز للطلب والدفع';

  @override
  String get adminNoAppInstall => 'لا حاجة لتثبيت أي تطبيق';

  @override
  String get adminPrintStandCard => 'طباعة بطاقة الطاولة (PDF)';

  @override
  String get adminAddTableTitle => 'إضافة طاولة';

  @override
  String get adminTableNumberLabel => 'رقم الطاولة / اسمها';

  @override
  String get adminCreate => 'إنشاء';

  @override
  String get adminDeleteTableTitle => 'حذف الطاولة؟';

  @override
  String get adminDeleteTableMessage =>
      'هل تريد حذف هذه الطاولة؟ لا يمكن التراجع عن هذا الإجراء، وستتم إزالتها نهائيًا من مخطط الصالة ونظام الطلبات.';

  @override
  String get adminDeleteTableConfirm => 'حذف الطاولة';

  @override
  String get layoutTitle => 'محرر تخطيط القائمة وطريقة العرض';

  @override
  String get layoutSavedSnack => 'تم حفظ تخطيط القائمة.';

  @override
  String get layoutSaveMenu => 'حفظ تخطيط القائمة';

  @override
  String get layoutSequencingHeading => 'ترتيب الفئات وشجرة الأطباق';

  @override
  String get layoutReorderHint => 'استخدم الأسهم لإعادة الترتيب';

  @override
  String get layoutClose => 'إغلاق';

  @override
  String get layoutNewCategory => 'فئة جديدة';

  @override
  String get layoutCategoryNameHint =>
      'أدخل اسم الفئة (مثل: المشروبات والنبيذ، الحلويات)';

  @override
  String get layoutCreateCategory => 'إنشاء فئة';

  @override
  String get layoutSpotlight => 'مميّزة';

  @override
  String get layoutOneDish => 'طبق واحد';

  @override
  String layoutDishCount(String count) {
    return '$count أطباق';
  }

  @override
  String layoutItemCount(String count) {
    return '$count عناصر';
  }

  @override
  String get layoutCurrentlyInspecting => 'قيد المعاينة حاليًا';

  @override
  String get layoutAddDish => 'إضافة طبق';

  @override
  String layoutDishesInCategory(String category, String count) {
    return 'الأطباق في $category ($count نشطة)';
  }

  @override
  String layoutDropDishHint(String category) {
    return 'أفلت الطبق هنا لإعادة ترتيبه أو نقله إلى $category';
  }

  @override
  String get layoutDeleteCategoryTitle => 'حذف الفئة؟';

  @override
  String get layoutDeleteCategoryMessage =>
      'هل تريد حذف هذه الفئة؟ لا يمكن التراجع عن هذا الإجراء، وسيتم حذفها نهائيًا مع جميع العناصر المرتبطة بها من نظام القائمة.';

  @override
  String get layoutDeleteCategoryConfirm => 'حذف الفئة';

  @override
  String get layoutHeroCard => 'بطاقة رئيسية';

  @override
  String get layoutActive => 'نشط';

  @override
  String get layoutHero => 'رئيسية';

  @override
  String get layoutList => 'قائمة';

  @override
  String get layoutDeleteDishTitle => 'حذف الطبق؟';

  @override
  String layoutDeleteDishMessage(String name) {
    return 'هل تريد إزالة $name من القائمة الرقمية؟';
  }

  @override
  String get layoutAddNewDish => 'إضافة طبق جديد';

  @override
  String get layoutAddDishSubtitle =>
      'أدخل تفاصيل الطبق لإضافته إلى كتالوج القائمة الرقمية.';

  @override
  String get layoutDishNameLabel => 'اسم الطبق (بالإيطالية / الإنجليزية) *';

  @override
  String get layoutDishNameHint => 'مثال: Pappardelle ai Funghi Porcini';

  @override
  String get layoutPriceLabel => 'السعر (€ يورو) *';

  @override
  String get layoutDishPictureLabel => 'صورة الطبق';

  @override
  String get layoutImageTooLarge => 'يجب ألا يتجاوز حجم الصورة 10 ميغابايت.';

  @override
  String get layoutUploadPrompt => 'انقر أو اسحب الصورة لرفعها';

  @override
  String get layoutUploadHint => 'اختياري · JPG أو PNG بحجم أقصى 10 ميغابايت';

  @override
  String get layoutEnterDishName => 'أدخل اسم الطبق.';

  @override
  String get layoutSaveAndAddDish => 'حفظ وإضافة الطبق';

  @override
  String get layoutSaveDish => 'حفظ الطبق';

  @override
  String layoutSaveDishError(String error) {
    return 'تعذّر حفظ الطبق: $error';
  }

  @override
  String get catalogNewDiscount => 'خصم جديد';

  @override
  String catalogAllCategoriesCount(String count) {
    return 'جميع الفئات ($count)';
  }

  @override
  String get catalogSearchDishesHint => 'ابحث عن الأطباق...';

  @override
  String get catalogNoDishesHint =>
      'لا توجد أطباق بعد. أضف الأطباق من تخطيط القائمة، ثم طبّق الخصومات هنا.';

  @override
  String get catalogApplyDiscountPromo => 'تطبيق عرض خصم';

  @override
  String get catalogTargetCategory => 'الفئة المستهدفة';

  @override
  String get catalogAllCategories => 'جميع الفئات';

  @override
  String get catalogDiscountRate => 'نسبة الخصم (%)';

  @override
  String get catalogPromoLabel => 'اسم العرض / الوصف (اختياري)';

  @override
  String get catalogPromoLabelHint => 'مثال: عرض ساعة السعادة';

  @override
  String get catalogActivateImmediately => 'التفعيل فورًا';

  @override
  String get catalogActivateImmediatelyDesc =>
      'مزامنة فورية مع الطاولات النشطة وقائمة الطلبات الرقمية';

  @override
  String get catalogApplyDiscount => 'تطبيق الخصم';

  @override
  String catalogPercentOff(String percent) {
    return 'خصم $percent%';
  }

  @override
  String get catalogNoPromo => 'لا يوجد عرض';

  @override
  String get catalogDiscount => 'الخصم';

  @override
  String get catalogApply => 'تطبيق';

  @override
  String get catalogCompanyInfo => 'معلومات المقهى';

  @override
  String get catalogCafeName => 'اسم المقهى';

  @override
  String get catalogPublicMenuUrl => 'رابط القائمة العام';

  @override
  String get catalogPublicMenuUrlHint => 'https://your-cafe.vercel.app';

  @override
  String get catalogChooseLogo => 'اختيار الشعار';

  @override
  String get catalogRemoveLogo => 'إزالة الشعار';

  @override
  String get catalogSaveCompany => 'حفظ معلومات المقهى';

  @override
  String get catalogAppearance => 'المظهر / ألوان السمة';

  @override
  String get catalogHeaderColor => 'لون الترويسة';

  @override
  String get catalogSidebarColor => 'لون الشريط الجانبي';

  @override
  String get catalogBackgroundColor => 'لون الخلفية';

  @override
  String get catalogButtonColor => 'لون الأزرار';

  @override
  String get catalogSaveColors => 'حفظ الألوان';

  @override
  String get catalogResetColors => 'إعادة الضبط';

  @override
  String get catalogSystemLanguage => 'لغة النظام';

  @override
  String get catalogSystemLanguageDesc =>
      'اختر اللغة الافتراضية لبوابة الإدارة وقوائم العملاء الرقمية.';

  @override
  String get catalogEnglishUs => 'English (US)';

  @override
  String get catalogLangDefault => 'افتراضية';

  @override
  String get catalogLangRegional => 'إقليمية';

  @override
  String get catalogApplyLanguageToQr =>
      'تطبيق اللغة تلقائيًا على قوائم QR للعملاء';

  @override
  String get catalogSaveLanguage => 'حفظ اللغة';

  @override
  String get catalogChangePassword => 'تغيير كلمة المرور';

  @override
  String get catalogCurrentPassword => 'كلمة المرور الحالية';

  @override
  String get catalogNewPassword => 'كلمة المرور الجديدة';

  @override
  String get catalogPasswordUpdated => 'تم تحديث كلمة المرور.';

  @override
  String get catalogUpdatePassword => 'تحديث كلمة المرور';

  @override
  String get catalogCashierStaffAccess => 'صلاحيات الكاشير والموظفين';

  @override
  String get catalogCashierNameHint => 'مثال: لوكا نيري';

  @override
  String get catalogCashierName => 'اسم الكاشير';

  @override
  String get catalogCashierPinLabel => 'رمز PIN سري من 4 أرقام';

  @override
  String get catalogSaveCashier => 'حفظ الكاشير';

  @override
  String get cashierLanguage => 'اللغة';

  @override
  String get cashierPosTerminal => 'جهاز POS رقم 01';

  @override
  String get cashierSoloShiftLive => 'وردية فردية مباشرة';

  @override
  String get cashierAllInOne => 'الكل في واحد';

  @override
  String get cashierRole => 'أمين الصندوق';

  @override
  String get cashierSoloCashier => 'أمين صندوق منفرد';

  @override
  String get cashierStationFrontCounter => 'المحطة 1: الكاونتر الأمامي';

  @override
  String get cashierAudioOn => 'الصوت مفعّل';

  @override
  String get cashierAssistanceCalls => 'طلبات المساعدة';

  @override
  String cashierCallsCount(String count) {
    return '$count طلبات';
  }

  @override
  String get cashierNeedsAttend => 'بحاجة إلى متابعة';

  @override
  String get cashierIncomingOrders => 'الطلبات الواردة';

  @override
  String cashierOrdersCount(String count) {
    return '$count طلبات';
  }

  @override
  String get cashierNeedsAccept => 'بانتظار القبول';

  @override
  String get cashierBillOutRequests => 'طلبات الفاتورة';

  @override
  String cashierCheckoutsCount(String count) {
    return '$count عمليات دفع';
  }

  @override
  String get cashierDueNow => 'مستحق الآن';

  @override
  String cashierFilterAllAlerts(String count) {
    return 'كل التنبيهات ($count)';
  }

  @override
  String cashierFilterCallStaff(String count) {
    return 'استدعاء الموظف ($count)';
  }

  @override
  String cashierFilterNewOrders(String count) {
    return 'طلبات جديدة ($count)';
  }

  @override
  String cashierFilterBillRequests(String count) {
    return 'طلبات الفاتورة ($count)';
  }

  @override
  String get cashierInstantAlerts => 'تنبيهات فورية';

  @override
  String get cashierBillRequest => 'طلب الفاتورة';

  @override
  String cashierItemsCount(String count) {
    return '$count أصناف';
  }

  @override
  String get cashierSettleBill => 'تسوية الفاتورة';

  @override
  String get cashierCallStaff => 'استدعاء الموظف';

  @override
  String get cashierAssistanceRequested => 'طُلبت المساعدة';

  @override
  String get cashierAttended => 'تمت المتابعة';

  @override
  String get cashierNewOrder => 'طلب جديد';

  @override
  String get cashierAcceptOrder => 'قبول الطلب';

  @override
  String cashierQuickTableStatus(String count) {
    return 'حالة الطاولات السريعة ($count)';
  }

  @override
  String cashierTableShort(String number) {
    return 'T-$number';
  }

  @override
  String get cashierFree => 'متاحة';

  @override
  String cashierTableNumber(String number) {
    return 'طاولة $number';
  }

  @override
  String cashierOrderNumber(String id) {
    return 'الطلب $id';
  }

  @override
  String cashierActiveBillOutRequest(String number) {
    return 'طلب فاتورة نشط  •  طاولة $number';
  }

  @override
  String get cashierItemsToSettle => 'الأصناف المطلوب تسويتها';

  @override
  String orderRound(int round) {
    return 'الجولة $round';
  }

  @override
  String get cashierTotalToCharge => 'المبلغ المطلوب تحصيله';

  @override
  String cashierSettleCloseBill(String amount) {
    return 'تسوية وإغلاق الفاتورة ($amount)';
  }

  @override
  String get cashierCashPayment => 'دفع نقدي';

  @override
  String get cashierTotalDue => 'الإجمالي المستحق';

  @override
  String get cashierCashReceived => 'المبلغ النقدي المستلم';

  @override
  String get cashierChangeDue => 'الباقي المستحق';

  @override
  String get cashierConfirmCash => 'تأكيد الدفع النقدي';

  @override
  String get cashierOrderItems => 'أصناف الطلب';

  @override
  String get cashierAmount => 'المبلغ';

  @override
  String get cashierSubtotal => 'المجموع الفرعي';

  @override
  String get cashierIncludesSurcharge => 'يشمل رسم الخدمة';

  @override
  String get cashierApplyServiceCharge => 'تطبيق رسم الخدمة';

  @override
  String get cashierReadyToServe => 'جاهز للتقديم';

  @override
  String get cashierMarkServed => 'تم التقديم';

  @override
  String get cashierWaitingForBill => 'بانتظار الفاتورة';

  @override
  String get cashierPrintReceipt => 'طباعة الإيصال';

  @override
  String get cashierSplitBill => 'تقسيم الفاتورة';

  @override
  String get cashierPrintChit => 'طباعة القسيمة';

  @override
  String get cashierSettled => 'مسوّاة';

  @override
  String cashierActiveTables(String active, String total) {
    return '$active / $total نشطة';
  }

  @override
  String cashierServiceCharge(String percent) {
    return 'رسم الخدمة ($percent)';
  }

  @override
  String get cashierBillRequestedBadge => 'طلب الفاتورة';

  @override
  String get cashierDineIn => 'تناول في المطعم';

  @override
  String cashierElapsedMinutes(String minutes) {
    return '$minutes د';
  }

  @override
  String cashierOrderItemsCount(String count) {
    return 'أصناف الطلب ($count)';
  }

  @override
  String get cashierTotalPayable => 'الإجمالي المستحق الدفع';

  @override
  String get cashierActionUnavailable => 'هذا الإجراء غير متاح في هذا الصندوق.';

  @override
  String get cashierRefuse => 'رفض';

  @override
  String get cashierItemRefused => 'تمت إزالة الصنف وتمييزه كغير متاح';

  @override
  String guestItemRemoved(String name) {
    return 'تمت إزالة الصنف: $name — غير متاح حالياً.';
  }

  @override
  String get guestConfirmRequestBill => 'تأكيد وطلب الفاتورة';

  @override
  String get cashierWaitingCustomerConfirm =>
      'بانتظار تأكيد الطاولة للطلب المحدّث.';

  @override
  String get cashierSettleAnyway => 'تسوية على أي حال';

  @override
  String get cashierSettleAnywayMessage =>
      'لم يؤكد الزبون الطلب المحدّث. هل تريد التسوية على أي حال؟';

  @override
  String get cashierNotAvailable => 'غير متاح';

  @override
  String get cashierMarkUnavailable => 'تمييز كغير متاح';

  @override
  String get cashierMarkAvailable => 'إتاحة الصنف';

  @override
  String get cashierColStatus => 'الحالة';

  @override
  String get cashierColActions => 'إجراءات سريعة';

  @override
  String cashierAvgTicket(String amount) {
    return 'متوسط التذكرة $amount';
  }

  @override
  String get cashierCall => 'نداء';

  @override
  String get cashierFloorManagement => 'إدارة الصالة';

  @override
  String get cashierFloorOverviewTitle => 'نظرة عامة على الصالة والطاولات';

  @override
  String cashierTablesCount(String count) {
    return '$count طاولات';
  }

  @override
  String cashierFloorAll(String count) {
    return 'الكل ($count)';
  }

  @override
  String cashierFloorOccupied(String count) {
    return 'مشغولة ($count)';
  }

  @override
  String cashierFloorBillDue(String count) {
    return 'فاتورة مستحقة ($count)';
  }

  @override
  String cashierFloorAvailable(String count) {
    return 'متاحة ($count)';
  }

  @override
  String get cashierStatusCleanReady => 'نظيفة وجاهزة';

  @override
  String get cashierStatusBillRequested => 'طُلبت الفاتورة';

  @override
  String get cashierStatusStaffCall => 'استدعاء موظف';

  @override
  String get cashierStatusDining => 'قيد تناول الطعام';

  @override
  String get cashierAvailable => 'متاحة';

  @override
  String get cashierDiningActive => 'جلسة طعام نشطة';

  @override
  String get cashierBillPending => 'الفاتورة معلّقة';

  @override
  String get cashierSoloStationSync => 'محطة فردية  •  مزامنة مباشرة للصندوق';

  @override
  String get cashierShiftSalesTitle => 'مبيعات الوردية وسجلات الصندوق';

  @override
  String get cashierExportSummary => 'تصدير الملخص (PDF/CSV)';

  @override
  String get cashierTotalShiftGrossSales => 'إجمالي مبيعات الوردية';

  @override
  String get cashierSettledOrders => 'الطلبات المسددة';

  @override
  String get cashierActivePendingBalance => 'الرصيد المعلّق الحالي';

  @override
  String get cashierColOrderTable => 'الإيصال والطاولة';

  @override
  String get cashierColTime => 'الوقت';

  @override
  String get cashierColAmount => 'المبلغ';

  @override
  String get cashierTillBalance => 'رصيد الصندوق والدرج رقم 01';

  @override
  String get cashierActive => 'نشط';

  @override
  String get cashierOpeningFloat => 'الرصيد الافتتاحي';

  @override
  String get cashierOpeningFloatRow => 'الرصيد الافتتاحي:';

  @override
  String get cashierCashCollected => 'النقد المحصّل:';

  @override
  String get cashierCardDigitalPayments => 'مدفوعات البطاقة / الرقمية:';

  @override
  String get cashierExpectedInDrawer => 'المتوقع في الدرج:';

  @override
  String get cashierToleranceNote =>
      'هامش التفاوت المسموح به في العدّ هو ±€2.00. يرجى التأكد من تسوية جميع فواتير الطاولات قبل إغلاق الصندوق.';

  @override
  String get cashierActualCashCounted => 'النقد الفعلي المعدود';

  @override
  String get cashierCloseRegister => 'إغلاق الصندوق / إنهاء الوردية';

  @override
  String cashierDifference(String amount) {
    return 'الفرق: $amount';
  }

  @override
  String get cashierMidShiftChit => 'إيصال عدّ النقد في منتصف الوردية';

  @override
  String get guestNavMenu => 'القائمة';

  @override
  String get guestTableBill => 'فاتورة الطاولة';

  @override
  String get guestRequestSent => 'تم إرسال طلبك';

  @override
  String get guestCallStaff => 'نداء الموظف';

  @override
  String guestTableNumber(String number) {
    return 'طاولة $number';
  }

  @override
  String get guestDineInOrder => 'طلب داخل المطعم';

  @override
  String get guestMenuTitle => 'قائمة الغداء';

  @override
  String get guestChefsSpecials => 'أطباق الشيف المميزة';

  @override
  String get guestCategoryAll => 'الكل';

  @override
  String get guestSpotlight => 'الأبرز';

  @override
  String guestItemCount(String count) {
    return '$count أصناف';
  }

  @override
  String guestCartItemCount(String count) {
    return '$count أصناف • السلة';
  }

  @override
  String get guestViewOrder => 'عرض الطلب';

  @override
  String get guestOrderButton => 'اطلب';

  @override
  String get guestConfirmOrderTitle => 'راجع طلبك';

  @override
  String guestItemsInOrder(String count) {
    return 'أصناف الطلب ($count)';
  }

  @override
  String get guestConfirmSendKitchen => 'تأكيد وإرسال للمطبخ';

  @override
  String get guestModifyOrder => 'تعديل الطلب والعودة للقائمة';

  @override
  String guestBilledToTable(String table) {
    return 'يُحسب على طاولة $table';
  }

  @override
  String get guestCloseReview => 'إغلاق المراجعة';

  @override
  String get guestSendingOrder => 'جارٍ الإرسال…';

  @override
  String guestTableDineIn(String number) {
    return 'طاولة $number • داخل المطعم';
  }

  @override
  String get guestChefsPick => 'اختيار الشيف';

  @override
  String get guestQuantity => 'الكمية';

  @override
  String get guestPortionServing => 'حصة واحدة';

  @override
  String guestAddToOrder(String amount) {
    return 'أضف إلى الطلب • $amount';
  }

  @override
  String get guestLiveTab => 'الحساب المفتوح';

  @override
  String guestOrderNumber(String id) {
    return 'طلب $id';
  }

  @override
  String guestSentToKitchenAt(String time) {
    return 'أُرسل إلى المطبخ الساعة $time';
  }

  @override
  String get guestKitchenPreparing =>
      'المطبخ يحضّر طلبك الآن\nالوقت المتوقع للتقديم ١٠–١٥ دقيقة';

  @override
  String get guestNewAdditions => 'إضافات جديدة';

  @override
  String get guestTicketSummary => 'ملخص الطلب';

  @override
  String get guestKitchenTicketTotal => 'إجمالي طلب المطبخ';

  @override
  String get guestCallServer => 'نداء النادل';

  @override
  String get guestRequestBill => 'طلب الفاتورة';

  @override
  String guestPlaceOrder(String amount) {
    return 'تأكيد الطلب • $amount';
  }

  @override
  String get guestOrdersSentInstantly => 'تُرسل الطلبات إلى المطبخ فورًا';

  @override
  String get guestStatusReceived => 'تم الاستلام';

  @override
  String get guestStatusPreparing => 'قيد التحضير';

  @override
  String get guestStatusReady => 'جاهز';

  @override
  String get guestStatusServed => 'تم التقديم';

  @override
  String get guestFinalTab => 'الحساب النهائي';

  @override
  String get guestOrderSummary => 'ملخص الطلب';

  @override
  String guestRefNumber(String id) {
    return 'مرجع رقم $id';
  }

  @override
  String get guestPaid => 'مدفوع';

  @override
  String get guestPaymentSuccessful => 'تم الدفع بنجاح';

  @override
  String get guestThankYou => 'شكرًا لتناولكم الطعام في Cafe Italiano!';

  @override
  String get guestSubtotal => 'المجموع الفرعي';

  @override
  String guestServiceCharge(String percent) {
    return 'رسوم الخدمة ($percent%)';
  }

  @override
  String get guestVatIncluded => 'الضيافة وضريبة القيمة المضافة (مشمولة)';

  @override
  String get guestTotalDue => 'الإجمالي المستحق';

  @override
  String get guestWannaCheckIn => 'أرغب في طلب الحساب';

  @override
  String get navCashierLog => 'سجل الكاشير والوردية';

  @override
  String get cashierLogScope => 'معاملاتك فقط. يمكن تصفيتها حسب الوردية.';

  @override
  String get salesAllShifts => 'كل الورديات';

  @override
  String get payTypesTitle => 'طرق الدفع';

  @override
  String get payTypesHint =>
      'يختار الزبون من الطرق المفعّلة. إيقاف طريقة لا يغيّر المبيعات السابقة.';

  @override
  String get payTypeNameEn => 'الاسم بالإنجليزية';

  @override
  String get payTypeNameAr => 'الاسم بالعربية';

  @override
  String get payTypeAdd => 'إضافة طريقة';

  @override
  String get payTypeInUse =>
      'هذه الطريقة مستخدمة في عملية بيع. أوقفها بدل حذفها.';

  @override
  String get payChoose => 'كيف ستدفع؟';

  @override
  String get cashierWaitingServed => 'بانتظار تعليم الطلب كمقدَّم';

  @override
  String get cashierSettleAnywayNotServed =>
      'لم يؤكد الزبون الطلب المعدّل، ولم يُعلَّم كمقدَّم. علّمه كمقدَّم قبل التسوية.';

  @override
  String payChanged(String oldName, String newName, String name, String time) {
    return 'تغيّرت طريقة الدفع من $oldName إلى $newName بواسطة $name في $time';
  }

  @override
  String get guestLoadingTable => 'جاري تحميل طاولتك...';

  @override
  String get guestQrInvalid => 'رمز QR هذا لا يطابق طاولة.';

  @override
  String get guestQrInvalidHint => 'اطلب من المقهى رمزاً جديداً.';

  @override
  String get guestRetry => 'حاول مرة أخرى';

  @override
  String get guestChooseService => 'كيف تريد الطلب؟';

  @override
  String get guestDineIn => 'تناول في المكان';

  @override
  String get guestDineInHint => 'نوصل الطلب إلى هذه الطاولة.';

  @override
  String get guestTakeout => 'سفري';

  @override
  String get guestTakeoutHint => 'تستلم الطلب بنفسك. الطاولة تبقى فارغة.';

  @override
  String get serviceTakeout => 'سفري';

  @override
  String payDeleteTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String get payDeleteMessage =>
      'المبيعات السابقة التي استخدمت هذه الطريقة ستبقى كما هي.';

  @override
  String get payTypeSave => 'حفظ';

  @override
  String get clearCashierLog => 'مسح سجل الكاشير';

  @override
  String get clearCashierLogConfirm =>
      'هذا يحذف مبيعاتك من سجل الكاشير ويعيد أرقام تذاكر اليوم حتى تختبر من جديد.';

  @override
  String get clearShiftSales => 'مسح مبيعات وسجلات الوردية';

  @override
  String get clearShiftSalesConfirm =>
      'هذا يمسح سجل الصندوق ويعيد مجاميع الوردية وأرقام تذاكر اليوم حتى تختبر من جديد.';

  @override
  String get clearLogsDone => 'تم المسح.';

  @override
  String get salesLoadMore => 'تحميل المزيد';

  @override
  String get cafeLocationTitle => 'موقع المقهى';

  @override
  String get cafeLocationRequire =>
      'اطلب من الضيوف أن يكونوا قرب المقهى ليتمكنوا من الطلب';

  @override
  String get cafeLocationUseCurrent => 'استخدم موقعي الحالي';

  @override
  String get cafeLocationLatitude => 'خط العرض';

  @override
  String get cafeLocationLongitude => 'خط الطول';

  @override
  String get cafeLocationRadius => 'النطاق (متر)';

  @override
  String get cafeLocationSave => 'حفظ الموقع';

  @override
  String get cafeLocationGpsNote =>
      'قد يخطئ GPS بمقدار 20 إلى 50 متراً داخل المباني.';

  @override
  String get cafeLocationNeedPoint =>
      'احفظ خط العرض وخط الطول قبل تفعيل هذا الخيار.';

  @override
  String get cafeLocationRadiusRange => 'النطاق يجب أن يكون بين 30 و 500 متر.';

  @override
  String get cafeLocationReadFailed => 'تعذر قراءة موقع هذا الجهاز.';

  @override
  String get cafeLocationSaveFailed => 'تعذر حفظ موقع المقهى.';

  @override
  String get cafeLocationSaved => 'تم حفظ موقع المقهى.';

  @override
  String get guestLocationTooFar =>
      'أنت بعيد عن المقهى ولا يمكن إرسال الطلب. يمكنك تصفح القائمة.';

  @override
  String get guestLocationDenied =>
      'الموقع مطلوب لإرسال الطلب. يمكنك تصفح القائمة.';

  @override
  String get guestLocationAllow => 'السماح بالموقع';

  @override
  String get guestLocationIosHint =>
      'على الآيفون، أعد تفعيل الموقع من إعدادات الموقع في المتصفح.';

  @override
  String get guestLocationUnavailable =>
      'تعذر قراءة موقعك. يمكنك تصفح القائمة.';

  @override
  String get guestLocationRetry => 'إعادة المحاولة';

  @override
  String get guestLocationChecking => 'جارٍ التحقق من موقعك…';

  @override
  String get cashierAddExpense => 'إضافة مصروف / صرف نقدي';

  @override
  String get cashierExpenseFor => 'دُفع إلى';

  @override
  String get cashierExpenseCafe => 'المقهى';

  @override
  String get cashierExpenseAmount => 'المبلغ';

  @override
  String get cashierExpenseDescription => 'الوصف';

  @override
  String get cashierExpenseAdd => 'إضافة';

  @override
  String get cashierExpenseInvalid =>
      'اختر من استلم المبلغ، وأدخل مبلغاً أكبر من صفر، واكتب وصف المصروف.';

  @override
  String get cashierExpenseSaved => 'تم تسجيل المصروف.';

  @override
  String get expenseType => 'النوع';

  @override
  String get expenseTypeCafe => 'مصروف المقهى';

  @override
  String get expenseTypeWithdrawal => 'سحب نقدي';

  @override
  String get expenseCategoriesTitle => 'فئات المصروفات';

  @override
  String get expenseCategoriesHint =>
      'يختار أمين الصندوق من الفئات المفعّلة عند تسجيل السحب. تبقى الأسماء ظاهرة على السجلات السابقة حتى بعد الحذف.';

  @override
  String get expenseCategoryDeleteMessage =>
      'ستبقى عمليات السحب السابقة التي استخدمت هذه الفئة تعرض اسمها.';

  @override
  String get expenseEdit => 'تعديل';

  @override
  String get expenseEdited => 'معدّل';

  @override
  String get expenseLogged => 'مسجّل';

  @override
  String get expenseOriginal => 'القيد الأصلي';

  @override
  String get expenseOriginalMissing => 'القيد الأصلي غير موجود على هذا الجهاز.';

  @override
  String get cashierExpenseNotEditable =>
      'يمكن تعديل المصروف من ورديتك المفتوحة فقط.';

  @override
  String get navWages => 'الأجور / المصروفات';

  @override
  String get navDashboard => 'لوحة المتابعة';

  @override
  String get summaryThisMonth => 'هذا الشهر';

  @override
  String get summarySelectedRange => 'النطاق المحدد';

  @override
  String get summaryToday => 'اليوم';

  @override
  String get summarySales => 'المبيعات';

  @override
  String get summaryExpenses => 'المصروفات';

  @override
  String get summaryNet => 'الصافي';

  @override
  String get dashboardRecentSales => 'آخر المبيعات';

  @override
  String get dashboardRecentExpenses => 'آخر المصروفات';

  @override
  String get dashboardViewAll => 'عرض الكل';

  @override
  String get expenseAllTypes => 'كل الأنواع';

  @override
  String get expenseColId => 'الرقم';

  @override
  String get expenseColWhen => 'التاريخ والوقت';

  @override
  String get expenseColCashier => 'الكاشير';

  @override
  String get expenseColType => 'النوع';

  @override
  String get expenseColDescription => 'الوصف';

  @override
  String get expenseColAmount => 'المبلغ';
}
