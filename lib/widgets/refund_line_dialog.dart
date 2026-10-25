import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';

/// Picks one dish of [payment], how many came back and why, and refunds that part. True when
/// something was refunded.
Future<bool> showRefundLineDialog(BuildContext context, CafeStore store, Payment payment) async {
  final refunded = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (context) => _RefundLineDialog(store: store, payment: payment),
  );
  if (refunded == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.refundDone)));
  }
  return refunded == true;
}

class _RefundLineDialog extends StatefulWidget {
  const _RefundLineDialog({required this.store, required this.payment});

  final CafeStore store;
  final Payment payment;

  @override
  State<_RefundLineDialog> createState() => _RefundLineDialogState();
}

class _RefundLineDialogState extends State<_RefundLineDialog> {
  final reason = TextEditingController();
  late final List<OrderLine> lines = widget.store.saleLines(widget.payment);
  int? picked;
  int qty = 1;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    picked = [for (var index = 0; index < lines.length; index++) index].where((index) => _left(index) > 0).firstOrNull;
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  int _left(int index) => lines[index].qty - widget.payment.refundedQty(orderLineKey(lines[index], index));

  Future<void> _submit() async {
    final index = picked;
    if (index == null) return;
    if (reason.text.trim().isEmpty) {
      setState(() => error = context.l10n.voidReasonRequired);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final failure = await widget.store.refundLine(widget.payment, orderLineKey(lines[index], index), qty, reason.text);
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      busy = false;
      error = context.l10n.errorText(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = widget.store;
    final index = picked;
    final amount = index == null ? 0.0 : refundAmount(widget.payment, lines, lines[index], qty);
    return AlertDialog(
      title: Text(l10n.refundTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.salesReceiptLine(store.receiptNumber(widget.payment))}  ·  ${store.currency.format(widget.payment.netTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(l10n.refundMessage, style: const TextStyle(color: CafeColors.inkMuted, height: 1.45)),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: picked,
                onChanged: (value) => setState(() {
                  picked = value;
                  qty = 1;
                }),
                child: Column(
                  children: [
                    for (var i = 0; i < lines.length; i++)
                      RadioListTile<int>(
                        value: i,
                        enabled: !busy && _left(i) > 0,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${lines[i].qty}× ${lines[i].name}'),
                        subtitle: Text(l10n.refundLeft(_left(i))),
                      ),
                  ],
                ),
              ),
              if (index != null)
                Row(
                  children: [
                    IconButton(
                      tooltip: '−',
                      onPressed: busy || qty <= 1 ? null : () => setState(() => qty--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      tooltip: '+',
                      onPressed: busy || qty >= _left(index) ? null : () => setState(() => qty++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    Text(l10n.refundAmount(store.currency.format(amount)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              TextField(
                controller: reason,
                maxLength: 200,
                enabled: !busy,
                decoration: InputDecoration(labelText: l10n.voidReasonLabel, errorText: error),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: busy || index == null ? null : _submit,
          style: CafeButtons.destructiveFilled,
          child: Text(l10n.refundConfirm),
        ),
      ],
    );
  }
}
