import 'package:flutter/material.dart';

/// 既存支出に含まれる未照合内訳の印。追加の支出ではない。
class AssetUnreconciledExpenseBadge extends StatelessWidget {
  const AssetUnreconciledExpenseBadge({
    super.key,
    this.preserveTextScale = false,
  });

  final bool preserveTextScale;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.help_outline, size: 10, color: foreground),
        const SizedBox(width: 2),
        Text(
          '不明',
          style: TextStyle(
            fontSize: 10,
            height: 1.4,
            color: foreground,
          ),
        ),
      ],
    );
    return Tooltip(
      message: '使途不明金あり（内訳未照合・日別支出に含む）',
      child: preserveTextScale
          ? row
          : FittedBox(fit: BoxFit.scaleDown, child: row),
    );
  }
}
