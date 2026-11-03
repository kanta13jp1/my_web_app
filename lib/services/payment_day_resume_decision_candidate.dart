/// Detached, pure decision model. It has no Auth, storage, migration, UI or
/// network adapter. Its inputs are hypothetical evidence, not proof. Runtime
/// adapters must enforce the same conditions at each effect/commit boundary.
enum LegacyDisposition {
  unresolved,
  preserveSeparatelyConfirmed,
  importPending,
  importOutcomeUnknown,
  importedAndVerified,
}

enum PendingDisposition {
  unknown,
  noPendingVerified,
  appliedAndVerified,
  rejectedWithoutEffectVerified,
  conflictUnresolved,
  conflictResolvedAndVerified,
}

class ResumeSession {
  const ResumeSession(this.owner, this.generation);
  final String owner;

  /// Non-reused across every Auth identity/session transition, including ABA.
  /// An Auth event subscriber and such a generation source are not implemented.
  final int generation;
}

class ResumeEvidence {
  const ResumeEvidence({
    required this.owner,
    required this.generation,
    this.authenticated = false,
    this.legacyInspectionRequested = false,
    this.legacyInspectionAuthorized = false,
    this.serverSnapshotValidated = false,
    this.independentCheckpointValidated = false,
    this.atomicOwnerStorageVerified = false,
    this.legacyWritersFenced = false,
    this.pendingDisposition = PendingDisposition.unknown,
    this.legacyDisposition = LegacyDisposition.unresolved,
  });
  final String owner;
  final int generation;
  final bool authenticated;
  final bool legacyInspectionRequested;

  /// A separately designed privacy authorization, not merely logged-in status.
  /// No such production adapter is implemented here.
  final bool legacyInspectionAuthorized;
  final bool serverSnapshotValidated;
  final bool independentCheckpointValidated;
  final bool atomicOwnerStorageVerified;
  final bool legacyWritersFenced;

  /// Receipt absence/timeout and unresolved conflicts must not be treated as
  /// no effect. A real receipt must match the immutable request and payload.
  final PendingDisposition pendingDisposition;

  /// Inspection or consent is not a completed import. Adapters must separately
  /// bind the explicit choice and any verified import to the owner/session.
  final LegacyDisposition legacyDisposition;
}

class ResumePermissions {
  const ResumePermissions({
    this.inspectQuarantinedLegacy = false,
    this.viewHistoricalSnapshot = false,
    this.mayRequestGuardedWrite = false,
  });

  /// A separate, explicit user operation, never an automatic read or import.
  final bool inspectQuarantinedLegacy;

  /// A labelled historical view only: not a forecast or notification source.
  final bool viewHistoricalSnapshot;

  /// Permission to request a guarded transaction only, never to write directly.
  /// The transaction must revalidate Auth, evidence, CAS and pending atomically.
  final bool mayRequestGuardedWrite;

  /// Historical snapshots do not justify forecasts, notifications or sending.
  /// A separate freshness and reconciliation contract is not implemented.
  bool get allowAutomaticDerivedEffects => false;
}

ResumePermissions decideOwnerResume(
  ResumeSession current,
  ResumeEvidence evidence,
) {
  if (current.owner.isEmpty ||
      current.generation < 0 ||
      !evidence.authenticated ||
      current.owner != evidence.owner ||
      current.generation != evidence.generation) {
    return const ResumePermissions();
  }
  final canView = evidence.serverSnapshotValidated &&
      evidence.independentCheckpointValidated;
  final dispositionResolved = evidence.legacyDisposition ==
          LegacyDisposition.preserveSeparatelyConfirmed ||
      evidence.legacyDisposition == LegacyDisposition.importedAndVerified;
  final pendingResolved = evidence.pendingDisposition ==
          PendingDisposition.noPendingVerified ||
      evidence.pendingDisposition == PendingDisposition.appliedAndVerified ||
      evidence.pendingDisposition ==
          PendingDisposition.conflictResolvedAndVerified;
  return ResumePermissions(
    inspectQuarantinedLegacy: evidence.legacyInspectionRequested &&
        evidence.legacyInspectionAuthorized,
    viewHistoricalSnapshot: canView,
    mayRequestGuardedWrite: canView &&
        evidence.atomicOwnerStorageVerified &&
        evidence.legacyWritersFenced &&
        pendingResolved &&
        dispositionResolved,
  );
}
