part of '../cashier_screens.dart';

/// Header button that opens the alert sound settings of this till.
class SoundSettingsButton extends StatelessWidget {
  const SoundSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AlertSoundSettings.instance..load();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => HeaderAction(
        icon: settings.all ? Icons.volume_up : Icons.volume_off,
        tooltip: context.l10n.soundSettingsTitle,
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _SoundSettingsDialog()),
      ),
    );
  }
}

class _SoundSettingsDialog extends StatelessWidget {
  const _SoundSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = AlertSoundSettings.instance;
    return AlertDialog(
      title: Text(l10n.soundSettingsTitle),
      content: SizedBox(
        width: 380,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(l10n.soundSettingsAll, style: const TextStyle(fontWeight: FontWeight.w800)),
                value: settings.all,
                onChanged: settings.setAll,
              ),
              const Divider(),
              for (final (kind, label) in [
                (AlertKind.order, l10n.soundSettingsOrders),
                (AlertKind.call, l10n.soundSettingsCalls),
                (AlertKind.bill, l10n.soundSettingsBills),
              ])
                SwitchListTile(
                  title: Text(label),
                  secondary: IconButton(
                    tooltip: label,
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => playAlertSound(kind),
                  ),
                  value: settings.isOn(kind),
                  onChanged: settings.all ? (value) => settings.setKind(kind, value) : null,
                ),
              const SizedBox(height: 8),
              Text(l10n.soundSettingsHint, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.waiterClose))],
    );
  }
}
