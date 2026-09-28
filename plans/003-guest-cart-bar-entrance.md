# 003 — Slide the guest cart bar in and crossfade its totals

- **Status**: DONE
- **Commit**: 1ca29f8
- **Severity**: MEDIUM
- **Category**: Missed opportunity
- **Estimated scope**: 1 file (`lib/screens/customer_screens.dart`), ~35 lines
- **Depends on**: 001 (uses `CafeMotion` from `lib/theme/cafe_theme.dart`)

## Problem

On the guest menu, the cart bar pops into existence the instant the first dish is added, pushing the menu up, and its item count and total jump between values:

```dart
// lib/screens/customer_screens.dart:257-307 — current (abridged)
if (cartCount > 0)
  Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Material(
      ...
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.guestCartItemCount('$cartCount'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          Text(store.currency.format(store.cartFor(table.id).total), style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
      ...
    ),
  ),
CustomerShell.nav(context, widget.tableSlug, '/t/${widget.tableSlug}'),
```

The bar is the guest's confirmation that tapping "+" worked. Appearing from nowhere doesn't say where it came from.

## Target

- Bar enters: height grows from 0 anchored to its bottom edge, plus opacity 0 → 1, 250ms, `CafeMotion.easeOut` (`Cubic(0.23, 1, 0.32, 1)`). Reads as sliding up from the bottom navigation.
- Bar exits (cart emptied): reverse, 200ms, `CafeMotion.easeOut.flipped`.
- Item count and total: crossfade 150ms (`CafeMotion.quick`), `CafeMotion.easeOut`, left-aligned (start-aligned in RTL).
- Reduce motion on: the bar and the numbers only fade; the bar's height snaps.
- Known tradeoff: the height change resizes the menu list above for 250ms. This is accepted to avoid restructuring the screen.

## Repo conventions to follow

Motion values come from `CafeMotion` in `lib/theme/cafe_theme.dart` (added by plan 001). `customer_screens.dart` already imports `../theme/cafe_theme.dart`.

## Steps

1. Replace `if (cartCount > 0) Padding(...)` with an `AnimatedSwitcher` whose child is the existing `Padding(...)` (unchanged apart from step 2) when `cartCount > 0`, and an empty box otherwise:

   ```dart
   AnimatedSwitcher(
     duration: CafeMotion.medium,
     reverseDuration: const Duration(milliseconds: 200),
     switchInCurve: CafeMotion.easeOut,
     switchOutCurve: CafeMotion.easeOut.flipped,
     transitionBuilder: (child, animation) {
       final faded = FadeTransition(opacity: animation, child: child);
       if (MediaQuery.disableAnimationsOf(context)) return faded;
       return SizeTransition(sizeFactor: animation, axisAlignment: 1, child: faded);
     },
     child: cartCount > 0
         ? KeyedSubtree(
             key: const ValueKey('cart-bar'),
             child: Padding(/* existing bar, unchanged */),
           )
         : const SizedBox.shrink(key: ValueKey('cart-bar-empty')),
   ),
   ```

2. Inside the bar, wrap each of the two `Text` widgets (count and total) in its own `AnimatedSwitcher`, keyed by its displayed string:

   ```dart
   AnimatedSwitcher(
     duration: CafeMotion.quick,
     switchInCurve: CafeMotion.easeOut,
     switchOutCurve: CafeMotion.easeOut.flipped,
     layoutBuilder: (current, previous) => Stack(
       alignment: AlignmentDirectional.centerStart,
       children: [...previous, if (current != null) current],
     ),
     child: Text(
       context.l10n.guestCartItemCount('$cartCount'),
       key: ValueKey('count-$cartCount'),
       style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
     ),
   ),
   ```

   Do the same for the total, with `key: ValueKey(<the formatted total string>)`.

## Boundaries

- Do NOT change the bar's buttons, colors, padding, or the `CustomerShell.nav` call.
- Do NOT touch other screens in the file (cart screen, bill screen, dish sheet).
- The app reloads data every 2 seconds; keys must depend only on the displayed values so an unchanged reload does not replay the animation. Do not key on object identity or timestamps.
- If the code does not match the excerpt above, STOP and report.

## Verification

- **Mechanical**: `flutter analyze` reports no issues.
- **Feel check**: open `/t/<slug>` with an empty cart, tap "+" on a dish.
  - The bar rises from the bottom navigation over about a quarter second; it does not appear from the middle.
  - Tap "+" again: the count and total crossfade in place without shifting sideways; in Arabic they stay right-aligned.
  - Wait 10 seconds without tapping: nothing re-animates on the background reloads.
  - Empty the cart from the cart screen and return: the bar leaves quickly.
  - With reduce motion on, the bar fades in without the rising motion.
- **Done when**: all of the above hold and no other part of the screen changed.
