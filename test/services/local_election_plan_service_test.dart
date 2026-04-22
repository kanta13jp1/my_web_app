import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_reality.dart';
import 'package:my_web_app/services/local_election_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default focused template allocates the full required net increase',
      () async {
    const service = LocalElectionPlanService();
    final prefs = await SharedPreferences.getInstance();

    final plan = await service.loadPlan(prefs: prefs);

    expect(plan.prefectures, hasLength(47));
    expect(plan.requiredNetIncrease, 360);
    expect(plan.allocatedNetIncrease, 360);
    expect(plan.allocationGap, 0);
    expect(plan.monthlyCheckpoints, hasLength(12));
    expect(
      plan.monthlyCheckpoints.last.cumulativeNewCandidateTarget,
      plan.totalNewCandidateTarget,
    );
    expect(
      plan.buildClipboardSummary(),
      contains('対象期間: 2026年4月 - 2027年3月'),
    );
  });

  test('saving an edited prefecture persists values and confirmation state',
      () async {
    const service = LocalElectionPlanService();
    final prefs = await SharedPreferences.getInstance();
    final plan = await service.loadPlan(prefs: prefs);

    final updatedPrefectures = [
      for (final item in plan.prefectures)
        if (item.prefecture == '東京')
          item.copyWith(
            additionalSeatTarget: 22,
            incumbentRetentionTarget: 14,
            endorsementDeadlineMonth: '2026-08',
            endorsementConfirmed: true,
            notes: '都議会系ネットワークを先行活用する',
          )
        else
          item,
    ];

    final saved = await service.savePlan(
      plan.copyWith(
        updatedAt: DateTime(2026, 4, 1, 9),
        prefectures: updatedPrefectures,
      ),
      prefs: prefs,
    );
    final loaded = await service.loadPlan(prefs: prefs);
    final tokyo =
        loaded.prefectures.firstWhere((item) => item.prefecture == '東京');

    expect(saved.updatedAt, DateTime(2026, 4, 1, 9));
    expect(tokyo.additionalSeatTarget, 22);
    expect(tokyo.incumbentRetentionTarget, 14);
    expect(tokyo.endorsementDeadlineMonth, '2026-08');
    expect(tokyo.endorsementConfirmed, isTrue);
    expect(tokyo.notes, '都議会系ネットワークを先行活用する');
  });

  test('balanced template stays close to equal distribution', () async {
    const service = LocalElectionPlanService();
    final prefs = await SharedPreferences.getInstance();

    final plan = await service.resetPlan(
      template: LocalElectionPlanTemplate.balanced,
      prefs: prefs,
    );
    final seatTargets =
        plan.prefectures.map((item) => item.additionalSeatTarget);

    expect(plan.allocatedNetIncrease, 360);
    expect(
      seatTargets.every((value) => value == 7 || value == 8),
      isTrue,
    );
  });

  test('auto update merges reality snapshot into prefecture KPIs', () async {
    const service = LocalElectionPlanService();
    final prefs = await SharedPreferences.getInstance();
    final plan = await service.loadPlan(prefs: prefs);
    final tokyo = plan.prefectures[12];
    final aichi = plan.prefectures[22];
    final now = DateTime(2026, 4, 22, 9);

    final updated = service.buildAutoUpdatedPlan(
      plan,
      LocalElectionRealitySnapshot(
        fetchedAt: now,
        baselineCurrentLocalMembers: 340,
        officialCurrentLocalMembers: 346,
        targetLocalMembers: 700,
        baselineNetIncreaseRequired: 360,
        actualNetIncreaseRequired: 354,
        official2023FirstHalfWins: 62,
        official2023SecondHalfWins: 121,
        official2023TotalWins: 183,
        aiSummary: 'latest snapshot',
        aiAlerts: const <String>[],
        aiStrategicNotes: const <String>[],
        scheduleAiSummary: 'upcoming schedules',
        scheduleAiAlerts: const <String>[],
        sources: const <LocalElectionRealitySource>[],
        prefectures: <LocalElectionPrefectureReality>[
          LocalElectionPrefectureReality(
            prefecture: tokyo.prefecture,
            sourceUrl: 'https://example.com/tokyo',
            currentMembers: 20,
            prefecturalAssemblyMembers: 3,
            municipalAssemblyMembers: 17,
            cdpLocalMembers: 64,
            cdpSourceUrl: 'https://cdp-japan.jp/members/prefecture/tokyo',
          ),
          LocalElectionPrefectureReality(
            prefecture: aichi.prefecture,
            sourceUrl: 'https://example.com/aichi',
            currentMembers: 12,
            prefecturalAssemblyMembers: 2,
            municipalAssemblyMembers: 10,
            cdpLocalMembers: 38,
            cdpSourceUrl: 'https://cdp-japan.jp/members/prefecture/aichi',
          ),
        ],
        members: const <LocalElectionLegislatorProfile>[],
        upcomingSchedules: <LocalElectionScheduleEntry>[
          LocalElectionScheduleEntry(
            electionName: 'Tokyo assembly A',
            prefecture: tokyo.prefecture,
            municipality: 'Ward A',
            electionCategory: 'city',
            voteDate: '2026-08-09',
            announcementDate: '2026-07-31',
            detailUrl: 'https://example.com/tokyo-a',
            officialCandidateSourceUrl: '',
            seatCount: 30,
            totalCandidateCount: 40,
            kokuminCandidateCount: 2,
            kokuminCandidateNames: const <String>['candidate-a'],
            kokuminCandidateStatuses: const <String>['公認'],
            kokuminCandidateXHandles: const <String>[],
          ),
          LocalElectionScheduleEntry(
            electionName: 'Tokyo assembly B',
            prefecture: tokyo.prefecture,
            municipality: 'Ward B',
            electionCategory: 'city',
            voteDate: '2026-09-06',
            announcementDate: '2026-08-28',
            detailUrl: 'https://example.com/tokyo-b',
            officialCandidateSourceUrl: '',
            seatCount: 20,
            totalCandidateCount: 26,
            kokuminCandidateCount: 0,
            kokuminCandidateNames: const <String>[],
            kokuminCandidateStatuses: const <String>[],
            kokuminCandidateXHandles: const <String>[],
          ),
          LocalElectionScheduleEntry(
            electionName: 'Aichi assembly',
            prefecture: aichi.prefecture,
            municipality: 'City A',
            electionCategory: 'city',
            voteDate: '2026-10-18',
            announcementDate: '2026-10-09',
            detailUrl: 'https://example.com/aichi',
            officialCandidateSourceUrl: '',
            seatCount: 18,
            totalCandidateCount: 24,
            kokuminCandidateCount: 1,
            kokuminCandidateNames: const <String>['candidate-b'],
            kokuminCandidateStatuses: const <String>['予定'],
            kokuminCandidateXHandles: const <String>[],
          ),
        ],
      ),
      now: now,
    );

    final updatedTokyo = updated.prefectures.firstWhere(
      (item) => item.prefecture == tokyo.prefecture,
    );
    final updatedAichi = updated.prefectures.firstWhere(
      (item) => item.prefecture == aichi.prefecture,
    );

    expect(updated.currentLocalMembers, 346);
    expect(updated.allocatedNetIncrease, 354);
    expect(updated.allocationGap, 0);
    expect(updatedTokyo.currentMembers, 20);
    expect(updatedTokyo.cdpLocalMembers, 64);
    expect(
      updatedTokyo.cdpSourceUrl,
      'https://cdp-japan.jp/members/prefecture/tokyo',
    );
    expect(updatedTokyo.incumbentRetentionTarget, 20);
    expect(updatedTokyo.scheduledElectionCount, 2);
    expect(updatedTokyo.endorsementDeadlineMonth, '2026-07');
    expect(updatedTokyo.newCandidateTarget, greaterThanOrEqualTo(3));
    expect(updatedTokyo.notes, contains('AI自動更新'));
    expect(updatedTokyo.autoUpdatedAt, now.toIso8601String());
    expect(updatedAichi.currentMembers, 12);
    expect(updatedAichi.cdpLocalMembers, 38);
    expect(updatedAichi.scheduledElectionCount, 1);
  });
}
