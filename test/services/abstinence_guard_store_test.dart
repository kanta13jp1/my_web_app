import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/abstinence_guard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AbstinenceGuardSnapshot prioritizes slipped blockers first', () {
    final alcohol = AbstinenceGuardStore.items.firstWhere(
      (item) => item.id == 'alcohol',
    );
    final sns = AbstinenceGuardStore.items.firstWhere(
      (item) => item.id == 'sns',
    );
    final smoking = AbstinenceGuardStore.items.firstWhere(
      (item) => item.id == 'smoking',
    );

    final snapshot = AbstinenceGuardSnapshot(
      states: [
        AbstinenceGuardState(
          item: alcohol,
          isEnabled: true,
          slipCount: 1,
        ),
        AbstinenceGuardState(
          item: sns,
          isEnabled: true,
          slipCount: 0,
        ),
        AbstinenceGuardState(
          item: smoking,
          isEnabled: true,
          slipCount: 3,
        ),
      ],
    );

    expect(snapshot.priorityStates.first.item.id, 'smoking');
    expect(snapshot.primaryInterference?.item.id, 'smoking');
  });

  test('loadSnapshot includes new digital blockers and exposes a primary item',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 3, 14);

    await AbstinenceGuardStore.setEnabled(
      itemId: 'sns',
      isEnabled: true,
      prefs: prefs,
      now: now,
    );
    await AbstinenceGuardStore.setEnabled(
      itemId: 'mobile_games',
      isEnabled: true,
      prefs: prefs,
      now: now,
    );
    await AbstinenceGuardStore.incrementSlip(
      itemId: 'sns',
      prefs: prefs,
      now: now,
    );

    final snapshot = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: now,
    );

    expect(snapshot.enabledLabels, contains('SNS'));
    expect(snapshot.enabledLabels.length, greaterThanOrEqualTo(2));
    expect(snapshot.primaryInterference?.item.id, 'sns');
    expect(snapshot.primaryInterference?.item.interruptionSignal, isNotEmpty);
    expect(snapshot.primaryInterference?.item.eliminationAction, isNotEmpty);
  });

  test('loadSnapshot exposes alcohol and smoking quit protocol progress',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 3, 21);

    await AbstinenceGuardStore.setEnabled(
      itemId: 'alcohol',
      isEnabled: true,
      prefs: prefs,
      now: now,
    );
    await AbstinenceGuardStore.setQuitProtocolStep(
      itemId: 'alcohol',
      stepId: 'remove_stock',
      isCompleted: true,
      prefs: prefs,
      now: now,
    );

    var snapshot = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: now,
    );

    expect(
      snapshot.quitProtocolStatuses.map((status) => status.item.id),
      containsAll(<String>['alcohol', 'smoking']),
    );

    final alcoholProtocol = snapshot.quitProtocolStatuses.firstWhere(
      (status) => status.item.id == 'alcohol',
    );
    expect(alcoholProtocol.completedCount, 1);
    expect(alcoholProtocol.totalCount, 3);
    expect(alcoholProtocol.isLockedForToday, isFalse);

    await AbstinenceGuardStore.setQuitProtocolStep(
      itemId: 'alcohol',
      stepId: 'block_purchase_route',
      isCompleted: true,
      prefs: prefs,
      now: now,
    );
    await AbstinenceGuardStore.setQuitProtocolStep(
      itemId: 'alcohol',
      stepId: 'prepare_replacement',
      isCompleted: true,
      prefs: prefs,
      now: now,
    );

    snapshot = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: now,
    );
    final lockedAlcoholProtocol = snapshot.quitProtocolStatuses.firstWhere(
      (status) => status.item.id == 'alcohol',
    );
    expect(lockedAlcoholProtocol.isLockedForToday, isTrue);
  });

  test('loadSnapshot includes discipline training totals and streak', () async {
    final prefs = await SharedPreferences.getInstance();
    final previousDay = DateTime(2026, 3, 20, 21);
    final now = DateTime(2026, 3, 21, 9);

    await AbstinenceGuardStore.recordDisciplineRep(
      categoryId: 'no_buy',
      moneySaved: 2200,
      timeSavedMinutes: 5,
      note: 'コンビニを見送った',
      prefs: prefs,
      now: previousDay,
    );
    await AbstinenceGuardStore.recordDisciplineRep(
      categoryId: 'no_scroll',
      moneySaved: 0,
      timeSavedMinutes: 15,
      note: 'SNSを開かなかった',
      prefs: prefs,
      now: now,
    );
    await AbstinenceGuardStore.recordDisciplineRep(
      categoryId: 'accept_discomfort',
      moneySaved: 500,
      timeSavedMinutes: 10,
      note: '歩いて帰った',
      prefs: prefs,
      now: now.add(const Duration(minutes: 30)),
    );

    final snapshot = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: now,
    );
    final discipline = snapshot.disciplineSnapshot;

    expect(discipline.totalRepCount, 2);
    expect(discipline.totalMoneySaved, 500);
    expect(discipline.totalTimeSavedMinutes, 25);
    expect(discipline.streakDays, 2);
    expect(
      discipline.recentEntries.map((entry) => entry.note),
      containsAll(<String>['SNSを開かなかった', '歩いて帰った']),
    );

    final noScrollSummary = discipline.summaries.firstWhere(
      (summary) => summary.category.id == 'no_scroll',
    );
    expect(noScrollSummary.count, 1);
    expect(noScrollSummary.totalTimeSavedMinutes, 15);
  });

  test('removeDisciplineRep removes only the selected discipline record',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 3, 21, 9);

    await AbstinenceGuardStore.recordDisciplineRep(
      categoryId: 'no_scroll',
      note: 'Xを開かなかった',
      prefs: prefs,
      now: now,
    );
    await AbstinenceGuardStore.recordDisciplineRep(
      categoryId: 'accept_discomfort',
      note: '自炊した',
      prefs: prefs,
      now: now.add(const Duration(minutes: 5)),
    );

    final before = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: now,
    );
    final targetEntry = before.disciplineSnapshot.recentEntries.firstWhere(
      (entry) => entry.note == '自炊した',
    );

    await AbstinenceGuardStore.removeDisciplineRep(
      entryId: targetEntry.id,
      prefs: prefs,
      now: now,
    );

    final after = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: now,
    );
    expect(after.disciplineSnapshot.totalRepCount, 1);
    expect(
      after.disciplineSnapshot.recentEntries.map((entry) => entry.note),
      isNot(contains('自炊した')),
    );
    expect(
      after.disciplineSnapshot.recentEntries.map((entry) => entry.note),
      contains('Xを開かなかった'),
    );
  });

  test('loadSlipCountsByDate returns daily touch hair counts', () async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime(2026, 3, 21, 9);

    await AbstinenceGuardStore.incrementSlip(
      itemId: 'touch_hair',
      prefs: prefs,
      now: DateTime(2026, 3, 19, 10),
    );
    await AbstinenceGuardStore.incrementSlip(
      itemId: 'touch_hair',
      prefs: prefs,
      now: today,
    );
    await AbstinenceGuardStore.incrementSlip(
      itemId: 'touch_hair',
      prefs: prefs,
      now: today.add(const Duration(minutes: 15)),
    );

    final trend = await AbstinenceGuardStore.loadSlipCountsByDate(
      itemId: 'touch_hair',
      days: 4,
      prefs: prefs,
      now: today,
    );

    expect(trend.map((day) => day.count), <int>[0, 1, 0, 2]);
    expect(trend.last.label, '3/21');
  });
}
