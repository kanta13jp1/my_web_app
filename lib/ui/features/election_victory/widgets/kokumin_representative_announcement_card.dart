import 'package:flutter/material.dart';

import '../../../../data/kokumin_representative_announcement.dart';

/// An announcement snapshot, with no derived seats or progress calculation.
class KokuminRepresentativeAnnouncementCard extends StatelessWidget {
  const KokuminRepresentativeAnnouncementCard({
    super.key,
    this.announcement = kokuminRepresentativeAnnouncement20261109,
    required this.onOpenSource,
  });

  final KokuminRepresentativeAnnouncement announcement;
  final ValueChanged<String> onOpenSource;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0F766E);
    final date = announcement.publishedOn.replaceAll('-', '/');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '党代表発表（$date）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _fact('現職 ${announcement.incumbentCount}人'),
              _fact('新人擁立数 ${announcement.newcomerNominationCount}人'),
              _fact('全国自治体議員 ${announcement.nationwideMemberTarget}人目標'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '公認予定候補の掲載件数や議員名簿の集計、アプリの計画値とは別の指標です。'
            '新人擁立数は当選・議席獲得を示すものではありません。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            '発表時点の固定値です。最新の状況は出典をご確認ください。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onOpenSource(announcement.originalPostUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('党代表の元投稿を開く'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenSource(announcement.officialSiteUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('党代表公式サイトの掲載を開く'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fact(String label) {
    const accent = Color(0xFF0F766E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
