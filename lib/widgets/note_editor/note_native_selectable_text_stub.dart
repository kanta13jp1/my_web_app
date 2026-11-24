import 'package:flutter/material.dart';

typedef NoteNativeSelectionCallback = void Function(
  String selectedText,
  TextSelection? selection,
);

/// 非Web環境向けのテキスト選択ビュー（実機iOSではWeb実装が使われる）。
class NoteNativeSelectableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color backgroundColor;
  final Color textColor;
  final NoteNativeSelectionCallback onSelectionChanged;

  const NoteNativeSelectableText({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.onSelectionChanged,
    this.style,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? const TextStyle(fontSize: 16, height: 1.7);
    final effectiveStyle = baseStyle.copyWith(color: textColor);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.16),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          key: const Key('note_native_selectable_text'),
          style: effectiveStyle,
          onSelectionChanged: (selection, _) {
            if (!selection.isValid || selection.isCollapsed) {
              return;
            }
            final start = selection.start.clamp(0, text.length);
            final end = selection.end.clamp(start, text.length);
            if (end > start) {
              onSelectionChanged(text.substring(start, end), selection);
            }
          },
        ),
      ),
    );
  }
}
