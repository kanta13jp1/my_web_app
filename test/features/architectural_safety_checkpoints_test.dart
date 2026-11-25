import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/architectural_safety_checkpoints/application/architectural_safety_checkpoint_controller.dart';
import 'package:my_web_app/features/architectural_safety_checkpoints/architectural_safety_checkpoints_container.dart';
import 'package:my_web_app/features/architectural_safety_checkpoints/domain/architectural_safety_checkpoint_models.dart';

class _InMemorySafetyRepository
    implements ArchitecturalSafetyCheckpointRepository {
  _InMemorySafetyRepository({
    this.isAdmin = true,
  }) : _store = <SafetyCheckpointRecord>[
          const SafetyCheckpointRecord(
            id: 'safety-chk-1',
            runKey: 'mcp-deploy-01',
            agentName: 'release-bot',
            toolName: 'deploy.edge_function',
            requestedScopes: <String>['update'],
            highRiskScopes: <String>['update'],
            pauseStatus: SafetyCheckpointStatus.pausedLossless,
            approvalState: 'awaiting_admin_approval',
            githubIssueNumber: 2712,
            githubRepo: 'kanta13jp1/my_web_app',
            pendingStep: 'execute_mcp_tool:deploy.edge_function',
            snapshotSha256: 'abc123def456',
            operationDigest: 'digest-deploy-01',
          ),
        ];

  final bool isAdmin;
  final List<SafetyCheckpointRecord> _store;

  @override
  Future<SafetyCheckpointFeed> fetchSafetyCheckpoints() async {
    return SafetyCheckpointFeed(
      isAdmin: isAdmin,
      checkpoints: List<SafetyCheckpointRecord>.from(_store),
    );
  }

  @override
  Future<SafetyCheckpointEvaluationResult> evaluateToolCall({
    required String toolName,
    required List<String> requestedScopes,
    required String actorRole,
    required String runKey,
    required String agentName,
    String pendingStep = '',
    int? githubIssueNumber,
    String? checkpointId,
  }) async {
    final bool isHighRisk = requestedScopes.any(
          (String s) => const <String>{
            'create',
            'update',
            'delete',
            'send',
            'purchase',
            'discount',
            'external_share',
          }.contains(s),
        ) ||
        toolName.startsWith('db.') ||
        toolName.startsWith('deploy.');

    if (!isHighRisk) {
      return const SafetyCheckpointEvaluationResult(
        decision: 'allow_direct',
        executionAllowed: true,
        pauseRequired: false,
      );
    }

    final SafetyCheckpointRecord created = SafetyCheckpointRecord(
      id: 'safety-chk-${_store.length + 1}',
      runKey: runKey,
      agentName: agentName,
      toolName: toolName,
      requestedScopes: requestedScopes,
      highRiskScopes: requestedScopes,
      pauseStatus: SafetyCheckpointStatus.pausedLossless,
      approvalState: 'awaiting_admin_approval',
      githubIssueNumber: githubIssueNumber,
      pendingStep:
          pendingStep.isEmpty ? 'execute_mcp_tool:$toolName' : pendingStep,
      snapshotSha256: 'sha256-$runKey',
      operationDigest: 'digest-$runKey',
    );
    _store.insert(0, created);
    return SafetyCheckpointEvaluationResult(
      decision: 'paused_for_approval',
      executionAllowed: false,
      pauseRequired: true,
      checkpoint: created,
    );
  }

  @override
  Future<SafetyCheckpointRecord> approveCheckpoint({
    required SafetyCheckpointRecord record,
    required SafetyApprovalChannel channel,
    int? githubIssueNumber,
    String? approvalNote,
  }) async {
    if (!isAdmin) {
      throw StateError('Admin privileges required');
    }
    final SafetyCheckpointRecord updated = record.copyWith(
      pauseStatus: SafetyCheckpointStatus.resumed,
      approvalState: 'approved',
      approvalChannel: channel,
      approvedByActor: channel == SafetyApprovalChannel.githubIssue
          ? 'github:owner'
          : 'admin',
      githubIssueNumber: githubIssueNumber ?? record.githubIssueNumber,
      resumedAtIso: '2026-11-25T11:00:00Z',
    );
    final int idx = _store.indexWhere(
      (SafetyCheckpointRecord item) => item.id == record.id,
    );
    if (idx >= 0) {
      _store[idx] = updated;
    }
    return updated;
  }

  @override
  Future<SafetyCheckpointRecord> rejectCheckpoint({
    required SafetyCheckpointRecord record,
    String reason = '',
  }) async {
    final SafetyCheckpointRecord updated = record.copyWith(
      pauseStatus: SafetyCheckpointStatus.failed,
      approvalState: 'rejected',
    );
    final int idx = _store.indexWhere(
      (SafetyCheckpointRecord item) => item.id == record.id,
    );
    if (idx >= 0) {
      _store[idx] = updated;
    }
    return updated;
  }
}

