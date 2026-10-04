// lib/features/result_submission/presentation/screens/result_submission_flow_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/result_submission_controller.dart';
import 'result_figures_screen.dart';
import 'capture_result_form_screen.dart';
import 'declaration_video_screen.dart';
import 'location_verification_screen.dart';
import 'review_submission_screen.dart';
import '../../services/device_location_service.dart';

/// Master workflow coordinator screen hosting the 5-step evidence capture flow (Section 1).
class ResultSubmissionFlowScreen extends StatefulWidget {
  const ResultSubmissionFlowScreen({
    super.key,
    required this.pollingUnitId,
    this.controller,
    this.onSubmitted,
  });

  final String pollingUnitId;
  final ResultSubmissionController? controller;
  final VoidCallback? onSubmitted;

  @override
  State<ResultSubmissionFlowScreen> createState() =>
      _ResultSubmissionFlowScreenState();
}

class _ResultSubmissionFlowScreenState
    extends State<ResultSubmissionFlowScreen> {
  late final ResultSubmissionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        ResultSubmissionController(pollingUnitId: widget.pollingUnitId);
    _controller.initialize();
    DeviceLocationService.warmUpPermissionsAndLocation();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onStepCompleted(int currentStep) {
    if (currentStep < 5) {
      _controller.setStep(currentStep + 1);
    }
  }

  void _onSubmissionCompleted() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SubmissionSuccessDialog(
        confirmationCode: _controller.draft.serverConfirmationCode ?? 'INEC-CONFIRMED',
        pollingUnitId: widget.pollingUnitId,
        onDone: () {
          Navigator.of(ctx).pop(); // dismiss dialog
          Navigator.of(context).pop(); // return to dashboard
          widget.onSubmitted?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (!_controller.isInitialized) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (_controller.configurationError != null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: Text('Result submission', style: AppTextStyles.sectionTitle())),
            body: Center(child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.event_busy_outlined, size: 44, color: AppColors.warning),
                const SizedBox(height: AppSpacing.md),
                Text(_controller.configurationError!, textAlign: TextAlign.center, style: AppTextStyles.body()),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), label: const Text('Return to dashboard')),
              ]),
            )),
          );
        }

        switch (_controller.currentStep) {
          case 1:
            return ResultFiguresScreen(
              controller: _controller,
              onNextStep: () => _onStepCompleted(1),
            );
          case 2:
            return CaptureResultFormScreen(
              controller: _controller,
              onNextStep: () => _onStepCompleted(2),
            );
          case 3:
            return DeclarationVideoScreen(
              controller: _controller,
              onNextStep: () => _onStepCompleted(3),
            );
          case 4:
            return LocationVerificationScreen(
              controller: _controller,
              onNextStep: () => _onStepCompleted(4),
            );
          case 5:
          default:
            return ReviewSubmissionScreen(
              controller: _controller,
              onNavigateToStep: (step) => _controller.setStep(step),
              onSubmissionCompleted: _onSubmissionCompleted,
            );
        }
      },
    );
  }
}

class _SubmissionSuccessDialog extends StatelessWidget {
  const _SubmissionSuccessDialog({
    required this.confirmationCode,
    required this.pollingUnitId,
    required this.onDone,
  });

  final String confirmationCode;
  final String pollingUnitId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppBorderRadius.card),
      backgroundColor: AppColors.surface,
      contentPadding: const EdgeInsets.all(AppSpacing.xxl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Result Submitted Successfully',
            style: AppTextStyles.sectionTitle(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your polling unit evidence has been transmitted and placed under Ward Collation review.',
            style: AppTextStyles.bodySmall(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'CONFIRMATION CODE',
                  style: AppTextStyles.inputLabel(color: AppColors.textSecondary).copyWith(fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  confirmationCode,
                  style: AppTextStyles.userIdDisplay().copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: 'RETURN TO DASHBOARD',
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}
