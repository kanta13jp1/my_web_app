import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/savings_plan_proposal_service.dart';

void main() {
  const input = SavingsPlanProposalInput(
    cashBalance: 400000,
    monthlyIncome: 400000,
    monthlyCommitments: 200000,
    observedLivingExpense: 12000,
    recordedDays: 5,
    estimatedPayments: true,
  );
  test(
      'AI proposes living/reserve while immutable account totals stay grounded',
      () async {
    String? prompt;
    final service = SavingsPlanProposalService(
      allowExternalAi: () async => true,
      generate: (value) async {
        prompt = value;
        return '{"living_costs":70000,"reserve":15000,"rationale":"食費・通勤費を確保し、支出記録を毎晩確認してください。"}';
      },
    );
    final result = await service.propose(input);
    expect(result.usedAi, isTrue);
    expect(result.input, same(input));
    expect(result.protectedCash, 285000);
    expect(result.availableSavings, 115000);
    expect(prompt, contains('days_with_recorded_expenses'));
    expect(prompt, isNot(contains('account_number')));
  });
  test('unsafe low living costs and malformed responses use labelled fallback',
      () async {
    for (final response in [
      '{"living_costs":1,"reserve":0,"rationale":"節約"}',
      'not json',
    ]) {
      final result = await SavingsPlanProposalService(
        allowExternalAi: () async => true,
        generate: (_) async => response,
      ).propose(input);
      expect(result.usedAi, isFalse);
      expect(result.livingCosts, 60000);
      expect(result.reserve, 10000);
      expect(result.source, contains('仮置き'));
    }
  });
  test('mask-money privacy setting prevents transmission', () async {
    var calls = 0;
    final result = await SavingsPlanProposalService(
      allowExternalAi: () async => false,
      generate: (_) async {
        calls++;
        return '{}';
      },
    ).propose(input);
    expect(calls, 0);
    expect(result.usedAi, isFalse);
    expect(result.source, contains('設定'));
  });
  test('sparse records and insufficient cash never fabricate existing savings',
      () async {
    const poor = SavingsPlanProposalInput(
      cashBalance: 50000,
      monthlyIncome: 300000,
      monthlyCommitments: 240000,
      observedLivingExpense: 698,
      recordedDays: 1,
      estimatedPayments: true,
    );
    final result = await SavingsPlanProposalService(
      allowExternalAi: () async => true,
      generate: (_) async => throw StateError('unavailable'),
    ).propose(poor);
    expect(result.availableSavings, 0);
    expect(result.reserveShortfall, 260000);
    expect(result.usedAi, isFalse);
    expect(result.rationale, contains('確定できません'));
  });
}
