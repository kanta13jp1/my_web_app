import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/realtime_lock/application/realtime_lock_controller.dart';
import 'package:my_web_app/features/realtime_lock/domain/realtime_lock_models.dart';
import 'package:my_web_app/features/realtime_lock/realtime_lock_container.dart';

class _TestSubHandle implements RealtimeLockSubscriptionHandle {
  _TestSubHandle(this.onDispose);

  final void Function() onDispose;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    onDispose();
  }
}

class _InMemoryRealtimeLockRepository implements RealtimeLockRepository {
  _InMemoryRealtimeLockRepository({
    this.throwOnLoad = false,
    this.loadGate,
    this.createGate,
  }) : _records = <LockedDocumentRecord>[
          const LockedDocumentRecord(
            id: 'doc-1',
            title: '運用シフト計画',
            content: '担当: Team Alpha',
            revision: 1,
            updatedBy: 'user-self',
            updatedAtIso: '2026-11-25T00:00:00Z',
            sourceActor: 'user',
          ),
        ];

  final bool throwOnLoad;
  final Completer<void>? loadGate;
  final Completer<void>? createGate;
  final List<LockedDocumentRecord> _records;
  int _seq = 10;

  void Function(List<PresenceEditor> editors)? _presenceSink;
  void Function(RevisionAlertEvent event)? _revisionSink;
  final List<_TestSubHandle> createdHandles = <_TestSubHandle>[];

  void emitPresence(List<PresenceEditor> editors) {
    _presenceSink?.call(editors);
  }

  void emitExternalUpdate({
    required String recordId,
    required String updatedBy,
    required String newContent,
    String sourceActor = 'remote',
  }) {
    final int idx = _records.indexWhere(
      (LockedDocumentRecord item) => item.id == recordId,
    );
    if (idx < 0) {
      return;
    }
    final LockedDocumentRecord prev = _records[idx];
    final LockedDocumentRecord updated = LockedDocumentRecord(
      id: prev.id,
      title: prev.title,
      content: newContent,
      revision: prev.revision + 1,
      updatedBy: updatedBy,
      updatedAtIso: '2026-11-25T01:00:0${prev.revision + 1}Z',
      sourceActor: sourceActor,
    );
    _records[idx] = updated;
    _revisionSink?.call(
      RevisionAlertEvent(
        recordId: recordId,
        newRevision: updated.revision,
        updatedBy: updatedBy,
        updatedAtIso: updated.updatedAtIso,
        sourceActor: sourceActor,
        serverRecord: updated,
      ),
    );
  }

