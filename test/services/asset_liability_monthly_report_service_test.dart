import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_report_service.dart';

void main() {
  group('AssetLiabilityMonthlyReportService', () {
    const service = AssetLiabilityMonthlyReportService();

    test('merges generated reports with local KPI snapshots by month', () {
      final views = service.buildReportViews(
        snapshots: <AssetLiabilityMonthlySnapshot>[
          _snapshot('2026-05', netWorth: -7000000),
          _snapshot('2026-06', netWorth: -6500000),
        ],
        reports: <AssetLiabilityMonthlyReport>[
          AssetLiabilityMonthlyReport(
            monthKey: '2026-06',
            generatedAt: DateTime.utc(2026, 7, 1),
            totalAssets: 180000,
            totalLiabilities: -6680000,
            netWorth: -6500000,
            aiSummary: 'AI summary for June',
            aiModel: 'claude-opus-4-7',
          ),
        ],
      );

      expect(views.map((view) => view.monthKey), <String>[
        '2026-06',
        '2026-05',
      ]);
      expect(views.first.hasAiReport, isTrue);
      expect(views.first.summary, 'AI summary for June');
      expect(views.first.aiModel, 'claude-opus-4-7');
      expect(views.first.netWorthDelta, 500000);
      expect(views.last.hasAiReport, isFalse);
      expect(views.last.summary, contains('2026-05 月次資産レポート'));
    });

    test('keeps remote-only reports visible until snapshots are synced', () {
      final views = service.buildReportViews(
        snapshots: const <AssetLiabilityMonthlySnapshot>[],
        reports: <AssetLiabilityMonthlyReport>[
          AssetLiabilityMonthlyReport(
            monthKey: '2026-07',
            generatedAt: DateTime.utc(2026, 8, 1),
            totalAssets: 100000,
            totalLiabilities: -600000,
            netWorth: -500000,
            aiSummary: '',
            aiModel: '',
          ),
        ],
      );

      expect(views.single.monthKey, '2026-07');
      expect(views.single.totalAssets, 100000);
      expect(views.single.summary, contains('KPIスナップショットがまだ端末側に同期されていません'));
      expect(views.single.aiModel, 'deterministic-local-snapshot');
    });

    test('applies limit after descending month sort', () {
      final views = service.buildReportViews(
        snapshots: <AssetLiabilityMonthlySnapshot>[
          _snapshot('2026-05', netWorth: -7000000),
          _snapshot('2026-06', netWorth: -6500000),
          _snapshot('2026-07', netWorth: -6400000),
        ],
        reports: const <AssetLiabilityMonthlyReport>[],
        limit: 2,
      );

      expect(views.map((view) => view.monthKey), <String>[
        '2026-07',
        '2026-06',
      ]);
    });
  });
}

AssetLiabilityMonthlySnapshot _snapshot(
  String monthKey, {
  required double netWorth,
}) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime.utc(
      int.parse(monthKey.substring(0, 4)),
      int.parse(monthKey.substring(5, 7)),
      28,
    ),
    positiveAssetTotal: 100000,
    liabilityTotal: netWorth - 100000,
    netWorth: netWorth,
    cashLikeTotal: 50000,
    monthlyScheduledPaymentTotal: 120000,
    monthlyPaidPaymentTotal: 60000,
    monthlyUnpaidPaymentTotal: 60000,
    monthlyActualPaymentTotal: 61000,
    monthlyPaymentDifferenceTotal: 1000,
    overduePaymentCount: 1,
  );
}
