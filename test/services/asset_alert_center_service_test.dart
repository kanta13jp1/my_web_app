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

    test('surfaces a payment source that is not a cash/deposit asset account',
        () {
      // 原資に資産一覧へ存在しない ID (PayPay カードの請求名フォールバック) を
      // 指定したケース。planner の無効化ガードは cardLoan しか見ないため
      // 非 null のまま残り、「未設定」にも入らないので従来は完全に不可視だった。
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{
          '三井住友銀行大塚支店': 500000,
          'モビット': -1000000,
        },
        baseDate: now,
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'paypay_card',
        },
      );

      final row = workbook.debtMasterRows.firstWhere((r) => r.name == 'モビット');
      // 前提: 原資は非 null のまま残る (cardLoan ではないので無効化されない)。
      expect(row.paymentSourceAccountId, 'paypay_card');
      // 従来の「未設定」判定には入らない = 既存レビュー/一括設定から不可視。
      expect(
        workbook.paymentSourceMissingRows.any((r) => r.id == row.id),
        isFalse,
      );
      // 新しい「資産口座でない」判定で捕捉する。
      expect(
        workbook.paymentSourceInvalidRows.any((r) => r.id == row.id),
        isTrue,
      );
      // 口座別の見込み残高からは差し引かれていない (どの口座とも ID が一致しない)。
      expect(
        workbook.accountCashflowSummaries
            .any((s) => s.accountId == 'paypay_card'),
        isFalse,
      );

      final center = service.build(workbook: workbook, now: now);
      final alert = center.alerts.firstWhere(
        (a) => a.id == 'payment_source_invalid:${row.id}',
      );
      expect(alert.category, AssetAlertCategory.paymentSourceMissing);
      // 「どこからも引かれていない=残高が過大に見える」ことを本文で明示する。
      expect(alert.detail.contains('見込み残高からも差し引かれておらず'), isTrue);
      expect(alert.detail.contains('実際より多く見えています'), isTrue);
    });

    test('does not flag an already-paid row as an invalid payment source', () {
      // 支払済みはどの口座の見込み残高からも引かれないのが正しい状態なので、
      // 「残高が実際より多く見える」は成立せず、警告を出すと誤報になる。
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{
          '三井住友銀行大塚支店': 500000,
          'モビット': -1000000,
        },
        baseDate: now,
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'paypay_card',
        },
        paidAccountNames: const <String>{'モビット'},
      );

      final row = workbook.debtMasterRows.firstWhere((r) => r.name == 'モビット');
      expect(row.paid, isTrue);
      expect(workbook.paymentSourceInvalidRows, isEmpty);

      final center = service.build(workbook: workbook, now: now);
      expect(
        center.alerts.any((a) => a.id.startsWith('payment_source_invalid:')),
        isFalse,
      );
    });

    test('does not flag a payment source that is a real deposit account', () {
      final now = DateTime(2026, 5, 15);
      final workbook = planner.buildWorkbook(
        latestSnapshot: <String, double>{
          '三井住友銀行大塚支店': 500000,
          'モビット': -1000000,
        },
        baseDate: now,
        paymentSourceAccountIds: const <String, String>{
          'mobit': 'smbc_otsuka_branch',
        },
      );

      expect(workbook.paymentSourceInvalidRows, isEmpty);
      final center = service.build(workbook: workbook, now: now);
      expect(
        center.alerts.any((a) => a.id.startsWith('payment_source_invalid:')),
        isFalse,
      );
    });
  });
}
