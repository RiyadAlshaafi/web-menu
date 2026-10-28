import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/features/app_feature.dart';

void main() {
  test('every feature has a unique key', () {
    final keys = AppFeature.values.map((f) => f.key).toSet();
    expect(keys.length, AppFeature.values.length);
  });

  test('all allows every feature', () {
    for (final feature in AppFeature.values) {
      expect(FeatureSet.all.allows(feature), isTrue, reason: feature.key);
    }
  });

  test('fromKeys keeps listed features and drops the rest', () {
    final set = FeatureSet.fromKeys(['tables', 'expenses']);
    expect(set.allows(AppFeature.tables), isTrue);
    expect(set.allows(AppFeature.expenses), isTrue);
    expect(set.allows(AppFeature.discounts), isFalse);
  });

  test('fromKeys ignores unknown keys, including removed ones', () {
    final set = FeatureSet.fromKeys(['expenses', 'wages', 'shifts', 'not_a_feature']);
    expect(set.allows(AppFeature.expenses), isTrue);
    expect(AppFeature.fromKey('wages'), isNull);
    expect(AppFeature.fromKey('shifts'), isNull);
  });

  test('a feature is off when the feature it needs is off', () {
    final set = FeatureSet.fromKeys(['qr_ordering', 'location_check']);
    expect(set.allows(AppFeature.qrOrdering), isFalse);
    expect(set.allows(AppFeature.locationCheck), isFalse);
  });

  test('a feature chain is on when every link is on', () {
    final set = FeatureSet.fromKeys(['tables', 'qr_ordering', 'location_check']);
    expect(set.allows(AppFeature.locationCheck), isTrue);
  });

  test('fromJson reads the installer file', () {
    final set = FeatureSet.fromJson('{"features": ["reports", "expenses"]}');
    expect(set.mode, InstallMode.online);
    expect(set.allows(AppFeature.reports), isTrue);
    expect(set.allows(AppFeature.expenses), isTrue);
    expect(set.allows(AppFeature.tables), isFalse);
  });

  test('fromJson with an empty list allows only core', () {
    final set = FeatureSet.fromJson('{"features": [], "listed": ["tables", "stock", "kitchen_printer", "dish_choices"]}');
    for (final feature in AppFeature.values) {
      expect(set.allows(feature), isFalse, reason: feature.key);
    }
  });

  test('a file from before stock, kitchen printing and dish choices keeps all three on', () {
    final set = FeatureSet.fromJson('{"mode": "offline", "features": ["tables"]}');
    expect(set.allows(AppFeature.stock), isTrue);
    expect(set.allows(AppFeature.kitchenPrinter), isTrue);
    expect(set.allows(AppFeature.dishChoices), isTrue);
    expect(set.allows(AppFeature.waiterPhones), isTrue, reason: 'tills set up before 2.7.8 keep their waiter phones');
    expect(set.allows(AppFeature.discounts), isFalse);
  });

  test('a newer setup that showed stock and kitchen printing and left them unticked turns them off', () {
    final set = FeatureSet.fromJson('{"mode": "online", "features": ["tables"], "listed": ["tables", "stock", "kitchen_printer"]}');
    expect(set.allows(AppFeature.stock), isFalse);
    expect(set.allows(AppFeature.kitchenPrinter), isFalse);
    final ticked = FeatureSet.fromJson('{"mode": "offline", "features": ["stock", "kitchen_printer"], "listed": ["stock", "kitchen_printer"]}');
    expect(ticked.allows(AppFeature.stock), isTrue, reason: 'stock works offline');
    expect(ticked.allows(AppFeature.kitchenPrinter), isTrue, reason: 'kitchen printing works offline');
  });

  test('a setup that showed dish choices and left the box unticked turns them off; ticked keeps them', () {
    final off = FeatureSet.fromJson('{"mode": "online", "features": ["tables"], "listed": ["tables", "dish_choices"]}');
    expect(off.allows(AppFeature.dishChoices), isFalse);
    final on = FeatureSet.fromJson('{"mode": "offline", "features": ["dish_choices"], "listed": ["dish_choices"]}');
    expect(on.allows(AppFeature.dishChoices), isTrue, reason: 'dish choices work offline');
  });

  test('fromJson falls back to all when there is no file or it is broken', () {
    expect(FeatureSet.fromJson(null).allows(AppFeature.discounts), isTrue);
    expect(FeatureSet.fromJson('not json').allows(AppFeature.discounts), isTrue);
    expect(FeatureSet.fromJson('{"features": "tables"}').allows(AppFeature.discounts), isTrue);
  });

  test('offline mode offers only features that work without internet', () {
    final offered = AppFeature.offeredIn(InstallMode.offline);
    expect(offered, [
      AppFeature.tables,
      AppFeature.discounts,
      AppFeature.dishToggle,
      AppFeature.expenses,
      AppFeature.reports,
      AppFeature.branding,
      AppFeature.paymentTypes,
      AppFeature.stock,
      AppFeature.kitchenPrinter,
      AppFeature.dishChoices,
      AppFeature.waiterPhones,
    ]);
    expect(AppFeature.offeredIn(InstallMode.online), AppFeature.values);
  });

  test('offline mode blocks online features even if they are listed', () {
    final set = FeatureSet.fromJson('{"mode": "offline", "features": ["tables", "qr_ordering", "location_check", "expenses"]}');
    expect(set.mode, InstallMode.offline);
    expect(set.allows(AppFeature.expenses), isTrue);
    expect(set.allows(AppFeature.tables), isTrue, reason: 'tables work offline as open tabs');
    expect(set.allows(AppFeature.qrOrdering), isFalse);
    expect(set.allows(AppFeature.locationCheck), isFalse);
  });

  test('reads the cafe slot picked in an online setup', () {
    expect(FeatureSet.fromJson('{"mode": "online", "features": [], "slot": 3}').slot, 3);
    expect(FeatureSet.fromJson('{"mode": "online", "features": []}').slot, isNull);
    expect(FeatureSet.all.slot, isNull);
  });

  test('ignores a slot that is out of range, not a number, or on an offline install', () {
    expect(FeatureSet.fromJson('{"features": [], "slot": 0}').slot, isNull);
    expect(FeatureSet.fromJson('{"features": [], "slot": 9}').slot, isNull);
    expect(FeatureSet.fromJson('{"features": [], "slot": "3"}').slot, isNull);
    expect(FeatureSet.fromJson('{"mode": "offline", "features": [], "slot": 3}').slot, isNull);
  });

  test('an unknown mode is read as online', () {
    expect(FeatureSet.fromJson('{"mode": "x", "features": []}').mode, InstallMode.online);
  });

  test('intersect keeps only features both sets allow', () {
    final installer = FeatureSet.fromKeys(['tables', 'expenses']);
    final paid = FeatureSet.fromKeys(['tables', 'discounts']);
    final both = installer.intersect(paid);
    expect(both.allows(AppFeature.tables), isTrue);
    expect(both.allows(AppFeature.expenses), isFalse);
    expect(both.allows(AppFeature.discounts), isFalse);
  });

  test('intersect is offline when either side is offline', () {
    final installer = FeatureSet.fromKeys(['qr_ordering', 'tables', 'expenses'], mode: InstallMode.offline);
    final both = installer.intersect(FeatureSet.all);
    expect(both.mode, InstallMode.offline);
    expect(both.allows(AppFeature.qrOrdering), isFalse);
    expect(both.allows(AppFeature.expenses), isTrue);
  });
}
