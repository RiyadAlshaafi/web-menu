import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/report_error.dart';
import '../l10n/l10n_ext.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/tawla_ui.dart';

/// The service charge percent added to dine-in bills. Shown when the setup ticked "Service charge".
class ServiceChargeCard extends StatefulWidget {
  const ServiceChargeCard({super.key});

  /// Highest percent the admin may set; anything above is a typo.
  static const maxPercent = 30;

  @override
  State<ServiceChargeCard> createState() => _ServiceChargeCardState();
}

class _ServiceChargeCardState extends State<ServiceChargeCard> {
  late final TextEditingController _percent = TextEditingController(
    text: _format(context.read<CafeStore>().savedServiceChargeRate * 100),
  );
  var _saving = false;

  static String _format(double percent) =>
      percent == percent.roundToDouble() ? '${percent.round()}' : percent.toStringAsFixed(1);

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save(CafeStore store) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final percent = double.tryParse(_percent.text.trim().replaceAll(',', '.'));
    if (percent == null || percent < 0 || percent > ServiceChargeCard.maxPercent) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.serviceChargeInvalid('${ServiceChargeCard.maxPercent}'))));
      return;
    }
    setState(() => _saving = true);
    String message;
    try {
      // restaurants.service_charge_rate keeps 4 decimals; save exactly that so till and server agree.
      await store.setServiceChargeRate((percent * 100).round() / 10000);
      message = l10n.serviceChargeSaved;
    } on Exception catch (error, stackTrace) {
      reportError('service charge', error, stackTrace);
      message = l10n.serviceChargeSaveFailed;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<CafeStore>();
    final l10n = context.l10n;
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(l10n.serviceChargeTitle, size: 18),
          const SizedBox(height: 6),
          Text(l10n.serviceChargeHint, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _percent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: l10n.serviceChargePercent, suffixText: '%'),
                  onSubmitted: (_) => _save(store),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saving ? null : () => _save(store),
                style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                child: Text(l10n.serviceChargeSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
