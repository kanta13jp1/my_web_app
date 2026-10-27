// WEB DRAFT ONLY. Not compiled, tested, deployed, or connected to real data.
// Construct only with an explicitly opened, isolated synthetic test database.
// No production DB opening, legacy access, migration, deletion or network I/O.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'debt_owner_atomic_journal_DRAFT.dart';
import 'debt_owner_durable_journal_DRAFT.dart';

const _maxSafeInteger = 9007199254740991;
const _syntheticOnly = bool.fromEnvironment('DEBT_IDB_ISOLATED_TEST');

// Test-only fault switches: remove the hooks before any production review.
class IndexedDbSyntheticFaults {
  final Set<String> abortAfterPut = <String>{};
  final Set<String> loseCompletion = <String>{};
}

class _Stored {
  _Stored({required this.fence, required this.envelope, required this.operation,
    required this.usedIds});
  int fence;
  DebtEnvelope? envelope;
  DurableOperation? operation;
  final Set<String> usedIds;
}

class _Decision<T> {
  const _Decision(this.value, {this.write});
  final T value;
  final _Stored? write;
}

class IndexedDbDebtStoreDraft implements DurableAtomicDebtStore {
  IndexedDbDebtStoreDraft({
    required this.database,
    required this.objectStoreName,
    this.syntheticFaults,
  }) {
    final host = Uri.base.host;
    if (!_syntheticOnly || (host != '127.0.0.1' && host != 'localhost')) {
      throw StateError('Requires an explicit isolated synthetic local origin');
    }
  }

  final web.IDBDatabase database;
  final String objectStoreName;
  final IndexedDbSyntheticFaults? syntheticFaults;

  // No current-auth global is consulted: scope is explicit for every call.
  String _key(DebtScope scope) => jsonEncode(<String>[scope.kind, scope.id]);

