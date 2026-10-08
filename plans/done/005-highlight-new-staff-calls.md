# 005 — Highlight new staff calls and bill requests on the cashier dashboard

- **Status**: DONE
- **Commit**: 1ca29f8
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 1 file (`lib/screens/cashier_screens.dart`), ~60 lines
- **Depends on**: 001 (uses `CafeMotion`)

## Problem

On the cashier dashboard, a new "Call staff" or bill request appears in the alerts list with no signal. It arrives through the background reload, so a busy cashier doesn't notice it. The cards have no keys, so their state can't survive a reload either:

```dart
// lib/screens/cashier_screens.dart:281-307 — current (abridged)
...bills.map((table) {
  final order = store.openOrderFor(table.id);
  return _alert(
    table: table.number,
    title: context.l10n.cashierBillRequest,
    ...
  );
}),
if (filter == _AlertFilter.all || filter == _AlertFilter.calls)
  ...calls.map(
    (call) => _alert(
      table: call.tableNumber,
      title: context.l10n.cashierCallStaff,
      ...
    ),
  ),
```

```dart
// lib/screens/cashier_screens.dart:493-509 — current
Widget _alert({
  required String table,
  required String title,
  required String body,
  required IconData icon,
  DateTime? time,
  double? amount,
  String? action,
  required VoidCallback onTap,
  VoidCallback? onAction,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SoftCard(
      radius: 16,
      ...
```

## Target

- When a staff call or bill request card first appears and the request is less than 20 seconds old, a terracotta tint `Color(0x33BA5333)` over the card fades to transparent over 1200ms. The curve is `Interval(0.3, 1.0, curve: CafeMotion.easeInOut)`, so the tint holds briefly, then fades.
- The tint is drawn on top of the card with the card's 16px radius. It is color only, with no movement, so it also runs with reduce motion on.
- Older requests, such as those present when the dashboard opens, never flash.
- Background reloads never replay the flash, because every alert card has a stable key.
- Order cards get keys too, so list state stays aligned, but they do not flash.
- 1200ms exceeds the 300ms budget for UI responses on purpose: this is an attention signal, not a response to the cashier's own input.

## Repo conventions to follow

Private widgets in this file are `_Name` classes. Motion values come from `CafeMotion` in `lib/theme/cafe_theme.dart`, which this file already imports.

## Steps

1. Add a private widget at the end of `lib/screens/cashier_screens.dart`:

   ```dart
   class _ArrivalFlash extends StatefulWidget {
     const _ArrivalFlash({required this.arrivedAt, required this.child});

     final DateTime? arrivedAt;
     final Widget child;

     @override
     State<_ArrivalFlash> createState() => _ArrivalFlashState();
   }

   class _ArrivalFlashState extends State<_ArrivalFlash> with SingleTickerProviderStateMixin {
     late final AnimationController fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
     late final Animation<double> tint = CurvedAnimation(parent: fade, curve: const Interval(0.3, 1.0, curve: CafeMotion.easeInOut));

     @override
     void initState() {
       super.initState();
       final at = widget.arrivedAt;
       if (at != null && DateTime.now().difference(at) < const Duration(seconds: 20)) {
         fade.forward(from: 0);
       } else {
         fade.value = 1;
       }
     }

     @override
     void dispose() {
       fade.dispose();
       super.dispose();
     }

     @override
     Widget build(BuildContext context) {
       return AnimatedBuilder(
         animation: tint,
         builder: (context, child) => DecoratedBox(
           position: DecorationPosition.foreground,
           decoration: BoxDecoration(
             color: Color.lerp(const Color(0x33BA5333), const Color(0x00BA5333), tint.value),
             borderRadius: BorderRadius.circular(16),
           ),
           child: child,
         ),
         child: widget.child,
       );
     }
   }
   ```

2. Change `_alert` to take `required Object id` and `DateTime? arrivedAt`. Give the outer `Padding` `key: ValueKey(id)`. Wrap the `SoftCard` (not the `Padding`) in `_ArrivalFlash(arrivedAt: arrivedAt, child: SoftCard(...))`.

3. Update the three call sites:
   - Bills: `id: 'bill-${table.id}'`, `arrivedAt: store.openCalls.where((c) => c.kind == 'bill' && c.tableId == table.id).firstOrNull?.createdAt`.
   - Calls: `id: 'call-${call.id}'`, `arrivedAt: call.createdAt`.
   - Orders: `id: 'order-${order.id}'`, no `arrivedAt`.

## Boundaries

- Do NOT change card layout, colors, text, or button behavior.
- Do NOT touch the floor screen or shifts screen.
- Do NOT use a `Timer` or poll; the flash is driven only by `initState`.
- If the code does not match the excerpts above, STOP and report.

## Verification

- **Mechanical**: `flutter analyze` reports no issues.
- **Feel check**: keep the cashier dashboard open. On another device, open a guest table and tap "Call staff", then "Request bill".
  - Each new card shows a soft terracotta tint that holds for a moment and fades within about a second.
  - Existing cards do not flash when the new one arrives, or when the list reloads every 2 seconds.
  - Reloading the dashboard with only old requests shows no flash.
- **Done when**: only requests newer than 20 seconds flash, and exactly once.
