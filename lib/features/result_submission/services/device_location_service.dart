import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_snapshot.dart';

enum LocationServiceStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

/// Service handling real device GPS location acquisition and permissions (Section 3 & 4).
class DeviceLocationService {
  DeviceLocationService();

  /// Configurable maximum allowed accuracy in meters (Section 27).
  static const double maxAllowedAccuracyMeters = 25.0;

  /// Global in-memory cached location snapshot.
  static LocationSnapshot? cachedLocation;

  /// Proactively requests Camera and Location permissions and warms up the GPS cache.
  static Future<void> warmUpPermissionsAndLocation() async {
    try {
      // 1. Warm up camera hardware/permission
      await availableCameras();
    } catch (_) {}

    try {
      // 2. Warm up location permission & seed cache
      final service = DeviceLocationService();
      await service.requestPermission();
      await service.getCurrentLocation(allowCached: false);
    } catch (_) {}
  }

  /// Checks the current location service and permission state.
  Future<LocationServiceStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationServiceStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return LocationServiceStatus.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationServiceStatus.permissionDeniedForever;
    }

    return LocationServiceStatus.ready;
  }

  /// Explicitly requests location permission from the platform.
  Future<LocationServiceStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationServiceStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return LocationServiceStatus.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationServiceStatus.permissionDeniedForever;
    }

    return LocationServiceStatus.ready;
  }

  /// Opens the native system location settings.
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Opens the native platform application settings.
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Acquires real GPS coordinates from the device hardware (Section 2 & 26).
  /// When [allowCached] is true, returns recent cached location instantly.
  Future<LocationSnapshot> getCurrentLocation({bool allowCached = true}) async {
    if (allowCached && cachedLocation != null && cachedLocation!.isAccurate) {
      final age = DateTime.now().difference(cachedLocation!.capturedAt);
      if (age < const Duration(minutes: 30)) {
        return cachedLocation!;
      }
    }

    final status = await checkStatus();
    if (status != LocationServiceStatus.ready) {
      final reqStatus = await requestPermission();
      if (reqStatus != LocationServiceStatus.ready) {
        if (cachedLocation != null) return cachedLocation!;
        throw LocationException(
          _statusToMessage(reqStatus),
          status: reqStatus,
        );
      }
    }

    // Try last known position first (instantaneous from device GPS subsystem)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && lastKnown.accuracy <= maxAllowedAccuracyMeters) {
        final snapshot = LocationSnapshot(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          accuracyMeters: lastKnown.accuracy,
          capturedAt: lastKnown.timestamp,
          isMock: lastKnown.isMocked,
        );
        cachedLocation = snapshot;
        final age = DateTime.now().difference(lastKnown.timestamp);
        if (age < const Duration(minutes: 10)) {
          return snapshot;
        }
      }
    } catch (_) {}

    // Quick GPS lock with 4-second timeout to prevent UI freezes
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );

      final snapshot = LocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
        isMock: position.isMocked,
      );
      cachedLocation = snapshot;
      return snapshot;
    } catch (e) {
      if (cachedLocation != null) return cachedLocation!;
      throw LocationException(
        'Unable to acquire a real GPS fix. Move to an area with location coverage and try again.',
        status: LocationServiceStatus.error,
      );
    }
  }

  String _statusToMessage(LocationServiceStatus status) {
    switch (status) {
      case LocationServiceStatus.serviceDisabled:
        return 'Location Services are turned off on your device.';
      case LocationServiceStatus.permissionDenied:
        return 'Location permission was denied.';
      case LocationServiceStatus.permissionDeniedForever:
        return 'Location permission is permanently denied. Please enable it in Settings.';
      case LocationServiceStatus.error:
        return 'Unable to acquire satellite location.';
      case LocationServiceStatus.ready:
        return 'Location service ready.';
    }
  }
}

class LocationException implements Exception {
  LocationException(this.message, {this.status});
  final String message;
  final LocationServiceStatus? status;

  @override
  String toString() => message;
}
