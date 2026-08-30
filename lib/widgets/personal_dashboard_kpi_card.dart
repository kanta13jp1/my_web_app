import 'package:flutter/material.dart';

/// A KPI card whose contents scale down together when copy or values grow.
///
/// The dashboard uses a fixed-aspect-ratio grid, so allowing an inner Column to
/// choose an unconstrained height can otherwise produce a RenderFlex overflow.
class PersonalDashboardKpiCard extends StatelessWidget {
  const PersonalDashboardKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final semanticLabel = <String>[
      label,
      value,
      if (subtitle != null) subtitle!,
    ].join('、');

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              alignment: Alignment.topLeft,
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
