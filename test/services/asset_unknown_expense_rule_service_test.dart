import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_unknown_expense_rule_service.dart';

void main() {
  group('AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop', () {
    test('プラス残高からの減少は対象 (従来動作)', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: 'みずほ銀行',
          previousAmount: 50000,
          currentAmount: 48000,
        ),
        isTrue,
      );
    });

    test('減少幅 1 円未満・増加は対象外', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '現金',
          previousAmount: 10000,
          currentAmount: 10000,
        ),
        isFalse,
      );
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '現金',
          previousAmount: 1000,
          currentAmount: 5000,
        ),
        isFalse,
      );
    });

    test('投資系タイプの減少は対象外 (評価損と区別できない)', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '証券口座',
          previousAmount: 100000,
          currentAmount: 90000,
        ),
        isFalse,
      );
    });

    test('現金: プラスからマイナスへ跨ぐ減少は対象 (従来動作)', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '現金',
          previousAmount: 500,
          currentAmount: -200,
        ),
        isTrue,
      );
    });

    test('現金: 残高 0 からマイナスへの減少も対象 (新規)', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '現金',
          previousAmount: 0,
          currentAmount: -3000,
        ),
        isTrue,
      );
    });

    test('現金: マイナス圏からさらに減少も対象 (新規)', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '現金',
          previousAmount: -3000,
          currentAmount: -8000,
        ),
        isTrue,
      );
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '手元現金',
          previousAmount: -100,
          currentAmount: -1100,
        ),
        isTrue,
      );
    });

    test('現金: マイナス圏での増加 (返済・補充) は対象外', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '現金',
          previousAmount: -8000,
          currentAmount: -2000,
        ),
        isFalse,
      );
    });

    test('現金以外: マイナス圏の減少は従来どおり対象外 (負債系の誤記録防止)', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: 'カード未払',
          previousAmount: -50000,
          currentAmount: -80000,
        ),
        isFalse,
      );
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: '銀行口座',
          previousAmount: 0,
          currentAmount: -1000,
        ),
        isFalse,
      );
    });

    test('英語表記 cash も現金系として扱う', () {
      expect(
        AssetUnknownExpenseRuleService.shouldAutoRecordFromAssetDrop(
          assetType: 'Cash Wallet',
          previousAmount: -100,
          currentAmount: -200,
        ),
        isTrue,
      );
    });
  });

  group('type 判定ヘルパー', () {
    test('isCashLikeType', () {
      expect(AssetUnknownExpenseRuleService.isCashLikeType('現金'), isTrue);
      expect(AssetUnknownExpenseRuleService.isCashLikeType('手元現金'), isTrue);
      expect(AssetUnknownExpenseRuleService.isCashLikeType('Cash'), isTrue);
      expect(AssetUnknownExpenseRuleService.isCashLikeType('みずほ銀行'), isFalse);
    });

    test('isInvestmentLikeType', () {
      expect(
        AssetUnknownExpenseRuleService.isInvestmentLikeType('証券口座'),
        isTrue,
      );
      expect(
        AssetUnknownExpenseRuleService.isInvestmentLikeType('NISA'),
        isTrue,
      );
      expect(
        AssetUnknownExpenseRuleService.isInvestmentLikeType('現金'),
        isFalse,
      );
    });
  });
}
