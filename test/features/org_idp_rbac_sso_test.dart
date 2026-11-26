import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/org_idp_rbac/domain/org_idp_rbac_models.dart';
import 'package:my_web_app/features/org_idp_rbac/org_idp_rbac_container.dart';

class _FakeOrgIdpRbacRepository implements OrgIdpRbacRepository {
  _FakeOrgIdpRbacRepository({
    final List<OrgTenantSummary>? initialOrganizations,
    final Map<String, OrgRbacRole>? initialRolesByOrg,
    final Map<String, List<IdpGroupMapping>>? initialMappingsByOrg,
  })  : organizations = List<OrgTenantSummary>.from(
          initialOrganizations ?? const <OrgTenantSummary>[],
        ),
        rolesByOrg = Map<String, OrgRbacRole>.from(
          initialRolesByOrg ?? const <String, OrgRbacRole>{},
        ),
        mappingsByOrg = <String, List<IdpGroupMapping>>{
          for (final entry in (initialMappingsByOrg ??
                  const <String, List<IdpGroupMapping>>{})
              .entries)
            entry.key: List<IdpGroupMapping>.from(entry.value),
        };

  final List<OrgTenantSummary> organizations;
  final Map<String, OrgRbacRole> rolesByOrg;
  final Map<String, List<IdpGroupMapping>> mappingsByOrg;
  final Map<String, List<SsoAuditEntry>> auditsByOrg =
      <String, List<SsoAuditEntry>>{};
  bool throwOnLoad = false;
  Completer<List<OrgTenantSummary>>? pendingOrgLoad;

  @override
  Future<List<OrgTenantSummary>> fetchOrganizations() async {
    if (pendingOrgLoad != null) {
      return pendingOrgLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('org idp backend unavailable');
    }
    return List<OrgTenantSummary>.unmodifiable(organizations);
  }

  @override
  Future<OrgIdpBundle> fetchOrgIdpState(final String workosOrgId) async {
    if (throwOnLoad) {
      throw StateError('org idp state unavailable');
    }
    final role = rolesByOrg[workosOrgId] ?? OrgRbacRole.none;
    return OrgIdpBundle(
      callerRole: role,
      capabilities: OrgUiCapabilities.fromRole(role),
      mappings: List<IdpGroupMapping>.unmodifiable(
        mappingsByOrg[workosOrgId] ?? const <IdpGroupMapping>[],
      ),
      audits: List<SsoAuditEntry>.unmodifiable(
        auditsByOrg[workosOrgId] ?? const <SsoAuditEntry>[],
      ),
    );
  }

  @override
  Future<IdpGroupMapping> upsertMapping({
    required final String workosOrgId,
    required final IdpProviderKind idpProvider,
    required final String idpGroupId,
    required final String idpGroupLabel,
    required final OrgRbacRole mappedRole,
    required final int priority,
  }) async {
    final current = mappingsByOrg.putIfAbsent(
      workosOrgId,
      () => <IdpGroupMapping>[],
    );
    current.removeWhere(
      (final IdpGroupMapping item) =>
          item.idpProvider == idpProvider && item.idpGroupId == idpGroupId,
    );
    final created = IdpGroupMapping(
      id: 'map-${current.length + 1}',
      workosOrgId: workosOrgId,
      idpProvider: idpProvider,
      idpGroupId: idpGroupId,
      idpGroupLabel: idpGroupLabel,
      mappedRole: mappedRole,
      priority: priority,
      isActive: true,
    );
    current.insert(0, created);
    return created;
  }

  @override
  Future<void> deleteMapping({
    required final String workosOrgId,
    required final String mappingId,
  }) async {
    mappingsByOrg[workosOrgId]?.removeWhere(
      (final IdpGroupMapping item) => item.id == mappingId,
    );
  }

