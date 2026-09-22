import 'package:flutter/material.dart';

class HedraBatchSelector extends StatelessWidget {
  const HedraBatchSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '動画の生成バリエーション数',
      value: '$value件',
      child: DropdownButtonFormField<int>(
        key: const Key('hedra-batch-size-dropdown'),
        initialValue: value,
        decoration: const InputDecoration(
          labelText: '生成バリエーション数（1〜8）',
          helperText: '複数件はHedraクレジット消費と待ち時間が件数に応じて増えます',
          border: OutlineInputBorder(),
        ),
        items: List.generate(
          8,
          (index) => DropdownMenuItem<int>(
            value: index + 1,
            child: Text('${index + 1}件'),
          ),
        ),
        onChanged: enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
      ),
    );
  }
}
