import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A day-cell amount label; data loading and aggregation remain in Home.
class HomeCalendarCashflowLine extends StatelessWidget {
  const HomeCalendarCashflowLine({
    super.key,
    required this.textKey,
    required this.label,
    required this.amount,
    required this.color,
    required this.sign,
    required this.isEmphasized,
  });
  final Key textKey;
  final String label;
  final int amount;
  final Color color;
  final String sign;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final textColor = isEmphasized ? color : color.withValues(alpha: 0.74);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        '$label $sign${_formatCalendarCashflowAmount(amount)}',
        key: textKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.6,
        ),
      ),
    );
  }

  String _formatCalendarCashflowAmount(int value) {
    final absValue = value.abs();
    if (absValue >= 10000) {
      final man = absValue / 10000;
      final digits = man >= 100 ? 0 : 1;
      return '${man.toStringAsFixed(digits)}万';
    }
    return NumberFormat('#,##0', 'ja_JP').format(absValue);
  }
}
