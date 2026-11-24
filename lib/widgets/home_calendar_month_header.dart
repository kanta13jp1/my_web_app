import 'package:flutter/material.dart';

/// Calendar presentation only; Home owns the month selection and loading.
class HomeCalendarMonthHeader extends StatelessWidget {
  const HomeCalendarMonthHeader({
    super.key,
    required this.currentMonthLabel,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String currentMonthLabel;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_month, color: Color(0xFFB0B0B0)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '継続カレンダー $currentMonthLabel',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('home_calendar_month_prev'),
          tooltip: '前月',
          visualDensity: VisualDensity.compact,
          onPressed: onPreviousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const Key('home_calendar_month_next'),
          tooltip: '翌月',
          visualDensity: VisualDensity.compact,
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
