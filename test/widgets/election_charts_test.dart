import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/widgets/election_progress_chart.dart';
import 'package:my_web_app/widgets/election_regional_kpi_chart.dart';

void main() {
  testWidgets('ElectionProgressChart renders current and target values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElectionProgressChart(
            currentTotal: 345,
            shortfall: 355,
            target: 700,
            caption: '公式議員ページの最新集計を反映',
          ),
        ),
      ),
    );

    expect(find.text('党全体 必達目標（700名）への進捗'), findsOneWidget);
    expect(find.textContaining('目標: 700人 / 現在: 345人'), findsOneWidget);
    expect(find.textContaining('達成率'), findsOneWidget);
  });

  testWidgets('ElectionRegionalKpiChart renders prefecture labels and legends',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElectionRegionalKpiChart(
            prefectures: [
              LocalElectionPrefecturePlan(
                prefecture: '東京',
                region: '関東',
                additionalSeatTarget: 12,
                incumbentRetentionTarget: 9,
                focusMunicipalityCount: 14,
                newCandidateTarget: 15,
                endorsementDeadlineMonth: '2026-09',
                closeRaceSupportRounds: 18,
              ),
              LocalElectionPrefecturePlan(
                prefecture: '愛知',
                region: '中部',
                additionalSeatTarget: 7,
                incumbentRetentionTarget: 5,
                focusMunicipalityCount: 9,
                newCandidateTarget: 8,
                endorsementDeadlineMonth: '2026-10',
                closeRaceSupportRounds: 10,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('都道府県連別 目標配分 (現職維持 + 新人擁立)'), findsOneWidget);
    expect(find.text('現職維持目標'), findsOneWidget);
    expect(find.text('新人擁立目標'), findsOneWidget);
    expect(find.text('東京'), findsOneWidget);
    expect(find.text('愛知'), findsOneWidget);
  });
}
