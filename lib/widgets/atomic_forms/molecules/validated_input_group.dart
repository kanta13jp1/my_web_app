import 'package:flutter/material.dart';

import '../atoms/focus_blur_text_field.dart';

/// ラベル・必須表示・補助説明・Blur即時検証を組み合わせた Molecule 入力グループ (#2730)。
class ValidatedInputGroup extends StatelessWidget {
  const ValidatedInputGroup({
    super.key,
    required this.label,
    this.requiredField = false,
    this.helperText,
    this.fieldKey,
    this.controller,
    this.focusNode,
    this.validator,
    this.hintText,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool requiredField;
  final String? helperText;
  final GlobalKey<FocusBlurTextFieldState>? fieldKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String value)? validator;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final helper = helperText;
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (requiredField) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '必須',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FocusBlurTextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            validator: validator,
            hintText: hintText,
            keyboardType: keyboardType,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: onChanged,
            enabled: enabled,
          ),
          if (helper != null && helper.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
