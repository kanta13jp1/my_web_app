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
}
