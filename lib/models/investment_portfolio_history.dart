class InvestmentPortfolioHistoryPoint {
  const InvestmentPortfolioHistoryPoint({
    required this.recordedAt,
    required this.marketValueJpy,
    required this.acquisitionCostJpy,
    required this.pricedAssetCount,
    required this.unpricedAssetCount,
  });

  final DateTime recordedAt;
  final double marketValueJpy;
  final double acquisitionCostJpy;
  final int pricedAssetCount;
  final int unpricedAssetCount;

  factory InvestmentPortfolioHistoryPoint.fromMap(Map<String, dynamic> row) {
    return InvestmentPortfolioHistoryPoint(
      recordedAt: _requiredDate(row, 'recorded_at').toUtc(),
      marketValueJpy: _requiredDouble(row, 'market_value_jpy'),
      acquisitionCostJpy: _requiredDouble(row, 'acquisition_cost_jpy'),
      pricedAssetCount: _requiredInt(row, 'priced_asset_count'),
      unpricedAssetCount: _requiredInt(row, 'unpriced_asset_count'),
    );
  }
}

double _requiredDouble(Map<String, dynamic> row, String key) {
  final value = row[key];
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite || parsed < 0) {
    throw FormatException('Missing or invalid $key in portfolio history row');
  }
  return parsed;
}

int _requiredInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  final parsed =
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 0) {
    throw FormatException('Missing or invalid $key in portfolio history row');
  }
  return parsed;
}

DateTime _requiredDate(Map<String, dynamic> row, String key) {
  final parsed = DateTime.tryParse(row[key]?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Missing or invalid $key in portfolio history row');
  }
  return parsed;
}
