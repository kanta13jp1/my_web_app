import 'package:flutter/material.dart';
import '../services/asset_waste_training_ai_service.dart';

class AssetWasteObservationStatus extends StatelessWidget {
  const AssetWasteObservationStatus({super.key, required this.snapshot});
  final AssetWasteTrainingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final status =
        snapshot.recordedExpenseDays == 0 ? '記録不足・採点なし。' : '記録ベースの参考値。';
    return Text(
      '$status'
      '支出記録日 ${snapshot.recordedExpenseDays}/${snapshot.elapsedDays}日。'
      '未記録日の支出・浪費の有無は不明です。能力や達成実績の評価ではありません。',
    );
  }
}
