# 004 — Shake the PIN dots when sign-in fails

- **Status**: DONE
- **Commit**: 1ca29f8
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 1 file (`lib/screens/auth_screens.dart`), ~40 lines
- **Depends on**: 001 (uses `CafeMotion`)

## Problem

When a cashier's PIN is wrong, the four dots silently empty and a small red line appears. It is easy to miss that the attempt failed:

```dart
// lib/screens/auth_screens.dart:148-162 — current
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: List.generate(4, (index) {
    final filled = index < store.pinBuffer.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? CafeColors.terracotta : const Color(0xFFD9D0C8),
      ),
    );
  }),
),
```

```dart
// lib/screens/auth_screens.dart:201-205 — current
Future<void> _submit(CafeStore store) async {
  if (!await store.signInCashier()) return;
  if (!mounted) return;
  context.go('/pos');
}
```

`_PinLoginScreenState` (line 20) is a plain `State` with a `FocusNode`.

## Target

- On a failed sign-in, the dots row shakes horizontally once: offsets 0 → -8 → 8 → -6 → 6 → -3 → 0 logical pixels, 360ms total, each segment `Curves.easeInOut`.
- Only the dots move. The red error text stays as it is.
- Filling a dot while typing stays instant (typing a PIN happens many times a day).
- Reduce motion on: no shake; the error text alone communicates the failure.
- A second failure during a shake restarts the shake from the start (`forward(from: 0)`); that is acceptable for a 360ms error signal.

## Repo conventions to follow

Screens are `StatefulWidget`s with state in `_XState`; controllers are created in `initState` and disposed in `dispose`, as `focusNode` is here.

## Steps

1. Add `with SingleTickerProviderStateMixin` to `_PinLoginScreenState`.
2. Add fields and create them in `initState`, dispose in `dispose`:

   ```dart
   late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
   late final Animation<double> shakeOffset = TweenSequence<double>([
     for (final (from, to) in const [(0.0, -8.0), (-8.0, 8.0), (8.0, -6.0), (-6.0, 6.0), (6.0, -3.0), (-3.0, 0.0)])
       TweenSequenceItem(tween: Tween(begin: from, end: to).chain(CurveTween(curve: Curves.easeInOut)), weight: 1),
   ]).animate(shake);
   ```

   Add `shake.dispose();` before `super.dispose()`.

3. Wrap the dots `Row` in:

   ```dart
   AnimatedBuilder(
     animation: shakeOffset,
     builder: (context, child) => Transform.translate(offset: Offset(shakeOffset.value, 0), child: child),
     child: Row(/* unchanged */),
   ),
   ```

4. Change `_submit`:

   ```dart
   Future<void> _submit(CafeStore store) async {
     if (!await store.signInCashier()) {
       if (mounted && !MediaQuery.disableAnimationsOf(context)) shake.forward(from: 0);
       return;
     }
     if (!mounted) return;
     context.go('/pos');
   }
   ```

## Boundaries

- Do NOT change the PIN pad keys, `CafeStore`, or the error text.
- Do NOT animate dot filling.
- If the code does not match the excerpts above, STOP and report.

## Verification

- **Mechanical**: `flutter analyze` reports no issues.
- **Feel check**: on `/login`, pick a cashier, type a wrong PIN, press Sign in (and separately press Enter on the keyboard).
  - The dots shake left and right once and settle centered; nothing else on the card moves.
  - Typing digits still fills dots instantly.
  - With reduce motion on, there is no shake and the error text still appears.
- **Done when**: both the button and the Enter key trigger the shake on failure, and a correct PIN never shakes.
