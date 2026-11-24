import 'package:flutter/material.dart';
import '../../pages/admin_dashboard_signals.dart';

class AdminComparisonCvrCard extends StatelessWidget {
  const AdminComparisonCvrCard({
    super.key,
    required this.comparisonTouches,
    required this.comparisonSignups,
    required this.loading,
    required this.onRefresh,
  });

  final Map<String, int> comparisonTouches;
  final int comparisonSignups;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFE5E7EB);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    final totalTouches = comparisonTouches.values.fold(0, (a, b) => a + b);
    // R30: 母数0で「0.0%」は計測した0%に見える捏造 → ダッシュボード共通の
    // formatRatePercent(母数0=「—」)に揃える。到達0で登録>0の自己矛盾表示も回避。
    final cvrLabel = formatRatePercent(comparisonSignups, totalTouches);

    final sorted = comparisonTouches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text(
                '比較ページ別 CVR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: onRefresh,
                  tooltip: '更新',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cvrStat(
                '総到達数',
                totalTouches.toString(),
                const Color(0xFFA78BFA),
              ),
              const SizedBox(width: 16),
              _cvrStat(
                '比較経由登録',
                comparisonSignups.toString(),
                const Color(0xFF059669),
              ),
              const SizedBox(width: 16),
              _cvrStat('CVR', cvrLabel, const Color(0xFFFF6B35)),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty && !loading)
            const Text(
              '比較ページへの到達データがまだありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                height: 1.6,
              ),
            )
          else
            ...sorted.take(14).map((e) {
              final pct = totalTouches > 0 ? e.value / totalTouches : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? const Color(0x1FE5E7EB)
                              : const Color(0xFF6366F1),
                          color: const Color(0xFF6366F1),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.value.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _cvrStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
