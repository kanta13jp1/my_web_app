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

  test('all prerequisites and resolved disposition allow model write', () {
    expect(decideOwnerResume(a, evidence()).mayRequestGuardedWrite, isTrue);
    expect(
        decideOwnerResume(
                a,
                evidence(
                    disposition: LegacyDisposition.preserveSeparatelyConfirmed))
            .mayRequestGuardedWrite,
        isTrue);
  });

  test('verified no-pending permits request; derived effects remain held', () {
    final result = decideOwnerResume(
        a, evidence(pending: PendingDisposition.noPendingVerified));
    expect(result.mayRequestGuardedWrite, isTrue);
    expect(result.allowAutomaticDerivedEffects, isFalse);
  });

  test('any missing barrier prevents writes', () {
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

  test('unconfirmed or lost snapshot never becomes empty first run', () {
    expect(
        decideOwnerResume(a, evidence(snapshot: false)).viewHistoricalSnapshot,
        isFalse);
    expect(
        decideOwnerResume(a, evidence(checkpoint: false))
            .viewHistoricalSnapshot,
        isFalse);
  });

  test('explicit legacy inspection is independent and does not import', () {
    final requested = decideOwnerResume(
        a, evidence(inspect: true, disposition: LegacyDisposition.unresolved));
    expect(requested.inspectQuarantinedLegacy, isTrue);
    expect(requested.viewHistoricalSnapshot, isTrue);
    expect(requested.mayRequestGuardedWrite, isFalse);
    expect(decideOwnerResume(a, evidence()).inspectQuarantinedLegacy, isFalse);
    expect(
        decideOwnerResume(a, evidence(inspect: true, inspectAuthorized: false))
            .inspectQuarantinedLegacy,
        isFalse);
    expect(
        decideOwnerResume(
                a,
                evidence(
                    snapshot: false,
                    inspect: true,
                    disposition: LegacyDisposition.importOutcomeUnknown))
            .mayRequestGuardedWrite,
        isFalse);
  });

  test('expiry and ABA session generation deny every operation', () {
    for (final result in [
      decideOwnerResume(a, evidence(auth: false, inspect: true)),
      decideOwnerResume(
          const ResumeSession('synthetic-b', 8), evidence(inspect: true)),
      decideOwnerResume(
          const ResumeSession('synthetic-a', 9), evidence(inspect: true)),
      decideOwnerResume(const ResumeSession('', 7), evidence(inspect: true)),
    ]) {
      expect(result.inspectQuarantinedLegacy, isFalse);
      expect(result.viewHistoricalSnapshot, isFalse);
      expect(result.mayRequestGuardedWrite, isFalse);
    }
  });
}
