import 'package:flutter/material.dart';

import '../features/app_feature.dart';
import '../l10n/l10n_ext.dart';

class AppSection {
  const AppSection({
    required this.path,
    required this.labelOf,
    required this.crumbOf,
    required this.icon,
    this.match,
    this.feature,
    this.orFeature,
  });

  final String path;
  final String Function(AppLocalizations l10n) labelOf;
  final String Function(AppLocalizations l10n) crumbOf;
  final IconData icon;
  final bool Function(String location)? match;

  /// The installer feature this section belongs to; null means always shown.
  final AppFeature? feature;

  /// A second feature that also shows this section (the alerts screen serves QR guests and waiter
  /// phones alike).
  final AppFeature? orFeature;

  bool shownIn(FeatureSet features) {
    final needed = feature;
    if (needed == null || features.allows(needed)) return true;
    final other = orFeature;
    return other != null && features.allows(other);
  }

  String label(BuildContext context) => labelOf(context.l10n);
  String crumb(BuildContext context) => crumbOf(context.l10n);

  bool matches(String location) => match?.call(location) ?? location.startsWith(path);
}

class AppSections {
  static final admin = <AppSection>[
    AppSection(
      path: '/admin/dashboard',
      feature: AppFeature.reports,
      labelOf: (l) => l.navDashboard,
      crumbOf: (l) => l.navDashboard,
      icon: Icons.grid_view_outlined,
    ),
    AppSection(
      path: '/admin/menu',
      labelOf: (l) => l.navMenuCatalogLabel,
      crumbOf: (l) => l.navMenuCatalog,
      icon: Icons.chrome_reader_mode_outlined,
    ),
    AppSection(
      path: '/admin/stock',
      feature: AppFeature.stock,
      labelOf: (l) => l.navStock,
      crumbOf: (l) => l.navStock,
      icon: Icons.inventory_2_outlined,
    ),
    AppSection(
      path: '/admin/discounts',
      feature: AppFeature.discounts,
      labelOf: (l) => l.navDiscounts,
      crumbOf: (l) => l.navDiscounts,
      icon: Icons.percent,
      match: (location) => location.startsWith('/admin/discounts') || location.startsWith('/admin/categories'),
    ),
    AppSection(
      path: '/admin/tables',
      feature: AppFeature.tables,
      labelOf: (l) => l.navTablesQr,
      crumbOf: (l) => l.navTablesQr,
      icon: Icons.qr_code_scanner_outlined,
    ),
    AppSection(
      path: '/admin/sales',
      feature: AppFeature.reports,
      labelOf: (l) => l.navSalesLog,
      crumbOf: (l) => l.navSalesLog,
      icon: Icons.receipt_outlined,
    ),
    AppSection(
      path: '/admin/wages',
      feature: AppFeature.expenses,
      labelOf: (l) => l.navWages,
      crumbOf: (l) => l.navWages,
      icon: Icons.account_balance_wallet_outlined,
    ),
    AppSection(
      path: '/admin/settings',
      labelOf: (l) => l.navSettings,
      crumbOf: (l) => l.navSettings,
      icon: Icons.settings_outlined,
    ),
  ];

  static final cashier = <AppSection>[
    AppSection(
      path: '/pos/takeout',
      labelOf: (l) => l.navQuickTakeout,
      crumbOf: (l) => l.navQuickTakeout,
      icon: Icons.work_outline,
    ),
    AppSection(
      path: '/pos',
      feature: AppFeature.qrOrdering,
      orFeature: AppFeature.waiterPhones,
      labelOf: (l) => l.navLiveAlerts,
      crumbOf: (l) => l.navLiveAlerts,
      icon: Icons.notifications_none_outlined,
      match: (location) => location == '/pos',
    ),
    AppSection(
      path: '/pos/tables',
      feature: AppFeature.tables,
      labelOf: (l) => l.navFloorOverview,
      crumbOf: (l) => l.navFloorOverview,
      icon: Icons.table_bar_outlined,
    ),
    AppSection(
      path: '/pos/dishes',
      feature: AppFeature.dishToggle,
      labelOf: (l) => l.navDishAvailability,
      crumbOf: (l) => l.navDishAvailability,
      icon: Icons.toggle_on_outlined,
    ),
    AppSection(
      path: '/pos/log',
      labelOf: (l) => l.navCashierLog,
      crumbOf: (l) => l.navCashierLog,
      icon: Icons.receipt_outlined,
    ),
    AppSection(
      path: '/pos/shifts',
      labelOf: (l) => l.navShiftSales,
      crumbOf: (l) => l.navShiftSales,
      icon: Icons.bar_chart_outlined,
    ),
  ];

  /// A waiter's tablet or phone: the floor and its tables only, never money pages.
  static final waiter = <AppSection>[
    AppSection(
      path: '/pos/tables',
      labelOf: (l) => l.navFloorOverview,
      crumbOf: (l) => l.navFloorOverview,
      icon: Icons.table_bar_outlined,
    ),
  ];

  /// Where a waiter device goes instead of [path], or null when it may open it: only
  /// `/pos/tables` and `/pos/tables/<id>`; other till pages go to the floor, admin pages to sign-in.
  static String? waiterRedirect(String path) {
    if (path == '/pos/tables' || RegExp(r'^/pos/tables/[^/]+$').hasMatch(path)) return null;
    if (path == '/pos' || path.startsWith('/pos/')) return '/pos/tables';
    if (path == '/admin' || path.startsWith('/admin/')) return '/login';
    return null;
  }

  /// Sections this install shows, in menu order.
  static List<AppSection> visible(List<AppSection> sections, FeatureSet features) =>
      sections.where((section) => section.shownIn(features)).toList();

  /// Where to send [path] when its feature is off, or null when the page may open.
  static String? blockedRedirect(String path, FeatureSet features) {
    final List<AppSection> sections;
    if (path.startsWith('/admin/')) {
      sections = admin;
    } else if (path == '/pos' || path.startsWith('/pos/')) {
      sections = cashier;
    } else {
      return null;
    }
    final matches = sections.where((section) => section.matches(path));
    if (matches.isEmpty) return null;
    if (matches.first.shownIn(features)) return null;
    return visible(sections, features).first.path;
  }

  static AppSection forAdmin(String location) {
    return admin.firstWhere((section) => section.matches(location), orElse: () => admin.first);
  }

  static AppSection forCashier(String location) {
    return cashier.firstWhere((section) => section.matches(location), orElse: () => cashier.first);
  }

  static bool compact(double width) => width < 960;

  /// Sidebar becomes a drawer so the page can use the full width.
  static bool useDrawer(double width) => width < 800;

  static double titleSize(double width, {double min = 22, double max = 32}) {
    final scaled = width * 0.028;
    return scaled.clamp(min, max);
  }
}
