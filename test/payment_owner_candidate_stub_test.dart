import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/payment_owner_local_candidate.dart';

void main() {
  test('non-web never falls back to shared preferences', () async {
    final store = createPaymentOwnerLocalCandidate('any');
    final result = await store.compareAndSet(
      owner: 'synthetic',
      expectedRevision: 0,
      syntheticCheckpointBaseRevision: 0,
      requestId: 'synthetic-request',
      value: 'synthetic-value',
    );
    expect(result.status, CandidateStatus.unsupported);
  });
}
