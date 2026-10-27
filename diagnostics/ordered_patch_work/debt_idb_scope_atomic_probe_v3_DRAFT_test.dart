@TestOn('browser')
library;
// SYNTHETIC BROWSER FIXTURE, NOT RUN. Disposable profile/origin required.
// --dart-define=DEBT_IDB_SCOPE_SYNTHETIC=true. No database deletion.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'debt_idb_scope_atomic_probe_v2_DRAFT.dart';

const _enabled = bool.fromEnvironment('DEBT_IDB_SCOPE_SYNTHETIC');
const _a = 'synthetic-owner-A';
const _b = 'synthetic-owner-B';

Future<web.IDBDatabase> _openNewSyntheticDb() {
  final host = Uri.base.host;
  if (!_enabled || (host != 'localhost' && host != '127.0.0.1')) {
    throw StateError('disposable local test origin and opt-in required');
  }
  final name = 'synthetic-debt-atomic-${web.window.crypto.randomUUID()}';
  final request = web.window.indexedDB.open(name, 1);
  final result = Completer<web.IDBDatabase>();
  var created = false;
  request.onupgradeneeded = ((web.Event _) {
    final raw = request.result;
    if (raw == null || !raw.isA<web.IDBDatabase>()) {
      request.transaction?.abort();
      return;
    }
    (raw as web.IDBDatabase).createObjectStore(syntheticStoreName);
    created = true;
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final raw = request.result;
    if (raw == null || !raw.isA<web.IDBDatabase>()) {
      if (!result.isCompleted) result.completeError(StateError('invalid test database'));
      return;
    }
    final db = raw as web.IDBDatabase;
    if (result.isCompleted || !created) {
      db.close();
      if (!result.isCompleted) result.completeError(StateError('existing DB refused'));
      return;
    }
    result.complete(db);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!result.isCompleted) result.completeError(StateError('open failed'));
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!result.isCompleted) result.completeError(StateError('open blocked'));
  }).toJS;
  return result.future;
}

// Open only the name generated and successfully created by this fixture.
// onupgradeneeded is rejected: a second connection must not create a database.
Future<web.IDBDatabase> _openSecondConnection(web.IDBDatabase first) {
  final name = first.name;
  if (!_enabled || (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') ||
      !name.startsWith('synthetic-debt-atomic-')) {
    throw StateError('synthetic connection required');
  }
  final request = web.window.indexedDB.open(name, 1);
  final result = Completer<web.IDBDatabase>();
  var unexpectedUpgrade = false;
  request.onupgradeneeded = ((web.Event _) {
    unexpectedUpgrade = true;
    request.transaction?.abort();
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!result.isCompleted) result.completeError(StateError('second connection failed'));
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!result.isCompleted) result.completeError(StateError('second connection blocked'));
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final raw = request.result;
    if (raw == null || !raw.isA<web.IDBDatabase>()) {
      if (!result.isCompleted) result.completeError(StateError('invalid second database'));
      return;
    }
    final db = raw as web.IDBDatabase;
    if (unexpectedUpgrade || result.isCompleted) {
      db.close();
      if (!result.isCompleted) result.completeError(StateError('unexpected new database'));
      return;
    }
    result.complete(db);
  }).toJS;
  return result.future;
}

