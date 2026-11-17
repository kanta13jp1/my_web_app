import 'package:flutter/material.dart';

/// Renders supplied status colors; Home owns the status conditions.
class HomeCalendarDayIndicators extends StatelessWidget {
  HomeCalendarDayIndicators({
    super.key,
    required Iterable<Color> colors,
    required this.isEmphasized,
  }) : colors = List.unmodifiable(colors);

  final List<Color> colors;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final color in colors)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isEmphasized ? color : color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
