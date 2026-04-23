import 'package:flutter/material.dart';

import '../services/ai_hub_chat_service.dart';

class AiResponseObservabilityPanel extends StatelessWidget {
  final AiHubChatObservability observability;
  final bool isDark;
  final Color accentColor;
  final String? fallbackLabel;

  const AiResponseObservabilityPanel({
    super.key,
    required this.observability,
    required this.isDark,
    this.accentColor = const Color(0xFF0F766E),
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_ChipData>[
      _ChipData(
        label: fallbackLabel ?? observability.provider,
        icon: Icons.hub_outlined,
      ),
      if (observability.model != null)
        _ChipData(
          label: observability.model!,
          icon: Icons.memory_outlined,
        ),
      if (observability.latencyMs != null)
        _ChipData(
          label: '${observability.latencyMs} ms',
          icon: Icons.timer_outlined,
        ),
      if (observability.estimatedCostUsd != null)
        _ChipData(
          label: '\$${observability.estimatedCostUsd!.toStringAsFixed(4)}',
          icon: Icons.attach_money_outlined,
        ),
      if (observability.inputChars != null || observability.outputChars != null)
        _ChipData(
          label:
              'in ${observability.inputChars ?? 0} / out ${observability.outputChars ?? 0}',
          icon: Icons.swap_horiz_outlined,
        ),
      if (observability.shortTraceId != null)
        _ChipData(
          label: 'trace ${observability.shortTraceId}',
          icon: Icons.route_outlined,
        ),
      if (observability.shortSessionId != null)
        _ChipData(
          label: 'session ${observability.shortSessionId}',
          icon: Icons.timeline_outlined,
        ),
    ];

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final background = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : accentColor.withValues(alpha: 0.05);
    final textColor =
        isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF334155);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 15, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'AI observability',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) => _ObservabilityChip(
                    chip: chip,
                    accentColor: accentColor,
                    isDark: isDark,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ObservabilityChip extends StatelessWidget {
  final _ChipData chip;
  final Color accentColor;
  final bool isDark;

  const _ObservabilityChip({
    required this.chip,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? accentColor.withValues(alpha: 0.14)
        : accentColor.withValues(alpha: 0.10);
    final border = accentColor.withValues(alpha: isDark ? 0.30 : 0.18);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            chip.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipData {
  final String label;
  final IconData icon;

  const _ChipData({
    required this.label,
    required this.icon,
  });
}
