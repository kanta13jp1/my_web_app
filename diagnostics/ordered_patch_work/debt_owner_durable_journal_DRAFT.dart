// DRAFT ONLY: not compiled/tested or connected to a real backend.
// A real atomic & durable adapter is not supplied. Legacy data is never read,
// assigned to an owner, migrated, deleted, or sent by this code.
import 'debt_owner_atomic_journal_DRAFT.dart';

enum DurablePhase { prepared, committed, acknowledged }
enum DurableMutation { applied, conflict, rejected, fenced }

class DurableOperation {
  const DurableOperation({
    required this.id,
    required this.baseVersion,
    required this.proposed,
    required this.phase,
  });
  final String id;
  final int? baseVersion;
  final DebtEnvelope proposed;
  final DurablePhase phase;
}

class DurableSnapshot {
  const DurableSnapshot({
    required this.read,
    required this.latestOperation,
  });
  final DebtRead read;
  // A prepared/committed record is unresolved even across service recreation.
  // Acknowledged records remain durable until safe compaction.
  final DurableOperation? latestOperation;
}

abstract class DurableAtomicDebtStore {
  // All operations below MUST be durably committed and linearizable per scope.
  // acquireFence atomically increments an owner-scoped persistent fence. Every
  // mutation checks its supplied fence IN THE SAME transaction; an operation
  // from an older instance must never commit after a new fence was acquired.
  // Throwing or an untrusted/partial adapter is not proof of these guarantees.
  Future<int> acquireFence(DebtScope scope);
  Future<DurableSnapshot> readSnapshot(DebtScope scope, int fence);

  // Conditional, atomic: expected version matches, no unresolved operation,
  // id has never been used for this scope; persist full proposed envelope as
  // a PREPARED record before returning applied. No legacy key is modified.
  Future<DurableMutation> prepare(
      DebtScope scope, int fence, int? expectedVersion, DurableOperation op);

  // One transaction: matching PREPARED op + expected version -> new complete
  // envelope AND COMMITTED marker. The marker is not automatically removed.
  Future<DurableMutation> commitPrepared(DebtScope scope, int fence, String id);

  // Conditional on exact op, COMMITTED state and exact envelope version.
  // Atomically marks ACKNOWLEDGED; retained journal permits later inspection.
  Future<DurableMutation> acknowledgeCommitted(
      DebtScope scope, int fence, String id, int envelopeVersion);
}

class DurableReceipt {
  const DurableReceipt(this.scope, this.operationId, this.version);
  final DebtScope scope;
  final String operationId;
  final int version;
}

class DurableDebtJournal {
  DurableDebtJournal._(this.store, this.scope, this.fence, this.newOperationId);

  // A new service instance obtains a new durable fence before it can mutate.
  // A failed/unknown fence acquisition produces no journal object.
  static Future<DurableDebtJournal> open({
    required DurableAtomicDebtStore store,
    required DebtScope scope,
    required String Function() newOperationId,
  }) async {
    final fence = await store.acquireFence(scope);
    if (fence < 1) throw const DebtJournalException('invalid_fence');
    return DurableDebtJournal._(store, scope, fence, newOperationId);
  }

  final DurableAtomicDebtStore store;
  final DebtScope scope;
  final int fence;
  final String Function() newOperationId;
  Future<void> _tail = Future<void>.value();
  bool _outcomeUnknown = false;

  DebtEnvelope? _envelope(DurableSnapshot state) {
    if (state.read.kind == DebtReadKind.invalid) {
      throw const DebtJournalException('invalid_envelope');
    }
    if (state.read.kind == DebtReadKind.absent) return null;
    final value = state.read.envelope;
    if (value == null || value.scope != scope || value.version < 1 ||
        value.values.entries.any((entry) => entry.key.isEmpty ||
            entry.value < 1 || entry.value > 31 ||
            value.tombstones.containsKey(entry.key)) ||
        value.tombstones.keys.any((key) => key.isEmpty) ||
        value.dirtyRevisions.entries.any((entry) => entry.key.isEmpty ||
            entry.value < 1 || entry.value > value.version ||
            (!value.values.containsKey(entry.key) &&
                !value.tombstones.containsKey(entry.key)))) {
      throw const DebtJournalException('invalid_envelope');
    }
    return value;
  }

  Future<DurableReceipt> setDay({
    required String key,
    required int? day,
    required DateTime editedAt,
    bool allowNewWorkspace = false,
  }) {
    final run = _tail.then((_) => _setDay(
      key: key, day: day, editedAt: editedAt,
      allowNewWorkspace: allowNewWorkspace,
    ));
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return run;
  }

