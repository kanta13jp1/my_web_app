import 'package:flutter/material.dart';

class HomePrimaryActionCard extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String detail;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? aiNudge;
  final bool isAiNudgeLoading;
  final int pendingCriticalTaskCount;
  final int pendingStockTaskCount;

  const HomePrimaryActionCard({
    super.key,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.onPressed,
    this.aiNudge,
    this.isAiNudgeLoading = false,
    this.pendingCriticalTaskCount = 0,
    this.pendingStockTaskCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
      isDark ? const Color(0xFF1A1A1A) : Colors.white,
    );
    final textColor = isDark ? Colors.white : const Color(0xDE000000);
    final buttonForeground =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? Colors.white
            : const Color(0xFF111827);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.02 : 0.55),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.16 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日の1件',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AIの提案: $detail',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.88),
                    height: 1.5,
                  ),
                ),
                if (isAiNudgeLoading) ...[
                  const SizedBox(height: 4),
                  Text(
                    'AIが補足を考えています…',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.72),
                      height: 1.5,
                    ),
                  ),
                ],
                if (aiNudge != null && aiNudge!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    aiNudge!,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ],
                if (pendingCriticalTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の必須タスク: $pendingCriticalTaskCount件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ],
                if (pendingStockTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の週末ストック: $pendingStockTaskCount件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: buttonForeground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