  LockedDocumentRecord? findById(String id) {
    for (final LockedDocumentRecord item in _records) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<LockedDocumentRecord>> loadDocuments() async {
    if (loadGate != null) {
      await loadGate!.future;
    }
    if (throwOnLoad) {
      throw StateError('Realtime lock repository unavailable');
    }
    return List<LockedDocumentRecord>.from(_records);
  }

  @override
  Future<LockedDocumentRecord> createDocument({
    required String title,
    required String content,
    required String updatedBy,
  }) async {
    if (createGate != null) {
      await createGate!.future;
    }
    final LockedDocumentRecord doc = LockedDocumentRecord(
      id: 'doc-${_seq++}',
      title: title,
      content: content,
      revision: 1,
      updatedBy: updatedBy,
      updatedAtIso: '2026-11-25T00:05:00Z',
      sourceActor: 'user',
    );
    _records.insert(0, doc);
    return doc;
  }

  @override
  Future<SaveLockedRecordOutcome> saveWithOptimisticLock({
    required String recordId,
    required int expectedRevision,
    required String title,
    required String content,
    required String updatedBy,
    String expectedUpdatedAtIso = '',
  }) async {
    final int idx = _records.indexWhere(
      (LockedDocumentRecord item) => item.id == recordId,
    );
    if (idx < 0) {
      throw StateError('Record not found: $recordId');
    }
    final LockedDocumentRecord current = _records[idx];
    if (current.revision != expectedRevision ||
        (expectedUpdatedAtIso.isNotEmpty &&
            current.updatedAtIso != expectedUpdatedAtIso)) {
      return SaveLockedRecordOutcome(
        saved: false,
        conflict: true,
        expectedRevision: expectedRevision,
        currentRevision: current.revision,
        serverRecord: current,
        message:
            '競合検知: expected r$expectedRevision != current r${current.revision}',
      );
    }

    final LockedDocumentRecord next = LockedDocumentRecord(
      id: current.id,
      title: title,
      content: content,
      revision: current.revision + 1,
      updatedBy: updatedBy,
      updatedAtIso: '2026-11-25T02:00:0${current.revision + 1}Z',
      sourceActor: 'user',
    );
    _records[idx] = next;
    return SaveLockedRecordOutcome(
      saved: true,
      conflict: false,
      record: next,
      expectedRevision: expectedRevision,
      currentRevision: next.revision,
      message: 'r${next.revision} で保存完了',
    );
  }

  @override
  Future<LockedDocumentRecord> triggerBatchUpdate({
    required String recordId,
    String actor = 'batch-job',
  }) async {
    final int idx = _records.indexWhere(
      (LockedDocumentRecord item) => item.id == recordId,
    );
    if (idx < 0) {
      throw StateError('Record not found');
    }
    final LockedDocumentRecord prev = _records[idx];
    final LockedDocumentRecord next = LockedDocumentRecord(
      id: prev.id,
      title: prev.title,
      content: '${prev.content}\n[batch-sync]',
      revision: prev.revision + 1,
      updatedBy: actor,
      updatedAtIso: '2026-11-25T01:30:00Z',
      sourceActor: 'batch',
    );
    _records[idx] = next;
    return next;
  }

  @override
  RealtimeLockSubscriptionHandle subscribeToDocument({
    required String recordId,
    required String sessionId,
    required String displayName,
    required void Function(List<PresenceEditor> editors) onPresenceChanged,
    required void Function(RevisionAlertEvent event) onRevisionChanged,
  }) {
    _presenceSink = onPresenceChanged;
    _revisionSink = onRevisionChanged;
    onPresenceChanged(<PresenceEditor>[
      PresenceEditor(
        sessionId: sessionId,
        userId: 'user-self',
        displayName: displayName,
        joinedAtIso: '2026-11-25T00:00:00Z',
        isSelf: true,
      ),
    ]);
    final _TestSubHandle handle = _TestSubHandle(() {
      _presenceSink = null;
      _revisionSink = null;
    });
    createdHandles.add(handle);
    return handle;
  }
}

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

Future<void> _enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'displays Realtime Presence, live conflict alert, blocks stale save, and resolves on latest revision',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _InMemoryRealtimeLockRepository repo =
          _InMemoryRealtimeLockRepository();
      await tester.pumpWidget(
        _wrapWithMaterial(RealtimeLockContainer(repository: repo)),
      );
      await tester.pumpAndSettle();

      // 1. Presence shows self and live peer joining.
      expect(find.textContaining('同時編集中: 1 名'), findsOneWidget);
      repo.emitPresence(const <PresenceEditor>[
        PresenceEditor(
          sessionId: 'session-local',
          userId: 'user-self',
          displayName: '編集ユーザー (自分)',
          joinedAtIso: '2026-11-25T00:00:00Z',
          isSelf: true,
        ),
        PresenceEditor(
          sessionId: 'session-peer',
          userId: 'user-peer',
          displayName: '別端末レビュアー',
          joinedAtIso: '2026-11-25T00:00:05Z',
          isSelf: false,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.textContaining('同時編集中: 2 名'), findsOneWidget);
      expect(find.textContaining('別端末レビュアー'), findsOneWidget);

      // 2. Edit locally while holding r1, then simulate concurrent update -> r2.
      await _enterTextVisible(
        tester,
        find.byKey(const ValueKey<String>('realtime_lock_draft_content_field')),
        '自分の未保存ドラフト',
      );
      repo.emitExternalUpdate(
        recordId: 'doc-1',
        updatedBy: 'nightly-batch',
        newContent: '担当: Team Beta (バッチ更新)',
        sourceActor: 'batch',
      );
      await tester.pumpAndSettle();

      // Immediate Conflict Alert appears without clobbering user draft.
      expect(
        find.byKey(const ValueKey<String>('realtime_lock_conflict_banner')),
        findsOneWidget,
      );
      expect(find.textContaining('nightly-batch'), findsOneWidget);
      expect(find.textContaining('Team Beta'), findsOneWidget);

      // 3. Stale save at r1 is blocked by optimistic lock; server r2 stays safe.
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('realtime_lock_save_btn')),
      );
      expect(
        find.byKey(const ValueKey<String>('realtime_lock_error_banner')),
        findsOneWidget,
      );
      expect(repo.findById('doc-1')?.revision, 2);
      expect(repo.findById('doc-1')?.content, '担当: Team Beta (バッチ更新)');

