import 'package:flutter/services.dart';

import 'alert_sound.dart';

/// The system's alert sound (Windows "Asterisk" on the desktop till), the same for every kind.
void playAlert(AlertKind kind) => SystemSound.play(SystemSoundType.alert);
