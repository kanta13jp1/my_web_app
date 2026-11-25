import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/external_diff_alert/domain/external_diff_alert_models.dart';
import 'package:my_web_app/features/external_diff_alert/external_diff_alert_container.dart';

class _FakeExternalDiffAlertRepository implements ExternalDiffAlertRepository {
  _FakeExternalDiffAlertRepository();

  ExternalDiffDashboardSnapshot snapshot = _buildDashboard(
    alertCount: 1,
    emailStatus: 'sent',
  );
  bool throwOnFetch = false;
  Completer<ExternalDiffDashboardSnapshot>? pendingFetchCompleter;
  void Function()? _realtimeCallback;
  int fetchCalls = 0;
  int upsertCalls = 0;
  int detectCalls = 0;
  int ackCalls = 0;
  int disposeCalls = 0;

  @override
  Future<ExternalDiffDashboardSnapshot> fetchDashboard({int limit = 30}) async {
    fetchCalls += 1;
    if (pendingFetchCompleter != null) {
      return pendingFetchCompleter!.future;
    }
    if (throwOnFetch) {
      throw StateError('dashboard unavailable ($limit)');
    }
    return snapshot;
  }

  @override
  Future<ExternalDiffRule> upsertRule({
    required String ruleName,
    required String sourceKey,
    required String fieldPath,
    required DiffRuleOperator operatorType,
    required String thresholdValue,
    required DiffAlertSeverity severity,
    required bool notifyEmail,
    required String recipientEmail,
  }) async {
    upsertCalls += 1;
    final created = ExternalDiffRule(
      id: 'rule-$upsertCalls',
      ruleName: ruleName,
      sourceKey: sourceKey,
      fieldPath: fieldPath,
      operatorType: operatorType,
      thresholdValue: thresholdValue,
      severity: severity,
      notifyEmail: notifyEmail,
      recipientEmail: recipientEmail,
      enabled: true,
      updatedAt: '2026-11-25T11:30:00Z',
    );
    snapshot = ExternalDiffDashboardSnapshot(
      alerts: snapshot.alerts,
      rules: <ExternalDiffRule>[created, ...snapshot.rules],
      snapshots: snapshot.snapshots,
    );
    return created;
  }

  @override
  Future<SnapshotDetectOutcome> runSnapshotDetect({
    required String sourceKey,
    required Map<String, Object?> payload,
    bool dryRun = false,
  }) async {
    detectCalls += 1;
    final newAlert = ExternalDiffAlertEvent(
      id: 'alert-new-$detectCalls',
      title: '[CRITICAL] $sourceKey: 閾値超過検知',
      status: 'completed',
      severity: DiffAlertSeverity.critical,
      sourceKey: sourceKey,
      ruleId: 'rule-1',
      ruleName: '閾値超過検知',
      diffSummary: 'errors=${payload['errors']} exceeded threshold > 5',
      changedFields: const <String>['errors'],
      emailStatus: dryRun ? 'dry_run' : 'sent',
      emailRecipientMasked: 'o***@example.test',
      createdAt: '2026-11-25T11:31:00Z',
    );
    snapshot = ExternalDiffDashboardSnapshot(
      alerts: <ExternalDiffAlertEvent>[newAlert, ...snapshot.alerts],
      rules: snapshot.rules,
      snapshots: snapshot.snapshots,
    );
    return SnapshotDetectOutcome(
      sourceKey: sourceKey,
      baselineInitialized: false,
      diffCount: 1,
      alertsTriggered: 1,
    );
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    ackCalls += 1;
    snapshot = ExternalDiffDashboardSnapshot(
      alerts: snapshot.alerts
          .map(
            (item) => item.id == alertId
                ? ExternalDiffAlertEvent(
                    id: item.id,
                    title: item.title,
                    status: 'cancelled',
                    severity: item.severity,
                    sourceKey: item.sourceKey,
                    ruleId: item.ruleId,
                    ruleName: item.ruleName,
                    diffSummary: item.diffSummary,
                    changedFields: item.changedFields,
                    emailStatus: item.emailStatus,
                    emailRecipientMasked: item.emailRecipientMasked,
                    createdAt: item.createdAt,
                  )
                : item,
          )
          .toList(growable: false),
      rules: snapshot.rules,
      snapshots: snapshot.snapshots,
    );
  }