  @override
  Future<SsoEvaluationResult> evaluateSsoAssertion({
    required final String workosOrgId,
    required final IdpProviderKind idpProvider,
    required final List<String> assertedGroups,
    required final bool simulateAzureOverage,
    required final OrgRbacRole requiredRole,
  }) async {
    if (simulateAzureOverage && assertedGroups.isEmpty) {
      return SsoEvaluationResult(
        allowed: false,
        resolvedRole: OrgRbacRole.none,
        resolutionSource: 'azure_overage_fail_closed',
        overageDetected: true,
        matchedGroups: const <String>[],
        warnings: const <String>[
          'Entra ID hasgroups Overage が検出されたため fail-closed で拒否されました。',
        ],
        capabilities: OrgUiCapabilities.fromRole(OrgRbacRole.none),
      );
    }

    final current = mappingsByOrg[workosOrgId] ?? const <IdpGroupMapping>[];
    final matched = current
        .where(
          (final IdpGroupMapping item) =>
              item.isActive &&
              item.idpProvider == idpProvider &&
              assertedGroups.contains(item.idpGroupId),
        )
        .toList()
      ..sort(
        (final IdpGroupMapping a, final IdpGroupMapping b) =>
            b.mappedRole.rank.compareTo(a.mappedRole.rank),
      );

    final resolved =
        matched.isNotEmpty ? matched.first.mappedRole : OrgRbacRole.viewer;
    final source = matched.isNotEmpty ? 'idp_group_mapping' : 'default_viewer';
    return SsoEvaluationResult(
      allowed: resolved.satisfies(requiredRole),
      resolvedRole: resolved,
      resolutionSource: source,
      overageDetected: simulateAzureOverage,
      matchedGroups:
          matched.map((final IdpGroupMapping item) => item.idpGroupId).toList(),
      warnings: simulateAzureOverage
          ? const <String>['Entra ID hasgroups Overage 検出 (補助検証モード)。']
          : const <String>[],
      capabilities: OrgUiCapabilities.fromRole(resolved),
    );
  }
}

List<OrgTenantSummary> _seedOrganizations() {
  return const <OrgTenantSummary>[
    OrgTenantSummary(
      workosOrgId: 'org_acme',
      organizationName: 'Acme Corp',
    ),
    OrgTenantSummary(
      workosOrgId: 'org_beta',
      organizationName: 'Beta Corp',
    ),
    OrgTenantSummary(
      workosOrgId: 'org_gamma',
      organizationName: 'Gamma Corp',
    ),
  ];
}

Map<String, OrgRbacRole> _seedRolesByOrg() {
  return const <String, OrgRbacRole>{
    'org_acme': OrgRbacRole.admin,
    'org_beta': OrgRbacRole.viewer,
    'org_gamma': OrgRbacRole.member,
  };
}

Map<String, List<IdpGroupMapping>> _seedMappingsByOrg() {
  return const <String, List<IdpGroupMapping>>{
    'org_acme': <IdpGroupMapping>[
      IdpGroupMapping(
        id: 'map-acme-1',
        workosOrgId: 'org_acme',
        idpProvider: IdpProviderKind.okta,
        idpGroupId: 'okta-admins',
        idpGroupLabel: 'Okta Admins',
        mappedRole: OrgRbacRole.admin,
        priority: 100,
        isActive: true,
      ),
    ],
    'org_beta': <IdpGroupMapping>[],
    'org_gamma': <IdpGroupMapping>[
      IdpGroupMapping(
        id: 'map-gamma-1',
        workosOrgId: 'org_gamma',
        idpProvider: IdpProviderKind.okta,
        idpGroupId: 'okta-members',
        idpGroupLabel: 'Okta Members',
        mappedRole: OrgRbacRole.member,
        priority: 100,
        isActive: true,
      ),
    ],
  };
}

