import 'alert_sound_io.dart' if (dart.library.js_interop) 'alert_sound_web.dart' as impl;

/// A short sound for a new guest order. Never throws: a till without sound still shows the toast.
void playNewOrderSound() {
  try {
    impl.playAlert();
  } catch (_) {
    // No audio device, or the browser blocked sound before the first click.
  }
}
