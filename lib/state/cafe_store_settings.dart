part of 'cafe_store.dart';

/// The guest menu address used when a cafe has none of its own yet: the same one the web
/// build defaults to (tool/build_web.sh).
const defaultGuestMenuUrl = 'https://tawla.ly';

extension CafeStoreSettings on CafeStore {
  String get cafeName {
    final name = (cafe['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? 'Tawla' : name;
  }

  String get logoUrl => (cafe['logoUrl'] as String?)?.trim() ?? '';

  /// The web address this cafe's guests open, saved with the cafe. Only the developer sets it
  /// (dev screen); empty until then.
  String get publicMenuUrl => (cafe['publicMenuUrl'] as String?)?.trim() ?? '';

  /// Address table QR codes point to: the cafe's own menu address first, then the
  /// PUBLIC_MENU_URL build setting, then the address the admin is using unless that is a local
  /// test address (a QR pointing at localhost works on no guest's phone), then
  /// [defaultGuestMenuUrl], so a new cafe's QR codes work before the developer sets one.
  /// Empty only when the saved address is not a web address, so no QR is made.
  String get guestMenuBase {
    var base = publicMenuUrl;
    if (base.isEmpty) base = const String.fromEnvironment('PUBLIC_MENU_URL').trim();
    if (base.isEmpty && kIsWeb) {
      final host = Uri.base.host;
      final local = host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '::1';
      final origin = Uri.base.origin;
      if (!local && origin.startsWith('http')) base = origin;
    }
    if (base.isEmpty) base = defaultGuestMenuUrl;
    base = base.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.endsWith('/rest/v1')) base = base.substring(0, base.length - 7).replaceFirst(RegExp(r'/+$'), '');
    return base.startsWith('http') ? base : '';
  }

  /// The table's guest menu link, or empty when there is no address (see [guestMenuBase]).
  String guestLink(String slug) {
    final base = guestMenuBase;
    if (base.isEmpty) return '';
    // A plain path: the guest web app (guest-web/) serves /t/<slug>, and a hash never reaches it.
    return '$base/t/$slug';
  }

  /// The developer saved a new guest menu address for this cafe on the dev screen.
  void applyPublicMenuUrl(String url) {
    cafe = {...cafe, 'publicMenuUrl': url.trim()};
    db.rememberPublicMenuUrl(url.trim());
    notifyListeners();
  }

  Future<void> saveCompany({
    required String name,
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
  /// How the takeout counter shows the menu: 'cards' (category cards with pictures) or 'classic'
  /// (every dish with a category bar on top).
  bool get takeoutCards => (cafe['takeoutLayout'] as String?) != 'classic';

  Future<void> setTakeoutCards(bool value) async {
    final layout = value ? 'cards' : 'classic';
    cafe = {...cafe, 'takeoutLayout': layout};
    notifyListeners();
    await db.writeTakeoutLayout(layout);
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
