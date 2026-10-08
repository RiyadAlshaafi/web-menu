# 001 — Replace the page transition and respect reduce motion

- **Status**: DONE
- **Commit**: 1ca29f8
- **Severity**: HIGH
- **Category**: Easing & duration, Physicality, Accessibility
- **Estimated scope**: 1 file (`lib/theme/cafe_theme.dart`), ~45 lines

## Problem

Every route uses Flutter's `FadeUpwardsPageTransitionsBuilder`:

```dart
// lib/theme/cafe_theme.dart:35-43 — current
pageTransitionsTheme: const PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
  },
),
```

That builder slides the page up from 25% of the screen height (about 225px on a tablet) and fades it in with `Curves.easeIn`, so content arrives late: the opacity starts slow at the exact moment the user is looking. It also ignores the OS "reduce motion" setting (`MediaQuery.disableAnimationsOf`).

## Target

- Enter: opacity 0 → 1 and a vertical slide from `Offset(0, 0.03)` to `Offset.zero`, both on `Cubic(0.23, 1, 0.32, 1)` (strong ease-out).
- Exit (pop): the same animation reversed with the flipped curve, so it also starts fast.
- Duration: the route's own duration (MaterialPageRoute is 300ms), no change.
- Reduce motion on: opacity only, no slide.
- Shared motion values live in a new `CafeMotion` class for the other plans to reuse.

## Repo conventions to follow

Theme constants are static members on small classes in `lib/theme/cafe_theme.dart` (`CafeColors`, `CafeTheme`). Add `CafeMotion` the same way, in the same file, directly after `CafeColors`.

## Steps

1. In `lib/theme/cafe_theme.dart`, after the closing `}` of `class CafeColors`, add:

   ```dart
   class CafeMotion {
     static const easeOut = Cubic(0.23, 1, 0.32, 1);
     static const easeInOut = Cubic(0.77, 0, 0.175, 1);
     static const quick = Duration(milliseconds: 150);
     static const medium = Duration(milliseconds: 250);
   }

   class CafePageTransitionsBuilder extends PageTransitionsBuilder {
     const CafePageTransitionsBuilder();

     static final _rise = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero);

     @override
     Widget buildTransitions<T>(
       PageRoute<T> route,
       BuildContext context,
       Animation<double> animation,
       Animation<double> secondaryAnimation,
       Widget child,
     ) {
       final curved = CurvedAnimation(
         parent: animation,
         curve: CafeMotion.easeOut,
         reverseCurve: CafeMotion.easeOut.flipped,
       );
       final faded = FadeTransition(opacity: curved, child: child);
       if (MediaQuery.disableAnimationsOf(context)) return faded;
       return SlideTransition(position: _rise.animate(curved), child: faded);
     }
   }
   ```

2. Replace the `pageTransitionsTheme` block (lines 35-43) with:

   ```dart
   pageTransitionsTheme: const PageTransitionsTheme(
     builders: {
       TargetPlatform.android: CafePageTransitionsBuilder(),
       TargetPlatform.iOS: CafePageTransitionsBuilder(),
       TargetPlatform.macOS: CafePageTransitionsBuilder(),
       TargetPlatform.windows: CafePageTransitionsBuilder(),
       TargetPlatform.linux: CafePageTransitionsBuilder(),
       TargetPlatform.fuchsia: CafePageTransitionsBuilder(),
     },
   ),
   ```

## Boundaries

- Do NOT touch any other file.
- Do NOT change colors, fonts, or input styles in the theme.
- Do NOT add dependencies.
- If the current code does not match the excerpt above, STOP and report.

## Verification

- **Mechanical**: `flutter analyze` reports no issues.
- **Feel check**: run `flutter run -d chrome`, open a guest menu (`/t/<slug>`), then go to the cart and back.
  - The new page is readable almost immediately; it moves only a few pixels, not a quarter of the screen.
  - Going back starts moving instantly, with no slow start.
  - With `timeDilation = 5.0` (temporarily in `main()`), the fade and the small rise finish together with no late fade-in.
  - Turn on reduce motion in the OS (Windows: Settings → Accessibility → Visual effects → Animation effects off) and reload: pages fade but do not move.
- **Done when**: `FadeUpwardsPageTransitionsBuilder` no longer appears in `lib/`, and `CafeMotion` exists in `cafe_theme.dart`.
