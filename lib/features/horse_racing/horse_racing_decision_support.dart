import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'horse_racing_performance_view_model.dart';

class HorseRacingResponsibleUseCard extends StatelessWidget {
  const HorseRacingResponsibleUseCard({
    required this.dailyBudgetYen,
    required this.paused,
    required this.onBudgetChanged,
    required this.onPauseChanged,
    super.key,
  });

  static const budgetOptions = <int>[500, 1000, 2000, 3000, 5000, 10000];

  final int dailyBudgetYen;
  final bool paused;
  final ValueChanged<int> onBudgetChanged;
  final ValueChanged<bool> onPauseChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('horse-racing-responsible-use-card'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '責任ある利用：AI予測は購入を勧めず、結果を保証しません',
                  style: TextStyle(
                    color: Color(0xFFFDE68A),
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '損失の可能性があります。生活費を使わず、先に1日の予算上限を決め、迷う場合は購入を休止してください。',
                  style: TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<int>(
              key: const Key('horse-racing-budget-limit'),
              initialValue: dailyBudgetYen,
              decoration: const InputDecoration(
                labelText: '1日の予算上限',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final amount in budgetOptions)
                  DropdownMenuItem(
                    value: amount,
                    child: Text('¥${NumberFormat('#,###').format(amount)}'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onBudgetChanged(value);
              },
            ),
          ),
          OutlinedButton.icon(
            key: const Key('horse-racing-pause-action'),
            onPressed: () => onPauseChanged(!paused),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause_circle_outline),
            label: Text(paused ? '休止を解除' : '今日は購入しない'),
            style: OutlinedButton.styleFrom(
              foregroundColor: paused
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFDE68A),
            ),
          ),
          if (paused)
            const Chip(
              key: Key('horse-racing-paused-chip'),
              avatar: Icon(Icons.lock_clock, size: 16),
              label: Text('購入記録を休止中'),
            ),
        ],
      ),
    );
  }
}

class HorseRacingEvidencePanel extends StatelessWidget {
  const HorseRacingEvidencePanel({required this.summary, super.key});

  final HorseRacingPerformanceViewModel summary;

  @override
  Widget build(BuildContext context) {
    final roi = summary.roiPercent;
    final predicted = summary.predictedProbabilityPercent;
    final gap = summary.calibrationGapPoints;
    final interval = summary.confidenceInterval;
    return Container(
      key: const Key('horse-racing-evidence-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (summary.rankingOnHold
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF60A5FA))
                  .withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.rankingOnHold
                ? 'データ不足のためランキング・購入推奨を保留'
                : '成績は参考情報です（購入推奨・結果保証ではありません）',
            style: TextStyle(
              color: summary.rankingOnHold
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFBFDBFE),
              fontWeight: FontWeight.bold,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('期間', summary.periodLabel),
              _metric('投下額', _yen(summary.totalStakeYen)),
              _metric('払戻額', _yen(summary.totalPayoutYen)),
              _metric(
                'ROI',
                roi == null ? '算出不可' : '${roi.toStringAsFixed(1)}%',
              ),
              _metric('母数', '${summary.resultCount}件'),
              _metric('的中', '${summary.hits}件'),
              _metric('95%信頼区間', interval?.label ?? '算出不可'),
              _metric(
                '平均予測確率',
                predicted == null ? '未提供' : '${predicted.toStringAsFixed(1)}%',
              ),
              _metric(
                '較正差',
                gap == null ? '未評価' : '${gap.toStringAsFixed(1)}pt',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ROI=(払戻額−投下額)÷投下額。母数・信頼区間・予測確率が不足する場合は、命中率だけで優劣を判断しません。',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      key: Key('horse-racing-evidence-$label'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  String _yen(int amount) => '¥${NumberFormat('#,###').format(amount)}';
}