void main() {
  group('ArchitecturalSafetyCheckpointController', () {
    test(
      'pauses high-risk MCP call, blocks non-admin approve, and resumes on admin UI or GitHub Issue approval',
      () async {
        final _InMemorySafetyRepository repo = _InMemorySafetyRepository();
        final ArchitecturalSafetyCheckpointController controller =
            ArchitecturalSafetyCheckpointController(repository: repo);
        addTearDown(controller.dispose);

        await controller.loadCheckpoints();
        expect(controller.canApproveAsAdmin, isTrue);
        expect(controller.awaitingApprovalCount, 1);

        final SafetyCheckpointEvaluationResult? readResult =
            await controller.evaluateToolCall(
          toolName: 'notes.search',
          requestedScopes: const <String>['read'],
        );
        expect(readResult?.executionAllowed, isTrue);
        expect(readResult?.pauseRequired, isFalse);

        final SafetyCheckpointEvaluationResult? deleteResult =
            await controller.evaluateToolCall(
          toolName: 'db.prune_logs',
          requestedScopes: const <String>['delete'],
          runKey: 'mcp-db-02',
          githubIssueNumber: 2712,
        );
        expect(deleteResult?.executionAllowed, isFalse);
        expect(deleteResult?.pauseRequired, isTrue);
        expect(controller.awaitingApprovalCount, 2);

        final bool approvedByIssue = await controller.approveCheckpoint(
          controller.records.first,
          channel: SafetyApprovalChannel.githubIssue,
          githubIssueNumber: 2712,
        );
        expect(approvedByIssue, isTrue);
        expect(
          controller.records.first.approvalChannel,
          SafetyApprovalChannel.githubIssue,
        );
        expect(controller.resumedCount, 1);

        final _InMemorySafetyRepository nonAdminRepo =
            _InMemorySafetyRepository(isAdmin: false);
        final ArchitecturalSafetyCheckpointController nonAdminController =
            ArchitecturalSafetyCheckpointController(repository: nonAdminRepo);
        addTearDown(nonAdminController.dispose);

        await nonAdminController.loadCheckpoints();
        expect(nonAdminController.canApproveAsAdmin, isFalse);
        final bool blocked = await nonAdminController.approveCheckpoint(
          nonAdminController.records.first,
          channel: SafetyApprovalChannel.adminUi,
        );
        expect(blocked, isFalse);
        expect(nonAdminController.errorMessage, contains('管理者権限'));

        controller.dispose();
        controller.dispose();
      },
    );
  });

  group('ArchitecturalSafetyCheckpointsContainer', () {
    testWidgets(
      'hides admin approval buttons and shows fail-closed notice for non-admin callers',
      (WidgetTester tester) async {
        final _InMemorySafetyRepository repo = _InMemorySafetyRepository(
          isAdmin: false,
        );
        final ArchitecturalSafetyCheckpointController controller =
            ArchitecturalSafetyCheckpointController(repository: repo);
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
                child: ArchitecturalSafetyCheckpointsContainer(
                  controller: controller,
                  autoLoad: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('safety-approve-ui-mcp-deploy-01')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('safety-admin-only-mcp-deploy-01')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'evaluates high-risk MCP call before execution and allows admin approval via UI and Issue',
      (WidgetTester tester) async {
        final _InMemorySafetyRepository repo = _InMemorySafetyRepository();
        final ArchitecturalSafetyCheckpointController controller =
            ArchitecturalSafetyCheckpointController(repository: repo);
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
                child: ArchitecturalSafetyCheckpointsContainer(
                  controller: controller,
                  autoLoad: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder approveUiBtn = find.byKey(
          const ValueKey<String>('safety-approve-ui-mcp-deploy-01'),
        );
        await tester.ensureVisible(approveUiBtn);
        await tester.pumpAndSettle();
        await tester.tap(approveUiBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('safety-card-mcp-deploy-01')),
            matching: find.text('承認済み再開'),
          ),
          findsOneWidget,
        );

        final Finder toolField = find.byKey(
          const ValueKey<String>('safety-tool-name-field'),
        );
        await tester.ensureVisible(toolField);
        await tester.enterText(toolField, 'db.migrate_table');

        final Finder runKeyField = find.byKey(
          const ValueKey<String>('safety-run-key-field'),
        );
        await tester.ensureVisible(runKeyField);
        await tester.enterText(runKeyField, 'mcp-migrate-88');

        final Finder issueField = find.byKey(
          const ValueKey<String>('safety-issue-number-field'),
        );
        await tester.ensureVisible(issueField);
        await tester.enterText(issueField, '2712');

        final Finder evalBtn = find.byKey(
          const ValueKey<String>('safety-evaluate-button'),
        );
        await tester.ensureVisible(evalBtn);
        await tester.pumpAndSettle();
        await tester.tap(evalBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('safety-card-mcp-migrate-88')),
          findsOneWidget,
        );

        final Finder approveIssueBtn = find.byKey(
          const ValueKey<String>('safety-approve-issue-mcp-migrate-88'),
        );
        await tester.ensureVisible(approveIssueBtn);
        await tester.pumpAndSettle();
        await tester.tap(approveIssueBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('safety-card-mcp-migrate-88'),
            ),
            matching: find.text('GitHub Issue承認'),
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'passes responsive and WCAG accessibility audit across 360x800, 390x844, and 1280x800 in light/dark modes with 2.0x textScale',
      (WidgetTester tester) async {
        const List<Size> viewports = <Size>[
          Size(360, 800),
          Size(390, 844),
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

            final _InMemorySafetyRepository repo = _InMemorySafetyRepository();
            final ArchitecturalSafetyCheckpointController controller =
                ArchitecturalSafetyCheckpointController(repository: repo);

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
                        child: ArchitecturalSafetyCheckpointsContainer(
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
