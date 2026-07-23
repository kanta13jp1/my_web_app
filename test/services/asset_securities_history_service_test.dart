import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_securities_history_service.dart';

AssetLiabilityMonthlySnapshot _snap(String monthKey, {double? securities}) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime(2026, 1, 1),
    positiveAssetTotal: 0,
    liabilityTotal: 0,
    netWorth: 0,
    cashLikeTotal: 0,
    monthlyScheduledPaymentTotal: 0,
    monthlyPaidPaymentTotal: 0,
    monthlyUnpaidPaymentTotal: 0,
    overduePaymentCount: 0,
    securitiesTotal: securities,
  );
}

void main() {
  const service = AssetSecuritiesHistoryService();

  group('AssetSecuritiesHistoryService.build', () {
    test('no snapshots yields empty history', () {
      final h = service.build(
        snapshots: const <AssetLiabilityMonthlySnapshot>[],
      );
      expect(h.hasData, isFalse);
      expect(h.hasSeries, isFalse);
      expect(h.changeAmount, isNull);
    });

    test('tracked months become points in ascending order', () {
      final h = service.build(
        snapshots: [
          _snap('2026-03', securities: 300),
          _snap('2026-01', securities: 100),
          _snap('2026-02', securities: 200),
        ],
      );
      expect(
        h.points.map((p) => p.monthKey).toList(),
        ['2026-01', '2026-02', '2026-03'],
      );
      expect(h.earliest, 100);
      expect(h.latest, 300);
      expect(h.changeAmount, 200);
      expect(h.hasSeries, isTrue);
    });

    test('untracked (null) months are skipped, never coerced to zero', () {
      final h = service.build(
        snapshots: [
          _snap('2026-01', securities: 500000),
          _snap('2026-02', securities: null), // 未追跡
          _snap('2026-03', securities: 520000),
        ],
      );
      // 0 円へ落とすと 50万→0→52万 の暴落グラフを捏造してしまう。
      expect(h.points.map((p) => p.monthKey).toList(), ['2026-01', '2026-03']);
      expect(h.points.every((p) => p.securitiesTotal > 0), isTrue);
      expect(h.untrackedMonthCount, 1);
      expect(h.hasUntrackedMonths, isTrue);
    });

    test('zero is a real tracked value and is kept', () {
      final h = service.build(
        snapshots: [
          _snap('2026-01', securities: 100),
          _snap('2026-02', securities: 0), // 実際に全部売却した月
        ],
      );
      expect(h.points.length, 2);
      expect(h.points.last.securitiesTotal, 0);
      expect(h.untrackedMonthCount, 0);
      expect(h.changeAmount, -100);
    });

    test('oneYear range keeps only the trailing 12 months', () {
      final h = service.build(
        snapshots: [
          _snap('2025-06', securities: 1), // 窓外
          _snap('2025-08', securities: 2), // 窓内 (2025-08..2026-07)
          _snap('2026-07', securities: 3),
        ],
        range: AssetSecuritiesRange.oneYear,
        asOf: DateTime(2026, 7, 15),
      );
      expect(h.points.map((p) => p.monthKey).toList(), ['2025-08', '2026-07']);
    });

    test('threeYears range spans 36 months', () {
      final h = service.build(
        snapshots: [
          _snap('2023-07', securities: 1), // 37か月前 → 窓外
          _snap('2023-08', securities: 2), // 36か月前 → 窓内
          _snap('2026-07', securities: 3),
        ],
        range: AssetSecuritiesRange.threeYears,
        asOf: DateTime(2026, 7, 15),
      );
      expect(h.points.map((p) => p.monthKey).toList(), ['2023-08', '2026-07']);
    });

    test('lifetime keeps everything', () {
      final h = service.build(
        snapshots: [
          _snap('2019-01', securities: 1),
          _snap('2026-07', securities: 2),
        ],
        range: AssetSecuritiesRange.lifetime,
        asOf: DateTime(2026, 7, 15),
      );
      expect(h.points.length, 2);
    });

    test('range falls back to the latest month when asOf is omitted', () {
      final h = service.build(
        snapshots: [
          _snap('2024-01', securities: 1),
          _snap('2026-06', securities: 2),
          _snap('2026-07', securities: 3),
        ],
        range: AssetSecuritiesRange.oneYear,
      );
      expect(h.points.map((p) => p.monthKey).toList(), ['2026-06', '2026-07']);
    });

    test('current month snapshot overrides history for the same month', () {
      final h = service.build(
        snapshots: [
          _snap('2026-06', securities: 100),
          _snap('2026-07', securities: 200),
        ],
        currentMonthSnapshot: _snap('2026-07', securities: 999),
      );
      expect(h.latest, 999);
      expect(h.changeAmount, 899);
    });

    test('a single tracked month has data but no series', () {
      final h = service.build(snapshots: [_snap('2026-07', securities: 100)]);
      expect(h.hasData, isTrue);
      expect(h.hasSeries, isFalse);
      expect(h.changeAmount, isNull);
    });

    test('blank month keys are ignored', () {
      final h = service.build(
        snapshots: [
          _snap('  ', securities: 999),
          _snap('2026-07', securities: 100),
        ],
      );
      expect(h.points.length, 1);
      expect(h.points.single.monthKey, '2026-07');
    });
  });
}
