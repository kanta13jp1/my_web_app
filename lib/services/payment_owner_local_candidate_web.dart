import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'payment_owner_local_candidate_types.dart';

PaymentOwnerLocalCandidate createPaymentOwnerLocalCandidate(
        String databaseName) =>
    _Candidate(databaseName);

/// Detached only: no real Auth, owner provenance, migration, old-writer fence,
/// cross-device synchronization, or device durability is provided by this class.
class _Candidate implements PaymentOwnerLocalCandidate {
  _Candidate(this.databaseName);
  final String databaseName;
  static const _storeName = 'synthetic_owner_state_v1';
  static const _maxSafeRevision = 9007199254740991;

  Future<web.IDBDatabase?> _openExisting() async {
    final done = Completer<web.IDBDatabase?>();
    Timer? timer;
    void finish(web.IDBDatabase? db) {
      if (done.isCompleted) {
        db?.close();
        return;
      }
      timer?.cancel();
      done.complete(db);
    }

    try {
      final request = web.window.indexedDB.open(databaseName);
      timer = Timer(const Duration(seconds: 5), () => finish(null));
      request.onupgradeneeded = ((web.Event _) {
        // A missing/new DB must never be silently initialized as an empty owner.
        try {
          request.transaction?.abort();
        } catch (_) {
          finish(null);
        }
      }).toJS;
      request.onblocked = ((web.Event _) => finish(null)).toJS;
      request.onerror = ((web.Event _) => finish(null)).toJS;
      request.onsuccess = ((web.Event _) {
        try {
          // finish closes a late connection after blocked/timeout.
          finish(request.result as web.IDBDatabase);
        } catch (_) {
          finish(null);
        }
      }).toJS;
    } catch (_) {
      finish(null);
    }
    return done.future;
  }

  @override
  Future<CandidateResult> compareAndSet({
    required String owner,
    required int expectedRevision,
    required String requestId,
    required String value,
  }) async {
    // Diagnostic-only boundary: never access a production origin or legacy DB.
    final hostname = web.window.location.hostname;
    if ((hostname != '127.0.0.1' && hostname != 'localhost') ||
        !databaseName.startsWith('codex_synthetic_payment_owner_') ||
        databaseName.length > 128 ||
        owner.isEmpty ||
        owner.length > 256 ||
        requestId.isEmpty ||
        requestId.length > 256 ||
        value.length > 8192 ||
        expectedRevision < 0 ||
        expectedRevision >= _maxSafeRevision) {
      return const CandidateResult(CandidateStatus.invalid);
    }
    final db = await _openExisting();
    if (db == null) return const CandidateResult(CandidateStatus.recoveryHold);
    final done = Completer<CandidateResult>();
    Timer? timer;
    void finish(CandidateResult result) {
      if (done.isCompleted) return;
      timer?.cancel();
      db.close();
      done.complete(result);
    }

    try {
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);
      var tentative = const CandidateResult(CandidateStatus.recoveryHold);
      var writeMayBeScheduled = false;
      tx.oncomplete = ((web.Event _) => finish(tentative)).toJS;
      tx.onabort = ((web.Event _) =>
          finish(const CandidateResult(CandidateStatus.aborted))).toJS;
      // A timeout does not prove the transaction failed or did not commit.
      timer = Timer(const Duration(seconds: 10), () {
        // Abort is best effort: an already committed transaction is still unknown.
        try {
          tx.abort();
        } catch (_) {/* Not proof of commit or rollback. */}
        finish(const CandidateResult(CandidateStatus.outcomeUnknown));
      });
      final request = store.get(owner.toJS);
      request.onsuccess = ((web.Event _) {
        if (done.isCompleted) return;
        try {
          final raw = request.result?.dartify();
          if (raw is! String || raw.length > 65536) return;
          final decoded = jsonDecode(raw);
          if (!raw.startsWith('{\"schema\":1,') ||
              jsonEncode(decoded) != raw ||
              decoded is! Map<String, dynamic> ||
              !_exactKeys(decoded, {
                'schema',
                'owner',
                'baseRevision',
                'revision',
                'value',
                'receipts'
              }) ||
              decoded['schema'] is! int ||
              decoded['schema'] != 1 ||
              decoded['owner'] != owner ||
              decoded['baseRevision'] is! int ||
              decoded['baseRevision'] < 0 ||
              decoded['revision'] is! int ||
              decoded['revision'] < decoded['baseRevision'] ||
              decoded['revision'] > _maxSafeRevision ||
              decoded['value'] is! String ||
              (decoded['value'] as String).length > 8192 ||
              decoded['receipts'] is! List) {
            return;
          }
          final revision = decoded['revision'] as int;
          final baseRevision = decoded['baseRevision'] as int;
          final receipts = decoded['receipts'] as List<dynamic>;
          if (receipts.length > 100 ||
              receipts.length != revision - baseRevision) return;
          final ids = <String>{};
          Map<String, dynamic>? prior;
          for (var index = 0; index < receipts.length; index++) {
            final item = receipts[index];
            if (item is! Map<String, dynamic> ||
                !_exactKeys(item,
                    {'requestId', 'expectedRevision', 'revision', 'value'}) ||
                item['requestId'] is! String ||
                (item['requestId'] as String).isEmpty ||
                (item['requestId'] as String).length > 256 ||
                !ids.add(item['requestId'] as String) ||
                item['expectedRevision'] is! int ||
                item['expectedRevision'] != baseRevision + index ||
                item['expectedRevision'] >= _maxSafeRevision ||
                item['revision'] is! int ||
                item['revision'] != item['expectedRevision'] + 1 ||
                item['value'] is! String ||
                (item['value'] as String).length > 8192 ||
                item['revision'] > revision) {
              return;
            }
            if (item['revision'] == revision &&
                item['value'] != decoded['value']) return;
            if (item['requestId'] == requestId) prior = item;
          }
          if (prior != null) {
            if (prior['expectedRevision'] != expectedRevision ||
                prior['value'] != value) {
              tentative =
                  const CandidateResult(CandidateStatus.versionConflict);
            } else {
              tentative = CandidateResult(CandidateStatus.historicalReceipt,
                  revision: prior['revision'] as int);
            }
            return;
          }
          if (revision != expectedRevision) {
            tentative = CandidateResult(CandidateStatus.versionConflict,
                revision: revision);
            return;
          }
          if (receipts.length == 100) return;
          final next = revision + 1;
          receipts.add({
            'requestId': requestId,
            'expectedRevision': expectedRevision,
            'revision': next,
            'value': value,
          });
          decoded['revision'] = next;
          decoded['value'] = value;
          final encoded = jsonEncode(decoded);
          if (encoded.length > 65536) return;
          writeMayBeScheduled = true;
          store.put(encoded.toJS, owner.toJS);
          tentative = CandidateResult(CandidateStatus.applied, revision: next);
        } catch (_) {
          // Never infer empty data from invalid or unrecognized state.
          tentative = CandidateResult(writeMayBeScheduled
              ? CandidateStatus.outcomeUnknown
              : CandidateStatus.recoveryHold);
          try {
            tx.abort();
          } catch (_) {/* The outcome can remain unknown. */}
        }
      }).toJS;
    } catch (_) {
      finish(const CandidateResult(CandidateStatus.recoveryHold));
    }
    return done.future;
  }
}

bool _exactKeys(Map<String, dynamic> value, Set<String> expected) =>
    value.length == expected.length && value.keys.toSet().containsAll(expected);
