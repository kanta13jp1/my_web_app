// Synthetic tests ONLY: no IDB, auth, app, database, or network.
import 'package:flutter_test/flutter_test.dart';
import 'debt_unknown_integrity_intent_v4_DRAFT.dart';

ScopeState makeA() => ScopeState(owner: 'a', version: 7, counter: 6,
  values: {'x':10,'y':20}, deleted: {'z'}, generations: {'x':4,'y':5,'z':6},
  dirty: {'y':5,'z':6}, mutationIds: {'x':'x0','y':'y0','z':'z0'},
  timestamp: 100, journal: ['x0','y0','z0']);
ScopeState makeB() => ScopeState(owner: 'b', version: 1, counter: 1,
  values: {'b':12}, deleted: {}, generations: {'b':1}, dirty: {'b':1},
  mutationIds: {'b':'b0'}, timestamp: 2, journal: ['b0']);

// Independent per-field assertions; never use production ScopeState.same.
void expectAllFields(ScopeState actual, ScopeState expected) {
  expect(actual.owner, expected.owner);
  expect(actual.version, expected.version);
  expect(actual.counter, expected.counter);
  expect(actual.timestamp, expected.timestamp);
  expect(actual.values, equals(expected.values));
  expect(actual.deleted, equals(expected.deleted));
  expect(actual.generations, equals(expected.generations));
  expect(actual.dirty, equals(expected.dirty));
  expect(actual.mutationIds, equals(expected.mutationIds));
  expect(actual.journal, equals(expected.journal));
}

