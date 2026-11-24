import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/services/admin_action_audit_service.dart';
import 'package:my_web_app/widgets/admin_action_audit_panel.dart';

class _FakeAdminActionAuditRepository implements AdminActionAuditRepository {
  final List<AdminImpactAssessment> _assessments = <AdminImpactAssessment>[
    AdminImpactAssessment(
      id: 'assess-initial-1',
      actorUserId: 'admin-1',
      actionType: AdminActionType.schemaMigration,
      targetResource: 'public.user_profiles',
      changeSummary: 'Add verification metadata index',
      expectedImpactScope: 'Reads during index build',
      riskLevel: AdminActionRiskLevel.high,
      riskScore: 78,
      mitigationPlan: 'CONCURRENTLY index creation',
      requiresPreConfirmation: true,
      impactConfirmed: false,
      status: AdminAssessmentStatus.pendingReview,
      approvedBy: null,
      approvedAt: null,
      executedAt: null,
      createdAt: DateTime.utc(2026, 11, 24, 1, 0),
      updatedAt: DateTime.utc(2026, 11, 24, 1, 0),
    ),
  ];

  final List<AdminActionAuditLogEntry> _logs = <AdminActionAuditLogEntry>[
    AdminActionAuditLogEntry(
      id: 'log-1',
      assessmentId: 'assess-initial-1',
      actorUserId: 'admin-1',
      actorRole: 'authenticated',
      actionType: AdminActionType.schemaMigration,
      targetTable: 'admin_impact_assessments',
      targetResource: 'public.user_profiles',
      operation: AdminAuditOperation.insert,
      riskLevel: AdminActionRiskLevel.high,
      impactSummary: 'Reads during index build',
      preState: const <String, Object?>{},
      postState: const <String, Object?>{'status': 'pending_review'},
      impactConfirmed: false,
      createdAt: DateTime.utc(2026, 11, 24, 1, 0),
    ),
    AdminActionAuditLogEntry(
      id: 'log-2',
      assessmentId: 'assess-old-2',
      actorUserId: 'admin-1',
      actorRole: 'authenticated',
      actionType: AdminActionType.configChange,
      targetTable: 'admin_impact_assessments',
      targetResource: 'app.banner_copy',
      operation: AdminAuditOperation.execute,
      riskLevel: AdminActionRiskLevel.low,
      impactSummary: 'Copy update only',
      preState: const <String, Object?>{'status': 'approved'},
      postState: const <String, Object?>{'status': 'executed'},
      impactConfirmed: true,
      createdAt: DateTime.utc(2026, 11, 24, 0, 30),
    ),
  ];

  bool throwOnLoad = false;
  int _seq = 10;

  @override
  Future<List<AdminActionAuditLogEntry>> listAuditLogs({
    int limit = 100,
  }) async {
    if (throwOnLoad) {
      throw StateError('simulated audit load error');
    }
    return _logs.take(limit).toList(growable: false);
  }

  @override
  Future<List<AdminImpactAssessment>> listAssessments({
    int limit = 50,
  }) async {
    if (throwOnLoad) {
      throw StateError('simulated assessment load error');
    }
    return _assessments.take(limit).toList(growable: false);
  }

