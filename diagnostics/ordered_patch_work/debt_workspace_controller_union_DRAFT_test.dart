// SYNTHETIC DRAFT ONLY: not compiled or run. In-memory fixtures are not an
// IndexedDB adapter, browser persistence test, or product-page integration.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'debt_workspace_controller_union_DRAFT.dart';
import 'debt_legacy_review_widget_DRAFT.dart';

class _ScopedFake implements ScopedDebtLocal {
  final snapshots = <DebtWorkspace, ScopedDebtSnapshot>{};
  final heldReads = <DebtWorkspace, Completer<void>>{};
  final heldWrites = <DebtWorkspace, Completer<void>>{};
  final heldResponses = <int, Completer<void>>{};
  final wrongRead = <DebtWorkspace, DebtWorkspace>{};
  final forcedRead = <DebtWorkspace, ScopedDebtSnapshot>{};
  final legacyRaw = <String, String>{
    'values': 'synthetic-values', 'deleted': 'synthetic-deleted',
    'dirty': 'synthetic-dirty', 'timestamp': 'synthetic-time',
  };
  bool rejectNext = false;
  bool failNextRead = false;
  bool throwAfterCommit = false;
  bool ignoreLease = false;
  final writeCommitted = Completer<void>();
  // Completes synchronously at entry, before heldWrites can be released.
  final writeStarted = Completer<void>();
  int writeCalls = 0;
  int fence = 0;
  final activationGates = <DebtWorkspace, Completer<void>>{};
  final activationStarted = Completer<void>();
  bool invalidAckValue = false;
  bool invalidAckVersion = false;
  bool invalidAckIntent = false;
  bool dropOtherValueFromAck = false;
  bool dropOtherTombstoneFromAck = false;
  bool dropOtherValueFromStore = false;
  bool dropOtherTombstoneFromStore = false;
  bool guardCandidateIntegrity = true;
  bool forgeAck = false;
  bool failReadAfterWrite = false;
  DebtWorkspace? active;

  @override
  Future<int> activate(DebtWorkspace workspace) async {
    if (!activationStarted.isCompleted) activationStarted.complete();
    final gate = activationGates.remove(workspace);
    if (gate != null) await gate.future;
    active = workspace;
    return ++fence;
  }

  ScopedDebtSnapshot _current(DebtWorkspace workspace) => snapshots[workspace] ??
      ScopedDebtSnapshot(workspace: workspace, version: 0, values: const {});

  @override
  Future<ScopedDebtSnapshot> read(DebtWorkspace workspace) async {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('synthetic read failed before commit');
    }
    final wrong = wrongRead[workspace];
    final captured = forcedRead[workspace] ?? _current(wrong ?? workspace);
    final gate = heldReads.remove(workspace);
    if (gate != null) await gate.future;
    return captured;
  }

  @override
  Future<ScopedEditResult> writeEdit(
      DebtWorkspace workspace, String key, int? day, int capturedFence, int expectedVersion, int intent, ScopedSelectionLeaseDraft lease) async {
    final number = ++writeCalls;
    if (!writeStarted.isCompleted) writeStarted.complete();
    final gate = heldWrites.remove(workspace);
    if (gate != null) await gate.future;
    if (rejectNext) {
      rejectNext = false;
      return const ScopedEditResult(committed: false);
    }
    final old = _current(workspace);
    if ((!ignoreLease && lease.isRevoked) || active != workspace || fence != capturedFence || old.version != expectedVersion) {
      return const ScopedEditResult(committed: false);
    }
    final values = Map<String, int>.from(old.values);
    final deleted = Set<String>.from(old.deletedKeys);
    if (day == null) { values.remove(key); deleted.add(key); }
    else { values[key] = day; deleted.remove(key); }
    final expectedValues = Map<String, int>.from(values);
    final expectedDeleted = Set<String>.from(deleted);
    if (dropOtherValueFromStore) values.remove('other-debt');
    if (dropOtherTombstoneFromStore) deleted.remove('deleted-item');
    // A cooperating fake checks the full candidate before its synchronous
    // mutation. This is not a real durable storage transaction.
    if (guardCandidateIntegrity &&
        (values.length != expectedValues.length || deleted.length != expectedDeleted.length ||
         expectedValues.keys.any((k) => values[k] != expectedValues[k]) ||
         !deleted.containsAll(expectedDeleted))) {
      return const ScopedEditResult(committed: false);
    }
    final next = ScopedDebtSnapshot(workspace: workspace,
        version: old.version + 1, values: values, deletedKeys: deleted);
    snapshots[workspace] = next;
    if (failReadAfterWrite) failNextRead = true;
    if (!writeCommitted.isCompleted) writeCommitted.complete();
    if (throwAfterCommit) {
      throwAfterCommit = false;
      throw StateError('synthetic lost response');
    }
    final responseGate = heldResponses.remove(number);
    if (responseGate != null) await responseGate.future;
    final ackValues = invalidAckValue
        ? <String, int>{'synthetic-debt': 31}
        : Map<String, int>.from(forgeAck ? expectedValues : next.values);
    final ackDeleted = Set<String>.from(forgeAck ? expectedDeleted : next.deletedKeys);
    if (dropOtherValueFromAck) ackValues.remove('other-debt');
    if (dropOtherTombstoneFromAck) ackDeleted.remove('deleted-item');
    final ack = ScopedDebtSnapshot(workspace: workspace,
        version: invalidAckVersion ? old.version : next.version,
        values: ackValues, deletedKeys: ackDeleted);
    return ScopedEditResult(committed: true, snapshot: ack,
        intent: invalidAckIntent ? intent + 1 : intent);
  }
}

