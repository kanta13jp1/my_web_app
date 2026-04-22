import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/widgets/election_japan_map.dart';
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
          body: SingleChildScrollView(
            child: ElectionRegionalKpiChart(
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
      ),
    );

    expect(
      find.text('都道府県連別 目標配分 (現職維持 + 新人擁立)'),
      findsOneWidget,
    );
    expect(find.text('現職維持目標'), findsOneWidget);
    expect(find.textContaining('新人擁立目標'), findsWidgets);
    expect(find.text('東京'), findsOneWidget);
    expect(find.text('愛知'), findsOneWidget);
  });

  testWidgets('ElectionJapanMap renders national KPI map and detail panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ElectionJapanMap(prefectures: _samplePrefecturePlans()),
          ),
        ),
      ),
    );

    expect(find.text('全国KPIマップ'), findsOneWidget);
    expect(find.text('都道府県別の純増・新人擁立・公認期限を地図で俯瞰'), findsOneWidget);
    expect(find.text('日本地図UI'), findsOneWidget);
    expect(find.text('東京 選択中'), findsOneWidget);
    expect(find.text('東京都 KPI'), findsOneWidget);
    expect(find.text('重点度'), findsOneWidget);
    expect(find.text('純増目標'), findsOneWidget);
    expect(find.text('現職人数'), findsOneWidget);
    expect(find.text('立憲地方議員'), findsOneWidget);
    expect(find.text('予定選挙'), findsOneWidget);
    expect(find.text('公認期限'), findsOneWidget);
    expect(find.text('高負荷'), findsOneWidget);
  });
}

List<LocalElectionPrefecturePlan> _samplePrefecturePlans() {
  return List<LocalElectionPrefecturePlan>.generate(47, (index) {
    final isTokyo = index == 12;
    return LocalElectionPrefecturePlan(
      prefecture: 'prefecture-$index',
      region: 'region',
      additionalSeatTarget: isTokyo ? 24 : (index % 5) + 1,
      incumbentRetentionTarget: isTokyo ? 12 : (index % 3) + 1,
      focusMunicipalityCount: isTokyo ? 20 : (index % 6) + 2,
      newCandidateTarget: isTokyo ? 26 : (index % 4) + 1,
      endorsementDeadlineMonth: isTokyo ? '2026-09' : '2026-11',
      closeRaceSupportRounds: isTokyo ? 18 : (index % 5) + 2,
      currentMembers: isTokyo ? 14 : (index % 7),
      scheduledElectionCount: isTokyo ? 3 : (index % 4),
      cdpLocalMembers: isTokyo ? 82 : 0,
      cdpSourceUrl:
          isTokyo ? 'https://cdp-japan.jp/members/prefecture/tokyo' : '',
      endorsementConfirmed: index == 0,
      notes: isTokyo ? '重点自治体から先に月次レビューする' : '',
    );
  });
}
