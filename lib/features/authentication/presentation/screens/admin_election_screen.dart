import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/vercel_api_client.dart';
import '../../services/admin_election_service.dart';

class AdminElectionScreen extends StatefulWidget {
  const AdminElectionScreen({super.key, this.service});
  final AdminElectionService? service;
  @override
  State<AdminElectionScreen> createState() => _AdminElectionScreenState();
}

class _AdminElectionScreenState extends State<AdminElectionScreen> {
  late final AdminElectionService _service = widget.service ?? AdminElectionService();
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  List<AdminElection> _elections = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _code.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final rows = await _service.list(); if (mounted) setState(() { _elections = rows; _loading = false; }); }
    catch (error) { if (mounted) setState(() { _error = error is VercelApiException ? error.message : 'Could not load election settings.'; _loading = false; }); }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try { await _service.create(code: _code.text.trim(), name: _name.text.trim()); _code.clear(); _name.clear(); await _load(); }
    catch (error) { if (mounted) setState(() => _error = error is VercelApiException ? error.message : 'Could not open election.'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _close(AdminElection election) async {
    try { await _service.close(election.id); await _load(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is VercelApiException ? error.message : 'Could not close election.'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text('Election settings', style: AppTextStyles.sectionTitle())),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      Text('Manage election window', style: AppTextStyles.screenTitle()),
      const SizedBox(height: AppSpacing.xs),
      Text('Only one election can accept submissions at a time. Closing it prevents new results and evidence uploads.', style: AppTextStyles.body(color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.lg),
      Card(color: AppColors.surface, elevation: 0, child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Open an election', style: AppTextStyles.sectionTitle()),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Short election code', hintText: 'e.g. NG-GOV-2027'), validator: (value) => value == null || value.trim().length < 3 ? 'Enter a code of at least 3 characters.' : null),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Election name', hintText: 'e.g. State Governorship Election'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter an election name.' : null),
        if (_error != null) ...[const SizedBox(height: AppSpacing.md), Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.error))],
        const SizedBox(height: AppSpacing.md),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _create, icon: const Icon(Icons.how_to_vote_outlined), label: Text(_saving ? 'Opening…' : 'Open election'))),
      ])))),
      const SizedBox(height: AppSpacing.lg),
      Text('Existing elections', style: AppTextStyles.sectionTitle()),
      if (_elections.isEmpty) const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: Text('No elections have been created.')),
      ..._elections.map((election) => Card(color: AppColors.surface, elevation: 0, child: ListTile(
        title: Text(election.name), subtitle: Text('${election.code} · ${election.status.toUpperCase()}'),
        trailing: election.status == 'open' ? TextButton(onPressed: () => _close(election), child: const Text('Close')) : null,
      ))),
    ])),
  );
}
