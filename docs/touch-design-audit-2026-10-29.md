# Touch-screen design audit — 2026-10-29

This audit only read the code. Nothing was changed. ✅ = I checked it in the code myself.
Goal: the till is used mostly by fingers (busy, sometimes wet, Arabic + English).

## The one fix that matters most

✅ **The theme uses Windows mouse sizes.** `lib/theme/cafe_theme.dart:181` never sets `visualDensity` or `materialTapTargetSize`, so on Windows Flutter shrinks every button by 8 px and drops the 48 px touch padding. A 40 px button becomes 32 px. This hits 40+ controls: header buttons, dialog X, Save/Cancel, checkboxes, ledger buttons.

Fix (≈5 lines in `ThemeData`):
- `visualDensity: VisualDensity.standard`
- `materialTapTargetSize: MaterialTapTargetSize.padded`
- `iconButtonTheme` → `minimumSize: Size(48, 48)`
- button themes → `minimumSize: Size(64, 48)`
- delete the `VisualDensity.compact` overrides in `floor_overview.dart:189,199`, `settle_panel.dart:386,393`, `cashier/shared.dart:47`

## High — fix soon

| # | Problem | Where | Fix |
|---|---|---|---|
| 1 | ✅ **A 4th or 5th cashier can't log in.** The PIN screen shows only `cashiers.take(3)` | `auth_screens.dart:131` | Show all cashiers in a Wrap/grid of 96×88 tiles |
| 2 | ✅ **One stray tap on a staff-call card clears the call** (the whole card does it, with no undo) | `live_alerts.dart:146` | Card tap does nothing; only the "Attended" button clears it, and it shows Undo |
| 3 | ✅ **At 1024×768 the Pay/Send button is about 200 px below the screen.** The side menu stays 232 px wide until 960 px | `app_sections.dart:193`, `cashier/shell.dart:113`, `quick_takeout.dart:149` | Compact menu below 1100 px; keep Pay/Send fixed at the bottom outside the scroll |
| 4 | ✅ **"Refuse" deletes a guest's item in one tap.** It sits right against an eye icon that hides the dish from the **whole menu** | `cashier/shared.dart:45-66` | 12 px gap, 44 px buttons, confirm or Undo; turn the eye into a labelled "Sold out" button |
| 5 | Floor card move/clear buttons are 36 px, grey, touch each other, and have tooltip-only labels; the status badge is clipped at 1024 | `floor_overview.dart:185-208` | One 48 px "⋯" button → a sheet with "Move table" / "Clear table" |
| 6 | A past receipt's payment method is a bare dropdown that **saves at once** | `sales_log_screen.dart:432-441` | Read-only text + "Change method" button + confirm |
| 7 | Dish availability: only the small switch can be tapped, not the 60 px row | `dish_availability_screen.dart:136-164` | Make the whole row tappable |
| 8 | Void/refund need a **typed reason** on the touch keyboard | `void_sale_dialog.dart:117`, `refund_line_dialog.dart:136` | Quick-reason chips ("Wrong item", "Changed mind", "Test sale"), with typing optional |
| 9 | Admin pages at 1024×768 scroll as a whole **and** each list scrolls inside it | `admin_screens.dart:92` | Only use the 900 px minimum on screens without their own list |
| 10 | Shared buttons default to 40 px, and edit sits 6-8 px from delete | `tawla_ui.dart:259,291`, `admin_catalog_screens.dart:695` | Defaults to 48 px, 12 px+ gaps, delete at the far end |

## Medium

- **Number pad instead of the Windows keyboard** for cash count, expense amount and claim PIN. Reuse `_PinPad` (64 px keys). `shift_sales.dart:424,618`
- The PIN pad doesn't sign in after the 4th digit, and the Clear key looks blank. `auth_screens.dart:316-388`
- **Payment type is a dropdown** on every sale. Use the existing `SegmentedPills` at 52 px above Pay. `quick_takeout.dart:296`
- Dish options open only on a hidden 1-second hold. Add a visible 44 px "Options" button. `quick_takeout.dart:439`
- '−' at quantity 1 deletes the line with no undo, and the steppers are 40 px. Make them 48 px and add Undo.
- Waiter dish card: tapping the count between − and + adds another dish. `waiter/order_screen.dart:278`
- Table-order dish cards overflow on 2-line names (124 px vs 144 px on takeout). `table_order.dart:86`
- Refund and Void are icon-only and 6 px apart. Add text labels and a 12 px gap. `shift_sales.dart:274-295`
- Header buttons (Sound, Phones) are 32 px with tooltip-only labels. Make them 48 px with short labels. `app_header.dart:98`
- Wide tables hide Total/Actions at 1024 behind a sideways swipe. Show rows as 2-line cards below 1000 px.
- Side menu between 800 and 959 px is icons only. Show a label under each icon.
- **Text fields are almost invisible**: no border, fill only 1.08:1 against white. Add a 1.5 px border and make them 52-56 px tall. `cafe_theme.dart:257-273`
- Filter boxes (`SelectBox`) can be tapped only on the text. Set `isExpanded: true` and drop `isDense`. `tawla_ui.dart:106`
- The confirm dialog is always red with a trash icon, even for "Activate all". Add a `destructive` flag. `cafe_dialogs.dart:31-78`
- Stock count has no +/- buttons. Menu-layout move arrows are 32 px and sit on a card that opens the editor.
- **Arabic labels have letter-spacing** (breaks the joins between letters) and are 10-11 px. Use 0 spacing in RTL and a 12 px minimum. `tawla_ui.dart:57,412`
- The Windows touch keyboard may cover dialog buttons. Remove `autofocus` and place dialogs near the top. **Test this on the real till.**

## Low

- Search fields have no clear (X) button. `tawla_ui.dart:62`
- Kitchen-critical text ("without onion") is 12 px. Raise it to 14 px bold. `cashier/shared.dart:92`
- The waiter's bill banner is white on orange at 2.7:1. Use `#95600F`. `waiter/tables_screen.dart:318`
- Log out, change café and remove phone have no confirm.
- A dead "Print receipt" button sits in live alerts. `live_alerts.dart:599`
- Discount is a 0-100 slider. Add 5/10/15/20/25/50% chips.
- The colour picker sits inside a scroll view, so dragging scrolls instead of picking.

## What's already good

No hover-only actions, no right-click-only actions. The nav items (64 px), the main buttons (52 px), the search field and the select boxes are finger-sized.

## Suggested order

1. Theme fix (5 lines; fixes the most)
2. High 1-4: login shows all cashiers, call card, 1024 layout, Refuse confirm
3. Number pad + payment pills + PIN auto-submit
4. The rest of High, then Medium
