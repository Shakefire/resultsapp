// lib/features/result_submission/presentation/screens/review_submission_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/result_submission_controller.dart';
import '../../models/submission_state.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 5: Final Review & Submission Screen (Section 21–24).
class ReviewSubmissionScreen extends StatefulWidget {
  const ReviewSubmissionScreen({
    super.key,
    required this.controller,
    required this.onNavigateToStep,
    required this.onSubmissionCompleted,
  });

  final ResultSubmissionController controller;
  final ValueChanged<int> onNavigateToStep;
  final VoidCallback onSubmissionCompleted;

  @override
  State<ReviewSubmissionScreen> createState() => _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState extends State<ReviewSubmissionScreen> {
  bool _isSubmitting = false;

  Future<void> _onSubmit() async {
    setState(() => _isSubmitting = true);
    final success = await widget.controller.submitFinalResult();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSubmissionCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.controller.draft;
    final figures = draft.figures;
    final photo = draft.resultPhoto;
    final video = draft.declarationVideo;
    final location = draft.location;
    final timestamp = draft.deviceTimestamp;
    final hasError = draft.state == SubmissionLifecycleState.uploadFailed;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Review Submission', style: AppTextStyles.sectionTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressIndicator(
              currentStep: 5,
              stepTitle: 'Review & Transmit Official Result',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.horizontalPaddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify all evidence packages before transmitting to the collation collation backend.',
                      style: AppTextStyles.subtitle(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Polling Unit Header Card
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
                          Text('POLLING UNIT', style: AppTextStyles.inputLabel(color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(draft.pollingUnitId, style: AppTextStyles.sectionTitle()),
                          Text('Ward 03 · AMAC, FCT', style: AppTextStyles.bodySmall()),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Item 1: Result Figures
                    _ReviewItemCard(
                      title: 'RESULT FIGURES',
                      status: figures.totalValidVotes > 0 ? 'Completed' : 'Pending',
                      isCompleted: figures.totalValidVotes > 0,
                      summary: 'Total Valid Votes: ${figures.totalValidVotes}\nTotal Votes Cast: ${figures.totalVotesCast}',
                      onEdit: () => widget.onNavigateToStep(1),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Item 2: Result Form Photo
                    _ReviewItemCard(
                      title: 'RESULT FORM (EC8A)',
                      status: photo != null ? 'Captured' : 'Missing',
                      isCompleted: photo != null,
                      summary: photo != null
                          ? 'Stamped with GPS & device timestamp\nSize: ${photo.fileSizeFormatted}'
                          : 'Please capture result sheet photo',
                      onEdit: () => widget.onNavigateToStep(2),
                      thumbnailPath: photo?.localPath,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Item 3: Declaration Video
                    _ReviewItemCard(
                      title: 'DECLARATION VIDEO',
                      status: video != null ? 'Recorded' : 'Missing',
                      isCompleted: video != null,
                      summary: video != null
                          ? 'Official declaration video recorded\nDuration: ${video.durationSeconds ?? 0}s (${video.fileSizeFormatted})'
                          : 'Please record declaration video',
                      onEdit: () => widget.onNavigateToStep(3),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Item 4: Location & Timestamp
                    _ReviewItemCard(
                      title: 'LOCATION & TIMESTAMP',
                      status: location != null ? 'Captured' : 'Pending',
                      isCompleted: location != null,
                      summary: location != null
                          ? '${location.latitudeFormatted}, ${location.longitudeFormatted} (${location.accuracyFormatted})\n${DateFormat('dd MMM yyyy · HH:mm:ss').format(timestamp)}'
                          : 'Please verify GPS coordinates',
                      onEdit: () => widget.onNavigateToStep(4),
                    ),

                    // Failure message banner (Section 23)
                    if (hasError && draft.uploadError != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                draft.uploadError!,
                                style: AppTextStyles.bodySmall(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxl),

                    PrimaryButton(
                      label: hasError ? 'RETRY SUBMISSION' : 'SUBMIT RESULT',
                      isLoading: _isSubmitting || widget.controller.isProcessing,
                      loadingLabel: widget.controller.processingMessage ?? 'Transmitting...',
                      enabled: draft.isComplete && !_isSubmitting,
                      onPressed: _onSubmit,
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.title,
    required this.status,
    required this.isCompleted,
    required this.summary,
    required this.onEdit,
    this.thumbnailPath,
  });

  final String title;
  final String status;
  final bool isCompleted;
  final String summary;
  final VoidCallback onEdit;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorderRadius.card,
        border: Border.all(
          color: isCompleted ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.successLight : AppColors.errorLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.priority_high_rounded,
              color: isCompleted ? AppColors.success : AppColors.error,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.inputLabel(
                        color: isCompleted ? AppColors.primary : AppColors.error,
                      ).copyWith(fontSize: 11),
                    ),
                    InkWell(
                      onTap: onEdit,
                      child: Text(
                        'EDIT',
                        style: AppTextStyles.caption(color: AppColors.primary).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: AppTextStyles.bodySmall().copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          if (thumbnailPath != null && !kIsWeb && File(thumbnailPath!).existsSync()) ...[
            const SizedBox(width: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(thumbnailPath!),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