      // 4. Rebase onto r2 and save cleanly -> r3 succeeds.
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('realtime_lock_rebase_save_btn')),
      );
      expect(
        find.byKey(const ValueKey<String>('realtime_lock_conflict_banner')),
        findsNothing,
      );
      expect(repo.findById('doc-1')?.revision, 3);
      expect(repo.findById('doc-1')?.content, '自分の未保存ドラフト');
    },
  );

  testWidgets('supports server reload recovery and 360x800/1280x800 viewports',
      (
    WidgetTester tester,
  ) async {
    final _InMemoryRealtimeLockRepository repo =
        _InMemoryRealtimeLockRepository();
    await tester.pumpWidget(
      _wrapWithMaterial(RealtimeLockContainer(repository: repo)),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('realtime_lock_simulate_batch_btn')),
    );
    expect(
      find.byKey(const ValueKey<String>('realtime_lock_conflict_banner')),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('realtime_lock_reload_server_btn')),
    );
    expect(
      find.byKey(const ValueKey<String>('realtime_lock_conflict_banner')),
      findsNothing,
    );
    expect(find.textContaining('取得リビジョン: r2'), findsOneWidget);

    for (final Size viewport in const <Size>[
      Size(360, 800),
      Size(1280, 800),
    ]) {
      await tester.binding.setSurfaceSize(viewport);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('handles load error and safe channel disposal', (
    WidgetTester tester,
  ) async {
    final _InMemoryRealtimeLockRepository repo =
        _InMemoryRealtimeLockRepository();
    final RealtimeLockController ctrl = RealtimeLockController(
      repository: repo,
    );
    await ctrl.loadDocuments();
    expect(repo.createdHandles.length, 1);
    expect(repo.createdHandles.first.disposed, isFalse);

    ctrl.dispose();
    expect(repo.createdHandles.first.disposed, isTrue);
    // Calling mutation after dispose must remain safe.
    ctrl.updateDraftTitle('ignored-after-dispose');

    await tester.pumpWidget(
      _wrapWithMaterial(
        RealtimeLockContainer(
          repository: _InMemoryRealtimeLockRepository(throwOnLoad: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('realtime_lock_error_banner')),
      findsOneWidget,
    );
  });

  testWidgets(
      'does not subscribe or leak channel handles on mid-flight dispose', (
    WidgetTester tester,
  ) async {
    final Completer<void> loadGate = Completer<void>();
    final _InMemoryRealtimeLockRepository loadRepo =
        _InMemoryRealtimeLockRepository(loadGate: loadGate);
    final RealtimeLockController loadCtrl = RealtimeLockController(
      repository: loadRepo,
    );
    final Future<void> pendingLoad = loadCtrl.loadDocuments();
    expect(loadRepo.createdHandles, isEmpty);

    loadCtrl.dispose();
    loadGate.complete();
    await pendingLoad;
    expect(loadRepo.createdHandles, isEmpty);

    final Completer<void> createGate = Completer<void>();
    final _InMemoryRealtimeLockRepository createRepo =
        _InMemoryRealtimeLockRepository(createGate: createGate);
    final RealtimeLockController createCtrl = RealtimeLockController(
      repository: createRepo,
    );
    final Future<bool> pendingCreate = createCtrl.createDocument(
      title: '破棄予定ドキュメント',
      content: 'draft',
    );
    createCtrl.dispose();
    createGate.complete();
    final bool created = await pendingCreate;
    expect(created, isFalse);
    expect(createRepo.createdHandles, isEmpty);
  });
}
