import 'package:web/web.dart';

import 'alert_sound.dart';

AudioContext? _audio;

/// Short beeps made in the browser, so no sound file has to be downloaded.
/// Order: two mid beeps. Call: one long low beep. Bill: three quick high beeps.
void playAlert(AlertKind kind) {
  final (pitch, length, offsets) = switch (kind) {
    AlertKind.order => (880.0, 0.15, const [0.0, 0.18]),
    AlertKind.call => (587.0, 0.45, const [0.0]),
    AlertKind.bill => (1175.0, 0.1, const [0.0, 0.14, 0.28]),
  };
  final audio = _audio ??= AudioContext();
  final start = audio.currentTime;
  for (final offset in offsets) {
    final tone = audio.createOscillator()
      ..type = 'sine'
      ..frequency.value = pitch;
    final volume = audio.createGain();
    volume.gain.setValueAtTime(0.2, start + offset);
    volume.gain.exponentialRampToValueAtTime(0.001, start + offset + length);
    tone.connect(volume);
    volume.connect(audio.destination);
    tone.start(start + offset);
    tone.stop(start + offset + length);
  }
}
