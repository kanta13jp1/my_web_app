// SYNTHETIC DESIGN ONLY. No IndexedDB adapter, auth, product or user data.
// A real atomic/durable fence, write-ahead store and recovery UI do not exist.
import 'dart:collection';

enum ProbePhase { prepared, committed, acknowledged }
enum ProbeStatus { ready, prepared, committed, acknowledged, ambiguous }

class ProbeError implements Exception {
  const ProbeError(this.code);
  final String code;
  @override
  String toString() => 'ProbeError($code)';
}

class ProbePayload {
  ProbePayload({required this.owner, required this.id, required this.baseVersion,
      required this.generation, required Map<String, int> values,
      required Set<String> tombstones, required Map<String, int> dirty})
      : values = UnmodifiableMapView(Map<String, int>.from(values)),
        tombstones = UnmodifiableSetView(Set<String>.from(tombstones)),
        dirty = UnmodifiableMapView(Map<String, int>.from(dirty));
  final String owner;
  final String id;
  final int baseVersion;
  final int generation;
  final Map<String, int> values;
  final Set<String> tombstones;
  final Map<String, int> dirty;
}

class ProbeMarker {
  const ProbeMarker(this.payload, this.phase);
  final ProbePayload payload;
  final ProbePhase phase;
}

class ProbeView {
  ProbeView({required this.owner, required this.fence, required this.version,
    required this.marker, required this.freshProof, required Map<String, int> values,
    required Set<String> tombstones, required Map<String, int> dirty})
      : values = UnmodifiableMapView(Map<String, int>.from(values)),
        tombstones = UnmodifiableSetView(Set<String>.from(tombstones)),
        dirty = UnmodifiableMapView(Map<String, int>.from(dirty));
  final String owner;
  final int fence;
  final int version;
  final ProbeMarker? marker;
  // A test fixture can establish genesis. A real adapter MUST NOT infer this
  // from an absent record when an earlier prepare may still be unresolved.
  final bool freshProof;
  final Map<String, int> values;
  final Set<String> tombstones;
  final Map<String, int> dirty;
}

abstract class SyntheticFencedJournal {
  // REQUIRED in a real implementation: serializable fence increment + read,
  // with all prior participating transactions either settled or fenced. Any
  // old actor that can ignore this fence invalidates the contract entirely.
  Future<ProbeView> settleFenceAndRead(String owner);
  // Each method below is one durable transaction with owner/fence/version/id
  // checks. false means known no commit; throws means outcome unknown.
  Future<bool> prepare(String owner, int fence, ProbePayload payload);
  Future<bool> commit(String owner, int fence, ProbePayload payload);
  // Check owner, fence, exact marker+full envelope in one transaction; mark
  // acknowledgement without clearing domain dirty generation. A previously
  // acknowledged marker still requires an atomic fence and identity recheck.
  Future<bool> acknowledgeObserved(String owner, int fence, ProbePayload payload);
}

class UnknownGateDraft {
  UnknownGateDraft(this.store, this.owner) {
    if (!owner.startsWith('synthetic-')) throw const ProbeError('synthetic_only');
  }
  final SyntheticFencedJournal store;
  final String owner;
  int? _fence;
  bool _ready = false;
  bool _busy = false;
  ProbeView? _lastView;
  ProbeStatus status = ProbeStatus.ambiguous;

