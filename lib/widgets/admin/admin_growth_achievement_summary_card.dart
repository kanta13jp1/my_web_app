import 'package:flutter/material.dart';
import '../../pages/admin_dashboard_signals.dart';

class AdminGrowthAchievementSummaryCard extends StatelessWidget {
  const AdminGrowthAchievementSummaryCard({
    super.key,
    required this.summary,
    required this.loading,
    required this.onRefresh,
    required this.onSelectPeriod,
  });

  final Map<String, dynamic>? summary;
  final bool loading;
  final VoidCallback onRefresh;
  final void Function(String since, String label) onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFE5E7EB);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    final periods = [
      (
        '今日',
        DateTime.now()
            .copyWith(hour: 0, minute: 0, second: 0)
            .toIso8601String(),
      ),
      (
        '今週',
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      ),
      (
        '今月',
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      ),
      ('すべて', '2020-01-01T00:00:00Z'),
    ];

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
              const Icon(Icons.trending_up, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'グロース実績サマリー',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
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
                  tooltip: '再読み込み',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Period selector
          Wrap(
            spacing: 8,
            children: periods.map((p) {
              final (lbl, since) = p;
              return ActionChip(
                label: Text(
                  lbl,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () => onSelectPeriod(since, lbl),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (summary == null && !loading)
            const Text(
              'データなし',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.6,
              ),
            )
          // R30: 期待するメトリクスキーが無いレスポンス(achievement.list は
          // items のみ返す)では捏造ゼロを出さず、集計未接続を正直に示す。
          else if (!growthSummaryHasMetrics(summary) && !loading)
            const Text(
              '成長サマリーの集計はまだ接続されていません。'
              '各カード(登録目標・累計登録・比較CVR等)で実数をご確認ください。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.6,
              ),
            )
          else if (growthSummaryHasMetrics(summary)) ...[
            Text(
              '期間: ${summary!['label'] ?? 'すべて'}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _growthStatRow(
              '新規ユーザー',
              '${summary!['newUsers'] ?? 0}人',
              const Color(0xFF6366F1),
            ),
            _growthStatRow(
              '累計ユーザー',
              '${summary!['totalUsersEver'] ?? 0}人',
              const Color(0xFF10B981),
            ),
            _growthStatRow(
              '成長シグナル',
              '${summary!['acquisitionSignals'] ?? 0}件',
              const Color(0xFFF59E0B),
            ),
            _growthStatRow(
              '紹介成立',
              '${summary!['referralsCompleted'] ?? 0}件',
              const Color(0xFFEC4899),
            ),
            _growthStatRow(
              'インポート試行',
              '${summary!['importPreviews'] ?? 0}件',
              const Color(0xFF0EA5E9),
            ),
          ],
        ],
      ),
    );
  }

  Widget _growthStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
