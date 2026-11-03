import 'payment_owner_local_candidate_types.dart';

PaymentOwnerLocalCandidate createPaymentOwnerLocalCandidate(
  String databaseName,
) =>
    _Unsupported();

class _Unsupported implements PaymentOwnerLocalCandidate {
  @override
  Future<CandidateResult> compareAndSet({
    required String owner,
    required int expectedRevision,
    required int syntheticCheckpointBaseRevision,
    required String requestId,
    required String value,
  }) async =>
      const CandidateResult(CandidateStatus.unsupported);
}
