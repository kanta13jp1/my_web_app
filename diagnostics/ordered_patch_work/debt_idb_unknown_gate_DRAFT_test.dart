// SYNTHETIC FIXTURE ONLY. Not run; no browser, IDB, user data or production.
import 'package:flutter_test/flutter_test.dart';
import 'debt_idb_unknown_gate_DRAFT.dart';

class _Record {
  int fence = 0;
  int version = 0;
  ProbeMarker? marker;
  bool freshProof = false;
  Map<String, int> values = {};
  Set<String> tombstones = {};
  Map<String, int> dirty = {};
  final Set<String> usedIds = {};
}

bool _same(ProbePayload a, ProbePayload b) =>
    a.owner == b.owner && a.id == b.id && a.baseVersion == b.baseVersion &&
    a.generation == b.generation &&
    a.values.length == b.values.length && a.values.keys.every((k) => a.values[k] == b.values[k]) &&
    a.tombstones.length == b.tombstones.length && a.tombstones.containsAll(b.tombstones) &&
    a.dirty.length == b.dirty.length && a.dirty.keys.every((k) => a.dirty[k] == b.dirty[k]);

class _FakeFencedJournal implements SyntheticFencedJournal {
  final records = <String, _Record>{};
  bool loseAfterPrepare = false;
  bool loseAfterCommit = false;
  bool loseAfterAck = false;
  bool delayBeforePrepare = false;
  bool delayBeforeCommit = false;
  bool failFence = false;
  ProbePayload? delayedCommit;
  int? delayedCommitFence;
  ProbePayload? delayed;
  int? delayedFence;
  int prepareCalls = 0;
  int commitCalls = 0;

  _Record rec(String owner) => records.putIfAbsent(owner, _Record.new);
  void seedFresh(String owner) { rec(owner).freshProof = true; }

  @override
  Future<ProbeView> settleFenceAndRead(String owner) async {
    if (failFence) {
      failFence = false;
      throw const ProbeError('synthetic_fence_unknown');
    }
    final r = rec(owner);
    r.fence++; // Fake atomic fence; real asynchronous IDB is not implemented.
    return ProbeView(owner: owner, fence: r.fence, version: r.version,
      marker: r.marker, freshProof: r.freshProof,
      values: Map.of(r.values), tombstones: Set.of(r.tombstones), dirty: Map.of(r.dirty));
  }

  @override
  Future<bool> prepare(String owner, int fence, ProbePayload p) async {
    prepareCalls++;
    final r = rec(owner);
    // The fake remembers an attempted prepare. A real crash before a durable
    // marker exists cannot establish this bit; absent record is not proof.
    r.freshProof = false;
    if (delayBeforePrepare) {
      delayBeforePrepare = false;
      delayed = p;
      delayedFence = fence;
      throw const ProbeError('synthetic_prepare_unknown');
    }
    if (r.fence != fence || p.owner != owner || r.version != p.baseVersion ||
        r.usedIds.contains(p.id) ||
        (r.marker != null && r.marker!.phase != ProbePhase.acknowledged)) return false;
    r.usedIds.add(p.id);
    r.marker = ProbeMarker(p, ProbePhase.prepared);
    if (loseAfterPrepare) {
      loseAfterPrepare = false;
      throw const ProbeError('synthetic_prepare_response_unknown');
    }
    return true;
  }

  bool releaseDelayedPrepare() {
    final p = delayed;
    if (p == null) return false;
    final r = rec(p.owner);
    delayed = null;
    if (r.fence != delayedFence) return false;
    r.usedIds.add(p.id);
    r.marker = ProbeMarker(p, ProbePhase.prepared);
    return true;
  }

  @override
  Future<bool> commit(String owner, int fence, ProbePayload p) async {
    commitCalls++;
    final r = rec(owner);
    if (delayBeforeCommit) {
      delayBeforeCommit = false;
      delayedCommit = p;
      delayedCommitFence = fence;
      throw const ProbeError('synthetic_commit_unknown');
    }
    final marker = r.marker;
    if (r.fence != fence || marker == null || marker.phase != ProbePhase.prepared ||
        !_same(marker.payload, p) || r.version != p.baseVersion) return false;
    r.values = Map.of(p.values);
    r.tombstones = Set.of(p.tombstones);
    r.dirty = Map.of(p.dirty);
    r.version++;
    r.marker = ProbeMarker(p, ProbePhase.committed);
    if (loseAfterCommit) {
      loseAfterCommit = false;
      throw const ProbeError('synthetic_commit_response_unknown');
    }
    return true;
  }