  @override
  bool subscribeToAlerts(void Function() onRealtimeAlert) {
    _realtimeCallback = onRealtimeAlert;
    return true;
  }

  void simulateRealtimePush(ExternalDiffAlertEvent incoming) {
    snapshot = ExternalDiffDashboardSnapshot(
      alerts: <ExternalDiffAlertEvent>[incoming, ...snapshot.alerts],
      rules: snapshot.rules,
      snapshots: snapshot.snapshots,
    );
    _realtimeCallback?.call();
  }

  @override
  Future<void> disposeSubscription() async {
    disposeCalls += 1;
    _realtimeCallback = null;
  }
}

ExternalDiffDashboardSnapshot _buildDashboard({
  required int alertCount,
  required String emailStatus,
}) {
  return ExternalDiffDashboardSnapshot(
    alerts: <ExternalDiffAlertEvent>[
      for (int i = 0; i < alertCount; i += 1)
        ExternalDiffAlertEvent(
          id: 'alert-$i',
          title: '[WARNING] status_feed: 初回検知 #$i',
          status: 'completed',
          severity: DiffAlertSeverity.warning,
          sourceKey: 'status_feed',
          ruleId: 'rule-0',
          ruleName: '初回検知',
          diffSummary: 'latency_ms changed',
          changedFields: const <String>['latency_ms'],
          emailStatus: emailStatus,
          emailRecipientMasked: 'u***@example.test',
          createdAt: '2026-11-25T11:00:00Z',
        ),
    ],
    rules: const <ExternalDiffRule>[
      ExternalDiffRule(
        id: 'rule-0',
        ruleName: '初回検知',
        sourceKey: 'status_feed',
        fieldPath: 'errors',
        operatorType: DiffRuleOperator.gt,
        thresholdValue: '5',
        severity: DiffAlertSeverity.warning,
        notifyEmail: true,
        recipientEmail: 'ops@example.test',
        enabled: true,
        updatedAt: '2026-11-25T10:00:00Z',
      ),
    ],
    snapshots: const <ExternalSnapshotSummary>[
      ExternalSnapshotSummary(
        id: 'snap-0',
        sourceKey: 'status_feed',
        sourceLabel: 'Status Feed',
        payloadHash: 'abcdef1234567890',
        fetchedAt: '2026-11-25T10:00:00Z',
      ),
    ],
  );
}

