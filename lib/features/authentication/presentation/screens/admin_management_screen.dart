import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/services/vercel_api_client.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/admin_management_service.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key, this.service, this.actingUser});
  final AdminManagementService? service;

  /// The logged-in user. Used to determine which actions are available.
  final UserModel? actingUser;
  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late final AdminManagementService _service =
      widget.service ?? AdminManagementService();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<ManagedAccount> _accounts = [];
  List<ManagedGeography> _records = [], _states = [], _lgas = [], _wards = [];
  String _level = 'states';
  String? _state, _lga, _ward;
  bool _loadingAccounts = true, _loadingGeo = true, _busy = false;
  String? _accountError, _geoError;

  bool get _needsState => _level != 'states';
  bool get _needsLga => _level == 'wards' || _level == 'polling_units';
  bool get _needsWard => _level == 'polling_units';
  bool get _usingCachedGeography => [
    ..._states,
    ..._lgas,
    ..._wards,
    ..._records,
  ].any((item) => item.isFromCache);

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadStateOptions();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
      _accountError = null;
    });
    try {
      final rows = await _service.getAccounts();
      if (mounted)
        setState(() {
          _accounts = rows;
          _loadingAccounts = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _accountError = _message(error);
          _loadingAccounts = false;
        });
    }
  }

  Future<void> _loadStateOptions() async {
    if (mounted)
      setState(() {
        _loadingGeo = true;
        _geoError = null;
      });
    try {
      final rows = await _service.getGeography('states');
      if (mounted)
        setState(() {
          _states = rows;
          _records = rows;
          _loadingGeo = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _geoError = _message(error);
          _loadingGeo = false;
        });
    }
  }

  Future<void> _loadGeography() async {
    setState(() {
      _loadingGeo = true;
      _geoError = null;
    });
    try {
      if (_needsState && _state == null) {
        setState(() {
          _records = [];
          _loadingGeo = false;
        });
        return;
      }
      if (_needsLga && _lga == null) {
        setState(() {
          _records = [];
          _loadingGeo = false;
        });
        return;
      }
      if (_needsWard && _ward == null) {
        setState(() {
          _records = [];
          _loadingGeo = false;
        });
        return;
      }
      final rows = await _service.getGeography(
        _level,
        stateCode: _state,
        lgaCode: _lga,
        wardCode: _ward,
      );
      if (mounted)
        setState(() {
          _records = rows;
          if (_level == 'states') _states = rows;
          if (_level == 'lgas') _lgas = rows;
          if (_level == 'wards') _wards = rows;
          _loadingGeo = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _geoError = _message(error);
          _loadingGeo = false;
        });
    }
  }

  Future<void> _loadLgas(String state) async {
    setState(() {
      _state = state;
      _lga = null;
      _ward = null;
      _lgas = [];
      _wards = [];
      _records = [];
    });
    setState(() {
      _loadingGeo = true;
      _geoError = null;
    });
    try {
      final rows = await _service.getGeography('lgas', stateCode: state);
      if (mounted)
        setState(() {
          _lgas = rows;
          if (_level == 'lgas') _records = rows;
          _loadingGeo = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _geoError = _message(error);
          _loadingGeo = false;
        });
    }
  }

  Future<void> _loadWards(String lga) async {
    setState(() {
      _lga = lga;
      _ward = null;
      _wards = [];
      _records = [];
    });
    setState(() {
      _loadingGeo = true;
      _geoError = null;
    });
    try {
      final rows = await _service.getGeography(
        'wards',
        stateCode: _state,
        lgaCode: lga,
      );
      if (mounted)
        setState(() {
          _wards = rows;
          if (_level == 'wards') _records = rows;
          _loadingGeo = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _geoError = _message(error);
          _loadingGeo = false;
        });
    }
  }

  Future<void> _chooseLevel(String? value) async {
    if (value == null) return;
    setState(() {
      _level = value;
      _state = null;
      _lga = null;
      _ward = null;
      _records = [];
      _lgas = [];
      _wards = [];
    });
    await _loadGeography();
  }

  String _message(Object error) => error is VercelApiException
      ? error.message
      : 'Could not complete the request. Check your connection and retry.';

  String? _geographyName(List<ManagedGeography> items, String? code) {
    if (code == null) return null;
    for (final item in items) {
      if (item.code == code) return item.name;
    }
    return null;
  }

  Future<void> _accountAction(ManagedAccount account, String action) async {
    final isToggleProvision = action == 'toggle_provision_power';
    final currentlyCanProvision = account.json['can_provision_users'] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isToggleProvision
              ? (currentlyCanProvision
                  ? 'Revoke account-creation power?'
                  : 'Grant account-creation power?')
              : action == 'reset_password'
              ? 'Reset password?'
              : '${action == 'deactivate' ? 'Deactivate' : 'Reactivate'} account?',
        ),
        content: Text(
          isToggleProvision
              ? (currentlyCanProvision
                  ? '${account.name} will no longer be able to create accounts.'
                  : '${account.name} will be able to create accounts within their geographic scope.')
              : action == 'reset_password'
              ? 'A new six-character temporary password will be issued. The user must change it at next sign-in.'
              : 'This change takes effect on the next API request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.updateAccount(account.id, action);
      if (!mounted) return;
      if (action == 'toggle_provision_power') {
        final granted = result['canProvisionUsers'] == true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(granted
              ? 'Account-creation power granted to ${account.name}.'
              : 'Account-creation power revoked from ${account.name}.'),
        ));
      } else if (action == 'reset_password') {
        final password = result['temporaryPassword'] as String?;
        if (password != null)
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Temporary password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    'User ID: ${account.userId}\nTemporary password: $password',
                  ),
                  if (result['auditWarning'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Warning: the password reset could not be written to the audit log. Record and investigate this action before release.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'User ID: ${account.userId}\nTemporary password: $password',
                      ),
                    );
                    if (mounted && context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Credentials copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy details'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
      }
      await _loadAccounts();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _createRecord() async {
    final code = TextEditingController(), name = TextEditingController();
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add ${switch (_level) {
            'states' => 'state / FCT',
            'lgas' => 'LGA / Area Council',
            'wards' => 'ward',
            _ => 'polling unit',
          }}',
        ),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_level != 'states') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'This location will be added under ${[_geographyName(_states, _state), if (_needsLga) _geographyName(_lgas, _lga), if (_needsWard) _geographyName(_wards, _ward)].whereType<String>().join('  ›  ')}',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Code'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a code.'
                    : null,
              ),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved != true) {
      code.dispose();
      name.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.createGeography(
        level: _level,
        code: code.text,
        name: name.text,
        stateCode: _state,
        lgaCode: _lga,
        wardCode: _ward,
      );
      await _loadGeography();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
    } finally {
      code.dispose();
      name.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName(ManagedGeography item) async {
    final controller = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == item.name) return;
    try {
      await _service.updateGeography(
        level: _level,
        code: item.code,
        name: name,
        active: null,
        stateCode: _state,
        lgaCode: _lga,
        wardCode: _ward,
      );
      await _loadGeography();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _setActive(ManagedGeography item, bool active) async {
    try {
      await _service.updateGeography(
        level: _level,
        code: item.code,
        name: null,
        active: active,
        stateCode: _state,
        lgaCode: _lga,
        wardCode: _ward,
      );
      await _loadGeography();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Super Admin management'),
      actions: [
        IconButton(
          onPressed: _loadAccounts,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Accounts'),
          Tab(text: 'Geography'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [_accountsTab(), _geographyTab()],
    ),
  );

  Widget _accountsTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              RouteNames.adminProvisionUser,
            ).then((_) => _loadAccounts()),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Create account and assign role/location'),
          ),
        ),
      ),
      if (_accountError != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _accountError!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      Expanded(
        child: _loadingAccounts
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty
            ? const Center(child: Text('No managed accounts found.'))
            : RefreshIndicator(
                onRefresh: _loadAccounts,
                child: ListView.builder(
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final canProvision = account.json['can_provision_users'] == true;
                    final accountRole = account.json['role'] as String? ?? '';
                    final isEligibleForProvision =
                        accountRole == 'state_admin' || accountRole == 'lga_admin';
                    final actorRole = widget.actingUser?.role;
                    final actorCanToggle = actorRole == UserRole.superAdmin ||
                        (actorRole == UserRole.stateAdmin &&
                            widget.actingUser?.canProvisionUsers == true);
                    return ListTile(
                      leading: Icon(
                        account.active
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                      ),
                      title: Text('${account.name} · ${account.userId}'),
                      subtitle: Text(
                        '${account.role.replaceAll('_', ' ')}${account.scope.isEmpty ? '' : ' · ${account.scope}'}'
                        '${canProvision ? ' · Can create accounts' : ''}\n'
                        '${account.active ? 'Active' : 'Inactive'}'
                        '${account.json['must_change_password'] == true ? ' · Password change required' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'assign') {
                            Navigator.pushNamed(
                              context,
                              RouteNames.adminAccountAssignment,
                              arguments: account.json,
                            ).then((_) => _loadAccounts());
                          } else {
                            _accountAction(account, action);
                          }
                        },
                        itemBuilder: (_) => [
                          if (actorRole == UserRole.superAdmin)
                            const PopupMenuItem(
                              value: 'assign',
                              child: Text('Change role/location'),
                            ),
                          const PopupMenuItem(
                            value: 'reset_password',
                            child: Text('Issue temporary password'),
                          ),
                          PopupMenuItem(
                            value: account.active ? 'deactivate' : 'reactivate',
                            child: Text(
                              account.active
                                  ? 'Deactivate account'
                                  : 'Reactivate account',
                            ),
                          ),
                          if (actorCanToggle && isEligibleForProvision)
                            PopupMenuItem(
                              value: 'toggle_provision_power',
                              child: Text(
                                canProvision
                                    ? 'Revoke account-creation power'
                                    : 'Grant account-creation power',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );

  Widget _geographyTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geographic directory',
                    style: AppTextStyles.sectionTitle(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build Nigeria’s location tree from state to polling unit.',
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed:
                  _busy ||
                      (_needsState && _state == null) ||
                      (_needsLga && _lga == null) ||
                      (_needsWard && _ward == null)
                  ? null
                  : _createRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add location'),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Choose a level and its parent locations',
                      style: AppTextStyles.body(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _level,
                  decoration: const InputDecoration(
                    labelText: 'What are you managing?',
                    prefixIcon: Icon(Icons.layers_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'states',
                      child: Text('State / FCT'),
                    ),
                    DropdownMenuItem(
                      value: 'lgas',
                      child: Text('LGA / Area Council'),
                    ),
                    DropdownMenuItem(value: 'wards', child: Text('Ward')),
                    DropdownMenuItem(
                      value: 'polling_units',
                      child: Text('Polling unit'),
                    ),
                  ],
                  onChanged: _chooseLevel,
                ),
                if (_needsState) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _state,
                    decoration: const InputDecoration(
                      labelText: '1 · State',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _states
                        .where((e) => e.active)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.code,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _loadLgas(value);
                    },
                  ),
                ],
                if (_needsLga) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _lga,
                    decoration: InputDecoration(
                      labelText: '2 · LGA / Area Council',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: const OutlineInputBorder(),
                      helperText: _state == null
                          ? 'Choose a state first'
                          : null,
                    ),
                    items: _lgas
                        .where((e) => e.active)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.code,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: _state == null
                        ? null
                        : (value) {
                            if (value != null) _loadWards(value);
                          },
                  ),
                ],
                if (_needsWard) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _ward,
                    decoration: InputDecoration(
                      labelText: '3 · Ward',
                      prefixIcon: const Icon(Icons.place_outlined),
                      border: const OutlineInputBorder(),
                      helperText: _lga == null ? 'Choose an LGA first' : null,
                    ),
                    items: _wards
                        .where((e) => e.active)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.code,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: _lga == null
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _ward = value);
                              _loadGeography();
                            }
                          },
                  ),
                ],
                if (_needsState && _state != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      [
                        _geographyName(_states, _state),
                        if (_needsLga) _geographyName(_lgas, _lga),
                        if (_needsWard) _geographyName(_wards, _ward),
                      ].whereType<String>().join('  ›  '),
                      style: AppTextStyles.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (_usingCachedGeography)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Showing saved location data. Creating or changing records needs a live connection.',
              style: AppTextStyles.bodySmall(color: AppColors.warning),
            ),
          ),
        ),
      if (_geoError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_geoError!, style: const TextStyle(color: Colors.red)),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _level == 'states'
                    ? 'States and FCT'
                    : 'Available ${_level.replaceAll('_', ' ')}',
                style: AppTextStyles.sectionTitle(),
              ),
            ),
            Text(
              '${_records.length}',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      Expanded(
        child: _loadingGeo
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _emptyGeographyMessage,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadGeography,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _records[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.active
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            _level == 'states'
                                ? Icons.map_outlined
                                : _level == 'lgas'
                                ? Icons.location_city_outlined
                                : _level == 'wards'
                                ? Icons.place_outlined
                                : Icons.how_to_vote_outlined,
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.code}  ·  ${item.active ? 'Active' : 'Inactive'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Location actions',
                          onSelected: (action) {
                            if (action == 'rename')
                              _editName(item);
                            else
                              _setActive(item, action == 'activate');
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: item.active ? 'deactivate' : 'activate',
                              child: Text(
                                item.active ? 'Deactivate' : 'Activate',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );

  String get _emptyGeographyMessage {
    if (_needsState && _state == null)
      return 'Select a state to load its geography.';
    if (_needsLga && _lga == null)
      return 'Select an LGA to load its geography.';
    if (_needsWard && _ward == null)
      return 'Select a ward to load its polling units.';
    return switch (_level) {
      'states' => 'No state records are available in Supabase.',
      'lgas' =>
        'No LGA rows are loaded for this state. Import the Nigeria LGA geography seed.',
      'wards' =>
        'No ward rows are loaded for this LGA. Import and reconcile the ward directory.',
      _ =>
        'No polling units are loaded for this ward. Import an INEC-validated polling-unit directory.',
    };
  }
}
