import 'payment_owner_local_candidate_stub.dart'
    if (dart.library.js_interop) 'payment_owner_local_candidate_web.dart'
    as impl;
import 'payment_owner_local_candidate_types.dart';
export 'payment_owner_local_candidate_types.dart';

/// Diagnostic only: Web implementation accepts loopback and synthetic DB names.
/// No legacy data may be read, inferred, migrated, cleared, or sent here.
PaymentOwnerLocalCandidate createPaymentOwnerLocalCandidate(
        String databaseName) =>
    impl.createPaymentOwnerLocalCandidate(databaseName);
