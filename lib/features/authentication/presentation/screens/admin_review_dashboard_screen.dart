import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/services/vercel_api_client.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/admin_review_service.dart';

class AdminReviewDashboardScreen extends StatefulWidget {
  const AdminReviewDashboardScreen({super.key, required this.user, this.service});
  final UserModel user;
  final AdminReviewService? service;

  @override
  State<AdminReviewDashboardScreen> createState() => _AdminReviewDashboardScreenState();
}

class _AdminReviewDashboardScreenState extends State<AdminReviewDashboardScreen> {
  late final AdminReviewService _service = widget.service ?? AdminReviewService();
  List<ReviewSubmission> _items = [];
  List<ReportElection> _reportElections = [];
  List<SummaryReadiness> _summaries = [];
  ReviewDashboardOverview? _overview;
  String? _summaryError;
  String? _overviewError;
  bool _loading = true;
  bool _overviewLoading = true;
  bool _overviewRequestInFlight = false;
  String? _error;
  String? _reportElectionId;
  bool _exporting = false;
  Timer? _overviewTimer;

  String get _title => switch (widget.user.role) {
        UserRole.wardAdmin => 'Ward review',
        UserRole.lgaAdmin => 'LGA review',
        UserRole.stateAdmin => 'State results',
        _ => 'Results review',
      };

  String get _queueDescription => switch (widget.user.role) {
        UserRole.wardAdmin => 'Polling unit results awaiting ward verification.',
        UserRole.lgaAdmin => 'Ward-verified polling unit results awaiting LGA approval.',
        UserRole.stateAdmin => 'LGA-approved polling unit results awaiting state approval.',
        _ => '',
      };

