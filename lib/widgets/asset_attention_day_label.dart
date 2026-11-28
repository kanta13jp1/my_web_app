import 'package:flutter/material.dart';
import '../services/asset_spending_attention_calendar.dart';

class AssetAttentionDayLabel extends StatelessWidget {
  const AssetAttentionDayLabel({super.key, required this.day});
  final AssetSpendingAttentionDay day;
  static const background = Color(0xFFFFF4CC);

  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF3B2F0B) : background;

  @override
  Widget build(BuildContext context) {
    if (!day.isAttentionDay) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: day.description,
      child: Semantics(
        label: day.description,
        child: Text(
          '注意',
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            height: 1.4,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
          ),
        ),
      ),
    );
  }
}
