/// A raw balance observation, not proof of an actual salary deposit.
final class SalaryBalanceHistoryRow {
  const SalaryBalanceHistoryRow({
    required this.rowId,
    required this.sourceOwnerId,
    required this.accountName,
    required this.recordedAt,
    required this.amount,
  });

  /// This identifies a history row, not a stable bank-account identity.
  final int rowId;
  final String sourceOwnerId;
  final String accountName;
  final DateTime recordedAt;
  final double amount;
}

final class SalaryHistoryReadToken {
  const SalaryHistoryReadToken._(
    this._issuer,
    this.ownerId,
    this.authGeneration,
    this.epoch,
    this.requestSerial,
  );

  final Object _issuer;
  final String ownerId;
  final int authGeneration;
  final int epoch;
  final int requestSerial;
}

final class SalaryHistoryMutationToken {
  const SalaryHistoryMutationToken._(
    this._issuer,
    this.ownerId,
    this.authGeneration,
    this.serial,
  );

  final Object _issuer;
  final String ownerId;
  final int authGeneration;
  final int serial;
}

/// [notCommitted] requires proof that the write cannot later commit.
enum SalaryHistoryMutationOutcome { committed, notCommitted, unknown }

/// Conservative, in-memory candidate-history state; this does not persist.
///
/// Call [observeAuth] for every relevant authentication event, including an
/// A -> B -> A transition, not only when the string at completion changes.
/// Every balance save/delete entry point must wrap its operation in a mutation
/// token. A pending or uncertain write remains associated with its original
/// owner across authentication events. A timeout does not cancel the write.
/// Missing events or omitted mutation paths make this guard incomplete.
/// The caller must also obtain rows through a verified owner-scoped query/RLS;
/// this class cannot prove that sourceOwnerId is truthful or that account
/// names uniquely identify accounts. Previously returned lists are immutable,
/// but callers must also clear any displayed copies on authentication changes.
/// This in-memory guard does not survive disposal or process termination; a
/// durable coordinator or independently established quiescence is required.
final class SalaryBalanceHistoryState {
  final Object _issuer = Object();
  String? _ownerId;
  int _authGeneration = 0;
  int _epoch = 0;
  int _requestSerial = 0;
  int _mutationSerial = 0;
  final Map<String, int> _ownerRevisions = <String, int>{};
  final Map<String, Map<int, SalaryHistoryMutationToken>> _pendingByOwner =
      <String, Map<int, SalaryHistoryMutationToken>>{};
  List<SalaryBalanceHistoryRow>? _rows;

  int get authGeneration => _authGeneration;
  int get revision => _ownerRevisions[_ownerId] ?? 0;

  void observeAuth(String? ownerId) {
    _authGeneration++;
    _epoch++;
    _requestSerial++;
    _ownerId = ownerId == null || ownerId.trim().isEmpty ? null : ownerId;
    _rows = null;
  }

  bool _matchesOwner(String? ownerId) =>
      _ownerId != null && ownerId != null && ownerId == _ownerId;

  bool _matchesCurrentContext(String? ownerId) =>
      _ownerId == ownerId && (ownerId == null || _matchesOwner(ownerId));

  bool _hasUnresolved(String? ownerId) =>
      ownerId != null && (_pendingByOwner[ownerId]?.isNotEmpty ?? false);

  /// A null result means that no usable owner exists or a write is in flight.
  SalaryHistoryReadToken? beginRead(String? currentOwnerId) {
    if (!_matchesOwner(currentOwnerId) || _hasUnresolved(currentOwnerId)) {
      return null;
    }
    // Never expose an older snapshot while a refresh is incomplete or failed.
    _rows = null;
    _requestSerial++;
    return SalaryHistoryReadToken._(
      _issuer,
      _ownerId!,
      _authGeneration,
      _epoch,
      _requestSerial,
    );
  }

  /// A late, superseded, mixed-owner or invalid response is never installed.
  bool acceptRead(
    SalaryHistoryReadToken token, {
    required String? currentOwnerId,
    required Iterable<SalaryBalanceHistoryRow> rows,
  }) {
    if (!identical(token._issuer, _issuer) ||
        !_matchesOwner(currentOwnerId) ||
        token.ownerId != _ownerId ||
        token.authGeneration != _authGeneration ||
        token.epoch != _epoch ||
        token.requestSerial != _requestSerial ||
        _hasUnresolved(currentOwnerId)) {
      return false;
    }
    // A response consumes its request once, including invalid batches.
    _requestSerial++;
    final copy = <SalaryBalanceHistoryRow>[];
    final ids = <int>{};
    for (final row in rows) {
      if (row.rowId <= 0 ||
          row.sourceOwnerId != token.ownerId ||
          row.accountName.trim().isEmpty ||
          !row.amount.isFinite ||
          !ids.add(row.rowId)) {
        _rows = null;
        return false;
      }
      copy.add(row);
    }
    _rows = List<SalaryBalanceHistoryRow>.unmodifiable(copy);
    return true;
  }

  /// Hide the previous snapshot during a mutation, without destroying it.
  SalaryHistoryMutationToken? beginMutation(String? currentOwnerId) {
    if (!_matchesOwner(currentOwnerId)) return null;
    _mutationSerial++;
    _epoch++;
    final token = SalaryHistoryMutationToken._(
      _issuer,
      _ownerId!,
      _authGeneration,
      _mutationSerial,
    );
    _pendingByOwner.putIfAbsent(
      _ownerId!,
      () => <int, SalaryHistoryMutationToken>{},
    )[_mutationSerial] = token;
    return token;
  }

  /// Unknown outcomes remain unresolved: a delayed server commit may follow.
  /// A later terminal outcome is allowed only with authoritative evidence that
  /// the original operation has completed or can no longer commit. A read by
  /// itself is not that evidence. Never blindly resend an uncertain write.
  bool finishMutation(
    SalaryHistoryMutationToken token, {
    required String? currentOwnerId,
    required SalaryHistoryMutationOutcome outcome,
  }) {
    final pending = _pendingByOwner[token.ownerId];
    if (!identical(token._issuer, _issuer) ||
        !_matchesCurrentContext(currentOwnerId) ||
        !identical(pending?[token.serial], token)) {
      return false;
    }
    if (_ownerId == token.ownerId) _epoch++;
    if (outcome == SalaryHistoryMutationOutcome.unknown) {
      if (_ownerId == token.ownerId) _rows = null;
      return true;
    }
    pending!.remove(token.serial);
    if (pending.isEmpty) _pendingByOwner.remove(token.ownerId);
    if (outcome == SalaryHistoryMutationOutcome.committed) {
      _ownerRevisions[token.ownerId] =
          (_ownerRevisions[token.ownerId] ?? 0) + 1;
      if (_ownerId == token.ownerId) _rows = null;
    }
    return true;
  }

  /// Null denotes unavailable/unverified, distinct from a verified empty list.
  List<SalaryBalanceHistoryRow>? rowsFor(String? currentOwnerId) {
    if (!_matchesOwner(currentOwnerId) || _hasUnresolved(currentOwnerId)) {
      return null;
    }
    return _rows;
  }
}
