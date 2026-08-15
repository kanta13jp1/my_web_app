import 'dart:math' as math;

import '../models/investment_portfolio_history.dart';

enum InvestmentHistoryPeriod { oneYear, threeYears, lifetime }

class InvestmentPortfolioHistoryService {
  const InvestmentPortfolioHistoryService({this.maxChartPoints = 180});

  final int maxChartPoints;

  List<InvestmentPortfolioHistoryPoint> selectForChart(
    Iterable<InvestmentPortfolioHistoryPoint> points, {
    required InvestmentHistoryPeriod period,
    required DateTime now,
  }) {
    if (maxChartPoints < 2) {
      throw StateError('maxChartPoints must be at least 2');
    }

    final sorted = points.toList(growable: false)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final cutoff = _cutoff(period, now.toUtc());
    final filtered = sorted
        .where((point) => point.pricedAssetCount > 0)
        .where(
          (point) =>
              cutoff == null || !point.recordedAt.toUtc().isBefore(cutoff),
        )
        .toList(growable: false);

    if (filtered.length <= maxChartPoints) {
      return List<InvestmentPortfolioHistoryPoint>.unmodifiable(filtered);
    }

    final lastIndex = filtered.length - 1;
    final sampled = <InvestmentPortfolioHistoryPoint>[];
    for (var index = 0; index < maxChartPoints; index++) {
      final sourceIndex = (index * lastIndex / (maxChartPoints - 1)).round();
      sampled.add(filtered[sourceIndex]);
    }
    return List<InvestmentPortfolioHistoryPoint>.unmodifiable(sampled);
  }

  DateTime? _cutoff(InvestmentHistoryPeriod period, DateTime now) {
    return switch (period) {
      InvestmentHistoryPeriod.oneYear => _yearsBefore(now, 1),
      InvestmentHistoryPeriod.threeYears => _yearsBefore(now, 3),
      InvestmentHistoryPeriod.lifetime => null,
    };
  }

  DateTime _yearsBefore(DateTime value, int years) {
    final year = value.year - years;
    final lastDay = DateTime.utc(year, value.month + 1, 0).day;
    return DateTime.utc(
      year,
      value.month,
      math.min(value.day, lastDay),
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }
}
