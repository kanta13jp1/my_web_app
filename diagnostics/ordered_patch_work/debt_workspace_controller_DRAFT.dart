// NON-SHIPPING DESIGN DRAFT: no production storage, auth, UI or network.
// An actual adapter must use an owner-scoped atomic transaction and a durable
// queue. The memory-only UI overlay below does not survive page destruction.
import 'dart:collection';
import 'dart:async';

enum WorkspaceKind { account, unowned, legacyReview }

class DebtWorkspace {
  const DebtWorkspace._(this.kind, this.id);
  factory DebtWorkspace.account(String id) {
    if (id.isEmpty) throw ArgumentError('empty scope');
    return DebtWorkspace._(WorkspaceKind.account, id);
  }
  factory DebtWorkspace.unowned(String workspaceId) {
    if (workspaceId.isEmpty) throw ArgumentError('empty scope');
    return DebtWorkspace._(WorkspaceKind.unowned, workspaceId);
  }
  const DebtWorkspace.legacyReview() : this._(WorkspaceKind.legacyReview, 'legacy');
  final WorkspaceKind kind;
  final String id;
  @override
  bool operator ==(Object other) =>
      other is DebtWorkspace && kind == other.kind && id == other.id;
  @override
  int get hashCode => Object.hash(kind, id);
}

class ScopedDebtSnapshot {
  ScopedDebtSnapshot({required this.workspace, required this.version,
      required Map<String, int> values, Set<String> deletedKeys = const {}})
      : values = UnmodifiableMapView(Map<String, int>.from(values)),
        deletedKeys = UnmodifiableSetView(Set<String>.from(deletedKeys));
  final DebtWorkspace workspace;
  final int version;
  final Map<String, int> values;
  final Set<String> deletedKeys;
}

class ScopedEditResult {
  const ScopedEditResult({required this.committed, this.snapshot, this.intent});
  final bool committed;
  final ScopedDebtSnapshot? snapshot;
  final int? intent;
}

abstract class ScopedDebtLocal {
  // Must atomically set active scope and increment a globally shared fence.
  // The fence is effective only after this Future completes; real auth and
  // storage must share its transaction ordering. This is not implemented here.
  Future<int> activate(DebtWorkspace workspace);
  // A valid snapshot must be read only from the requested scope; absent versus
  // corrupted/unknown legacy must be reported by the implementation.
  Future<ScopedDebtSnapshot> read(DebtWorkspace workspace);
  // The adapter MUST capture the workspace itself, append the edit durably,
  // preserve same-key order, serialize or CAS transactionally per scope, and
  // return false only for confirmed no-commit; ambiguous outcomes must throw.
  // A legacyReview edit goes to an unowned draft,
  // NEVER mutates/deletes the original legacy keys or transmits data.
  Future<ScopedEditResult> writeEdit(
      DebtWorkspace workspace, String key, int? day, int fence, int expectedVersion, int intent);
}

// Remote source and merge are synthetic contracts only. A real merge MUST
// check the captured owner, auth epoch/fence, current revision and dirty keys
// inside the same owner-scoped transaction; this controller cannot prove it.
abstract class ScopedDebtRestore {
  // fence must be captured from activate. A real adapter must bind it to
  // an owner-scoped durable fence and check that fence transactionally.
  Future<ScopedDebtSnapshot> fetch(DebtWorkspace workspace, int fence);
  Future<ScopedEditResult> mergeIfUnchanged(DebtWorkspace workspace,
      int fence, int expectedVersion, ScopedDebtSnapshot remote);
}
class DebtWorkspaceController {
  DebtWorkspaceController(this.local, {bool enableSyntheticRestore = false})
      : _enableSyntheticRestore = enableSyntheticRestore;
  // Test-only switch. With the real auth barrier absent, production must not
  // enable this or begin restore. This is not a runtime security boundary.
  final bool _enableSyntheticRestore;
  final ScopedDebtLocal local;
  DebtWorkspace? _workspace;
  ScopedDebtSnapshot? _visible;
  int _selectionEpoch = 0;
  int _intentSerial = 0;
  int? _activeFence;
  Future<int?> _activationBarrier = Future<int?>.value(null);
  final _unknownRestores = <DebtWorkspace>{};
  Future<void> _activationTail = Future<void>.value();
  final _writeTails = <DebtWorkspace, Future<void>>{};
  final _unknownScopes = <DebtWorkspace>{};
  bool _loading = false;
  String? _failureCode;
  final _failureByScope = <DebtWorkspace, String>{};
  final _pendingByScope = <DebtWorkspace, Map<String, int?>>{};
  final _latestIntent = <DebtWorkspace, Map<String, int>>{};

