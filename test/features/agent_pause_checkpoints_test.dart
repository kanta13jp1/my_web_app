import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/agent_pause_checkpoints/agent_pause_checkpoints_container.dart';
import 'package:my_web_app/features/agent_pause_checkpoints/application/agent_pause_checkpoint_controller.dart';
import 'package:my_web_app/features/agent_pause_checkpoints/domain/agent_pause_checkpoint_models.dart';

class _InMemoryCheckpointRepository implements AgentPauseCheckpointRepository {
  _InMemoryCheckpointRepository({
    this.throwOnFetch = false,
    this.isAdmin = true,
    List<AgentPauseCheckpointRecord>? initialRecords,
  }) : _store = List<AgentPauseCheckpointRecord>.from(
          initialRecords ??
              const <AgentPauseCheckpointRecord>[
                AgentPauseCheckpointRecord(
                  id: 'rec-1',
                  runKey: 'daily-brief-01',
                  agentName: 'digest-worker',
                  checkpointSeq: 2,
                  pauseStatus: AgentPauseStatus.pausedLossless,
                  usageRatioPct: 100.0,
                  warning90ThresholdPct: 90.0,
                  warning90Sent: true,
                  silentPauseAlerted: true,
                  pendingStep: 'step_3_publish',
                  snapshotSha256: 'abc123def456',
                  completedCount: 5,
                ),
                AgentPauseCheckpointRecord(
                  id: 'rec-2',
                  runKey: 'competitor-scan-02',
                  agentName: 'research-worker',
                  checkpointSeq: 1,
                  pauseStatus: AgentPauseStatus.warning90,
                  usageRatioPct: 91.5,
                  warning90ThresholdPct: 90.0,
                  warning90Sent: true,
                  silentPauseAlerted: false,
                  pendingStep: 'step_2_rank',
                  snapshotSha256: 'fed987cba654',
                  completedCount: 3,
                ),
              ],
        );

  final bool throwOnFetch;
  final bool isAdmin;
  final List<AgentPauseCheckpointRecord> _store;

  @override
  Future<bool> fetchIsAdmin() async => isAdmin;

  @override
  Future<List<AgentPauseCheckpointRecord>> fetchCheckpoints() async {
    if (throwOnFetch) {
      throw StateError('checkpoint fetch error');
    }
    return List<AgentPauseCheckpointRecord>.from(_store);
  }

  @override
  Future<AgentPauseCheckpointRecord> saveLosslessPauseCheckpoint({
    required String runKey,
    required String agentName,
    required double usageRatioPct,
    required String pendingStep,
  }) async {
    final AgentPauseStatus nextStatus = usageRatioPct >= 100.0
        ? AgentPauseStatus.pausedLossless
        : (usageRatioPct >= 90.0
            ? AgentPauseStatus.warning90
            : AgentPauseStatus.running);
    final AgentPauseCheckpointRecord created = AgentPauseCheckpointRecord(
      id: 'rec-${_store.length + 1}',
      runKey: runKey,
      agentName: agentName,
      checkpointSeq: 1,
      pauseStatus: nextStatus,
      usageRatioPct: usageRatioPct,
      warning90ThresholdPct: 90.0,
      warning90Sent: usageRatioPct >= 90.0,
      silentPauseAlerted: usageRatioPct >= 100.0,
      pendingStep: pendingStep,
      snapshotSha256: '998877665544',
      completedCount: 0,
    );
    _store.insert(0, created);
    return created;
  }

  @override
  Future<AgentPauseCheckpointRecord> resumeCheckpoint({
    required AgentPauseCheckpointRecord record,
    required double replenishedUsagePct,
  }) async {
    if (!record.isLosslessPaused) {
      throw StateError('not paused');
    }
    final AgentPauseCheckpointRecord updated = record.copyWith(
      checkpointSeq: record.checkpointSeq + 1,
      pauseStatus: AgentPauseStatus.resumed,
      usageRatioPct: replenishedUsagePct,
      resumedAtIso: '2026-11-24T08:30:00Z',
    );
    final int idx = _store.indexWhere(
      (AgentPauseCheckpointRecord item) => item.id == record.id,
    );
    if (idx >= 0) {
      _store[idx] = updated;
    }
    return updated;
  }
}

