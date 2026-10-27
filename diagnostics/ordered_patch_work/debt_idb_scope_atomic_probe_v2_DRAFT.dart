// NON-SHIPPING SYNTHETIC PROBE. No product, legacy, network or real user data.
// The caller supplies an already opened, disposable synthetic IDB database.
// Browser type checking, event ordering and durability have NOT been tested.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

const _enabled = bool.fromEnvironment('DEBT_IDB_SCOPE_SYNTHETIC');
const _maxSafe = 9007199254740991;
const syntheticStoreName = 'synthetic_scope_atomic';

class SyntheticAtomicFaults {
  bool abortAfterPut = false;
  bool dropOtherValue = false;
  bool dropOtherTombstone = false;
  bool loseCompletion = false;
  // Synthetic-only fault toggles; never evidence of a real native failure.
  bool simulateAbortFailure = false;
  bool suppressTerminalEvents = false;
}

class SyntheticAtomicError implements Exception {
  const SyntheticAtomicError(this.code);
  final String code;
  @override
  String toString() => 'SyntheticAtomicError($code)';
}

class _Decision<T> {
  const _Decision(this.value, [this.record]);
  final T value;
  final Map<String, dynamic>? record;
}

class SyntheticScopeAtomicProbe {
  SyntheticScopeAtomicProbe(this.database, {this.faults,
      this.settlementTimeout = const Duration(seconds: 10)}) {
    final host = Uri.base.host;
    if (!_enabled || (host != 'localhost' && host != '127.0.0.1') ||
        !database.name.startsWith('synthetic-debt-atomic-')) {
      throw const SyntheticAtomicError('isolated_database_required');
    }
  }
  final web.IDBDatabase database;
  final SyntheticAtomicFaults? faults;
  final Duration settlementTimeout;

