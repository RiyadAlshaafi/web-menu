import 'package:web/web.dart';

AudioContext? _audio;

/// Two short beeps made in the browser, so no sound file has to be downloaded.
void playAlert() {
  final audio = _audio ??= AudioContext();
  final start = audio.currentTime;
  for (final offset in const [0.0, 0.18]) {
    final tone = audio.createOscillator()
      ..type = 'sine'
      ..frequency.value = 880;
    final volume = audio.createGain();
    volume.gain.setValueAtTime(0.2, start + offset);
    volume.gain.exponentialRampToValueAtTime(0.001, start + offset + 0.15);
    tone.connect(volume);
    volume.connect(audio.destination);
    tone.start(start + offset);
    tone.stop(start + offset + 0.15);
  }
}