  // All decisions and IndexedDB requests below are synchronous inside the
  // request success callback. No network/digest/arbitrary Future occurs inside
  // a transaction; the Future resolves only when transaction oncomplete fires.
  Future<T> _transaction<T>(DebtScope scope, {
    required bool write,
    required String operation,
    required _Decision<T> Function(_Stored? record) decide,
  }) {
    final done = Completer<T>();
    web.IDBTransaction tx;
    try {
      tx = write
          ? database.transaction(objectStoreName.toJS, 'readwrite',
              web.IDBTransactionOptions(durability: 'strict'))
          : database.transaction(objectStoreName.toJS, 'readonly');
      if (write && tx.durability != 'strict') {
        tx.abort();
        throw const DebtJournalException('strict_durability_unavailable');
      }
    } catch (_) {
      return Future<T>.error(const DebtJournalException('idb_transaction_unavailable'));
    }
    Object? actionError;
    StackTrace? actionStack;
    T? result;
    var hasResult = false;
    void abortWith(Object error, StackTrace stack) {
      actionError ??= error;
      actionStack ??= stack;
      try { tx.abort(); } catch (_) { /* transaction may already have aborted */ }
    }
    tx.onabort = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(actionError ?? const DebtJournalException('idb_aborted'),
            actionStack ?? StackTrace.current);
      }
    }).toJS;
    tx.onerror = ((web.Event _) {
      actionError ??= const DebtJournalException('idb_transaction_error');
      // Do not claim completion here. The transaction still needs to abort or
      // complete; oncomplete checks actionError and never returns success.
    }).toJS;
    tx.oncomplete = ((web.Event _) {
      if (done.isCompleted) return;
      if (actionError != null || !hasResult) {
        done.completeError(actionError ?? const DebtJournalException('idb_missing_result'),
            actionStack ?? StackTrace.current);
      } else if (syntheticFaults?.loseCompletion.remove(operation) ?? false) {
        // Simulates lost caller response after actual transaction completion.
        done.completeError(const DebtJournalException('synthetic_unknown'));
      } else {
        done.complete(result as T);
      }
    }).toJS;
    try {
      final objectStore = tx.objectStore(objectStoreName);
      final get = objectStore.get(_key(scope).toJS);
      get.onerror = ((web.Event _) {
        abortWith(const DebtJournalException('idb_read_error'), StackTrace.current);
      }).toJS;
      get.onsuccess = ((web.Event _) {
        try {
          final raw = get.result;
          final _Stored? record;
          if (raw == null) {
            record = null;
          } else if (raw.isA<JSString>()) {
            record = _decode(scope, (raw as JSString).toDart);
          } else {
            throw const DebtJournalException('invalid_record_type');
          }
          final decision = decide(record);
          result = decision.value;
          hasResult = true;
          if (decision.write != null) {
            if (!write) throw const DebtJournalException('readonly_mutation');
            final put = objectStore.put(_encode(scope, decision.write!).toJS,
                _key(scope).toJS);
            put.onerror = ((web.Event _) {
              abortWith(const DebtJournalException('idb_write_error'), StackTrace.current);
            }).toJS;
            if (syntheticFaults?.abortAfterPut.remove(operation) ?? false) {
              abortWith(const DebtJournalException('synthetic_abort'), StackTrace.current);
            }
          }
        } catch (e, stack) {
          // FormatException/type errors can include raw sensitive data.
          abortWith(e is DebtJournalException ? e :
              const DebtJournalException('idb_record_or_action_error'), stack);
        }
      }).toJS;
    } catch (e, stack) {
      abortWith(e is DebtJournalException ? e :
          const DebtJournalException('idb_request_setup_error'), stack);
    }
    return done.future;
  }

  @override
  Future<int> acquireFence(DebtScope scope) => _transaction(scope,
      write: true, operation: 'fence', decide: (record) {
    final next = record ?? _Stored(fence: 0, envelope: null,
        operation: null, usedIds: <String>{});
    if (next.fence >= _maxSafeInteger) {
      throw const DebtJournalException('fence_overflow');
    }
    next.fence++;
    return _Decision<int>(next.fence, write: next);
  });

  @override
  Future<DurableSnapshot> readSnapshot(DebtScope scope, int fence) =>
      _transaction(scope, write: false, operation: 'read', decide: (record) {
    if (record == null) throw const DebtJournalException('scope_not_initialized');
    if (record.fence != fence) throw const DebtJournalException('fenced');
    final value = record.envelope;
    return _Decision<DurableSnapshot>(DurableSnapshot(
      read: value == null ? const DebtRead.absent() : DebtRead.valid(value),
      latestOperation: record.operation,
    ));
  });

  @override
  Future<DurableMutation> prepare(DebtScope scope, int fence,
      int? expectedVersion, DurableOperation op) => _transaction(scope,
      write: true, operation: 'prepare', decide: (record) {
    if (record == null) return const _Decision(DurableMutation.rejected);
    if (record.fence != fence) return const _Decision(DurableMutation.fenced);
    if (record.envelope?.version != expectedVersion ||
        (record.operation != null && record.operation!.phase != DurablePhase.acknowledged)) {
      return const _Decision(DurableMutation.conflict);
    }
    if (op.id.isEmpty || op.phase != DurablePhase.prepared ||
        op.baseVersion != expectedVersion || op.proposed.scope != scope ||
        op.proposed.version != (expectedVersion ?? 0) + 1 ||
        record.usedIds.contains(op.id) || record.usedIds.length >= 2048) {
      return const _Decision(DurableMutation.rejected);
    }
    _validateEnvelope(scope, op.proposed);
    record.usedIds.add(op.id);
    record.operation = op;
    return _Decision(DurableMutation.applied, write: record);
  });

  @override
  Future<DurableMutation> commitPrepared(DebtScope scope, int fence, String id) =>
      _transaction(scope, write: true, operation: 'commit', decide: (record) {
    if (record == null) return const _Decision(DurableMutation.rejected);
    if (record.fence != fence) return const _Decision(DurableMutation.fenced);
    final op = record.operation;
    if (op == null || op.id != id || op.phase != DurablePhase.prepared ||
        op.baseVersion != record.envelope?.version) {
      return const _Decision(DurableMutation.conflict);
    }
    record.envelope = op.proposed;
    record.operation = DurableOperation(id: op.id, baseVersion: op.baseVersion,
        proposed: op.proposed, phase: DurablePhase.committed);
    return _Decision(DurableMutation.applied, write: record);
  });

  @override
  Future<DurableMutation> acknowledgeCommitted(DebtScope scope, int fence,
      String id, int envelopeVersion) => _transaction(scope,
      write: true, operation: 'ack', decide: (record) {
    if (record == null) return const _Decision(DurableMutation.rejected);
    if (record.fence != fence) return const _Decision(DurableMutation.fenced);
    final op = record.operation;
    if (op == null || op.id != id || op.phase != DurablePhase.committed ||
        record.envelope?.version != envelopeVersion ||
        !_sameEnvelope(record.envelope, op.proposed)) {
      return const _Decision(DurableMutation.conflict);
    }
    record.operation = DurableOperation(id: op.id, baseVersion: op.baseVersion,
        proposed: op.proposed, phase: DurablePhase.acknowledged);
    return _Decision(DurableMutation.applied, write: record);
  });
}

void _validateEnvelope(DebtScope scope, DebtEnvelope value) {
  if (value.scope != scope || value.version < 1 || value.version > _maxSafeInteger ||
      ((value.values.isNotEmpty || value.tombstones.isNotEmpty ||
          value.dirtyRevisions.isNotEmpty) && value.changedAt == null) ||
      value.values.entries.any((e) => e.key.isEmpty || e.value < 1 || e.value > 31 ||
          value.tombstones.containsKey(e.key)) ||
      value.tombstones.keys.any((key) => key.isEmpty) ||
      value.dirtyRevisions.entries.any((e) => e.key.isEmpty || e.value < 1 ||
          e.value > value.version ||
          (!value.values.containsKey(e.key) && !value.tombstones.containsKey(e.key)))) {
    throw const DebtJournalException('invalid_envelope');
  }
}

