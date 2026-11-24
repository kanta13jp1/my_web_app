import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_emergency_defense_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

AssetLiabilityCashflowRow _row({
  required String id,
  required String name,
  required double amount,
  AssetLiabilityCashflowEventType eventType =
      AssetLiabilityCashflowEventType.payment,
  bool paid = false,
  bool received = false,
}) {
  return AssetLiabilityCashflowRow(
    eventType: eventType,
    accountId: id,
    accountName: name,
    paymentDay: 25,
    paymentDate: DateTime(2026, 6, 25),
    paymentSourceAccountId:
        eventType == AssetLiabilityCashflowEventType.income ? null : 'jibun',
    paymentSourceAccountName:
        eventType == AssetLiabilityCashflowEventType.income ? null : 'じぶん銀行',
    destinationAccountId:
        eventType == AssetLiabilityCashflowEventType.income ? 'jibun' : null,
    destinationAccountName:
        eventType == AssetLiabilityCashflowEventType.income ? 'じぶん銀行' : null,
    paymentMethod: AssetLiabilityPaymentMethod.direct,
    paymentMethodLabel: null,
    paymentMethodSettingSource:
        AssetLiabilityPaymentMethodSettingSource.builtInDefault,
    billingAccountId: null,
    billingAccountName: null,
    includedInBillingAccount: false,
    paymentAmount: amount,
    paymentAmountEstimated: false,
    paid: paid,
    received: received,
    overdue: false,
    cashBeforePayment: 100000,
    cashAfterPayment: 100000 - amount,
    riskLevel: AssetLiabilityCashRiskLevel.normal,
  );
}

void main() {
  group('AssetEmergencyDefenseService (#3289)', () {
    test('classifies essential rent/telecom/utilities vs credit card debt', () {
      expect(
        AssetEmergencyDefenseService.isEssentialCashflowRow(
          _row(id: 'rent', name: '家賃', amount: 80000),
        ),
        isTrue,
      );
      expect(
        AssetEmergencyDefenseService.isEssentialCashflowRow(
          _row(id: 'kddi', name: 'KDDI', amount: 6000),
        ),
        isTrue,
      );
      expect(
        AssetEmergencyDefenseService.isEssentialCashflowRow(
          _row(id: 'au_mobile', name: 'au', amount: 4500),
        ),
        isTrue,
      );
      expect(
        AssetEmergencyDefenseService.isEssentialCashflowRow(
          _row(
            id: 'salary',
            name: '給与入金',
            amount: 220000,
            eventType: AssetLiabilityCashflowEventType.income,
          ),
        ),
        isTrue,
      );
      expect(
        AssetEmergencyDefenseService.isEssentialCashflowRow(
          _row(id: 'aupay_card', name: 'auPAYカード', amount: 40000),
        ),
        isFalse,
      );
      expect(
        AssetEmergencyDefenseService.isEssentialCashflowRow(
          _row(id: 'acom', name: 'アコム', amount: 30000),
        ),
        isFalse,
      );
    });

    test('calculates cashAfterEssentials, essentialTotal, and shortage', () {
      final summary = AssetEmergencyDefenseService.summarizeRows(
        cashLikeTotal: 70000,
        monthlyUnreceivedIncomeTotal: 0,
        cashflowRows: [
          _row(id: 'rent', name: '家賃', amount: 80000),
          _row(id: 'kddi', name: 'KDDI', amount: 5000),
          _row(id: 'au', name: 'au', amount: 4000),
          _row(id: 'acom', name: 'アコム', amount: 50000),
        ],
      );

      expect(summary.essentialTotal, 89000);
      expect(summary.essentialUnpaidTotal, 89000);
      expect(summary.deferrableTotal, 50000);
      expect(summary.cashAfterEssentials, -19000);
      expect(summary.hasShortage, isTrue);
      expect(summary.shortageAmount, 19000);
      expect(summary.essentialRows.length, 3);
      expect(summary.deferrableRows.length, 1);
    });

    test('propagates essential flag and insight guidance via planner', () {
      final workbook = const AssetLiabilityPlanningService().buildWorkbook(
        latestSnapshot: const <String, double>{
          'じぶん銀行': 60000,
          'アコム': -200000,
        },
        baseDate: DateTime(2026, 6, 15),
        paymentDayOverrides: const <String, int>{'アコム': 27},
        includeDefaultFixedPayments: true,
        salaryDay: 25,
      );

      final rentRow = workbook.cashflowRows.firstWhere(
        (r) => r.accountName == '家賃',
      );
      final kddiRow = workbook.cashflowRows.firstWhere(
        (r) => r.accountName == 'KDDI',
      );
      final acomRow = workbook.cashflowRows.firstWhere(
        (r) => r.accountName == 'アコム',
      );
      expect(rentRow.essential, isTrue);
      expect(kddiRow.essential, isTrue);
      expect(acomRow.essential, isFalse);
      expect(acomRow.deferrable, isTrue);
      expect(workbook.cashAfterEssentials, isNotNull);

      final report = const AssetManagementInsightService().buildReport(
        workbook: workbook,
        emergencyMode: true,
      );
      expect(
        report.actionItems.first.title,
        contains('生活防衛モード'),
      );
      expect(
        report.actionItems.first.suggestedAction,
        contains('支払順を組み替えて'),
      );
    });
  });
}
