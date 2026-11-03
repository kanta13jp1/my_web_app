import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/payment_day_resume_decision_candidate.dart';

void main() {
  const a = ResumeSession('synthetic-a', 7);
  ResumeEvidence evidence({
    String owner = 'synthetic-a',
    int generation = 7,
    bool auth = true,
    bool inspect = false,
    bool inspectAuthorized = true,
    bool snapshot = true,
    bool checkpoint = true,
    bool atomic = true,
    bool fenced = true,
    PendingDisposition pending = PendingDisposition.appliedAndVerified,
    LegacyDisposition disposition = LegacyDisposition.importedAndVerified,
  }) =>
      ResumeEvidence(
        owner: owner,
        generation: generation,
        authenticated: auth,
        legacyInspectionRequested: inspect,
        legacyInspectionAuthorized: inspectAuthorized,
        serverSnapshotValidated: snapshot,
        independentCheckpointValidated: checkpoint,
        atomicOwnerStorageVerified: atomic,
        legacyWritersFenced: fenced,
        pendingDisposition: pending,
        legacyDisposition: disposition,
      );

  test('resolved prerequisites allow only guarded request', () {
    final imported = decideOwnerResume(a, evidence());
    expect(imported.mayRequestGuardedWrite, isTrue);
    expect(imported.allowAutomaticDerivedEffects, isFalse);
    final preserved = decideOwnerResume(
      a,
      evidence(disposition: LegacyDisposition.preserveSeparatelyConfirmed),
    );
    expect(preserved.mayRequestGuardedWrite, isTrue);
  });

  test('verified no-pending is distinct from an unavailable read', () {
    final noPending = decideOwnerResume(
      a,
      evidence(pending: PendingDisposition.noPendingVerified),
    );
    expect(noPending.mayRequestGuardedWrite, isTrue);
    expect(noPending.allowAutomaticDerivedEffects, isFalse);
  });

  test('any missing barrier prevents a guarded write request', () {
    for (final e in [
      evidence(snapshot: false),
      evidence(checkpoint: false),
      evidence(atomic: false),
      evidence(fenced: false),
      evidence(pending: PendingDisposition.unknown),
      evidence(pending: PendingDisposition.rejectedWithoutEffectVerified),
      evidence(pending: PendingDisposition.conflictUnresolved),
      evidence(disposition: LegacyDisposition.unresolved),
      evidence(disposition: LegacyDisposition.importPending),
      evidence(disposition: LegacyDisposition.importOutcomeUnknown),
    ]) {
      expect(decideOwnerResume(a, e).mayRequestGuardedWrite, isFalse);
    }
  });

  test('unconfirmed or lost snapshot is never an empty first run', () {
    final absentSnapshot = decideOwnerResume(a, evidence(snapshot: false));
    final absentCheckpoint = decideOwnerResume(a, evidence(checkpoint: false));
    expect(absentSnapshot.viewHistoricalSnapshot, isFalse);
    expect(absentCheckpoint.viewHistoricalSnapshot, isFalse);
  });

  test('legacy inspection needs separate authorization and does not import',
      () {
    final requested = decideOwnerResume(
      a,
      evidence(inspect: true, disposition: LegacyDisposition.unresolved),
    );
    expect(requested.inspectQuarantinedLegacy, isTrue);
    expect(requested.viewHistoricalSnapshot, isTrue);
    expect(requested.mayRequestGuardedWrite, isFalse);
    final withoutRequest = decideOwnerResume(a, evidence());
    final withoutPrivacyAuth = decideOwnerResume(
      a,
      evidence(inspect: true, inspectAuthorized: false),
    );
    expect(withoutRequest.inspectQuarantinedLegacy, isFalse);
    expect(withoutPrivacyAuth.inspectQuarantinedLegacy, isFalse);
    final unknownImport = decideOwnerResume(
      a,
      evidence(
        snapshot: false,
        inspect: true,
        disposition: LegacyDisposition.importOutcomeUnknown,
      ),
    );
    expect(unknownImport.mayRequestGuardedWrite, isFalse);
  });

  test('expiry and ABA session generation deny every operation', () {
    final oldForB = decideOwnerResume(
      const ResumeSession('synthetic-b', 8),
      evidence(inspect: true),
    );
    final oldForAAgain = decideOwnerResume(
      const ResumeSession('synthetic-a', 9),
      evidence(inspect: true),
    );
    for (final result in [
      decideOwnerResume(a, evidence(auth: false, inspect: true)),
      oldForB,
      oldForAAgain,
      decideOwnerResume(const ResumeSession('', 7), evidence(inspect: true)),
    ]) {
      expect(result.inspectQuarantinedLegacy, isFalse);
      expect(result.viewHistoricalSnapshot, isFalse);
      expect(result.mayRequestGuardedWrite, isFalse);
      expect(result.allowAutomaticDerivedEffects, isFalse);
    }
  });
}
