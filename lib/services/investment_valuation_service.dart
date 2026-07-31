import '../models/investment_asset.dart';

class InvestmentAssetValuation {
  const InvestmentAssetValuation({
    required this.asset,
    required this.acquisitionCostJpy,
    required this.marketValueJpy,
    required this.unrealizedGainLossJpy,
    required this.unrealizedGainLossRate,
  });

  final InvestmentAsset asset;
  final double acquisitionCostJpy;
  final double? marketValueJpy;
  final double? unrealizedGainLossJpy;
  final double? unrealizedGainLossRate;

  bool get isPriced => marketValueJpy != null;
}

class InvestmentPortfolioValuation {
  const InvestmentPortfolioValuation({
    required this.items,
    required this.totalAcquisitionCostJpy,
    required this.pricedAcquisitionCostJpy,
    required this.pricedMarketValueJpy,
    required this.totalUnrealizedGainLossJpy,
    required this.unpricedAssetCount,
  });

  final List<InvestmentAssetValuation> items;
  final double totalAcquisitionCostJpy;
  final double pricedAcquisitionCostJpy;
  final double pricedMarketValueJpy;
  final double totalUnrealizedGainLossJpy;
  final int unpricedAssetCount;

  bool get isComplete => unpricedAssetCount == 0;

  double? get totalUnrealizedGainLossRate {
    if (pricedAcquisitionCostJpy == 0) {
      return pricedMarketValueJpy == 0 ? 0 : null;
    }
    return totalUnrealizedGainLossJpy / pricedAcquisitionCostJpy;
  }
}

class InvestmentValuationService {
  const InvestmentValuationService();

  InvestmentAssetValuation evaluate(InvestmentAsset asset) {
    final acquisitionCost = asset.quantity * asset.buyPriceJpy;
    final currentPrice = asset.currentPriceJpy;
    if (currentPrice == null) {
      return InvestmentAssetValuation(
        asset: asset,
        acquisitionCostJpy: acquisitionCost,
        marketValueJpy: null,
        unrealizedGainLossJpy: null,
        unrealizedGainLossRate: null,
      );
    }

    final marketValue = asset.quantity * currentPrice;
    final gainLoss = marketValue - acquisitionCost;
    return InvestmentAssetValuation(
      asset: asset,
      acquisitionCostJpy: acquisitionCost,
      marketValueJpy: marketValue,
      unrealizedGainLossJpy: gainLoss,
      unrealizedGainLossRate:
          acquisitionCost == 0 ? null : gainLoss / acquisitionCost,
    );
  }

  InvestmentPortfolioValuation summarize(Iterable<InvestmentAsset> assets) {
    final items = assets.map(evaluate).toList(growable: false);
    var totalAcquisitionCost = 0.0;
    var pricedAcquisitionCost = 0.0;
    var pricedMarketValue = 0.0;
    var totalGainLoss = 0.0;
    var unpricedAssetCount = 0;

    for (final item in items) {
      totalAcquisitionCost += item.acquisitionCostJpy;
      final marketValue = item.marketValueJpy;
      final gainLoss = item.unrealizedGainLossJpy;
      if (marketValue == null || gainLoss == null) {
        unpricedAssetCount++;
        continue;
      }
      pricedAcquisitionCost += item.acquisitionCostJpy;
      pricedMarketValue += marketValue;
      totalGainLoss += gainLoss;
    }

    return InvestmentPortfolioValuation(
      items: items,
      totalAcquisitionCostJpy: totalAcquisitionCost,
      pricedAcquisitionCostJpy: pricedAcquisitionCost,
      pricedMarketValueJpy: pricedMarketValue,
      totalUnrealizedGainLossJpy: totalGainLoss,
      unpricedAssetCount: unpricedAssetCount,
    );
  }
}
