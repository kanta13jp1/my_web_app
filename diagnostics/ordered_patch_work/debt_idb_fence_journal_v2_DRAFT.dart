// SYNTHETIC ONLY: disposable randomly named local browser database.
// Not connected to product, authentication, legacy stores, server, or user data.
// This prototype and browser fixtures have NOT been analyzed or executed.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

const _enabled = bool.fromEnvironment('DEBT_FENCE_SYNTHETIC');
const _maxSafe = 9007199254740991;
const fenceProbeStore = 'synthetic_fenced_journal';

class FenceError implements Exception {
  const FenceError(this.code);
  final String code;
  @override String toString() => 'FenceError($code)';
}
class FenceToken {
  const FenceToken(this.owner, this.fence);
  final String owner;
  final int fence;
}
class FenceFaults {
  bool loseCommitCompletion = false;
  bool suppressCommitTerminal = false;
  bool losePrepareCompletion = false;
  bool loseReconcileCompletion = false;
}
class _Decision<T> {
  const _Decision(this.value, [this.next]);
  final T value;
  final Map<String, dynamic>? next;
}

bool _deepEqual(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((k) => b.containsKey(k) && _deepEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length && List.generate(a.length, (i) => _deepEqual(a[i], b[i])).every((x) => x);
  }
  return a == b;
}

