import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/features/app_feature.dart';
import 'package:menu_web_v1/navigation/app_sections.dart';

List<String> _paths(List<AppSection> sections) => sections.map((s) => s.path).toList();

void main() {
  final coreOnly = FeatureSet.fromKeys(const []);

  test('every section shows when all features are on', () {
    expect(AppSections.visible(AppSections.admin, FeatureSet.all).length, AppSections.admin.length);
    expect(AppSections.visible(AppSections.cashier, FeatureSet.all).length, AppSections.cashier.length);
  });

  test('core only keeps the always-on sections', () {
    expect(_paths(AppSections.visible(AppSections.admin, coreOnly)), ['/admin/menu', '/admin/settings']);
    expect(_paths(AppSections.visible(AppSections.cashier, coreOnly)), ['/pos/takeout', '/pos/log', '/pos/shifts']);
  });

  test('live alerts need QR ordering, which needs tables', () {
    final qrWithoutTables = FeatureSet.fromKeys(['qr_ordering']);
    expect(_paths(AppSections.visible(AppSections.cashier, qrWithoutTables)), isNot(contains('/pos')));
    final both = FeatureSet.fromKeys(['tables', 'qr_ordering']);
    expect(_paths(AppSections.visible(AppSections.cashier, both)), containsAll(['/pos', '/pos/tables']));
  });

  test('a page whose feature is off goes to the first page that is on', () {
    expect(AppSections.blockedRedirect('/admin/dashboard', coreOnly), '/admin/menu');
    expect(AppSections.blockedRedirect('/admin/wages', coreOnly), '/admin/menu');
    expect(AppSections.blockedRedirect('/admin/categories', coreOnly), '/admin/menu');
    expect(AppSections.blockedRedirect('/pos', coreOnly), '/pos/takeout');
    expect(AppSections.blockedRedirect('/pos/dishes', coreOnly), '/pos/takeout');
  });

  test('pages that are on, core pages and sign-in pages are never redirected', () {
    expect(AppSections.blockedRedirect('/admin/dashboard', FeatureSet.all), isNull);
    expect(AppSections.blockedRedirect('/admin/settings', coreOnly), isNull);
    expect(AppSections.blockedRedirect('/pos/shifts', coreOnly), isNull);
    expect(AppSections.blockedRedirect('/admin/login', coreOnly), isNull);
    expect(AppSections.blockedRedirect('/login', coreOnly), isNull);
  });

  test('offline mode hides online-only sections even when ticked', () {
    final offline = FeatureSet.fromKeys(['tables', 'qr_ordering', 'reports', 'expenses', 'stock'], mode: InstallMode.offline);
    expect(
      _paths(AppSections.visible(AppSections.admin, offline)),
      ['/admin/dashboard', '/admin/menu', '/admin/stock', '/admin/tables', '/admin/sales', '/admin/wages', '/admin/settings'],
    );
    final cashier = _paths(AppSections.visible(AppSections.cashier, offline));
    expect(cashier, contains('/pos/tables'), reason: 'tables work offline as open tabs');
    expect(cashier, isNot(contains('/pos')), reason: 'live alerts need QR ordering');
  });
}
