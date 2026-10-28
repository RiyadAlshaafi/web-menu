import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// What the phone is alerting the waiter to; each has its own tone.
enum WaiterTone { ready, call, bill }

/// Plays [tone] out loud. Swapped for a recorder in tests.
typedef TonePlayer = Future<void> Function(WaiterTone tone);

const _sampleRate = 22050;

/// Beep pitch, length and start time (seconds) of each beep in a tone.
List<({double hz, double length, double at})> _beeps(WaiterTone tone) => switch (tone) {
  WaiterTone.ready => const [(hz: 784.0, length: 0.16, at: 0.0), (hz: 1175.0, length: 0.28, at: 0.2)],
  WaiterTone.call => const [
    (hz: 880.0, length: 0.2, at: 0.0),
    (hz: 880.0, length: 0.2, at: 0.3),
    (hz: 880.0, length: 0.2, at: 0.6),
  ],
  WaiterTone.bill => const [
    (hz: 1047.0, length: 0.12, at: 0.0),
    (hz: 1047.0, length: 0.12, at: 0.16),
    (hz: 1319.0, length: 0.3, at: 0.32),
  ],
};

/// A small WAV file made in memory, so the app ships no sound files.
Uint8List toneWav(WaiterTone tone) {
  final beeps = _beeps(tone);
  final seconds = beeps.map((b) => b.at + b.length).reduce(max) + 0.05;
  final samples = (seconds * _sampleRate).ceil();
  final data = ByteData(44 + samples * 2);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final t = i / _sampleRate;
    var value = 0.0;
    for (final beep in beeps) {
      final local = t - beep.at;
      if (local < 0 || local > beep.length) continue;
      // Quick fade in and out, so a beep never clicks.
      final edge = min(min(local, beep.length - local) / 0.012, 1.0);
      value += sin(2 * pi * beep.hz * local) * edge * 0.7;
    }
    data.setInt16(44 + i * 2, (value.clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

AudioPlayer? _player;

/// The real speaker. A phone without sound still shows the alert, so a failure is swallowed.
Future<void> playWaiterTone(WaiterTone tone) async {
  try {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(BytesSource(toneWav(tone), mimeType: 'audio/wav'));
  } catch (_) {
    // No audio output.
  }
}
