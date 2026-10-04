// lib/features/authentication/presentation/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../controllers/auth_controller.dart';
import '../../models/registration_form.dart';
import '../../models/user_model.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_field.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';

/// Registration screen — claim a pre-assigned User ID with a password.
///
/// Flow:
///   1. User enters their pre-assigned User ID.
///   2. System looks up the ID and displays the associated name.
///   3. If recognised → user sets a password and confirms it.
///   4. Submitting creates the account.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.authController});
  final AuthController authController;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _userIdFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Lookup state
  _LookupState _lookupState = _LookupState.idle;
  String? _foundName; // name returned from lookup
  String? _serverError;

  AuthController get _auth => widget.authController;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _userIdFocusNode.addListener(_onUserIdFocusLost);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _userIdFocusNode.removeListener(_onUserIdFocusLost);
    _userIdFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ─── ID Lookup ─────────────────────────────────────────────────────────────

  /// Triggered when the User ID field loses focus (or user taps Continue).
  void _onUserIdFocusLost() {
    if (!_userIdFocusNode.hasFocus) {
      _performLookup();
    }
  }

  Future<void> _performLookup() async {
    final id = _userIdController.text.trim();

    // Don't look up if ID is too short / clearly invalid
    if (id.length < 4) {
      setState(() {
        _lookupState = _LookupState.idle;
        _foundName = null;
      });
      return;
    }

    setState(() {
      _lookupState = _LookupState.loading;
      _foundName = null;
      _serverError = null;
    });

    final name = await _auth.lookupUserId(id);

    if (!mounted) return;

    if (name != null) {
      setState(() {
        _lookupState = _LookupState.found;
        _foundName = name;
      });
      // Move focus to password field
      _passwordFocusNode.requestFocus();
    } else {
      setState(() {
        _lookupState = _LookupState.notFound;
        _foundName = null;
      });
    }
  }

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _onCreateAccount() async {
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);

    if (_lookupState != _LookupState.found) {
      await _performLookup();
      if (_lookupState != _LookupState.found) return;
    }

    if (!_formKey.currentState!.validate()) return;

    final form = RegistrationForm(
      userId: _userIdController.text.trim(),
      fullName: _foundName!,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    final UserModel? user = await _auth.register(form: form);

    if (!mounted) return;

    if (user != null) {
      Navigator.of(context).pushReplacementNamed(
        RouteNames.registrationSuccess,
        arguments: user,
      );
    } else {
      setState(() => _serverError = _auth.errorMessage);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth < 390
        ? AppSpacing.horizontalPaddingSmall
        : AppSpacing.horizontalPaddingLarge;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text('Create Account', style: AppTextStyles.sectionTitle()),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _auth,
          builder: (context, child) {
            final isLoading = _auth.isLoading;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPadding),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      'Enter your pre-assigned User ID to claim your account.',
                      style: AppTextStyles.subtitle(),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── User ID + lookup ────────────────────────────────────
                    AuthTextField(
                      label: 'User ID',
                      hint: 'e.g. ERS-0001',
                      controller: _userIdController,
                      focusNode: _userIdFocusNode,
                      autofocus: true,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      suffixIcon: _buildUserIdSuffix(),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      onChanged: (val) {
                        // Reset lookup state whenever the user edits the ID
                        setState(() {
                          _lookupState = _LookupState.idle;
                          _foundName = null;
                          _serverError = null;
                        });
                      },
                      onFieldSubmitted: (_) => _performLookup(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'User ID is required.';
                        }
                        if (v.trim().length < 4) {
                          return 'User ID must be at least 4 characters.';
                        }
                        if (_lookupState != _LookupState.found) {
                          return 'Please verify your User ID first.';
                        }
                        return null;
                      },
                    ),

                    // ── Lookup result banner ────────────────────────────────
                    _buildLookupBanner(),

                    // ── Password fields (only shown when ID is verified) ─────
                    if (_lookupState == _LookupState.found) ...[
                      const SizedBox(height: AppSpacing.xxl),

                      // Divider
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            color: AppColors.primary,
                            margin: const EdgeInsets.only(right: AppSpacing.sm),
                          ),
                          Text(
                            'SET YOUR PASSWORD',
                            style: AppTextStyles.inputLabel().copyWith(
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Divider(color: AppColors.border, thickness: 1),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      PasswordField(
                        label: 'Password',
                        hint: 'Enter 6 alphanumeric characters',
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required.';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(v)) {
                            return 'Password must be 6 alphanumeric characters.';
                          }
                          return null;
                        },
                      ),

                      PasswordStrengthIndicator(
                        password: _passwordController.text,
                      ),

                      const SizedBox(height: AppSpacing.fieldGap),

                      PasswordField(
                        label: 'Confirm Password',
                        hint: 'Confirm your password',
                        controller: _confirmPasswordController,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        onFieldSubmitted: (_) => _onCreateAccount(),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password.';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                    ],

                    // ── Server error ────────────────────────────────────────
                    if (_serverError != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ErrorBanner(message: _serverError!),
                    ],

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Primary action button ───────────────────────────────
                    _buildActionButton(isLoading),

                    const SizedBox(height: AppSpacing.xxl),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: AppTextStyles.bodySmall(),
                          ),
                          SecondaryButton(
                            label: 'Login',
                            onPressed: isLoading
                                ? null
                                : () => Navigator.of(context)
                                    .pushReplacementNamed(RouteNames.login),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Sub-builders ──────────────────────────────────────────────────────────

  Widget? _buildUserIdSuffix() {
    switch (_lookupState) {
      case _LookupState.loading:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _LookupState.found:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20);
      case _LookupState.notFound:
        return const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
      case _LookupState.idle:
        return null;
    }
  }

  Widget _buildLookupBanner() {
    switch (_lookupState) {
      case _LookupState.found:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'User ID recognised',
                        style: AppTextStyles.caption(color: AppColors.success),
                      ),
                      Text(
                        _foundName!,
                        style: AppTextStyles.body().copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case _LookupState.notFound:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'User ID not recognised. Please check and try again, or contact your administrator.',
                    style: AppTextStyles.bodySmall(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        );

      case _LookupState.loading:
      case _LookupState.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton(bool isLoading) {
    // Show "Look Up" when ID hasn't been verified yet
    if (_lookupState == _LookupState.idle ||
        _lookupState == _LookupState.notFound) {
      return PrimaryButton(
        label: 'LOOK UP USER ID',
        isLoading: _lookupState == _LookupState.loading,
        loadingLabel: 'Looking up...',
        enabled: _userIdController.text.trim().length >= 4,
        onPressed: _performLookup,
      );
    }

    if (_lookupState == _LookupState.loading) {
      return PrimaryButton(
        label: 'LOOK UP USER ID',
        isLoading: true,
        loadingLabel: 'Looking up...',
        onPressed: null,
      );
    }

    // ID verified → show Create Account
    return PrimaryButton(
      label: 'CREATE ACCOUNT',
      loadingLabel: 'Creating account...',
      isLoading: isLoading,
      enabled: true,
      onPressed: _onCreateAccount,
    );
  }
}

// ─── Lookup state enum ─────────────────────────────────────────────────────
enum _LookupState { idle, loading, found, notFound }

// ─── Error banner ──────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
