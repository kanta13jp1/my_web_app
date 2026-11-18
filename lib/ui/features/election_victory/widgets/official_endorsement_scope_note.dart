import 'package:flutter/material.dart';

import '../../../../models/election_intelligence.dart';

class OfficialEndorsementScopeNote extends StatelessWidget {
  const OfficialEndorsementScopeNote({super.key, required this.snapshot});

  final OfficialEndorsementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hasAssemblyCounts =
        snapshot.prefecturalCount + snapshot.municipalCount > 0;
    return Text(
      '地方議会選挙で党が公認した候補の掲載件数です。'
      '現職・新人・元職は公認決定時の分類です。'
      '所属議員の総数や新人の擁立数とは集計の対象が異なります。'
      '推薦${snapshot.recommendationCount}件は公認の集計から除いています。'
      '推薦件数の集計対象には首長選挙も含まれます。'
      '${hasAssemblyCounts ? '都道府県議・市区町村議の区分は公式一覧の選挙名に基づきます。' : ''}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