bool _sameMap<K, V>(Map<K, V> a, Map<K, V> b) => a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);
bool _sameEnvelope(DebtEnvelope? a, DebtEnvelope? b) => a != null && b != null &&
    a.scope == b.scope && a.version == b.version && a.changedAt == b.changedAt &&
    _sameMap(a.values, b.values) && _sameMap(a.tombstones, b.tombstones) &&
    _sameMap(a.dirtyRevisions, b.dirtyRevisions);

Map<String, Object?> _envelopeJson(DebtEnvelope e) => <String, Object?>{
  'version': e.version, 'values': e.values,
  'deleted': e.tombstones.map((key, value) => MapEntry(key, value.toUtc().toIso8601String())),
  'dirty': e.dirtyRevisions, 'changedAt': e.changedAt?.toUtc().toIso8601String(),
};

String _encode(DebtScope scope, _Stored record) {
  final op = record.operation;
  return jsonEncode(<String, Object?>{
    'schema': 1, 'scope': jsonEncode(<String>[scope.kind, scope.id]),
    'fence': record.fence,
    'envelope': record.envelope == null ? null : _envelopeJson(record.envelope!),
    'operation': op == null ? null : <String, Object?>{
      'id': op.id, 'base': op.baseVersion,
      'phase': op.phase.name, 'proposed': _envelopeJson(op.proposed),
    },
    'usedIds': record.usedIds.toList()..sort(),
  });
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const DebtJournalException('invalid_record');
  return Map<String, dynamic>.from(value);
}
DateTime _utc(Object? raw) {
  if (raw is! String || !raw.endsWith('Z')) throw const DebtJournalException('invalid_time');
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc) throw const DebtJournalException('invalid_time');
  return parsed;
}
DebtEnvelope _envelope(DebtScope scope, Object? raw) {
  final data = _map(raw);
  final version = data['version'];
  if (version is! int) throw const DebtJournalException('invalid_version');
  final values = Map<String, int>.from(_map(data['values']));
  final dirty = Map<String, int>.from(_map(data['dirty']));
  final deleted = _map(data['deleted']).map((key, value) => MapEntry(key, _utc(value)));
  final changedAt = data['changedAt'] == null ? null : _utc(data['changedAt']);
  final value = DebtEnvelope(scope: scope, version: version, values: values,
      tombstones: deleted, dirtyRevisions: dirty, changedAt: changedAt);
  _validateEnvelope(scope, value);
  return value;
}
_Stored _decode(DebtScope scope, String raw) {
  final data = _map(jsonDecode(raw));
  if (data['schema'] != 1 || data['scope'] != jsonEncode(<String>[scope.kind, scope.id]) ||
      data['fence'] is! int || (data['fence'] as int) < 1 ||
      (data['fence'] as int) > _maxSafeInteger || data['usedIds'] is! List) {
    throw const DebtJournalException('invalid_record');
  }
  final rawIds = data['usedIds'] as List;
  if (rawIds.any((id) => id is! String || id.isEmpty) || rawIds.length > 2048) {
    throw const DebtJournalException('invalid_record');
  }
  final ids = rawIds.cast<String>().toSet();
  if (ids.length != rawIds.length) throw const DebtJournalException('invalid_record');
  final current = data['envelope'] == null ? null : _envelope(scope, data['envelope']);
  DurableOperation? op;
  if (data['operation'] != null) {
    final value = _map(data['operation']);
    final id = value['id'];
    final base = value['base'];
    if (id is! String || !ids.contains(id) || (base != null && base is! int)) {
      throw const DebtJournalException('invalid_operation');
    }
    final phase = switch (value['phase']) {
      'prepared' => DurablePhase.prepared,
      'committed' => DurablePhase.committed,
      'acknowledged' => DurablePhase.acknowledged,
      _ => throw const DebtJournalException('invalid_operation'),
    };
    final proposed = _envelope(scope, value['proposed']);
    if (proposed.version != (base as int? ?? 0) + 1 ||
        (phase == DurablePhase.prepared && current?.version != base) ||
        (phase != DurablePhase.prepared && !_sameEnvelope(current, proposed))) {
      throw const DebtJournalException('invalid_operation');
    }
    op = DurableOperation(id: id, baseVersion: base as int?, proposed: proposed, phase: phase);
  }
  if (op == null && (current != null || ids.isNotEmpty)) {
    throw const DebtJournalException('invalid_record');
  }
  return _Stored(fence: data['fence'] as int, envelope: current,
      operation: op, usedIds: ids);
}
