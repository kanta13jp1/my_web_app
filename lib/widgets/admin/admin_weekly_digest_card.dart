import 'package:flutter/material.dart';
import '../../pages/admin_dashboard_signals.dart';
import '../../services/growth_mission_service.dart';

class AdminWeeklyDigestCard extends StatelessWidget {
  const AdminWeeklyDigestCard({
    super.key,
    required this.digest,
    required this.loaded,
  });

  final WeeklyDigestSnapshot digest;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final d = digest;
    final hasData = d.currentWeekStart.isNotEmpty;
    // R18: loading / loaded-empty / loaded-data の3状態に分けてヘッダ文言を決める。
    final cardState = weeklyDigestCardState(
      loaded: loaded,
      hasData: hasData,
    );
    final headerText = switch (cardState) {
      WeeklyDigestCardState.loading => '読み込み中...',
      WeeklyDigestCardState.empty => '今週はまだ計測データがありません（計測待ち）',
      WeeklyDigestCardState.data =>
        '${d.currentWeekStart} 〜 ${d.currentWeekEnd}',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, size: 18, color: Color(0xFF3949AB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _weeklyKpiChip(
                  context,
                  '登録',
                  d.signupSubmitTotal,
                  d.signupSubmitDelta,
                ),
                _weeklyKpiChip(
                  context,
                  '紹介',
                  d.referralsCompleted,
                  d.referralsDelta,
                ),
                _weeklyKpiChip(context, 'インポートCTA', d.importCtaClicks, 0),
                _weeklyKpiChip(context, '公開メモCTA', d.publicMemoCtaClicks, 0),
              ],
            ),
            if (d.channels.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'チャネル別',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...d.channels.map(
                (ch) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          ch.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                            height: 1.5,
                          ),
                        ),
                      ),
                      Text(
                        'タッチ ${ch.touches}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '登録 ${ch.signupSubmits}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3949AB),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (d.brief.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                d.brief,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _weeklyKpiChip(
    BuildContext context,
    String label,
    int value,
    int delta,
  ) {
    final isPositive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
              if (delta != 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}$delta',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
