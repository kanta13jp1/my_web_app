import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_portfolio_history.dart';
import 'package:my_web_app/services/investment_portfolio_history_service.dart';

void main() {
  const service = InvestmentPortfolioHistoryService();
  final now = DateTime.utc(2026, 7, 21, 12);

  test('one year includes the exact cutoff and excludes older points', () {
    final selected = service.selectForChart(
      [
        _point(DateTime.utc(2025, 7, 21, 11)),
        _point(DateTime.utc(2025, 7, 21, 12)),
        _point(DateTime.utc(2026, 7, 21, 12)),
      ],
      period: InvestmentHistoryPeriod.oneYear,
      now: now,
    );

    expect(selected.map((point) => point.recordedAt), [
      DateTime.utc(2025, 7, 21, 12),
      DateTime.utc(2026, 7, 21, 12),
    ]);
  });

  test('three years and lifetime use distinct deterministic windows', () {
    final points = [
      _point(DateTime.utc(2022, 7, 21)),
      _point(DateTime.utc(2023, 7, 21, 12)),
      _point(DateTime.utc(2026, 7, 21)),
    ];

    final threeYears = service.selectForChart(
      points,
      period: InvestmentHistoryPeriod.threeYears,
      now: now,
    );
    final lifetime = service.selectForChart(
      points.reversed,
      period: InvestmentHistoryPeriod.lifetime,
      now: now,
    );

    expect(threeYears, hasLength(2));
    expect(lifetime, hasLength(3));
    expect(lifetime.first.recordedAt, DateTime.utc(2022, 7, 21));
    expect(lifetime.last.recordedAt, DateTime.utc(2026, 7, 21));
  });

  test('year cutoff clamps leap day to the final day of February', () {
    final selected = service.selectForChart(
      [
        _point(DateTime.utc(2023, 2, 27, 12)),
        _point(DateTime.utc(2023, 2, 28, 12)),
      ],
      period: InvestmentHistoryPeriod.oneYear,
      now: DateTime.utc(2024, 2, 29, 12),
    );

    expect(selected.single.recordedAt, DateTime.utc(2023, 2, 28, 12));
  });

  test('year cutoff handles the final day of December', () {
    final selected = service.selectForChart(
      [
        _point(DateTime.utc(2025, 12, 30, 12)),
        _point(DateTime.utc(2025, 12, 31, 12)),
      ],
      period: InvestmentHistoryPeriod.oneYear,
      now: DateTime.utc(2026, 12, 31, 12),
    );

    expect(selected.single.recordedAt, DateTime.utc(2025, 12, 31, 12));
  });

  test('downsampling preserves both endpoints and the point budget', () {
    const compact = InvestmentPortfolioHistoryService(maxChartPoints: 5);
    final points = [
      for (var day = 1; day <= 10; day++) _point(DateTime.utc(2026, 7, day)),
    ];

    final selected = compact.selectForChart(
      points,
      period: InvestmentHistoryPeriod.lifetime,
      now: now,
    );

    expect(selected, hasLength(5));
    expect(selected.first.recordedAt, points.first.recordedAt);
    expect(selected.last.recordedAt, points.last.recordedAt);
  });

  test('omits snapshots where no holding has a market price', () {
    final selected = service.selectForChart(
      [
        InvestmentPortfolioHistoryPoint(
          recordedAt: DateTime.utc(2026, 7, 20),
          marketValueJpy: 0,
          acquisitionCostJpy: 0,
          pricedAssetCount: 0,
          unpricedAssetCount: 2,
        ),
        _point(DateTime.utc(2026, 7, 21)),
      ],
      period: InvestmentHistoryPeriod.oneYear,
      now: now,
    );

    expect(selected, hasLength(1));
    expect(selected.single.recordedAt, DateTime.utc(2026, 7, 21));
  });

  test('rejects an invalid chart point budget', () {
    const invalid = InvestmentPortfolioHistoryService(maxChartPoints: 1);

    expect(
      () => invalid.selectForChart(
        const [],
        period: InvestmentHistoryPeriod.lifetime,
        now: now,
      ),
      throwsStateError,
    );
  });
}

InvestmentPortfolioHistoryPoint _point(DateTime recordedAt) {
  return InvestmentPortfolioHistoryPoint(
    recordedAt: recordedAt,
    marketValueJpy: 1200,
    acquisitionCostJpy: 1000,
    pricedAssetCount: 1,
    unpricedAssetCount: 0,
  );
}
