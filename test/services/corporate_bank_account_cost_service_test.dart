import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/corporate_bank_account_cost_service.dart';

void main() {
  group('CorporateBankAccountCostService', () {
    const service = CorporateBankAccountCostService();

    test('calculates annual cost from monthly base and transfer fees', () {
      const input = CorporateBankSimulationInput(
        otherBankMonthlyTransferCount: 10,
        sameBankMonthlyTransferCount: 2,
        needsOverseasRemittance: false,
        accountingSoftware: CorporateAccountingSoftware.moneyForward,
      );

      const plan = CorporateBankFeePlan(
        planKey: 'sample',
        bankKey: 'sample',
        bankName: 'Sample Bank',
        planName: 'Basic',
        monthlyBaseFeeYen: 500,
        sameBankTransferFeeYen: 10,
        otherBankTransferFeeYen: 100,
        freeTransferCount: 1,
        overseasRemittanceAvailable: false,
        overseasReceiptAvailable: false,
        apiAvailable: true,
        supportedAccountingSoftware: <String>['money_forward'],
        sourceUrls: <String>[],
        sourceCheckedAt: '2026-06-06',
        notes: '',
      );

      final result = service.simulate(input, plans: const [plan]).single;

      expect(result.monthlySameBankTransferCostYen, 20);
      expect(result.monthlyOtherBankTransferCostYen, 900);
      expect(result.monthlyTotalYen, 1420);
      expect(result.annualTotalYen, 17040);
      expect(result.meetsRequirements, isTrue);
    });

    test(
      'prioritizes requirement-matching plans before cheaper mismatches',
      () {
        const input = CorporateBankSimulationInput(
          otherBankMonthlyTransferCount: 30,
          needsOverseasRemittance: true,
          accountingSoftware: CorporateAccountingSoftware.freee,
        );

        const cheapDomesticOnly = CorporateBankFeePlan(
          planKey: 'cheap',
          bankKey: 'cheap',
          bankName: 'Cheap Domestic Bank',
          planName: 'Domestic',
          monthlyBaseFeeYen: 0,
          sameBankTransferFeeYen: 0,
          otherBankTransferFeeYen: 50,
          freeTransferCount: 0,
          overseasRemittanceAvailable: false,
          overseasReceiptAvailable: false,
          apiAvailable: true,
          supportedAccountingSoftware: <String>['freee'],
          sourceUrls: <String>[],
          sourceCheckedAt: '2026-06-06',
          notes: '',
        );
        const overseasCapable = CorporateBankFeePlan(
          planKey: 'overseas',
          bankKey: 'overseas',
          bankName: 'Overseas Bank',
          planName: 'Standard',
          monthlyBaseFeeYen: 0,
          sameBankTransferFeeYen: 0,
          otherBankTransferFeeYen: 120,
          freeTransferCount: 0,
          overseasRemittanceAvailable: true,
          overseasReceiptAvailable: true,
          apiAvailable: true,
          supportedAccountingSoftware: <String>['freee'],
          sourceUrls: <String>[],
          sourceCheckedAt: '2026-06-06',
          notes: '',
        );

        final results = service.simulate(
          input,
          plans: const [cheapDomesticOnly, overseasCapable],
        );

        expect(results.first.plan.planKey, 'overseas');
        expect(results.first.meetsRequirements, isTrue);
        expect(results.last.warnings, contains('海外送金要件を満たす公式掲載がありません。'));
      },
    );

    test('flags accounting software and API gaps', () {
      const input = CorporateBankSimulationInput(
        otherBankMonthlyTransferCount: 5,
        needsOverseasRemittance: false,
        accountingSoftware: CorporateAccountingSoftware.moneyForward,
      );

      const plan = CorporateBankFeePlan(
        planKey: 'manual',
        bankKey: 'manual',
        bankName: 'Manual Bank',
        planName: 'Manual',
        monthlyBaseFeeYen: 0,
        sameBankTransferFeeYen: 0,
        otherBankTransferFeeYen: 100,
        freeTransferCount: 0,
        overseasRemittanceAvailable: true,
        overseasReceiptAvailable: true,
        apiAvailable: false,
        supportedAccountingSoftware: <String>['freee'],
        sourceUrls: <String>[],
        sourceCheckedAt: '2026-06-06',
        notes: '',
      );

      final result = service.simulate(input, plans: const [plan]).single;

      expect(result.meetsRequirements, isFalse);
      expect(result.warnings, contains('マネーフォワード連携は公式掲載またはseedで未確認です。'));
      expect(result.warnings, contains('APIまたは自動連携は要手動確認です。'));
    });

    test('builds WBS task drafts from the selected result', () {
      const input = CorporateBankSimulationInput(
        otherBankMonthlyTransferCount: 60,
        needsOverseasRemittance: false,
        accountingSoftware: CorporateAccountingSoftware.moneyForward,
      );
      final result = service.simulate(input).first;

      final drafts = service.buildWbsTaskDrafts(input, result);

      expect(drafts, hasLength(3));
      expect(drafts.first.title, contains('#2926'));
      expect(drafts.first.description, contains(result.plan.bankName));
      expect(drafts.first.toToolsHubBody()['action'], 'wbs.add_task');
      expect(
        drafts.first.toToolsHubBody()['milestone_code'],
        'corporate-bank-account-cost-2926',
      );
    });
  });
}
