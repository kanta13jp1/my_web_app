// DRAFT ONLY: not compiled, tested, connected to prefs, or suitable for release.
// No adapter is supplied for SharedPreferences or a real database. The atomic
// guarantee below is a REQUIREMENT on a future backend, not an existing fact.
import 'dart:collection';

class DebtScope {
  const DebtScope._(this.kind, this.id);
  factory DebtScope.owner(String ownerId) {
    if (ownerId.isEmpty) throw ArgumentError('empty owner');
    return DebtScope._('owner', ownerId);
  }
  factory DebtScope.unowned(String workspaceId) {
    if (workspaceId.isEmpty) throw ArgumentError('empty workspace');
    return DebtScope._('unowned', workspaceId);
  }
  final String kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is DebtScope && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

// One consistent snapshot: values, tombstones, dirty revisions and timestamp
// must be encoded and committed together by the adapter. Scope is verified on
// every read to detect a misrouted or malformed envelope.
class DebtEnvelope {
  DebtEnvelope({
    required this.scope,
    required this.version,
    required Map<String, int> values,
    required Map<String, DateTime> tombstones,
    required Map<String, int> dirtyRevisions,
    required this.changedAt,
  })  : values = UnmodifiableMapView(Map<String, int>.from(values)),
        tombstones = UnmodifiableMapView(Map<String, DateTime>.from(tombstones)),
        dirtyRevisions = UnmodifiableMapView(Map<String, int>.from(dirtyRevisions));

  final DebtScope scope;
  final int version;
  final Map<String, int> values;
  final Map<String, DateTime> tombstones;
  final Map<String, int> dirtyRevisions;
  final DateTime? changedAt;
}

enum DebtReadKind { absent, valid, invalid }
class DebtRead {
  const DebtRead._(this.kind, this.envelope);
  const DebtRead.absent() : this._(DebtReadKind.absent, null);
  const DebtRead.invalid() : this._(DebtReadKind.invalid, null);
  const DebtRead.valid(DebtEnvelope value) : this._(DebtReadKind.valid, value);
  final DebtReadKind kind;
  final DebtEnvelope? envelope;
}

enum DebtCommit { committed, conflict, rejected }

abstract class AtomicDebtStore {
  Future<DebtRead> read(DebtScope scope);

  // REQUIRED: linearizable conditional commit per scope; null expectedVersion
  // means create only if absent. Compare and the full envelope write are one
  // durable transaction, with no writes on conflict/rejected. Throwing may mean
  // unknown outcome and must never be silently retried. The real adapter must
  // enforce scope match and preserve malformed records for recovery.
  Future<DebtCommit> compareAndCommit(
    DebtScope scope, int? expectedVersion, DebtEnvelope proposed,
  );
}

class DebtJournalException implements Exception {
  const DebtJournalException(this.code);
  // Codes carry no user identifiers or amounts.
  final String code;
  @override
  String toString() => 'DebtJournalException($code)';
}

class DebtEditReceipt {
  const DebtEditReceipt(this.scope, this.version);
  final DebtScope scope;
  final int version;
}

class DebtOwnerJournal {
  DebtOwnerJournal({
    required this.store,
    required this.scope,
    this.maxConflictAttempts = 3,
  }) {
    if (maxConflictAttempts < 1) throw ArgumentError('invalid attempts');
  }

  final AtomicDebtStore store;
  // Immutable for this journal's entire life: no closure reads a current-owner
  // global. A UI must construct a different journal when switching owner.
  final DebtScope scope;
  final int maxConflictAttempts;
  Future<void> _tail = Future<void>.value();
  bool _outcomeUnknown = false;

  Future<DebtEnvelope?> load() async {
    final result = await store.read(scope);
    if (result.kind == DebtReadKind.invalid) {
      throw const DebtJournalException('invalid_envelope');
    }
    if (result.kind == DebtReadKind.absent) return null;
    final item = result.envelope;
    if (item == null || item.scope != scope || item.version < 1) {
      throw const DebtJournalException('invalid_envelope');
    }
    if (item.values.entries.any((entry) => entry.key.isEmpty ||
            entry.value < 1 || entry.value > 31 ||
            item.tombstones.containsKey(entry.key)) ||
        item.tombstones.keys.any((key) => key.isEmpty) ||
        item.dirtyRevisions.entries.any((entry) => entry.key.isEmpty ||
            entry.value < 1 || entry.value > item.version ||
            (!item.values.containsKey(entry.key) &&
                !item.tombstones.containsKey(entry.key)))) {
      throw const DebtJournalException('invalid_envelope');
    }
    return item;
  }

  Future<DebtEditReceipt> setDay({
    required String key,
    required int? day,
    required DateTime editedAt,
    // This permits a new empty owner/unowned namespace; it does not authorize
    // legacy import or delete any legacy keys. Callers must preserve legacy.
    bool allowNewWorkspace = false,
  }) {
    final run = _tail.then((_) => _setDay(
      key: key, day: day, editedAt: editedAt,
      allowNewWorkspace: allowNewWorkspace,
    ));
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return run;
  }

  Future<DebtEditReceipt> _setDay({
    required String key,
    required int? day,
    required DateTime editedAt,
    required bool allowNewWorkspace,
  }) async {
    if (_outcomeUnknown) throw const DebtJournalException('outcome_unknown');
    if (key.isEmpty || (day != null && (day < 1 || day > 31))) {
      throw const DebtJournalException('invalid_edit');
    }
    final time = editedAt.toUtc();
    for (var attempt = 0; attempt < maxConflictAttempts; attempt++) {
      final old = await load();
      if (old == null && !allowNewWorkspace) {
        throw const DebtJournalException('workspace_not_initialized');
      }
      final nextVersion = (old?.version ?? 0) + 1;
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
      dirty[key] = nextVersion;
      final previousTime = old?.changedAt;
      final updatedAt = previousTime != null && previousTime.isAfter(time)
          ? previousTime : time;
      final next = DebtEnvelope(
        scope: scope, version: nextVersion, values: values,
        tombstones: deleted, dirtyRevisions: dirty, changedAt: updatedAt,
      );
      // A thrown exception may mean an unknown commit outcome. Do not retry
      // or allow later writes through this instance without reconciliation.
      final DebtCommit outcome;
      try {
        outcome = await store.compareAndCommit(scope, old?.version, next);
      } catch (_) {
        _outcomeUnknown = true;
        rethrow;
      }
      if (outcome == DebtCommit.committed) {
        return DebtEditReceipt(scope, nextVersion);
      }
      if (outcome == DebtCommit.rejected) {
        throw const DebtJournalException('write_rejected');
      }
      // Only an explicit transaction conflict can be retried.
    }
    throw const DebtJournalException('conflict_limit');
  }
}
