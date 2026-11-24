import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/async_job.dart';
import 'package:my_web_app/services/async_job_service.dart';
import 'package:my_web_app/widgets/async_job_status_panel.dart';

class _FakeAsyncJobRepository implements AsyncJobRepository {
  _FakeAsyncJobRepository(List<AsyncJob> seed)
      : jobs = List<AsyncJob>.from(seed);

  final List<AsyncJob> jobs;
  final StreamController<List<AsyncJob>> controller =
      StreamController<List<AsyncJob>>.broadcast();

  void emitCurrent() {
    controller.add(List<AsyncJob>.from(jobs));
  }

  @override
  Future<AsyncJob> cancelJob(String jobId) async {
    final idx = jobs.indexWhere((j) => j.id == jobId);
    final current = jobs[idx];
    final updated = AsyncJob(
      id: current.id,
      userId: current.userId,
      jobType: current.jobType,
      title: current.title,
      status: AsyncJobStatus.cancelled,
      progressPercent: current.progressPercent,
      requestPayload: current.requestPayload,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    jobs[idx] = updated;
    emitCurrent();
    return updated;
  }

  @override
  Future<AsyncJob> enqueueJob({
    required String jobType,
    String? title,
    Map<String, dynamic>? requestPayload,
  }) async {
    final now = DateTime.utc(2026, 11, 24);
    final created = AsyncJob(
      id: 'job-new-${jobs.length + 1}',
      userId: 'user-1',
      jobType: jobType,
      title: title ?? jobType,
      status: AsyncJobStatus.queued,
      progressPercent: 0,
      requestPayload: requestPayload ?? const <String, dynamic>{},
      createdAt: now,
      updatedAt: now,
    );
    jobs.insert(0, created);
    emitCurrent();
    return created;
  }

  @override
  Future<AsyncJob?> fetchJobStatus(String jobId) async {
    for (final job in jobs) {
      if (job.id == jobId) return job;
    }
    return null;
  }

  @override
  Future<List<AsyncJob>> listJobs({
    AsyncJobStatus? statusFilter,
    int limit = 30,
  }) async {
    return jobs
        .where((j) => statusFilter == null || j.status == statusFilter)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Stream<List<AsyncJob>> watchJobs({int limit = 30}) {
    return controller.stream;
  }
}

List<AsyncJob> _sampleJobs() {
  final ts = DateTime.utc(2026, 11, 24, 9, 0);
  return <AsyncJob>[
    AsyncJob(
      id: 'job-run-1',
      userId: 'user-1',
      jobType: 'monthly_report_export',
      title: '月次レポート集計',
      status: AsyncJobStatus.running,
      progressPercent: 60,
      requestPayload: const <String, dynamic>{'month': '2026-11'},
      createdAt: ts,
      updatedAt: ts,
    ),
    AsyncJob(
      id: 'job-done-2',
      userId: 'user-1',
      jobType: 'analytics_export',
      title: '利用統計エクスポート',
      status: AsyncJobStatus.completed,
      progressPercent: 100,
      requestPayload: const <String, dynamic>{},
      resultPayload: const <String, dynamic>{'total_rows': 350},
      createdAt: ts,
      updatedAt: ts,
      completedAt: ts,
    ),
    AsyncJob(
      id: 'job-fail-3',
      userId: 'user-1',
      jobType: 'data_sync',
      title: '外部同期バッチ',
      status: AsyncJobStatus.failed,
      progressPercent: 25,
      requestPayload: const <String, dynamic>{},
      errorMessage: 'Upstream HTTP 503',
      createdAt: ts,
      updatedAt: ts,
    ),
  ];
}

void main() {
  group('AsyncJob model & AsyncJobStatusPanel (#2731)', () {
    test('parses AsyncJob JSON with status and result payload', () {
      final job = AsyncJob.fromJson(<String, dynamic>{
        'id': 'job-123',
        'user_id': 'user-abc',
        'job_type': 'report_build',
        'title': '集計ジョブ',
        'status': 'completed',
        'progress_percent': 100,
        'request_payload': <String, dynamic>{'quarter': 'Q4'},
        'result_payload': <String, dynamic>{'url': 'https://example.test/out'},
        'created_at': '2026-11-24T00:00:00Z',
        'updated_at': '2026-11-24T00:01:00Z',
      });
      expect(job.id, 'job-123');
      expect(job.status, AsyncJobStatus.completed);
      expect(job.status.isTerminal, isTrue);
      expect(job.resultPayload?['url'], 'https://example.test/out');
    });

    testWidgets(
      'displays live status updates, lookup by Job ID, and result/error cards',
      (tester) async {
        final repo = _FakeAsyncJobRepository(_sampleJobs());
        addTearDown(repo.controller.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AsyncJobStatusPanel(repository: repo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('async_job_card_job-run-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('async_job_result_job-done-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('async_job_err_job-fail-3')),
          findsOneWidget,
        );

        // Filter to completed only
        await tester.tap(
          find.byKey(const ValueKey<String>('async_job_filter_completed')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('async_job_card_job-done-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('async_job_card_job-run-1')),
          findsNothing,
        );

        // Realtime update promotes running job to completed
        await tester.tap(
          find.byKey(const ValueKey<String>('async_job_filter_all')),
        );
        await tester.pumpAndSettle();
        repo.jobs[0] = AsyncJob(
          id: 'job-run-1',
          userId: 'user-1',
          jobType: 'monthly_report_export',
          title: '月次レポート集計',
          status: AsyncJobStatus.completed,
          progressPercent: 100,
          requestPayload: const <String, dynamic>{},
          resultPayload: const <String, dynamic>{'status': 'done'},
          createdAt: repo.jobs[0].createdAt,
          updatedAt: repo.jobs[0].updatedAt,
        );
        repo.emitCurrent();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('async_job_result_job-run-1')),
          findsOneWidget,
        );

        // Explicit Job ID lookup
        await tester.enterText(
          find.byKey(const ValueKey<String>('async_job_lookup_field')),
          'job-done-2',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('async_job_lookup_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('async_job_lookup_message')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'meets light/dark layout, 2.0x text scaling, and accessibility guidelines',
      (tester) async {
        final seeded = _sampleJobs();
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
                key: ValueKey<String>('${viewport.width}_${theme.brightness}'),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: AsyncJobStatusPanel(
                        initialJobs: seeded,
                        autoSubscribeRealtime: false,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey<String>('async_job_status_panel')),
              findsOneWidget,
            );

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
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