class SyntheticFenceJournal {
  SyntheticFenceJournal(this.database, {this.faults,
      this.settlementTimeout = const Duration(seconds: 10)}) {
    if (!_enabled || (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') ||
        !database.name.startsWith('synthetic-debt-fence-')) {
      throw const FenceError('isolated_database_required');
    }
  }
  final web.IDBDatabase database;
  final FenceFaults? faults;
  final Duration settlementTimeout;
  void _name(String value) {
    if (!value.startsWith('synthetic-') || value.length > 128) throw const FenceError('synthetic_name_required');
  }
  Map<String,dynamic> _copy(Map<String,dynamic> x) => Map<String,dynamic>.from(jsonDecode(jsonEncode(x)) as Map);
  Map<String,dynamic> _map(dynamic x) {
    if (x is! Map) throw const FenceError('invalid_record');
    return Map<String,dynamic>.from(x);
  }
  bool _safe(dynamic x) => x is int && x >= 0 && x <= _maxSafe;
  Map<String,dynamic> _validate(String owner, dynamic raw) {
    final r = _map(raw);
    if (r['owner'] != owner || !_safe(r['version']) || !_safe(r['counter']) ||
        !_safe(r['fence']) || r['fence'] == 0) throw const FenceError('invalid_record');
    final values = _map(r['values']); final deleted = _map(r['deleted']);
    final gen = _map(r['generations']); final dirty = _map(r['dirty']);
    if (r['usedIds'] is! List || (r['usedIds'] as List).length > 64) throw const FenceError('invalid_record');
    final keys = <String>{...values.keys,...deleted.keys};
    if (keys.length != gen.length || !gen.keys.toSet().containsAll(keys)) throw const FenceError('invalid_record');
    for (final k in keys) {
      _name(k);
      if (values.containsKey(k) == deleted.containsKey(k) ||
          (values.containsKey(k) && (values[k] is! int || values[k] < 1 || values[k] > 31)) ||
          (deleted.containsKey(k) && deleted[k] != true) ||
          !_safe(gen[k]) || gen[k] == 0 || gen[k] > r['counter']) throw const FenceError('invalid_record');
    }
    for (final e in dirty.entries) {
      if (!keys.contains(e.key) || e.value != gen[e.key]) throw const FenceError('invalid_record');
    }
    final used = (r['usedIds'] as List);
    if (used.any((id) => id is! String || !id.startsWith('synthetic-')) || used.toSet().length != used.length) {
      throw const FenceError('invalid_record');
    }
    final pending = r['pending'];
    if (pending != null) {
      final p = _map(pending);
      if (p['owner'] != owner || p['id'] is! String || !used.contains(p['id']) ||
          p['key'] is! String || !((p['key'] as String).startsWith('synthetic-')) ||
          !_safe(p['baseVersion']) || !_safe(p['preparedFence']) || p['preparedFence'] == 0 || (p['phase'] != 'prepared' && p['phase'] != 'committed' && p['phase'] != 'observed') ||
          (p['phase'] == 'observed' && (!_safe(p['observedFence']) || p['observedFence'] <= p['preparedFence'])) ||
          (p['value'] != null && (p['value'] is! int || p['value'] < 1 || p['value'] > 31))) {
        throw const FenceError('invalid_record');
      }
    }
    return r;
  }
  Map<String,dynamic> _snapshot(Map<String,dynamic> r) => {
    'owner':r['owner'], 'version':r['version'], 'counter':r['counter'],
    'values':r['values'], 'deleted':r['deleted'], 'generations':r['generations'],
    'dirty':r['dirty'], 'usedIds':r['usedIds'],
  };
  Future<T> _run<T>(String owner, _Decision<T> Function(Map<String,dynamic>?) decide,
      {bool loseCompletion = false, bool suppressTerminal = false}) {
    _name(owner);
    final done = Completer<T>();
    late web.IDBTransaction tx;
    try {
      tx = database.transaction(fenceProbeStore.toJS, 'readwrite', web.IDBTransactionOptions(durability:'strict'));
      if (tx.durability != 'strict') { tx.abort(); throw const FenceError('strict_unavailable'); }
    } catch (_) { return Future<T>.error(const FenceError('transaction_unavailable')); }
    final timer = Timer(settlementTimeout, () {
      if (!done.isCompleted) done.completeError(const FenceError('settlement_unknown'));
    });
    T? result; var hasResult = false; Object? error;
    void fail() { error ??= const FenceError('action_error'); try { tx.abort(); } catch (_) {} }
    tx.onabort = ((web.Event _) {
      if (suppressTerminal) return;
      timer.cancel(); if (!done.isCompleted) done.completeError(const FenceError('rolled_back'));
    }).toJS;
    tx.onerror = ((web.Event _) { error ??= const FenceError('idb_error'); }).toJS;
    tx.oncomplete = ((web.Event _) {
      if (suppressTerminal) return;
      timer.cancel(); if (done.isCompleted) return;
      if (error != null || !hasResult || loseCompletion) done.completeError(const FenceError('unknown_after_complete'));
      else done.complete(result as T);
    }).toJS;
    try {
      final store = tx.objectStore(fenceProbeStore);
      final get = store.get(owner.toJS);
      get.onerror = ((web.Event _) { fail(); }).toJS;
      get.onsuccess = ((web.Event _) {
        try {
          final raw = get.result;
          final Map<String,dynamic>? current;
          if (raw == null) { current = null; }
          else if (raw.isA<JSString>()) { current = _validate(owner, jsonDecode((raw as JSString).toDart)); }
          else { throw const FenceError('invalid_type'); }
          final decision = decide(current);
          result = decision.value; hasResult = true;
          if (decision.next != null) {
            _validate(owner, decision.next);
            final put = store.put(jsonEncode(decision.next).toJS, owner.toJS);
            put.onerror = ((web.Event _) { fail(); }).toJS;
          }
        } catch (_) { fail(); }
      }).toJS;
    } catch (_) { fail(); }
    return done.future;
  }
  // Initialization is ONLY for a DB freshly created by the fixture, never
  // inferred safe from absence in a pre-existing profile or user store.
  Future<bool> initializeFreshFixture(String owner) => _run(owner, (r) {
    if (r != null) return const _Decision<bool>(false);
    return _Decision<bool>(true, {'owner':owner,'fence':1,'version':0,'counter':0,
      'values':<String,dynamic>{},'deleted':<String,dynamic>{},
      'generations':<String,dynamic>{},'dirty':<String,dynamic>{},
      'usedIds':<String>[], 'pending':null});
  });
  Future<FenceToken> acquire(String owner) => _run(owner, (r) {
    if (r == null || r['fence'] == _maxSafe) throw const FenceError('missing_or_exhausted');
    final n = _copy(r); n['fence'] = (r['fence'] as int) + 1;
    return _Decision<FenceToken>(FenceToken(owner, n['fence'] as int), n);
  });
  Future<Map<String,dynamic>> inspect(String owner) => _run(owner, (r) {
    if (r == null) throw const FenceError('missing_scope_unknown');
    return _Decision<Map<String,dynamic>>(_copy(r));
  });
  // A previous observed marker is replaced only atomically with a new prepared
  // intent, on a newer fence, after explicit previous snapshot verification.
  Future<bool> prepare(FenceToken token, int expectedVersion, String id, String key, int? value,
      {String? previousId, Map<String,dynamic>? previousExpected}) {
    _name(id); _name(key);
    if (!_safe(expectedVersion) || (value != null && (value < 1 || value > 31))) throw const FenceError('invalid_input');
    final lose = faults?.losePrepareCompletion == true;
    if (lose) faults!.losePrepareCompletion = false;
    return _run(token.owner, (r) {
      if (r == null || r['fence'] != token.fence || r['version'] != expectedVersion ||
          (r['usedIds'] as List).contains(id) || (r['usedIds'] as List).length >= 64) {
        return const _Decision<bool>(false);
      }
      final old = r['pending'];
      if (old == null) {
        if (previousId != null || previousExpected != null) return const _Decision<bool>(false);
      } else {
        final p = _map(old);
        if (p['phase'] != 'observed' || p['owner'] != token.owner ||
            p['id'] != previousId || previousExpected == null ||
            token.fence <= (p['observedFence'] as int) || !_deepEqual(_snapshot(r), previousExpected)) {
          return const _Decision<bool>(false);
        }
      }
      final n = _copy(r); (n['usedIds'] as List).add(id);
      n['pending'] = {'owner':token.owner,'id':id,'key':key,'value':value,
        'baseVersion':expectedVersion,'preparedFence':token.fence,'phase':'prepared'};
      return _Decision<bool>(true,n);
    }, loseCompletion: lose);
  }
  // Read-only recovery; it returns the retained intent but never applies or
  // discards it. A fresh fence must be established before this observation.
  Future<Map<String,dynamic>?> recoverPrepared(FenceToken token) => _run(token.owner, (r) {
    if (r == null || r['fence'] != token.fence || r['pending'] == null) return const _Decision<Map<String,dynamic>?>(null);
    final p = _map(r['pending']);
    if (p['phase'] != 'prepared' || p['owner'] != token.owner || token.fence <= (p['preparedFence'] as int)) {
      return const _Decision<Map<String,dynamic>?>(null);
    }
    return _Decision<Map<String,dynamic>?>(_copy(p));
  });
  // Diagnostic only: no operation ID is removed to avoid unsafe reuse.
  Future<String> capacity(FenceToken token) => _run(token.owner, (r) {
    if (r == null || r['fence'] != token.fence) return const _Decision<String>('stale_or_missing');
    return _Decision<String>((r['usedIds'] as List).length >= 64 ? 'journal_limit' : 'available');
  });
  Future<bool> commit(FenceToken token, int expectedVersion, String id) {
    _name(id);
    final lose = faults?.loseCommitCompletion == true;
    if (lose) faults!.loseCommitCompletion = false;
    final suppress = faults?.suppressCommitTerminal == true;
    if (suppress) faults!.suppressCommitTerminal = false;
    return _run(token.owner, (r) {
      if (r == null || r['fence'] != token.fence || r['version'] != expectedVersion ||
          r['pending'] == null || r['counter'] == _maxSafe || r['version'] == _maxSafe) {
        return const _Decision<bool>(false);
      }
      final p = _map(r['pending']);
      if (p['owner'] != token.owner || p['id'] != id || p['baseVersion'] != expectedVersion || p['preparedFence'] != token.fence || p['phase'] != 'prepared') {
        return const _Decision<bool>(false);
      }
      final n = _copy(r); final values = _map(n['values']); final deleted = _map(n['deleted']);
      final gens = _map(n['generations']); final dirty = _map(n['dirty']);
      final key = p['key'] as String; final value = p['value'];
      final g = (r['counter'] as int) + 1;
      if (value == null) { values.remove(key); deleted[key] = true; }
      else { deleted.remove(key); values[key] = value; }
      gens[key] = g; dirty[key] = g;
      n['values']=values; n['deleted']=deleted; n['generations']=gens; n['dirty']=dirty;
      n['counter']=g; n['version']=(r['version'] as int)+1;
      n['pending']={...p,'phase':'committed'};
      return _Decision<bool>(true,n);
    }, loseCompletion: lose, suppressTerminal: suppress);
  }
  // Explicit local journal observation, NOT remote acknowledgement; dirty stays.
  // Caller must retain the independently computed full expected snapshot.
  Future<bool> reconcile(FenceToken token, String id, String key, int? value, int baseVersion, Map<String,dynamic> expected) {
    final lose = faults?.loseReconcileCompletion == true;
    if (lose) faults!.loseReconcileCompletion = false;
    return _run(token.owner, (r) {
      if (r == null || r['fence'] != token.fence || r['pending'] == null) return const _Decision<bool>(false);
      final p = _map(r['pending']);
      final phase = p['phase'];
      final minFence = phase == 'observed' ? p['observedFence'] : p['preparedFence'];
      if (p['owner'] != token.owner || p['id'] != id || p['key'] != key || p['value'] != value ||
          p['baseVersion'] != baseVersion || (phase != 'committed' && phase != 'observed') ||
          token.fence <= (minFence as int) || !_deepEqual(_snapshot(r), expected)) return const _Decision<bool>(false);
      final n = _copy(r); n['pending'] = {...p,'phase':'observed','observedFence':token.fence};
      return _Decision<bool>(true,n);
    }, loseCompletion:lose);
  }
}