class _RestoreFake implements ScopedDebtRestore {
  _RestoreFake(this.local);
  final _ScopedFake local;
  final remote = <DebtWorkspace, ScopedDebtSnapshot>{};
  final fetchGates = <DebtWorkspace, Completer<void>>{};
  Completer<void>? mergeGate;
  Completer<void>? mergeResponseGate;
  final mergeCommitted = Completer<void>();
  final mergeStarted = Completer<void>();
  int merges = 0;
  bool throwAfterMerge = false;
  bool dropExistingValue = false;
  bool dropExistingTombstone = false;
  // Fault injection for remote-only tombstones; default fake keeps them.
  bool dropIncomingTombstone = false;
  bool dropIncomingValue = false;
  bool injectUnexpectedValue = false;

  @override
  Future<ScopedDebtSnapshot> fetch(DebtWorkspace workspace, int fence) async {
    final captured = remote[workspace] ??
        ScopedDebtSnapshot(workspace: workspace, version: 0, values: const {});
    final gate = fetchGates.remove(workspace);
    if (gate != null) await gate.future;
    return captured;
  }

  @override
  Future<ScopedEditResult> mergeIfUnchanged(DebtWorkspace workspace,
      int fence, int expectedVersion, ScopedDebtSnapshot incoming, ScopedSelectionLeaseDraft lease) async {
    merges++;
    if (!mergeStarted.isCompleted) mergeStarted.complete();
    final gate = mergeGate;
    mergeGate = null;
    if (gate != null) await gate.future;
    final current = local._current(workspace);
    if (lease.isRevoked || current.version != expectedVersion || incoming.workspace != workspace || local.active != workspace || local.fence != fence) {
      return const ScopedEditResult(committed: false);
    }
    // Synthetic union only. Real storage must additionally protect dirty keys,
    // tombstones, owner epoch and old-version concurrent tabs in a transaction.
    final merged = <String, int>{...incoming.values, ...current.values};
    if (dropIncomingValue) merged.remove('remote-only');
    if (injectUnexpectedValue) merged['unexpected'] = 8;
    final deleted = Set<String>.from(current.deletedKeys);
    if (!dropIncomingTombstone) {
      // Only unconflicted synthetic tombstones; full dirty/LWW policy is not modeled.
      deleted.addAll(incoming.deletedKeys.where((key) => !current.values.containsKey(key)));
    }
    for (final key in deleted) { merged.remove(key); }
    if (dropExistingValue && current.values.isNotEmpty) merged.remove(current.values.keys.first);
    if (dropExistingTombstone && deleted.isNotEmpty) deleted.remove(deleted.first);
    final snapshot = ScopedDebtSnapshot(workspace: workspace,
        version: current.version + 1, values: merged, deletedKeys: deleted);
    local.snapshots[workspace] = snapshot;
    if (!mergeCommitted.isCompleted) mergeCommitted.complete();
    final responseGate = mergeResponseGate;
    mergeResponseGate = null;
    if (responseGate != null) await responseGate.future;
    if (throwAfterMerge) throw StateError('synthetic lost merge response');
    return ScopedEditResult(committed: true, snapshot: snapshot);
  }
}
void main() {
  final a = DebtWorkspace.account('synthetic-A');
  final b = DebtWorkspace.account('synthetic-B');
  final anonymous = DebtWorkspace.unowned('synthetic-device');

  test('late A read cannot appear in selected B view', () async {
    final fake = _ScopedFake();
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    fake.snapshots[b] = ScopedDebtSnapshot(workspace: b, version: 1,
        values: const {'synthetic-debt': 20});
    final gate = Completer<void>();
    fake.heldReads[a] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    final pendingA = controller.select(a);
    expect(controller.visible, isNull);
    await controller.select(b);
    gate.complete();
    await pendingA;
    expect(controller.workspace, b);
    expect(controller.visible!.values['synthetic-debt'], 20);
  });

  test('in-flight A edit stays pending after B fence; B remains isolated', () async {
    final fake = _ScopedFake();
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final gate = Completer<void>();
    fake.heldWrites[a] = gate;
    final oldEdit = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    await controller.select(b);
    await controller.edit('synthetic-debt', 20);
    gate.complete();
    await oldEdit;
    expect(fake._current(a).values, isEmpty);
    expect(fake.snapshots[b]!.values['synthetic-debt'], 20);
    expect(controller.workspace, b);
    expect(controller.visible!.values['synthetic-debt'], 20);
  });

  test('wrong-scope load is rejected instead of rendered', () async {
    final fake = _ScopedFake()..wrongRead[b] = a;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(b);
    expect(controller.visible, isNull);
    expect(controller.failureCode, 'local_read_failed');
  });

  test('late old response cannot revert newer same-key view', () async {
    final fake = _ScopedFake();
    final gate = Completer<void>();
    fake.heldResponses[1] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final first = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    final second = controller.edit('synthetic-debt', 20);
    gate.complete();
    await first;
    await second;
    expect(fake.snapshots[a]!.values['synthetic-debt'], 20);
    expect(controller.visible!.values['synthetic-debt'], 20);
    expect(controller.pending, isEmpty);
  });

  test('failed local save keeps pending edit when switching away and back', () async {
    final fake = _ScopedFake()..rejectNext = true;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.edit('synthetic-debt', 10);
    expect(controller.pending['synthetic-debt'], 10);
    expect(controller.failureCode, 'local_write_failed');
    await controller.select(b);
    expect(controller.pending, isEmpty);
    await controller.select(a);
    expect(controller.pending['synthetic-debt'], 10);
    expect(controller.failureCode, 'local_write_failed');
  });

  test('unowned edit is not automatically copied to a signed-in owner', () async {
    final fake = _ScopedFake();
    final legacyBefore = Map<String, String>.from(fake.legacyRaw);
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(anonymous);
    await controller.edit('synthetic-debt', 12);
    await controller.select(a);
    expect(controller.visible!.values, isEmpty);
    expect(fake.snapshots[anonymous]!.values['synthetic-debt'], 12);
    expect(fake.legacyRaw, legacyBefore);
  });

  test('A reopening retains stale-fenced A edit as pending', () async {
    final fake = _ScopedFake();
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final gate = Completer<void>();
    fake.heldWrites[a] = gate;
    final oldEdit = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    await controller.select(b);
    await controller.select(a);
    gate.complete();
    await oldEdit;
    expect(controller.workspace, a);
    expect(controller.visible!.values, isEmpty);
    expect(controller.pending['synthetic-debt'], 10);
  });

  test('legacy review edits do not modify original synthetic four parts', () async {
    final fake = _ScopedFake();
    final original = Map<String, String>.from(fake.legacyRaw);
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(const DebtWorkspace.legacyReview());
    await controller.edit('synthetic-debt', 15);
    expect(fake.legacyRaw, original);
    expect(controller.visible!.values['synthetic-debt'], 15);
  });

  testWidgets('legacy view can continue locally without enabling copy', (tester) async {
    var localCalls = 0;
    var copyCalls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DebtLegacyReviewDraft(
      destinationLabel: null,
      rows: const [LegacyReviewRowDraft(label: 'synthetic-debt', day: 12)],
      onContinueLocal: () => localCalls++,
      onReviewCopy: () => copyCalls++,
      copyAvailable: false,
    ))));
    await tester.tap(find.text('端末で続ける'));
    await tester.pump();
    expect(localCalls, 1);
    expect(copyCalls, 0);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
  test('late A remote read cannot merge into B after sign-in switch', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final gate = Completer<void>();
    restore.fetchGates[a] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final pending = controller.pullAndRestore(restore);
    await controller.select(b);
    await controller.edit('synthetic-debt', 20);
    gate.complete();
    await pending;
    expect(restore.merges, 0);
    expect(controller.workspace, b);
    expect(controller.visible!.values['synthetic-debt'], 20);
  });

  test('first sign-in performs scoped pull without importing legacy or guest', () async {
    final fake = _ScopedFake();
    final original = Map<String, String>.from(fake.legacyRaw);
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-remote': 14});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(anonymous);
    await controller.edit('synthetic-guest', 12);
    await controller.onAuthChanged('synthetic-A',
        unownedWorkspaceId: 'synthetic-device', restore: restore);
    expect(controller.workspace, a);
    expect(controller.visible!.values['synthetic-remote'], 14);
    expect(controller.visible!.values, isNot(contains('synthetic-guest')));
    expect(fake.snapshots[anonymous]!.values['synthetic-guest'], 12);
    expect(fake.legacyRaw, original);
  });

  test('remote read completing during pending edit cannot be merged', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final fetchGate = Completer<void>();
    final writeGate = Completer<void>();
    restore.fetchGates[a] = fetchGate;
    fake.heldWrites[a] = writeGate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final pendingRestore = controller.pullAndRestore(restore);
    final pendingEdit = controller.edit('synthetic-debt', 20);
    fetchGate.complete();
    await pendingRestore;
    expect(restore.merges, 0);
    writeGate.complete();
    await pendingEdit;
    expect(controller.visible!.values['synthetic-debt'], 20);
  });

  test('edit during merge invalidates fake version guard', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final gate = Completer<void>();
    restore.mergeGate = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final pendingRestore = controller.pullAndRestore(restore);
    await restore.mergeStarted.future;
    await controller.edit('synthetic-debt', 20);
    gate.complete();
    await pendingRestore;
    expect(controller.visible!.values['synthetic-debt'], 20);
    expect(fake.snapshots[a]!.values['synthetic-debt'], 20);
  });
  test('wrong-owner remote payload is rejected before merge', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: b, version: 1,
        values: const {'synthetic-debt': 10});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(restore.merges, 0);
    expect(controller.failureCode, 'restore_scope_mismatch');
    expect(controller.visible!.values, isEmpty);
  });

  testWidgets('available review button only invokes injected review callback', (tester) async {
    var reviews = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DebtLegacyReviewDraft(
      destinationLabel: 'synthetic-A',
      rows: const [LegacyReviewRowDraft(label: 'synthetic-debt', day: 12)],
      onContinueLocal: () {},
      onReviewCopy: () => reviews++,
      copyAvailable: true,
    ))));
    await tester.tap(find.text('内容とコピー先を確認'));
    await tester.pump();
    expect(reviews, 1);
  });
  test('A-B-A rejects remote response captured at first A epoch', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final gate = Completer<void>();
    restore.fetchGates[a] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final old = controller.pullAndRestore(restore);
    await controller.select(b);
    await controller.select(a);
    gate.complete();
    await old;
    expect(restore.merges, 0);
    expect(controller.workspace, a);
    expect(controller.visible!.values, isEmpty);
  });
  test('held first commit cannot be overtaken by newer same-key save', () async {
    final fake = _ScopedFake();
    final gate = Completer<void>();
    fake.heldWrites[a] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final first = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    final second = controller.edit('synthetic-debt', 20);
    await Future<void>.delayed(Duration.zero);
    expect(fake.writeCalls, 1);
    expect(controller.pending['synthetic-debt'], 20);
    gate.complete();
    await Future.wait([first, second]);
    expect(fake.snapshots[a]!.values['synthetic-debt'], 20);
    expect(controller.pending, isEmpty);
  });

  test('started merge cannot commit after a new owner fence', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final gate = Completer<void>();
    restore.mergeGate = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final pending = controller.pullAndRestore(restore);
    await restore.mergeStarted.future;
    await controller.select(b);
    gate.complete();
    await pending;
    expect(fake._current(a).values, isEmpty);
    expect(fake._current(b).values, isEmpty);
    expect(controller.workspace, b);
  });

  test('lost local write response blocks later writes pending recovery', () async {
    final fake = _ScopedFake()..throwAfterCommit = true;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.edit('synthetic-debt', 10);
    await controller.edit('synthetic-debt', 20);
    expect(fake.writeCalls, 1);
    expect(fake.snapshots[a]!.values['synthetic-debt'], 10);
    expect(controller.pending['synthetic-debt'], 20);
    expect(controller.failureCode, 'local_write_unknown');
  });

  test('held old value cannot resurrect after newer deletion', () async {
    final fake = _ScopedFake();
    final gate = Completer<void>();
    fake.heldWrites[a] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final first = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    final deletion = controller.edit('synthetic-debt', null);
    await Future<void>.delayed(Duration.zero);
    expect(fake.writeCalls, 1);
    gate.complete();
    await Future.wait([first, deletion]);
    expect(fake.snapshots[a]!.values.containsKey('synthetic-debt'), isFalse);
    expect(fake.snapshots[a]!.deletedKeys, contains('synthetic-debt'));
  });

  test('edit waits for activation fence before starting local write', () async {
    final fake = _ScopedFake();
    final gate = Completer<void>();
    fake.activationGates[a] = gate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    final selection = controller.select(a);
    await fake.activationStarted.future;
    final edit = controller.edit('synthetic-debt', 12);
    await Future<void>.delayed(Duration.zero);
    expect(fake.writeCalls, 0);
    expect(controller.pending['synthetic-debt'], 12);
    gate.complete();
    await Future.wait([selection, edit]);
    expect(fake.snapshots[a]!.values['synthetic-debt'], 12);
  });

  for (final defect in ['value', 'version', 'intent']) {
    test('invalid $defect acknowledgement retains edit and blocks writes', () async {
      final fake = _ScopedFake();
      fake.invalidAckValue = defect == 'value';
      fake.invalidAckVersion = defect == 'version';
      fake.invalidAckIntent = defect == 'intent';
      final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
      await controller.select(a);
      await controller.edit('synthetic-debt', 12);
      expect(controller.pending['synthetic-debt'], 12);
      expect(controller.failureCode, 'local_write_unknown');
      await controller.edit('synthetic-debt', 13);
      expect(fake.writeCalls, 1);
      expect(controller.pending['synthetic-debt'], 13);
    });
  }

  test('default controller never starts restore without a real auth barrier', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(restore.merges, 0);
  });

  test('unknown restore result blocks repeat restore and later writes', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake)..throwAfterMerge = true;
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(controller.failureCode, 'restore_unknown');
    await controller.pullAndRestore(restore);
    await controller.edit('synthetic-debt', 20);
    expect(restore.merges, 1);
    expect(fake.writeCalls, 0);
    expect(controller.pending['synthetic-debt'], 20);
  });

  // The synchronous fake commit gate checks the revoked in-memory lease.
  // This does not establish cancellation of a real asynchronous transaction.
  test('notification revokes fake old merge before new fence commits', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final mergeGate = Completer<void>();
    restore.mergeGate = mergeGate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final oldMerge = controller.pullAndRestore(restore);
    await restore.mergeStarted.future;
    final activationGate = Completer<void>();
    fake.activationGates[b] = activationGate;
    final switching = controller.select(b);
    await Future<void>.delayed(Duration.zero);
    mergeGate.complete();
    await oldMerge;
    final afterOldMerge = Map<String, int>.from(fake._current(a).values);
    activationGate.complete();
    await switching;
    expect(afterOldMerge, isEmpty);
  });

  test('read fails before write: pending remains and retry is allowed', () async {
    final fake = _ScopedFake();
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    fake.failNextRead = true;
    await controller.edit('synthetic-debt', 12);
    expect(controller.failureCode, 'local_read_failed');
    expect(controller.pending['synthetic-debt'], 12);
    expect(fake.writeCalls, 0);
    await controller.edit('synthetic-debt', 12);
    expect(fake.writeCalls, 1);
    expect(controller.pending, isEmpty);
    expect(fake.snapshots[a]!.values['synthetic-debt'], 12);
  });

  test('same version with changed content is not accepted as refresh', () async {
    final fake = _ScopedFake();
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
        values: const {'synthetic-debt': 12}, deletedKeys: const {'deleted-item'});
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
        values: const {'synthetic-debt': 13}, deletedKeys: const {});
    await controller.refresh();
    expect(controller.failureCode, 'local_read_failed');
    expect(controller.visible!.values['synthetic-debt'], 12);
    expect(controller.visible!.deletedKeys, contains('deleted-item'));
  });

  for (final missing in ['value', 'tombstone']) {
    test('restore missing existing $missing is unknown and halts later work', () async {
      final fake = _ScopedFake();
      fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
          values: const {'synthetic-debt': 12}, deletedKeys: const {'deleted-item'});
      final restore = _RestoreFake(fake);
      restore.dropExistingValue = missing == 'value';
      restore.dropExistingTombstone = missing == 'tombstone';
      final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
      await controller.select(a);
      await controller.pullAndRestore(restore);
      expect(controller.failureCode, 'restore_unknown');
      expect(controller.visible!.values['synthetic-debt'], 12);
      expect(controller.visible!.deletedKeys, contains('deleted-item'));
      await controller.pullAndRestore(restore);
      expect(restore.merges, 1);
      // The bad fake already committed: detection is not a rollback.
      expect(fake.snapshots[a]!.version, 3);
    });
  }

  // The fake checks the in-memory lease immediately before its mutation.
  // This cannot prove async backend cancellation or cross-tab ordering.
  test('owner notification revokes fake old write before new fence commits', () async {
    final fake = _ScopedFake();
    final writeGate = Completer<void>();
    fake.heldWrites[a] = writeGate;
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    final oldWrite = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    final activationGate = Completer<void>();
    fake.activationGates[b] = activationGate;
    final switching = controller.select(b);
    await Future<void>.delayed(Duration.zero);
    writeGate.complete();
    await oldWrite;
    final afterOldWrite = Map<String, int>.from(fake._current(a).values);
    activationGate.complete();
    await switching;
    expect(afterOldWrite, isEmpty);
  });

  test('write committed before switch but late response remains unknown', () async {
    final fake = _ScopedFake();
    final responseGate = Completer<void>();
    fake.heldResponses[1] = responseGate;
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    final oldWrite = controller.edit('synthetic-debt', 10);
    await fake.writeCommitted.future;
    await controller.select(b);
    responseGate.complete();
    await oldWrite;
    await controller.select(a);
    expect(fake._current(a).values['synthetic-debt'], 10);
    expect(controller.pending['synthetic-debt'], 10);
    expect(controller.failureCode, 'local_write_unknown');
  });

  test('restore committed before switch but late response remains unknown', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final responseGate = Completer<void>();
    restore.mergeResponseGate = responseGate;
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    final oldMerge = controller.pullAndRestore(restore);
    await restore.mergeCommitted.future;
    await controller.select(b);
    responseGate.complete();
    await oldMerge;
    await controller.select(a);
    expect(fake._current(a).values['synthetic-debt'], 10);
    expect(controller.failureCode, 'restore_unknown');
  });

  test('adapter ignoring lease can commit; controller preserves unknown input', () async {
    final fake = _ScopedFake()..ignoreLease = true;
    final writeGate = Completer<void>();
    fake.heldWrites[a] = writeGate;
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    final oldWrite = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    final activationGate = Completer<void>();
    fake.activationGates[b] = activationGate;
    final switching = controller.select(b);
    await Future<void>.delayed(Duration.zero);
    writeGate.complete();
    await oldWrite;
    final oldScope = Map<String, int>.from(fake._current(a).values);
    activationGate.complete();
    await switching;
    await controller.select(a);
    expect(oldScope['synthetic-debt'], 10);
    expect(controller.pending['synthetic-debt'], 10);
    expect(controller.failureCode, 'local_write_unknown');
  });

  // Regression: a matching edited key is not sufficient if unrelated state
  // disappears from the accepted acknowledgement. The durable fake record is
  // kept intact here to isolate a false receipt from destructive persistence.
  for (final missing in ['other value', 'other tombstone']) {
    test('missing $missing in ack retains pending', () async {
      final fake = _ScopedFake();
      fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
          values: const {'synthetic-debt': 5, 'other-debt': 17},
          deletedKeys: const {'deleted-item'});
      fake.dropOtherValueFromAck = missing == 'other value';
      fake.dropOtherTombstoneFromAck = missing == 'other tombstone';
      final controller = DebtWorkspaceController(fake);
      await controller.select(a);
      await controller.edit('synthetic-debt', 10);
      expect(fake.snapshots[a]!.values['other-debt'], 17);
      expect(fake.snapshots[a]!.deletedKeys, contains('deleted-item'));
      expect(controller.pending['synthetic-debt'], 10); // Expected safe behavior; unverified.
      expect(controller.failureCode, 'local_write_unknown');
    });
  }

  // Regression: ignoring an older ack for rendering must not acknowledge and
  // discard the pending edit if the newer snapshot disagrees about the value.
  test('older ack cannot clear pending after newer snapshot', () async {
    final fake = _ScopedFake();
    final responseGate = Completer<void>();
    fake.heldResponses[1] = responseGate;
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    final write = controller.edit('synthetic-debt', 10);
    await fake.writeStarted.future;
    await fake.writeCommitted.future;
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
        values: const {'synthetic-debt': 20});
    await controller.refresh();
    responseGate.complete();
    await write;
    expect(controller.visible!.values['synthetic-debt'], 20);
    expect(controller.pending['synthetic-debt'], 10); // Expected safe behavior; unverified.
    expect(controller.failureCode, 'local_write_unknown');
  });

  // Regression: this fake loses an incoming remote tombstone. A receiver must
  // either preserve the tombstone or report the committed result as unknown.
  test('remote tombstone loss is not accepted as restore success', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake)..dropIncomingTombstone = true;
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {}, deletedKeys: const {'remote-deleted'});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(restore.merges, 1);
    // An already committed missing tombstone is not "not applied". Either
    // persisted AND visible state keeps it, or the outcome must be unknown.
    final preserved = fake._current(a).deletedKeys.contains('remote-deleted') &&
        (controller.visible?.deletedKeys.contains('remote-deleted') ?? false);
    final safe = preserved || controller.failureCode == 'restore_unknown';
    expect(safe, isTrue); // Expected safe behavior; unverified.
  });

  test('cooperative fake preserves unconflicted remote tombstone', () async {
    final fake = _ScopedFake();
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {}, deletedKeys: const {'remote-deleted'});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(fake._current(a).deletedKeys, contains('remote-deleted'));
    expect(controller.visible!.deletedKeys, contains('remote-deleted'));
    expect(controller.failureCode, isNull);
  });

  for (final loss in ['other value', 'other tombstone']) {
    test('cooperative fake vetoes corrupt $loss before commit', () async {
      final fake = _ScopedFake();
      fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
          values: const {'synthetic-debt': 5, 'other-debt': 17},
          deletedKeys: const {'deleted-item'});
      fake.dropOtherValueFromStore = loss == 'other value';
      fake.dropOtherTombstoneFromStore = loss == 'other tombstone';
      final controller = DebtWorkspaceController(fake);
      await controller.select(a);
      await controller.edit('synthetic-debt', 10);
      expect(fake._current(a).version, 2);
      expect(fake._current(a).values['synthetic-debt'], 5);
      expect(fake._current(a).values['other-debt'], 17);
      expect(fake._current(a).deletedKeys, contains('deleted-item'));
      expect(controller.pending['synthetic-debt'], 10);
      expect(controller.failureCode, 'local_write_failed');
    });
  }

  for (final loss in ['other value', 'other tombstone']) {
    test('forged good ack after stored $loss is detected by reread', () async {
      final fake = _ScopedFake()
        ..guardCandidateIntegrity = false
        ..forgeAck = true;
      fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
          values: const {'synthetic-debt': 5, 'other-debt': 17},
          deletedKeys: const {'deleted-item'});
      fake.dropOtherValueFromStore = loss == 'other value';
      fake.dropOtherTombstoneFromStore = loss == 'other tombstone';
      final controller = DebtWorkspaceController(fake);
      await controller.select(a);
      await controller.edit('synthetic-debt', 10);
      if (loss == 'other value') {
        expect(fake._current(a).values.containsKey('other-debt'), isFalse);
      } else {
        expect(fake._current(a).deletedKeys.contains('deleted-item'), isFalse);
      }
      // Detection does not undo the already damaged fake storage.
      expect(controller.pending['synthetic-debt'], 10);
      expect(controller.failureCode, 'local_write_unknown');
    });
  }

  test('failed postcommit reread keeps pending as unknown', () async {
    final fake = _ScopedFake()..failReadAfterWrite = true;
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    await controller.edit('synthetic-debt', 10);
    expect(fake._current(a).values['synthetic-debt'], 10);
    expect(controller.pending['synthetic-debt'], 10);
    expect(controller.failureCode, 'local_write_unknown');
  });

  test('remote deletion conflicting with local value is not merged', () async {
    final fake = _ScopedFake();
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 12});
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {}, deletedKeys: const {'synthetic-debt'});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(restore.merges, 0);
    expect(fake._current(a).values['synthetic-debt'], 12);
    expect(controller.failureCode, 'restore_conflict');
  });

  for (final mismatch in ['older version', 'same version different data']) {
    test('prewrite $mismatch refuses commit and keeps pending', () async {
      final fake = _ScopedFake();
      fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 3,
          values: const {'synthetic-debt': 12, 'other-debt': 17});
      final controller = DebtWorkspaceController(fake);
      await controller.select(a);
      fake.forcedRead[a] = ScopedDebtSnapshot(workspace: a,
          version: mismatch == 'older version' ? 2 : 3,
          values: const {'synthetic-debt': 12});
      await controller.edit('synthetic-debt', 10);
      expect(fake.writeCalls, 0);
      expect(fake._current(a).values['other-debt'], 17);
      expect(controller.pending['synthetic-debt'], 10);
      expect(controller.failureCode, 'local_snapshot_changed');
    });
  }

  for (final defect in ['missing remote value', 'unexpected injected value']) {
    test('remote union $defect is not accepted as success', () async {
      final fake = _ScopedFake();
      final restore = _RestoreFake(fake);
      restore.dropIncomingValue = defect == 'missing remote value';
      restore.injectUnexpectedValue = defect == 'unexpected injected value';
      restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
          values: const {'remote-only': 10});
      final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
      await controller.select(a);
      await controller.pullAndRestore(restore);
      expect(restore.merges, 1);
      expect(controller.failureCode, 'restore_unknown');
      expect(controller.visible!.values, isEmpty);
      // Bad fake already committed: detection does not undo storage damage.
      expect(fake._current(a).version, 1);
    });
  }

  for (final day in [0, 32]) {
    test('base day $day refuses write without losing pending', () async {
      final fake = _ScopedFake();
      fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 1,
          values: {'other-debt': day});
      final controller = DebtWorkspaceController(fake);
      await controller.select(a);
      await controller.edit('synthetic-debt', 10);
      expect(fake.writeCalls, 0);
      expect(controller.pending['synthetic-debt'], 10);
      expect(controller.failureCode, 'local_data_invalid');
    });
  }

  for (final day in [0, 32]) {
    test('remote day $day refuses merge', () async {
      final fake = _ScopedFake();
      final restore = _RestoreFake(fake);
      restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
          values: {'remote-only': day});
      final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
      await controller.select(a);
      await controller.pullAndRestore(restore);
      expect(restore.merges, 0);
      expect(fake._current(a).values, isEmpty);
      expect(controller.failureCode, 'restore_invalid_remote');
    });
  }

  test('nonconflicting synthetic union includes both values and tombstones', () async {
    final fake = _ScopedFake();
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 2,
        values: const {'local-only': 12});
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'remote-only': 10}, deletedKeys: const {'remote-deleted'});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(controller.visible!.values, {'local-only': 12, 'remote-only': 10});
    expect(controller.visible!.deletedKeys, contains('remote-deleted'));
    expect(controller.failureCode, isNull);
  });

  test('conflicting remote value refuses merge', () async {
    final fake = _ScopedFake();
    fake.snapshots[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 12});
    final restore = _RestoreFake(fake);
    restore.remote[a] = ScopedDebtSnapshot(workspace: a, version: 1,
        values: const {'synthetic-debt': 10});
    final controller = DebtWorkspaceController(fake, enableSyntheticRestore: true);
    await controller.select(a);
    await controller.pullAndRestore(restore);
    expect(restore.merges, 0);
    expect(fake._current(a).values['synthetic-debt'], 12);
    expect(controller.failureCode, 'restore_conflict');
  });

}
