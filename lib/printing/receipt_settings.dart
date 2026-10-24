/// How the cafe's printouts look, the same on every till (saved with the cafe, as
/// restaurants.receipt_settings): cafe name and logo on or off, header and footer text, and
/// which lines show. Missing keys take the defaults below, which print as before this existed.
/// Paper width is not here: each till's printer has its own (TillPrinters).
class ReceiptSettings {
  const ReceiptSettings({
    this.showCafeName = true,
    this.showLogo = true,
    this.header = '',
    this.footer = '',
    this.showOrderNumber = true,
    this.showTable = true,
    this.showDate = true,
    this.showCashier = false,
    this.showChoices = true,
    this.showDiscount = true,
    this.showServiceCharge = true,
    this.showPaymentMethod = true,
  });

  /// Longest header or footer the editor accepts.
  static const maxTextLength = 200;

  final bool showCafeName;
  final bool showLogo;

  /// Extra lines under the cafe name, such as an address or phone number.
  final String header;

  /// The closing line; empty prints the usual thank-you.
  final String footer;
  final bool showOrderNumber;
  final bool showTable;
  final bool showDate;
  final bool showCashier;
  final bool showChoices;
  final bool showDiscount;
  final bool showServiceCharge;
  final bool showPaymentMethod;

  factory ReceiptSettings.fromJson(Object? raw) {
    final json = raw is Map ? raw : const {};
    bool flag(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;
    String text(String key) {
      final value = json[key];
      if (value is! String) return '';
      final trimmed = value.trim();
      return trimmed.length > maxTextLength ? trimmed.substring(0, maxTextLength) : trimmed;
    }

    const base = ReceiptSettings();
    return ReceiptSettings(
      showCafeName: flag('showCafeName', base.showCafeName),
      showLogo: flag('showLogo', base.showLogo),
      header: text('header'),
      footer: text('footer'),
      showOrderNumber: flag('showOrderNumber', base.showOrderNumber),
      showTable: flag('showTable', base.showTable),
      showDate: flag('showDate', base.showDate),
      showCashier: flag('showCashier', base.showCashier),
      showChoices: flag('showChoices', base.showChoices),
      showDiscount: flag('showDiscount', base.showDiscount),
      showServiceCharge: flag('showServiceCharge', base.showServiceCharge),
      showPaymentMethod: flag('showPaymentMethod', base.showPaymentMethod),
    );
  }

  Map<String, dynamic> toJson() => {
        'showCafeName': showCafeName,
        'showLogo': showLogo,
        'header': header,
        'footer': footer,
        'showOrderNumber': showOrderNumber,
        'showTable': showTable,
        'showDate': showDate,
        'showCashier': showCashier,
        'showChoices': showChoices,
        'showDiscount': showDiscount,
        'showServiceCharge': showServiceCharge,
        'showPaymentMethod': showPaymentMethod,
      };

  ReceiptSettings copyWith({
    bool? showCafeName,
    bool? showLogo,
    String? header,
    String? footer,
    bool? showOrderNumber,
    bool? showTable,
    bool? showDate,
    bool? showCashier,
    bool? showChoices,
    bool? showDiscount,
    bool? showServiceCharge,
    bool? showPaymentMethod,
  }) =>
      ReceiptSettings(
        showCafeName: showCafeName ?? this.showCafeName,
        showLogo: showLogo ?? this.showLogo,
        header: header ?? this.header,
        footer: footer ?? this.footer,
        showOrderNumber: showOrderNumber ?? this.showOrderNumber,
        showTable: showTable ?? this.showTable,
        showDate: showDate ?? this.showDate,
        showCashier: showCashier ?? this.showCashier,
        showChoices: showChoices ?? this.showChoices,
        showDiscount: showDiscount ?? this.showDiscount,
        showServiceCharge: showServiceCharge ?? this.showServiceCharge,
        showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      );

  @override
  bool operator ==(Object other) =>
      other is ReceiptSettings && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}
