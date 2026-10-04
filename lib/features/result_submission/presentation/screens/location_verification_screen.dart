// lib/features/result_submission/presentation/screens/location_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/result_submission_controller.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 4: Location & Timestamp Verification (Section 3, 4, 26 & 27).
class LocationVerificationScreen extends StatefulWidget {
  const LocationVerificationScreen({
    super.key,
    required this.controller,
    required this.onNextStep,
  });

  final ResultSubmissionController controller;
  final VoidCallback onNextStep;

  @override
  State<LocationVerificationScreen> createState() =>
      _LocationVerificationScreenState();
}

class _LocationVerificationScreenState extends State<LocationVerificationScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.location == null) {
      widget.controller.refreshCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.controller.location;
    final timestamp = widget.controller.draft.deviceTimestamp;
    final isAcquiring = widget.controller.isProcessing;

    final bool hasLowAccuracy =
        location != null && location.accuracyMeters > 25.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Location & Timestamp', style: AppTextStyles.sectionTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressIndicator(
              currentStep: 4,
              stepTitle: 'Verify GPS Coordinates & Timestamp',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.horizontalPaddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Real-time satellite coordinates and cryptographic device timestamp verification.',
                      style: AppTextStyles.subtitle(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // GPS Card
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
                                'SATELLITE POSITION',
                                style: AppTextStyles.inputLabel(color: AppColors.primary),
                              ),
                              if (location != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: location.isAccurate
                                        ? AppColors.successLight
                                        : AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    location.isAccurate ? 'Accurate' : 'Low Precision',
                                    style: AppTextStyles.caption(
                                      color: location.isAccurate
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (location != null) ...[
                            _CoordRow(label: 'Latitude', value: location.latitudeFormatted),
                            const SizedBox(height: AppSpacing.sm),
                            _CoordRow(label: 'Longitude', value: location.longitudeFormatted),
                            const SizedBox(height: AppSpacing.sm),
                            _CoordRow(
                              label: 'Accuracy Radius',
                              value: location.accuracyFormatted,
                              highlight: true,
                            ),
                          ] else ...[
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isAcquiring
                                  ? null
                                  : () => widget.controller.refreshCurrentLocation(),
                              icon: const Icon(Icons.my_location, size: 16),
                              label: Text(
                                isAcquiring ? 'ACQUIRING FIX...' : 'REFRESH GPS FIX',
                                style: AppTextStyles.buttonText(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (hasLowAccuracy) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Location accuracy is low. Move away from tall obstructions to improve satellite reception before submitting.',
                                style: AppTextStyles.bodySmall(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    // Timestamp Card
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
                            'DEVICE TIMESTAMP',
                            style: AppTextStyles.inputLabel(color: AppColors.primary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(timestamp),
                            style: AppTextStyles.sectionTitle(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('HH:mm:ss').format(timestamp)} ${timestamp.timeZoneName}',
                            style: AppTextStyles.body(color: AppColors.primary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Evidence metadata timestamp will be audited against backend server receipt time upon transmission.',
                            style: AppTextStyles.caption(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    PrimaryButton(
                      label: 'CONTINUE TO REVIEW',
                      enabled: location != null && !isAcquiring,
                      onPressed: widget.onNextStep,
                    ),

                    const SizedBox(height: AppSpacing.xl),
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

class _CoordRow extends StatelessWidget {
  const _CoordRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