void main() {
  group('AgentPauseCheckpointController', () {
    test('loads checkpoints, saves lossless pause, resumes, and catches errors',
        () async {
      final _InMemoryCheckpointRepository repo =
          _InMemoryCheckpointRepository();
      final AgentPauseCheckpointController controller =
          AgentPauseCheckpointController(repository: repo);
      addTearDown(controller.dispose);

      await controller.loadCheckpoints();
      expect(controller.records.length, 2);
      expect(controller.pausedCount, 1);
      expect(controller.warning90Count, 2);
      expect(controller.silentAlertedCount, 1);

      final bool saved = await controller.captureCheckpoint(
        runKey: 'night-audit-03',
        agentName: 'audit-agent',
        usageRatioPct: 100.0,
        pendingStep: 'step_4_sync',
      );
      expect(saved, isTrue);
      expect(controller.records.first.isLosslessPaused, isTrue);

      final bool resumed =
          await controller.resumeCheckpoint(controller.records.first);
      expect(resumed, isTrue);
      expect(
        controller.records.first.pauseStatus,
        AgentPauseStatus.resumed,
      );

      final _InMemoryCheckpointRepository failingRepo =
          _InMemoryCheckpointRepository(throwOnFetch: true);
      final AgentPauseCheckpointController failingController =
          AgentPauseCheckpointController(repository: failingRepo);
      addTearDown(failingController.dispose);

      await failingController.loadCheckpoints();
      expect(failingController.errorMessage, isNotEmpty);

      final _InMemoryCheckpointRepository nonAdminRepo =
          _InMemoryCheckpointRepository(isAdmin: false);
      final AgentPauseCheckpointController nonAdminController =
          AgentPauseCheckpointController(repository: nonAdminRepo);
      addTearDown(nonAdminController.dispose);

      await nonAdminController.loadCheckpoints();
      expect(nonAdminController.canResumeAsAdmin, isFalse);
      final bool nonAdminResumed = await nonAdminController.resumeCheckpoint(
        nonAdminController.records.first,
      );
      expect(nonAdminResumed, isFalse);
      expect(nonAdminController.errorMessage, contains('管理者権限'));

      controller.dispose();
      controller.dispose();
    });
  });

  group('AgentPauseCheckpointsContainer', () {
    testWidgets(
      'hides resume button and renders admin-only notice for non-admin callers',
      (WidgetTester tester) async {
        final _InMemoryCheckpointRepository repo =
            _InMemoryCheckpointRepository(isAdmin: false);
        final AgentPauseCheckpointController controller =
            AgentPauseCheckpointController(repository: repo);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AgentPauseCheckpointsContainer(
                  controller: controller,
                  autoLoad: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('checkpoint-resume-daily-brief-01'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey<String>('checkpoint-admin-only-daily-brief-01'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'captures lossless checkpoint and resumes paused agent cleanly',
      (WidgetTester tester) async {
        final _InMemoryCheckpointRepository repo =
            _InMemoryCheckpointRepository();
        final AgentPauseCheckpointController controller =
            AgentPauseCheckpointController(repository: repo);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E3A8A),
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AgentPauseCheckpointsContainer(
                  controller: controller,
                  autoLoad: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('checkpoint-card-daily-brief-01')),
          findsOneWidget,
        );

        final Finder resumeBtn = find.byKey(
          const ValueKey<String>('checkpoint-resume-daily-brief-01'),
        );
        await tester.ensureVisible(resumeBtn);
        await tester.pumpAndSettle();
        await tester.tap(resumeBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('checkpoint-card-daily-brief-01'),
            ),
            matching: find.text('再開済み'),
          ),
          findsOneWidget,
        );

        final Finder runKeyField = find.byKey(
          const ValueKey<String>('checkpoint-run-key-field'),
        );
        await tester.ensureVisible(runKeyField);
        await tester.enterText(runKeyField, 'manual-pause-99');

        final Finder agentField = find.byKey(
          const ValueKey<String>('checkpoint-agent-name-field'),
        );
        await tester.ensureVisible(agentField);
        await tester.enterText(agentField, 'worker-x');

        final Finder usageField = find.byKey(
          const ValueKey<String>('checkpoint-usage-pct-field'),
        );
        await tester.ensureVisible(usageField);
        await tester.enterText(usageField, '100.0');

        final Finder stepField = find.byKey(
          const ValueKey<String>('checkpoint-pending-step-field'),
        );
        await tester.ensureVisible(stepField);
        await tester.enterText(stepField, 'step_final');

        final Finder saveBtn = find.byKey(
          const ValueKey<String>('checkpoint-save-button'),
        );
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('checkpoint-card-manual-pause-99')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit at 360x800 and 1280x800 in light/dark modes with 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(360, 800),
          Size(1280, 800),
        ];
        const List<Brightness> modes = <Brightness>[
          Brightness.light,
          Brightness.dark,
        ];

        for (final Size viewport in viewports) {
          for (final Brightness mode in modes) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            final _InMemoryCheckpointRepository repo =
                _InMemoryCheckpointRepository();
            final AgentPauseCheckpointController controller =
                AgentPauseCheckpointController(repository: repo);

            final SemanticsHandle semanticsHandle = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>('${viewport.width}_${mode.name}'),
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: mode,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xFF1E3A8A),
                      brightness: mode,
                    ),
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: viewport,
                      textScaler: const TextScaler.linear(2.0),
                    ),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: AgentPauseCheckpointsContainer(
                          controller: controller,
                          autoLoad: true,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
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
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              controller.dispose();
            }
          }
        }
      },
    );
  });
}
