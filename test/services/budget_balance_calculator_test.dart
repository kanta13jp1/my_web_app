import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/budget_balance_calculator.dart';

void main() {
  const calculator = BudgetBalanceCalculator();
  Map<BudgetBalanceField, String> example() => {
        BudgetBalanceField.income: '230000',
        BudgetBalanceField.essential: '110000',
        BudgetBalanceField.annual: '120000',
        BudgetBalanceField.reserve: '10000',
        BudgetBalanceField.enjoyment: '20000',
        BudgetBalanceField.investment: '50000',
      };
  test('allocates annual costs and preserves a positive remainder', () {
    final result = calculator.calculate(example())!;
    expect(result.monthlyAnnualProvision, 10000);
    expect(result.allocated, 200000);
    expect(result.remaining, 30000);
  });
  test('does not clamp a shortfall to zero', () {
    final inputs = example()..[BudgetBalanceField.investment] = '150000';
    expect(calculator.calculate(inputs)!.remaining, -70000);
  });
  test('rounds a fractional monthly provision upward', () {
    final inputs = example()..[BudgetBalanceField.annual] = '1';
    expect(calculator.calculate(inputs)!.monthlyAnnualProvision, 1);
  });
  test('unknown differs from an explicit zero', () {
    final inputs = example()..remove(BudgetBalanceField.reserve);
    expect(calculator.calculate(inputs), isNull);
    inputs[BudgetBalanceField.reserve] = '0';
    expect(calculator.calculate(inputs)!.remaining, 40000);
  });
  test(
      'rejects invalid and oversized amounts instead of silently coercing them',
      () {
    for (final invalid in [
      '',
      '-1',
      '1.5',
      'NaN',
      'Infinity',
      '1e5',
      '1,23',
      '1000000001'
    ]) {
      expect(calculator.validate(invalid), isNotNull, reason: invalid);
    }
  });
  test('allows grouped integers and handles all-zero inputs', () {
    final inputs = {for (final field in BudgetBalanceField.values) field: '0'};
    expect(calculator.calculate(inputs)!.remaining, 0);
    inputs[BudgetBalanceField.income] = ' 230,000 ';
    expect(calculator.calculate(inputs)!.remaining, 230000);
  });
}
