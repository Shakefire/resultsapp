// lib/features/result_submission/models/location_snapshot.dart

/// Represents a real GPS location acquisition captured from the device.
class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    this.isMock = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final bool isMock;

  /// High precision readable coordinate strings
  String get latitudeFormatted => latitude.toStringAsFixed(5);
  String get longitudeFormatted => longitude.toStringAsFixed(5);
  String get accuracyFormatted => '±${accuracyMeters.toStringAsFixed(0)} m';

  /// Whether GPS accuracy meets the acceptable operational threshold (e.g. <= 25 meters).
  bool get isAccurate => accuracyMeters <= 25.0;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'capturedAt': capturedAt.toIso8601String(),
      'isMock': isMock,
    };
  }

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) {
    return LocationSnapshot(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      isMock: json['isMock'] as bool? ?? false,
    );
  }
}