  bool releaseDelayedCommit() {
    final p = delayedCommit;
    if (p == null) return false;
    final r = rec(p.owner);
    delayedCommit = null;
    if (r.fence != delayedCommitFence || r.marker?.phase != ProbePhase.prepared) return false;
    r.values = Map.of(p.values);
    r.tombstones = Set.of(p.tombstones);
    r.dirty = Map.of(p.dirty);
    r.version++;
    r.marker = ProbeMarker(p, ProbePhase.committed);
    return true;
  }

  @override
  Future<bool> acknowledgeObserved(String owner, int fence, ProbePayload p) async {
    final r = rec(owner);
    final marker = r.marker;
    if (r.fence != fence || marker == null ||
        (marker.phase != ProbePhase.committed && marker.phase != ProbePhase.acknowledged) ||
        !_same(marker.payload, p) || r.version != p.baseVersion + 1 ||
        r.values.length != p.values.length ||
        !r.values.keys.every((k) => r.values[k] == p.values[k]) ||
        r.tombstones.length != p.tombstones.length || !r.tombstones.containsAll(p.tombstones) ||
        r.dirty.length != p.dirty.length || !r.dirty.keys.every((k) => r.dirty[k] == p.dirty[k])) {
      return false;
    }
    r.marker = ProbeMarker(p, ProbePhase.acknowledged); // domain dirty stays.
    if (loseAfterAck) {
      loseAfterAck = false;
      throw const ProbeError('synthetic_ack_response_unknown');
    }
    return true;
  }
}

ProbePayload _edit(String owner, String id, {int base = 0, int day = 10, int generation = 1}) =>
    ProbePayload(owner: owner, id: id, baseVersion: base, generation: generation,
        values: {'synthetic-p': day}, tombstones: const {'synthetic-r'},
        dirty: {'synthetic-p': generation, 'synthetic-r': generation});

