enum InvestmentAssetType {
  stock('stock'),
  crypto('crypto'),
  reit('reit'),
  etf('etf');

  const InvestmentAssetType(this.storageKey);

  final String storageKey;

  static InvestmentAssetType fromStorageKey(String value) {
    return values.firstWhere(
      (type) => type.storageKey == value,
      orElse: () =>
          throw FormatException('Unsupported investment asset type: $value'),
    );
  }
}

enum InvestmentTickerValidationError { empty, invalidFormat }

String normalizeInvestmentTicker(String value) => value.trim().toUpperCase();

InvestmentTickerValidationError? investmentTickerValidationError(
  String? value, {
  String? existingTicker,
}) {
  final normalized = normalizeInvestmentTicker(value ?? '');
  if (normalized.isEmpty) {
    return InvestmentTickerValidationError.empty;
  }
  if (_investmentTickerPattern.hasMatch(normalized)) {
    return null;
  }

  // Keep already-stored legacy symbols editable without accepting a new
  // unsupported ticker at the market-price boundary.
  if (existingTicker != null &&
      normalized == normalizeInvestmentTicker(existingTicker)) {
    return null;
  }
  return InvestmentTickerValidationError.invalidFormat;
}

class InvestmentAsset {
  const InvestmentAsset({
    required this.id,
    required this.userId,
    required this.assetType,
    required this.ticker,
    required this.quantity,
    required this.buyPriceJpy,
    required this.buyDate,
    required this.currentPriceJpy,
    required this.lastPricedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final InvestmentAssetType assetType;
  final String ticker;
  final double quantity;
  final double buyPriceJpy;
  final DateTime? buyDate;
  final double? currentPriceJpy;
  final DateTime? lastPricedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory InvestmentAsset.fromMap(Map<String, dynamic> row) {
    return InvestmentAsset(
      id: _requiredString(row, 'id'),
      userId: _requiredString(row, 'user_id'),
      assetType: InvestmentAssetType.fromStorageKey(
        _requiredString(row, 'asset_type'),
      ),
      ticker: _requiredString(row, 'ticker'),
      quantity: _requiredDouble(row, 'quantity'),
      buyPriceJpy: _requiredDouble(row, 'buy_price_jpy'),
      buyDate: _nullableDate(row['buy_date']),
      currentPriceJpy: _nullableDouble(row['current_price_jpy']),
      lastPricedAt: _nullableDate(row['last_priced_at']),
      createdAt: _requiredDate(row, 'created_at'),
      updatedAt: _requiredDate(row, 'updated_at'),
    );
  }

  InvestmentAssetDraft toDraft() {
    return InvestmentAssetDraft(
      assetType: assetType,
      ticker: ticker,
      existingTicker: ticker,
      quantity: quantity,
      buyPriceJpy: buyPriceJpy,
      buyDate: buyDate,
      currentPriceJpy: currentPriceJpy,
      lastPricedAt: lastPricedAt,
    );
  }
}

class InvestmentAssetDraft {
  const InvestmentAssetDraft({
    required this.assetType,
    required this.ticker,
    this.existingTicker,
    required this.quantity,
    required this.buyPriceJpy,
    this.buyDate,
    this.currentPriceJpy,
    this.lastPricedAt,
  });

  final InvestmentAssetType assetType;
  final String ticker;
  final String? existingTicker;
  final double quantity;
  final double buyPriceJpy;
  final DateTime? buyDate;
  final double? currentPriceJpy;
  final DateTime? lastPricedAt;

  String get normalizedTicker => normalizeInvestmentTicker(ticker);

  Map<String, dynamic> toInsertMap({required String userId}) {
    _validate(userId: userId, allowExistingTicker: false);
    return <String, dynamic>{'user_id': userId.trim(), ...toUpdateMap()};
  }

  Map<String, dynamic> toUpdateMap() {
    _validate();
    return <String, dynamic>{
      'asset_type': assetType.storageKey,
      'ticker': normalizedTicker,
      'quantity': quantity,
      'buy_price_jpy': buyPriceJpy,
      'buy_date': _dateOnly(buyDate),
      'current_price_jpy': currentPriceJpy,
      'last_priced_at': lastPricedAt?.toUtc().toIso8601String(),
    };
  }

  void _validate({String? userId, bool allowExistingTicker = true}) {
    if (userId != null && userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    switch (investmentTickerValidationError(
      ticker,
      existingTicker: allowExistingTicker ? existingTicker : null,
    )) {
      case InvestmentTickerValidationError.empty:
        throw ArgumentError.value(ticker, 'ticker', 'must not be empty');
      case InvestmentTickerValidationError.invalidFormat:
        throw ArgumentError.value(
          ticker,
          'ticker',
          'must be 1-32 chars of A-Z, 0-9, dot, underscore, colon, or hyphen',
        );
      case null:
        break;
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
    if (!buyPriceJpy.isFinite || buyPriceJpy < 0) {
      throw ArgumentError.value(
        buyPriceJpy,
        'buyPriceJpy',
        'must be non-negative',
      );
    }
    final currentPrice = currentPriceJpy;
    if (currentPrice != null && (!currentPrice.isFinite || currentPrice < 0)) {
      throw ArgumentError.value(
        currentPrice,
        'currentPriceJpy',
        'must be non-negative',
      );
    }
    if (lastPricedAt != null && currentPrice == null) {
      throw ArgumentError(
        'currentPriceJpy is required when lastPricedAt is set',
      );
    }
  }
}

final RegExp _investmentTickerPattern = RegExp(r'^[A-Z0-9._:-]{1,32}$');

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim() ?? '';
  if (value.isEmpty) {
    throw FormatException('Missing $key in investment asset row');
  }
  return value;
}

double _requiredDouble(Map<String, dynamic> row, String key) {
  final value = _nullableDouble(row[key]);
  if (value == null) {
    throw FormatException('Missing or invalid $key in investment asset row');
  }
  return value;
}

double? _nullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

DateTime _requiredDate(Map<String, dynamic> row, String key) {
  final value = _nullableDate(row[key]);
  if (value == null) {
    throw FormatException('Missing or invalid $key in investment asset row');
  }
  return value;
}

DateTime? _nullableDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

String? _dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
