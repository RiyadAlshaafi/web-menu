import 'package:geolocator/geolocator.dart';

import 'report_error.dart';

class DevicePoint {
  const DevicePoint({required this.latitude, required this.longitude, required this.accuracyM});

  final double latitude;
  final double longitude;
  final double accuracyM;
}

enum DeviceLocationFailure { denied, unavailable }

class DeviceLocationException implements Exception {
  DeviceLocationException(this.failure);

  final DeviceLocationFailure failure;

  @override
  String toString() => failure == DeviceLocationFailure.denied ? 'location denied' : 'location unavailable';
}

Future<DevicePoint> readDeviceLocation() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw DeviceLocationException(DeviceLocationFailure.unavailable);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw DeviceLocationException(DeviceLocationFailure.denied);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return DevicePoint(latitude: position.latitude, longitude: position.longitude, accuracyM: position.accuracy);
  } on DeviceLocationException {
    rethrow;
  } catch (_, stackTrace) {
    reportError('device location', 'read failed', stackTrace);
    throw DeviceLocationException(DeviceLocationFailure.unavailable);
  }
}
