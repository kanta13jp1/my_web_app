import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
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
}