  DebtWorkspace? get workspace => _workspace;
  ScopedDebtSnapshot? get visible => _visible;
  bool get loading => _loading;
  String? get failureCode => _failureCode;
  Map<String, int?> get pending => Map.unmodifiable(
      _pendingByScope[_workspace] ?? <String, int?>{});

  // Clears the visible map synchronously before awaiting the new scope. Old
  // results may finish their own scope's persistence, never update this view.
  Future<void> select(DebtWorkspace workspace) async {
    final epoch = ++_selectionEpoch;
    _workspace = workspace;
    _activeFence = null;
    _visible = null;
    _loading = true;
    _failureCode = _failureByScope[workspace];
    final predecessor = _activationTail;
    final activated = Completer<void>();
    final barrier = Completer<int?>();
    _activationBarrier = barrier.future;
    _activationTail = activated.future;
    try {
      await predecessor;
      final fence = await local.activate(workspace);
      barrier.complete(fence);
      activated.complete();
      if (!_isCurrent(workspace, epoch)) return;
      _activeFence = fence;
      final snapshot = await local.read(workspace);
      if (!_isCurrent(workspace, epoch)) return;
      _accept(workspace, snapshot);
    } catch (_) {
      if (_isCurrent(workspace, epoch)) _failureCode = 'local_read_failed';
    } finally {
      if (!barrier.isCompleted) barrier.complete(null);
      if (!activated.isCompleted) activated.complete();
      if (_isCurrent(workspace, epoch)) _loading = false;
    }
  }

