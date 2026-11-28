import 'package:flutter/material.dart';

class HomeMorningBriefingCard extends StatelessWidget {
  const HomeMorningBriefingCard({
    super.key,
    required this.onTap,
    this.isHighlighted = false,
    this.isVisible = true,
  });

  static const cardKey = Key('home_morning_briefing_card');

  final VoidCallback onTap;
  final bool isHighlighted;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final accent =
        isHighlighted ? const Color(0xFFFFA000) : const Color(0xFFFFC107);

    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              const Color(0xFFFFC107)
                  .withValues(alpha: isHighlighted ? 0.2 : 0.09),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isHighlighted ? 0.18 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        leading: CircleAvatar(
          backgroundColor: accent,
          radius: 26,
          child: const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
        ),
        title: Text(
          isHighlighted ? 'モーニング・ブリーフィング（最優先）' : 'モーニング・ブリーフィング',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          isHighlighted ? 'まず朝の優先順位を固定してください。' : '今日のタスクと優先順位を確認します。',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