  @override
  Future<AdminImpactAssessment> createImpactAssessment({
    required AdminActionType actionType,
    required String targetResource,
    required String changeSummary,
    String expectedImpactScope = '',
    String mitigationPlan = '',
  }) async {
    _seq += 1;
    final evaluation = AdminActionImpactEvaluator.evaluate(
      actionType: actionType,
      targetResource: targetResource,
      changeSummary: changeSummary,
      expectedImpactScope: expectedImpactScope,
      mitigationPlan: mitigationPlan,
    );
    final now = DateTime.utc(2026, 11, 24, 2, _seq);
    final created = AdminImpactAssessment(
      id: 'assess-$_seq',
      actorUserId: 'admin-1',
      actionType: actionType,
      targetResource: targetResource,
      changeSummary: changeSummary,
      expectedImpactScope: expectedImpactScope,
      riskLevel: evaluation.riskLevel,
      riskScore: evaluation.riskScore,
      mitigationPlan: mitigationPlan,
      requiresPreConfirmation: evaluation.requiresPreConfirmation,
      impactConfirmed: false,
      status: AdminAssessmentStatus.pendingReview,
      approvedBy: null,
      approvedAt: null,
      executedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    _assessments.insert(0, created);
    _logs.insert(
      0,
      AdminActionAuditLogEntry(
        id: 'log-$_seq',
        assessmentId: created.id,
        actorUserId: 'admin-1',
        actorRole: 'authenticated',
        actionType: created.actionType,
        targetTable: 'admin_impact_assessments',
        targetResource: created.targetResource,
        operation: AdminAuditOperation.insert,
        riskLevel: created.riskLevel,
        impactSummary: created.expectedImpactScope,
        preState: const <String, Object?>{},
        postState: <String, Object?>{'status': created.status.wireValue},
        impactConfirmed: false,
        createdAt: now,
      ),
    );
    return created;
  }

  @override
  Future<AdminImpactAssessment> confirmAndApproveAssessment({
    required String id,
    required bool impactConfirmed,
    String mitigationPlan = '',
  }) async {
    if (!impactConfirmed) {
      throw StateError('impactConfirmed must be true');
    }
    final index = _assessments.indexWhere((a) => a.id == id);
    final current = _assessments[index];
    final now = DateTime.utc(2026, 11, 24, 3, 0);
    final updated = AdminImpactAssessment(
      id: current.id,
      actorUserId: current.actorUserId,
      actionType: current.actionType,
      targetResource: current.targetResource,
      changeSummary: current.changeSummary,
      expectedImpactScope: current.expectedImpactScope,
      riskLevel: current.riskLevel,
      riskScore: current.riskScore,
      mitigationPlan:
          mitigationPlan.isNotEmpty ? mitigationPlan : current.mitigationPlan,
      requiresPreConfirmation: current.requiresPreConfirmation,
      impactConfirmed: true,
      status: AdminAssessmentStatus.approved,
      approvedBy: 'admin-1',
      approvedAt: now,
      executedAt: null,
      createdAt: current.createdAt,
      updatedAt: now,
    );
    _assessments[index] = updated;
    _seq += 1;
    _logs.insert(
      0,
      AdminActionAuditLogEntry(
        id: 'log-$_seq',
        assessmentId: updated.id,
        actorUserId: 'admin-1',
        actorRole: 'authenticated',
        actionType: updated.actionType,
        targetTable: 'admin_impact_assessments',
        targetResource: updated.targetResource,
        operation: AdminAuditOperation.approve,
        riskLevel: updated.riskLevel,
        impactSummary: updated.expectedImpactScope,
        preState: const <String, Object?>{'status': 'pending_review'},
        postState: const <String, Object?>{'status': 'approved'},
        impactConfirmed: true,
        createdAt: now,
      ),
    );
    return updated;
  }

  @override
  Future<AdminImpactAssessment> executeApprovedAssessment({
    required String id,
  }) async {
    final index = _assessments.indexWhere((a) => a.id == id);
    final current = _assessments[index];
    final now = DateTime.utc(2026, 11, 24, 4, 0);
    final executed = AdminImpactAssessment(
      id: current.id,
      actorUserId: current.actorUserId,
      actionType: current.actionType,
      targetResource: current.targetResource,
      changeSummary: current.changeSummary,
      expectedImpactScope: current.expectedImpactScope,
      riskLevel: current.riskLevel,
      riskScore: current.riskScore,
      mitigationPlan: current.mitigationPlan,
      requiresPreConfirmation: current.requiresPreConfirmation,
      impactConfirmed: current.impactConfirmed,
      status: AdminAssessmentStatus.executed,
      approvedBy: current.approvedBy,
      approvedAt: current.approvedAt,
      executedAt: now,
      createdAt: current.createdAt,
      updatedAt: now,
    );
    _assessments[index] = executed;
    _seq += 1;
    _logs.insert(
      0,
      AdminActionAuditLogEntry(
        id: 'log-$_seq',
        assessmentId: executed.id,
        actorUserId: 'admin-1',
        actorRole: 'authenticated',
        actionType: executed.actionType,
        targetTable: 'admin_impact_assessments',
        targetResource: executed.targetResource,
        operation: AdminAuditOperation.execute,
        riskLevel: executed.riskLevel,
        impactSummary: executed.expectedImpactScope,
        preState: const <String, Object?>{'status': 'approved'},
        postState: const <String, Object?>{'status': 'executed'},
        impactConfirmed: true,
        createdAt: now,
      ),
    );
    return executed;
  }
}

void main() {
  group(
    'AdminActionAuditService',
    () {
      test(
        'evaluates critical risk for sensitive RLS and user privilege updates',
        () {
          final result = AdminActionImpactEvaluator.evaluate(
            actionType: AdminActionType.userPrivilegeChange,
            targetResource: 'public.user_profiles',
            changeSummary: 'Promote operator admin flag',
            expectedImpactScope: 'Grants admin dashboard access',
            mitigationPlan: 'Revoke via SQL rollback',
          );
          expect(result.riskLevel, AdminActionRiskLevel.critical);
          expect(result.riskScore, greaterThanOrEqualTo(85));
          expect(result.requiresPreConfirmation, isTrue);

          final lowResult = AdminActionImpactEvaluator.evaluate(
            actionType: AdminActionType.configChange,
            targetResource: 'ui.banner_text',
            changeSummary: 'Adjust copy label',
            expectedImpactScope: 'Header notice only',
          );
          expect(lowResult.riskLevel, AdminActionRiskLevel.low);
        },
      );

      test(
        'parses audit logs and assessments and applies filters accurately',
        () {
          final entry =
              AdminActionAuditLogEntry.fromJson(const <String, Object?>{
            'id': 'audit-1',
            'assessment_id': 'assess-1',
            'actor_user_id': 'admin-1',
            'actor_role': 'authenticated',
            'action_type': 'rls_policy_update',
            'target_table': 'admin_impact_assessments',
            'target_resource': 'public.financial_records',
            'operation': 'APPROVE',
            'risk_level': 'critical',
            'impact_summary': 'Restricts client writes',
            'pre_state': <String, Object?>{'status': 'pending_review'},
            'post_state': <String, Object?>{'status': 'approved'},
            'impact_confirmed': true,
            'created_at': '2026-11-24T01:00:00Z',
          });
          expect(entry.actionType, AdminActionType.rlsPolicyUpdate);
          expect(entry.operation, AdminAuditOperation.approve);
          expect(entry.riskLevel, AdminActionRiskLevel.critical);
          expect(entry.impactConfirmed, isTrue);

          final filtered = const AdminAuditFilter(
            riskLevel: AdminActionRiskLevel.critical,
            searchQuery: 'financial_records',
          ).apply(<AdminActionAuditLogEntry>[entry]);
          expect(filtered, hasLength(1));

          final nonMatch = const AdminAuditFilter(
            operation: AdminAuditOperation.execute,
          ).apply(<AdminActionAuditLogEntry>[entry]);
          expect(nonMatch, isEmpty);
        },
      );
    },
  );

  group(
    'AdminActionAuditPanel Widget & A11y',
    () {
      testWidgets(
        'supports filtering, pre-change confirmation, approve, and execute',
        (WidgetTester tester) async {
          final repo = _FakeAdminActionAuditRepository();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AdminActionAuditPanel(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('監査ログ総数: 2'), findsOneWidget);

          final searchField =
              find.byKey(const ValueKey<String>('audit_search_input'));
          await tester.ensureVisible(searchField);
          await tester.enterText(searchField, 'banner_copy');
          await tester.pumpAndSettle();
          expect(
            find.textContaining('[実行記録] システム設定変更 - app.banner_copy'),
            findsOneWidget,
          );
          expect(
            find.textContaining('[起票] DBスキーマ変更 - public.user_profiles'),
            findsNothing,
          );

          final lowChip =
              find.byKey(const ValueKey<String>('audit_risk_chip_low'));
          await tester.ensureVisible(lowChip);
          await tester.tap(lowChip);
          await tester.pumpAndSettle();

          final allRiskChip =
              find.byKey(const ValueKey<String>('audit_risk_chip_all'));
          await tester.ensureVisible(allRiskChip);
          await tester.tap(allRiskChip);
          await tester.enterText(searchField, '');
          await tester.pumpAndSettle();

          final targetField =
              find.byKey(const ValueKey<String>('audit_target_resource_input'));
          await tester.ensureVisible(targetField);
          await tester.enterText(targetField, 'public.mcp_audit_log');

          final summaryField =
              find.byKey(const ValueKey<String>('audit_change_summary_input'));
          await tester.ensureVisible(summaryField);
          await tester.enterText(summaryField, 'Tighten RLS select policy');

          final impactField =
              find.byKey(const ValueKey<String>('audit_impact_scope_input'));
          await tester.ensureVisible(impactField);
          await tester.enterText(impactField, 'Admin queries only');

          final createBtn = find
              .byKey(const ValueKey<String>('audit_create_assessment_button'));
          await tester.ensureVisible(createBtn);
          await tester.tap(createBtn);
          await tester.pumpAndSettle();

          expect(find.textContaining('変更前の影響評価を起票しました'), findsOneWidget);

          final confirmBox = find.byKey(
            const ValueKey<String>('audit_confirm_checkbox_assess-11'),
          );
          final approveBtn = find
              .byKey(const ValueKey<String>('audit_approve_button_assess-11'));
          await tester.ensureVisible(approveBtn);
          expect(
            tester.widget<FilledButton>(approveBtn).onPressed,
            isNull,
          );

          await tester.ensureVisible(confirmBox);
          await tester.tap(confirmBox);
          await tester.pumpAndSettle();

          await tester.ensureVisible(approveBtn);
          expect(
            tester.widget<FilledButton>(approveBtn).onPressed,
            isNotNull,
          );
          await tester.tap(approveBtn);
          await tester.pumpAndSettle();
          expect(find.textContaining('事前影響確認を承認し'), findsOneWidget);

          final executeBtn = find
              .byKey(const ValueKey<String>('audit_execute_button_assess-11'));
          await tester.ensureVisible(executeBtn);
          await tester.tap(executeBtn);
          await tester.pumpAndSettle();
          expect(find.textContaining('変更実行を監査ログへ記録しました'), findsOneWidget);
        },
      );

      testWidgets(
        'displays error and recovers on retry',
        (WidgetTester tester) async {
          final repo = _FakeAdminActionAuditRepository()..throwOnLoad = true;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AdminActionAuditPanel(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('監査ログ・影響評価の読込に失敗しました'), findsOneWidget);

          repo.throwOnLoad = false;
          final retryBtn =
              find.byKey(const ValueKey<String>('audit_retry_button'));
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(find.textContaining('監査ログ総数: 2'), findsOneWidget);
        },
      );

      for (final viewport in const <Size>[Size(390, 844), Size(1280, 800)]) {
        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          testWidgets(
            'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (WidgetTester tester) async {
              final a11yHandle = tester.ensureSemantics();
              addTearDown(a11yHandle.dispose);
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _FakeAdminActionAuditRepository();
                final theme = brightness == Brightness.dark
                    ? ThemeData.dark()
                    : ThemeData.light();
                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey<String>(
                      '${viewport.width.toInt()}_${brightness.name}',
                    ),
                    theme: theme,
                    home: Builder(
                      builder: (BuildContext context) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: viewport,
                            textScaler: const TextScaler.linear(2.0),
                          ),
                          child: Scaffold(
                            body: SingleChildScrollView(
                              child: AdminActionAuditPanel(repository: repo),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
                await tester.pumpAndSettle();

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
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              }
            },
          );
        }
      }
    },
  );
}
