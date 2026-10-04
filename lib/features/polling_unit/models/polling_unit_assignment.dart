// lib/features/polling_unit/models/polling_unit_assignment.dart

/// Data model representing a Polling Unit staff member's active assignment.
class PollingUnitAssignment {
  const PollingUnitAssignment({
    required this.pollingUnitId,
    required this.pollingUnitName,
    required this.ward,
    required this.lga,
    required this.state,
    this.location,
    this.delimitationCode,
  });

  /// Primary identifier, e.g. "PU 0047"
  final String pollingUnitId;

  /// Specific polling-unit facility name, e.g. "Gwarinpa Primary School"
  final String pollingUnitName;

  /// Ward information, e.g. "Ward 03"
  final String ward;

  /// Local Government Area, e.g. "AMAC"
  final String lga;

  /// State or Federal Capital Territory, e.g. "FCT"
  final String state;

  /// Optional descriptive location or landmark
  final String? location;

  /// Full administrative delimitation string if available
  final String? delimitationCode;

  /// Formatted ward and LGA line, e.g. "Ward 03 · AMAC"
  String get wardAndLga => '$ward · $lga';

  PollingUnitAssignment copyWith({
    String? pollingUnitId,
    String? pollingUnitName,
    String? ward,
    String? lga,
    String? state,
    String? location,
    String? delimitationCode,
  }) {
    return PollingUnitAssignment(
      pollingUnitId: pollingUnitId ?? this.pollingUnitId,
      pollingUnitName: pollingUnitName ?? this.pollingUnitName,
      ward: ward ?? this.ward,
      lga: lga ?? this.lga,
      state: state ?? this.state,
      location: location ?? this.location,
      delimitationCode: delimitationCode ?? this.delimitationCode,
    );
  }
}
