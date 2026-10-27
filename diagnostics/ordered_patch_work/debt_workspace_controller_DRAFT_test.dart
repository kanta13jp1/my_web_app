// SYNTHETIC DRAFT ONLY: not compiled or run. In-memory fixtures are not an
// IndexedDB adapter, browser persistence test, or product-page integration.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'debt_workspace_controller_DRAFT.dart';
import 'debt_legacy_review_widget_DRAFT.dart';

class _ScopedFake implements ScopedDebtLocal {
  final snapshots = <DebtWorkspace, ScopedDebtSnapshot>{};
  final heldReads = <DebtWorkspace, Completer<void>>{};
  final heldWrites = <DebtWorkspace, Completer<void>>{};
  final heldResponses = <int, Completer<void>>{};
  final wrongRead = <DebtWorkspace, DebtWorkspace>{};
  final legacyRaw = <String, String>{
    'values': 'synthetic-values', 'deleted': 'synthetic-deleted',
    'dirty': 'synthetic-dirty', 'timestamp': 'synthetic-time',
  };
  bool rejectNext = false;
  bool failNextRead = false;
  bool throwAfterCommit = false;
  int writeCalls = 0;
  int fence = 0;
  final activationGates = <DebtWorkspace, Completer<void>>{};
  final activationStarted = Completer<void>();
  bool invalidAckValue = false;
  bool invalidAckVersion = false;
  bool invalidAckIntent = false;
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
    final captured = _current(wrong ?? workspace);
    final gate = heldReads.remove(workspace);
    if (gate != null) await gate.future;
    return captured;
  }

  @override
  Future<ScopedEditResult> writeEdit(
      DebtWorkspace workspace, String key, int? day, int capturedFence, int expectedVersion, int intent) async {
    final number = ++writeCalls;
    final gate = heldWrites.remove(workspace);
    if (gate != null) await gate.future;
    if (rejectNext) {
      rejectNext = false;
      return const ScopedEditResult(committed: false);
    }
    final old = _current(workspace);
    if (active != workspace || fence != capturedFence || old.version != expectedVersion) {
      return const ScopedEditResult(committed: false);
    }
    final values = Map<String, int>.from(old.values);
    final deleted = Set<String>.from(old.deletedKeys);
    if (day == null) { values.remove(key); deleted.add(key); }
    else { values[key] = day; deleted.remove(key); }
    final next = ScopedDebtSnapshot(workspace: workspace,
        version: old.version + 1, values: values, deletedKeys: deleted);
    snapshots[workspace] = next;
    if (throwAfterCommit) {
      throwAfterCommit = false;
      throw StateError('synthetic lost response');
    }
    final responseGate = heldResponses.remove(number);
    if (responseGate != null) await responseGate.future;
    final ack = ScopedDebtSnapshot(workspace: workspace,
        version: invalidAckVersion ? old.version : next.version,
        values: invalidAckValue ? const {'synthetic-debt': 31} : next.values,
        deletedKeys: next.deletedKeys);
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
  final mergeStarted = Completer<void>();
  int merges = 0;
  bool throwAfterMerge = false;
  bool dropExistingValue = false;
  bool dropExistingTombstone = false;

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
      int fence, int expectedVersion, ScopedDebtSnapshot incoming) async {
    merges++;
    if (!mergeStarted.isCompleted) mergeStarted.complete();
    final gate = mergeGate;
    mergeGate = null;
    if (gate != null) await gate.future;
    final current = local._current(workspace);
    if (current.version != expectedVersion || incoming.workspace != workspace || local.active != workspace || local.fence != fence) {
      return const ScopedEditResult(committed: false);
    }
    // Synthetic union only. Real storage must additionally protect dirty keys,
    // tombstones, owner epoch and old-version concurrent tabs in a transaction.
    final merged = <String, int>{...incoming.values, ...current.values};
    final deleted = Set<String>.from(current.deletedKeys);
    for (final key in deleted) { merged.remove(key); }
    if (dropExistingValue && current.values.isNotEmpty) merged.remove(current.values.keys.first);
    if (dropExistingTombstone && deleted.isNotEmpty) deleted.remove(deleted.first);
    final snapshot = ScopedDebtSnapshot(workspace: workspace,
        version: current.version + 1, values: merged, deletedKeys: deleted);
    local.snapshots[workspace] = snapshot;
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
    await Future<void>.delayed(Duration.zero);
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
    await Future<void>.delayed(Duration.zero);
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
    await Future<void>.delayed(Duration.zero);
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
    await Future<void>.delayed(Duration.zero);
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
    await Future<void>.delayed(Duration.zero);
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

  // KNOWN RED: test-only opt-in is deliberately unsafe before new fence
  // commits. Production restore must stay disabled; never suppress this test.
  test('KNOWN RED: notification should stop old merge before fence commits', () async {
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
    expect(afterOldMerge, isEmpty); // Expected RED: A was committed.
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

  // KNOWN RED: the controller cannot revoke an already submitted local write
  // synchronously before the new owner fence commits. Not a production test.
  test('KNOWN RED: owner notification should revoke an old in-flight write', () async {
    final fake = _ScopedFake();
    final writeGate = Completer<void>();
    fake.heldWrites[a] = writeGate;
    final controller = DebtWorkspaceController(fake);
    await controller.select(a);
    final oldWrite = controller.edit('synthetic-debt', 10);
    await Future<void>.delayed(Duration.zero);
    final activationGate = Completer<void>();
    fake.activationGates[b] = activationGate;
    final switching = controller.select(b);
    await Future<void>.delayed(Duration.zero);
    writeGate.complete();
    await oldWrite;
    final afterOldWrite = Map<String, int>.from(fake._current(a).values);
    activationGate.complete();
    await switching;
    expect(afterOldWrite, isEmpty); // Expected RED: A write already committed.
  });

}
