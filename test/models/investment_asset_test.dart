import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_asset.dart';

void main() {
  group('InvestmentAsset', () {
    test('parses PostgREST numeric strings and nullable pricing fields', () {
      final asset = InvestmentAsset.fromMap(<String, dynamic>{
        'id': 'asset-1',
        'user_id': 'user-1',
        'asset_type': 'stock',
        'ticker': '7203',
        'quantity': '12.50000000',
        'buy_price_jpy': '2500.0000',
        'buy_date': '2026-05-20',
        'current_price_jpy': '2800.0000',
        'last_priced_at': '2026-05-22T03:00:00Z',
        'created_at': '2026-05-20T01:00:00Z',
        'updated_at': '2026-05-22T03:00:00Z',
      });

      expect(asset.assetType, InvestmentAssetType.stock);
      expect(asset.quantity, 12.5);
      expect(asset.buyPriceJpy, 2500);
      expect(asset.currentPriceJpy, 2800);
      expect(asset.buyDate, DateTime(2026, 5, 20));
      expect(asset.lastPricedAt, DateTime.utc(2026, 5, 22, 3));
    });

    test('normalizes draft ticker and emits schema-shaped payloads', () {
      final draft = InvestmentAssetDraft(
        assetType: InvestmentAssetType.crypto,
        ticker: ' btc-jpy ',
        quantity: 0.125,
        buyPriceJpy: 10000000,
        buyDate: DateTime(2026, 5, 1, 18),
      );

      expect(draft.toInsertMap(userId: 'user-1'), <String, dynamic>{
        'user_id': 'user-1',
        'asset_type': 'crypto',
        'ticker': 'BTC-JPY',
        'quantity': 0.125,
        'buy_price_jpy': 10000000,
        'buy_date': '2026-05-01',
        'current_price_jpy': null,
        'last_priced_at': null,
      });
    });

    test('rejects values that violate database constraints', () {
      expect(
        () => const InvestmentAssetDraft(
          assetType: InvestmentAssetType.etf,
          ticker: ' ',
          quantity: 1,
          buyPriceJpy: 100,
        ).toUpdateMap(),
        throwsArgumentError,
      );
      expect(
        () => const InvestmentAssetDraft(
          assetType: InvestmentAssetType.reit,
          ticker: '8951',
          quantity: 0,
          buyPriceJpy: 100,
        ).toUpdateMap(),
        throwsArgumentError,
      );
      expect(
        () => InvestmentAssetDraft(
          assetType: InvestmentAssetType.stock,
          ticker: '7203',
          quantity: 1,
          buyPriceJpy: 100,
          lastPricedAt: DateTime.utc(2026, 5, 22),
        ).toUpdateMap(),
        throwsArgumentError,
      );
    });
  });
}