  Future<DurableReceipt> _setDay({
    required String key,
    required int? day,
    required DateTime editedAt,
    required bool allowNewWorkspace,
  }) async {
    if (_outcomeUnknown) throw const DebtJournalException('outcome_unknown');
    if (key.isEmpty || (day != null && (day < 1 || day > 31))) {
      throw const DebtJournalException('invalid_edit');
    }
    final state = await store.readSnapshot(scope, fence);
    final old = _envelope(state);
    final last = state.latestOperation;
    if (last != null) _checkOperation(last, old);
    if (last != null && last.phase != DurablePhase.acknowledged) {
      throw const DebtJournalException('reconciliation_required');
    }
    if (old == null && !allowNewWorkspace) {
      throw const DebtJournalException('workspace_not_initialized');
    }
    final version = (old?.version ?? 0) + 1;
    final time = editedAt.toUtc();
    final values = Map<String, int>.from(old?.values ?? <String, int>{});
    final deleted = Map<String, DateTime>.from(old?.tombstones ?? <String, DateTime>{});
    final dirty = Map<String, int>.from(old?.dirtyRevisions ?? <String, int>{});
    if (day == null) {
      values.remove(key);
      deleted[key] = time;
    } else {
      values[key] = day;
      deleted.remove(key);
    }
    dirty[key] = version;
    final previousTime = old?.changedAt;
    final proposed = DebtEnvelope(
      scope: scope, version: version, values: values, tombstones: deleted,
      dirtyRevisions: dirty,
      changedAt: previousTime != null && previousTime.isAfter(time)
          ? previousTime : time,
    );
    final id = newOperationId();
    if (id.isEmpty) throw const DebtJournalException('invalid_operation_id');
    final op = DurableOperation(
      id: id, baseVersion: old?.version, proposed: proposed,
      phase: DurablePhase.prepared,
    );
    // The storage adapter must reject reused IDs durably. No retry after any
    // thrown exception: it may have committed a stage or a final envelope.
    final DurableMutation staged;
    try {
      staged = await store.prepare(scope, fence, old?.version, op);
    } catch (_) {
      _outcomeUnknown = true;
      rethrow;
    }
    if (staged != DurableMutation.applied) {
      throw DebtJournalException('prepare_${staged.name}');
    }
    final DurableMutation committed;
    try {
      committed = await store.commitPrepared(scope, fence, id);
    } catch (_) {
      _outcomeUnknown = true;
      rethrow;
    }
    if (committed != DurableMutation.applied) {
      // PREPARED remains durable. No success and no automatic retry.
      throw DebtJournalException('commit_${committed.name}');
    }
    // The COMMITTED record remains for explicit observation/acknowledgement.
    return DurableReceipt(scope, id, version);
  }

  void _checkOperation(DurableOperation op, DebtEnvelope? current) {
    if (op.id.isEmpty || op.proposed.scope != scope ||
        op.proposed.version != (op.baseVersion ?? 0) + 1) {
      throw const DebtJournalException('invalid_operation');
    }
    if (op.phase == DurablePhase.prepared) {
      if (current?.version != op.baseVersion) {
        throw const DebtJournalException('invalid_operation');
      }
      return;
    }
    if (current == null || current.version != op.proposed.version ||
        !_sameMap(current.values, op.proposed.values) ||
        !_sameMap(current.tombstones, op.proposed.tombstones) ||
        !_sameMap(current.dirtyRevisions, op.proposed.dirtyRevisions) ||
        current.changedAt != op.proposed.changedAt) {
      throw const DebtJournalException('invalid_operation');
    }
  }

  // A new fenced instance can inspect the durable record, including an
  // ACKNOWLEDGED record after a response was lost. Never log its contents.
  Future<DurableOperation?> inspectLatest() async {
    if (_outcomeUnknown) {
      throw const DebtJournalException('reopen_with_new_fence');
    }
    final state = await store.readSnapshot(scope, fence);
    final current = _envelope(state);
    final op = state.latestOperation;
    if (op != null) _checkOperation(op, current);
    return op;
  }

  // PREPARED is intentionally not replayed or discarded by this prototype.
  Future<DurableOperation?> inspectUnresolved() async {
    final op = await inspectLatest();
    return op?.phase == DurablePhase.acknowledged ? null : op;
  }

  // Called after a successful save or explicit recovery inspection. It is not
  // a remote-sync ack and never clears dirty keys or legacy data.
  Future<void> acknowledgeObserved(DurableReceipt receipt) async {
    if (_outcomeUnknown) {
      throw const DebtJournalException('reopen_with_new_fence');
    }
    if (receipt.scope != scope || receipt.operationId.isEmpty) {
      throw const DebtJournalException('receipt_scope_mismatch');
    }
    final state = await store.readSnapshot(scope, fence);
    final value = _envelope(state);
    final op = state.latestOperation;
    if (op == null || op.id != receipt.operationId ||
        op.phase != DurablePhase.committed ||
        value == null || value.version != receipt.version ||
        op.proposed.scope != scope || op.proposed.version != value.version ||
        !_sameMap(op.proposed.values, value.values) ||
        !_sameMap(op.proposed.tombstones, value.tombstones) ||
        !_sameMap(op.proposed.dirtyRevisions, value.dirtyRevisions) ||
        op.proposed.changedAt != value.changedAt) {
      throw const DebtJournalException('receipt_not_confirmed');
    }
    final DurableMutation result;
    try {
      result = await store.acknowledgeCommitted(
          scope, fence, receipt.operationId, receipt.version);
    } catch (_) {
      _outcomeUnknown = true;
      rethrow;
    }
    if (result != DurableMutation.applied) {
      throw DebtJournalException('ack_${result.name}');
    }
  }
}

bool _sameMap<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
