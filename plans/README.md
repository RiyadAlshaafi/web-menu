# Animation plans

Written against commit `1ca29f8`.

| # | Plan | Severity | Status |
| --- | --- | --- | --- |
| 001 | [Replace the page transition and respect reduce motion](001-page-transition-and-reduced-motion.md) | HIGH | DONE |
| 002 | [Make cashier and admin sidebar tab switches instant](002-instant-sidebar-tabs.md) | HIGH | DONE |
| 003 | [Slide the guest cart bar in and crossfade its totals](003-guest-cart-bar-entrance.md) | MEDIUM | DONE |
| 004 | [Shake the PIN dots when sign-in fails](004-pin-error-shake.md) | LOW | DONE |
| 005 | [Highlight new staff calls and bill requests](005-highlight-new-staff-calls.md) | LOW | DONE |

## Order

Run 001 first: it adds `CafeMotion` to `lib/theme/cafe_theme.dart`, which 003, 004, and 005 use. 002 is independent. After 001, the rest can run in any order; each touches a different file.
