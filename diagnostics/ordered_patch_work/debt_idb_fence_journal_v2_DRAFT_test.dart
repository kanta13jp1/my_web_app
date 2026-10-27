@TestOn('browser')
library;
// SYNTHETIC BROWSER FIXTURE, NOT RUN. Disposable profile/origin required.
// --dart-define=DEBT_FENCE_SYNTHETIC=true. No database deletion.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'debt_idb_fence_journal_v2_DRAFT.dart';

const _enabled = bool.fromEnvironment('DEBT_FENCE_SYNTHETIC');
const _a = 'synthetic-owner-A';
const _b = 'synthetic-owner-B';

Future<web.IDBDatabase> _openNewSyntheticDb() {
  final host = Uri.base.host;
  if (!_enabled || (host != 'localhost' && host != '127.0.0.1')) {
    throw StateError('disposable local test origin and opt-in required');
  }
  final name = 'synthetic-debt-fence-${web.window.crypto.randomUUID()}';
  final request = web.window.indexedDB.open(name, 1);
  final result = Completer<web.IDBDatabase>();
  var created = false;
  request.onupgradeneeded = ((web.Event _) {
    final raw = request.result;
    if (raw == null || !raw.isA<web.IDBDatabase>()) {
      request.transaction?.abort();
      return;
    }
    (raw as web.IDBDatabase).createObjectStore(fenceProbeStore);
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
      !name.startsWith('synthetic-debt-fence-')) {
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

Map<String,dynamic> _expectedA(String id) => {
  'owner':_a,'version':1,'counter':1,'values':{'synthetic-p':20},
  'deleted':<String,dynamic>{},'generations':{'synthetic-p':1},
  'dirty':{'synthetic-p':1},'usedIds':[id],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late web.IDBDatabase db;
  late FenceFaults faults;
  late SyntheticFenceJournal journal;
  setUp(() async {
    db = await _openNewSyntheticDb();
    faults = FenceFaults(); journal = SyntheticFenceJournal(db, faults:faults);
    expect(await journal.initializeFreshFixture(_a), isTrue);
    expect(await journal.initializeFreshFixture(_b), isTrue);
  });
  tearDown(() { db.close(); });

  test('recreated connection increments persistent fence and rejects old token', () async {
    final old = await journal.acquire(_a);
    final second = await _openSecondConnection(db);
    try {
      final recreated = SyntheticFenceJournal(second);
      final fresh = await recreated.acquire(_a);
      expect(fresh.fence, greaterThan(old.fence));
      expect(await journal.prepare(old,0,'synthetic-old','synthetic-p',20), isFalse);
      expect(await recreated.prepare(fresh,0,'synthetic-new','synthetic-p',20), isTrue);
      final state = await recreated.inspect(_a);
      expect((state['pending'] as Map)['id'],'synthetic-new');
      expect(state['version'],0);
    } finally { second.close(); }
  });
  test('commit unknown blocks same owner across recreation while B works', () async {
    final a = await journal.acquire(_a); final b = await journal.acquire(_b);
    expect(await journal.prepare(a,0,'synthetic-a','synthetic-p',20), isTrue);
    faults.loseCommitCompletion = true;
    await expectLater(journal.commit(a,0,'synthetic-a'),
      throwsA(isA<FenceError>().having((e) => e.code,'code','unknown_after_complete')));
    final second = await _openSecondConnection(db);
    try {
      final recreated = SyntheticFenceJournal(second);
      final a2 = await recreated.acquire(_a);
      expect(await recreated.prepare(a2,1,'synthetic-next','synthetic-p',12),isFalse);
      expect(await journal.prepare(b,0,'synthetic-b','synthetic-q',9),isTrue);
      expect(await journal.commit(b,0,'synthetic-b'),isTrue);
      final observed = await recreated.inspect(_a);
      expect((observed['pending'] as Map)['phase'],'committed');
      expect((observed['dirty'] as Map)['synthetic-p'],1);
      final wrong = _expectedA('synthetic-a'); wrong['counter']=2;
      expect(await recreated.reconcile(a2,'synthetic-a','synthetic-p',20,0,wrong),isFalse);
      expect(await recreated.prepare(a2,1,'synthetic-next','synthetic-p',12),isFalse);
      expect(await recreated.reconcile(a2,'synthetic-a','synthetic-p',20,0,_expectedA('synthetic-a')),isTrue);
      final after = await recreated.inspect(_a);
      expect((after['pending'] as Map)['phase'],'observed');
      expect((after['dirty'] as Map)['synthetic-p'],1);
      expect(await recreated.prepare(a2,1,'synthetic-next','synthetic-p',12),isFalse);
      final a3 = await recreated.acquire(_a);
      expect(await recreated.prepare(a3,1,'synthetic-next','synthetic-p',12,
        previousId:'synthetic-a',previousExpected:_expectedA('synthetic-a')),isTrue);
    } finally { second.close(); }
  });
  test('prepared marker survives fence rotation and cannot be auto committed', () async {
    final old = await journal.acquire(_a);
    expect(await journal.prepare(old,0,'synthetic-a','synthetic-p',20),isTrue);
    final recreated = SyntheticFenceJournal(db); final fresh = await recreated.acquire(_a);
    expect(await journal.commit(old,0,'synthetic-a'),isFalse);
    expect(await recreated.commit(fresh,0,'synthetic-a'),isFalse);
    expect(await recreated.prepare(fresh,0,'synthetic-next','synthetic-p',10),isFalse);
    final state = await recreated.inspect(_a);
    expect((state['pending'] as Map)['phase'],'prepared'); expect(state['version'],0);
    final retained = (await recreated.recoverPrepared(fresh))!;
    expect(retained['id'],'synthetic-a'); expect(retained['key'],'synthetic-p');
    expect(retained['value'],20); expect(retained['baseVersion'],0);
  });
  test('wrong owner cannot reconcile identical operation and leaves both scopes intact', () async {
    final a = await journal.acquire(_a); final b = await journal.acquire(_b);
    expect(await journal.prepare(a,0,'synthetic-a','synthetic-p',20),isTrue);
    expect(await journal.commit(a,0,'synthetic-a'),isTrue);
    expect(await journal.prepare(b,0,'synthetic-a','synthetic-p',20),isTrue);
    expect(await journal.commit(b,0,'synthetic-a'),isTrue);
    final b2 = await journal.acquire(_b);
    final beforeA = await journal.inspect(_a); final beforeB = await journal.inspect(_b);
    expect(await journal.reconcile(b2,'synthetic-a','synthetic-p',20,0,_expectedA('synthetic-a')),isFalse);
    expect(await journal.inspect(_a),beforeA); expect(await journal.inspect(_b),beforeB);
  });
  test('wrong version and reused operation ID do not change scope', () async {
    final a = await journal.acquire(_a);
    expect(await journal.prepare(a,1,'synthetic-a','synthetic-p',20),isFalse);
    expect(await journal.prepare(a,0,'synthetic-a','synthetic-p',20),isTrue);
    expect(await journal.commit(a,1,'synthetic-a'),isFalse);
    expect(await journal.commit(a,0,'synthetic-a'),isTrue);
    final a2 = await journal.acquire(_a);
    expect(await journal.reconcile(a2,'synthetic-a','synthetic-p',20,0,_expectedA('synthetic-a')),isTrue);
    final a3 = await journal.acquire(_a); final before = await journal.inspect(_a);
    expect(await journal.prepare(a3,1,'synthetic-a','synthetic-p',22,
      previousId:'synthetic-a',previousExpected:_expectedA('synthetic-a')),isFalse);
    expect(await journal.inspect(_a),before);
  });
  test('tombstone is preserved and reconciliation never clears dirty', () async {
    final a = await journal.acquire(_a);
    expect(await journal.prepare(a,0,'synthetic-delete','synthetic-p',null),isTrue);
    expect(await journal.commit(a,0,'synthetic-delete'),isTrue);
    final expected = <String,dynamic>{'owner':_a,'version':1,'counter':1,
      'values':<String,dynamic>{},'deleted':{'synthetic-p':true},
      'generations':{'synthetic-p':1},'dirty':{'synthetic-p':1},'usedIds':['synthetic-delete']};
    final fresh = await journal.acquire(_a);
    expect(await journal.reconcile(fresh,'synthetic-delete','synthetic-p',null,0,expected),isTrue);
    final state = await journal.inspect(_a);
    expect((state['deleted'] as Map)['synthetic-p'],isTrue);
    expect((state['dirty'] as Map)['synthetic-p'],1);
  });
  test('suppressed terminal observation times out and marker remains blocking', () async {
    final short = SyntheticFenceJournal(db, faults:faults, settlementTimeout:const Duration(milliseconds:80));
    final a = await short.acquire(_a);
    expect(await short.prepare(a,0,'synthetic-a','synthetic-p',20),isTrue);
    faults.suppressCommitTerminal = true;
    await expectLater(short.commit(a,0,'synthetic-a'),
      throwsA(isA<FenceError>().having((e) => e.code,'code','settlement_unknown')));
    final resumed = SyntheticFenceJournal(db); final fresh = await resumed.acquire(_a);
    expect(await resumed.prepare(fresh,1,'synthetic-next','synthetic-p',12),isFalse);
    final observed = await resumed.inspect(_a);
    expect((observed['pending'] as Map)['phase'],'committed');
    expect((observed['dirty'] as Map)['synthetic-p'],1);
  });
  test('reconcile requires fence newer than prepared commit', () async {
    final a = await journal.acquire(_a);
    expect(await journal.prepare(a,0,'synthetic-a','synthetic-p',20),isTrue);
    expect(await journal.commit(a,0,'synthetic-a'),isTrue);
    expect(await journal.reconcile(a,'synthetic-a','synthetic-p',20,0,_expectedA('synthetic-a')),isFalse);
    final state = await journal.inspect(_a);
    expect((state['pending'] as Map)['phase'],'committed');
  });
  test('unknown reconcile keeps observed marker until fresh-fence next prepare', () async {
    final a = await journal.acquire(_a);
    expect(await journal.prepare(a,0,'synthetic-a','synthetic-p',20),isTrue);
    expect(await journal.commit(a,0,'synthetic-a'),isTrue);
    final a2 = await journal.acquire(_a); faults.loseReconcileCompletion=true;
    await expectLater(journal.reconcile(a2,'synthetic-a','synthetic-p',20,0,_expectedA('synthetic-a')),
      throwsA(isA<FenceError>().having((e) => e.code,'code','unknown_after_complete')));
    final state = await journal.inspect(_a);
    expect((state['pending'] as Map)['phase'],'observed');
    expect(await journal.prepare(a2,1,'synthetic-next','synthetic-p',12,
      previousId:'synthetic-a',previousExpected:_expectedA('synthetic-a')),isFalse);
    final a3 = await journal.acquire(_a);
    expect(await journal.prepare(a3,1,'synthetic-next','synthetic-p',12),isFalse);
    expect(await journal.prepare(a3,1,'synthetic-next','synthetic-p',12,
      previousId:'synthetic-a',previousExpected:_expectedA('synthetic-a')),isTrue);
    final after = await journal.inspect(_a);
    expect((after['pending'] as Map)['id'],'synthetic-next');
    expect((after['pending'] as Map)['phase'],'prepared');
    expect((after['dirty'] as Map)['synthetic-p'],1);
  });
  test('unknown prepare retains recoverable input and does not replay after fresh fence', () async {
    final a = await journal.acquire(_a); faults.losePrepareCompletion=true;
    await expectLater(journal.prepare(a,0,'synthetic-a','synthetic-p',20),
      throwsA(isA<FenceError>().having((e) => e.code,'code','unknown_after_complete')));
    final fresh = await journal.acquire(_a);
    final retained = (await journal.recoverPrepared(fresh))!;
    expect(retained['owner'],_a); expect(retained['id'],'synthetic-a');
    expect(retained['key'],'synthetic-p'); expect(retained['value'],20);
    expect(retained['baseVersion'],0); expect(retained['phase'],'prepared');
    expect(await journal.commit(fresh,0,'synthetic-a'),isFalse);
    expect(await journal.prepare(fresh,0,'synthetic-next','synthetic-p',12),isFalse);
  });
  test('64 retained operation IDs stop safely and report limit', () async {
    var token = await journal.acquire(_a);
    var prior = <String,dynamic>{}; String? priorId;
    final ids = <String>[];
    for (var i=0;i<64;i++) {
      final id = 'synthetic-op-$i'; final value = i % 31 + 1;
      expect(await journal.prepare(token,i,id,'synthetic-p',value,
        previousId:priorId,previousExpected:priorId == null ? null : prior),isTrue);
      expect(await journal.commit(token,i,id),isTrue);
      ids.add(id);
      prior = {'owner':_a,'version':i+1,'counter':i+1,
        'values':{'synthetic-p':value},'deleted':<String,dynamic>{},
        'generations':{'synthetic-p':i+1},'dirty':{'synthetic-p':i+1},
        'usedIds':List<String>.of(ids)};
      token = await journal.acquire(_a);
      expect(await journal.reconcile(token,id,'synthetic-p',value,i,prior),isTrue);
      priorId = id;
      token = await journal.acquire(_a);
    }
    final before = await journal.inspect(_a);
    expect(await journal.capacity(token),'journal_limit');
    expect(await journal.prepare(token,64,'synthetic-over','synthetic-p',12,
      previousId:priorId,previousExpected:prior),isFalse);
    final after = await journal.inspect(_a);
    expect(after,before); expect((after['usedIds'] as List).length,64);
    expect((after['pending'] as Map)['phase'],'observed');
    expect((after['dirty'] as Map)['synthetic-p'],64);
  });
}