void main() {
  group('OrgIdpRbacModels and OrgIdpRbacContainer (#2691)', () {
    test(
      'computes hierarchical OrgRbacRole capabilities for owner/admin/member/viewer/none',
      () {
        final ownerCaps = OrgUiCapabilities.fromRole(OrgRbacRole.owner);
        expect(ownerCaps.canViewOrg, isTrue);
        expect(ownerCaps.canExecuteMemberActions, isTrue);
        expect(ownerCaps.canManageIdpMappings, isTrue);
        expect(ownerCaps.canAssignOwnerRole, isTrue);

        final adminCaps = OrgUiCapabilities.fromRole(OrgRbacRole.admin);
        expect(adminCaps.canManageIdpMappings, isTrue);
        expect(adminCaps.canAssignOwnerRole, isFalse);

        final memberCaps = OrgUiCapabilities.fromRole(OrgRbacRole.member);
        expect(memberCaps.canExecuteMemberActions, isTrue);
        expect(memberCaps.canManageIdpMappings, isFalse);

        final viewerCaps = OrgUiCapabilities.fromRole(OrgRbacRole.viewer);
        expect(viewerCaps.canViewOrg, isTrue);
        expect(viewerCaps.canExecuteMemberActions, isFalse);
        expect(viewerCaps.canManageIdpMappings, isFalse);

        final noneCaps = OrgUiCapabilities.fromRole(OrgRbacRole.none);
        expect(noneCaps.canViewOrg, isFalse);
        expect(noneCaps.canExecuteMemberActions, isFalse);
        expect(noneCaps.canManageIdpMappings, isFalse);
        expect(
          OrgRbacRole.fromWire('admin').satisfies(OrgRbacRole.member),
          isTrue,
        );
        expect(
          OrgRbacRole.fromWire('viewer').satisfies(OrgRbacRole.member),
          isFalse,
        );
      },
    );

    testWidgets(
      'gates UI capabilities dynamically per role/tenant and saves or deletes IdP mappings',
      (final WidgetTester tester) async {
        final repo = _FakeOrgIdpRbacRepository(
          initialOrganizations: _seedOrganizations(),
          initialRolesByOrg: _seedRolesByOrg(),
          initialMappingsByOrg: _seedMappingsByOrg(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: OrgIdpRbacContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('idp_rbac_admin_editor_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('delete_mapping_map-acme-1')),
          findsOneWidget,
        );
        expect(find.text('IdP ルール管理: 許可'), findsOneWidget);

        final groupIdField = find.byKey(
          const ValueKey<String>('idp_group_id_field'),
        );
        await tester.ensureVisible(groupIdField);
        await tester.pumpAndSettle();
        await tester.enterText(groupIdField, 'eng-operators');

        final groupLabelField = find.byKey(
          const ValueKey<String>('idp_group_label_field'),
        );
        await tester.ensureVisible(groupLabelField);
        await tester.pumpAndSettle();
        await tester.enterText(groupLabelField, 'Engineering Operators');

        final saveButton = find.byKey(
          const ValueKey<String>('idp_save_mapping_button'),
        );
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('idp_rbac_status_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Engineering Operators (eng-operators)'),
          findsOneWidget,
        );

        final deleteOldBtn = find.byKey(
          const ValueKey<String>('delete_mapping_map-acme-1'),
        );
        await tester.ensureVisible(deleteOldBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteOldBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('delete_mapping_map-acme-1')),
          findsNothing,
        );

        final orgDropdown = find.byKey(
          const ValueKey<String>('idp_org_dropdown'),
        );
        await tester.ensureVisible(orgDropdown);
        await tester.pumpAndSettle();
        await tester.tap(orgDropdown);
        await tester.pumpAndSettle();

        final betaOption = find.text('Beta Corp (org_beta)').last;
        await tester.ensureVisible(betaOption);
        await tester.pumpAndSettle();
        await tester.tap(betaOption);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('idp_rbac_admin_editor_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('idp_rbac_restricted_card')),
          findsOneWidget,
        );
        expect(find.text('IdP ルール管理: 不可'), findsOneWidget);
        expect(
          find.text('Engineering Operators (eng-operators)'),
          findsNothing,
        );

        await tester.ensureVisible(orgDropdown);
        await tester.pumpAndSettle();
        await tester.tap(orgDropdown);
        await tester.pumpAndSettle();

        final gammaOption = find.text('Gamma Corp (org_gamma)').last;
        await tester.ensureVisible(gammaOption);
        await tester.pumpAndSettle();
        await tester.tap(gammaOption);
        await tester.pumpAndSettle();

        expect(find.text('メンバー操作 API: 許可'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('idp_rbac_admin_editor_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('delete_mapping_map-gamma-1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'evaluates Okta group assertions and enforces Entra ID overage fail-closed',
      (final WidgetTester tester) async {
        final repo = _FakeOrgIdpRbacRepository(
          initialOrganizations: _seedOrganizations(),
          initialRolesByOrg: _seedRolesByOrg(),
          initialMappingsByOrg: _seedMappingsByOrg(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: OrgIdpRbacContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final ssoGroupsField = find.byKey(
          const ValueKey<String>('sso_groups_csv_field'),
        );
        await tester.ensureVisible(ssoGroupsField);
        await tester.pumpAndSettle();
        await tester.enterText(ssoGroupsField, 'okta-admins');

        final evaluateBtn = find.byKey(
          const ValueKey<String>('sso_evaluate_button'),
        );
        await tester.ensureVisible(evaluateBtn);
        await tester.pumpAndSettle();
        await tester.tap(evaluateBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('allowed=true, role=管理者'),
          findsOneWidget,
        );

        final providerDropdown = find.byKey(
          const ValueKey<String>('sso_provider_dropdown'),
        );
        await tester.ensureVisible(providerDropdown);
        await tester.pumpAndSettle();
        await tester.tap(providerDropdown);
        await tester.pumpAndSettle();

        final entraOption = find.text('Microsoft Entra ID (Azure AD)').last;
        await tester.ensureVisible(entraOption);
        await tester.pumpAndSettle();
        await tester.tap(entraOption);
        await tester.pumpAndSettle();

        await tester.ensureVisible(ssoGroupsField);
        await tester.pumpAndSettle();
        await tester.enterText(ssoGroupsField, '');

        final overageSwitch = find.byKey(
          const ValueKey<String>('sso_overage_switch'),
        );
        await tester.ensureVisible(overageSwitch);
        await tester.pumpAndSettle();
        await tester.tap(overageSwitch);
        await tester.pumpAndSettle();

        await tester.ensureVisible(evaluateBtn);
        await tester.pumpAndSettle();
        await tester.tap(evaluateBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'allowed=false, role=アクセス不可, source=azure_overage_fail_closed',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('idp_rbac_admin_editor_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('idp_rbac_restricted_card')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'retries failed loads cleanly and ignores async completion after dispose',
      (final WidgetTester tester) async {
        final repo = _FakeOrgIdpRbacRepository(
          initialOrganizations: _seedOrganizations(),
          initialRolesByOrg: _seedRolesByOrg(),
          initialMappingsByOrg: _seedMappingsByOrg(),
        )..throwOnLoad = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: OrgIdpRbacContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('idp_rbac_error_banner')),
          findsOneWidget,
        );

        repo.throwOnLoad = false;
        final retryBtn = find.byKey(
          const ValueKey<String>('idp_rbac_retry_button'),
        );
        await tester.ensureVisible(retryBtn);
        await tester.pumpAndSettle();
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('idp_rbac_error_banner')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('idp_rbac_admin_editor_card')),
          findsOneWidget,
        );

        final completer = Completer<List<OrgTenantSummary>>();
        final pendingRepo = _FakeOrgIdpRbacRepository()
          ..pendingOrgLoad = completer;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrgIdpRbacContainer(repository: pendingRepo),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        completer.complete(_seedOrganizations());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in const <Size>[
      Size(360, 800),
      Size(390, 844),
      Size(1280, 800),
    ]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final semanticsHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final repo = _FakeOrgIdpRbacRepository(
                initialOrganizations: _seedOrganizations(),
                initialRolesByOrg: _seedRolesByOrg(),
                initialMappingsByOrg: _seedMappingsByOrg(),
              );
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    'idp_rbac_${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                  home: Builder(
                    builder: (final BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: Scaffold(
                          body: OrgIdpRbacContainer(repository: repo),
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
              expect(tester.takeException(), isNull);
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
