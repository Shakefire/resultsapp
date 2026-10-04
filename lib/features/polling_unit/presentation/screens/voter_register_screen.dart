// lib/features/polling_unit/presentation/screens/voter_register_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';
import '../../models/voter_register.dart';

/// Screen displaying the Polling Unit's official voter register status and details.
class VoterRegisterScreen extends StatefulWidget {
  const VoterRegisterScreen({
    super.key,
    required this.controller,
  });

  final PollingUnitDashboardController controller;

  @override
  State<VoterRegisterScreen> createState() => _VoterRegisterScreenState();
}

class _VoterRegisterScreenState extends State<VoterRegisterScreen> {
  bool _opening = false;
  String? _error;

  Future<void> _openRegister() async {
    setState(() { _opening = true; _error = null; });
    try {
      final url = await widget.controller.getVoterRegisterDownloadUrl();
      if (url == null) throw Exception('No voter register is available for this polling unit.');
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open the private register link.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.controller.voterRegister;
    final assignment = widget.controller.assignment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Voter Register', style: AppTextStyles.sectionTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.horizontalPaddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          assignment?.pollingUnitId ?? 'PU 0047',
                          style: AppTextStyles.inputLabel(color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            register?.status.displayTitle ?? 'Uploaded',
                            style: AppTextStyles.caption(color: AppColors.primary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      assignment?.pollingUnitName ?? 'Gwarinpa Primary School',
                      style: AppTextStyles.sectionTitle(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      label: 'File Name',
                      value: register?.fileName ?? 'PU0047_VOTER_REGISTER.pdf',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'File Size',
                      value: register?.fileSizeBytes == null ? 'PDF Document' : '${(register!.fileSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB (PDF Document)',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Scope',
                      value: assignment?.wardAndLga ?? 'Ward 03 · AMAC',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Accreditation Status',
                      value: 'Verified Active',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _opening ? null : _openRegister,
                icon: _opening ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.open_in_new),
                label: Text(_opening ? 'Opening secure file…' : 'Open voter register'),
              )),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.error)),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Administrative Scope Notice (Section 10)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppBorderRadius.card,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'This document is strictly assigned to your polling unit scope. Administrative unit reassignments are managed at the Ward and LGA collation levels.',
                        style: AppTextStyles.bodySmall(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
