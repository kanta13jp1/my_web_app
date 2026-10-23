import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/space_sharing_page.dart';
import 'package:my_web_app/services/space_sharing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders invitation and owner controls on narrow layout',
      (tester) async {
    final source = _FakeSpaceSharingDataSource(_ownerSnapshot());
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SpaceSharingPage(
          dataSource: source,
          initialSpaceId: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('space_sharing_narrow')), findsOneWidget);
    expect(
      find.byKey(const Key('space_invitation_accept_invite-2')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('space_invite_7')), findsOneWidget);
    expect(find.byKey(const Key('space_create_note_7')), findsOneWidget);
    expect(find.text('Shared note'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('space_invitation_accept_invite-2')),
    );
    await tester.pumpAndSettle();

    expect(source.acceptedInvitationId, 'invite-2');
  });

  testWidgets('submits a normalized invitation permission', (tester) async {
    final source = _FakeSpaceSharingDataSource(_ownerSnapshot());
    await tester.pumpWidget(
      MaterialApp(
        home: SpaceSharingPage(
          dataSource: source,
          initialSpaceId: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('space_invite_7')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('space_invite_email')),
      'New.Member@Example.com',
    );
    await tester.tap(find.byKey(const Key('space_invite_submit')));
    await tester.pumpAndSettle();

    expect(source.invitedEmail, 'New.Member@Example.com');
    expect(source.invitedPermission, SpacePermission.edit);
  });

  testWidgets('view-only member has no mutation controls on wide layout',
      (tester) async {
    final source = _FakeSpaceSharingDataSource(_viewerSnapshot());
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SpaceSharingPage(
          dataSource: source,
          initialSpaceId: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('space_sharing_wide')), findsOneWidget);
    expect(find.byKey(const Key('space_invite_7')), findsNothing);
    expect(find.byKey(const Key('space_create_note_7')), findsNothing);
    expect(find.byKey(const Key('space_note_move_91')), findsNothing);
    expect(find.byKey(const Key('space_leave_7')), findsOneWidget);
    expect(find.byKey(const Key('space_note_open_91')), findsOneWidget);
  });
  testWidgets('failed refresh warns while retaining visible sharing data',
      (tester) async {
    final source = _FakeSpaceSharingDataSource(_ownerSnapshot());
    await tester.pumpWidget(
      MaterialApp(home: SpaceSharingPage(dataSource: source)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('space_sharing_list')), findsOneWidget);

    source.loadError = StateError('synthetic refresh failure');
    await tester.tap(find.byKey(const Key('space_sharing_reload')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('space_sharing_stale_warning')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('space_sharing_list')), findsOneWidget);
    expect(tester.takeException(), isNull);

    source.loadError = null;
    await tester.tap(find.byKey(const Key('space_sharing_reload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('space_sharing_stale_warning')), findsNothing);
  });
  for (final olderFails in [false, true]) {
    testWidgets('latest sharing refresh wins when olderFails=$olderFails',
        (tester) async {
      final source = _FakeSpaceSharingDataSource(_ownerSnapshot());
      await tester.pumpWidget(
        MaterialApp(home: SpaceSharingPage(dataSource: source)),
      );
      await tester.pumpAndSettle();

      final older = Completer<SpaceSharingSnapshot>();
      final newer = Completer<SpaceSharingSnapshot>();
      var calls = 0;
      source.loadOverride = () => calls++ == 0 ? older.future : newer.future;
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final olderRefresh = refresh.onRefresh();
      final newerRefresh = refresh.onRefresh();
      newer.complete(_viewerSnapshot());
      await newerRefresh;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('space_invite_7')), findsNothing);

      if (olderFails) {
        older.completeError(StateError('synthetic older failure'));
      } else {
        older.complete(_ownerSnapshot());
      }
      await olderRefresh;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('space_invite_7')), findsNothing);
      expect(
        find.byKey(const Key('space_sharing_stale_warning')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final action in ['invite', 'move', 'remove']) {
    testWidgets('disposed sharing page ignores $action dialog confirmation',
        (tester) async {
      final source = _FakeSpaceSharingDataSource(_ownerSnapshot());
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, child) => show
                ? SpaceSharingPage(dataSource: source, initialSpaceId: 7)
                : const Scaffold(body: Text('Replacement')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final openKey = switch (action) {
        'invite' => 'space_invite_7',
        'move' => 'space_note_move_91',
        _ => 'space_member_remove_member',
      };
      final open = find.byKey(Key(openKey));
      await tester.scrollUntilVisible(
        open,
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('space_sharing_list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(open);
      await tester.pumpAndSettle();
      if (action == 'invite') {
        await tester.enterText(
          find.byKey(const Key('space_invite_email')),
          'fixture@example.invalid',
        );
      }
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('space_sharing_page')), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final confirmKey = switch (action) {
        'invite' => 'space_invite_submit',
        'move' => 'space_note_move_submit',
        _ => 'space_member_remove_confirm',
      };
      await tester.tap(find.byKey(Key(confirmKey)));
      await tester.pumpAndSettle();
      expect(source.mutationCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('cancelled invitation resets email when reopened',
      (tester) async {
    final source = _FakeSpaceSharingDataSource(_ownerSnapshot());
    await tester.pumpWidget(
      MaterialApp(
        home: SpaceSharingPage(dataSource: source, initialSpaceId: 7),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('space_invite_7')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('space_invite_email')),
      'cancelled@example.invalid',
    );
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(source.mutationCalls, 0);
    await tester.tap(find.byKey(const Key('space_invite_7')));
    await tester.pumpAndSettle();
    final input = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('space_invite_email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(input.controller.text, isEmpty);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(source.mutationCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

SpaceSharingSnapshot _ownerSnapshot() => SpaceSharingSnapshot(
      currentUserId: 'owner',
      incomingInvitations: const [
        SpaceInvitationRecord(
          id: 'invite-2',
          spaceId: 8,
          spaceName: 'Invited Space',
          email: 'owner@example.com',
          permission: SpacePermission.view,
        ),
      ],
      spaces: [
        SpaceAccessRecord(
          id: 7,
          ownerId: 'owner',
          name: 'Project Space',
          description: 'Shared project',
          permission: SpacePermission.owner,
          members: const [
            SpaceMemberRecord(
              userId: 'member',
              email: 'member@example.com',
              permission: SpacePermission.edit,
            ),
          ],
          pendingInvitations: const [
            SpaceInvitationRecord(
              id: 'invite-1',
              spaceId: 7,
              spaceName: 'Project Space',
              email: 'pending@example.com',
              permission: SpacePermission.view,
            ),
          ],
          notebooks: const [
            SpaceNotebookRecord(id: 70, name: 'Roadmap'),
          ],
          notes: [
            SpaceNoteRecord(
              id: 91,
              title: 'Shared note',
              createdBy: 'member',
              updatedAt: DateTime.utc(2026, 8, 31),
              notebookId: 70,
            ),
          ],
        ),
      ],
    );

SpaceSharingSnapshot _viewerSnapshot() => SpaceSharingSnapshot(
      currentUserId: 'viewer',
      incomingInvitations: const [],
      spaces: [
        SpaceAccessRecord(
          id: 7,
          ownerId: 'owner',
          name: 'Project Space',
          description: '',
          permission: SpacePermission.view,
          members: const [
            SpaceMemberRecord(
              userId: 'viewer',
              email: 'viewer@example.com',
              permission: SpacePermission.view,
            ),
          ],
          pendingInvitations: const [],
          notebooks: const [
            SpaceNotebookRecord(id: 70, name: 'Roadmap'),
          ],
          notes: [
            SpaceNoteRecord(
              id: 91,
              title: 'Shared note',
              createdBy: 'member',
              updatedAt: DateTime.utc(2026, 8, 31),
              notebookId: 70,
            ),
          ],
        ),
      ],
    );

class _FakeSpaceSharingDataSource implements SpaceSharingDataSource {
  _FakeSpaceSharingDataSource(this.snapshot);

  final SpaceSharingSnapshot snapshot;
  int mutationCalls = 0;
  StateError? loadError;
  Future<SpaceSharingSnapshot> Function()? loadOverride;
  String? acceptedInvitationId;
  String? invitedEmail;
  SpacePermission? invitedPermission;

  @override
  Future<SpaceSharingSnapshot> load() async {
    if (loadOverride != null) return loadOverride!();
    if (loadError != null) throw loadError!;
    return snapshot;
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    acceptedInvitationId = invitationId;
  }

  @override
  Future<void> declineInvitation(String invitationId) async {}

  @override
  Future<void> revokeInvitation(String invitationId) async {}

  @override
  Future<void> invite({
    required int spaceId,
    required String email,
    required SpacePermission permission,
  }) async {
    mutationCalls += 1;
    invitedEmail = email;
    invitedPermission = permission;
  }

  @override
  Future<void> updateMemberPermission({
    required int spaceId,
    required String memberUserId,
    required SpacePermission permission,
  }) async {}

  @override
  Future<void> removeMember({
    required int spaceId,
    required String memberUserId,
  }) async {
    mutationCalls += 1;
  }

  @override
  Future<int> createDirectNote({
    required int spaceId,
    String title = '',
    String content = '',
  }) async =>
      92;

  @override
  Future<void> moveNote({
    required int noteId,
    int? destinationNotebookId,
  }) async {
    mutationCalls += 1;
  }
}
