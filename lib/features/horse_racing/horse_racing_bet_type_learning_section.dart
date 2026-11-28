import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'horse_racing_performance_view_model.dart';

/// 券種別学習AIセクション（的中率・日次学習推移・過去レース学習データ）。
class HorseRacingBetTypeLearningSection extends StatelessWidget {
  const HorseRacingBetTypeLearningSection({
    super.key,
    required this.betTypeAccuracy,
    required this.learning,
    required this.performance,
    required this.isPredicting,
    required this.onRefreshAccuracyLearning,
    required this.onRunLearningBackfill,
  });

  final List<Map<String, Object?>> betTypeAccuracy;
  final Map<String, Object?> learning;
  final HorseRacingPerformanceViewModel performance;
  final bool isPredicting;
  final VoidCallback onRefreshAccuracyLearning;
  final VoidCallback onRunLearningBackfill;

  static final NumberFormat _yenFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final dailyAccuracy = _mapList(learning['daily_accuracy']);
    final backfillStatus = _mapList(learning['backfill_status']);
    final placeRow =
        betTypeAccuracy.where((r) => r['bet_type'] == '複勝').firstOrNull;
    final wideRow =
        betTypeAccuracy.where((r) => r['bet_type'] == 'ワイド').firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '券種別学習AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton.icon(
                onPressed: isPredicting ? null : onRefreshAccuracyLearning,
                icon: const Icon(Icons.model_training, size: 16),
                label: const Text('結果分析を更新'),
              ),
              TextButton.icon(
                onPressed: isPredicting ? null : onRunLearningBackfill,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('過去21日を学習'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (betTypeAccuracy.isEmpty)
            const Text(
              '結果取得後に、購入しない判断・単勝・複勝・枠連・馬連・ワイド・馬単・3連複・3連単の的中率を自動集計します。',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
                height: 1.5,
              ),
            )
          else ...[
            if (placeRow != null || wideRow != null) ...[
              Row(
                children: [
                  if (placeRow != null)
                    Expanded(
                      child: _LearningStatCard(
                        title: '複勝命中率',
                        value:
                            '${(placeRow['hit_rate_pct'] as num?)?.toStringAsFixed(1) ?? '-'}%',
                        icon: Icons.trending_up,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  if (placeRow != null && wideRow != null)
                    const SizedBox(width: 8),
                  if (wideRow != null)
                    Expanded(
                      child: _LearningStatCard(
                        title: 'ワイド命中率',
                        value:
                            '${(wideRow['hit_rate_pct'] as num?)?.toStringAsFixed(1) ?? '-'}%',
                        icon: Icons.expand,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final row in betTypeAccuracy)
                  _BetTypeAccuracyCard(
                    row: row,
                    evidence: performance.betTypes
                        .where(
                          (item) => item.betType == row['bet_type']?.toString(),
                        )
                        .firstOrNull,
                    yenFormatter: _formatYen,
                  ),
              ],
            ),
          ],
          if (learning.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              performance.rankingOnHold
                  ? '参考指標: データ不足のため券種ランキングと購入推奨を保留中'
                  : '参考指標: ${learning['best_low_risk_bet_type'] ?? '集計中'} の統計を継続観測中（購入推奨ではありません）',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                height: 1.5,
              ),
            ),
            if (dailyAccuracy.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DailyLearningTrend(rows: dailyAccuracy),
            ],
            if (backfillStatus.isNotEmpty) ...[
              const SizedBox(height: 10),
              _BackfillCoverage(rows: backfillStatus),
            ],
          ],
        ],
      ),
    );
  }

  static String _formatYen(int value) => '¥${_yenFormat.format(value)}';

  static List<Map<String, Object?>> _mapList(Object? value) {
    if (value is List) {
      return value
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => item.map(
              (key, val) => MapEntry(key.toString(), val),
            ),
          )
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

num? _numValue(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

class _LearningStatCard extends StatelessWidget {
  const _LearningStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
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
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyLearningTrend extends StatelessWidget {
  const _DailyLearningTrend({required this.rows});

  final List<Map<String, Object?>> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日次学習推移',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final row in visibleRows) ...[
                _DailyLearningCard(row: row),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyLearningCard extends StatelessWidget {
  const _DailyLearningCard({required this.row});

  final Map<String, Object?> row;

  @override
  Widget build(BuildContext context) {
    final date = row['race_date']?.toString() ?? '-';
    final races = _numValue(row['evaluated_races'])?.toInt() ?? 0;
    final score = _numValue(row['avg_learning_score'])?.toDouble() ?? 0;
    final place = _numValue(row['place_hit_rate_pct'])?.toDouble();
    final wide = _numValue(row['wide_hit_rate_pct'])?.toDouble();
    final skip = _numValue(row['skip_accuracy_pct'])?.toDouble();
    final placeLabel = place == null ? '-' : '${place.toStringAsFixed(0)}%';
    final wideLabel = wide == null ? '-' : '${wide.toStringAsFixed(0)}%';
    final skipLabel = skip == null ? '-' : '${skip.toStringAsFixed(0)}%';

    return Container(
      width: 154,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '学習スコア ${score.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF93C5FD),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          Text(
            '$racesレース評価',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '複勝 $placeLabel / ワイド $wideLabel',
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          Text(
            '見送り $skipLabel',
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackfillCoverage extends StatelessWidget {
  const _BackfillCoverage({required this.rows});

  final List<Map<String, Object?>> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '過去レース学習データ',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        for (final row in visibleRows) _BackfillCoverageRow(row: row),
      ],
    );
  }
}

class _BackfillCoverageRow extends StatelessWidget {
  const _BackfillCoverageRow({required this.row});

  final Map<String, Object?> row;

  @override
  Widget build(BuildContext context) {
    final date = row['race_date']?.toString() ?? '-';
    final source = row['source']?.toString() ?? '-';
    final races = _numValue(row['races'])?.toInt() ?? 0;
    final results = _numValue(row['races_with_results'])?.toInt() ?? 0;
    final predicted = _numValue(row['baseline_predictions'])?.toInt() ?? 0;
    final evaluated = _numValue(row['baseline_evaluated_races'])?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$date / $source',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '結果$results/$races  予想$predicted  評価$evaluated',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BetTypeAccuracyCard extends StatelessWidget {
  const _BetTypeAccuracyCard({
    required this.row,
    required this.evidence,
    required this.yenFormatter,
  });

  final Map<String, Object?> row;
  final HorseRacingBetTypeEvidence? evidence;
  final String Function(int value) yenFormatter;

  @override
  Widget build(BuildContext context) {
    final betType = row['bet_type']?.toString() ?? '-';
    final total = (row['total_predictions'] as num?)?.toInt() ?? 0;
    final hits = (row['hits'] as num?)?.toInt() ?? 0;
    final rate = (row['hit_rate_pct'] as num?)?.toDouble() ?? 0;
    final roiLabel = evidence?.roiPercent == null
        ? '算出不可'
        : '${evidence!.roiPercent!.toStringAsFixed(1)}%';
    final color = rate >= 50
        ? const Color(0xFF4CAF50)
        : rate >= 25
            ? const Color(0xFFFFC107)
            : const Color(0xFFFF6B35);

    return Container(
      width: 184,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            betType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${rate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          Text(
            '$hits / $total 的中（母数 $total）',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          Text(
            '95%信頼区間 ${evidence?.confidenceInterval?.label ?? '算出不可'}',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          Text(
            '投下 ${yenFormatter(evidence?.stakeYen ?? 0)} / '
            'ROI $roiLabel',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
