import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';

class AppSection {
  const AppSection({
    required this.path,
    required this.labelOf,
    required this.crumbOf,
    required this.icon,
    this.match,
  });

  final String path;
  final String Function(AppLocalizations l10n) labelOf;
  final String Function(AppLocalizations l10n) crumbOf;
  final IconData icon;
  final bool Function(String location)? match;

  String label(BuildContext context) => labelOf(context.l10n);
  String crumb(BuildContext context) => crumbOf(context.l10n);

  bool matches(String location) => match?.call(location) ?? location.startsWith(path);
}

class AppSections {
  static final admin = <AppSection>[
    AppSection(
      path: '/admin/menu',
      labelOf: (l) => l.navMenuCatalogLabel,
      crumbOf: (l) => l.navMenuCatalog,
      icon: Icons.menu_book,
    ),
    AppSection(
      path: '/admin/discounts',
      labelOf: (l) => l.navDiscounts,
      crumbOf: (l) => l.navDiscounts,
      icon: Icons.percent,
      match: (location) => location.startsWith('/admin/discounts') || location.startsWith('/admin/categories'),
    ),
    AppSection(
      path: '/admin/tables',
      labelOf: (l) => l.navTablesQr,
      crumbOf: (l) => l.navTablesQr,
      icon: Icons.qr_code_2,
    ),
    AppSection(
      path: '/admin/sales',
      labelOf: (l) => l.navSalesLog,
      crumbOf: (l) => l.navSalesLog,
      icon: Icons.receipt_long,
    ),
    AppSection(
      path: '/admin/settings',
      labelOf: (l) => l.navSettings,
      crumbOf: (l) => l.navSettings,
      icon: Icons.settings,
    ),
  ];

  static final cashier = <AppSection>[
    AppSection(
      path: '/pos',
      labelOf: (l) => l.navLiveAlerts,
      crumbOf: (l) => l.navLiveAlerts,
      icon: Icons.notifications_active_outlined,
      match: (location) => location == '/pos',
    ),
    AppSection(
      path: '/pos/tables',
      labelOf: (l) => l.navFloorOverview,
      crumbOf: (l) => l.navFloorOverview,
      icon: Icons.table_restaurant_outlined,
    ),
    AppSection(
      path: '/pos/dishes',
      labelOf: (l) => l.navDishAvailability,
      crumbOf: (l) => l.navDishAvailability,
      icon: Icons.toggle_on_outlined,
    ),
    AppSection(
      path: '/pos/sales',
      labelOf: (l) => l.navSalesLog,
      crumbOf: (l) => l.navSalesLog,
      icon: Icons.receipt_long,
    ),
    AppSection(
      path: '/pos/shifts',
      labelOf: (l) => l.navShiftSales,
      crumbOf: (l) => l.navShiftSales,
      icon: Icons.receipt_long_outlined,
    ),
  ];

  static AppSection forAdmin(String location) {
    return admin.firstWhere((section) => section.matches(location), orElse: () => admin.first);
  }

  static AppSection forCashier(String location) {
    return cashier.firstWhere((section) => section.matches(location), orElse: () => cashier.first);
  }

  static int columnsFor(double width, {int max = 3}) {
    if (width < 720) return 1;
    if (width < 1100) return 2;
    return max;
  }

  static bool compact(double width) => width < 960;

  static double titleSize(double width, {double min = 22, double max = 32}) {
    final scaled = width * 0.028;
    return scaled.clamp(min, max);
  }
}
