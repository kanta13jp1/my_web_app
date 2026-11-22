import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_revolving_extra_payment_simulator.dart';

void main() {
  const planner = AssetLiabilityPlanningService();

  AssetLiabilityDebtRow rowFor(double payment) {
    final workbook = planner.buildWorkbook(
      latestSnapshot: const <String, double>{
        'bank': 500000,
        'ファミペイ': -100000,
      },
      baseDate: DateTime(2026, 6, 1),
      monthlyPaymentOverrides: <String, double>{'ファミペイ': payment},
    );
    return workbook.debtMasterRows.firstWhere((r) => r.name == 'ファミペイ');
  }

  test('extra payment shortens payoff and saves interest', () {
    final result = AssetRevolvingExtraPaymentSimulator.simulate(
      row: rowFor(10000),
      extraPayment: 5000,
    );
    expect(result.monthsSaved, isNotNull);
    expect(result.monthsSaved! > 0, isTrue);
    expect(result.interestSaved! > 0, isTrue);
  });

  test('zero or negative extra changes nothing', () {
    final result = AssetRevolvingExtraPaymentSimulator.simulate(
      row: rowFor(10000),
      extraPayment: -300,
    );
    expect(result.extraPayment, 0);
    expect(result.monthsSaved, 0);
    expect(result.interestSaved, 0);
  });

  test('payment below interest becomes payable with enough extra', () {
    final result = AssetRevolvingExtraPaymentSimulator.simulate(
      row: rowFor(500),
      extraPayment: 20000,
    );
    expect(result.baseline.everPaysOff, isFalse);
    expect(result.becomesPayable, isTrue);
    expect(result.monthsSaved, isNull);
    expect(result.interestSaved, isNull);
  });

  test('lump sum early repayment reduces payoff months and total interest', () {
    final result = AssetRevolvingExtraPaymentSimulator.simulateLumpSum(
      row: rowFor(10000),
      lumpSumAmount: 50000,
    );
    expect(result.extraPayment, 50000);
    expect(result.monthsSaved, isNotNull);
    expect(result.monthsSaved! > 0, isTrue);
    expect(result.interestSaved, isNotNull);
    expect(result.interestSaved! > 0, isTrue);
  });

  test('full balance lump sum clears payoff immediately', () {
    final result = AssetRevolvingExtraPaymentSimulator.simulateLumpSum(
      row: rowFor(10000),
      lumpSumAmount: 100000,
    );
    expect(result.boosted.months, 0);
    expect(result.boosted.totalInterest, 0);
    expect(result.boosted.everPaysOff, isTrue);
  });

  test('zero or negative lump sum matches baseline', () {
    final result = AssetRevolvingExtraPaymentSimulator.simulateLumpSum(
      row: rowFor(10000),
      lumpSumAmount: -100,
    );
    expect(result.extraPayment, 0);
    expect(result.monthsSaved, 0);
    expect(result.interestSaved, 0);
  });

  test('isHighInterestCandidate targets >= 15% debts and excludes 0% bills',
      () {
    final workbook = planner.buildWorkbook(
      latestSnapshot: const <String, double>{
        'bank': 500000,
        'モビット': -100000,
        '水道代': -5000,
      },
      baseDate: DateTime(2026, 6, 1),
    );
    final mobit = workbook.debtMasterRows.firstWhere((r) => r.name == 'モビット');
    final water = workbook.debtMasterRows.firstWhere((r) => r.name == '水道代');
    expect(
      AssetRevolvingExtraPaymentSimulator.isHighInterestCandidate(mobit),
      isTrue,
    );
    expect(
      AssetRevolvingExtraPaymentSimulator.isHighInterestCandidate(water),
      isFalse,
    );
  });
}
