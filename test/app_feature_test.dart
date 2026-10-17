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
    final set = FeatureSet.fromJson('{"features": []}');
    for (final feature in AppFeature.values) {
      expect(set.allows(feature), isFalse, reason: feature.key);
    }
  });

  test('fromJson falls back to all when there is no file or it is broken', () {
    expect(FeatureSet.fromJson(null).allows(AppFeature.discounts), isTrue);
    expect(FeatureSet.fromJson('not json').allows(AppFeature.discounts), isTrue);
    expect(FeatureSet.fromJson('{"features": "tables"}').allows(AppFeature.discounts), isTrue);
  });

  test('offline mode offers only features that work without internet', () {
    final offered = AppFeature.offeredIn(InstallMode.offline);
    expect(offered, [
      AppFeature.discounts,
      AppFeature.dishToggle,
      AppFeature.expenses,
      AppFeature.reports,
      AppFeature.branding,
      AppFeature.paymentTypes,
    ]);
    expect(AppFeature.offeredIn(InstallMode.online), AppFeature.values);
  });

  test('offline mode blocks online features even if they are listed', () {
    final set = FeatureSet.fromJson('{"mode": "offline", "features": ["tables", "qr_ordering", "expenses"]}');
    expect(set.mode, InstallMode.offline);
    expect(set.allows(AppFeature.expenses), isTrue);
    expect(set.allows(AppFeature.tables), isFalse);
    expect(set.allows(AppFeature.qrOrdering), isFalse);
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
    final installer = FeatureSet.fromKeys(['tables', 'expenses'], mode: InstallMode.offline);
    final both = installer.intersect(FeatureSet.all);
    expect(both.mode, InstallMode.offline);
    expect(both.allows(AppFeature.tables), isFalse);
    expect(both.allows(AppFeature.expenses), isTrue);
  });
}
