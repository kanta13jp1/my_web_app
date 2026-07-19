import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_asset.dart';
import 'package:my_web_app/services/investment_valuation_service.dart';

void main() {
  const service = InvestmentValuationService();

  group('InvestmentValuationService', () {
    test('calculates market value and unrealized gain deterministically', () {
      final valuation = service.evaluate(
        _asset(
          id: 'stock-1',
          quantity: 12.5,
          buyPriceJpy: 2500,
          currentPriceJpy: 2800,
        ),
      );

      expect(valuation.acquisitionCostJpy, 31250);
      expect(valuation.marketValueJpy, 35000);
      expect(valuation.unrealizedGainLossJpy, 3750);
      expect(valuation.unrealizedGainLossRate, closeTo(0.12, 0.000001));
      expect(valuation.isPriced, isTrue);
    });

    test('keeps unpriced holdings explicit instead of assuming a price', () {
      final valuation = service.evaluate(
        _asset(id: 'crypto-1', quantity: 0.1, buyPriceJpy: 10000000),
      );

      expect(valuation.acquisitionCostJpy, 1000000);
      expect(valuation.marketValueJpy, isNull);
      expect(valuation.unrealizedGainLossJpy, isNull);
      expect(valuation.unrealizedGainLossRate, isNull);
      expect(valuation.isPriced, isFalse);
    });

    test('summarizes priced holdings without hiding unpriced holdings', () {
      final summary = service.summarize(<InvestmentAsset>[
        _asset(
          id: 'stock-1',
          quantity: 10,
          buyPriceJpy: 1000,
          currentPriceJpy: 1200,
        ),
        _asset(
          id: 'reit-1',
          quantity: 2,
          buyPriceJpy: 5000,
          currentPriceJpy: 4500,
        ),
        _asset(id: 'crypto-1', quantity: 0.1, buyPriceJpy: 100000),
      ]);

      expect(summary.items, hasLength(3));
      expect(summary.totalAcquisitionCostJpy, 30000);
      expect(summary.pricedAcquisitionCostJpy, 20000);
      expect(summary.pricedMarketValueJpy, 21000);
      expect(summary.totalUnrealizedGainLossJpy, 1000);
      expect(summary.totalUnrealizedGainLossRate, closeTo(0.05, 0.000001));
      expect(summary.unpricedAssetCount, 1);
      expect(summary.isComplete, isFalse);
    });
  });
}

InvestmentAsset _asset({
  required String id,
  required double quantity,
  required double buyPriceJpy,
  double? currentPriceJpy,
}) {
  return InvestmentAsset(
    id: id,
    userId: 'user-1',
    assetType: InvestmentAssetType.stock,
    ticker: id,
    quantity: quantity,
    buyPriceJpy: buyPriceJpy,
    buyDate: DateTime(2026, 5, 1),
    currentPriceJpy: currentPriceJpy,
    lastPricedAt: currentPriceJpy == null ? null : DateTime.utc(2026, 5, 22),
    createdAt: DateTime.utc(2026, 5, 1),
    updatedAt: DateTime.utc(2026, 5, 22),
  );
}