Map<String, dynamic> _field(Map<String, dynamic> state, String name) =>
    Map<String, dynamic>.from(state[name] as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late web.IDBDatabase db;
  late SyntheticAtomicFaults faults;
  late SyntheticScopeAtomicProbe probe;

  setUp(() async {
    db = await _openNewSyntheticDb();
    faults = SyntheticAtomicFaults();
    probe = SyntheticScopeAtomicProbe(db, faults: faults);
  });
  tearDown(() { db.close(); });

  Future<void> seed() async {
    expect(await probe.edit(_a, 'synthetic-p', 7,
        expectedVersion: 0, operationId: 'synthetic-op-p1', updatedAt: 101), isTrue);
    expect(await probe.edit(_a, 'synthetic-q', 12,
        expectedVersion: 1, operationId: 'synthetic-op-q', updatedAt: 102), isTrue);
    expect(await probe.edit(_a, 'synthetic-r', null,
        expectedVersion: 2, operationId: 'synthetic-op-r', updatedAt: 103), isTrue);
    expect(await probe.edit(_b, 'synthetic-p', 20,
        expectedVersion: 0, operationId: 'synthetic-op-b', updatedAt: 104), isTrue);
  }

  test('single edit keeps other values, tombstone, generations and owner', () async {
    await seed();
    final beforeB = jsonEncode(await probe.read(_b));
    expect(await probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-p2', updatedAt: 105), isTrue);
    final a = await probe.read(_a);
    expect(a['version'], 4);
    expect(a['counter'], 4);
    expect(a['updatedAt'], 105);
    expect(_field(a, 'values'), {'synthetic-p': 20, 'synthetic-q': 12});
    expect(_field(a, 'tombstones'), {'synthetic-r': true});
    expect(_field(a, 'generations'), {'synthetic-p': 4, 'synthetic-q': 2, 'synthetic-r': 3});
    expect(_field(a, 'dirty'), {'synthetic-p': 4, 'synthetic-q': 2, 'synthetic-r': 3});
    expect(_field(a, 'journal').keys, containsAll(['synthetic-op-p1', 'synthetic-op-q', 'synthetic-op-r', 'synthetic-op-p2']));
    expect(jsonEncode(await probe.read(_b)), beforeB);
  });

  for (final defect in ['value', 'tombstone']) {
    test('candidate missing another $defect is rejected before put', () async {
      await seed();
      final beforeA = jsonEncode(await probe.read(_a));
      final beforeB = jsonEncode(await probe.read(_b));
      faults.dropOtherValue = defect == 'value';
      faults.dropOtherTombstone = defect == 'tombstone';
      expect(await probe.edit(_a, 'synthetic-p', 20,
          expectedVersion: 3, operationId: 'synthetic-op-invalid', updatedAt: 105), isFalse);
      expect(jsonEncode(await probe.read(_a)), beforeA);
      expect(jsonEncode(await probe.read(_b)), beforeB);
    });
  }

  test('abort after put request success rolls back complete record', () async {
    await seed();
    final beforeA = jsonEncode(await probe.read(_a));
    final beforeB = jsonEncode(await probe.read(_b));
    faults.abortAfterPut = true;
    await expectLater(probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-abort', updatedAt: 105),
        throwsA(isA<SyntheticAtomicError>().having((e) => e.code, 'code', 'rolled_back')));
    expect(jsonEncode(await probe.read(_a)), beforeA);
    expect(jsonEncode(await probe.read(_b)), beforeB);
  });

  test('old CAS and duplicate operation do not mutate scope', () async {
    await seed();
    final before = jsonEncode(await probe.read(_a));
    expect(await probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 2, operationId: 'synthetic-op-stale', updatedAt: 105), isFalse);
    expect(await probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-p1', updatedAt: 105), isFalse);
    expect(jsonEncode(await probe.read(_a)), before);
  });

  test('old generation ack cannot clear newer same-key dirty state', () async {
    await seed();
    expect(await probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-p2', updatedAt: 105), isTrue);
    final before = jsonEncode(await probe.read(_a));
    expect(await probe.acknowledge(_a, 'synthetic-op-p1'), isFalse);
    expect(jsonEncode(await probe.read(_a)), before);
    expect(await probe.acknowledge(_a, 'synthetic-op-p2'), isTrue);
    final after = await probe.read(_a);
    expect(_field(after, 'values')['synthetic-p'], 20);
    expect(_field(after, 'dirty').containsKey('synthetic-p'), isFalse);
    expect(_field(after, 'dirty')['synthetic-q'], 2);
    expect(_field(after, 'dirty')['synthetic-r'], 3);
    expect((_field(after, 'journal')['synthetic-op-p2'] as Map)['state'], 'acknowledged');
  });

  test('postcomplete response loss leaves journal and dirty visible', () async {
    await seed();
    faults.loseCompletion = true;
    await expectLater(probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-unknown', updatedAt: 105),
        throwsA(isA<SyntheticAtomicError>()));
    final after = await probe.read(_a);
    expect(_field(after, 'values')['synthetic-p'], 20);
    expect(_field(after, 'dirty')['synthetic-p'], 4);
    expect((_field(after, 'journal')['synthetic-op-unknown'] as Map)['state'], 'pending');
    // No automatic retry, process kill, or durable recovery is claimed here.
  });
  test('concurrent expected version allows at most one commit', () async {
    await seed();
    final results = await Future.wait([
      probe.edit(_a, 'synthetic-p', 20,
          expectedVersion: 3, operationId: 'synthetic-op-p2', updatedAt: 105),
      probe.edit(_a, 'synthetic-q', 9,
          expectedVersion: 3, operationId: 'synthetic-op-q2', updatedAt: 106),
    ]);
    expect(results.where((v) => v).length, 1);
    final after = await probe.read(_a);
    expect(after['version'], 4);
    expect(_field(after, 'tombstones')['synthetic-r'], isTrue);
    expect(_field(after, 'dirty')['synthetic-r'], 3);
    if (results[0]) {
      expect(_field(after, 'values'), {'synthetic-p': 20, 'synthetic-q': 12});
    } else {
      expect(_field(after, 'values'), {'synthetic-p': 7, 'synthetic-q': 9});
    }
  });

  test('value and tombstone acknowledgements cannot clear newer edits', () async {
    await seed();
    expect(await probe.edit(_a, 'synthetic-p', null,
        expectedVersion: 3, operationId: 'synthetic-op-delete', updatedAt: 105), isTrue);
    expect(await probe.acknowledge(_a, 'synthetic-op-p1'), isFalse);
    var state = await probe.read(_a);
    expect(_field(state, 'tombstones')['synthetic-p'], isTrue);
    expect(_field(state, 'dirty')['synthetic-p'], 4);
    expect(await probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 4, operationId: 'synthetic-op-recreate', updatedAt: 106), isTrue);
    expect(await probe.acknowledge(_a, 'synthetic-op-delete'), isFalse);
    state = await probe.read(_a);
    expect(_field(state, 'values')['synthetic-p'], 20);
    expect(_field(state, 'dirty')['synthetic-p'], 5);
  });

  test('abort request failure followed by completion is unknown, not rollback', () async {
    await seed();
    faults.abortAfterPut = true;
    faults.simulateAbortFailure = true;
    await expectLater(probe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-abort-unknown', updatedAt: 105),
        throwsA(isA<SyntheticAtomicError>().having((e) => e.code, 'code', 'unknown_after_complete')));
    final after = await probe.read(_a);
    expect(after['version'], 4);
    expect(_field(after, 'values')['synthetic-p'], 20);
    expect(_field(after, 'dirty')['synthetic-p'], 4);
    expect((_field(after, 'journal')['synthetic-op-abort-unknown'] as Map)['state'], 'pending');
  });

  test('missing terminal event resolves as unknown, never rollback', () async {
    await seed();
    final shortProbe = SyntheticScopeAtomicProbe(db, faults: faults,
        settlementTimeout: const Duration(milliseconds: 80));
    faults.suppressTerminalEvents = true;
    await expectLater(shortProbe.edit(_a, 'synthetic-p', 20,
        expectedVersion: 3, operationId: 'synthetic-op-event-unknown', updatedAt: 105),
        throwsA(isA<SyntheticAtomicError>().having((e) => e.code, 'code', 'settlement_unknown')));
    // This is simulated loss of callback observation, not a real process kill.
    final after = await probe.read(_a);
    expect(_field(after, 'values')['synthetic-p'], 20);
    expect(_field(after, 'dirty')['synthetic-p'], 4);
  });

  test('current tombstone ack clears only its dirty marker', () async {
    await seed();
    expect(await probe.acknowledge(_a, 'synthetic-op-r'), isTrue);
    final after = await probe.read(_a);
    expect(_field(after, 'tombstones')['synthetic-r'], isTrue);
    expect(_field(after, 'generations')['synthetic-r'], 3);
    expect(_field(after, 'dirty').containsKey('synthetic-r'), isFalse);
    expect(_field(after, 'dirty')['synthetic-p'], 1);
    expect(_field(after, 'dirty')['synthetic-q'], 2);
    expect((_field(after, 'journal')['synthetic-op-r'] as Map)['state'], 'acknowledged');
  });

  test('owner B cannot acknowledge owner A operation or change either', () async {
    await seed();
    final beforeA = jsonEncode(await probe.read(_a));
    final beforeB = jsonEncode(await probe.read(_b));
    expect(await probe.acknowledge(_b, 'synthetic-op-p1'), isFalse);
    expect(jsonEncode(await probe.read(_a)), beforeA);
    expect(jsonEncode(await probe.read(_b)), beforeB);
  });

  test('independent connections preserve complete winning state and owner B', () async {
    await seed();
    final beforeA = await probe.read(_a);
    final beforeB = jsonEncode(await probe.read(_b));
    final secondDb = await _openSecondConnection(db);
    try {
      final second = SyntheticScopeAtomicProbe(secondDb);
      final results = await Future.wait([
        probe.edit(_a, 'synthetic-p', 20,
            expectedVersion: 3, operationId: 'synthetic-op-connection-a', updatedAt: 105),
        second.edit(_a, 'synthetic-q', 9,
            expectedVersion: 3, operationId: 'synthetic-op-connection-b', updatedAt: 106),
      ]);
      expect(results.where((result) => result).length, 1);
      final winnerA = results[0];
      final winnerKey = winnerA ? 'synthetic-p' : 'synthetic-q';
      final loserKey = winnerA ? 'synthetic-q' : 'synthetic-p';
      final winnerId = winnerA ? 'synthetic-op-connection-a' : 'synthetic-op-connection-b';
      final loserId = winnerA ? 'synthetic-op-connection-b' : 'synthetic-op-connection-a';
      final winnerDay = winnerA ? 20 : 9;
      final expected = Map<String, dynamic>.from(jsonDecode(jsonEncode(beforeA)) as Map);
      final values = _field(expected, 'values')..[winnerKey] = winnerDay;
      final generations = _field(expected, 'generations')..[winnerKey] = 4;
      final dirty = _field(expected, 'dirty')..[winnerKey] = 4;
      final journal = _field(expected, 'journal');
      journal[winnerId] = {'key': winnerKey, 'generation': 4,
        'kind': 'value', 'day': winnerDay, 'state': 'pending'};
      expected['values'] = values;
      expected['generations'] = generations;
      expected['dirty'] = dirty;
      expected['journal'] = journal;
      expected['version'] = 4;
      expected['counter'] = 4;
      expected['updatedAt'] = winnerA ? 105 : 106;
      final afterA = await probe.read(_a);
      expect(afterA, expected);
      expect(await second.read(_a), expected);
      expect(_field(afterA, 'journal').containsKey(loserId), isFalse);
      expect(_field(afterA, 'values')[loserKey], _field(beforeA, 'values')[loserKey]);
      expect(_field(afterA, 'generations')[loserKey], _field(beforeA, 'generations')[loserKey]);
      expect(_field(afterA, 'dirty')[loserKey], _field(beforeA, 'dirty')[loserKey]);
      expect(jsonEncode(await probe.read(_b)), beforeB);
      expect(jsonEncode(await second.read(_b)), beforeB);
    } finally {
      secondDb.close();
    }
  });

}