  // Names are synthetic-only; checks are not proof of isolated browser profile.
  void _checkName(String s) {
    if (!s.startsWith('synthetic-') || s.length > 128) {
      throw const SyntheticAtomicError('synthetic_name_required');
    }
  }
  Map<String, dynamic> _blank(String owner) => <String, dynamic>{
    'owner': owner, 'version': 0, 'counter': 0, 'values': <String, dynamic>{},
    'tombstones': <String, dynamic>{}, 'generations': <String, dynamic>{},
    'dirty': <String, dynamic>{}, 'journal': <String, dynamic>{}, 'updatedAt': 0,
  };
  Map<String, dynamic> _copy(Map<String, dynamic> input) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(input)) as Map);
  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) throw const SyntheticAtomicError('invalid_record');
    return Map<String, dynamic>.from(value);
  }
  bool _safeNum(dynamic n) => n is int && n >= 0 && n <= _maxSafe;

  Map<String, dynamic> _decode(String owner, String text) {
    final r = _map(jsonDecode(text));
    if (r['owner'] != owner || !_safeNum(r['version']) || !_safeNum(r['counter']) ||
        !_safeNum(r['updatedAt'])) throw const SyntheticAtomicError('invalid_record');
    final values = _map(r['values']);
    final tombs = _map(r['tombstones']);
    final generations = _map(r['generations']);
    final dirty = _map(r['dirty']);
    final journal = _map(r['journal']);
    if (journal.length > 64) throw const SyntheticAtomicError('journal_limit');
    final keys = <String>{...values.keys, ...tombs.keys};
    for (final key in keys) {
      _checkName(key);
      if (values.containsKey(key) == tombs.containsKey(key)) {
        throw const SyntheticAtomicError('invalid_record');
      }
      if (values.containsKey(key) &&
          (values[key] is! int || (values[key] as int) < 1 || (values[key] as int) > 31)) {
        throw const SyntheticAtomicError('invalid_record');
      }
      if (tombs.containsKey(key) && tombs[key] != true) {
        throw const SyntheticAtomicError('invalid_record');
      }
      final g = generations[key];
      if (!_safeNum(g) || g == 0 || (g as int) > (r['counter'] as int)) {
        throw const SyntheticAtomicError('invalid_record');
      }
    }
    if (generations.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(generations.keys.toSet()).isNotEmpty) {
      throw const SyntheticAtomicError('invalid_record');
    }
    for (final e in dirty.entries) {
      if (!keys.contains(e.key) || e.value != generations[e.key]) {
        throw const SyntheticAtomicError('invalid_record');
      }
    }
    for (final e in journal.entries) {
      _checkName(e.key);
      final op = _map(e.value);
      if (op['key'] is! String || !_safeNum(op['generation']) ||
          op['generation'] == 0 || (op['generation'] as int) > (r['counter'] as int) ||
          (op['kind'] != 'value' && op['kind'] != 'tombstone') ||
          (op['state'] != 'pending' && op['state'] != 'acknowledged')) {
        throw const SyntheticAtomicError('invalid_record');
      }
      _checkName(op['key'] as String);
      if (op['kind'] == 'value' &&
          (op['day'] is! int || (op['day'] as int) < 1 || (op['day'] as int) > 31)) {
        throw const SyntheticAtomicError('invalid_record');
      }
      if (op['kind'] == 'tombstone' && op['day'] != null) {
        throw const SyntheticAtomicError('invalid_record');
      }
    }
    return r;
  }

  // Decisions and get/put calls happen in the IDB request callback with no
  // unrelated await. The transaction's oncomplete, not put success, resolves.
  Future<T> _run<T>(String owner, {
    required bool write,
    required _Decision<T> Function(Map<String, dynamic>) decide,
  }) {
    _checkName(owner);
    final done = Completer<T>();
    late web.IDBTransaction tx;
    try {
      tx = write
          ? database.transaction(syntheticStoreName.toJS, 'readwrite',
              web.IDBTransactionOptions(durability: 'strict'))
          : database.transaction(syntheticStoreName.toJS, 'readonly');
      if (write && tx.durability != 'strict') {
        tx.abort();
        throw const SyntheticAtomicError('strict_unavailable');
      }
    } catch (_) {
      return Future<T>.error(const SyntheticAtomicError('transaction_unavailable'));
    }
    // Missing terminal events can never be classified as rollback/success.
    final ignoreTerminal = faults?.suppressTerminalEvents == true;
    if (ignoreTerminal) faults!.suppressTerminalEvents = false;
    final timer = Timer(settlementTimeout, () {
      if (!done.isCompleted) done.completeError(const SyntheticAtomicError('settlement_unknown'));
    });
    Object? actionError;
    T? result;
    var hasResult = false;
    void fail() {
      // An abort request is not evidence that the transaction rolled back.
      actionError ??= const SyntheticAtomicError('operation_error');
      if (faults?.simulateAbortFailure == true) {
        faults!.simulateAbortFailure = false;
        return; // Test-only: let the transaction settle without calling abort.
      }
      try { tx.abort(); } catch (_) { /* wait for terminal event or unknown */ }
    }
    tx.onabort = ((web.Event _) {
      if (ignoreTerminal) return;
      timer.cancel();
      if (!done.isCompleted) done.completeError(const SyntheticAtomicError('rolled_back'));
    }).toJS;
    tx.onerror = ((web.Event _) { actionError ??= const SyntheticAtomicError('idb_error'); }).toJS;
    tx.oncomplete = ((web.Event _) {
      if (ignoreTerminal) return;
      timer.cancel();
      if (done.isCompleted) return;
      if (actionError != null || !hasResult) {
        // oncomplete means the transaction may have committed; never say rollback.
        done.completeError(const SyntheticAtomicError('unknown_after_complete'));
      } else if (faults?.loseCompletion == true) {
        faults!.loseCompletion = false;
        done.completeError(const SyntheticAtomicError('unknown_after_complete'));
      } else {
        done.complete(result as T);
      }
    }).toJS;
    try {
      final store = tx.objectStore(syntheticStoreName);
      final get = store.get(owner.toJS);
      get.onerror = ((web.Event _) { fail(); }).toJS;
      get.onsuccess = ((web.Event _) {
        try {
          final raw = get.result;
          final record = raw == null ? _blank(owner) :
              (raw.isA<JSString>() ? _decode(owner, (raw as JSString).toDart)
                  : throw const SyntheticAtomicError('invalid_type'));
          final outcome = decide(record);
          result = outcome.value;
          hasResult = true;
          if (outcome.record != null) {
            if (!write) throw const SyntheticAtomicError('readonly_mutation');
            final put = store.put(jsonEncode(outcome.record).toJS, owner.toJS);
            put.onerror = ((web.Event _) { fail(); }).toJS;
            if (faults?.abortAfterPut == true) {
              faults!.abortAfterPut = false;
              // Request success is not transaction success; abort while the
              // transaction is active, then verify onabort and old state.
              put.onsuccess = ((web.Event _) { fail(); }).toJS;
            }
          }
        } catch (_) { fail(); }
      }).toJS;
    } catch (_) { fail(); }
    return done.future;
  }

  Future<Map<String, dynamic>> read(String owner) => _run(owner,
      write: false, decide: (r) => _Decision<Map<String, dynamic>>(_copy(r)));

  Future<bool> edit(String owner, String key, int? day, {
    required int expectedVersion, required String operationId, required int updatedAt,
  }) {
    _checkName(key);
    _checkName(operationId);
    if (day != null && (day < 1 || day > 31) || !_safeNum(expectedVersion) ||
        !_safeNum(updatedAt) || updatedAt == 0) {
      throw const SyntheticAtomicError('invalid_input');
    }
    return _run(owner, write: true, decide: (old) {
      final journal = _map(old['journal']);
      if (old['version'] != expectedVersion || journal.containsKey(operationId) ||
          journal.length >= 64 || old['version'] == _maxSafe || old['counter'] == _maxSafe) {
        return const _Decision<bool>(false);
      }
      final next = _copy(old);
      final values = _map(next['values']);
      final tombs = _map(next['tombstones']);
      final generations = _map(next['generations']);
      final dirty = _map(next['dirty']);
      final nextJournal = _map(next['journal']);
      final generation = (old['counter'] as int) + 1;
      if (day == null) { values.remove(key); tombs[key] = true; }
      else { tombs.remove(key); values[key] = day; }
      generations[key] = generation;
      dirty[key] = generation;
      nextJournal[operationId] = <String, dynamic>{'key': key, 'generation': generation,
        'kind': day == null ? 'tombstone' : 'value', 'day': day, 'state': 'pending'};
      if (faults?.dropOtherValue == true) {
        faults!.dropOtherValue = false;
        values.remove('synthetic-q');
      }
      if (faults?.dropOtherTombstone == true) {
        faults!.dropOtherTombstone = false;
        tombs.remove('synthetic-r');
      }
      next['values'] = values;
      next['tombstones'] = tombs;
      next['generations'] = generations;
      next['dirty'] = dirty;
      next['journal'] = nextJournal;
      next['version'] = (old['version'] as int) + 1;
      next['counter'] = generation;
      next['updatedAt'] = updatedAt;
      // Check each unrelated key across value/tombstone/generation/dirty before
      // issuing put. Protect against injected candidate loss, not a dishonest DB.
      for (final field in ['values', 'tombstones', 'generations', 'dirty']) {
        final before = _map(old[field]);
        final after = _map(next[field]);
        final keys = <String>{...before.keys, ...after.keys}..remove(key);
        for (final k in keys) {
          if (before.containsKey(k) != after.containsKey(k) || before[k] != after[k]) {
            return const _Decision<bool>(false);
          }
        }
      }
      _decode(owner, jsonEncode(next));
      return _Decision<bool>(true, next);
    });
  }

  Future<bool> acknowledge(String owner, String operationId) {
    _checkName(operationId);
    return _run(owner, write: true, decide: (old) {
      final journal = _map(old['journal']);
      if (!journal.containsKey(operationId)) return const _Decision<bool>(false);
      final op = _map(journal[operationId]);
      final key = op['key'] as String;
      final generation = op['generation'] as int;
      final values = _map(old['values']);
      final tombs = _map(old['tombstones']);
      final dirty = _map(old['dirty']);
      final matches = op['state'] == 'pending' && dirty[key] == generation &&
          _map(old['generations'])[key] == generation &&
          (op['kind'] == 'value' ? values[key] == op['day'] : tombs[key] == true);
      if (!matches || old['version'] == _maxSafe) return const _Decision<bool>(false);
      final next = _copy(old);
      final nextDirty = _map(next['dirty'])..remove(key);
      final nextJournal = _map(next['journal']);
      final nextOp = _map(nextJournal[operationId])..['state'] = 'acknowledged';
      nextJournal[operationId] = nextOp;
      next['dirty'] = nextDirty;
      next['journal'] = nextJournal;
      next['version'] = (old['version'] as int) + 1;
      _decode(owner, jsonEncode(next));
      return _Decision<bool>(true, next);
    });
  }
}