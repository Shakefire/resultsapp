// lib/features/polling_unit/presentation/screens/submission_details_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';
import '../../models/result_submission.dart';

/// Screen displaying the submitted result details and current collation status.
class SubmissionDetailsScreen extends StatelessWidget {
  const SubmissionDetailsScreen({
    super.key,
    required this.controller,
  });

  final PollingUnitDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final assignment = controller.assignment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Submission Details', style: AppTextStyles.sectionTitle()),
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
              // Polling unit & status summary card
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
                            color: result?.status.statusLightColor ?? AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result?.status.displayTitle ?? 'Submitted',
                            style: AppTextStyles.caption(
                              color: result?.status.statusColor ?? AppColors.textSecondary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      assignment?.pollingUnitName ?? 'Gwarinpa Primary School',
                      style: AppTextStyles.sectionTitle(),
                    ),
                    Text(
                      assignment != null ? '${assignment.wardAndLga}, ${assignment.state}' : '',
                      style: AppTextStyles.bodySmall(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: AppSpacing.md),
                    _DetailRow(label: 'Submission ID', value: result?.id ?? '—'),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(
                      label: 'Submitted At',
                      value: result?.submittedAt != null
                          ? '${result!.submittedAt!.day}/${result.submittedAt!.month}/${result.submittedAt!.year}'
                          : '—',
                    ),
                    if (result?.registeredVoters != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(label: 'Registered voters', value: '${result!.registeredVoters}'),
                      _DetailRow(label: 'Accredited voters', value: '${result.accreditedVoters}'),
                      _DetailRow(label: 'Ballots cast', value: '${result.ballotsCast}'),
                    ],
                  ],
                ),
              ),

              if (result?.status == ResultStatus.returned && result?.returnReason != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.md), decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(AppSpacing.sm)), child: Text('Returned for correction: ${result!.returnReason}', style: AppTextStyles.bodySmall(color: AppColors.error))),
              ],
              if (result?.evidence.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Evidence', style: AppTextStyles.sectionTitle()),
                ...result!.evidence.map((file) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(file.type == 'result_photo' ? Icons.image_outlined : Icons.videocam_outlined, color: AppColors.primary),
                  title: Text(file.type == 'result_photo' ? 'Result form photo' : 'Declaration video'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () async {
                    try {
                      final url = await controller.getEvidenceDownloadUrl(file.objectKey);
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } catch (error) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open evidence: $error')));
                    }
                  },
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
