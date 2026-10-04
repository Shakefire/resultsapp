import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/vercel_api_client.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/admin_account_service.dart';

/// Admin form for assigning a role and geographic scope to a new account.
/// Accessible to Super Admin and delegated provisioners (canProvisionUsers == true).
class AdminAccountProvisionScreen extends StatefulWidget {
  const AdminAccountProvisionScreen({super.key, this.service, this.actingUser});

  final AdminAccountService? service;

  /// The currently logged-in user. Used to lock geographic scope for
  /// delegated (non-super-admin) provisioners.
  final UserModel? actingUser;

  @override
  State<AdminAccountProvisionScreen> createState() =>
      _AdminAccountProvisionScreenState();
}

class _AdminAccountProvisionScreenState
    extends State<AdminAccountProvisionScreen> {
  late final AdminAccountService _service =
      widget.service ?? AdminAccountService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool get _isSuperAdmin => widget.actingUser?.role == UserRole.superAdmin;
  bool get _isStateAdminDelegated =>
      !_isSuperAdmin && widget.actingUser?.role == UserRole.stateAdmin;

  late final List<UserRole> _roles = _buildRoleList();

  List<UserRole> _buildRoleList() {
    final all = UserRole.values.where((r) => r != UserRole.superAdmin).toList();
    if (_isStateAdminDelegated) {
      // State Admin delegated: cannot create another state_admin
      return all.where((r) => r != UserRole.stateAdmin).toList();
    }
    if (widget.actingUser?.role == UserRole.lgaAdmin) {
      return [UserRole.wardAdmin, UserRole.pollingUnitStaff];
    }
    if (widget.actingUser?.role == UserRole.wardAdmin) {
      return [UserRole.pollingUnitStaff];
    }
    return all;
  }

  UserRole _role = UserRole.pollingUnitStaff;
  List<GeographyOption> _states = [];
  List<GeographyOption> _lgas = [];
  List<GeographyOption> _wards = [];
  List<GeographyOption> _pollingUnits = [];
  String? _state;
  String? _lga;
  String? _ward;
  String? _pollingUnit;
  bool _loadingStates = true;
  bool _loadingChildren = false;
  bool _saving = false;
  bool _grantProvisionPower = false;
  String? _error;
  ProvisionedAccount? _created;

  /// True when the selected role allows granting provision power and the
  /// acting user has authority to grant it.
  bool get _canGrantProvisionPower {
    if (_isSuperAdmin) {
      return _role == UserRole.stateAdmin || _role == UserRole.lgaAdmin || _role == UserRole.wardAdmin;
    }
    if (widget.actingUser?.role == UserRole.stateAdmin) {
      return _role == UserRole.lgaAdmin || _role == UserRole.wardAdmin;
    }
    if (widget.actingUser?.role == UserRole.lgaAdmin) {
      return _role == UserRole.wardAdmin;
    }
    return false;
  }

  bool get _usingCachedGeography => [
    ..._states,
    ..._lgas,
    ..._wards,
    ..._pollingUnits,
  ].any((option) => option.isFromCache);

  bool get _needsLga =>
      _role == UserRole.lgaAdmin ||
      _role == UserRole.wardAdmin ||
      _role == UserRole.pollingUnitStaff;
  bool get _needsWard =>
      _role == UserRole.wardAdmin || _role == UserRole.pollingUnitStaff;
  bool get _needsPollingUnit => _role == UserRole.pollingUnitStaff;

  @override
  void initState() {
    super.initState();
    _loadStates();
    // Pre-select and lock geographic scope for delegated (non-super) admins.
    if (!_isSuperAdmin) {
      final actorState = widget.actingUser?.stateId;
      if (actorState != null) {
        _state = actorState;
        _loadingStates = false; // Will be set properly after states load
      }
      if (widget.actingUser?.role == UserRole.lgaAdmin || widget.actingUser?.role == UserRole.wardAdmin) {
        final actorLga = widget.actingUser?.lgaId;
        if (actorLga != null) _lga = actorLga;
      }
      if (widget.actingUser?.role == UserRole.wardAdmin) {
        final actorWard = widget.actingUser?.wardId;
        if (actorWard != null) _ward = actorWard;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    try {
      final options = await _service.getGeography(level: 'states');
      if (mounted)
        setState(() {
          _states = options;
          _loadingStates = false;
          // After loading states, trigger LGA load if state is pre-locked
          if (_state != null && !_isSuperAdmin) {
            _loadLgas(_state!);
          }
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loadingStates = false;
        });
    }
  }

  String _message(Object error) => error is VercelApiException
      ? error.message
      : 'Could not load the assignment list. Check your connection and retry.';

  Future<void> _loadLgas(String stateCode) async {
    setState(() {
      _loadingChildren = true;
      _lgas = [];
      _wards = [];
      _pollingUnits = [];
      _lga = null;
      _ward = null;
      _pollingUnit = null;
      _error = null;
    });
    try {
      final options = await _service.getGeography(
        level: 'lgas',
        stateCode: stateCode,
      );
      if (mounted)
        setState(() {
          _lgas = options;
          _loadingChildren = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loadingChildren = false;
        });
    }
  }

  Future<void> _loadWards(String stateCode, String lgaCode) async {
    setState(() {
      _loadingChildren = true;
      _wards = [];
      _pollingUnits = [];
      _ward = null;
      _pollingUnit = null;
      _error = null;
    });
    try {
      final options = await _service.getGeography(
        level: 'wards',
        stateCode: stateCode,
        lgaCode: lgaCode,
      );
      if (mounted)
        setState(() {
          _wards = options;
          _loadingChildren = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loadingChildren = false;
        });
    }
  }

  Future<void> _loadPollingUnits(
    String stateCode,
    String lgaCode,
    String wardCode,
  ) async {
    setState(() {
      _loadingChildren = true;
      _pollingUnits = [];
      _pollingUnit = null;
      _error = null;
    });
    try {
      final options = await _service.getGeography(
        level: 'polling_units',
        stateCode: stateCode,
        lgaCode: lgaCode,
        wardCode: wardCode,
      );
      if (mounted)
        setState(() {
          _pollingUnits = options;
          _loadingChildren = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loadingChildren = false;
        });
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_state == null ||
        (_needsLga && _lga == null) ||
        (_needsWard && _ward == null) ||
        (_needsPollingUnit && _pollingUnit == null)) {
      setState(() => _error = 'Choose every location required for this role.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final account = await _service.createAccount(
        fullName: _nameController.text,
        role: _role,
        stateCode: _state!,
        lgaCode: _needsLga ? _lga : null,
        wardCode: _needsWard ? _ward : null,
        pollingUnitCode: _needsPollingUnit ? _pollingUnit : null,
        canProvisionUsers: _canGrantProvisionPower && _grantProvisionPower,
      );
      if (mounted)
        setState(() {
          _created = account;
          _saving = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _saving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Create account', style: AppTextStyles.sectionTitle()),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _created == null
                ? _buildForm()
                : _buildCredentials(_created!),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Provision a user', style: AppTextStyles.screenTitle()),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Assign the account’s role and operating area. The user ID and one-time password are generated after creation.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account details', style: AppTextStyles.sectionTitle()),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the user’s full name.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<UserRole>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (role) {
                        if (role != null)
                          setState(() {
                            _role = role;
                            _created = null;
                            _grantProvisionPower = false;
                          });
                      },
              ),
              if (_canGrantProvisionPower) ...[ 
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  value: _grantProvisionPower,
                  onChanged: _saving ? null : (v) => setState(() => _grantProvisionPower = v),
                  title: const Text('Grant account-creation power'),
                  subtitle: Text(
                    _role == UserRole.stateAdmin
                        ? 'This State Admin will be able to create accounts within their state.'
                        : 'This LGA Admin will be able to create accounts within their LGA.',
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                  ),
                  secondary: Icon(
                    Icons.supervisor_account_outlined,
                    color: _grantProvisionPower ? AppColors.primary : null,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Geographic assignment',
                style: AppTextStyles.sectionTitle(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _scopeDescription,
                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              // Lock state selection for delegated (non-super) admins
              if (!_isSuperAdmin && _state != null)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'State / FCT',
                    prefixIcon: Icon(Icons.map_outlined),
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                  child: Text(
                    _states.where((s) => s.code == _state).firstOrNull?.name ?? _state!,
                    style: AppTextStyles.body(),
                  ),
                )
              else
              _dropdown('State / FCT', _states, _state, _loadingStates, (
                value,
              ) {
                setState(() => _state = value);
                if (value != null) _loadLgas(value);
              }),
              if (_state != null &&
                  !_loadingChildren &&
                  _lgas.isEmpty &&
                  _needsLga)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'No active LGA records are loaded for this state in Supabase.',
                    style: AppTextStyles.bodySmall(color: AppColors.warning),
                  ),
                ),
              if (_needsLga) ...[
                const SizedBox(height: AppSpacing.md),
                _dropdown(
                  'LGA',
                  _lgas,
                  _lga,
                  _loadingChildren && _state != null,
                  (value) {
                    setState(() => _lga = value);
                    if (value != null && _state != null && _needsWard)
                      _loadWards(_state!, value);
                  },
                ),
              ],
              if (_needsWard) ...[
                const SizedBox(height: AppSpacing.md),
                _dropdown(
                  'Ward',
                  _wards,
                  _ward,
                  _loadingChildren && _lga != null,
                  (value) {
                    setState(() => _ward = value);
                    if (value != null &&
                        _state != null &&
                        _lga != null &&
                        _needsPollingUnit)
                      _loadPollingUnits(_state!, _lga!, value);
                  },
                ),
                if (_lga != null && !_loadingChildren && _wards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'No active ward records are loaded for this LGA in Supabase.',
                      style: AppTextStyles.bodySmall(color: AppColors.warning),
                    ),
                  ),
              ],
              if (_needsPollingUnit) ...[
                const SizedBox(height: AppSpacing.md),
                _dropdown(
                  'Polling unit',
                  _pollingUnits,
                  _pollingUnit,
                  _loadingChildren && _ward != null,
                  (value) => setState(() => _pollingUnit = value),
                ),
                if (_ward != null && !_loadingChildren && _pollingUnits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'No polling-unit directory is loaded for this ward yet.',
                      style: AppTextStyles.bodySmall(color: AppColors.warning),
                    ),
                  ),
              ],
              if (_usingCachedGeography)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'Showing saved geography from an earlier successful fetch. Account changes still require a live backend connection.',
                    style: AppTextStyles.bodySmall(color: AppColors.warning),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _notice(_error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _saving ||
                    _loadingStates ||
                    (_needsPollingUnit && _pollingUnits.isEmpty)
                ? null
                : _create,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: Text(_saving ? 'Creating account…' : 'Create account'),
          ),
        ),
      ],
    ),
  );

  String get _scopeDescription {
    if (_role == UserRole.stateAdmin)
      return 'State Admin can review the full state summary.';
    if (_role == UserRole.lgaAdmin)
      return 'LGA Admin can review and approve results in the selected LGA.';
    if (_role == UserRole.wardAdmin)
      return 'Ward Admin can review submissions in the selected ward.';
    return 'Polling Unit Staff can submit and view records for the selected polling unit.';
  }

  Widget _dropdown(
    String label,
    List<GeographyOption> options,
    String? value,
    bool loading,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: options.any((option) => option.code == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label.startsWith('State') ? Icons.map_outlined : Icons.place_outlined,
        ),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option.code,
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: loading || options.isEmpty || _saving ? null : onChanged,
      validator: (selected) => selected == null ? 'Choose $label.' : null,
    );
  }

  Widget _buildCredentials(ProvisionedAccount account) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.success, size: 40),
        const SizedBox(height: AppSpacing.md),
        Text('Account created', style: AppTextStyles.screenTitle()),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Share these credentials securely. The six-character temporary password must be changed at first sign-in.',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _credentialRow('User ID', account.userId),
        const SizedBox(height: AppSpacing.md),
        _credentialRow('Temporary password', account.temporaryPassword),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      'User ID: ${account.userId}\nTemporary password: ${account.temporaryPassword}',
                ),
              );
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied.')),
                );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy credentials'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              setState(() {
                _created = null;
                _nameController.clear();
                _role = UserRole.pollingUnitStaff;
                _state = null;
                _lga = null;
                _ward = null;
                _pollingUnit = null;
                _lgas = [];
                _wards = [];
                _pollingUnits = [];
              });
            },
            child: const Text('Create another account'),
          ),
        ),
      ],
    ),
  );

  Widget _credentialRow(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption()),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: AppTextStyles.body().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
      ],
    ),
  );

  Widget _notice(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
    ),
    child: Text(
      message,
      style: AppTextStyles.bodySmall(color: AppColors.warning),
    ),
  );

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
