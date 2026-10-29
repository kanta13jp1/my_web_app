import 'package:flutter/material.dart';

/// 既存支出に含まれる未照合内訳の印。追加の支出ではない。
class AssetUnreconciledExpenseBadge extends StatelessWidget {
  const AssetUnreconciledExpenseBadge(
      {super.key, this.preserveTextScale = false});

  final bool preserveTextScale;

  @override
  Widget build(BuildContext context) {
    const row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.help_outline, size: 10, color: Color(0xFF92400E)),
        SizedBox(width: 2),
        Text(
          '不明',
          style: TextStyle(fontSize: 9, color: Color(0xFF92400E)),
        ),
      ],
    );
    return Tooltip(
      message: '使途不明金あり（内訳未照合・日別支出に含む）',
      child: preserveTextScale
          ? row
          : const FittedBox(fit: BoxFit.scaleDown, child: row),
    );
  }
}
