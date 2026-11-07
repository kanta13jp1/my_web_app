import 'dart:convert';
import 'inflow_atomic_core_NONPRODUCTION.dart';

// Synthetic transaction event model only. No IndexedDB, browser or I/O.
// Request success does not touch committed; only fake transactionComplete does.
void check(bool ok, String description) {
  if (!ok) throw StateError('synthetic failure: ' + description);
}

class FakeTransaction {
  FakeTransaction(this.committed);
  final Map<String, String> committed;
  final staged = <String, String>{};
  bool aborted = false;
  bool complete = false;

  void requestPut(String key, String value) {
    if (aborted || complete) throw StateError('bad synthetic ordering');
    staged[key] = value; // fake request success; NOT committed.
  }

  void abort() {
    aborted = true;
    staged.clear();
  }

  void transactionComplete() {
    if (aborted || complete) throw StateError('bad synthetic ordering');
    committed.addAll(staged);
    complete = true;
  }
}

bool fakeValid(String field, String raw) {
  try {
    final value = jsonDecode(raw);
    if (field == 'gc') return value is Map;
    if (field == 'salaryPrompt') return value is bool;
    return fields.contains(field) && value is List;
  } catch (_) {
    return false;
  }
}

void main() {
  final legacy = <String, String>{
    'asset_expected_inflows_v1': 'SYNTHETIC_LEGACY_BYTES',
    'asset_expected_inflow_rules_v1': 'SYNTHETIC_RULE_BYTES',
    'asset_expected_inflow_deleted_ids_v1': 'SYNTHETIC_TOMBSTONE_BYTES',
    'inflow_tombstone_gc_v1': 'SYNTHETIC_GC_BYTES',
    'asset_salary_inflow_prompt_dismissed_v1': 'SYNTHETIC_PROMPT_BYTES',
  };
  final originalLegacy = Map<String, String>.from(legacy);
  final db = <String, String>{
    metaKey('A'): encodeMeta(const Meta('A', 0, 1)),
    metaKey('B'): encodeMeta(const Meta('B', 0, 1)),
    fieldKey('A', 'entries'): '[]',
    fieldKey('A', 'rules'): '[]',
    fieldKey('B', 'entries'): '[2]',
  };
  Decision decideA({
    required int revision,
    required int fence,
    bool current = true,
    bool supported = true,
    bool legacyConfirmed = true,
    Map<String, String> changes = const {'entries':'[1]', 'rules':'[3]'},
  }) => decide(
    owner: 'A', expectedRevision: revision, expectedFence: fence,
    actual: decodeMeta(db[metaKey('A')]!), changes: changes, current: current,
    isolatedSupported: supported, legacyAuthorised: legacyConfirmed,
    validate: fakeValid,
  );

  final first = decideA(revision: 0, fence: 1);
  check(first.kind == DecisionKind.write, 'fresh revision accepted');
  final t1 = FakeTransaction(db);
  t1.requestPut(fieldKey('A', 'entries'), first.changes['entries']!);
  t1.requestPut(fieldKey('A', 'rules'), first.changes['rules']!);
  t1.requestPut(metaKey('A'), encodeMeta(first.meta!));
  check(db[fieldKey('A', 'entries')] == '[]' &&
      db[fieldKey('A', 'rules')] == '[]', 'put success is not commit');
  t1.abort();
  check(db[fieldKey('A', 'entries')] == '[]' &&
      db[fieldKey('A', 'rules')] == '[]' &&
      decodeMeta(db[metaKey('A')]!)!.revision == 0, 'abort rollback in fake');

  final t2 = FakeTransaction(db);
  t2.requestPut(fieldKey('A', 'entries'), first.changes['entries']!);
  t2.requestPut(fieldKey('A', 'rules'), first.changes['rules']!);
  t2.requestPut(metaKey('A'), encodeMeta(first.meta!));
  t2.transactionComplete();
  check(onTransactionComplete(first.kind, true) == CompletionKind.committed,
      'completion yields success');
  check(db[fieldKey('A', 'entries')] == '[1]' &&
      db[fieldKey('A', 'rules')] == '[3]' &&
      decodeMeta(db[metaKey('A')]!)!.revision == 1, 'multi record committed');
  check(db[fieldKey('B', 'entries')] == '[2]' &&
      decodeMeta(db[metaKey('B')]!)!.revision == 0, 'B unaffected');

  check(decideA(revision: 0, fence: 1).kind == DecisionKind.conflict,
      'old revision conflict');
  check(decideA(revision: 1, fence: 0).kind == DecisionKind.conflict,
      'stale fence conflict');
  check(decideA(revision: 1, fence: 1, current: false).kind ==
      DecisionKind.unknown, 'changed owner stops');
  check(decideA(revision: 1, fence: 1, supported: false).kind ==
      DecisionKind.unknown, 'unsupported stops');
  check(decideA(revision: 1, fence: 1, legacyConfirmed: false).kind ==
      DecisionKind.unknown, 'unknown legacy stops');
  check(decideA(revision: 1, fence: 1, changes: {'entries':'broken'}).kind ==
      DecisionKind.unknown, 'bad payload stops');
  check(decideA(revision: 1, fence: 1, changes: {'unknown':'[]'}).kind ==
      DecisionKind.unknown, 'unknown field stops');
  check(decodeMeta('not-json') == null, 'corrupt metadata invalid');
  check(decodeMeta('{"schema":1,"owner":"A","revision":0,"fence":1,"extra":true}') == null,
      'unknown metadata preserved');
  check(onTransactionComplete(DecisionKind.write, false) ==
      CompletionKind.unknown, 'switch after dispatch unknown');
  // Loss of transactionComplete can be simulated as unknown, but this does not
  // simulate a real crash or prove whether an actual commit occurred.
  check(!t1.complete && t1.aborted, 'abort is not success');
  check(db[fieldKey('B', 'entries')] == '[2]', 'B remains unchanged');
  check(jsonEncode(legacy) == jsonEncode(originalLegacy), 'legacy untouched');
  // v2: unknown, never conflict, for invalid safe-integer boundaries.
  Decision boundary({
    required int expectedRevision,
    required int expectedFence,
    required Meta? actual,
  }) => decide(
    owner: 'A', expectedRevision: expectedRevision,
    expectedFence: expectedFence, actual: actual,
    changes: const {'entries':'[]'}, current: true,
    isolatedSupported: true, legacyAuthorised: true, validate: fakeValid,
  );

  for (final invalid in [-1, maxSafeInteger, maxSafeInteger + 1]) {
    check(boundary(expectedRevision: invalid, expectedFence: 1,
        actual: const Meta('A', 0, 1)).kind == DecisionKind.unknown,
        'invalid expected revision stops');
  }
  for (final invalid in [-1, maxSafeInteger + 1]) {
    check(boundary(expectedRevision: 0, expectedFence: invalid,
        actual: const Meta('A', 0, 1)).kind == DecisionKind.unknown,
        'invalid expected fence stops');
    check(boundary(expectedRevision: 0, expectedFence: 1,
        actual: Meta('A', 0, invalid)).kind == DecisionKind.unknown,
        'invalid actual fence stops');
  }
  for (final invalid in [-1, maxSafeInteger, maxSafeInteger + 1]) {
    check(boundary(expectedRevision: 0, expectedFence: 1,
        actual: Meta('A', invalid, 1)).kind == DecisionKind.unknown,
        'invalid actual revision stops');
  }
  final nearLimit = boundary(expectedRevision: maxSafeInteger - 1,
      expectedFence: 1, actual: Meta('A', maxSafeInteger - 1, 1));
  check(nearLimit.kind == DecisionKind.write &&
      nearLimit.meta!.revision == maxSafeInteger, 'last safe revision write');
  final decodedLast = decodeMeta(encodeMeta(nearLimit.meta!));
  check(decodedLast != null && decodedLast.revision == maxSafeInteger,
      'last safe revision can be read');
  check(boundary(expectedRevision: maxSafeInteger, expectedFence: 1,
      actual: decodedLast).kind == DecisionKind.unknown,
      'exhausted revision cannot increment');
  check(boundary(expectedRevision: 0, expectedFence: maxSafeInteger,
      actual: Meta('A', 0, maxSafeInteger)).kind == DecisionKind.write,
      'maximum safe fence is readable and comparable');
  for (final raw in [
    '{"schema":1,"owner":"A","revision":NaN,"fence":1}',
    '{"schema":1,"owner":"A","revision":Infinity,"fence":1}',
    '{"schema":1,"owner":"A","revision":1.5,"fence":1}',
    '{"schema":1,"owner":"A","revision":"0","fence":1}',
    '{"schema":1,"owner":"A","revision":9007199254740992,"fence":1}',
    '{"schema":1,"owner":"A","revision":0,"fence":-1}'
  ]) {
    final badMeta = decodeMeta(raw);
    check(badMeta == null, 'invalid numeric metadata does not decode');
    check(boundary(expectedRevision: 0, expectedFence: 1,
        actual: badMeta).kind == DecisionKind.unknown,
        'invalid metadata stops without write');
  }
  print('synthetic transaction model checks passed');
}