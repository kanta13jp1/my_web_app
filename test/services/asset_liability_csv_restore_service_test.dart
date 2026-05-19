import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';

void main() {
  group('AssetLiabilityCsvRestoreService', () {
    const service = AssetLiabilityCsvRestoreService();

    test('previews monthly history, payment schedule, and income plans', () {
      final preview =
          service.previewCsvSections(<AssetLiabilityCsvRestoreSection, String>{
        AssetLiabilityCsvRestoreSection.monthlyHistory: [
          'month_key,saved_at,assets,liabilities,net_worth,cash,scheduled,paid,unpaid,overdue,actual_paid_payment_total,payment_difference_total',
          '2026-05,2026-05-31 20:00:00,60000,-100000,-40000,50000,20000,6200,13800,1,6200,1200',
        ].join('\n'),
        AssetLiabilityCsvRestoreSection.paymentSchedule: [
          'category,alerts,direct_target,source,billing_card,date,account,source_account,method,card_billed,direct_cashflow,amount,estimate_state,paid_state,overdue,cash_after,actual_payment_amount,payment_difference_amount,payment_difference_reason',
          'direct,ok,target,manual,,2026-05-20,"auPay card",Bank,direct,direct,target,5000,actual,paid,,45000,6200,1200,"late fee, adjustment"',
        ].join('\n'),
        AssetLiabilityCsvRestoreSection.incomePlans: [
          'date,name,amount,destination,received',
          '2026-05-25,"副業,臨時収入",30000,main bank,yes',
        ].join('\n'),
      });

      expect(preview.rejectedRows, isEmpty);
      expect(preview.monthlySnapshots.single.monthKey, '2026-05');
      expect(preview.monthlySnapshots.single.monthlyActualPaymentTotal, 6200);
      expect(preview.affectedMonthKeys, <String>['2026-05']);

      final mayState = preview.monthlyStates['2026-05']!;
      expect(mayState.paymentOverrides['auPay card'], 5000);
      expect(mayState.actualPaymentAmounts['auPay card'], 6200);
      expect(
        mayState.paymentDifferenceReasons['auPay card'],
        'late fee, adjustment',
      );
      expect(mayState.paidAccountNames, contains('auPay card'));
      expect(mayState.incomePlans.single.name, '副業,臨時収入');
      expect(mayState.incomePlans.single.received, isTrue);
    });

    test('keeps existing state unless an explicit overwrite policy is used',
        () {
      final preview =
          service.previewCsvSections(<AssetLiabilityCsvRestoreSection, String>{
        AssetLiabilityCsvRestoreSection.paymentSchedule: [
          'category,alerts,direct_target,source,billing_card,date,account,source_account,method,card_billed,direct_cashflow,amount,estimate_state,paid_state,overdue,cash_after,actual_payment_amount,payment_difference_amount,payment_difference_reason',
          'direct,ok,target,manual,,2026-05-20,mobit,Bank,direct,direct,target,70000,actual,paid,,0,70000,0,',
        ].join('\n'),
      });
      final existing = AssetLiabilityMonthlyState(
        paymentOverrides: <String, double>{'mobit': 60000},
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'existing_salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'bank',
            destinationAccountName: 'Bank',
            received: false,
          ),
        ],
      );

      final appendOnly = service.mergePreview(
        preview: preview,
        existingStates: <String, AssetLiabilityMonthlyState>{
          '2026-05': existing,
        },
        existingSnapshots: const <AssetLiabilityMonthlySnapshot>[],
        policy: AssetLiabilityCsvRestoreApplyPolicy.appendOnly,
      );
      expect(
        appendOnly.monthlyStates['2026-05']!.paymentOverrides['mobit'],
        60000,
      );
      expect(
        appendOnly.monthlyStates['2026-05']!.incomePlans.single.name,
        'Salary',
      );

      final overwrite = service.mergePreview(
        preview: preview,
        existingStates: <String, AssetLiabilityMonthlyState>{
          '2026-05': existing,
        },
        existingSnapshots: const <AssetLiabilityMonthlySnapshot>[],
        policy: AssetLiabilityCsvRestoreApplyPolicy.overwriteImportedFields,
      );
      expect(
        overwrite.monthlyStates['2026-05']!.paymentOverrides['mobit'],
        70000,
      );
      expect(
        overwrite.monthlyStates['2026-05']!.incomePlans.single.name,
        'Salary',
      );
    });

    test('rejects malformed CSV rows without mutating existing data', () {
      final preview =
          service.previewCsvSections(<AssetLiabilityCsvRestoreSection, String>{
        AssetLiabilityCsvRestoreSection.monthlyHistory: [
          'month_key,saved_at,assets,liabilities,net_worth,cash,scheduled,paid,unpaid,overdue,actual_paid_payment_total,payment_difference_total',
          'bad-month,not-date,invalid,-100000,-40000,50000,20000,6200,13800,1,6200,1200',
        ].join('\n'),
      });

      expect(preview.hasRestorableRows, isFalse);
      expect(preview.rejectedRows.single.reason, contains('invalid'));

      const existing = AssetLiabilityMonthlyState(
        paymentOverrides: <String, double>{'paypay_card': 12000},
      );
      final merged = service.mergePreview(
        preview: preview,
        existingStates: const <String, AssetLiabilityMonthlyState>{
          '2026-05': existing,
        },
        existingSnapshots: const <AssetLiabilityMonthlySnapshot>[],
        policy: AssetLiabilityCsvRestoreApplyPolicy.overwriteImportedFields,
      );

      expect(
        merged.monthlyStates['2026-05']!.paymentOverrides['paypay_card'],
        12000,
      );
      expect(merged.warnings.single, contains('No restorable rows'));
    });

    test('restores escaped card statement fields with Japanese text', () {
      final preview =
          service.previewCsvSections(<AssetLiabilityCsvRestoreSection, String>{
        AssetLiabilityCsvRestoreSection.cardStatement: [
          'billing_account_id,billing_account_name,posted_at,description,amount,billed_amount,statement_line_total,configured_detail_total,statement_difference,configured_difference,review_alerts',
          'paypay_card,PayPay,2026-05-12,"通信費 ""家族,共有""",5764,10000,5764,5764,-4236,-4236,',
        ].join('\n'),
      });

      expect(preview.rejectedRows, isEmpty);
      final line = preview.monthlyStates['2026-05']!.cardStatementLines.single;
      expect(line.billingAccountId, 'paypay_card');
      expect(line.description, '通信費 "家族,共有"');
      expect(line.amount, 5764);
      expect(line.postedAt, DateTime(2026, 5, 12));
    });
  });
}
