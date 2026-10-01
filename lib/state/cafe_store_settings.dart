part of 'cafe_store.dart';

extension CafeStoreSettings on CafeStore {
  String get cafeName {
    final name = (cafe['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? 'Café Italiano' : name;
  }

  String get logoUrl => (cafe['logoUrl'] as String?)?.trim() ?? '';

  static const defaultMenuOrigin = 'https://web-menu-akakus.vercel.app';

  String guestLink(String slug) {
    var base = '';
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.startsWith('http')) base = origin;
    }
    if (base.isEmpty) base = const String.fromEnvironment('PUBLIC_MENU_URL', defaultValue: defaultMenuOrigin);
    base = base.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.endsWith('/rest/v1')) base = base.substring(0, base.length - 7).replaceFirst(RegExp(r'/+$'), '');
    if (!base.startsWith('http')) return '';
    return '$base/#/t/$slug';
  }

  Future<void> saveCompany({required String name, String? logoDataUrl, bool removeLogo = false}) async {
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
  String get databasePath => db.databasePath;
  bool get isSqlite => db.isSqlite;
  double get serviceChargeRate => (cafe['serviceChargeRate'] as num?)?.toDouble() ?? 0.10;
  double get taxRate => (cafe['taxRate'] as num?)?.toDouble() ?? 0;
  Future<void> setLocale(String value) async {
    locale = value;
    await db.writeLocale(value);
    notifyListeners();
  }
}
