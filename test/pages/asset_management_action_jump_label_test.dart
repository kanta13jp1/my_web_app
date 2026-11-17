import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_debt_discipline_monitor.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';

/// アクションアイテムの「対処できる場所」へのジャンプリンク文言マッピングを検証する。
/// widget を組まず、種別 → 文言の純粋な対応だけをテストする (#issue-1215 HITL)。
AssetManagementInsightActionItem _item(
  AssetManagementInsightActionType type, {
  String? relatedAccountId = 'debt-1',
}) {
  return AssetManagementInsightActionItem(
    type: type,
    severity: AssetManagementInsightSeverity.warning,
    title: 'title',
    description: 'description',
    relatedAccountId: relatedAccountId,
    dueDate: null,
    paymentDay: null,
    suggestedAction: 'suggestedAction',
  );
}

void main() {
  group('assetManagementActionJumpLabel', () {
    test('期限超過は支払済みチェックへのリンク文言を返す', () {
      expect(
        assetManagementActionJumpLabel(
          _item(AssetManagementInsightActionType.overduePayment),
        ),
        '支払済みチェックへ移動',
      );
    });

    test('支払日近接・資金ショートは支払予定確認リンクを返す', () {
      expect(
        assetManagementActionJumpLabel(
          _item(AssetManagementInsightActionType.upcomingPayment),
        ),
        '支払予定を確認する',
      );
      expect(
        assetManagementActionJumpLabel(
          _item(AssetManagementInsightActionType.cashShortageRisk),
        ),
        '支払予定を確認する',
      );
    });

    test('既存の入力不備系リンク文言は維持される (回帰)', () {
      expect(
        assetManagementActionJumpLabel(
          _item(AssetManagementInsightActionType.missingPaymentDay),
        ),
        '支払日を入力する',
      );
      expect(
        assetManagementActionJumpLabel(
          _item(AssetManagementInsightActionType.missingPaymentSource),
        ),
        '支払原資口座を設定する',
      );
    });

    test('関連口座が無い項目はリンクを出さない (null)', () {
      expect(
        assetManagementActionJumpLabel(
          _item(
            AssetManagementInsightActionType.overduePayment,
            relatedAccountId: null,
          ),
        ),
        isNull,
      );
      expect(
        assetManagementActionJumpLabel(
          _item(
            AssetManagementInsightActionType.overduePayment,
            relatedAccountId: '   ',
          ),
        ),
        isNull,
      );
    });

    test('リンク対象外の種別は null を返す', () {
      expect(
        assetManagementActionJumpLabel(
          _item(AssetManagementInsightActionType.emergencyLivingExpense),
        ),
        isNull,
      );
    });
  });

  group('reassignCardStatementLine', () {
    test('指定した未照合明細のみ請求先カードIDと名称を更新し他行を保持する', () {
      final lines = <AssetLiabilityCardStatementLine>[
        AssetLiabilityCardStatementLine(
          id: 'line-1',
          billingAccountId: 'unknown_card',
          billingAccountName: '未登録カード',
          postedAt: DateTime(2026, 10, 10),
          description: 'スーパーマーケット',
          amount: 3200,
        ),
        AssetLiabilityCardStatementLine(
          id: 'line-2',
          billingAccountId: 'famipay',
          billingAccountName: 'ファミペイ',
          postedAt: DateTime(2026, 10, 11),
          description: 'コンビニ',
          amount: 850,
        ),
      ];

      final updated = reassignCardStatementLine(
        lines,
        lineId: 'line-1',
        billingAccountId: 'aupay_card',
        billingAccountName: 'auPAYカード',
      );

      expect(updated.length, 2);
      expect(updated[0].billingAccountId, 'aupay_card');
      expect(updated[0].billingAccountName, 'auPAYカード');
      expect(updated[0].description, 'スーパーマーケット');
      expect(updated[0].amount, 3200);
      expect(updated[1].billingAccountId, 'famipay');
      expect(updated[1].billingAccountName, 'ファミペイ');
    });
  });

  group('unreconciledBalanceDiffBreakdown', () {
    test('newBorrowing かつ正の金額の候補のみを抽出して合計内訳として返す', () {
      final report = AssetDebtDisciplineReport(
        windowDays: 28,
        zeroNewBorrowingAchieved: false,
        newUsageRepaymentAchieved: false,
        hasPriorMonthData: true,
        totalNewBorrowing: 67013,
        totalNewUsageRepaymentShortfall: 10000,
        newBorrowingViolations: const <AssetDebtDisciplineViolation>[
          AssetDebtDisciplineViolation(
            type: AssetDebtDisciplineViolationType.newBorrowing,
            severity: AssetDebtTrendSeverity.critical,
            accountId: 'mobit',
            accountName: 'モビット',
            kind: AssetLiabilityAccountKind.cardLoan,
            amount: 40000,
            currentBalance: 140000,
            problem: 'problem',
            action: 'action',
          ),
          AssetDebtDisciplineViolation(
            type: AssetDebtDisciplineViolationType.newBorrowing,
            severity: AssetDebtTrendSeverity.critical,
            accountId: 'acom',
            accountName: 'アコムカードローン',
            kind: AssetLiabilityAccountKind.cardLoan,
            amount: 27013,
            currentBalance: 127013,
            problem: 'problem',
            action: 'action',
          ),
        ],
        revolvingViolations: const <AssetDebtDisciplineViolation>[
          AssetDebtDisciplineViolation(
            type: AssetDebtDisciplineViolationType.revolvingCard,
            severity: AssetDebtTrendSeverity.warning,
            accountId: 'aupay',
            accountName: 'auPAYカード',
            kind: AssetLiabilityAccountKind.creditCard,
            amount: 10000,
            currentBalance: 50000,
            problem: 'problem',
            action: 'action',
          ),
        ],
      );

      final breakdown = unreconciledBalanceDiffBreakdown(report);
      expect(breakdown.length, 2);
      expect(breakdown[0].accountName, 'モビット');
      expect(breakdown[0].amount, 40000);
      expect(breakdown[1].accountName, 'アコムカードローン');
      expect(breakdown[1].amount, 27013);
    });
  });
}
