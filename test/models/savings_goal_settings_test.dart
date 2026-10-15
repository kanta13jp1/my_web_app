import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/savings_life_plan.dart';

void main() {
  test('legacy plan retains its chosen amount and deadline without a goal name', () {
    final plan = SavingsLifePlan.fromJson({
      'version': 2,
      'start': '2026-10-13',
      'targetDate': '2027-04-13',
      'target': 250000,
      'reserve': 0,
    });
    expect(plan.goalName, isEmpty);
    expect(plan.target, 250000);
    expect(plan.targetDate, DateTime(2027, 4, 13));
    final restored = SavingsLifePlan.fromJson(plan.toJson());
    expect(restored.target, 250000);
    expect(restored.targetDate, plan.targetDate);
  });
  test('chosen goal name and amount survive roundtrip', () {
    final plan = SavingsLifePlan(
      start: DateTime(2026, 10, 13),
      targetDate: DateTime(2027, 4, 13),
      target: 250000,
      goalName: '引越し',
    );
    final restored = SavingsLifePlan.fromJson(plan.toJson());
    expect(restored.goalName, '引越し');
    expect(restored.target, 250000);
  });
}
