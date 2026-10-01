part of 'cafe_store.dart';

extension CafeStoreLocation on CafeStore {
  void _clearGuestPoint() {
    _guestLat = null;
    _guestLng = null;
    _guestAccuracyM = null;
    _guestNearUntil = null;
  }

  Future<void> refreshGuestLocation(String qrSlug, {bool force = false}) async {
    if (authKind != AuthKind.none) {
      _clearGuestPoint();
      guestLocation = GuestLocationStatus.off;
      return;
    }
    if (_guestLocationBusy) return;
    final cached = guestLocation == GuestLocationStatus.allowed &&
        _guestNearUntil != null &&
        DateTime.now().isBefore(_guestNearUntil!) &&
        _guestLat != null &&
        _guestLng != null;
    if (!force && cached) return;
    if (!force && _guestLocationStarted && guestLocation != GuestLocationStatus.off) return;
    _guestLocationBusy = true;
    _guestLocationStarted = true;

    Map<String, dynamic> rule;
    try {
      rule = await db.guestLocationRule(qrSlug);
    } catch (_, stackTrace) {
      reportError('guest location rule', 'lookup failed', stackTrace);
      _clearGuestPoint();
      guestLocation = GuestLocationStatus.off;
      _guestLocationBusy = false;
      notifyListeners();
      return;
    }
    if (rule['enabled'] != true) {
      _clearGuestPoint();
      guestLocation = GuestLocationStatus.off;
      _guestLocationBusy = false;
      notifyListeners();
      return;
    }

    guestLocation = GuestLocationStatus.checking;
    notifyListeners();
    try {
      final point = await readDeviceLocation();
      final checked = await db.guestLocationRule(
        qrSlug,
        lat: point.latitude,
        lng: point.longitude,
        accuracyM: point.accuracyM,
      );
      final status = checked['status'] as String? ?? '';
      if (status == 'too_far') {
        _clearGuestPoint();
        guestLocation = GuestLocationStatus.tooFar;
      } else if (status == 'allowed') {
        _guestLat = point.latitude;
        _guestLng = point.longitude;
        _guestAccuracyM = point.accuracyM;
        _guestNearUntil = DateTime.now().add(const Duration(minutes: 10));
        guestLocation = GuestLocationStatus.allowed;
      } else {
        _clearGuestPoint();
        guestLocation = GuestLocationStatus.unavailable;
      }
    } on DeviceLocationException catch (error) {
      _clearGuestPoint();
      guestLocation = error.failure == DeviceLocationFailure.denied
          ? GuestLocationStatus.denied
          : GuestLocationStatus.unavailable;
    } catch (_, stackTrace) {
      reportError('guest location', 'check failed', stackTrace);
      _clearGuestPoint();
      guestLocation = GuestLocationStatus.unavailable;
    }
    _guestLocationBusy = false;
    notifyListeners();
  }

  Future<String?> prepareGuestOrderLocation(String qrSlug) async {
    if (authKind != AuthKind.none || guestLocation == GuestLocationStatus.off) return null;
    final fresh = guestLocation == GuestLocationStatus.allowed &&
        _guestNearUntil != null &&
        DateTime.now().isBefore(_guestNearUntil!) &&
        _guestLat != null &&
        _guestLng != null;
    if (!fresh) await refreshGuestLocation(qrSlug, force: true);
    if (canPlaceOrder) return null;
    return switch (guestLocation) {
      GuestLocationStatus.tooFar => 'too_far',
      GuestLocationStatus.denied => 'location_required',
      _ => 'location_required',
    };
  }

  Future<({bool enabled, double? lat, double? lng, int radiusM})?> loadCafeLocation() => db.readCafeLocation();

  Future<String?> saveCafeLocation({required bool enabled, double? lat, double? lng, required int radiusM}) {
    return db.writeCafeLocation(enabled: enabled, lat: lat, lng: lng, radiusM: radiusM);
  }
}
