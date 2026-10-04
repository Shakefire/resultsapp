// lib/features/result_submission/presentation/screens/result_figures_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/result_submission_controller.dart';
import '../../models/result_figures.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 1: Enter official Result Sheet (EC8A) figures with real-time mathematical validation.
class ResultFiguresScreen extends StatefulWidget {
  const ResultFiguresScreen({
    super.key,
    required this.controller,
    required this.onNextStep,
  });

  final ResultSubmissionController controller;
  final VoidCallback onNextStep;

  @override
  State<ResultFiguresScreen> createState() => _ResultFiguresScreenState();
}

class _ResultFiguresScreenState extends State<ResultFiguresScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _registeredVotersCtrl;
  late TextEditingController _accreditedVotersCtrl;
  late TextEditingController _rejectedVotesCtrl;

  // Default major political parties in Nigerian presidential/general elections
  final List<String> _parties = ['APC', 'LP', 'NNPP', 'PDP', 'ADC', 'APGA'];
  late Map<String, TextEditingController> _partyControllers;

  @override
  void initState() {
    super.initState();
    final figures = widget.controller.figures;

    _registeredVotersCtrl = TextEditingController(
      text: figures.registeredVoters > 0 ? figures.registeredVoters.toString() : '',
    );
    _accreditedVotersCtrl = TextEditingController(
      text: figures.accreditedVoters > 0 ? figures.accreditedVoters.toString() : '',
    );
    _rejectedVotesCtrl = TextEditingController(
      text: figures.rejectedVotes > 0 ? figures.rejectedVotes.toString() : '0',
    );

    _partyControllers = {};
    for (final party in _parties) {
      final val = figures.partyVotes[party];
      _partyControllers[party] = TextEditingController(
        text: val != null && val > 0 ? val.toString() : '',
      );
      _partyControllers[party]!.addListener(_onTallyChanged);
    }

    _registeredVotersCtrl.addListener(_onTallyChanged);
    _accreditedVotersCtrl.addListener(_onTallyChanged);
    _rejectedVotesCtrl.addListener(_onTallyChanged);
  }

  void _onTallyChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _registeredVotersCtrl.dispose();
    _accreditedVotersCtrl.dispose();
    _rejectedVotesCtrl.dispose();
    for (final c in _partyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _getInt(TextEditingController ctrl) {
    return int.tryParse(ctrl.text.trim()) ?? 0;
  }

  ResultFigures _buildCurrentFigures() {
    final Map<String, int> partyMap = {};
    for (final entry in _partyControllers.entries) {
      partyMap[entry.key] = _getInt(entry.value);
    }
    return ResultFigures(
      registeredVoters: _getInt(_registeredVotersCtrl),
      accreditedVoters: _getInt(_accreditedVotersCtrl),
      partyVotes: partyMap,
      rejectedVotes: _getInt(_rejectedVotesCtrl),
    );
  }

  Future<void> _onSaveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final figures = _buildCurrentFigures();
    await widget.controller.saveFigures(figures);
    widget.onNextStep();
  }

  @override
  Widget build(BuildContext context) {
    final figures = _buildCurrentFigures();
    final hasOverAccreditation = figures.registeredVoters > 0 &&
        figures.accreditedVoters > figures.registeredVoters;
    final hasOverVoting = figures.accreditedVoters > 0 &&
        figures.totalVotesCast > figures.accreditedVoters;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Result Figures', style: AppTextStyles.sectionTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressIndicator(
              currentStep: 1,
              stepTitle: 'Enter Result Figures (Form EC8A)',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.horizontalPaddingLarge),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transcribe exact numbers recorded on the certified polling unit result sheet.',
                        style: AppTextStyles.subtitle(),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Section 1: Accreditation summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppBorderRadius.card,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VOTER STATISTICS',
                              style: AppTextStyles.inputLabel(color: AppColors.primary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildNumberField(
                              label: 'Registered Voters',
                              hint: 'e.g. 750',
                              controller: _registeredVotersCtrl,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (int.tryParse(v) == null || int.parse(v) <= 0) {
                                  return 'Must be greater than 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.fieldGap),
                            _buildNumberField(
                              label: 'Accredited Voters',
                              hint: 'e.g. 480',
                              controller: _accreditedVotersCtrl,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final acc = int.tryParse(v) ?? 0;
                                final reg = _getInt(_registeredVotersCtrl);
                                if (reg > 0 && acc > reg) {
                                  return 'Cannot exceed Registered Voters ($reg)';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Section 2: Political party votes
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppBorderRadius.card,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PARTY SCORES',
                                  style: AppTextStyles.inputLabel(color: AppColors.primary),
                                ),
                                Text(
                                  'VALID VOTES: ${figures.totalValidVotes}',
                                  style: AppTextStyles.caption(color: AppColors.primary).copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ..._parties.map((party) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.fieldGap),
                                child: _buildNumberField(
                                  label: '$party Votes',
                                  hint: '0',
                                  controller: _partyControllers[party]!,
                                ),
                              );
                            }),
                            const Divider(color: AppColors.border),
                            const SizedBox(height: AppSpacing.sm),
                            _buildNumberField(
                              label: 'Rejected / Invalid Ballots',
                              hint: '0',
                              controller: _rejectedVotesCtrl,
                            ),
                          ],
                        ),
                      ),

                      // Real-time mathematical audit box
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: (hasOverAccreditation || hasOverVoting)
                              ? AppColors.errorLight
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          border: Border.all(
                            color: (hasOverAccreditation || hasOverVoting)
                                ? AppColors.error
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildTallyRow('Total Valid Votes', '${figures.totalValidVotes}'),
                            const SizedBox(height: 4),
                            _buildTallyRow('Rejected Ballots', '${figures.rejectedVotes}'),
                            const Divider(height: 12, thickness: 1),
                            _buildTallyRow('TOTAL VOTES CAST', '${figures.totalVotesCast}', isBold: true),
                            if (hasOverAccreditation) ...[
                              const SizedBox(height: 8),
                              const Text(
                                '⚠️ Accredited voters cannot exceed registered voters.',
                                style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                            if (hasOverVoting) ...[
                              const SizedBox(height: 8),
                              const Text(
                                '⚠️ Over-voting detected: Total votes cast exceeds accredited voters.',
                                style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      PrimaryButton(
                        label: 'SAVE & CONTINUE TO PHOTO',
                        enabled: !hasOverAccreditation && !hasOverVoting,
                        onPressed: _onSaveAndContinue,
                      ),

                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.inputLabel()),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputText(color: AppColors.textPlaceholder),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTallyRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 13 : 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 14 : 12,
          ),
        ),
      ],
    );
  }
}
