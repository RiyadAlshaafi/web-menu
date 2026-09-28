# 002 — Make cashier and admin sidebar tab switches instant

- **Status**: DONE
- **Commit**: 1ca29f8
- **Severity**: HIGH
- **Category**: Purpose & frequency
- **Estimated scope**: 1 file (`lib/main.dart`), 7 route lines

## Problem

The cashier and admin areas are `ShellRoute`s: the sidebar stays on screen and only the content area changes. Each content route uses `builder:`, so go_router wraps it in a `MaterialPage` and plays the full page transition on every tab click:

```dart
// lib/main.dart:100-117 — current
ShellRoute(
  builder: (context, state, child) => CashierShell(location: state.uri.path, child: child),
  routes: [
    GoRoute(path: '/pos', builder: (_, _) => const CashierDashboardScreen()),
    GoRoute(path: '/pos/tables', builder: (_, _) => const CashierFloorScreen()),
    GoRoute(path: '/pos/shifts', builder: (_, _) => const CashierShiftsScreen()),
  ],
),
ShellRoute(
  builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
  routes: [
    GoRoute(path: '/admin/menu', builder: (_, _) => const AdminMenuScreen()),
    GoRoute(path: '/admin/discounts', builder: (_, _) => const AdminCategoriesScreen()),
    GoRoute(path: '/admin/categories', redirect: (_, _) => '/admin/discounts'),
    GoRoute(path: '/admin/tables', builder: (_, _) => const AdminTablesScreen()),
    GoRoute(path: '/admin/settings', builder: (_, _) => const AdminSettingsScreen()),
  ],
),
```

Cashiers switch between Dashboard, Tables, and Shifts dozens of times a day. Motion on an action that frequent adds delay with no purpose: the sidebar already shows where you are.

## Target

Content inside both shells swaps with no transition. Navigation that enters or leaves a shell (for example login → `/pos`) keeps the normal page transition.

## Repo conventions to follow

Routes are declared inline in `lib/main.dart` with `GoRoute`. go_router's `NoTransitionPage` is already available from `package:go_router/go_router.dart`, which `main.dart` imports.

## Steps

1. In `lib/main.dart`, change each of the seven `builder:` routes inside the two `ShellRoute`s to a `pageBuilder` returning `NoTransitionPage`. Example for the first:

   ```dart
   GoRoute(
     path: '/pos',
     pageBuilder: (_, state) => NoTransitionPage(key: state.pageKey, child: const CashierDashboardScreen()),
   ),
   ```

   Apply the same pattern to `/pos/tables`, `/pos/shifts`, `/admin/menu`, `/admin/discounts`, `/admin/tables`, `/admin/settings`, keeping each route's screen widget.

2. Leave `/admin/categories` (redirect only) and the `ShellRoute` `builder:`s themselves unchanged.

## Boundaries

- Do NOT change any route outside the two `ShellRoute`s.
- Do NOT change the redirect logic or `_RouterRefresh`.
- If the code does not match the excerpt above, STOP and report.

## Verification

- **Mechanical**: `flutter analyze` reports no issues.
- **Feel check**: sign in as a cashier, click Dashboard → Tables → Shifts quickly several times. Content changes instantly with no fade or slide; the sidebar highlight moves immediately. Signing out and in still shows the normal page transition.
- **Done when**: no route inside either `ShellRoute` uses `builder:`.