void main() {
  const a = 'synthetic-owner-A';
  const b = 'synthetic-owner-B';

  test('commit response unknown blocks A through recreation until reconciliation', () async {
    final store = _FakeFencedJournal()..seedFresh(a)..loseAfterCommit = true;
    final p = _edit(a, 'synthetic-op-A');
    final gate = UnknownGateDraft(store, a);
    expect(await gate.inspect(), ProbeStatus.ready);
    await expectLater(gate.submit(p), throwsA(isA<ProbeError>()));
    await expectLater(gate.submit(_edit(a, 'synthetic-op-next')), throwsA(isA<ProbeError>()));
    final reopened = UnknownGateDraft(store, a);
    expect(await reopened.inspect(), ProbeStatus.committed);
    await expectLater(reopened.submit(_edit(a, 'synthetic-op-next')), throwsA(isA<ProbeError>()));
    await reopened.reconcileCommitted(p);
    expect(store.rec(a).dirty['synthetic-p'], 1);
    expect(store.rec(a).dirty['synthetic-r'], 1);
    expect(await reopened.inspect(), ProbeStatus.acknowledged);
  });

  test('prepared response unknown survives recreation without retry', () async {
    final store = _FakeFencedJournal()..seedFresh(a)..loseAfterPrepare = true;
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await expectLater(gate.submit(_edit(a, 'synthetic-op-A')), throwsA(isA<ProbeError>()));
    final reopened = UnknownGateDraft(store, a);
    expect(await reopened.inspect(), ProbeStatus.prepared);
    await expectLater(reopened.submit(_edit(a, 'synthetic-op-next')), throwsA(isA<ProbeError>()));
    expect(store.commitCalls, 0);
  });

  test('late prepare is fenced and absence without genesis proof stays blocked', () async {
    final store = _FakeFencedJournal()..seedFresh(a)..delayBeforePrepare = true;
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await expectLater(gate.submit(_edit(a, 'synthetic-op-A')), throwsA(isA<ProbeError>()));
    final reopened = UnknownGateDraft(store, a);
    expect(await reopened.inspect(), ProbeStatus.ambiguous);
    expect(store.releaseDelayedPrepare(), isFalse);
    await expectLater(reopened.submit(_edit(a, 'synthetic-op-next')), throwsA(isA<ProbeError>()));
  });

  test('ack response unknown is reconciled only after fenced exact observation', () async {
    final store = _FakeFencedJournal()..seedFresh(a)..loseAfterAck = true;
    final p = _edit(a, 'synthetic-op-A');
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await gate.submit(p);
    expect(await gate.inspect(), ProbeStatus.committed);
    await expectLater(gate.reconcileCommitted(p), throwsA(isA<ProbeError>()));
    final reopened = UnknownGateDraft(store, a);
    expect(await reopened.inspect(), ProbeStatus.acknowledged);
    await reopened.reconcileCommitted(p);
    expect(store.rec(a).dirty['synthetic-p'], 1);
    await reopened.submit(_edit(a, 'synthetic-op-next', base: 1, day: 12, generation: 2));
    expect(store.rec(a).values['synthetic-p'], 12);
  });

  test('same ID with changed payload cannot reconcile or unblock', () async {
    final store = _FakeFencedJournal()..seedFresh(a);
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await gate.submit(_edit(a, 'synthetic-op-A'));
    await gate.inspect();
    await expectLater(gate.reconcileCommitted(_edit(a, 'synthetic-op-A', day: 11)),
        throwsA(isA<ProbeError>()));
    await expectLater(gate.submit(_edit(a, 'synthetic-op-next')), throwsA(isA<ProbeError>()));
  });

  test('owner B cannot acknowledge A and can proceed in its own fresh scope', () async {
    final store = _FakeFencedJournal()..seedFresh(a)..seedFresh(b)..loseAfterCommit = true;
    final gateA = UnknownGateDraft(store, a);
    await gateA.inspect();
    await expectLater(gateA.submit(_edit(a, 'synthetic-op-A')), throwsA(isA<ProbeError>()));
    final gateB = UnknownGateDraft(store, b);
    expect(await gateB.inspect(), ProbeStatus.ready);
    await expectLater(gateB.reconcileCommitted(_edit(a, 'synthetic-op-A')), throwsA(isA<ProbeError>()));
    await gateB.submit(_edit(b, 'synthetic-op-B', day: 20));
    expect(store.rec(a).values['synthetic-p'], 10);
    expect(store.rec(b).values['synthetic-p'], 20);
  });

  test('operation ID is not reusable after acknowledgement', () async {
    final store = _FakeFencedJournal()..seedFresh(a);
    final p = _edit(a, 'synthetic-op-A');
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await gate.submit(p);
    await gate.inspect();
    await gate.reconcileCommitted(p);
    await expectLater(gate.submit(_edit(a, 'synthetic-op-A', base: 1, day: 12, generation: 2)),
        throwsA(isA<ProbeError>()));
    expect(store.rec(a).values['synthetic-p'], 10);
  });
  test('late commit after new fake fence is rejected; prepared remains', () async {
    final store = _FakeFencedJournal()..seedFresh(a)..delayBeforeCommit = true;
    final p = _edit(a, 'synthetic-op-A');
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await expectLater(gate.submit(p), throwsA(isA<ProbeError>()));
    final reopened = UnknownGateDraft(store, a);
    expect(await reopened.inspect(), ProbeStatus.prepared);
    expect(store.releaseDelayedCommit(), isFalse);
    expect(store.rec(a).values, isEmpty);
    expect(store.rec(a).marker!.phase, ProbePhase.prepared);
  });

  test('failed new fence inspection cannot use earlier view to acknowledge', () async {
    final store = _FakeFencedJournal()..seedFresh(a);
    final p = _edit(a, 'synthetic-op-A');
    final gate = UnknownGateDraft(store, a);
    await gate.inspect();
    await gate.submit(p);
    expect(await gate.inspect(), ProbeStatus.committed);
    store.failFence = true;
    await expectLater(gate.inspect(), throwsA(isA<ProbeError>()));
    await expectLater(gate.reconcileCommitted(p), throwsA(isA<ProbeError>()));
    expect(store.rec(a).marker!.phase, ProbePhase.committed);
  });

  test('fresh proof on nonempty scope does not enable writes', () async {
    final store = _FakeFencedJournal()..seedFresh(a);
    store.rec(a).version = 1;
    store.rec(a).values['synthetic-p'] = 10;
    final gate = UnknownGateDraft(store, a);
    expect(await gate.inspect(), ProbeStatus.ambiguous);
    await expectLater(gate.submit(_edit(a, 'synthetic-op-A')), throwsA(isA<ProbeError>()));
    expect(store.prepareCalls, 0);
  });

}