// lib/features/authentication/presentation/widgets/location_selector.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/user_role.dart';
import '../../../../data/mock/location_mock_data.dart';

/// Cascading location selector that adapts to the selected role.
/// Structure is separated from mock data — replace MockLocationRepository
/// with ApiLocationRepository to connect real API.
class LocationSelector extends StatefulWidget {
  const LocationSelector({
    super.key,
    required this.role,
    required this.onLocationChanged,
    this.enabled = true,
  });

  final UserRole role;

  /// Called whenever any location field changes.
  final void Function({
    String? stateId,
    String? stateName,
    String? lgaId,
    String? lgaName,
    String? wardId,
    String? wardName,
    String? pollingUnitId,
    String? pollingUnitName,
  }) onLocationChanged;

  final bool enabled;

  @override
  State<LocationSelector> createState() => LocationSelectorState();
}

class LocationSelectorState extends State<LocationSelector> {
  final _repo = MockLocationRepository();

  String? _stateId;
  String? _stateName;
  String? _lgaId;
  String? _lgaName;
  String? _wardId;
  String? _wardName;
  String? _pollingUnitId;
  String? _pollingUnitName;

  // Derived lists
  late List<LocationState> _states;
  List<LocationLga> _lgas = [];
  List<LocationWard> _wards = [];
  List<LocationPollingUnit> _pollingUnits = [];

  @override
  void initState() {
    super.initState();
    _states = _repo.getStates();
  }

  /// Whether the LGA field is shown for the current role.
  bool get _showLga =>
      widget.role == UserRole.lgaAdmin ||
      widget.role == UserRole.wardAdmin ||
      widget.role == UserRole.pollingUnitStaff;

  /// Whether the Ward field is shown for the current role.
  bool get _showWard =>
      widget.role == UserRole.wardAdmin ||
      widget.role == UserRole.pollingUnitStaff;

  /// Whether the Polling Unit field is shown.
  bool get _showPollingUnit => widget.role == UserRole.pollingUnitStaff;

  void _onStateChanged(String? id) {
    final name = _states.firstWhere((s) => s.id == id).name;
    setState(() {
      _stateId = id;
      _stateName = name;
      _lgaId = null;
      _lgaName = null;
      _wardId = null;
      _wardName = null;
      _pollingUnitId = null;
      _pollingUnitName = null;
      _lgas = id != null ? _repo.getLgas(id) : [];
      _wards = [];
      _pollingUnits = [];
    });
    _notifyChanged();
  }

  void _onLgaChanged(String? id) {
    final name = _lgas.firstWhere((l) => l.id == id).name;
    setState(() {
      _lgaId = id;
      _lgaName = name;
      _wardId = null;
      _wardName = null;
      _pollingUnitId = null;
      _pollingUnitName = null;
      _wards = id != null ? _repo.getWards(id) : [];
      _pollingUnits = [];
    });
    _notifyChanged();
  }

  void _onWardChanged(String? id) {
    final name = _wards.firstWhere((w) => w.id == id).name;
    setState(() {
      _wardId = id;
      _wardName = name;
      _pollingUnitId = null;
      _pollingUnitName = null;
      _pollingUnits = id != null ? _repo.getPollingUnits(id) : [];
    });
    _notifyChanged();
  }

  void _onPollingUnitChanged(String? id) {
    final name = _pollingUnits.firstWhere((p) => p.id == id).name;
    setState(() {
      _pollingUnitId = id;
      _pollingUnitName = name;
    });
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onLocationChanged(
      stateId: _stateId,
      stateName: _stateName,
      lgaId: _lgaId,
      lgaName: _lgaName,
      wardId: _wardId,
      wardName: _wardName,
      pollingUnitId: _pollingUnitId,
      pollingUnitName: _pollingUnitName,
    );
  }

  /// Validates that all required location fields are selected.
  String? validate() {
    if (_stateId == null) return 'Please select your state.';
    if (_showLga && _lgaId == null) return 'Please select your LGA.';
    if (_showWard && _wardId == null) return 'Please select your ward.';
    if (_showPollingUnit && _pollingUnitId == null) {
      return 'Please select your polling unit.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // State
        _LocationDropdown(
          label: 'STATE',
          hint: 'Select state',
          value: _stateId,
          items: _states
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
              .toList(),
          onChanged: widget.enabled ? _onStateChanged : null,
        ),

        if (_showLga) ...[
          const SizedBox(height: AppSpacing.fieldGap),
          _LocationDropdown(
            label: 'LGA',
            hint: _stateId == null ? 'Select state first' : 'Select LGA',
            value: _lgaId,
            items: _lgas
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (widget.enabled && _stateId != null) ? _onLgaChanged : null,
            disabled: _stateId == null,
          ),
        ],

        if (_showWard) ...[
          const SizedBox(height: AppSpacing.fieldGap),
          _LocationDropdown(
            label: 'WARD',
            hint: _lgaId == null ? 'Select LGA first' : 'Select ward',
            value: _wardId,
            items: _wards
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (widget.enabled && _lgaId != null) ? _onWardChanged : null,
            disabled: _lgaId == null,
          ),
        ],

        if (_showPollingUnit) ...[
          const SizedBox(height: AppSpacing.fieldGap),
          _LocationDropdown(
            label: 'POLLING UNIT',
            hint: _wardId == null ? 'Select ward first' : 'Select polling unit',
            value: _pollingUnitId,
            items: _pollingUnits
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: (widget.enabled && _wardId != null) ? _onPollingUnitChanged : null,
            disabled: _wardId == null,
          ),
        ],
      ],
    );
  }
}

/// Internal reusable dropdown row for location fields.
class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.disabled = false,
  });

  final String label;
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.inputLabel()),
        const SizedBox(height: AppSpacing.xs + 2),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          style: AppTextStyles.inputText(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputText(color: AppColors.textPlaceholder),
            prefixIcon: const IconTheme(
              data: IconThemeData(color: AppColors.textSecondary, size: 20),
              child: Icon(Icons.location_on_outlined),
            ),
            filled: true,
            fillColor: disabled ? AppColors.background : AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle: AppTextStyles.errorText(),
          ),
          items: items,
        ),
      ],
    );
  }
}
