import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/career_monthly_kpi.dart';
import 'package:my_web_app/models/self_mental_health_check.dart';
import 'package:my_web_app/services/career_monthly_kpi_service.dart';
import 'package:my_web_app/services/self_mental_health_risk_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SelfMentalHealthRiskService (#1393 / #2771)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('upserts 1 entry per day and invokes cloud writer fail-open',
        () async {
      var cloudCalls = 0;
      final service = SelfMentalHealthRiskService(
        cloudWriter: (check) async {
          cloudCalls++;
          if (cloudCalls == 2) {
            throw Exception('offline');
          }
          return true;
        },
      );

      final morning = await service.recordDailyCheck(
        moodScore: 4,
        fatigueScore: 2,
        note: '朝は順調',
        now: DateTime(2026, 11, 23, 9),
      );
      expect(morning.syncedToCloud, isTrue);
      expect(morning.dateKey, '2026-11-23');

      final evening = await service.recordDailyCheck(
        moodScore: 2,
        fatigueScore: 5,
        note: '夜に負荷増',
        now: DateTime(2026, 11, 23, 22),
      );
      expect(evening.syncedToCloud, isFalse);

      final entries = await service.loadEntries();
      expect(entries, hasLength(1));
      expect(entries.single.moodScore, 2);
      expect(entries.single.fatigueScore, 5);
      expect(entries.single.note, '夜に負荷増');
    });

    test('evaluates low, caution, and high burnout risk over 14-day window',
        () {
      final now = DateTime(2026, 11, 23);

      final few = <SelfMentalHealthCheck>[
        SelfMentalHealthCheck(
          dateKey: '2026-11-22',
          moodScore: 1,
          fatigueScore: 5,
          recordedAt: DateTime(2026, 11, 22),
        ),
      ];
      final fewReport = SelfMentalHealthRiskService.evaluateRisk(few, now: now);
      expect(fewReport.level, SelfBurnoutRiskLevel.low);
      expect(fewReport.hasAlert, isFalse);

      final healthy = <SelfMentalHealthCheck>[
        for (var i = 0; i < 5; i++)
          SelfMentalHealthCheck(
            dateKey: '2026-11-${19 + i}',
            moodScore: 4,
            fatigueScore: 2,
            recordedAt: DateTime(2026, 11, 19 + i),
          ),
      ];
      final healthyReport = SelfMentalHealthRiskService.evaluateRisk(
        healthy,
        now: now,
      );
      expect(healthyReport.level, SelfBurnoutRiskLevel.low);

      final caution = <SelfMentalHealthCheck>[
        for (var i = 0; i < 4; i++)
          SelfMentalHealthCheck(
            dateKey: '2026-11-${19 + i}',
            moodScore: i.isEven ? 3 : 2,
            fatigueScore: 4,
            recordedAt: DateTime(2026, 11, 19 + i),
          ),
        // Break trailing streak on the final day while keeping >=4 high-fatigue days.
        SelfMentalHealthCheck(
          dateKey: '2026-11-23',
          moodScore: 4,
          fatigueScore: 2,
          recordedAt: DateTime(2026, 11, 23),
        ),
      ];
      final cautionReport = SelfMentalHealthRiskService.evaluateRisk(
        caution,
        now: now,
      );
      expect(cautionReport.level, SelfBurnoutRiskLevel.caution);
      expect(cautionReport.hasAlert, isTrue);
      expect(cautionReport.suggestions, isNotEmpty);

      final high = <SelfMentalHealthCheck>[
        for (var i = 0; i < 3; i++)
          SelfMentalHealthCheck(
            dateKey: '2026-11-${21 + i}',
            moodScore: 2,
            fatigueScore: 4,
            recordedAt: DateTime(2026, 11, 21 + i),
          ),
      ];
      final highReport = SelfMentalHealthRiskService.evaluateRisk(
        high,
        now: now,
      );
      expect(highReport.level, SelfBurnoutRiskLevel.high);
      expect(highReport.consecutiveHighStrainDays, 3);
      expect(highReport.neutralNotice, contains('医療上の診断'));
    });
  });

  group('CareerMonthlyKpiService deterministic close (#2772)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('computes deterministic checksum and auto-closes at month end',
        () async {
      final service = CareerMonthlyKpiService();
      final items = <CareerMonthlyKpi>[
        const CareerMonthlyKpi(
          monthKey: '2026-11',
          annualGoal: '個人開発KPI達成',
          category: 'career',
          metricName: 'リリース機能数',
          targetValue: 4,
          actualValue: 3,
          unit: '件',
          reflection: '順調',
          nextAction: '残り1件完了',
        ),
      ];

      final first = CareerMonthlyKpiService.buildClosingSnapshot(
        items,
        '2026-11',
        generatedAt: DateTime(2026, 11, 30, 23),
      );
      final second = CareerMonthlyKpiService.buildClosingSnapshot(
        items,
        '2026-11',
        generatedAt: DateTime(2026, 11, 30, 23),
      );

      expect(first.checksum, second.checksum);
      expect(first.averageProgressPercent, 75);
      expect(first.completedMetrics, 0);
      expect(first.totalMetrics, 1);

      final snapshots = await service.ensureMonthEndAutoSnapshot(
        items,
        now: DateTime(2026, 11, 30, 12),
      );
      expect(snapshots, hasLength(1));
      expect(snapshots.single.monthKey, '2026-11');
      expect(snapshots.single.autoGenerated, isTrue);
    });
  });
}