  // Null means an accepted local deletion, not a discarded edit. Editors may
  // submit while read/restore is pending. The overlay is kept on rejection;
  // this draft does not guarantee that overlay survives an app/process crash.
  Future<void> edit(String key, int? day) async {
    final workspace = _workspace;
    if (workspace == null || key.isEmpty ||
        (day != null && (day < 1 || day > 31))) {
      _failureCode = 'invalid_edit';
      return;
    }
    final epoch = _selectionEpoch;
    final selectionBarrier = _activationBarrier;
    final serial = ++_intentSerial;
    (_pendingByScope[workspace] ??= <String, int?>{})[key] = day;
    (_latestIntent[workspace] ??= <String, int>{})[key] = serial;
    // Serialize same-scope commits through responses; an uncertain response
    // stops successors until resolved, rather than allowing reordering.
    final predecessor = _writeTails[workspace] ?? Future<void>.value();
    final finished = Completer<void>();
    _writeTails[workspace] = finished.future;
    try {
      await predecessor;
      if (_unknownScopes.contains(workspace)) {
        _failureByScope[workspace] = 'local_write_unknown';
        if (_workspace == workspace) _failureCode = 'local_write_unknown';
        return;
      }
      final fence = await selectionBarrier;
      if (fence == null || !_isCurrent(workspace, epoch) || _activeFence != fence) {
        _failureByScope[workspace] = 'activation_unavailable';
        if (_workspace == workspace) _failureCode = 'activation_unavailable';
        return;
      }
      ScopedDebtSnapshot base;
      try {
        base = await local.read(workspace);
      } catch (_) {
        // No write has been submitted: safe to retry, while keeping overlay.
        _failureByScope[workspace] = 'local_read_failed';
        if (_workspace == workspace) _failureCode = 'local_read_failed';
        return;
      }
      if (base.workspace != workspace || !_isCurrent(workspace, epoch) || _activeFence != fence) {
        _failureByScope[workspace] = 'activation_unavailable';
        if (_workspace == workspace) _failureCode = 'activation_unavailable';
        return;
      }
      final result = await local.writeEdit(workspace, key, day, fence, base.version, serial);
      final ack = result.snapshot;
      final valueMatches = ack != null &&
          (day == null ? !ack.values.containsKey(key) && ack.deletedKeys.contains(key)
                       : ack.values[key] == day && !ack.deletedKeys.contains(key));
      if (!result.committed || ack == null || ack.workspace != workspace ||
          ack.version <= base.version || result.intent != serial || !valueMatches) {
        // A claimed commit without a valid receipt is ambiguous, not a safe
        // failure. Block subsequent same-scope writes pending real recovery.
        if (result.committed) _unknownScopes.add(workspace);
        if (_latestIntent[workspace]?[key] == serial) {
          final failure = result.committed ? 'local_write_unknown' : 'local_write_failed';
          _failureByScope[workspace] = failure;
          if (_workspace == workspace) _failureCode = failure;
        }
        return;
      }
      // If A was reopened after A -> B -> A, refresh A using the new epoch;
      // the stale completion must not directly replace the reopened view.
      if (_isCurrent(workspace, epoch)) {
        _accept(workspace, result.snapshot!);
      } else if (_workspace == workspace) {
        final currentEpoch = _selectionEpoch;
        final refreshed = await local.read(workspace);
        if (!_isCurrent(workspace, currentEpoch) ||
            refreshed.workspace != workspace ||
            refreshed.version < result.snapshot!.version) return;
        _accept(workspace, refreshed);
      }
      // Only the latest accepted edit for this key can clear its overlay.
      if (_latestIntent[workspace]?[key] == serial) {
        _pendingByScope[workspace]?.remove(key);
        if (_pendingByScope[workspace]?.isEmpty ?? true) {
          _failureByScope.remove(workspace);
          if (_workspace == workspace) _failureCode = null;
        }
      }
    } catch (_) {
      // Exception may follow commit; block later writes until durable recovery.
      _unknownScopes.add(workspace);
      if (_latestIntent[workspace]?[key] == serial) {
        _failureByScope[workspace] = 'local_write_unknown';
        if (_workspace == workspace) _failureCode = 'local_write_unknown';
      }
    } finally {
      finished.complete();
      if (identical(_writeTails[workspace], finished.future)) {
        _writeTails.remove(workspace);
      }
    }
  }

  // Owner initialization must use the owner-scoped store and start a fresh
  // pull only after the scoped load. Never reuse a prior owner's boot cache.
  Future<void> onAuthChanged(String? ownerId, {
    required String unownedWorkspaceId,
    ScopedDebtRestore? restore,
  }) async {
    final scope = ownerId == null
        ? DebtWorkspace.unowned(unownedWorkspaceId)
        : DebtWorkspace.account(ownerId);
    final selected = select(scope);
    final epoch = _selectionEpoch;
    await selected;
    if (ownerId != null && restore != null && _isCurrent(scope, epoch)) {
      await pullAndRestore(restore);
    }
  }