void main() {
  group('ExternalDiffAlertModels', () {
    test('rejects invalid payload and parses strict JSON snapshot', () {
      expect(
        () => ExternalDiffDashboardSnapshot.fromJson(
          const <String, Object?>{'alerts': 'bad'},
        ),
        throwsFormatException,
      );

      final parsed = ExternalDiffDashboardSnapshot.fromJson(
        const <String, Object?>{
          'alerts': <Object?>[
            <String, Object?>{
              'id': 'a1',
              'title': 'Alert 1',
              'status': 'completed',
              'severity': 'critical',
              'sourceKey': 'feed_a',
              'ruleId': 'r1',
              'ruleName': 'Spike',
              'diffSummary': 'errors > 5',
              'changedFields': <String>['errors'],
              'emailStatus': 'sent',
              'emailRecipientMasked': 'a***@example.test',
              'createdAt': '2026-11-25T11:00:00Z',
            },
          ],
          'rules': <Object?>[],
          'snapshots': <Object?>[],
        },
      );

      expect(parsed.alerts.length, 1);
      expect(parsed.alerts.first.severity, DiffAlertSeverity.critical);
      expect(parsed.alerts.first.isAcknowledged, isFalse);
    });
  });

  group('ExternalDiffAlertContainer widget tests', () {
    testWidgets(
        'loads realtime connection, pushes live alert, and acknowledges',
        (WidgetTester tester) async {
      final repo = _FakeExternalDiffAlertRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ExternalDiffAlertContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Realtime 監視接続中'), findsOneWidget);
      expect(find.textContaining('初回検知 #0'), findsOneWidget);

      repo.simulateRealtimePush(
        const ExternalDiffAlertEvent(
          id: 'alert-rt',
          title: '[CRITICAL] billing_sync: 課金 Webhook 差分検知',
          status: 'completed',
          severity: DiffAlertSeverity.critical,
          sourceKey: 'billing_sync',
          ruleId: 'rule-rt',
          ruleName: '課金差分',
          diffSummary: 'amount_delta=+120%',
          changedFields: <String>['amount'],
          emailStatus: 'sent',
          emailRecipientMasked: 'b***@example.test',
          createdAt: '2026-11-25T11:20:00Z',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('課金 Webhook 差分検知'), findsOneWidget);

      final ackBtn = find.byKey(const Key('external_diff_ack_alert-rt'));
      await tester.ensureVisible(ackBtn);
      await tester.tap(ackBtn);
      await tester.pumpAndSettle();

      expect(repo.ackCalls, 1);
      expect(find.text('確認済み'), findsOneWidget);
    });

    testWidgets('saves trigger rule and executes snapshot diff detection', (
      WidgetTester tester,
    ) async {
      final repo = _FakeExternalDiffAlertRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ExternalDiffAlertContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.byKey(const Key('external_diff_save_rule_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(repo.upsertCalls, 1);
      expect(find.textContaining('保存しました'), findsOneWidget);

      final detectBtn = find.byKey(const Key('external_diff_detect_btn'));
      await tester.ensureVisible(detectBtn);
      await tester.tap(detectBtn);
      await tester.pumpAndSettle();

      expect(repo.detectCalls, 1);
      expect(find.textContaining('発火アラート 1 件'), findsOneWidget);
    });

    testWidgets('renders error banner on failure and retries cleanly', (
      WidgetTester tester,
    ) async {
      final repo = _FakeExternalDiffAlertRepository()..throwOnFetch = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ExternalDiffAlertContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('external_diff_error_banner')),
        findsOneWidget,
      );

      repo.throwOnFetch = false;
      final retryBtn = find.byKey(const Key('external_diff_retry_btn'));
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('external_diff_error_banner')), findsNothing);
      expect(repo.fetchCalls, 2);
    });

    testWidgets(
        'cleans up realtime subscription and ignores post-dispose async',
        (WidgetTester tester) async {
      final repo = _FakeExternalDiffAlertRepository()
        ..pendingFetchCompleter = Completer<ExternalDiffDashboardSnapshot>();

      await tester.pumpWidget(
        MaterialApp(
          home: ExternalDiffAlertContainer(repository: repo),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      expect(repo.disposeCalls, 1);

      repo.pendingFetchCompleter!.complete(
        _buildDashboard(alertCount: 1, emailStatus: 'sent'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('supports mobile and desktop viewports in dark 2.0x textScale',
        (WidgetTester tester) async {
      final repo = _FakeExternalDiffAlertRepository();
      for (final Size viewport in const <Size>[
        Size(360, 800),
        Size(390, 844),
        Size(1280, 800),
      ]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: const TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ExternalDiffAlertContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        for (final Finder btn in <Finder>[
          find.byKey(const Key('external_diff_refresh_btn')),
          find.byKey(const Key('external_diff_save_rule_btn')),
          find.byKey(const Key('external_diff_detect_btn')),
        ]) {
          final size = tester.getSize(btn);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  });
}
