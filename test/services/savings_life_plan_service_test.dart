import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/savings_life_plan.dart';
import 'package:my_web_app/services/savings_life_plan_service.dart';

void main() {
  final start = DateTime.utc(2026, 10, 13);
  SavingsLifePlan plan(
          {int? savings = 0, int income = 400000, int living = 50000,}) =>
      SavingsLifePlan(
        start: start,
        targetDate: DateTime.utc(2027, 10, 13),
        savings: savings,
        income: income,
        livingCosts: living,
        reserve: 10000,
      );
  test('one million is final savings, not an additional million', () {
    final result = SavingsLifePlanService.calculate(
        plan: plan(savings: 400000), asOf: start, monthlyCommitments: 200000,);
    expect(result.requiredMonthlySavings, 50000);
    expect(result.checkpoints.length, 12);
    expect(result.checkpoints.last.targetSavings, 1000000);
    expect(result.checkpoints.last.date, DateTime.utc(2027, 10, 13));
    expect(result.dailyLivingBudget, 1612);
  });
  test(
      'ceil division funds exact target without over-rounding final checkpoint',
      () {
    final result = SavingsLifePlanService.calculate(
        plan: plan(), asOf: start, monthlyCommitments: 200000,);
    expect(result.requiredMonthlySavings, 83334);
    expect(result.checkpoints.last.targetSavings, 1000000);
    expect(result.monthlyShortfall, 0);
  });
  test('repayment and essential costs are retained when goal is unaffordable',
      () {
    final input = plan(income: 300000, living: 60000);
    final result = SavingsLifePlanService.calculate(
        plan: input, asOf: start, monthlyCommitments: 240000,);
    expect(result.monthlyCapacity, -10000);
    expect(result.monthlyShortfall, 93334);
    expect(result.dailyLivingBudget, isNull);
    expect(input.livingCosts, 60000);
    expect(result.checkpoints.last.forecastSavings, 0);
  });
  test(
      'unconfirmed opening savings is missing, never inferred from account assets',
      () {
    final result = SavingsLifePlanService.calculate(
        plan: plan(savings: null), asOf: start, monthlyCommitments: 200000,);
    expect(result.ready, isFalse);
    expect(result.dailyLivingBudget, isNull);
  });
  test('remaining deposit opportunities shrink after an anniversary', () {
    final result = SavingsLifePlanService.calculate(
        plan: plan(savings: 100000),
        asOf: DateTime.utc(2027, 1, 13),
        monthlyCommitments: 200000,);
    expect(result.checkpoints.length, 9);
    expect(result.requiredMonthlySavings, 100000);
    expect(result.checkpoints.first.date, DateTime.utc(2027, 2, 13));
  });
  test('calendar month anchors clamp Jan 31 and leap years', () {
    expect(SavingsLifePlanService.anniversary(DateTime.utc(2028, 1, 31), 1),
        DateTime.utc(2028, 2, 29),);
    expect(SavingsLifePlanService.anniversary(DateTime.utc(2028, 2, 29), 12),
        DateTime.utc(2029, 2, 28),);
  });
  test('expired deadline has no future daily allowance', () {
    final result = SavingsLifePlanService.calculate(
        plan: plan(),
        asOf: DateTime.utc(2027, 10, 13),
        monthlyCommitments: 200000,);
    expect(result.expired, isTrue);
    expect(result.checkpoints, isEmpty);
    expect(result.dailyLivingBudget, isNull);
  });
  test(
      'saved anchors and zero savings round-trip; corrupt amounts are rejected',
      () {
    expect(SavingsLifePlan.fromJson(plan().toJson()).savings, 0);
    expect(() => SavingsLifePlan.fromJson({...plan().toJson(), 'income': -1}),
        throwsFormatException,);
    expect(() => SavingsLifePlan.fromJson({...plan().toJson(), 'version': 2}),
        throwsFormatException,);
  });
}
