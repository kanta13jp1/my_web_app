@TestOn('browser')
library;
// SYNTHETIC DRAFT ONLY. Not executed, compiled, or connected to user storage.
// A future runner MUST use a fresh disposable browser profile on localhost and
// pass --dart-define=DEBT_IDB_ISOLATED_TEST=true. No databases are deleted.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'debt_owner_atomic_journal_DRAFT.dart';
import 'debt_owner_durable_journal_DRAFT.dart';
import 'debt_owner_indexeddb_adapter_DRAFT.dart';

const _enabled = bool.fromEnvironment('DEBT_IDB_ISOLATED_TEST');
const _storeName = 'synthetic_scope_records';
final _a = DebtScope.owner('synthetic-owner-A');
final _b = DebtScope.owner('synthetic-owner-B');
final _time = DateTime.utc(2030, 1, 2);

Future<web.IDBDatabase> _openSyntheticDatabase() {
  final host = Uri.base.host;
  if (!_enabled || (host != '127.0.0.1' && host != 'localhost')) {
    throw StateError('Requires explicit isolated local test origin and profile');
  }
  // Cryptographic random name; creation is required, never open an existing DB.
  final name = 'synthetic-debt-journal-${web.window.crypto.randomUUID()}';
  final request = web.window.indexedDB.open(name, 1);
  final done = Completer<web.IDBDatabase>();
  var created = false;
  request.onupgradeneeded = ((web.Event _) {
    final raw = request.result;
    if (raw == null || !raw.isA<web.IDBDatabase>()) {
      request.transaction?.abort();
      return;
    }
    final database = raw as web.IDBDatabase;
    database.createObjectStore(_storeName);
    created = true;
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final raw = request.result;
    if (raw == null || !raw.isA<web.IDBDatabase>()) {
      if (!done.isCompleted) done.completeError(StateError('invalid synthetic DB'));
      return;
    }
    final database = raw as web.IDBDatabase;
    if (done.isCompleted) { database.close(); return; }
    if (!created) {
      database.close();
      if (!done.isCompleted) done.completeError(StateError('refusing existing DB'));
      return;
    }
    if (!done.isCompleted) done.complete(database);
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('synthetic open blocked'));
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('synthetic open failed'));
  }).toJS;
  return done.future;
}

Future<void> _putSyntheticRaw(web.IDBDatabase db, DebtScope scope, String value) {
  final done = Completer<void>();
  final tx = db.transaction(_storeName.toJS, 'readwrite',
      web.IDBTransactionOptions(durability: 'strict'));
  tx.oncomplete = ((web.Event _) { if (!done.isCompleted) done.complete(); }).toJS;
  tx.onabort = ((web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('synthetic raw abort'));
  }).toJS;
  tx.objectStore(_storeName).put(value.toJS, jsonEncode(<String>[scope.kind, scope.id]).toJS);
  return done.future;
}