void main() {
  late AtomicIntentFake db;
  setUp(() { db = AtomicIntentFake(makeA(), makeB()); });
  test('edit derives candidate from base and preserves unrelated state and owner', () {
    final b = db.read('b');
    expect(db.apply('a', db.read('a'), const Edit('x',11,'new',101,'a',1)), Result.committed);
    final a = db.read('a');
    expect(a.values, {'x':11,'y':20});
    expect(a.deleted, {'z'});
    expect(a.generations, {'x':7,'y':5,'z':6});
    expect(a.dirty, {'x':7,'y':5,'z':6});
    expect(a.mutationIds, {'x':'new','y':'y0','z':'z0'});
    expect(a.journal, ['x0','y0','z0','new']);
    expect(a.version, 8); expect(a.counter, 7); expect(a.timestamp, 101);
    expectAllFields(db.read('b'), b);
  });
  for (final component in ['value','tombstone','dirty','generation','journal']) {
    test('faulted candidate missing other $component is rejected before write', () {
      final before = db.read('a'); final b = db.read('b');
      final result = db.apply('a', before, const Edit('x',11,'new',101,'a',1), fault: (c) {
        switch (component) {
          case 'value': c.values.remove('y'); break;
          case 'tombstone': c.deleted.remove('z'); break;
          case 'dirty': c.dirty.remove('y'); break;
          case 'generation': c.generations['y'] = 4; break;
          case 'journal': c.journal.remove('y0'); break;
        }
      });
      expect(result, Result.candidateCorrupt); expect(db.writes, 0);
      expectAllFields(db.read('a'), before); expectAllFields(db.read('b'), b);
    });
  }
  for (final generation in [4, 6]) {
    test('reused generation $generation is rejected atomically', () {
      final before = db.read('a');
      final result = db.apply('a', before, const Edit('x',11,'new',101,'a',1), fault: (c) {
        c.generations['x'] = generation; c.dirty['x'] = generation; c.counter = generation;
      });
      expect(result, Result.candidateCorrupt); expect(db.writes, 0);
      expectAllFields(db.read('a'), before);
    });
  }
  test('stale base conflicts and preserves newer different key and pending intent', () {
    final stale = db.read('a');
    expect(db.apply('a', stale, const Edit('y',21,'b1',101,'a',1)), Result.committed);
    final afterB = db.read('a'); final pending = const Edit('x',11,'a1',102,'a',1);
    expect(db.apply('a', stale, pending), Result.conflict);
    expect(db.writes, 1); expectAllFields(db.read('a'), afterB);
    expect(pending.value, 11);
  });
  test('same version but different data is rejected', () {
    final invalidBase = db.read('a'); invalidBase.values['y'] = 19;
    final before = db.read('a');
    expect(db.apply('a', invalidBase, const Edit('x',11,'new',101,'a',1)), Result.conflict);
    expect(db.writes, 0); expectAllFields(db.read('a'), before);
  });
  test('delete then recreate prevents old deletion acknowledgement', () {
    expect(db.apply('a', db.read('a'), const Delete('x','del',101,'a',1)), Result.committed);
    expect(db.apply('a', db.read('a'), const Edit('x',12,'recreate',102,'a',1)), Result.committed);
    final before = db.read('a');
    expect(db.apply('a', before, const Ack('x',7,'del',null,true,'a',1)), Result.conflict);
    expectAllFields(db.read('a'), before);
    expect(before.generations['x'], 8); expect(before.dirty['x'], 8);
  });
  test('ack deletes only matching dirty and preserves tombstone and other keys', () {
    final before = db.read('a');
    expect(db.apply('a', before, const Ack('z',6,'z0',null,true,'a',1)), Result.committed);
    final after = db.read('a'); before.dirty.remove('z'); before.version++;
    expectAllFields(after, before); expect(after.deleted, contains('z'));
  });
  test('owner B cannot acknowledge owner A operation', () {
    final a = db.read('a'); final b = db.read('b');
    db.switchOwner('b');
    expect(db.apply('b', b, const Ack('z',6,'z0',null,true,'a',1)), Result.conflict);
    expectAllFields(db.read('a'), a); expectAllFields(db.read('b'), b);
  });
  test('generation overflow and invalid value preserve base', () {
    final a = makeA()..counter = maxSafeGeneration;
    final fake = AtomicIntentFake(a, makeB());
    expect(fake.apply('a', a.copy(), const Edit('x',11,'over',101,'a',1)), Result.invalid);
    expectAllFields(fake.read('a'), a); expect(fake.writes, 0);
    final before = db.read('a');
    expect(db.apply('a', before, const Edit('x',32,'invalid',101,'a',1)), Result.invalid);
    expectAllFields(db.read('a'), before); expect(db.writes, 0);
  });
  test('duplicate operation id is rejected without changes', () {
    final before = db.read('a');
    expect(db.apply('a', before, const Edit('x',11,'x0',101,'a',1)), Result.duplicate);
    expectAllFields(db.read('a'), before); expect(db.writes, 0);
  });
  test('A receipt cannot clear identical B key generation ID and value', () {
    final a = makeA();
    final b = ScopeState(owner:'b', version:a.version, counter:a.counter,
      values:Map.of(a.values), deleted:Set.of(a.deleted),
      generations:Map.of(a.generations), dirty:Map.of(a.dirty),
      mutationIds:Map.of(a.mutationIds), timestamp:a.timestamp, journal:List.of(a.journal));
    final sameIds = AtomicIntentFake(a,b);
    final beforeA = sameIds.read('a'); final beforeB = sameIds.read('b');
    final receiptA = const Ack('y',5,'y0',20,false,'a',1);
    sameIds.switchOwner('b');
    expect(sameIds.apply('b', beforeB, receiptA), Result.conflict);
    // Same current epoch isolates owner mismatch from the epoch guard.
    final forgedOwner = Ack('y',5,'y0',20,false,'a',sameIds.authEpoch);
    expect(sameIds.apply('b', beforeB, forgedOwner), Result.conflict);
    expectAllFields(sameIds.read('a'), beforeA);
    expectAllFields(sameIds.read('b'), beforeB);
    expect(sameIds.writes, 0);
  });
  test('A B A session change rejects old A receipt with identical state', () {
    final before = db.read('a');
    final receiptA = const Ack('y',5,'y0',20,false,'a',1);
    db.switchOwner('b'); db.switchOwner('a');
    expect(db.apply('a', before, receiptA), Result.conflict);
    expectAllFields(db.read('a'), before); expect(db.writes, 0);
  });
  test('delete result equals independent whole-record oracle', () {
    final expected = ScopeState(owner:'a', version:8, counter:7,
      values:{'y':20}, deleted:{'x','z'}, generations:{'x':7,'y':5,'z':6},
      dirty:{'x':7,'y':5,'z':6}, mutationIds:{'x':'del','y':'y0','z':'z0'},
      timestamp:101, journal:['x0','y0','z0','del']);
    final b = db.read('b');
    expect(db.apply('a', db.read('a'), const Delete('x','del',101,'a',1)), Result.committed);
    expectAllFields(db.read('a'), expected); expectAllFields(db.read('b'), b);
  });
  test('ack result equals independent whole-record oracle', () {
    final expected = ScopeState(owner:'a', version:8, counter:6,
      values:{'x':10,'y':20}, deleted:{'z'}, generations:{'x':4,'y':5,'z':6},
      dirty:{'y':5}, mutationIds:{'x':'x0','y':'y0','z':'z0'},
      timestamp:100, journal:['x0','y0','z0']);
    expect(db.apply('a', db.read('a'), const Ack('z',6,'z0',null,true,'a',1)), Result.committed);
    expectAllFields(db.read('a'), expected);
  });
  for (final action in ['delete','ack']) {
    test('$action candidate multiple unrelated losses cannot commit', () {
      final before = db.read('a'); final b = db.read('b');
      final Intent intent = action == 'delete' ? const Delete('x','del',101,'a',1)
          : const Ack('y',5,'y0',20,false,'a',1);
      final result = db.apply('a', before, intent, fault:(candidate) {
        candidate.values.remove('y'); candidate.deleted.remove('z');
        candidate.dirty.remove('z'); candidate.journal.remove('z0');
      });
      expect(result, Result.candidateCorrupt); expect(db.writes, 0);
      expectAllFields(db.read('a'), before); expectAllFields(db.read('b'), b);
    });
  }
  for (final action in ['edit','delete']) {
    test('old A $action rejected after A B A with unchanged base', () {
      final before = db.read('a'); final b = db.read('b');
      final Intent old = action == 'edit' ? const Edit('x',11,'late',101,'a',1)
          : const Delete('x','late',101,'a',1);
      db.switchOwner('b'); db.switchOwner('a');
      expect(db.apply('a', before, old), Result.conflict);
      expectAllFields(db.read('a'), before); expectAllFields(db.read('b'), b);
      expect(db.writes, 0); expect(old.key, 'x');
    });
    test('old A $action rejected against identical B with current epoch', () {
      final a = makeA();
      final b = ScopeState(owner:'b', version:a.version, counter:a.counter,
        values:Map.of(a.values), deleted:Set.of(a.deleted),
        generations:Map.of(a.generations), dirty:Map.of(a.dirty),
        mutationIds:Map.of(a.mutationIds), timestamp:a.timestamp, journal:List.of(a.journal));
      final isolated = AtomicIntentFake(a,b); isolated.switchOwner('b');
      final beforeA = isolated.read('a'); final beforeB = isolated.read('b');
      // Force same current epoch to isolate the captured-owner guard.
      final Intent misdelivered = action == 'edit'
          ? Edit('x',11,'late',101,'a',isolated.authEpoch)
          : Delete('x','late',101,'a',isolated.authEpoch);
      expect(isolated.apply('b', beforeB, misdelivered), Result.conflict);
      expectAllFields(isolated.read('a'), beforeA);
      expectAllFields(isolated.read('b'), beforeB); expect(isolated.writes, 0);
    });
  }
  test('current owner and epoch permit new intended edit after switch', () {
    db.switchOwner('b'); final a = db.read('a'); final beforeB = db.read('b');
    final fresh = Edit('b',13,'b1',3,'b',db.authEpoch);
    expect(db.apply('b', beforeB, fresh), Result.committed);
    expectAllFields(db.read('a'), a); expect(db.read('b').values['b'], 13);
  });
  for (final transition in ['B','ABA']) {
    test('switch $transition inside candidate hook prevents old A commit', () {
      final beforeA = db.read('a'); final beforeB = db.read('b');
      final intent = const Edit('x',11,'late',101,'a',1);
      final result = db.apply('a', beforeA, intent, fault: (_) {
        db.switchOwner('b');
        if (transition == 'ABA') db.switchOwner('a');
      });
      expect(result, Result.conflict); expect(db.writes, 0);
      expectAllFields(db.read('a'), beforeA); expectAllFields(db.read('b'), beforeB);
      expect(intent.value, 11);
    });
  }
  test('reentrant same-owner newer commit rejects stale candidate', () {
    final before = db.read('a');
    final result = db.apply('a', before, const Edit('x',11,'outer',101,'a',1),
        fault: (_) {
          expect(db.apply('a', before, const Edit('y',21,'inner',101,'a',1)), Result.committed);
        });
    expect(result, Result.conflict); expect(db.writes, 1);
    final expected = ScopeState(owner:'a',version:8,counter:7,
      values:{'x':10,'y':21},deleted:{'z'},generations:{'x':4,'y':7,'z':6},
      dirty:{'y':7,'z':6},mutationIds:{'x':'x0','y':'inner','z':'z0'},
      timestamp:101,journal:['x0','y0','z0','inner']);
    expectAllFields(db.read('a'), expected);
  });
}
