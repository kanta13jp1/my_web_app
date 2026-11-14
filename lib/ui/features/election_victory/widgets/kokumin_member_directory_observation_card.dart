import 'package:flutter/material.dart';

import '../../../../data/kokumin_member_directory_observation.dart';

/// Independently verified directory header; never synthesizes member rows.
class KokuminMemberDirectoryObservationCard extends StatelessWidget {
  const KokuminMemberDirectoryObservationCard({
    super.key,
    this.observation = kokuminMemberDirectoryObservation20261114,
    required this.onOpenSource,
  });

  final KokuminMemberDirectoryObservation observation;
  final ValueChanged<String> onOpenSource;

  @override
  Widget build(BuildContext context) {
    final date = observation.verifiedOn.replaceAll('-', '/');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '党公式名簿の掲載人数: ${observation.listedMemberCount}人',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('確認日: $date（原本の基準日は記載なし）'),
            const SizedBox(height: 8),
            const Text(
              '党公式サイト「地方自治体議員」の掲載人数です。'
              '全国現職420人（11/9党代表発表）とは一致していません。'
              '差の理由は未確認です。'
              '下記の過去の名簿取得値・県別内訳・計画KPIは更新していません。'
              '予定候補者の公認・推薦件数は含めていません。',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onOpenSource(observation.sourceUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('党公式の地方議員名簿を開く'),
            ),
          ],
        ),
      ),
    );
  }
}