Future<String?> _getSyntheticRaw(web.IDBDatabase db, DebtScope scope) {
  final done = Completer<String?>();
  final tx = db.transaction(_storeName.toJS, 'readonly');
  String? observed;
  final request = tx.objectStore(_storeName).get(jsonEncode(<String>[scope.kind, scope.id]).toJS);
  request.onsuccess = ((web.Event _) {
    final raw = request.result;
    if (raw != null && raw.isA<JSString>()) observed = (raw as JSString).toDart;
  }).toJS;
  tx.oncomplete = ((web.Event _) { if (!done.isCompleted) done.complete(observed); }).toJS;
  tx.onabort = ((web.Event _) {
    if (!done.isCompleted) done.completeError(StateError('synthetic read abort'));
  }).toJS;
  return done.future;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late web.IDBDatabase db;
  late IndexedDbSyntheticFaults faults;
  late IndexedDbDebtStoreDraft store;

  setUp(() async {
    db = await _openSyntheticDatabase();
    faults = IndexedDbSyntheticFaults();
    store = IndexedDbDebtStoreDraft(database: db, objectStoreName: _storeName,
        syntheticFaults: faults);
  });
  tearDown(() { db.close(); });

  test('synthetic prepare, commit, acknowledge and new version', () async {
    var nextId = 0;
    final journal = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-${++nextId}');
    final first = await journal.setDay(key: 'synthetic-debt', day: 10,
        editedAt: _time, allowNewWorkspace: true);
    final marker = await journal.inspectUnresolved();
    expect(marker!.phase, DurablePhase.committed);
    expect(marker.proposed.values['synthetic-debt'], 10);
    await journal.acknowledgeObserved(first);
    final second = await journal.setDay(key: 'synthetic-debt', day: 20, editedAt: _time);
    expect(second.version, 2);
    final state = await store.readSnapshot(_a, journal.fence);
    expect(state.read.envelope!.values['synthetic-debt'], 20);
    expect(state.read.envelope!.dirtyRevisions['synthetic-debt'], 2);
  });

  test('abort after synthetic put is failure and prepared intent remains', () async {
    final journal = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-abort');
    faults.abortAfterPut.add('commit');
    await expectLater(journal.setDay(key: 'synthetic-debt', day: 10,
        editedAt: _time, allowNewWorkspace: true), throwsA(isA<DebtJournalException>()));
    final after = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-next');
    expect((await after.inspectUnresolved())!.phase, DurablePhase.prepared);
    final state = await store.readSnapshot(_a, after.fence);
    expect(state.read.kind, DebtReadKind.absent);
  });

  test('lost completion is unknown and committed marker survives reopen', () async {
    final journal = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-unknown');
    faults.loseCompletion.add('commit');
    await expectLater(journal.setDay(key: 'synthetic-debt', day: 10,
        editedAt: _time, allowNewWorkspace: true), throwsA(isA<DebtJournalException>()));
    final after = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-next');
    final marker = await after.inspectUnresolved();
    expect(marker!.phase, DurablePhase.committed);
    expect(marker.proposed.values['synthetic-debt'], 10);
    await expectLater(after.setDay(key: 'synthetic-debt', day: 20, editedAt: _time),
        throwsA(isA<DebtJournalException>()));
  });

  test('new fence rejects old writer and does not affect another owner', () async {
    final old = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-old');
    final next = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-new');
    final other = await DurableDebtJournal.open(store: store, scope: _b,
        newOperationId: () => 'synthetic-other');
    await other.setDay(key: 'synthetic-debt', day: 20, editedAt: _time,
        allowNewWorkspace: true);
    await expectLater(old.setDay(key: 'synthetic-debt', day: 10, editedAt: _time,
        allowNewWorkspace: true), throwsA(isA<DebtJournalException>()));
    expect((await store.readSnapshot(_b, other.fence)).read.envelope!.values['synthetic-debt'], 20);
    expect((await store.readSnapshot(_a, next.fence)).read.kind, DebtReadKind.absent);
  });

  test('duplicate ID is rejected and prior committed data is retained', () async {
    final journal = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-duplicate');
    final first = await journal.setDay(key: 'synthetic-debt', day: 10,
        editedAt: _time, allowNewWorkspace: true);
    await journal.acknowledgeObserved(first);
    await expectLater(journal.setDay(key: 'synthetic-debt', day: 20, editedAt: _time),
        throwsA(isA<DebtJournalException>()));
    expect((await store.readSnapshot(_a, journal.fence)).read.envelope!.values['synthetic-debt'], 10);
  });

  test('malformed record causes abort and is not replaced', () async {
    await _putSyntheticRaw(db, _a, 'synthetic-invalid-json');
    await expectLater(store.acquireFence(_a), throwsA(anything));
    expect(await _getSyntheticRaw(db, _a), 'synthetic-invalid-json');
    // This does not inspect legacy or any other database.
  });
  test('aborted ack preserves committed marker and dirty', () async {
    final journal = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-ack-abort');
    final receipt = await journal.setDay(key: 'synthetic-debt', day: 10,
        editedAt: _time, allowNewWorkspace: true);
    faults.abortAfterPut.add('ack');
    await expectLater(journal.acknowledgeObserved(receipt),
        throwsA(isA<DebtJournalException>()));
    final after = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-next');
    final marker = await after.inspectUnresolved();
    expect(marker!.phase, DurablePhase.committed);
    expect((await store.readSnapshot(_a, after.fence)).read.envelope!
        .dirtyRevisions['synthetic-debt'], 1);
  });
  test('lost prepare completion preserves prepared marker', () async {
    final first = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-prepare-unknown');
    faults.loseCompletion.add('prepare');
    await expectLater(first.setDay(key: 'synthetic-debt', day: 10,
        editedAt: _time, allowNewWorkspace: true), throwsA(isA<DebtJournalException>()));
    final after = await DurableDebtJournal.open(store: store, scope: _a,
        newOperationId: () => 'synthetic-next');
    expect((await after.inspectUnresolved())!.phase, DurablePhase.prepared);
    expect((await store.readSnapshot(_a, after.fence)).read.kind, DebtReadKind.absent);
  });

  test('fence is checked in the transaction before stale prepare writes', () async {
    final oldFence = await store.acquireFence(_a);
    final nextFence = await store.acquireFence(_a);
    final proposed = DebtEnvelope(scope: _a, version: 1,
      values: const <String, int>{'synthetic-debt': 10},
      tombstones: const <String, DateTime>{},
      dirtyRevisions: const <String, int>{'synthetic-debt': 1}, changedAt: _time);
    final op = DurableOperation(id: 'synthetic-old', baseVersion: null,
        proposed: proposed, phase: DurablePhase.prepared);
    expect(await store.prepare(_a, oldFence, null, op), DurableMutation.fenced);
    final state = await store.readSnapshot(_a, nextFence);
    expect(state.read.kind, DebtReadKind.absent);
    expect(state.latestOperation, isNull);
  });

  test('stale commit cannot change a prepared record after a new fence', () async {
    final oldFence = await store.acquireFence(_a);
    final proposed = DebtEnvelope(scope: _a, version: 1,
      values: const <String, int>{'synthetic-debt': 10},
      tombstones: const <String, DateTime>{},
      dirtyRevisions: const <String, int>{'synthetic-debt': 1}, changedAt: _time);
    final op = DurableOperation(id: 'synthetic-old', baseVersion: null,
        proposed: proposed, phase: DurablePhase.prepared);
    expect(await store.prepare(_a, oldFence, null, op), DurableMutation.applied);
    final nextFence = await store.acquireFence(_a);
    expect(await store.commitPrepared(_a, oldFence, op.id), DurableMutation.fenced);
    final state = await store.readSnapshot(_a, nextFence);
    expect(state.read.kind, DebtReadKind.absent);
    expect(state.latestOperation!.phase, DurablePhase.prepared);
  });
  test('wrong owner payload is rejected without crossing scopes', () async {
    final fence = await store.acquireFence(_a);
    final proposed = DebtEnvelope(scope: _b, version: 1,
      values: const <String, int>{'synthetic-debt': 10},
      tombstones: const <String, DateTime>{},
      dirtyRevisions: const <String, int>{'synthetic-debt': 1}, changedAt: _time);
    final op = DurableOperation(id: 'synthetic-wrong-owner', baseVersion: null,
        proposed: proposed, phase: DurablePhase.prepared);
    expect(await store.prepare(_a, fence, null, op), DurableMutation.rejected);
    final state = await store.readSnapshot(_a, fence);
    expect(state.latestOperation, isNull);
    expect(state.read.kind, DebtReadKind.absent);
  });
}