  Future<void> pullAndRestore(ScopedDebtRestore restore) async {
    // Real restore disabled until auth notification and durable commit share
    // a verified linearization barrier. Synthetic opt-in is tests only.
    if (!_enableSyntheticRestore) return;
    final workspace = _workspace;
    final current = _visible;
    if (workspace == null || workspace.kind != WorkspaceKind.account || current == null || _unknownRestores.contains(workspace) || _unknownScopes.contains(workspace)) return;
    final epoch = _selectionEpoch;
    final baseVersion = current.version;
    final fence = _activeFence;
    if (fence == null) return;
    try {
      final remote = await restore.fetch(workspace, fence);
      if (!_isCurrent(workspace, epoch)) return;
      if (remote.workspace != workspace) {
        _failureByScope[workspace] = 'restore_scope_mismatch';
        _failureCode = 'restore_scope_mismatch';
        return;
      }
      if (_visible?.version != baseVersion ||
          (_pendingByScope[workspace]?.isNotEmpty ?? false)) return;
      ScopedEditResult result;
      try {
        result = await restore.mergeIfUnchanged(workspace, fence, baseVersion, remote);
      } catch (_) {
        _unknownRestores.add(workspace);
        _unknownScopes.add(workspace);
        _failureByScope[workspace] = 'restore_unknown';
        if (_workspace == workspace) _failureCode = 'restore_unknown';
        return;
      }
      final ack = result.snapshot;
      if (!result.committed || ack == null || ack.workspace != workspace ||
          ack.version <= baseVersion || !_preservesBase(current, ack)) {
        if (result.committed) {
          _unknownRestores.add(workspace);
          _unknownScopes.add(workspace);
        }
        final failure = result.committed ? 'restore_unknown' : 'restore_not_applied';
        _failureByScope[workspace] = failure;
        if (_workspace == workspace) _failureCode = failure;
        return;
      }
      if (!_isCurrent(workspace, epoch)) return;
      try {
        _accept(workspace, ack);
      } catch (_) {
        // A merge may already have committed; response cannot be trusted.
        _unknownRestores.add(workspace);
        _unknownScopes.add(workspace);
        _failureByScope[workspace] = 'restore_unknown';
        if (_workspace == workspace) _failureCode = 'restore_unknown';
      }
    } catch (_) {
      if (_isCurrent(workspace, epoch)) {
        _failureByScope[workspace] = 'restore_failed';
        _failureCode = 'restore_failed';
      }
    }
  }
  bool _isCurrent(DebtWorkspace workspace, int epoch) =>
      _workspace == workspace && _selectionEpoch == epoch;

  // Deliberately conservative: restore may not replace any locally present
  // value or tombstone until a reviewed conflict-resolution policy exists.
  // Post-commit validation detects bad receipts but cannot roll back storage.
  bool _preservesBase(ScopedDebtSnapshot base, ScopedDebtSnapshot next) {
    if (next.deletedKeys.any(next.values.containsKey)) return false;
    for (final key in base.values.keys) {
      if (next.values[key] != base.values[key] || next.deletedKeys.contains(key)) return false;
    }
    return next.deletedKeys.containsAll(base.deletedKeys);
  }

  bool _sameContent(ScopedDebtSnapshot a, ScopedDebtSnapshot b) {
    if (a.values.length != b.values.length || a.deletedKeys.length != b.deletedKeys.length) return false;
    for (final key in a.values.keys) {
      if (!b.values.containsKey(key) || a.values[key] != b.values[key]) return false;
    }
    return a.deletedKeys.containsAll(b.deletedKeys);
  }

  // Diagnostic refresh: equal revision with different content is rejected.
  Future<void> refresh() async {
    final workspace = _workspace;
    final epoch = _selectionEpoch;
    if (workspace == null) return;
    try {
      final snapshot = await local.read(workspace);
      if (_isCurrent(workspace, epoch)) _accept(workspace, snapshot);
    } catch (_) {
      if (_isCurrent(workspace, epoch)) _failureCode = 'local_read_failed';
    }
  }

  void _accept(DebtWorkspace workspace, ScopedDebtSnapshot snapshot) {
    if (snapshot.workspace != workspace || snapshot.version < 0 ||
        snapshot.deletedKeys.any(snapshot.values.containsKey)) {
      throw StateError('invalid scope or contents');
    }
    final old = _visible;
    if (old != null && snapshot.version == old.version && !_sameContent(old, snapshot)) {
      throw StateError('same version with different contents');
    }
    if (old == null || snapshot.version > old.version) _visible = snapshot;
  }
}
