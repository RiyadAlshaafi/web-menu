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

  test('core only keeps the always-on and standard sections', () {
    expect(
      _paths(AppSections.visible(AppSections.admin, coreOnly)),
      ['/admin/dashboard', '/admin/menu', '/admin/sales', '/admin/wages', '/admin/settings'],
    );
    expect(_paths(AppSections.visible(AppSections.cashier, coreOnly)), ['/pos/takeout', '/pos/log', '/pos/shifts']);
  });

  test('live alerts come with tables', () {
    final qrWithoutTables = FeatureSet.fromKeys(['qr_ordering']);
    expect(_paths(AppSections.visible(AppSections.cashier, qrWithoutTables)), isNot(contains('/pos')));
    final tables = FeatureSet.fromKeys(['tables'], mode: InstallMode.offline);
    expect(_paths(AppSections.visible(AppSections.cashier, tables)), containsAll(['/pos', '/pos/tables']));
    expect(AppSections.blockedRedirect('/pos', tables), isNull);
    expect(FeatureSet.fromKeys(['waiter_phones']).allows(AppFeature.waiterPhones), isFalse, reason: 'needs tables');
  });

  test('a page whose feature is off goes to the first page that is on', () {
    expect(AppSections.blockedRedirect('/admin/stock', coreOnly), '/admin/dashboard');
    expect(AppSections.blockedRedirect('/admin/categories', coreOnly), '/admin/dashboard');
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
    expect(cashier, contains('/pos'), reason: 'live alerts come with tables');
  });
}
