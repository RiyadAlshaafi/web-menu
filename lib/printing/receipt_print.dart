import 'package:flutter/services.dart';
import 'package:menu_web_v1/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

import '../core/choice_labels.dart';
import '../core/ledger.dart';
import 'kitchen_ticket.dart';
import 'receipt_settings.dart';
import 'slip.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../core/time_format.dart';

/// What a receipt says about one sale: taken from a real sale, or made up for the preview in
/// Settings. Dine-in, takeout and voided sales all print from this.
class ReceiptData {
  const ReceiptData({
    required this.receiptNumber,
    required this.orderNumber,
    required this.paidAt,
    required this.takeout,
    required this.tableNumber,
    required this.cashierName,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.service,
    required this.total,
    required this.method,
    this.voidReason,
  });

  final String receiptNumber;
  final String orderNumber;
  final DateTime paidAt;
  final bool takeout;
  final String tableNumber;
  final String cashierName;
  final List<OrderLine> lines;
  final double subtotal;
  final double discount;
  final double service;
  final double total;
  final String method;

  /// Set for a voided sale, which prints with a VOID banner and the reason.
  final String? voidReason;

  factory ReceiptData.ofSale(CafeStore store, Payment payment) {
    final row = saleLedgerRow(store, payment);
    final charged = row.lines.fold<double>(0, (sum, line) => sum + line.total);
    return ReceiptData(
      receiptNumber: store.receiptNumber(payment),
      orderNumber: store.orderNumber(payment.shiftOrderNumber),
      paidAt: payment.paidAt,
      takeout: row.takeout,
      tableNumber: row.tableNumber,
      cashierName: row.cashierName,
      lines: row.lines,
      subtotal: row.subtotal,
      discount: row.discount,
      service: row.total - charged,
      total: row.total,
      method: store.paymentLabel(payment),
      voidReason: payment.isVoided ? (payment.voidReason ?? '') : null,
    );
  }

  /// A made-up sale for the preview: the first dishes of the menu (or a sample dish), with a
  /// small discount and the cafe's service charge on dine-in, so every line can be seen.
  factory ReceiptData.sample(CafeStore store, AppLocalizations l10n, {required bool takeout}) {
    final dishes = store.menuItems.where((item) => item.price > 0).take(2).toList();
    final lines = dishes.isEmpty
        ? [OrderLine(menuItemId: 'sample', name: l10n.kitchenTestDish, qty: 2, unitPrice: 10)]
        : [
            for (final (index, dish) in dishes.indexed)
              OrderLine(menuItemId: dish.id, name: dish.displayName(store.locale), qty: index + 1, unitPrice: dish.price),
          ];
    final charged = lines.fold<double>(0, (sum, line) => sum + line.total);
    final discount = (charged * 0.1 * 100).roundToDouble() / 100;
    final afterDiscount = charged - discount;
    final service = takeout ? 0.0 : (afterDiscount * store.serviceChargeRate * 100).roundToDouble() / 100;
    final method = store.paymentTypes.where((type) => type.enabled).firstOrNull;
    return ReceiptData(
      receiptNumber: '2610001',
      orderNumber: store.orderNumber(7),
      paidAt: DateTime.now(),
      takeout: takeout,
      tableNumber: takeout ? '' : '4',
      cashierName: store.cashiers.firstOrNull?.name ?? l10n.receiptSampleCashier,
      lines: lines,
      subtotal: charged,
      discount: discount,
      service: service,
      total: afterDiscount + service,
      method: method == null ? l10n.receiptSampleMethod : (store.locale == 'ar' ? method.nameAr : method.nameEn),
    );
  }
}

/// The cashier receipt (dine-in, takeout or voided), as slip lines. [settings] defaults to the
/// cafe's saved ones; the editor passes the ones being edited.
List<SlipLine> receiptSlip(CafeStore store, ReceiptData data, AppLocalizations l10n, {ReceiptSettings? settings}) {
  final look = settings ?? store.receiptSettings;
  final money = store.currency.format;
  return [
    if (look.showLogo && store.logoUrl.isNotEmpty) SlipLogo(store.logoUrl),
    if (look.showCafeName) SlipText(store.cafeName, center: true, size: 16, bold: true),
    for (final line in look.header.split('\n'))
      if (line.trim().isNotEmpty) SlipText(line.trim(), center: true, size: 9),
    const SlipGap(),
    if (data.voidReason != null) ...[
      SlipText(l10n.voidStatus.toUpperCase(), center: true, size: 20, bold: true),
      SlipText(l10n.voidReasonLine(data.voidReason!), center: true),
      const SlipGap(),
    ],
    SlipText('${l10n.salesReceiptNo} ${data.receiptNumber}'),
    if (look.showOrderNumber) SlipText(l10n.cashierOrderNumber(data.orderNumber)),
    if (look.showDate) SlipText(formatTripoliDateTime(data.paidAt)),
    if (look.showTable) SlipText(data.takeout ? l10n.serviceTakeout : l10n.cashierTableShort(data.tableNumber)),
    if (look.showCashier && data.cashierName.isNotEmpty) SlipText(l10n.receiptCashierLine(data.cashierName)),
    const SlipDivider(),
    for (final line in data.lines) ...[
      SlipPair('${line.qty}  ${line.name}', money(line.total)),
      if (look.showChoices && line.choices.isNotEmpty)
        SlipText(choicesText(line.choices, l10n.localeName, without: l10n.dishChoiceWithout, money: money), size: 9),
    ],
    const SlipDivider(),
    SlipPair(l10n.cashierSubtotal, money(data.subtotal)),
    if (look.showDiscount && data.discount > 0) SlipPair(l10n.salesColDiscount, money(data.discount)),
    if (look.showServiceCharge && data.service > 0.009)
      SlipPair(l10n.cashierServiceCharge(store.serviceChargePercentLabel), money(data.service)),
    SlipPair(l10n.cashierTotalPayable, money(data.total), bold: true),
    if (look.showPaymentMethod) SlipText('${l10n.salesColMethod} ${data.method}'),
    const SlipGap(8),
    SlipText(look.footer.isEmpty ? l10n.receiptThankYou : look.footer, center: true),
  ];
}

Future<Uint8List> receiptPdfBytes(CafeStore store, Payment payment, AppLocalizations l10n, {int paperMm = defaultPaperMm}) =>
    slipPdf(receiptSlip(store, ReceiptData.ofSale(store, payment), l10n), paperMm: paperMm);

/// Prints straight to this till's cashier printer, at its paper width, when one is picked in
/// Settings; otherwise opens the print dialog. Throws when the cashier printer did not print.
Future<void> showReceiptPrint(CafeStore store, Payment payment, AppLocalizations l10n) async {
  final printer = (await TillPrinters.settings()).receipt;
  if (printer != null) {
    final result = await TillPrinters.printPdf(
      printer,
      name: 'receipt-${store.receiptNumber(payment)}',
      build: (paperMm) => receiptPdfBytes(store, payment, l10n, paperMm: paperMm),
    );
    if (result != KitchenPrintResult.printed) throw StateError('receipt printer: ${result.name}');
    return;
  }
  final bytes = await receiptPdfBytes(store, payment, l10n);
  await Printing.layoutPdf(
    name: 'receipt-${store.receiptNumber(payment)}',
    onLayout: (format) async => bytes,
  );
}
