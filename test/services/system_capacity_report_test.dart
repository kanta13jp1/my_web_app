import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/system_capacity_report_service.dart';
import 'package:my_web_app/widgets/admin/system_capacity_report_card.dart';

class _FakeCapacityReportRepository implements SystemCapacityReportRepository {
  _FakeCapacityReportRepository({
    required List<SystemCapacityMonthlyStat> seed,
  }) : items = List<SystemCapacityMonthlyStat>.from(seed);

  final List<SystemCapacityMonthlyStat> items;
  bool shouldThrowOnFetch = false;
  int aggregateCalls = 0;
  int notifyCalls = 0;

  @override
  Future<List<SystemCapacityMonthlyStat>> fetchMonthlyStats({
    int limit = 12,
  }) async {
    if (shouldThrowOnFetch) {
      throw StateError('simulated fetch error');
    }
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<SystemCapacityMonthlyStat> aggregateMonth({
    String? reportMonth,
  }) async {
    aggregateCalls += 1;
    final target = reportMonth ?? items.first.reportMonth;
    final updated = SystemCapacityMonthlyStat(
      reportMonth: target,
      userAccessCount: 3450,
      batchJobCount: 120,
      errorCount: 2,
      errorRatePercent: 0.06,
      summaryPayload: const <String, Object?>{'timezone': 'Asia/Tokyo'},
      updatedAt: DateTime.utc(2026, 11, 24),
    );
    final idx = items.indexWhere((row) => row.reportMonth == target);
    if (idx >= 0) {
      items[idx] = updated;
    } else {
      items.insert(0, updated);
    }
    return updated;
  }

  @override
  Future<CapacityReportNotifyResult> notifyReport({
    String? reportMonth,
    bool dryRun = false,
  }) async {
    notifyCalls += 1;
    final target = reportMonth ?? items.first.reportMonth;
    final existing = items.firstWhere((row) => row.reportMonth == target);
    final notified = SystemCapacityMonthlyStat(
      reportMonth: existing.reportMonth,
      userAccessCount: existing.userAccessCount,
      batchJobCount: existing.batchJobCount,
      errorCount: existing.errorCount,
      errorRatePercent: existing.errorRatePercent,
      notifiedAt: dryRun ? existing.notifiedAt : DateTime.utc(2026, 11, 24, 1),
      summaryPayload: existing.summaryPayload,
      updatedAt: DateTime.utc(2026, 11, 24, 1),
    );
    final idx = items.indexWhere((row) => row.reportMonth == target);
    if (idx >= 0) {
      items[idx] = notified;
    }
    return CapacityReportNotifyResult(
      report: notified,
      dryRun: dryRun,
      emailSent: !dryRun,
      inAppRecorded: true,
      message: '${notified.reportMonth} の月次レポートをメール送信・記録しました',
    );
  }
}

List<SystemCapacityMonthlyStat> _sampleReports() => <SystemCapacityMonthlyStat>[
      SystemCapacityMonthlyStat(
        reportMonth: '2026-11',
        userAccessCount: 2400,
        batchJobCount: 95,
        errorCount: 3,
        errorRatePercent: 0.12,
        summaryPayload: const <String, Object?>{'landing_views': 2100},
        updatedAt: DateTime.utc(2026, 11, 24),
      ),
      SystemCapacityMonthlyStat(
        reportMonth: '2026-10',
        userAccessCount: 1900,
        batchJobCount: 80,
        errorCount: 4,
        errorRatePercent: 0.20,
        notifiedAt: DateTime.utc(2026, 11, 1, 0, 20),
        summaryPayload: const <String, Object?>{'landing_views': 1700},
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    ];

void main() {
  group('SystemCapacityReportService (#2745)', () {
    test(
      'parses SystemCapacityMonthlyStat JSON and resolves client lazily',
      () {
        final repo = SupabaseSystemCapacityReportRepository();
        expect(repo, isNotNull);

        final parsed = SystemCapacityMonthlyStat.fromJson(
          const <String, Object?>{
            'report_month': '2026-11',
            'user_access_count': '1250',
            'batch_job_count': 42,
            'error_count': 2,
            'error_rate_percent': '0.15',
            'notified_at': '2026-11-01T00:20:00Z',
            'summary_payload': <String, Object?>{'landing_views': 1000},
            'updated_at': '2026-11-24T01:00:00Z',
          },
        );
        expect(parsed.reportMonth, '2026-11');
        expect(parsed.userAccessCount, 1250);
        expect(parsed.batchJobCount, 42);
        expect(parsed.errorCount, 2);
        expect(parsed.errorRatePercent, closeTo(0.15, 0.001));
        expect(parsed.isNotified, isTrue);
        expect(parsed.summaryPayload['landing_views'], 1000);
      },
    );
  });

  group('SystemCapacityReportCard UI & accessibility (#2745)', () {
    testWidgets(
      'displays chart and table, runs aggregate/notify actions, and shows error state',
      (tester) async {
        final repo = _FakeCapacityReportRepository(seed: _sampleReports());

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SystemCapacityReportCard(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('capacity_report_table')),
          findsOneWidget,
        );
        expect(find.text('2026-11'), findsOneWidget);
        expect(find.text('2026-10'), findsOneWidget);

        // Switch chart metric chip
        await tester.tap(
          find.byKey(const ValueKey<String>('capacity_metric_chip_errorRate')),
        );
        await tester.pumpAndSettle();

        // Trigger aggregation
        await tester.tap(
          find.byKey(const ValueKey<String>('capacity_report_aggregate_btn')),
        );
        await tester.pumpAndSettle();
        expect(repo.aggregateCalls, 1);
        expect(
          find.byKey(const ValueKey<String>('capacity_report_status_banner')),
          findsOneWidget,
        );
        expect(find.text('3450'), findsOneWidget);

        // Trigger notification
        await tester.tap(
          find.byKey(const ValueKey<String>('capacity_report_notify_btn')),
        );
        await tester.pumpAndSettle();
        expect(repo.notifyCalls, 1);
        expect(
          find.text('2026-11 の月次レポートをメール送信・記録しました'),
          findsOneWidget,
        );

        // Error state when refresh fails
        repo.shouldThrowOnFetch = true;
        await tester.tap(
          find.byKey(const ValueKey<String>('capacity_report_refresh_btn')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('capacity_report_error_banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows empty state cleanly when initialReports is empty',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: SystemCapacityReportCard(
                  initialReports: <SystemCapacityMonthlyStat>[],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('capacity_report_empty_state')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'meets light/dark 390x844 and 1280x800 layout with 2.0x textScale and accessibility guidelines',
      (tester) async {
        final seeded = _sampleReports();
        final configs = <(Size, ThemeData)>[
          (const Size(390, 844), ThemeData.light()),
          (const Size(1280, 800), ThemeData.dark()),
        ];

        for (final (viewport, theme) in configs) {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey<String>(
                  '${viewport.width}_${theme.brightness}',
                ),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SystemCapacityReportCard(initialReports: seeded),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(
                const ValueKey<String>('system_capacity_report_card'),
              ),
              findsOneWidget,
            );
            expect(find.byType(LineChart), findsOneWidget);

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(textContrastGuideline),
            );
          } finally {
            handle.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        }
      },
    );
  });
}
