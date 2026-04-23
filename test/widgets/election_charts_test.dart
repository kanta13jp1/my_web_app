import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/models/local_election_reality.dart';
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

  testWidgets('ElectionJapanMap renders national KGI/KPI map and detail panel',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ElectionJapanMap(
              prefectures: _samplePrefecturePlans(),
              schedules: _sampleSchedules(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('全国KGI/KPIマップ'), findsOneWidget);
    expect(find.text('都道府県別の現職維持・新人当選目標・公認期限を地図で俯瞰'), findsOneWidget);
    expect(find.text('日本地図UI'), findsOneWidget);
    expect(find.text('東京 選択中'), findsOneWidget);
    expect(find.text('KGI 36 / KPI 14'), findsOneWidget);
    expect(find.text('東京都 KGI/KPI'), findsOneWidget);
    expect(find.text('重点度'), findsOneWidget);
    expect(find.text('KGI目標'), findsWidgets);
    expect(find.text('KPI実績'), findsWidgets);
    expect(find.text('現職人数'), findsOneWidget);
    expect(find.text('立憲地方議員'), findsOneWidget);
    expect(find.text('現職維持目標'), findsOneWidget);
    expect(find.text('現職維持数'), findsOneWidget);
    expect(find.text('新人当選目標'), findsOneWidget);
    expect(find.text('新人当選数'), findsOneWidget);
    expect(find.text('新人擁立目標'), findsWidgets);
    expect(find.text('現状当選率'), findsWidgets);
    expect(find.text('予定選挙'), findsOneWidget);
    expect(find.text('予定選挙内訳'), findsOneWidget);
    expect(find.text('中野区議会議員選挙'), findsOneWidget);
    expect(find.text('東京区長選挙'), findsNothing);
    expect(find.textContaining('公示日 2026年05月17日'), findsOneWidget);
    expect(find.textContaining('投開票日 2026年05月24日'), findsOneWidget);
    expect(find.text('公認期限'), findsOneWidget);
    expect(find.text('高負荷'), findsOneWidget);
  });
}

List<LocalElectionPrefecturePlan> _samplePrefecturePlans() {
  return List<LocalElectionPrefecturePlan>.generate(47, (index) {
    final isTokyo = index == 12;
    return LocalElectionPrefecturePlan(
      prefecture: isTokyo ? '東京' : 'prefecture-$index',
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

List<LocalElectionScheduleEntry> _sampleSchedules() {
  return const <LocalElectionScheduleEntry>[
    LocalElectionScheduleEntry(
      electionName: '中野区議会議員選挙',
      prefecture: '東京都',
      municipality: '中野区',
      electionCategory: '区議会議員選挙',
      voteDate: '2026-05-24',
      announcementDate: '2026-05-17',
      detailUrl: 'https://example.com/nakano',
      officialCandidateSourceUrl: 'https://example.com/candidates',
      seatCount: 42,
      totalCandidateCount: 55,
      kokuminCandidateCount: 0,
      kokuminCandidateNames: <String>[],
      kokuminCandidateStatuses: <String>[],
      kokuminCandidateXHandles: <String>[],
    ),
    LocalElectionScheduleEntry(
      electionName: '東京区長選挙',
      prefecture: '東京都',
      municipality: '東京区',
      electionCategory: 'chief',
      voteDate: '2026-05-24',
      announcementDate: '2026-05-17',
      detailUrl: 'https://example.com/chief',
      officialCandidateSourceUrl: 'https://example.com/candidates',
      seatCount: 1,
      totalCandidateCount: 2,
      kokuminCandidateCount: 0,
      kokuminCandidateNames: <String>[],
      kokuminCandidateStatuses: <String>[],
      kokuminCandidateXHandles: <String>[],
    ),
    LocalElectionScheduleEntry(
      electionName: '過去の東京都選挙',
      prefecture: '東京都',
      municipality: '過去区',
      electionCategory: '区長選挙',
      voteDate: '2026-04-01',
      announcementDate: '2026-03-25',
      detailUrl: '',
      officialCandidateSourceUrl: '',
      seatCount: 1,
      totalCandidateCount: 2,
      kokuminCandidateCount: 0,
      kokuminCandidateNames: <String>[],
      kokuminCandidateStatuses: <String>[],
      kokuminCandidateXHandles: <String>[],
      isPast: true,
    ),
  ];
}
