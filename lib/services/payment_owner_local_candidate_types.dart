/// Experimental detached local boundary; never use as an Auth boundary.
enum CandidateStatus {
  applied,
  historicalReceipt,
  versionConflict,
  recoveryHold,
  unsupported,
  aborted,
  outcomeUnknown,
  invalid,
}

class CandidateResult {
  const CandidateResult(this.status, {this.revision});
  final CandidateStatus status;

  /// Historical receipt revision, current conflicting revision, or applied revision.
  final int? revision;
}

abstract interface class PaymentOwnerLocalCandidate {
  /// Caller must provide an already enrolled owner row. Missing data is held.
  /// This does not establish the caller's owner identity or storage durability.
  /// The checkpoint parameter is synthetic input only: no trusted external
  /// checkpoint/authentication adapter exists and this must not be wired to users.
  Future<CandidateResult> compareAndSet({
    required String owner,
    required int expectedRevision,
    required int syntheticCheckpointBaseRevision,
    required String requestId,
    required String value,
  });
}
