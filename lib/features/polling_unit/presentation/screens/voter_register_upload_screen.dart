import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';

/// Screen allowing Polling Unit Staff to upload the voter register PDF.
class VoterRegisterUploadScreen extends StatefulWidget {
  const VoterRegisterUploadScreen({
    super.key,
    required this.controller,
  });

  final PollingUnitDashboardController controller;

  @override
  State<VoterRegisterUploadScreen> createState() => _VoterRegisterUploadScreenState();
}

class _VoterRegisterUploadScreenState extends State<VoterRegisterUploadScreen> {
  bool _isUploading = false;
  String? _selectedFile;
  String? _selectedPath;
  Uint8List? _selectedBytes;
  String? _error;

  Future<void> _selectFile() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = selection?.files.single;
    if (file == null) return;
    if (!kIsWeb && file.path == null && file.bytes == null) return;
    if (kIsWeb && file.bytes == null) return;
    if (file.size <= 0 || file.size > 25 * 1024 * 1024) {
      setState(() => _error = 'Choose a PDF file under 25 MB.');
      return;
    }
    setState(() {
      _selectedFile = file.name;
      _selectedPath = file.path ?? file.name;
      _selectedBytes = file.bytes;
      _error = null;
    });
  }

  Future<void> _startUpload() async {
    final path = _selectedPath;
    if (path == null) return;
    setState(() { _isUploading = true; _error = null; });
    try {
      await widget.controller.uploadVoterRegister(
        path,
        bytes: _selectedBytes,
        fileName: _selectedFile,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() { _isUploading = false; _error = error.toString(); });
      return;
    }

    if (!mounted) return;
    setState(() => _isUploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voter register PDF uploaded successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.controller.assignment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Upload Register', style: AppTextStyles.sectionTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
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
                        Text('TARGET POLLING UNIT', style: AppTextStyles.inputLabel(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          assignment?.pollingUnitId ?? 'PU 0047',
                          style: AppTextStyles.sectionTitle(),
                        ),
                        Text(
                          assignment?.pollingUnitName ?? 'Gwarinpa Primary School',
                          style: AppTextStyles.bodySmall(),
                        ),
                        Text(
                          assignment != null ? '${assignment.wardAndLga}, ${assignment.state}' : '',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Text('Select Register PDF', style: AppTextStyles.sectionTitle()),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Upload the certified voter register document allocated to this polling station.',
                    style: AppTextStyles.subtitle(),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Upload box / File selector
                  InkWell(
                    onTap: _isUploading ? null : _selectFile,
                    borderRadius: AppBorderRadius.card,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppBorderRadius.card,
                        border: Border.all(
                          color: _selectedFile != null ? AppColors.primary : AppColors.border,
                          width: _selectedFile != null ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedFile != null ? Icons.picture_as_pdf : Icons.cloud_upload_outlined,
                            size: 40,
                            color: _selectedFile != null ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _selectedFile ?? 'Tap to select Voter Register PDF',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body().copyWith(
                              fontWeight: _selectedFile != null ? FontWeight.w600 : FontWeight.w400,
                              color: _selectedFile != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          if (_selectedFile == null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Supported format: PDF up to 25MB',
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  if (_error != null) ...[
                    Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.error)),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  PrimaryButton(
                    label: 'UPLOAD & TRANSMIT REGISTER',
                    isLoading: _isUploading,
                    loadingLabel: 'Uploading PDF...',
                    enabled: _selectedFile != null && !_isUploading,
                    onPressed: _startUpload,
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),

            if (_isUploading)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppBorderRadius.card,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Uploading Voter Register',
                          style: AppTextStyles.sectionTitle(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Streaming PDF directly to secure storage...',
                          style: AppTextStyles.body(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const LinearProgressIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.background,
                        ),
                        const SizedBox(height: 8),
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
}
