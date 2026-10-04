import 'package:flutter/material.dart';
import '../../../../core/services/vercel_api_client.dart';
import '../../models/user_role.dart';
import '../../services/admin_account_service.dart';
import '../../services/admin_management_service.dart';

class AdminAccountAssignmentScreen extends StatefulWidget {
  const AdminAccountAssignmentScreen({super.key, required this.account});
  final Map<String, dynamic> account;
  @override
  State<AdminAccountAssignmentScreen> createState() => _AdminAccountAssignmentScreenState();
}

class _AdminAccountAssignmentScreenState extends State<AdminAccountAssignmentScreen> {
  final _lookups = AdminAccountService();
  final _service = AdminManagementService();
  late UserRole _role = UserRole.values.firstWhere((value) => value.code == widget.account['role'], orElse: () => UserRole.pollingUnitStaff);
  List<GeographyOption> _states = [], _lgas = [], _wards = [], _units = [];
  String? _state, _lga, _ward, _unit;
  bool _loading = true, _saving = false;
  String? _error;
  bool get _needsLga => _role == UserRole.lgaAdmin || _role == UserRole.wardAdmin || _role == UserRole.pollingUnitStaff;
  bool get _needsWard => _role == UserRole.wardAdmin || _role == UserRole.pollingUnitStaff;
  bool get _needsUnit => _role == UserRole.pollingUnitStaff;

  @override
  void initState() { super.initState(); _state = widget.account['state_code'] as String?; _lga = widget.account['lga_code'] as String?; _ward = widget.account['ward_code'] as String?; _unit = widget.account['polling_unit_code'] as String?; _loadOptions(); }

  Future<void> _loadOptions() async {
    try {
      _states = await _lookups.getGeography(level: 'states');
      if (_state != null) _lgas = await _lookups.getGeography(level: 'lgas', stateCode: _state);
      if (_state != null && _lga != null) _wards = await _lookups.getGeography(level: 'wards', stateCode: _state, lgaCode: _lga);
      if (_state != null && _lga != null && _ward != null) _units = await _lookups.getGeography(level: 'polling_units', stateCode: _state, lgaCode: _lga, wardCode: _ward);
      if (mounted) setState(() => _loading = false);
    } catch (error) { if (mounted) setState(() { _error = _message(error); _loading = false; }); }
  }

  String _message(Object error) => error is VercelApiException ? error.message : 'Unable to load or update this account.';

  Future<void> _save() async {
    if (_state == null || (_needsLga && _lga == null) || (_needsWard && _ward == null) || (_needsUnit && _unit == null)) { setState(() => _error = 'Choose every location required for this role.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final newUserId = await _service.assignAccount(widget.account['auth_user_id'] as String, role: _role.code, stateCode: _state!, lgaCode: _needsLga ? _lga : null, wardCode: _needsWard ? _ward : null, pollingUnitCode: _needsUnit ? _unit : null);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Assignment updated'), content: Text('New User ID: $newUserId\nThe account must sign in again and change its password.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) { if (mounted) setState(() { _error = _message(error); _saving = false; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change account assignment')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: ListView(padding: const EdgeInsets.all(24), children: [
      Text(widget.account['full_name'] as String? ?? '', style: Theme.of(context).textTheme.titleLarge),
      Text(widget.account['user_id'] as String? ?? '', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 20),
      DropdownButtonFormField<UserRole>(value: _role, decoration: const InputDecoration(labelText: 'Role'), items: UserRole.values.where((role) => role != UserRole.superAdmin).map((role) => DropdownMenuItem(value: role, child: Text(role.displayName))).toList(), onChanged: _saving ? null : (value) { if (value != null) setState(() { _role = value; _lga = null; _ward = null; _unit = null; }); }),
      const SizedBox(height: 12),
      _select('State / FCT', _states, _state, (value) async { if (value == null) return; setState(() { _state = value; _lga = null; _ward = null; _unit = null; _lgas = []; _wards = []; _units = []; }); try { final rows = await _lookups.getGeography(level: 'lgas', stateCode: value); if (mounted) setState(() => _lgas = rows); } catch (error) { if (mounted) setState(() => _error = _message(error)); } }),
      if (_needsLga) _select('LGA', _lgas, _lga, (value) async { if (value == null) return; setState(() { _lga = value; _ward = null; _unit = null; _wards = []; _units = []; }); try { final rows = await _lookups.getGeography(level: 'wards', stateCode: _state, lgaCode: value); if (mounted) setState(() => _wards = rows); } catch (error) { if (mounted) setState(() => _error = _message(error)); } }),
      if (_needsWard) _select('Ward', _wards, _ward, (value) async { if (value == null) return; setState(() { _ward = value; _unit = null; _units = []; }); try { final rows = await _lookups.getGeography(level: 'polling_units', stateCode: _state, lgaCode: _lga, wardCode: value); if (mounted) setState(() => _units = rows); } catch (error) { if (mounted) setState(() => _error = _message(error)); } }),
      if (_needsUnit) _select('Polling unit', _units, _unit, (value) => setState(() => _unit = value)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save assignment')),
    ]))),
  );

  Widget _select(String label, List<GeographyOption> choices, String? value, ValueChanged<String?> changed) => Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(value: choices.any((item) => item.code == value) ? value : null, decoration: InputDecoration(labelText: label), items: choices.map((item) => DropdownMenuItem(value: item.code, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: _saving || choices.isEmpty ? null : changed));
}
