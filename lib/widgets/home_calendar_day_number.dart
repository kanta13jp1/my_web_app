import 'package:flutter/material.dart';

/// Day-number presentation; selection and calendar data remain in Home.
class HomeCalendarDayNumber extends StatelessWidget {
  const HomeCalendarDayNumber({
    super.key,
    required this.day,
    required this.isCurrentMonth,
    required this.matchesFilter,
    required this.isUnset,
    required this.isDark,
    required this.accentColor,
  });

  final int day;
  final bool isCurrentMonth;
  final bool matchesFilter;
  final bool isUnset;
  final bool isDark;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$day',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: isCurrentMonth
            ? matchesFilter
                ? (isUnset
                    ? (isDark
                        ? Colors.white.withValues(
                            alpha: 0.7,
                          )
                        : const Color(0xDE000000))
                    : accentColor)
                : isDark
                    ? const Color(0xFF666666)
                    : const Color(0xFFB0B0B0)
            : const Color(0xFFB0B0B0),
        height: 1.5,
      ),
    );
  }
}
