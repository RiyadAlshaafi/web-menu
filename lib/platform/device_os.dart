import 'device_os_io.dart' if (dart.library.js_interop) 'device_os_web.dart' as impl;

/// True on an Android phone or tablet (a waiter device). Reads the real operating system, so a
/// Windows or Linux test run is never mistaken for one.
bool get isAndroidDevice => impl.isAndroidDevice;