  // After recreation no writes are allowed until a fenced inspection. An
  // absent marker without a trustworthy genesis proof is ambiguous, not idle.
  Future<ProbeStatus> inspect() async {
    if (_busy) throw const ProbeError('busy');
    _ready = false;
    _fence = null;
    _lastView = null;
    _busy = true;
    try {
      final view = await store.settleFenceAndRead(owner);
      if (view.owner != owner || view.fence < 1 || view.version < 0) {
        throw const ProbeError('invalid_scope_or_fence');
      }
      _fence = view.fence;
      _lastView = view;
      final marker = view.marker;
      if (marker == null) {
        final verifiedEmpty = view.freshProof && view.version == 0 &&
            view.values.isEmpty && view.tombstones.isEmpty && view.dirty.isEmpty;
        status = verifiedEmpty ? ProbeStatus.ready : ProbeStatus.ambiguous;
        _ready = verifiedEmpty;
      } else if (marker.payload.owner != owner || !_validPayload(marker.payload)) {
        status = ProbeStatus.ambiguous;
      } else if (marker.phase == ProbePhase.prepared) {
        // PREPARED never auto-applies or auto-discards.
        status = ProbeStatus.prepared;
      } else if (!_matchesCommitted(view, marker.payload)) {
        status = ProbeStatus.ambiguous;
      } else if (marker.phase == ProbePhase.committed) {
        status = ProbeStatus.committed;
      } else {
        // Even an acknowledged marker requires explicit identity reconciliation.
        status = ProbeStatus.acknowledged;
      }
      return status;
    } catch (_) {
      status = ProbeStatus.ambiguous;
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<void> submit(ProbePayload payload) async {
    if (_busy || !_ready || _fence == null) throw const ProbeError('blocked');
    if (payload.owner != owner || !_validPayload(payload)) throw const ProbeError('invalid_payload');
    _ready = false; // Set before any await so a second call cannot overtake.
    _busy = true;
    try {
      if (!await store.prepare(owner, _fence!, payload)) throw const ProbeError('prepare_rejected');
      if (!await store.commit(owner, _fence!, payload)) throw const ProbeError('commit_rejected');
      // Commit is locally recorded, but explicit fenced reconciliation remains.
      status = ProbeStatus.committed;
    } catch (_) {
      status = ProbeStatus.ambiguous;
      _fence = null;
      _lastView = null;
      rethrow;
    } finally {
      _busy = false;
    }
  }

  // Caller supplies the exact retained intent. No PREPARED retry or deletion.
  // The acknowledgement is local journal observation, not a server sync ack.
  Future<void> reconcileCommitted(ProbePayload expected) async {
    if (_busy || _fence == null || _lastView == null || expected.owner != owner ||
        !_validPayload(expected) ||
        (status != ProbeStatus.committed && status != ProbeStatus.acknowledged)) {
      throw const ProbeError('blocked');
    }
    final view = _lastView!;
    final marker = view.marker;
    if (marker == null || marker.phase == ProbePhase.prepared ||
        !_samePayload(marker.payload, expected) || !_matchesCommitted(view, expected)) {
      throw const ProbeError('reconciliation_mismatch');
    }
    _busy = true;
    try {
      if (!await store.acknowledgeObserved(owner, _fence!, expected)) {
        throw const ProbeError('ack_rejected');
      }
      // A matching, previously acknowledged marker resolves response loss.
      _ready = true;
      status = ProbeStatus.ready;
      _lastView = null;
    } catch (_) {
      _ready = false;
      _fence = null;
      _lastView = null;
      status = ProbeStatus.ambiguous;
      rethrow;
    } finally {
      _busy = false;
    }
  }
}

bool _validPayload(ProbePayload p) =>
    p.owner.startsWith('synthetic-') && p.id.startsWith('synthetic-') &&
    p.baseVersion >= 0 && p.generation > 0 &&
    p.values.keys.every((k) => k.startsWith('synthetic-')) &&
    p.values.values.every((v) => v >= 1 && v <= 31) &&
    p.tombstones.every((k) => k.startsWith('synthetic-') && !p.values.containsKey(k)) &&
    p.dirty.keys.every((k) => (p.values.containsKey(k) || p.tombstones.contains(k)) &&
        p.dirty[k]! > 0 && p.dirty[k]! <= p.generation);

bool _mapEquals(Map<String, int> a, Map<String, int> b) =>
    a.length == b.length && a.keys.every((k) => b.containsKey(k) && a[k] == b[k]);
bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
bool _samePayload(ProbePayload a, ProbePayload b) =>
    a.owner == b.owner && a.id == b.id && a.baseVersion == b.baseVersion &&
    a.generation == b.generation && _mapEquals(a.values, b.values) &&
    _setEquals(a.tombstones, b.tombstones) && _mapEquals(a.dirty, b.dirty);
bool _matchesCommitted(ProbeView view, ProbePayload p) =>
    view.owner == p.owner && view.version == p.baseVersion + 1 &&
    _mapEquals(view.values, p.values) && _setEquals(view.tombstones, p.tombstones) &&
    _mapEquals(view.dirty, p.dirty);