  @override
  void initState() {
    super.initState();
    _load();
    _loadDashboardOverview();
    _overviewTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadDashboardOverview();
    });
    if (widget.user.role == UserRole.stateAdmin) _loadReportElections();
    if (widget.user.role == UserRole.stateAdmin || widget.user.role == UserRole.lgaAdmin) _loadSummaries();
  }

  @override
  void dispose() {
    _overviewTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardOverview() async {
    if (_overviewRequestInFlight) return;
    _overviewRequestInFlight = true;
    if (_overview == null && mounted) setState(() { _overviewLoading = true; _overviewError = null; });
    try {
      final overview = await _service.getDashboardOverview();
      if (mounted) setState(() { _overview = overview; _overviewError = null; _overviewLoading = false; });
    } catch (error) {
      if (mounted) setState(() {
        _overviewError = error is VercelApiException ? error.message : 'Unable to load live result totals.';
        _overviewLoading = false;
      });
    } finally {
      _overviewRequestInFlight = false;
    }
  }

  Future<void> _loadSummaries() async {
    try { final data = await _service.getSummaryReadiness(); if (mounted) setState(() { _summaries = data; _summaryError = null; }); }
    catch (error) { if (mounted) setState(() => _summaryError = error is VercelApiException ? error.message : 'Unable to load summary completeness.'); }
  }

  Future<void> _loadReportElections() async {
    try {
      final elections = await _service.getReportableElections();
      if (mounted) setState(() { _reportElections = elections; _reportElectionId ??= elections.firstOrNull?.id; });
    } catch (_) {
      // The review queue remains usable when there are no reportable elections.
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.getQueue();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error is VercelApiException ? error.message : 'Unable to load this review queue.'; _loading = false; });
    }
  }

  Future<void> _refreshAll() async {
    await _load();
    await _loadDashboardOverview();
    if (widget.user.role == UserRole.lgaAdmin || widget.user.role == UserRole.stateAdmin) await _loadSummaries();
    if (widget.user.role == UserRole.stateAdmin) await _loadReportElections();
  }

  Future<void> _decide(ReviewSubmission item, String action, {String? reason}) async {
    try {
      await _service.decide(submissionId: item.id, action: action, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decision recorded.')));
      await _load();
      await _loadDashboardOverview();
      if (widget.user.role == UserRole.lgaAdmin || widget.user.role == UserRole.stateAdmin) await _loadSummaries();
      if (widget.user.role == UserRole.stateAdmin) await _loadReportElections();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is VercelApiException ? error.message : 'Could not record this decision.')));
    }
  }

  Future<void> _approveSummary(SummaryReadiness summary) async {
    try {
      final result = await _service.approveSummary(summary.electionId);
      if (!mounted) return;
      final figures = Map<String, dynamic>.from(result['figures'] as Map? ?? const {});
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text(widget.user.role == UserRole.lgaAdmin ? 'LGA total approved' : 'State summary approved'),
        content: SelectableText('Election: ${summary.electionName}\nSources: ${result['sourceCount'] ?? result['lgaCount']}\nApproved: ${result['approvedAt']}\n\n${const JsonEncoder.withIndent('  ').convert(figures)}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ));
      await _loadSummaries();
      await _loadDashboardOverview();
      if (widget.user.role == UserRole.stateAdmin) await _loadReportElections();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is VercelApiException ? error.message : 'Could not approve this summary.')));
    }
  }

  Future<void> _returnResult(ReviewSubmission item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Return result for correction'),
      content: TextField(controller: controller, autofocus: true, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason', hintText: 'Explain what the polling unit needs to correct.')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Return result'))],
    ));
    controller.dispose();
    if (reason == null) return;
    if (reason.length < 3) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a return reason of at least three characters.'))); return; }
    await _decide(item, 'returned', reason: reason);
  }

  Future<void> _export() async {
    final electionId = _reportElectionId;
    if (electionId == null) return;
    setState(() => _exporting = true);
    try {
      final report = await _service.exportStateReport(electionId);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('Official CSV report generated'),
        content: SelectableText('${report.filename}\n${report.rowCount} approved rows\nGenerated ${report.generatedAt}\n\n${report.csv}', maxLines: 14),
        actions: [
          TextButton(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report.csv));
            if (context.mounted) Navigator.pop(context);
            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard.')));
          }, child: const Text('Copy CSV')),
          FilledButton(onPressed: () async {
            try {
              final path = await FilePicker.platform.saveFile(fileName: report.filename,
                type: FileType.custom, allowedExtensions: const ['csv'],
                bytes: Uint8List.fromList(utf8.encode(report.csv)));
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(path != null ? 'Report saved: $path' : 'Report saved.')),
                );
              }
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Could not save report: $error')),
                );
              }
            }
          }, child: const Text('Save CSV')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is VercelApiException ? error.message : 'Could not export report.')));
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text(_title, style: AppTextStyles.sectionTitle()), actions: [IconButton(onPressed: _loading ? null : _refreshAll, tooltip: 'Refresh', icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(onRefresh: _refreshAll, child: _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text(_title, style: AppTextStyles.screenTitle()),
          const SizedBox(height: AppSpacing.xs),
          Text(_queueDescription, style: AppTextStyles.body(color: AppColors.textSecondary)),
          // ── Delegated provisioning shortcut ──────────────────────────────
          if (widget.user.canProvisionUsers) ...[ 
            const SizedBox(height: AppSpacing.lg),
            Card(
              color: AppColors.surface,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Create account'),
                subtitle: const Text('Provision accounts within your assigned area.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, RouteNames.adminProvisionUser),
              ),
            ),
            Card(
              color: AppColors.surface,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Manage accounts'),
                subtitle: const Text('Reset passwords, activate or deactivate accounts.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, RouteNames.adminManagement),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _dashboardOverviewPanel(),
          if (widget.user.role == UserRole.lgaAdmin || widget.user.role == UserRole.stateAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            _summaryPanel(),
          ],
          if (widget.user.role == UserRole.stateAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            _exportPanel(),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _messageCard(_error!, isError: true),
          ] else if (_items.isEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _messageCard('No results are waiting in your queue.'),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            ..._queueWidgets(),
          ],
        ])),
  );

  List<Widget> _queueWidgets() {
    if (widget.user.role == UserRole.wardAdmin) return _items.map(_submissionCard).toList();
    final grouped = <String, List<ReviewSubmission>>{};
    for (final item in _items) {
      final key = widget.user.role == UserRole.lgaAdmin ? item.wardCode : item.lgaCode;
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped.entries.expand((entry) => <Widget>[
      Padding(padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs), child: Row(children: [
        Expanded(child: Text('${widget.user.role == UserRole.lgaAdmin ? 'Ward' : 'LGA'} ${entry.key}', style: AppTextStyles.sectionTitle())),
        Text('${entry.value.length} results', style: AppTextStyles.caption()),
      ])),
      ...entry.value.map(_submissionCard),
    ]).toList();
  }

  Widget _exportPanel() {
    final elections = _reportElections;
    return Card(color: AppColors.surface, elevation: 0, child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Official report export', style: AppTextStyles.sectionTitle()),
      const SizedBox(height: AppSpacing.sm),
      if (elections.isEmpty) Text('A State-approved result is required before a report can be generated.', style: AppTextStyles.bodySmall()),
      if (elections.isNotEmpty) DropdownButtonFormField<String>(value: elections.any((election) => election.id == _reportElectionId) ? _reportElectionId : elections.first.id, decoration: const InputDecoration(labelText: 'Election'), items: elections.map((election) => DropdownMenuItem(value: election.id, child: Text(election.label))).toList(), onChanged: (value) => setState(() => _reportElectionId = value)),
      const SizedBox(height: AppSpacing.sm),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: elections.isEmpty || _exporting ? null : _export, icon: _exporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined), label: Text(_exporting ? 'Generating…' : 'Generate CSV'))),
    ])));
  }

  Widget _dashboardOverviewPanel() {
    if (_overviewLoading && _overview == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final overview = _overview;
    if (overview == null) {
      return _messageCard(_overviewError ?? 'Election overview is unavailable.', isError: true);
    }
    if (overview.ongoingElectionCount == 0 || overview.electionName == null) {
      return Card(
        color: AppColors.surface,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.event_busy_outlined, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('No ongoing election', style: AppTextStyles.sectionTitle()),
                  Text('This dashboard will show scoped results when an election is open and within its scheduled window.', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
                ]),
              ),
              IconButton(onPressed: _loadDashboardOverview, tooltip: 'Refresh overview', icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
      );
    }

    final isWard = widget.user.role == UserRole.wardAdmin;
    final isLga = widget.user.role == UserRole.lgaAdmin;
    final expectedLabel = widget.user.role == UserRole.stateAdmin ? 'Active LGAs' : 'Active polling units';
    final approvedLabel = isWard ? 'Ward verified' : isLga ? 'LGA approved' : 'LGA totals approved';
    final awaitingLabel = isWard ? 'Awaiting ward review' : isLga ? 'Awaiting LGA total' : 'Awaiting LGA totals';
    final missingLabel = widget.user.role == UserRole.stateAdmin ? 'Pending LGAs' : 'Missing PU records';
    final parties = overview.partyVotes.entries.toList()
      ..sort((a, b) => _voteCount(b.value).compareTo(_voteCount(a.value)));
    final totalPartyVotes = parties.fold<int>(0, (sum, item) => sum + _voteCount(item.value));

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(overview.electionName!, style: AppTextStyles.sectionTitle()),
              Text(overview.electionCode ?? '', style: AppTextStyles.caption()),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(20)),
              child: Text('ONGOING · ${overview.ongoingElectionCount}', style: AppTextStyles.caption(color: AppColors.success)),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.xl, runSpacing: AppSpacing.md, children: [
            _overviewMetric(expectedLabel, overview.expected),
            _overviewMetric(approvedLabel, overview.approved),
            _overviewMetric(awaitingLabel, overview.awaiting),
            if (isLga) _overviewMetric('At Ward review', overview.submittedUnits),
            _overviewMetric('Returned', overview.returned),
            _overviewMetric(missingLabel, overview.missing),
          ]),
          const Divider(height: AppSpacing.xl),
          Row(children: [
            Expanded(child: Text('Party result overview · ${parties.length} ${parties.length == 1 ? 'party' : 'parties'}', style: AppTextStyles.sectionTitle())),
            IconButton(onPressed: _overviewRequestInFlight ? null : _loadDashboardOverview, tooltip: 'Refresh live result totals', icon: const Icon(Icons.refresh)),
          ]),
          Text('${overview.partySource} · refreshed every 60 seconds', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
          if (_overviewError != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text('Showing the last successful totals. ${_overviewError!}', style: AppTextStyles.caption(color: AppColors.warning))),
          if (parties.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text('No approved party figures are available yet.', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
            )
          else ...[
            const SizedBox(height: AppSpacing.sm),
            ...parties.map((entry) {
              final votes = _voteCount(entry.value);
              final share = totalPartyVotes == 0 ? 0.0 : votes / totalPartyVotes;
              final percent = (share * 100).toStringAsFixed(1);
              return Semantics(
                label: '${entry.key}: ${_formatCount(votes)} votes, $percent percent of party votes',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(children: [
                    SizedBox(width: 64, child: Text(entry.key, style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w600))),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: share, minHeight: 8, backgroundColor: AppColors.border, color: AppColors.primary),
                      ),
                    )),
                    SizedBox(width: 110, child: Text('${_formatCount(votes)}  ·  $percent%', textAlign: TextAlign.right, style: AppTextStyles.bodySmall())),
                  ]),
                ),
              );
            }),
            const Divider(height: AppSpacing.lg),
            Align(alignment: Alignment.centerRight, child: Text('Total party votes  ${_formatCount(totalPartyVotes)}', style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w600))),
          ],
          if (overview.approvalComplete)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(children: [
                const Icon(Icons.verified_outlined, size: 18, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(_approvalCompleteLabel, style: AppTextStyles.bodySmall(color: AppColors.success))),
              ]),
            ),
        ]),
      ),
    );
  }

  String get _approvalCompleteLabel => switch (widget.user.role) {
    UserRole.wardAdmin => 'All active polling units have Ward-verified results.',
    UserRole.lgaAdmin => 'The LGA total is approved and available to the State Admin.',
    UserRole.stateAdmin => 'The State summary is approved.',
    _ => 'Approval is complete.',
  };

  Widget _overviewMetric(String label, int value) => SizedBox(
    width: 140,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_formatCount(value), style: AppTextStyles.sectionTitle()),
      Text(label, style: AppTextStyles.caption(color: AppColors.textSecondary)),
    ]),
  );

  int _voteCount(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _formatCount(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  Widget _summaryPanel() => Card(color: AppColors.surface, elevation: 0, child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(widget.user.role == UserRole.lgaAdmin ? 'LGA total validation' : 'State summary approval', style: AppTextStyles.sectionTitle()),
    const SizedBox(height: AppSpacing.xs),
    Text(widget.user.role == UserRole.lgaAdmin
      ? 'Totals sum the latest Ward-verified result for every active polling unit in this LGA. Missing, returned, or unverified results block approval.'
      : 'The state summary sums approved LGA totals. Every LGA in the state must be approved before State approval.', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
    if (_summaryError != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(_summaryError!, style: AppTextStyles.bodySmall(color: AppColors.error))),
    if (_summaries.isEmpty && _summaryError == null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text('No elections are available.', style: AppTextStyles.bodySmall())),
    ..._summaries.map((summary) => Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Container(padding: const EdgeInsets.all(AppSpacing.md), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppSpacing.sm)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(summary.electionName, style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w600)),
      Text(summary.electionCode, style: AppTextStyles.caption()),
      const SizedBox(height: AppSpacing.xs),
      Text(widget.user.role == UserRole.lgaAdmin
        ? 'Ward-verified ${summary.verified}/${summary.expected} · Returned ${summary.returned} · Missing ${summary.missing}'
        : 'LGA totals approved ${summary.approved}/${summary.expected} · Missing ${summary.missing}', style: AppTextStyles.bodySmall()),
      if (summary.isApproved) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text('Approved', style: AppTextStyles.bodySmall(color: AppColors.success))),
      if (summary.ready) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _approveSummary(summary), icon: const Icon(Icons.verified_outlined), label: Text(widget.user.role == UserRole.lgaAdmin ? 'Approve LGA total' : 'Approve State summary')))),
      if (!summary.ready && !summary.isApproved) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text('Approval is blocked until the completeness rule is met.', style: AppTextStyles.caption(color: AppColors.warning))),
    ])))),
  ])));

  Widget _submissionCard(ReviewSubmission item) => Card(
    color: AppColors.surface, elevation: 0,
    shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(AppSpacing.md)),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('${item.pollingUnitCode} · ${item.wardCode}', style: AppTextStyles.sectionTitle())), _statusPill(item.status)]),
      const SizedBox(height: AppSpacing.xs),
      Text('${item.stateCode} / ${item.lgaCode} / ${item.wardCode} / ${item.pollingUnitCode}', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
      Text('Election ${item.electionId} · Revision ${item.revision}', style: AppTextStyles.caption()),
      const SizedBox(height: AppSpacing.md),
      Text('Result figures', style: AppTextStyles.inputLabel()),
      const SizedBox(height: AppSpacing.xs),
      SelectableText(const JsonEncoder.withIndent('  ').convert(item.figures), style: AppTextStyles.bodySmall()),
      if (item.evidence.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text('Evidence files', style: AppTextStyles.inputLabel()),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: item.evidence.map((evidence) => OutlinedButton.icon(
          onPressed: () async {
            try { await _service.openEvidence(evidence); }
            catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is VercelApiException ? error.message : 'Could not open evidence.'))); }
          },
          icon: Icon(switch (evidence.type) { 'result_photo' => Icons.image_outlined, 'declaration_video' => Icons.videocam_outlined, _ => Icons.picture_as_pdf_outlined }),
          label: Text(switch (evidence.type) { 'result_photo' => 'Result photo', 'declaration_video' => 'Declaration video', _ => 'Voter register' }),
        )).toList()),
      ],
      if (item.decisions.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text('Review history', style: AppTextStyles.inputLabel()),
        ...item.decisions.map((decision) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('${decision['action']}${decision['reason'] == null ? '' : ': ${decision['reason']}'}', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)))),
      ],
      if (widget.user.role == UserRole.wardAdmin) ...[
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (widget.user.role == UserRole.wardAdmin) OutlinedButton.icon(onPressed: () => _returnResult(item), icon: const Icon(Icons.undo), label: const Text('Return with reason')),
          FilledButton.icon(onPressed: () => _decide(item, _action), icon: const Icon(Icons.verified_outlined), label: Text(_approveLabel)),
        ]),
      ],
    ])),
  );

  String get _action => switch (widget.user.role) { UserRole.wardAdmin => 'ward_verified', UserRole.lgaAdmin => 'lga_approved', _ => 'state_approved' };
  String get _approveLabel => widget.user.role == UserRole.wardAdmin ? 'Verify result' : 'Approve result';

  Widget _statusPill(String status) => Container(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs), decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)), child: Text(status.replaceAll('_', ' ').toUpperCase(), style: AppTextStyles.caption(color: AppColors.primary)));

  Widget _messageCard(String text, {bool isError = false}) => Container(padding: const EdgeInsets.all(AppSpacing.lg), decoration: BoxDecoration(color: isError ? AppColors.errorLight : AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.md)), child: Text(text, style: AppTextStyles.body(color: isError ? AppColors.error : AppColors.textSecondary)));
}

extension _FirstOrNull<T> on List<T> { T? get firstOrNull => isEmpty ? null : first; }
