import 'package:flutter/material.dart';

/// Calendar cell decoration; Home owns interaction and supplied day content.
class HomeCalendarDaySurface extends StatelessWidget {
  const HomeCalendarDaySurface({
    super.key,
    required this.accentColor,
    required this.isToday,
    required this.isCurrentMonth,
    required this.matchesFilter,
    required this.hasSlip,
    required this.isClean,
    required this.isUnset,
    required this.child,
  });

  final Color accentColor;
  final bool isToday;
  final bool isCurrentMonth;
  final bool matchesFilter;
  final bool hasSlip;
  final bool isClean;
  final bool isUnset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isCurrentMonth
        ? matchesFilter
            ? accentColor.withValues(
                alpha: hasSlip
                    ? 0.18
                    : isClean
                        ? 0.14
                        : isUnset
                            ? 0.08
                            : 0.1,
              )
            : const Color(0xFFB0B0B0).withValues(alpha: 0.035)
        : const Color(0xFFB0B0B0).withValues(alpha: 0.05);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? const Color(0xFF6366F1)
              : isCurrentMonth
                  ? matchesFilter
                      ? accentColor.withValues(alpha: 0.22)
                      : const Color(0xFFB0B0B0).withValues(alpha: 0.08)
                  : Colors.transparent,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: child,
    );
  }
}
