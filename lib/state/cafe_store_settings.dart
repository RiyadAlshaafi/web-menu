part of 'cafe_store.dart';

extension CafeStoreSettings on CafeStore {
  String get cafeName {
    final name = (cafe['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? 'Tawla' : name;
  }

  String get logoUrl => (cafe['logoUrl'] as String?)?.trim() ?? '';

  /// The web address this cafe's guests open, saved with the cafe.
  String get publicMenuUrl => (cafe['publicMenuUrl'] as String?)?.trim() ?? '';

  /// Address printed in table QR codes: the cafe's own menu address first,
  /// then the PUBLIC_MENU_URL build setting, then the address the admin is
  /// using unless that is a local test address (a QR pointing at localhost
  /// works on no guest's phone). Empty when none is known, so no QR is made.
  String guestLink(String slug) {
    var base = publicMenuUrl;
    if (base.isEmpty) base = const String.fromEnvironment('PUBLIC_MENU_URL').trim();
    if (base.isEmpty && kIsWeb) {
      final host = Uri.base.host;
      final local = host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '::1';
      final origin = Uri.base.origin;
      if (!local && origin.startsWith('http')) base = origin;
    }
    base = base.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.endsWith('/rest/v1')) base = base.substring(0, base.length - 7).replaceFirst(RegExp(r'/+$'), '');
    if (!base.startsWith('http')) return '';
    return '$base/#/t/$slug';
  }

  Future<void> saveCompany({
    required String name,
    String? publicMenuUrl,
    String? logoDataUrl,
    bool removeLogo = false,
  }) async {
    var logo = logoUrl;
    if (removeLogo) {
      logo = '';
    } else if (logoDataUrl != null && logoDataUrl.startsWith('data:')) {
      logo = await db.storeLogo(logoDataUrl);
    }
    cafe = {
      ...cafe,
      'name': name.trim(),
      'logoUrl': logo,
      if (publicMenuUrl != null) 'publicMenuUrl': publicMenuUrl.trim(),
    };
    await db.writeCafe(cafe);
    notifyListeners();
  }

  Future<void> saveAppearance({required Color header, required Color sidebar, required Color background, required Color button}) async {
    cafe = {
      ...cafe,
      'headerColor': CafeColors.toHex(header),
      'sidebarColor': CafeColors.toHex(sidebar),
      'backgroundColor': CafeColors.toHex(background),
      'buttonColor': CafeColors.toHex(button),
    };
    await db.writeCafe(cafe);
    notifyListeners();
  }

  Future<void> resetAppearance() => saveAppearance(
        header: CafeColors.defaultHeader,
        sidebar: CafeColors.defaultSidebar,
        background: CafeColors.defaultBackground,
        button: CafeColors.defaultButton,
      );
  double get serviceChargeRate => (cafe['serviceChargeRate'] as num?)?.toDouble() ?? 0;
  bool get autoPrintReceipt => cafe['autoPrintReceipt'] as bool? ?? true;

  Future<void> setAutoPrintReceipt(bool value) async {
    cafe = {...cafe, 'autoPrintReceipt': value};
    notifyListeners();
    await db.writeAutoPrintReceipt(value);
  }
  /// Guests can only order while a cashier device is online (off until the admin turns it on).
  bool get requireCashierOnline => cafe['requireCashierOnline'] as bool? ?? false;

  Future<void> setRequireCashierOnline(bool value) async {
    cafe = {...cafe, 'requireCashierOnline': value};
    notifyListeners();
    await db.writeRequireCashierOnline(value);
  }

  double get taxRate => (cafe['taxRate'] as num?)?.toDouble() ?? 0;
  Future<void> setLocale(String value) async {
    locale = value;
    await db.writeLocale(value);
    notifyListeners();
  }
}
