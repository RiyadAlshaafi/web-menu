import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';

/// Asks for a reason and voids [payment]. True when the sale was voided.
Future<bool> showVoidSaleDialog(
  BuildContext context,
  CafeStore store,
  Payment payment,
) async {
  final voided = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (context) => _VoidSaleDialog(store: store, payment: payment),
  );
  if (voided == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.voidDone)));
  }
  return voided == true;
}

class _VoidSaleDialog extends StatefulWidget {
  const _VoidSaleDialog({required this.store, required this.payment});

  final CafeStore store;
  final Payment payment;

  @override
  State<_VoidSaleDialog> createState() => _VoidSaleDialogState();
}

class _VoidSaleDialogState extends State<_VoidSaleDialog> {
  final reason = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (reason.text.trim().isEmpty) {
      setState(() => error = context.l10n.voidReasonRequired);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final failure = await widget.store.voidPayment(widget.payment, reason.text);
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.block, color: CafeColors.alert, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.voidSaleTitle,
                      style: CafeTheme.display.copyWith(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonCancel,
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.salesReceiptLine(store.receiptNumber(widget.payment))}  ·  '
                '${store.currency.format(widget.payment.totalDue)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.voidSaleMessage,
                style: const TextStyle(
                  color: CafeColors.inkMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reason,
                autofocus: true,
                maxLength: 200,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.voidReasonLabel,
                  hintText: l10n.voidReasonHint,
                  errorText: error,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ).merge(CafeButtons.destructiveFilled),
                    child: Text(l10n.voidConfirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
