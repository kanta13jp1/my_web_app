// Synthetic design tests only. Not executed. No real backend or UI connection.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'debt_workspace_controller_DRAFT.dart';
import 'debt_legacy_guard_DRAFT.dart';

class _GuardFake implements LegacyCopyBackendDraft {
  DebtWorkspace owner = DebtWorkspace.account('synthetic-A');
  int fence = 1;
  String digest = 'synthetic-original-1';
  int revision = 0;
  int writes = 0;
  final used = <String>{};
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<LegacyCopyOutcomeDraft> applyIfCurrent(LegacyConfirmationDraft t) async {
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    // This is a synchronous fake critical section, not a storage transaction.
    if (t.destination != owner || t.fence != fence || t.legacyDigest != digest ||
        t.destinationVersion != revision) return LegacyCopyOutcomeDraft.changed;
    if (!used.add(t.operationId)) return LegacyCopyOutcomeDraft.duplicate;
    writes++;
    revision++;
    return LegacyCopyOutcomeDraft.copied;
  }
}

void main() {
  LegacyConfirmationDraft token() => LegacyConfirmationDraft(
    destination: DebtWorkspace.account('synthetic-A'), fence: 1,
    legacyDigest: 'synthetic-original-1', destinationVersion: 0,
    operationId: 'synthetic-operation');
  test('legacy changed while confirmation open is rejected', () async {
    final backend = _GuardFake()..digest = 'synthetic-original-2';
    expect(await LegacyGuardDraft(backend).confirm(token()), LegacyCopyOutcomeDraft.changed);
    expect(backend.writes, 0);
  });
  test('owner or fence changed before commit is rejected', () async {
    final backend = _GuardFake()..gate = Completer<void>();
    final pending = LegacyGuardDraft(backend).confirm(token());
    await backend.started.future;
    backend.owner = DebtWorkspace.account('synthetic-B');
    backend.fence++;
    backend.gate!.complete();
    expect(await pending, LegacyCopyOutcomeDraft.changed);
    expect(backend.writes, 0);
  });
  test('double confirmation allows one write', () async {
    final backend = _GuardFake()..gate = Completer<void>();
    final guard = LegacyGuardDraft(backend);
    final first = guard.confirm(token());
    await backend.started.future;
    expect(await guard.confirm(token()), LegacyCopyOutcomeDraft.duplicate);
    backend.gate!.complete();
    expect(await first, LegacyCopyOutcomeDraft.copied);
    expect(await guard.confirm(token()), LegacyCopyOutcomeDraft.duplicate);
    expect(backend.writes, 1);
  });
  test('same owner with a new fence rejects old confirmation', () async {
    final backend = _GuardFake()..fence = 2;
    expect(await LegacyGuardDraft(backend).confirm(token()), LegacyCopyOutcomeDraft.changed);
    expect(backend.writes, 0);
  });
  test('destination changed before confirmation rejects copy', () async {
    final backend = _GuardFake()..revision = 1;
    expect(await LegacyGuardDraft(backend).confirm(token()), LegacyCopyOutcomeDraft.changed);
    expect(backend.writes, 0);
  });

}