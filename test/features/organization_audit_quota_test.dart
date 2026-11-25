import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/organization_audit_quota/application/organization_audit_quota_controller.dart';
import 'package:my_web_app/features/organization_audit_quota/data/supabase_organization_audit_quota_repository.dart';
import 'package:my_web_app/features/organization_audit_quota/domain/organization_audit_quota_models.dart';
import 'package:my_web_app/features/organization_audit_quota/organization_audit_quota_container.dart';

class _InMemoryOrgAuditQuotaRepository
    implements OrganizationAuditQuotaRepository {
  _InMemoryOrgAuditQuotaRepository({
    final int initialUsed = 70,
    final int initialLimit = 100,
  })  : _used = initialUsed,
        _limit = initialLimit {
    _recomputeAlertAndLogs();
  }

  final String orgId = '11111111-1111-4111-8111-111111111111';
  int _used;
  int _limit;
  bool throwOnLoad = false;
  DateTime? _warnTriggeredAt;
  DateTime? _exceededAt;
  final List<OrganizationQuotaAlert> _alerts = <OrganizationQuotaAlert>[];
  final List<OrganizationAuditLogEntry> _logs = <OrganizationAuditLogEntry>[
    OrganizationAuditLogEntry(
      id: 'log-1',
      organizationId: '11111111-1111-4111-8111-111111111111',
      actorUserId: 'user-owner',
      actorRole: 'authenticated',
      eventType: OrgAuditEventType.login,
      resourceType: 'session',
      resourceId: 'sess-1',
      summary: '組織オーナーがログインしました',
      createdAt: DateTime.utc(2026, 11, 25, 0, 10),
    ),
    OrganizationAuditLogEntry(
      id: 'log-2',
      organizationId: '11111111-1111-4111-8111-111111111111',
      actorUserId: 'user-owner',
      actorRole: 'authenticated',
      eventType: OrgAuditEventType.permissionChange,
      resourceType: 'team_membership',
      resourceId: 'user-member',
      summary: '組織メンバー権限変更 (member -> admin)',
      createdAt: DateTime.utc(2026, 11, 25, 0, 20),
    ),
    OrganizationAuditLogEntry(
      id: 'log-3',
      organizationId: '11111111-1111-4111-8111-111111111111',
      actorUserId: 'user-admin',
      actorRole: 'authenticated',
      eventType: OrgAuditEventType.resourceCreate,
      resourceType: 'team_shared_note',
      resourceId: '42',
      summary: '組織共有ノート作成 (note_id=42)',
      createdAt: DateTime.utc(2026, 11, 25, 0, 30),
    ),
  ];

  void _recomputeAlertAndLogs() {
    final double pct = (_used / _limit) * 100.0;
    if (pct >= 80.0 && _warnTriggeredAt == null) {
      _warnTriggeredAt = DateTime.utc(2026, 11, 25, 1, 0);
      _alerts.insert(
        0,
        OrganizationQuotaAlert(
          id: 'alert-warn-80',
          organizationId: orgId,
          resourceType: OrgQuotaResourceType.apiCalls,
          periodKey: '2026-11',
          alertLevel: OrgQuotaAlertLevel.warning80,
          usagePct: pct,
          usedAmount: _used,
          limitAmount: _limit,
          message: '組織の api_calls 利用率が警告閾値 (80%) に到達しました ($_used/$_limit)。',
          adminNotified: true,
          createdAt: DateTime.utc(2026, 11, 25, 1, 0),
          notifiedAt: DateTime.utc(2026, 11, 25, 1, 0),
        ),
      );
    }
  }

  @override
  Future<OrganizationAuditQuotaDashboard> fetchDashboard({
    required final String organizationId,
    final OrgAuditEventType eventFilter = OrgAuditEventType.all,
  }) async {
    if (throwOnLoad) {
      throw StateError('Simulated dashboard load failure');
    }
    final List<OrganizationAuditLogEntry> filtered =
        eventFilter == OrgAuditEventType.all
            ? List<OrganizationAuditLogEntry>.unmodifiable(_logs)
            : _logs
                .where(
                  (final OrganizationAuditLogEntry e) =>
                      e.eventType == eventFilter,
                )
                .toList(growable: false);
    return OrganizationAuditQuotaDashboard(
      organizationId: organizationId,
      periodKey: '2026-11',
      quotas: <OrganizationQuotaUsage>[
        OrganizationQuotaUsage(
          id: 'quota-1',
          organizationId: organizationId,
          resourceType: OrgQuotaResourceType.apiCalls,
          periodKey: '2026-11',
          limitAmount: _limit,
          usedAmount: _used,
          warningThresholdPct: 80.0,
          warning80TriggeredAt: _warnTriggeredAt,
          lastExceededAt: _exceededAt,
        ),
      ],
      alerts: List<OrganizationQuotaAlert>.unmodifiable(_alerts),
      auditLogs: filtered,
    );
  }

  @override
  Future<OrganizationAuditLogEntry> recordAuditEvent({
    required final String organizationId,
    required final OrgAuditEventType eventType,
    required final String resourceType,
    final String resourceId = '',
    final String summary = '',
  }) async {
    final entry = OrganizationAuditLogEntry(
      id: 'log-${_logs.length + 1}',
      organizationId: organizationId,
      actorUserId: 'user-owner',
      actorRole: 'authenticated',
      eventType: eventType,
      resourceType: resourceType,
      resourceId: resourceId,
      summary: summary,
      createdAt: DateTime.utc(2026, 11, 25, 2, 0),
    );
    _logs.insert(0, entry);
    return entry;
  }

  @override
  Future<OrgQuotaConsumeOutcome> consumeQuota({
    required final String organizationId,
    required final OrgQuotaResourceType resourceType,
    final int units = 1,
  }) async {
    if (_used + units > _limit) {
      _exceededAt = DateTime.utc(2026, 11, 25, 1, 30);
      _logs.insert(
        0,
        OrganizationAuditLogEntry(
          id: 'log-${_logs.length + 1}',
          organizationId: organizationId,
          actorUserId: 'user-member',
          actorRole: 'authenticated',
          eventType: OrgAuditEventType.quotaLimitExceeded,
          resourceType: resourceType.wireValue,
          resourceId: '2026-11',
          summary: '上限超過のためブロックしました',
          createdAt: DateTime.utc(2026, 11, 25, 1, 30),
        ),
      );
      throw const OrgQuotaExceededException(
        message: '組織のリソース利用上限に達したため処理をブロックしました。管理者にクォータ引き上げを依頼してください。',
      );
    }

    final bool wasWarned = _warnTriggeredAt != null;
    _used += units;
    _recomputeAlertAndLogs();
    final bool newlyWarned = !wasWarned && _warnTriggeredAt != null;
    final double pct = (_used / _limit) * 100.0;
    return OrgQuotaConsumeOutcome(
      allowed: true,
      httpStatus: 200,
      usedAmount: _used,
      limitAmount: _limit,
      remaining: _limit - _used,
      usagePct: pct,
      warning80Triggered: pct >= 80.0,
      alertTriggered: newlyWarned,
    );
  }

  @override
  Future<OrganizationQuotaUsage> updateQuotaLimit({
    required final String organizationId,
    required final OrgQuotaResourceType resourceType,
    required final int limitAmount,
    final double warningThresholdPct = 80.0,
  }) async {
    _limit = limitAmount;
    return OrganizationQuotaUsage(
      id: 'quota-1',
      organizationId: organizationId,
      resourceType: resourceType,
      periodKey: '2026-11',
      limitAmount: _limit,
      usedAmount: _used,
      warningThresholdPct: warningThresholdPct,
      warning80TriggeredAt: _warnTriggeredAt,
      lastExceededAt: _exceededAt,
    );
  }

  @override
  Future<OrganizationQuotaAlert> acknowledgeAlert({
    required final String organizationId,
    required final String alertId,
  }) async {
    final int idx = _alerts.indexWhere(
      (final OrganizationQuotaAlert a) => a.id == alertId,
    );
    final OrganizationQuotaAlert existing = _alerts[idx];
    final updated = OrganizationQuotaAlert(
      id: existing.id,
      organizationId: existing.organizationId,
      resourceType: existing.resourceType,
      periodKey: existing.periodKey,
      alertLevel: existing.alertLevel,
      usagePct: existing.usagePct,
      usedAmount: existing.usedAmount,
      limitAmount: existing.limitAmount,
      message: existing.message,
      adminNotified: existing.adminNotified,
      createdAt: existing.createdAt,
      notifiedAt: existing.notifiedAt,
      acknowledgedBy: 'user-owner',
      acknowledgedAt: DateTime.utc(2026, 11, 25, 2, 0),
    );
    _alerts[idx] = updated;
    return updated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrganizationAuditQuotaController Unit Tests (#2692)', () {
    test(
      'triggers 80% warning alert and surfaces HTTP 429 block message',
      () async {
        final repo = _InMemoryOrgAuditQuotaRepository(
          initialUsed: 75,
          initialLimit: 100,
        );
        final controller = OrganizationAuditQuotaController(
          repository: repo,
          organizationId: repo.orgId,
        );
        await controller.loadDashboard();
        expect(controller.state.hasWarning80, isFalse);

        // Push utilization to 80% -> triggers 80% admin warning
        final outcome80 = await controller.consumeResourceQuota(
          resourceType: OrgQuotaResourceType.apiCalls,
          units: 5,
        );
        expect(outcome80?.allowed, isTrue);
        expect(outcome80?.alertTriggered, isTrue);
        expect(controller.state.hasWarning80, isTrue);
        expect(controller.state.activeWarningAlerts.length, 1);

        // Exceed 100% -> throws HTTP 429 OrgQuotaExceededException and sets block banner
        final blocked = await controller.consumeResourceQuota(
          resourceType: OrgQuotaResourceType.apiCalls,
          units: 25,
        );
        expect(blocked, isNull);
        expect(
          controller.state.quotaBlockedMessage,
          contains('組織のリソース利用上限に達したため処理をブロックしました'),
        );
      },
    );
  });

  group('OrganizationAuditQuotaContainer Widget & A11y (#2692)', () {
    testWidgets(
      'displays audit logs, 80% warning banner, 429 block banner, and alert acknowledgment',
      (final WidgetTester tester) async {
        final repo = _InMemoryOrgAuditQuotaRepository(
          initialUsed: 70,
          initialLimit: 100,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrganizationAuditQuotaContainer(
                organizationId: repo.orgId,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('組織監査ログ (3 件)'), findsOneWidget);
        expect(find.textContaining('組織オーナーがログインしました'), findsOneWidget);

        // Consume 15 -> 85/100 (85%) -> shows 80% admin alert banner
        final unitsField = find.byKey(
          const ValueKey<String>('org_quota_units_input'),
        );
        await tester.ensureVisible(unitsField);
        await tester.enterText(unitsField, '15');

        final consumeBtn = find.byKey(
          const ValueKey<String>('org_quota_consume_btn'),
        );
        await tester.ensureVisible(consumeBtn);
        await tester.tap(consumeBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('org_quota_warning_80_banner')),
          findsOneWidget,
        );

        // Consume 25 -> 85+25 > 100 -> shows HTTP 429 block banner
        await tester.ensureVisible(unitsField);
        await tester.enterText(unitsField, '25');
        await tester.ensureVisible(consumeBtn);
        await tester.tap(consumeBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('org_quota_blocked_429_banner')),
          findsOneWidget,
        );

        // Acknowledge alert
        final ackBtn = find.byKey(
          const ValueKey<String>('org_quota_ack_btn_alert-warn-80'),
        );
        await tester.ensureVisible(ackBtn);
        await tester.tap(ackBtn);
        await tester.pumpAndSettle();
        expect(find.text('管理者確認済み'), findsOneWidget);
      },
    );

    for (final Size viewport in const <Size>[Size(360, 800), Size(390, 844)]) {
      for (final Brightness brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final a11yHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final repo = _InMemoryOrgAuditQuotaRepository(
                initialUsed: 85,
                initialLimit: 100,
              );
              await tester.pumpWidget(
                MaterialApp(
                  theme: brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                  home: Builder(
                    builder: (final BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: viewport,
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: Scaffold(
                          body: OrganizationAuditQuotaContainer(
                            organizationId: repo.orgId,
                            repository: repo,
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
              a11yHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
