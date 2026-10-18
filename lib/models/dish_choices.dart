import 'dart:math';

/// One ingredient or extra topping an admin set on a dish.
///
/// Only an option that is off by default and turned on is charged; removing a
/// default ingredient is free. The dish discount never applies to options.
class DishOption {
  const DishOption({
    required this.id,
    required this.kind,
    required this.nameAr,
    required this.nameEn,
    this.price = 0,
    this.defaultOn = false,
  });

  static const ingredient = 'ingredient';
  static const topping = 'topping';

  final String id;

  /// [ingredient] or [topping]; only changes how the option is grouped.
  final String kind;
  final String nameAr;
  final String nameEn;
  final double price;
  final bool defaultOn;

  bool get isTopping => kind == topping;

  /// What turning this option on adds to one dish.
  double get chargedPrice => defaultOn ? 0 : price;

  String displayName(String locale) =>
      locale == 'en' || nameAr.isEmpty ? (nameEn.isEmpty ? nameAr : nameEn) : nameAr;

  DishOption copyWith({String? kind, String? nameAr, String? nameEn, double? price, bool? defaultOn}) => DishOption(
    id: id,
    kind: kind ?? this.kind,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    price: price ?? this.price,
    defaultOn: defaultOn ?? this.defaultOn,
  );

  factory DishOption.fromJson(Map<String, dynamic> json) => DishOption(
    id: json['id'] as String,
    kind: json['kind'] == topping ? topping : ingredient,
    nameAr: json['nameAr'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    defaultOn: json['defaultOn'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'price': price,
    'defaultOn': defaultOn,
  };

  String get syncKey => '$id:$kind:$nameAr:$nameEn:$price:$defaultOn';

  /// A random v4 UUID; the server and the guest web app expect option ids in that form.
  static String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static final _random = Random.secure();
}

/// A choice on one order line that differs from the dish defaults, frozen with
/// the names and the price charged when the line was made.
class LineChoice {
  const LineChoice({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.on,
    this.price = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// True when the guest added it, false when they removed a default ingredient.
  final bool on;

  /// Charged per dish; always 0 for a removal.
  final double price;

  String displayName(String locale) =>
      locale == 'en' || nameAr.isEmpty ? (nameEn.isEmpty ? nameAr : nameEn) : nameAr;

  factory LineChoice.fromJson(Map<String, dynamic> json) => LineChoice(
    id: json['id'] as String,
    nameAr: json['nameAr'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    on: json['on'] as bool? ?? false,
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {'id': id, 'nameAr': nameAr, 'nameEn': nameEn, 'on': on, 'price': price};
}

/// Parses a stored list of options or choices; anything malformed is dropped.
List<T> parseJsonList<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return const [];
  final result = <T>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    try {
      result.add(parse(Map<String, dynamic>.from(entry)));
    } on TypeError {
      continue;
    }
  }
  return List.unmodifiable(result);
}

/// The choices of one line that differ from [options]' defaults when [onIds] are on.
/// Ids the dish does not have are ignored.
List<LineChoice> choicesFor(List<DishOption> options, Set<String> onIds) => List.unmodifiable([
  for (final option in options)
    if (onIds.contains(option.id) != option.defaultOn)
      LineChoice(
        id: option.id,
        nameAr: option.nameAr,
        nameEn: option.nameEn,
        on: !option.defaultOn,
        price: option.defaultOn ? 0 : option.price,
      ),
]);

/// The option ids that are on for a line with [choices].
Set<String> onIdsFor(List<DishOption> options, List<LineChoice> choices) {
  final changed = {for (final choice in choices) choice.id: choice.on};
  return {
    for (final option in options)
      if (changed[option.id] ?? option.defaultOn) option.id,
  };
}

/// What [choices] add to one dish.
double choicesExtra(List<LineChoice> choices) =>
    choices.fold(0, (sum, choice) => choice.on ? sum + choice.price : sum);

/// Two lines of the same dish merge only when this matches.
String choiceKey(List<LineChoice> choices) {
  final parts = [for (final choice in choices) '${choice.on ? '+' : '-'}${choice.id}']..sort();
  return parts.join(',');
}
