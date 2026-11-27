import 'package:flutter/material.dart';

/// Presentation only; Home owns highlight selection.
class HomeCalendarSummaryPill extends StatelessWidget {
  const HomeCalendarSummaryPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.interactionKey,
    required this.onTap,
  });
  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final String interactionKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key(interactionKey),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 0.24 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: color.withValues(alpha: isSelected ? 0.38 : 0.18),
              ),
            ),
            child: Text(
              '$label $value',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
