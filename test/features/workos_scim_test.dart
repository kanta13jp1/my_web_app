import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/workos_scim/domain/workos_scim_models.dart';
import 'package:my_web_app/features/workos_scim/workos_scim_container.dart';

class _FakeWorkosScimRepository implements WorkosScimRepository {
  _FakeWorkosScimRepository({
    final List<WorkosOrganization>? initialOrganizations,
    final List<WorkosDirectoryMember>? initialMembers,
    final List<WorkosScimEvent>? initialEvents,
  })  : organizations = List<WorkosOrganization>.from(
          initialOrganizations ?? const <WorkosOrganization>[],
        ),
        members = List<WorkosDirectoryMember>.from(
          initialMembers ?? const <WorkosDirectoryMember>[],
        ),
        events = List<WorkosScimEvent>.from(
          initialEvents ?? const <WorkosScimEvent>[],
        );

  final List<WorkosOrganization> organizations;
  final List<WorkosDirectoryMember> members;
  final List<WorkosScimEvent> events;
  final List<WorkosPortalIntent> portalRequests = <WorkosPortalIntent>[];
  bool simulateOfflineFallback = false;
  bool throwOnLoad = false;
  Completer<List<WorkosOrganization>>? pendingOrgLoad;

  @override
  Future<List<WorkosOrganization>> fetchOrganizations() async {
    if (pendingOrgLoad != null) {
      return pendingOrgLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('workos organizations unavailable');
    }
    return List<WorkosOrganization>.unmodifiable(organizations);
  }

  @override
  Future<List<WorkosDirectoryMember>> fetchMembers(
    final String workosOrgId,
  ) async {
    return List<WorkosDirectoryMember>.unmodifiable(
      members.where(
        (final WorkosDirectoryMember m) => m.workosOrgId == workosOrgId,
      ),
    );
  }

  @override
  Future<List<WorkosScimEvent>> fetchRecentEvents(
    final String workosOrgId,
  ) async {
    return List<WorkosScimEvent>.unmodifiable(
      events.where(
        (final WorkosScimEvent e) => e.workosOrgId == workosOrgId,
      ),
    );
  }

  @override
  Future<WorkosOrganization> registerOrganization({
    required final String workosOrgId,
    required final String organizationName,
  }) async {
    final created = WorkosOrganization(
      id: 'org-uuid-${organizations.length + 1}',
      workosOrgId: workosOrgId,
      organizationName: organizationName,
      ownerUserId: 'owner-1',
      scimEnabled: true,
      defaultRole: WorkosOrgRole.member,
      lastIntent: WorkosPortalIntent.dsync,
    );
    organizations.insert(0, created);
    return created;
  }

  @override
  Future<WorkosPortalLinkResult> generateAdminPortalLink({
    required final String workosOrgId,
    required final WorkosPortalIntent intent,
    final String? returnUrl,
  }) async {
    portalRequests.add(intent);
    if (simulateOfflineFallback) {
      return WorkosPortalLinkResult(
        ok: true,
        isOfflineFallback: true,
        intent: intent,
        workosOrgId: workosOrgId,
        message: 'WORKOS_API_KEY 未設定のためオフラインプレビューとして返却しました。',
      );
    }
    return WorkosPortalLinkResult(
      ok: true,
      isOfflineFallback: false,
      intent: intent,
      workosOrgId: workosOrgId,
      portalUrl: 'https://id.workos.com/portal/link_${intent.wireValue}',
      message: 'issued',
    );
  }

  @override
  Future<WorkosDirectoryMember> updateMemberRole({
    required final String workosOrgId,
    required final String directoryUserId,
    required final WorkosOrgRole role,
  }) async {
    for (var i = 0; i < members.length; i += 1) {
      if (members[i].directoryUserId == directoryUserId) {
        final updated = members[i].copyWith(role: role);
        members[i] = updated;
        return updated;
      }
    }
    throw StateError('Member not found');
  }
}

List<WorkosOrganization> _seedOrgs() => <WorkosOrganization>[
      WorkosOrganization(
        id: 'org-1',
        workosOrgId: 'org_acme_1',
        organizationName: 'Acme Enterprise',
        ownerUserId: 'owner-1',
        scimEnabled: true,
        defaultRole: WorkosOrgRole.member,
        lastIntent: WorkosPortalIntent.dsync,
        lastPortalGeneratedAt: DateTime.utc(2026, 11, 25, 0, 0),
      ),
    ];

List<WorkosDirectoryMember> _seedMembers() => <WorkosDirectoryMember>[
      WorkosDirectoryMember(
        id: 'mem-1',
        workosOrgId: 'org_acme_1',
        directoryUserId: 'dir_usr_admin',
        email: 'admin@acme.example',
        displayName: 'Alice Admin',
        role: WorkosOrgRole.admin,
        status: WorkosProvisioningStatus.active,
        lastEventType: 'dsync.user.created',
        lastSyncedAt: DateTime.utc(2026, 11, 25, 1, 0),
      ),
      WorkosDirectoryMember(
        id: 'mem-2',
        workosOrgId: 'org_acme_1',
        directoryUserId: 'dir_usr_suspended',
        email: 'bob@acme.example',
        displayName: 'Bob Suspended',
        role: WorkosOrgRole.owner,
        status: WorkosProvisioningStatus.suspended,
        lastEventType: 'dsync.user.updated',
        lastSyncedAt: DateTime.utc(2026, 11, 25, 1, 5),
      ),
    ];

