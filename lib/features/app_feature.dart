import 'dart:convert';

/// How a till is installed. Picked first in the Windows setup.
enum InstallMode {
  /// Every feature can be ticked: QR ordering, live screens, admin tools.
  online('online'),

  /// No internet at all: everything is kept in a local database on this PC. Only the
  /// features that need guests' phones to reach a server (QR ordering, location check) are left
  /// out; tables work as open tabs the cashier fills in.
  offline('offline');

  const InstallMode(this.key);

  final String key;

  static InstallMode fromKey(String? key) => key == offline.key ? offline : online;
}

/// Optional parts of the app, ticked per install in the Windows setup.
///
/// Core screens (login, menu, quick takeout, payment, receipts, cashier log,
/// shifts, settings) are always on and are not listed here. [standard] ones are always on too
/// but kept as keys so older `features.json` files still read. [key] is the name written
/// to `features.json` by the installer, so never rename one.
enum AppFeature {
  /// Tables & floor, and the live alerts screen. Offline the cashier enters each table's dishes
  /// (open tab, pay later).
  tables('tables', worksOffline: true),
  qrOrdering('qr_ordering'),
  locationCheck('location_check'),
  discounts('discounts', worksOffline: true),
  dishToggle('dish_toggle', worksOffline: true),
  /// Expense entry, expense categories and the expenses ledger ("Wages" screen).
  expenses('expenses', worksOffline: true, standard: true),
  reports('reports', worksOffline: true, standard: true),
  /// Custom app colours (the logo stays with the cafe name, which is core).
  branding('branding', worksOffline: true),
  paymentTypes('payment_types', worksOffline: true, standard: true),
  /// Counted dish stock: the admin's Stock page; at 0 a dish is sold out.
  stock('stock', worksOffline: true, addedLater: true),
  /// Kitchen tickets on this till's kitchen printer.
  kitchenPrinter('kitchen_printer', worksOffline: true, addedLater: true),
  /// Ingredient and topping choices on a dish: the admin's choices editor, and the cashier's hold
  /// on a dish (or tap on a ticket line) to change them. Off, dishes are sold as they come.
  dishChoices('dish_choices', worksOffline: true, addedLater: true),
  /// Waiter phones and tablets on the cafe Wi-Fi send table orders to this till, which shows them
  /// on the alerts screen to accept. Works offline too: the phones never need the internet.
  waiterPhones('waiter_phones', worksOffline: true, addedLater: true),
  /// Opens the till's cash drawer after each cash sale (the drawer switch in printer settings).
  cashDrawer('cash_drawer', worksOffline: true, addedLater: true),
  /// Move a table's tab to another table, or merge it into one that is eating.
  moveTables('move_tables', worksOffline: true, addedLater: true),
  /// A percent added to dine-in bills; the admin sets it and the cashier may leave it off a bill.
  serviceCharge('service_charge', worksOffline: true, addedLater: true),
  /// The language switch in Settings (English and Arabic). Off, the app stays in its language.
  languages('languages', worksOffline: true, addedLater: true),
  /// The choice between the two takeout screen designs in Settings.
  takeoutLayout('takeout_layout', worksOffline: true, addedLater: true),
  /// The choice of how guests see the menu after scanning a table's QR code.
  menuDesign('menu_design', addedLater: true),
  /// The receipts and printouts editor in Settings.
  receiptEditor('receipt_editor', worksOffline: true, addedLater: true);

  const AppFeature(this.key, {this.worksOffline = false, this.addedLater = false, this.standard = false});

  final String key;

  /// Always on in every install: the setup does not list it and an unticked one in an older
  /// `features.json` still counts as on.
  final bool standard;

  /// Whether this works in offline mode (local database, no internet).
  final bool worksOffline;

  /// Added after tills were already set up: a features.json written before it existed (no
  /// "listed" field) leaves it on, so an update never takes it away.
  final bool addedLater;

  /// The feature this one cannot work without, if any.
  AppFeature? get requires => switch (this) {
        qrOrdering => tables,
        waiterPhones => tables,
        moveTables => tables,
        serviceCharge => tables,
        locationCheck => qrOrdering,
        menuDesign => qrOrdering,
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
  const FeatureSet._(this.mode, this._enabled, [this.slot]);

  /// Highest cafe slot number (slots are 1-8).
  static const maxSlot = 8;

  /// Online with every feature on. Used on the web and when no installer file exists.
  static final FeatureSet all = FeatureSet._(InstallMode.online, Set.unmodifiable(AppFeature.values));

  /// Listed keys are on; unknown keys are ignored. [slot] counts only online and only 1-8.
  factory FeatureSet.fromKeys(Iterable<String> keys, {InstallMode mode = InstallMode.online, int? slot}) {
    final enabled = keys.map(AppFeature.fromKey).whereType<AppFeature>().toSet();
    final validSlot = mode == InstallMode.online && slot != null && slot >= 1 && slot <= maxSlot ? slot : null;
    return FeatureSet._(mode, Set.unmodifiable(enabled), validSlot);
  }

  /// Reads the installer's `features.json`
  /// (`{"mode": "online", "features": [...], "listed": [...], "slot": 3}`). "listed" names the
  /// boxes the setup showed; a file without it predates the [AppFeature.addedLater] features, which
  /// then stay on. A missing or broken file means every feature is on, so a bad write never
  /// takes features away from a cafe.
  factory FeatureSet.fromJson(String? json) {
    if (json == null) return all;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map || decoded['features'] is! List) return all;
      final mode = InstallMode.fromKey(decoded['mode'] as String?);
      final slot = decoded['slot'];
      final listed = decoded['listed'];
      return FeatureSet.fromKeys(
        [
          ...(decoded['features'] as List).whereType<String>(),
          // A box the till's setup never showed (not in "listed") was added later: it stays on.
          for (final feature in AppFeature.values)
            if (feature.addedLater && (listed is! List || !listed.contains(feature.key))) feature.key,
        ],
        mode: mode,
        slot: slot is int ? slot : null,
      );
    } on FormatException {
      return all;
    }
  }

  final InstallMode mode;
  final Set<AppFeature> _enabled;

  /// The cafe slot picked in an online setup; the till links to it at every start. Null when none.
  final int? slot;

  /// On only when the feature and everything it needs are on, and the mode offers it.
  bool allows(AppFeature feature) {
    if (!feature.standard && !_enabled.contains(feature)) return false;
    if (mode == InstallMode.offline && !feature.worksOffline) return false;
    final needed = feature.requires;
    return needed == null || allows(needed);
  }

  /// Features both sets allow (installer choice ∩ what the cafe paid for).
  /// Offline wins when either set is offline.
  FeatureSet intersect(FeatureSet other) => FeatureSet._(
        mode == InstallMode.offline || other.mode == InstallMode.offline ? InstallMode.offline : InstallMode.online,
        Set.unmodifiable(_enabled.intersection(other._enabled)),
        slot ?? other.slot,
      );
}
