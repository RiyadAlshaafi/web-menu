import 'dart:convert';

/// How a till is installed. Picked first in the Windows setup.
enum InstallMode {
  /// Every feature can be ticked: QR ordering, live screens, admin tools.
  online('online'),

  /// Till only: just the features that keep working with no internet.
  /// The cafe still needs internet once to link the device and set up the menu.
  offline('offline');

  const InstallMode(this.key);

  final String key;

  static InstallMode fromKey(String? key) => key == offline.key ? offline : online;
}

/// Optional parts of the app, ticked per install in the Windows setup.
///
/// Core screens (login, menu, quick takeout, payment, receipts, cashier log,
/// shifts, settings) are always on and are not listed here. [key] is the name written
/// to `features.json` by the installer, so never rename one.
enum AppFeature {
  tables('tables'),
  qrOrdering('qr_ordering'),
  locationCheck('location_check'),
  discounts('discounts'),
  dishToggle('dish_toggle'),
  /// Expense entry, expense categories and the expenses ledger ("Wages" screen).
  expenses('expenses', worksOffline: true),
  reports('reports'),
  /// Custom app colours (the logo stays with the cafe name, which is core).
  branding('branding'),
  paymentTypes('payment_types', worksOffline: true);

  const AppFeature(this.key, {this.worksOffline = false});

  final String key;

  /// Whether the till can use this with no internet (it is saved and uploaded later).
  final bool worksOffline;

  /// The feature this one cannot work without, if any.
  AppFeature? get requires => switch (this) {
        qrOrdering => tables,
        locationCheck => qrOrdering,
        _ => null,
      };

  /// Features the setup lists for [mode].
  static List<AppFeature> offeredIn(InstallMode mode) =>
      mode == InstallMode.offline ? values.where((f) => f.worksOffline).toList() : values;

  static AppFeature? fromKey(String key) {
    for (final feature in values) {
      if (feature.key == key) return feature;
    }
    return null;
  }
}

/// The features one install may show. Immutable.
class FeatureSet {
  const FeatureSet._(this.mode, this._enabled);

  /// Online with every feature on. Used on the web and when no installer file exists.
  static final FeatureSet all = FeatureSet._(InstallMode.online, Set.unmodifiable(AppFeature.values));

  /// Listed keys are on; unknown keys are ignored.
  factory FeatureSet.fromKeys(Iterable<String> keys, {InstallMode mode = InstallMode.online}) {
    final enabled = keys.map(AppFeature.fromKey).whereType<AppFeature>().toSet();
    return FeatureSet._(mode, Set.unmodifiable(enabled));
  }

  /// Reads the installer's `features.json` (`{"mode": "online", "features": [...]}`).
  /// A missing or broken file means every feature is on, so a bad write never
  /// takes features away from a cafe.
  factory FeatureSet.fromJson(String? json) {
    if (json == null) return all;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map || decoded['features'] is! List) return all;
      final mode = InstallMode.fromKey(decoded['mode'] as String?);
      return FeatureSet.fromKeys((decoded['features'] as List).whereType<String>(), mode: mode);
    } on FormatException {
      return all;
    }
  }

  final InstallMode mode;
  final Set<AppFeature> _enabled;

  /// On only when the feature and everything it needs are on, and the mode offers it.
  bool allows(AppFeature feature) {
    if (!_enabled.contains(feature)) return false;
    if (mode == InstallMode.offline && !feature.worksOffline) return false;
    final needed = feature.requires;
    return needed == null || allows(needed);
  }

  /// Features both sets allow (installer choice ∩ what the cafe paid for).
  /// Offline wins when either set is offline.
  FeatureSet intersect(FeatureSet other) => FeatureSet._(
        mode == InstallMode.offline || other.mode == InstallMode.offline ? InstallMode.offline : InstallMode.online,
        Set.unmodifiable(_enabled.intersection(other._enabled)),
      );
}
