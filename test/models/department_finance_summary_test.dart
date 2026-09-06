import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/department_finance_summary.dart';

void main() {
  test('parses the finance summary contract and availability', () {
    final summary = DepartmentFinanceSummary.fromJson({
      'status': 'ok',
      'month_key': '2026-09',
      'net_assets': 1250000,
      'current_month_cashflow': -25000,
      'investment_valuation': 840000,
      'anomaly_count': 3,
      'availability': {
        'net_assets': 'available',
        'current_month_cashflow': 'available',
        'investment_valuation': 'partial',
        'anomaly_count': 'available',
      },
    });

    expect(summary.monthKey, '2026-09');
    expect(summary.currentMonthCashflow, -25000);
    expect(summary.anomalyCount, 3);
    expect(
      summary.investmentValuationAvailability,
      FinanceMetricAvailability.partial,
    );
  });

  test('keeps unavailable financial values null instead of inventing zero', () {
    final summary = DepartmentFinanceSummary.fromJson({
      'status': 'ok',
      'month_key': '2026-09',
      'net_assets': null,
      'current_month_cashflow': null,
      'investment_valuation': 0,
      'anomaly_count': 0,
      'availability': {
        'net_assets': 'not_recorded',
        'current_month_cashflow': 'not_recorded',
        'investment_valuation': 'not_recorded',
        'anomaly_count': 'available',
      },
    });

    expect(summary.netAssets, isNull);
    expect(summary.currentMonthCashflow, isNull);
    expect(
      summary.netAssetsAvailability,
      FinanceMetricAvailability.notRecorded,
    );
  });

  test('rejects malformed counts', () {
    expect(
      () => DepartmentFinanceSummary.fromJson({
        'status': 'ok',
        'month_key': '2026-09',
        'net_assets': null,
        'current_month_cashflow': null,
        'investment_valuation': 0,
        'anomaly_count': -1,
        'availability': {
          'net_assets': 'not_recorded',
          'current_month_cashflow': 'not_recorded',
          'investment_valuation': 'not_recorded',
          'anomaly_count': 'available',
        },
      }),
      throwsFormatException,
    );
  });
}
