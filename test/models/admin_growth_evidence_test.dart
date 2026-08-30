import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/admin_growth_evidence.dart';

void main() {
  group('AdminAcquisitionCohortEvidence', () {
    test('calculates retention and paid conversion from joined counts', () {
      const evidence = AdminAcquisitionCohortEvidence(
        source: 'google',
        acquiredUsers: 50,
        day7EligibleUsers: 40,
        day7RetainedUsers: 20,
        day30EligibleUsers: 25,
        day30RetainedUsers: 10,
        paidConvertedUsers: 5,
      );

      expect(evidence.day7RetentionRate, 0.5);
      expect(evidence.day30RetentionRate, 0.4);
      expect(evidence.paidConversionRate, 0.1);
      expect(evidence.hasCompleteDecisionEvidence, isTrue);
      expect(evidence.missingInputs, isEmpty);
    });

    test('does not promote aggregate signals into cohort evidence', () {
      final evidence = adminAcquisitionEvidenceFromAggregateSignals({
        'direct': 8,
        'google': 12,
        'empty': 0,
      });

      expect(evidence.map((row) => row.source), ['google', 'direct']);
      expect(evidence.first.aggregateSignalCount, 12);
      expect(evidence.first.acquiredUsers, isNull);
      expect(evidence.first.day7RetentionRate, isNull);
      expect(evidence.first.paidConversionRate, isNull);
      expect(evidence.first.hasCompleteDecisionEvidence, isFalse);
    });

    test('rejects missing, zero, and inconsistent cohort denominators', () {
      const evidence = AdminAcquisitionCohortEvidence(
        source: 'x',
        acquiredUsers: 0,
        day7EligibleUsers: 4,
        day7RetainedUsers: 5,
      );

      expect(evidence.day7RetentionRate, isNull);
      expect(evidence.day30RetentionRate, isNull);
      expect(evidence.paidConversionRate, isNull);
      expect(evidence.missingInputs, hasLength(3));
    });
  });

  group('AdminPlanEconomics', () {
    test('derives gross margin, CAC, payback, churn, and LTV', () {
      const economics = AdminPlanEconomics(
        planName: 'Pro',
        monthlyRevenueYen: 100000,
        paidCustomers: 20,
        monthlyAiVariableCostYen: 20000,
        monthlyOtherVariableCostYen: 0,
        monthlyAcquisitionSpendYen: 30000,
        newPaidCustomers: 10,
        beginningPaidCustomers: 20,
        churnedCustomers: 2,
      );

      expect(economics.grossMarginYen, 80000);
      expect(economics.grossMarginRate, 0.8);
      expect(economics.customerAcquisitionCostYen, 3000);
      expect(economics.grossMarginPerCustomerYen, 4000);
      expect(economics.paybackMonths, 0.75);
      expect(economics.monthlyChurnRate, 0.1);
      expect(economics.lifetimeValueYen, 40000);
      expect(economics.hasCompleteDecisionEvidence, isTrue);
      expect(economics.missingInputs, isEmpty);
    });

    test('keeps derived decisions null when required inputs are missing', () {
      const economics = AdminPlanEconomics(planName: 'unknown');

      expect(economics.grossMarginYen, isNull);
      expect(economics.grossMarginRate, isNull);
      expect(economics.customerAcquisitionCostYen, isNull);
      expect(economics.paybackMonths, isNull);
      expect(economics.monthlyChurnRate, isNull);
      expect(economics.lifetimeValueYen, isNull);
      expect(economics.hasCompleteDecisionEvidence, isFalse);
      expect(economics.missingInputs, hasLength(8));
    });

    test('does not report infinite LTV when measured churn is zero', () {
      const economics = AdminPlanEconomics(
        planName: 'Pro',
        monthlyRevenueYen: 10000,
        paidCustomers: 10,
        monthlyAiVariableCostYen: 2000,
        monthlyOtherVariableCostYen: 0,
        beginningPaidCustomers: 10,
        churnedCustomers: 0,
      );

      expect(economics.monthlyChurnRate, 0);
      expect(economics.lifetimeValueYen, isNull);
      expect(economics.hasCompleteDecisionEvidence, isFalse);
    });

    test('requires non-AI variable cost before reporting gross margin', () {
      const economics = AdminPlanEconomics(
        planName: 'Pro',
        monthlyRevenueYen: 10000,
        paidCustomers: 10,
        monthlyAiVariableCostYen: 2000,
      );

      expect(economics.grossMarginYen, isNull);
      expect(economics.missingInputs, contains('その他変動費'));
    });
  });
}
