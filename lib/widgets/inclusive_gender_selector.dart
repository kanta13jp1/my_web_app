import 'package:flutter/material.dart';

class InclusiveGenderSelector extends StatelessWidget {
  const InclusiveGenderSelector({
    super.key,
    required this.controller,
    this.maxLength = 30,
  });

  final TextEditingController controller;
  final int maxLength;

  static const String unansweredLabel = '回答しない';
  static const List<String> inclusivePresets = <String>[
    unansweredLabel,
    '女性',
    '男性',
    'ノンバイナリー',
    'その他',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final current = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                '性別・ジェンダー表記（任意・回答しない選択可）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in inclusivePresets)
                  _buildOptionChip(
                    context: context,
                    option: option,
                    selected: option == unansweredLabel
                        ? current.isEmpty
                        : current == option,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('inclusive_gender_text_field'),
              controller: controller,
              maxLength: maxLength,
              decoration: const InputDecoration(
                labelText: '性別（任意・自由記述可）',
                hintText: '回答しない / 女性 / 男性 / ノンバイナリー / 自由入力',
                prefixIcon: Icon(Icons.wc_outlined),
                border: OutlineInputBorder(),
                helperText: '空欄のままでも保存できます。多様な選択肢や自由表記に対応しています。',
              ),
              validator: (input) {
                if (input != null && input.trim().length > maxLength) {
                  return '性別は$maxLength文字以内で入力してください';
                }
                return null;
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionChip({
    required BuildContext context,
    required String option,
    required bool selected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        selected ? colorScheme.primaryContainer : colorScheme.surface;
    final textColor =
        selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final borderColor = selected ? colorScheme.primary : colorScheme.outline;

    return Semantics(
      button: true,
      selected: selected,
      label: '性別選択肢: $option',
      child: ChoiceChip(
        key: Key('inclusive_gender_chip_$option'),
        label: Text(
          option,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        backgroundColor: bgColor,
        selectedColor: bgColor,
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1.0),
        onSelected: (_) {
          if (option == unansweredLabel) {
            controller.clear();
          } else {
            controller.text = option;
          }
        },
      ),
    );
  }
}
