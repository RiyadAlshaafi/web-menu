import 'package:flutter/services.dart';

/// The system's alert sound (Windows "Asterisk" on the desktop till).
void playAlert() => SystemSound.play(SystemSoundType.alert);
