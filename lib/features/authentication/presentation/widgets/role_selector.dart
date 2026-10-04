// lib/features/authentication/presentation/widgets/role_selector.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/user_role.dart';

/// Dropdown selector for user role — only shows registerable roles.
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final UserRole? selectedRole;
  final ValueChanged<UserRole?> onChanged;
  final FormFieldValidator<UserRole>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final roles = UserRoleExtension.registrationRoles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ROLE', style: AppTextStyles.inputLabel()),
        const SizedBox(height: AppSpacing.xs + 2),
        DropdownButtonFormField<UserRole>(
          initialValue: selectedRole,
          onChanged: enabled ? onChanged : null,
          validator: validator != null
              ? (v) => validator!(v)
              : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          style: AppTextStyles.inputText(),
          decoration: InputDecoration(
            hintText: 'Select your role',
            hintStyle: AppTextStyles.inputText(color: AppColors.textPlaceholder),
            prefixIcon: const IconTheme(
              data: IconThemeData(color: AppColors.textSecondary, size: 20),
              child: Icon(Icons.badge_outlined),
            ),
            filled: true,
            fillColor: enabled ? AppColors.surface : AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.input,
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle: AppTextStyles.errorText(),
          ),
          items: roles.map((role) {
            return DropdownMenuItem<UserRole>(
              value: role,
              child: Text(
                role.displayName,
                style: AppTextStyles.inputText(),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
