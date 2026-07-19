import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_alert.dart';
import 'package:my_web_app/services/asset_alert_center_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const service = AssetAlertCenterService();

  AssetAlert anomaly(String id, AssetAlertSeverity severity) {
    return AssetAlert(
      id: id,
      severity: severity,
      category: AssetAlertCategory.anomaly,
      title: 'anomaly $id',
      detail: 'detail $id',
    );
  }

  group('AssetAlertCenterService.build', () {
    test('surfaces overdue payments as critical alerts', () {
      final now = DateTime(2026, 5, 14);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{
          '財布': 25000,
          'アコムカードローン': -100000,
          'モビット': -100000,
        },
        baseDate: now,
        monthlyPaymentOverrides: const <String, double>{
          'アコムカードローン': 5000,
          'モビット': 9000,
        },
      );

      final center = service.build(workbook: workbook, now: now);

      expect(center.hasAlerts, isTrue);
      expect(
        center.alerts.any(
          (a) => a.category == AssetAlertCategory.overduePayment,
        ),
        isTrue,
      );
      // 全アラートは重要度降順で並ぶ。
      for (var i = 1; i < center.alerts.length; i++) {
        expect(
          center.alerts[i - 1].severity.weight >=
              center.alerts[i].severity.weight,
          isTrue,
        );
      }
    });

    test('injected anomaly alerts are merged and severity-sorted', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 100000},
        baseDate: now,
      );

      final center = service.build(
        workbook: workbook,
        now: now,
        anomalyAlerts: [
          anomaly('a-info', AssetAlertSeverity.info),
          anomaly('a-critical', AssetAlertSeverity.critical),
          anomaly('a-warning', AssetAlertSeverity.warning),
        ],
      );

      expect(
        center.alerts.map((a) => a.id).toList(),
        ['a-critical', 'a-warning', 'a-info'],
      );
      expect(center.criticalCount, 1);
      expect(center.warningCount, 1);
    });

    test('dismissed ids are filtered out and counted', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 100000},
        baseDate: now,
      );

      final center = service.build(
        workbook: workbook,
        now: now,
        anomalyAlerts: [
          anomaly('a-critical', AssetAlertSeverity.critical),
          anomaly('a-warning', AssetAlertSeverity.warning),
        ],
        dismissedIds: {'a-warning'},
      );

      expect(center.alerts.map((a) => a.id).toList(), ['a-critical']);
      expect(center.dismissedCount, 1);
    });

    test('duplicate ids are de-duplicated (first wins)', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 100000},
        baseDate: now,
      );

      final center = service.build(
        workbook: workbook,
        now: now,
        anomalyAlerts: [
          anomaly('dup', AssetAlertSeverity.critical),
          anomaly('dup', AssetAlertSeverity.info),
        ],
      );

      expect(center.alerts.where((a) => a.id == 'dup').length, 1);
      expect(
        center.alerts.firstWhere((a) => a.id == 'dup').severity,
        AssetAlertSeverity.critical,
      );
    });

    test('empty workbook with no anomalies yields no alerts', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 500000},
        baseDate: now,
      );

      final center = service.build(workbook: workbook, now: now);
      expect(center.hasAlerts, isFalse);
      expect(center.dismissedCount, 0);
    });

    test('same-severity alerts sort by occurredAt then id (stable)', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{'財布': 100000},
        baseDate: now,
      );

      final center = service.build(
        workbook: workbook,
        now: now,
        anomalyAlerts: [
          // occurredAt null → 末尾。id 昇順で b→a ではなく a→b。
          anomaly('z', AssetAlertSeverity.warning),
          anomaly('a', AssetAlertSeverity.warning),
        ],
      );

      expect(center.alerts.map((a) => a.id).toList(), ['a', 'z']);
    });
  });
}
