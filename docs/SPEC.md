# Tawla — Product Spec

*12 October 2026*

## 1. What it is

A cafe till with QR ordering, in **English and Arabic**.

- **Guests** scan the table's QR code and order from their phone.
- **Cashiers** take payment and sell takeout.
- **Admins** set up the menu, tables and staff.

Runs on: a **guest website**, a **staff website**, and a **Windows till** that works offline.

## 2. Who uses it

| Who | How they get in |
| --- | --- |
| Guest | Scans the table's QR code. No account. |
| Cashier | Taps their name and types a PIN. |
| Admin | Email and password. |

- Each device is linked to its cafe once, by opening `tawla.ly/c/<cafe-name>`.
- Each cafe sees only its own data.

## 3. What each person can do

**Guest**

- Read the menu
- Order, and add more later
- Watch the order's progress live
- Call staff
- Ask for the bill

**Cashier**

- Get alerts for new orders and calls
- Take payment
- Sell takeout
- Turn dishes on or off
- Record expenses
- Open and close a shift

**Admin**

- Edit the menu, prices and discounts
- Add tables and print QR codes
- Add or remove cashiers
- See sales and expenses
- Export reports (CSV or PDF)
- Change the logo, colours and settings

## 4. Works everywhere

- **Offline:** the Windows till keeps selling and uploads later.
- **Live:** screens update within seconds.
- **Two languages:** Arabic reads right to left.
- **Receipts:** print in both languages.
- **Spam limits:** stop a phone or table from sending too many orders or calls.
- **Backups:** every night.

## 5. What it stores

- Cafes
- Staff
- Tables
- Menu
- Orders
- Receipts
- Shifts
- Expenses
- Staff calls

**Key rule:** guests and tills can't edit data directly. Everything goes through checked actions.

## 6. Main flows

**Guest orders**

1. Scan the QR code
2. Add dishes
3. Send
4. The till beeps
5. The order shows live

**Guest wants help or the bill**

1. Tap "Call staff" or "Request bill"
2. The cashier sees it

**Cashier gets paid**

1. Open the table
2. Enter the cash
3. Confirm
4. The receipt prints

**Till is offline**

1. Keep selling
2. Sales are saved on the PC
3. When the internet is back, a cashier enters their PIN
4. Sales upload

## 7. Tech

- **Staff app:** Flutter
- **Guest app:** Next.js
- **Database:** Supabase
- **Hosting:** Cloudflare
- **Builds and backups:** GitHub Actions

## 8. Problems to fix

1. **Tests don't run before going live.**
2. A cashier can close a shift while tables are still unpaid.
3. The guest menu always says "Mezzogiorno Menu", not the cafe's name.
4. The web till can't work offline.
5. Very few tests for the admin screens.

**Not yet checked:** password reset, real receipt printer.
