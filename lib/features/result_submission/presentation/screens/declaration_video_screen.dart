// lib/features/result_submission/presentation/screens/declaration_video_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/result_submission_controller.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 3: Declaration Video Recording Screen (Section 18–20).
class DeclarationVideoScreen extends StatefulWidget {
  const DeclarationVideoScreen({
    super.key,
    required this.controller,
    required this.onNextStep,
  });

  final ResultSubmissionController controller;
  final VoidCallback onNextStep;

  /// Configurable maximum duration in seconds (Section 20).
  static const int maxVideoDurationSeconds = 60;

  @override
  State<DeclarationVideoScreen> createState() => _DeclarationVideoScreenState();
}

class _DeclarationVideoScreenState extends State<DeclarationVideoScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initVideoCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isCameraReady = true);
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = true);
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.startVideoRecording();
    }

    setState(() {
      _isRecording = true;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsedSeconds >= DeclarationVideoScreen.maxVideoDurationSeconds) {
        _stopRecording();
      } else {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    String videoPath = '';

    if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
      final file = await _cameraController!.stopVideoRecording();
      videoPath = file.path;
    } else {
      // Fallback for emulator / web simulation
      if (kIsWeb) {
        videoPath = 'web_declaration_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      } else {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/declaration_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(List<int>.filled(2048, 0x00));
        videoPath = file.path;
      }
    }

    setState(() {
      _isRecording = false;
    });

    await widget.controller.attachDeclarationVideo(
      videoPath,
      _elapsedSeconds > 0 ? _elapsedSeconds : 15,
    );
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.controller.declarationVideo;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Declaration Video', style: AppTextStyles.sectionTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressIndicator(
              currentStep: 3,
              stepTitle: 'Record Official Declaration Video',
            ),
            Expanded(
              child: video != null
                  ? _buildVideoCompletedView()
                  : _buildRecordingView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.horizontalPaddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record the Presiding Officer officially reading aloud the polling unit votes.',
            style: AppTextStyles.subtitle(),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Viewfinder card / video box
          ClipRRect(
            borderRadius: AppBorderRadius.card,
            child: Container(
              width: double.infinity,
              height: 280,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_cameraController != null && _cameraController!.value.isInitialized)
                    CameraPreview(_cameraController!)
                  else
                    const Center(
                      child: Icon(Icons.videocam, size: 64, color: Colors.white38),
                    ),

                  // Recording badge overlay
                  if (_isRecording)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'RECORDING ${_formatTimer(_elapsedSeconds)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Max duration notice
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Maximum limit: ${DeclarationVideoScreen.maxVideoDurationSeconds}s',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Action Button
          if (!_isRecording)
            PrimaryButton(
              label: 'START RECORDING',
              icon: const Icon(Icons.videocam, color: Colors.white, size: 18),
              onPressed: _isCameraReady ? _startRecording : null,
            )
          else
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop, color: Colors.white),
                label: Text(
                  'STOP RECORDING (${_formatTimer(_elapsedSeconds)})',
                  style: AppTextStyles.buttonText(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.button,
                  ),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildVideoCompletedView() {
    final video = widget.controller.declarationVideo!;

    return SingleChildScrollView(
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
                    Text('DECLARATION VIDEO', style: AppTextStyles.inputLabel(color: AppColors.primary)),
                    const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Declaration Recorded', style: AppTextStyles.sectionTitle()),
                const SizedBox(height: AppSpacing.sm),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Duration', value: '${video.durationSeconds ?? 0} seconds'),
                const SizedBox(height: AppSpacing.xs),
                _InfoRow(label: 'File Size', value: video.fileSizeFormatted),
                const SizedBox(height: AppSpacing.xs),
                _InfoRow(
                  label: 'GPS Metadata',
                  value: video.location != null
                      ? '${video.location!.latitudeFormatted}, ${video.location!.longitudeFormatted}'
                      : 'Captured',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.controller.draft.declarationVideo = null;
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppBorderRadius.button,
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('RECORD AGAIN'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: 'CONFIRM & NEXT',
                  onPressed: widget.onNextStep,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
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
        Text(value, style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
