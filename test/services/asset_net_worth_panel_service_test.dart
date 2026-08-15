import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_net_worth_panel_service.dart';

AssetLiabilityMonthlySnapshot _snap(
  String monthKey, {
  required double netWorth,
  double assets = 0,
  double liabilities = 0,
}) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime(2026, 1, 1),
    positiveAssetTotal: assets,
    liabilityTotal: liabilities,
    netWorth: netWorth,
    cashLikeTotal: 0,
    monthlyScheduledPaymentTotal: 0,
    monthlyPaidPaymentTotal: 0,
    monthlyUnpaidPaymentTotal: 0,
    overduePaymentCount: 0,
  );
}

void main() {
  const service = AssetNetWorthPanelService();

  group('AssetNetWorthPanelService.build', () {
    test('empty snapshots produce no data', () {
      final p = service.build(
        snapshots: const <AssetLiabilityMonthlySnapshot>[],
      );
      expect(p.hasData, isFalse);
      expect(p.netWorth, isNull);
      expect(p.sparkline, isEmpty);
    });

    test('latest month drives the headline value and breakdown', () {
      final p = service.build(
        snapshots: [
          _snap('2026-05', netWorth: 100),
          _snap('2026-07', netWorth: 300, assets: 500, liabilities: 200),
          _snap('2026-06', netWorth: 200),
        ],
      );
      expect(p.monthKey, '2026-07');
      expect(p.netWorth, 300);
      expect(p.positiveAssetTotal, 500);
      expect(p.liabilityTotal, 200);
    });

    test('delta amount and percent versus previous month', () {
      final p = service.build(
        snapshots: [
          _snap('2026-06', netWorth: 200000),
          _snap('2026-07', netWorth: 250000),
        ],
      );
      expect(p.deltaAmount, 50000);
      expect(p.deltaPercent, closeTo(25.0, 1e-9));
      expect(p.isImproved, isTrue);
    });

    test('negative delta is reported with a negative percent', () {
      final p = service.build(
        snapshots: [
          _snap('2026-06', netWorth: 200000),
          _snap('2026-07', netWorth: 150000),
        ],
      );
      expect(p.deltaAmount, -50000);
      expect(p.deltaPercent, closeTo(-25.0, 1e-9));
      expect(p.isImproved, isFalse);
    });

    test('percent is null when previous month is zero (no divide by zero)', () {
      final p = service.build(
        snapshots: [
          _snap('2026-06', netWorth: 0),
          _snap('2026-07', netWorth: 50000),
        ],
      );
      expect(p.deltaAmount, 50000);
      expect(p.hasDelta, isTrue);
      // 0 基準は除算不能 → % は出さず ±¥ のみ。
      expect(p.deltaPercent, isNull);
      expect(p.hasDeltaPercent, isFalse);
    });

    test('percent is null when previous month is negative (sign would flip)',
        () {
      // -1,000,000 → -500,000 は「改善」だが比率だと -50% と出て誤読される。
      final p = service.build(
        snapshots: [
          _snap('2026-06', netWorth: -1000000),
          _snap('2026-07', netWorth: -500000),
        ],
      );
      expect(p.deltaAmount, 500000);
      expect(p.isImproved, isTrue);
      expect(p.deltaPercent, isNull);
    });

    test('single month has no delta at all', () {
      final p = service.build(snapshots: [_snap('2026-07', netWorth: 100)]);
      expect(p.hasData, isTrue);
      expect(p.hasDelta, isFalse);
      expect(p.deltaAmount, isNull);
      expect(p.deltaPercent, isNull);
      expect(p.hasSparkline, isFalse);
    });

    test('sparkline keeps the trailing 6 months in ascending order', () {
      final p = service.build(
        snapshots: [
          for (var m = 1; m <= 9; m++)
            _snap(
              '2026-${m.toString().padLeft(2, '0')}',
              netWorth: m.toDouble(),
            ),
        ],
      );
      expect(p.sparkline.length, AssetNetWorthPanelService.sparklineMonths);
      expect(
        p.sparkline.map((e) => e.monthKey).toList(),
        ['2026-04', '2026-05', '2026-06', '2026-07', '2026-08', '2026-09'],
      );
      expect(p.sparkline.last.netWorth, 9);
      expect(p.hasSparkline, isTrue);
    });

    test('current month snapshot overrides same-month history (fresher)', () {
      final p = service.build(
        snapshots: [
          _snap('2026-06', netWorth: 100),
          _snap('2026-07', netWorth: 200),
        ],
        currentMonthSnapshot: _snap('2026-07', netWorth: 999),
      );
      expect(p.netWorth, 999);
      expect(p.deltaAmount, 899);
    });

    test('blank month keys are ignored', () {
      final p = service.build(
        snapshots: [
          _snap('   ', netWorth: 12345),
          _snap('2026-07', netWorth: 100),
        ],
      );
      expect(p.monthKey, '2026-07');
      expect(p.netWorth, 100);
    });

    test('zero delta counts as improved (not a decline)', () {
      final p = service.build(
        snapshots: [
          _snap('2026-06', netWorth: 100000),
          _snap('2026-07', netWorth: 100000),
        ],
      );
      expect(p.deltaAmount, 0);
      expect(p.deltaPercent, 0);
      expect(p.isImproved, isTrue);
    });
  });
}
