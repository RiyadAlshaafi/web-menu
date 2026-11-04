import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Windows till window: it opens full screen, and the top bar's button switches it to a
/// normal window and back (a touch till has no F11 key). Other platforms have no such window.
class AppWindow extends ChangeNotifier {
  AppWindow._();

  static final instance = AppWindow._();

  static const _channel = MethodChannel('cafe_pos/window');

  /// Tests set this to lay out the button on a platform that has no till window.
  @visibleForTesting
  static bool? debugSupported;

  /// True on the Windows desktop app.
  bool get supported => debugSupported ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  /// The runner opens the window full screen.
  bool _fullscreen = true;
  bool get fullscreen => _fullscreen;

  bool _loaded = false;

  /// Reads the window's state once, in case it was started as a normal window.
  Future<void> load() async {
    if (_loaded || !supported) return;
    _loaded = true;
    try {
      final value = await _channel.invokeMethod<bool>('isFullscreen');
      if (value != null) _setFullscreen(value);
    } on PlatformException catch (error) {
      debugPrint('Could not read the window state: ${error.message}');
    } on MissingPluginException {
      // A runner built before the full-screen switch: keep the default.
    }
  }

  Future<void> toggle() async {
    if (!supported) return;
    try {
      final value = await _channel.invokeMethod<bool>('setFullscreen', !_fullscreen);
      _setFullscreen(value ?? !_fullscreen);
    } on PlatformException catch (error) {
      debugPrint('Could not switch full screen: ${error.message}');
    } on MissingPluginException {
      debugPrint('This build of the app cannot switch full screen.');
    }
  }

  void _setFullscreen(bool value) {
    if (value == _fullscreen) return;
    _fullscreen = value;
    notifyListeners();
  }
}
