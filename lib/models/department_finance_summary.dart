enum FinanceMetricAvailability { available, partial, notRecorded }

class DepartmentFinanceSummary {
  const DepartmentFinanceSummary({
    required this.monthKey,
    required this.netAssets,
    required this.currentMonthCashflow,
    required this.investmentValuation,
    required this.anomalyCount,
    required this.netAssetsAvailability,
    required this.currentMonthCashflowAvailability,
    required this.investmentValuationAvailability,
    required this.anomalyCountAvailability,
  });

  factory DepartmentFinanceSummary.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ok') {
      throw const FormatException('Finance summary status is invalid.');
    }
    final availability = _record(json['availability'], 'availability');
    return DepartmentFinanceSummary(
      monthKey: _requiredString(json['month_key'], 'month_key'),
      netAssets: _optionalNumber(json['net_assets'], 'net_assets'),
      currentMonthCashflow: _optionalNumber(
        json['current_month_cashflow'],
        'current_month_cashflow',
      ),
      investmentValuation: _requiredNumber(
        json['investment_valuation'],
        'investment_valuation',
      ),
      anomalyCount: _requiredNonNegativeInt(
        json['anomaly_count'],
        'anomaly_count',
      ),
      netAssetsAvailability: _availability(
        availability['net_assets'],
        'availability.net_assets',
      ),
      currentMonthCashflowAvailability: _availability(
        availability['current_month_cashflow'],
        'availability.current_month_cashflow',
      ),
      investmentValuationAvailability: _availability(
        availability['investment_valuation'],
        'availability.investment_valuation',
      ),
      anomalyCountAvailability: _availability(
        availability['anomaly_count'],
        'availability.anomaly_count',
      ),
    );
  }

  final String monthKey;
  final num? netAssets;
  final num? currentMonthCashflow;
  final num investmentValuation;
  final int anomalyCount;
  final FinanceMetricAvailability netAssetsAvailability;
  final FinanceMetricAvailability currentMonthCashflowAvailability;
  final FinanceMetricAvailability investmentValuationAvailability;
  final FinanceMetricAvailability anomalyCountAvailability;
}

Map<String, dynamic> _record(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$field must be an object.');
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$field must be a non-empty string.');
}

num? _optionalNumber(Object? value, String field) {
  if (value == null) return null;
  return _requiredNumber(value, field);
}

num _requiredNumber(Object? value, String field) {
  if (value is num && value.isFinite) return value;
  throw FormatException('$field must be a finite number.');
}

int _requiredNonNegativeInt(Object? value, String field) {
  final number = _requiredNumber(value, field);
  if (number < 0 || number != number.truncate()) {
    throw FormatException('$field must be a non-negative integer.');
  }
  return number.toInt();
}

FinanceMetricAvailability _availability(Object? value, String field) {
  return switch (value) {
    'available' => FinanceMetricAvailability.available,
    'partial' => FinanceMetricAvailability.partial,
    'not_recorded' => FinanceMetricAvailability.notRecorded,
    _ => throw FormatException('$field is invalid.'),
  };
}
