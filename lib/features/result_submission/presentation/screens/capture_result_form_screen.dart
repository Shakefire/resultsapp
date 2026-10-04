// lib/features/result_submission/presentation/screens/capture_result_form_screen.dart
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
import '../widgets/camera_overlay_widget.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 2: Guided Evidence Camera Interface for capturing physical Form EC8A (Section 6–17).
class CaptureResultFormScreen extends StatefulWidget {
  const CaptureResultFormScreen({
    super.key,
    required this.controller,
    required this.onNextStep,
  });

  final ResultSubmissionController controller;
  final VoidCallback onNextStep;

  @override
  State<CaptureResultFormScreen> createState() =>
      _CaptureResultFormScreenState();
}

class _CaptureResultFormScreenState extends State<CaptureResultFormScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _hasCameraHardware = true;
  String? _cameraErrorMessage;

  FlashMode _currentFlashMode = FlashMode.off;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  Offset? _focusPoint;
  final bool _isDocumentAligned = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      camera.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _hasCameraHardware = false;
          _isCameraInitialized = true;
        });
        return;
      }

      // Default to back camera for document scanning
      final backCamera = _availableCameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 5.0);

      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _hasCameraHardware = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasCameraHardware = false;
        _isCameraInitialized = true;
        _cameraErrorMessage = 'Camera unavailable: $e';
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
      default:
        nextMode = FlashMode.off;
        break;
    }
    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _currentFlashMode = nextMode);
    } catch (_) {}
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    try {
      await _cameraController!.setZoomLevel(clamped);
      setState(() => _currentZoom = clamped);
    } catch (_) {}
  }

  Future<void> _onTapFocus(TapUpDetails details, BoxConstraints constraints) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    final offset = details.localPosition;
    setState(() => _focusPoint = offset);

    final x = (offset.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final y = (offset.dy / constraints.maxHeight).clamp(0.0, 1.0);

    try {
      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
    } catch (_) {}

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Future<void> _takePhoto() async {
    final camera = _cameraController;
    if (!_hasCameraHardware || camera == null || !camera.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A physical camera is required to capture result evidence.')),
      );
      return;
    }
    final xfile = await camera.takePicture();
    if (!mounted) return;
    await widget.controller.processAndAttachResultPhoto(xfile.path);
  }

  String _getFlashModeLabel() {
    switch (_currentFlashMode) {
      case FlashMode.always:
        return 'On';
      case FlashMode.auto:
        return 'Auto';
      default:
        return 'Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final photo = widget.controller.resultPhoto;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              photo != null ? 'Inspect Evidence Photo' : 'Capture Result Form',
              style: AppTextStyles.sectionTitle(color: Colors.white),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                StepProgressIndicator(
                  currentStep: 2,
                  stepTitle: photo != null ? 'Result Form Captured' : 'Capture Result Form (EC8A)',
                ),
                Expanded(
                  child: photo != null
                      ? _buildInspectionView(photo.localPath)
                      : _buildCameraCaptureView(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Live Guided Camera Viewfinder
  Widget _buildCameraCaptureView() {
    if (!_isCameraInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _onTapFocus(details, constraints),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live camera stream; no simulated image is accepted as evidence.
              if (_hasCameraHardware && _cameraController != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF1E2621),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.document_scanner, size: 56, color: AppColors.primaryLight),
                        const SizedBox(height: 12),
                        Text(
                          'Align Physical Result Form EC8A',
                          style: AppTextStyles.sectionTitle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cameraErrorMessage ?? 'Live viewfinder ready',
                          style: AppTextStyles.caption(color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                  ),
                ),

              // Guided overlay with corner guides, top-right metadata, touch focus, and shutter
              CameraOverlayWidget(
                pollingUnitId: widget.controller.pollingUnitId,
                location: widget.controller.location,
                deviceTimestamp: DateTime.now(),
                onCapturePressed: _takePhoto,
                onFlashTogglePressed: _toggleFlash,
                flashModeLabel: _getFlashModeLabel(),
                isCapturing: widget.controller.isProcessing,
                focusPoint: _focusPoint,
                isDocumentAligned: _isDocumentAligned,
                currentZoom: _currentZoom,
                onZoomIn: _hasCameraHardware ? () => _setZoom(_currentZoom + 0.5) : null,
                onZoomOut: _hasCameraHardware ? () => _setZoom(_currentZoom - 0.5) : null,
              ),

              // Processing overlay
              if (widget.controller.isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C221E),
                        borderRadius: AppBorderRadius.card,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 38,
                            height: 38,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            widget.controller.processingMessage ?? 'Processing evidence...',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Securing GPS coordinates & timestamp',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Inspection view of the composed image showing the stamped top-right metadata
  Widget _buildInspectionView(String imagePath) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ClipRRect(
                borderRadius: AppBorderRadius.card,
                child: (!kIsWeb && File(imagePath).existsSync())
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                      )
                    : Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(Icons.image, size: 64, color: AppColors.primary),
                        ),
                      ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.horizontalPaddingLarge),
            color: AppColors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Metadata stamped in top-right corner',
                      style: AppTextStyles.body(color: AppColors.textPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.controller.draft.resultPhoto = null;
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
                        child: const Text('RETAKE PHOTO'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
