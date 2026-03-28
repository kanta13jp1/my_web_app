import 'package:flutter_test/flutter_test.dart';
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
}
