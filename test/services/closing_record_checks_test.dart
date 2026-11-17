import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/closing_record_checks.dart';

void main() {
  const unchecked = ClosingRecordChecks(
    assets: false,
    liabilities: false,
    fixedCosts: false,
    flows: false,
    tasks: false,
  );

  test('partial registered balances do not complete either side', () {
    final result = unchecked.withRecordedBalances(
      registeredAccounts: {'cash', 'loan'},
      recordedToday: {'cash': 100},
    );
    expect(result.assets, isFalse);
    expect(result.liabilities, isFalse);
  });

  test('complete raw coverage only checks the observed balance sides', () {
    final result = unchecked.withRecordedBalances(
      registeredAccounts: {'cash', 'loan'},
      recordedToday: {'cash': 0, 'loan': -100},
    );
    expect(result.assets, isTrue);
    expect(result.liabilities, isTrue);
    expect(result.fixedCosts, isFalse);
    expect(result.flows, isFalse);
    expect(result.tasks, isFalse);
  });

  test('empty accounts and recordings cannot imply completion', () {
    final result = unchecked.withRecordedBalances(
      registeredAccounts: {},
      recordedToday: {},
    );
    expect(result.assets, isFalse);
    expect(result.liabilities, isFalse);
  });

  test('existing owner checks survive without new recordings', () {
    const existing = ClosingRecordChecks(
      assets: true,
      liabilities: true,
      fixedCosts: true,
      flows: false,
      tasks: true,
    );
    final result = existing.withRecordedBalances(
      registeredAccounts: {'cash'},
      recordedToday: {},
    );
    expect(result.assets, isTrue);
    expect(result.liabilities, isTrue);
    expect(result.fixedCosts, isTrue);
    expect(result.flows, isFalse);
    expect(result.tasks, isTrue);
  });
}
