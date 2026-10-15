import 'package:flutter/material.dart';
import '../services/asset_spending_attention_calendar.dart';

class AssetAttentionDayLabel extends StatelessWidget {
  const AssetAttentionDayLabel({super.key, required this.day});
  final AssetSpendingAttentionDay day;
  static const background = Color(0xFFFFF4CC);
  @override
  Widget build(BuildContext context) => day.isAttentionDay
      ? Tooltip(message: day.description, child: Semantics(label: day.description,
          child: const Text('注意', maxLines: 1,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF78350F)))))
      : const SizedBox.shrink();
}
