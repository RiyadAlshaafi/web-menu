import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../theme/cafe_theme.dart';

Future<bool> showCafeConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? cancel,
  String? confirm,
}) async {
  final cancelLabel = cancel ?? context.l10n.commonCancel;
  final confirmLabel = confirm ?? context.l10n.commonDelete;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0x99FFDAD6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: CafeColors.alert, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: CafeTheme.display.copyWith(fontSize: 20))),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CafeColors.key,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x4DDDC0B8)),
                  ),
                  child: Text(message, style: const TextStyle(color: CafeColors.inkMuted, height: 1.45)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(cancelLabel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ).merge(CafeButtons.destructiveFilled),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}