List<WorkosScimEvent> _seedEvents() => <WorkosScimEvent>[
      WorkosScimEvent(
        id: 'scim-1',
        workosOrgId: 'org_acme_1',
        workosEventId: 'evt_101',
        eventType: 'dsync.user.updated',
        directoryUserId: 'dir_usr_suspended',
        targetStatus: WorkosProvisioningStatus.suspended,
        processedAt: DateTime.utc(2026, 11, 25, 1, 5),
      ),
    ];

void main() {
  group(
    'WorkosScimContainer (#2683)',
    () {
      test(
        'enforces org provisioning status and RBAC rank on WorkosDirectoryMember.canAccess',
        () {
          final activeAdmin = _seedMembers().first;
          final suspendedOwner = _seedMembers().last;

          expect(
            activeAdmin.canAccess(
              orgScimEnabled: true,
              requiredRole: WorkosOrgRole.member,
            ),
            isTrue,
          );
          expect(
            activeAdmin.canAccess(
              orgScimEnabled: true,
              requiredRole: WorkosOrgRole.owner,
            ),
            isFalse,
          );
          expect(
            suspendedOwner.canAccess(
              orgScimEnabled: true,
              requiredRole: WorkosOrgRole.viewer,
            ),
            isFalse,
          );
          expect(
            activeAdmin.canAccess(
              orgScimEnabled: false,
              requiredRole: WorkosOrgRole.viewer,
            ),
            isFalse,
          );
        },
      );

      testWidgets(
        'generates Admin Portal setup links (live + offline fallback), filters SCIM members, and opens URL callback',
        (final WidgetTester tester) async {
          final openedUrls = <String>[];
          final repo = _FakeWorkosScimRepository(
            initialOrganizations: _seedOrgs(),
            initialMembers: _seedMembers(),
            initialEvents: _seedEvents(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: WorkosScimContainer(
                  repository: repo,
                  onOpenPortalUrl: openedUrls.add,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('workos_member_dir_usr_admin')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey<String>('workos_rbac_dir_usr_suspended'),
              ),
              matching: find.text('認可: 拒否'),
              matchRoot: true,
            ),
            findsOneWidget,
          );

          final generateBtn = find.byKey(
            const ValueKey<String>('workos_generate_portal_button'),
          );
          await tester.ensureVisible(generateBtn);
          await tester.pumpAndSettle();
          await tester.tap(generateBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('workos_portal_result_card')),
            findsOneWidget,
          );

          final openBtn = find.byKey(
            const ValueKey<String>('workos_open_portal_button'),
          );
          await tester.ensureVisible(openBtn);
          await tester.pumpAndSettle();
          await tester.tap(openBtn);
          await tester.pumpAndSettle();
          expect(
            openedUrls,
            equals(const <String>['https://id.workos.com/portal/link_dsync']),
          );

          repo.simulateOfflineFallback = true;
          await tester.ensureVisible(generateBtn);
          await tester.pumpAndSettle();
          await tester.tap(generateBtn);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('WORKOS_API_KEY 未設定'),
            findsWidgets,
          );

          final suspendedChip = find.byKey(
            const ValueKey<String>('workos_filter_suspended'),
          );
          await tester.ensureVisible(suspendedChip);
          await tester.pumpAndSettle();
          await tester.tap(suspendedChip);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey<String>('workos_member_dir_usr_admin')),
            findsNothing,
          );
          expect(
            find.byKey(
              const ValueKey<String>('workos_member_dir_usr_suspended'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'displays error banner, recovers on retry, and disposes safely while pending',
        (final WidgetTester tester) async {
          final repo = _FakeWorkosScimRepository(
            initialOrganizations: _seedOrgs(),
            initialMembers: _seedMembers(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WorkosScimContainer(repository: repo),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey<String>('workos_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('workos_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.pumpAndSettle();
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey<String>('workos_error_banner')),
            findsNothing,
          );

          final completer = Completer<List<WorkosOrganization>>();
          final pendingRepo = _FakeWorkosScimRepository()
            ..pendingOrgLoad = completer;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WorkosScimContainer(repository: pendingRepo),
              ),
            ),
          );
          await tester.pump();
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(_seedOrgs());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      for (final viewport in const <Size>[Size(360, 800), Size(390, 844)]) {
        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          testWidgets(
            'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (final WidgetTester tester) async {
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _FakeWorkosScimRepository(
                  initialOrganizations: _seedOrgs(),
                  initialMembers: _seedMembers(),
                  initialEvents: _seedEvents(),
                );
                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey<String>(
                      'workos_${viewport.width.toInt()}_${brightness.name}',
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
                            body: WorkosScimContainer(repository: repo),
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
    },
  );
}
