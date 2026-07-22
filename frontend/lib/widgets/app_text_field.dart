// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : app_text_field.dart
// Description     : Shared labeled text-field widget wrapping a TextFormField with validation.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Label + `TextFormField` + validator, wrapping the pattern repeated
/// identically across register/login/reset/edit-profile/create-listing
/// screens (a `Semantics(label:)` + caption `Text` + field).
class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final int maxLines;
  final void Function(String)? onChanged;

  const LabeledTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            hintText: hintText,
          ),
        ),
      ],
    );
  }
}
