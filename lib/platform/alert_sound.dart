import 'alert_sound_settings.dart';
import 'alert_sound_io.dart' if (dart.library.js_interop) 'alert_sound_web.dart' as impl;

/// What the cashier is being alerted to; each has its own tone in the browser.
enum AlertKind { order, call, bill }

/// A short sound for a new guest order, staff call or bill request. Never throws: a till
/// without sound still shows the alert on screen.
void playAlertSound(AlertKind kind) {
  final settings = AlertSoundSettings.instance..load();
  if (!settings.plays(kind)) return;
  try {
    impl.playAlert(kind);
  } catch (_) {
    // No audio device, or the browser blocked sound before the first click.
  }
}
