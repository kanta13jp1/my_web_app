// Synthetic single-isolate model only. Not a storage adapter or production code.
// No I/O, auth, real transactions, timing or crash durability are implemented.
const int maxSafeGeneration = 9007199254740991;

bool _mapEqual<K, V>(Map<K, V> a, Map<K, V> b) =>
    a.length == b.length && a.keys.every((k) => b.containsKey(k) && a[k] == b[k]);
bool _setEqual<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
bool _listEqual<T>(List<T> a, List<T> b) =>
    a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);

class ScopeState {
  ScopeState({required this.owner, required this.version, required this.counter,
    required this.values, required this.deleted, required this.generations,
    required this.dirty, required this.mutationIds, required this.timestamp,
    required this.journal});
  final String owner;
  int version, counter, timestamp;
  final Map<String, int> values, generations, dirty;
  final Set<String> deleted;
  final Map<String, String> mutationIds;
  final List<String> journal;

  ScopeState copy() => ScopeState(owner: owner, version: version, counter: counter,
      values: Map.of(values), deleted: Set.of(deleted),
      generations: Map.of(generations), dirty: Map.of(dirty),
      mutationIds: Map.of(mutationIds), timestamp: timestamp,
      journal: List.of(journal));
  bool same(ScopeState b) => owner == b.owner && version == b.version &&
      counter == b.counter && timestamp == b.timestamp &&
      _mapEqual(values, b.values) && _setEqual(deleted, b.deleted) &&
      _mapEqual(generations, b.generations) && _mapEqual(dirty, b.dirty) &&
      _mapEqual(mutationIds, b.mutationIds) && _listEqual(journal, b.journal);
  bool get valid {
    final keys = {...values.keys, ...deleted};
    return owner.isNotEmpty && version >= 0 && version <= maxSafeGeneration && timestamp >= 0 &&
        counter >= 0 && counter <= maxSafeGeneration &&
        keys.every((k) => k.isNotEmpty && generations.containsKey(k)) &&
        values.entries.every((e) => e.value >= 1 && e.value <= 31 && !deleted.contains(e.key)) &&
        generations.keys.toSet().difference(keys).isEmpty &&
        generations.values.every((g) => g > 0 && g <= counter) &&
        generations.values.toSet().length == generations.length &&
        _setEqual(generations.keys.toSet(), keys) &&
        _setEqual(mutationIds.keys.toSet(), keys) &&
        mutationIds.values.every((id) => id.isNotEmpty && journal.contains(id)) &&
        dirty.entries.every((e) => generations[e.key] == e.value) &&
        journal.every((s) => s.isNotEmpty) && journal.toSet().length == journal.length;
  }
}

abstract class Intent {
  const Intent(this.key, this.capturedOwner, this.capturedEpoch);
  final String key;
  final String capturedOwner;
  final int capturedEpoch;
}
class Edit extends Intent {
  const Edit(super.key, this.value, this.operationId, this.time, super.capturedOwner, super.capturedEpoch);
  final int value, time;
  final String operationId;
}
class Delete extends Intent {
  const Delete(super.key, this.operationId, this.time, super.capturedOwner, super.capturedEpoch);
  final String operationId;
  final int time;
}
class Ack extends Intent {
  const Ack(String key, this.generation, this.operationId, this.value, this.isDeleted, this.receiptOwner, this.receiptEpoch) : super(key, receiptOwner, receiptEpoch);
  final int generation;
  final String operationId;
  final int? value;
  final bool isDeleted;
  final String receiptOwner;
  final int receiptEpoch;
}

enum Result { committed, conflict, invalid, candidateCorrupt, duplicate }
typedef CandidateFault = void Function(ScopeState candidate);

// This sync fake is serialized by a single Dart call stack. Production MUST
// implement read/compare/derive/validate/write in one genuine transaction.
class AtomicIntentFake {
  AtomicIntentFake(ScopeState a, ScopeState b) : _states = {a.owner: a.copy(), b.owner: b.copy()};
  final Map<String, ScopeState> _states;
  int writes = 0;
  // Session epoch is only an in-memory test model, never real authentication.
  String activeOwner = 'a';
  int authEpoch = 1;
  void switchOwner(String owner) { activeOwner = owner; authEpoch++; }
  ScopeState read(String owner) => _states[owner]!.copy();

  Result apply(String owner, ScopeState expectedBase, Intent intent, {CandidateFault? fault}) {
    final base = _states[owner];
    if (base == null || owner != activeOwner || owner != expectedBase.owner || !base.same(expectedBase)) return Result.conflict;
    if (intent.capturedOwner != owner || intent.capturedEpoch != authEpoch) return Result.conflict;
    if (!base.valid || base.version >= maxSafeGeneration || intent.key.isEmpty) return Result.invalid;
    final candidate = base.copy();
    if (intent is Ack) {
      final k = intent.key;
      final present = base.values.containsKey(k) || base.deleted.contains(k);
      if (intent.receiptOwner != owner || intent.receiptEpoch != authEpoch ||
          !present || base.generations[k] != intent.generation ||
          base.dirty[k] != intent.generation || base.mutationIds[k] != intent.operationId ||
          base.deleted.contains(k) != intent.isDeleted || base.values[k] != intent.value) {
        return Result.conflict;
      }
      candidate.dirty.remove(k);
      candidate.version++;
    } else if (intent is Edit || intent is Delete) {
      final id = intent is Edit ? intent.operationId : (intent as Delete).operationId;
      final time = intent is Edit ? intent.time : (intent as Delete).time;
      if (id.isEmpty || time < base.timestamp || base.counter >= maxSafeGeneration ||
          (intent is Edit && (intent.value < 1 || intent.value > 31))) return Result.invalid;
      if (base.journal.contains(id)) return Result.duplicate;
      candidate.counter++;
      candidate.version++;
      candidate.timestamp = time;
      candidate.generations[intent.key] = candidate.counter;
      candidate.dirty[intent.key] = candidate.counter;
      candidate.mutationIds[intent.key] = id;
      candidate.journal.add(id);
      if (intent is Edit) {
        candidate.deleted.remove(intent.key);
        candidate.values[intent.key] = intent.value;
      } else {
        candidate.values.remove(intent.key);
        candidate.deleted.add(intent.key);
      }
    } else {
      return Result.invalid;
    }
    // Reference proposal derived directly from the current transaction base.
    // The fault hook models a defective candidate before put; complete state
    // must equal the reference, not merely pass structural validity.
    final expected = candidate.copy();
    fault?.call(candidate);
    // Synchronous model of a transaction-bound fence and base check directly
    // before put. Real IDB must provide atomic enforcement across isolates.
    final current = _states[owner];
    if (current == null || owner != activeOwner ||
        intent.capturedOwner != owner || intent.capturedEpoch != authEpoch ||
        !current.same(base)) return Result.conflict;
    if (!candidate.valid || !candidate.same(expected)) return Result.candidateCorrupt;
    _states[owner] = candidate.copy();
    writes++;
    return Result.committed;
  }
}
