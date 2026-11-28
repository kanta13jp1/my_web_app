import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ready_now_ledger_service.dart';

void main() {
  const service = ReadyNowLedgerService();
  final verifiedAt = DateTime.utc(2026, 11, 28, 12, 0);

  test(
    'rejects 90%+ progress without proof and classifies as missingProofUnknown',
    () {
      const unprovedNinety = ReadyNowLedgerEntry(
        entryId: 'task-unproved-90',
        title: '外部公開待ちタスク',
        priorityRank: 1,
        progressPercent: 90,
        stage: CriticalPathStage.namedProspect,
        dependencyStatus: DependencyStatus.ready,
        completedEvidence: <String>[],
        remainingAcceptanceItems: <String>['公開URL確認'],
        lastEvidenceTimestamp: null,
        confidence: EvidenceConfidence.low,
      );

      expect(
        unprovedNinety.readinessState,
        ReadinessState.missingProofUnknown,
      );
      expect(unprovedNinety.verifiedProgressPercent, isNull);
      expect(
        service.validateEntry(unprovedNinety).errors,
        containsAll(<String>[
          'progress_90_plus_requires_completed_evidence',
          'progress_90_plus_requires_evidence_timestamp',
        ]),
      );
    },
  );

  test(
    'enforces evidence-gated critical path stage transitions without skipping',
    () {
      final skipped = service.validateStageTransition(
        fromStage: CriticalPathStage.identityAndPayoutReadiness,
        toStage: CriticalPathStage.attributableVisit,
        completedEvidence: const <String>['Stripe KYC完了'],
        lastEvidenceTimestamp: verifiedAt,
      );
      expect(
        skipped.errors,
        contains('cannot_skip_critical_path_stage'),
      );

      final missingProofAdvance = service.validateStageTransition(
        fromStage: CriticalPathStage.identityAndPayoutReadiness,
        toStage: CriticalPathStage.namedProspect,
        completedEvidence: const <String>[],
        lastEvidenceTimestamp: null,
      );
      expect(
        missingProofAdvance.errors,
        containsAll(<String>[
          'stage_advance_requires_completed_evidence',
          'stage_advance_requires_evidence_timestamp',
        ]),
      );

      final validAdvance = service.validateStageTransition(
        fromStage: CriticalPathStage.identityAndPayoutReadiness,
        toStage: CriticalPathStage.namedProspect,
        completedEvidence: const <String>['KYC承認済'],
        lastEvidenceTimestamp: verifiedAt,
      );
      expect(validAdvance.isValid, isTrue);
    },
  );

  test(
    'sorts readyNow items before blocked/unknown backlog in critical-path order',
    () {
      final blockedExternal = ReadyNowLedgerEntry(
        entryId: 'task-blocked',
        title: '外部承認待ち',
        priorityRank: 1,
        progressPercent: 80,
        stage: CriticalPathStage.checkout,
        dependencyStatus: DependencyStatus.blockedExternal,
        blockerOwner: 'Stripe審査',
        nextExternalAction: '本人確認書類の再提出待ち',
        completedEvidence: const <String>['申込送信済'],
        remainingAcceptanceItems: const <String>['審査通過'],
        lastEvidenceTimestamp: verifiedAt,
        confidence: EvidenceConfidence.medium,
      );

      const missingProof = ReadyNowLedgerEntry(
        entryId: 'task-unknown',
        title: '証跡なし95%タスク',
        priorityRank: 1,
        progressPercent: 95,
        stage: CriticalPathStage.verifiedPayout,
        dependencyStatus: DependencyStatus.ready,
      );

      final readyStep1 = ReadyNowLedgerEntry(
        entryId: 'task-ready-1',
        title: '本人確認と入金準備',
        priorityRank: 2,
        progressPercent: 50,
        stage: CriticalPathStage.identityAndPayoutReadiness,
        dependencyStatus: DependencyStatus.ready,
        completedEvidence: const <String>['口座登録済'],
        remainingAcceptanceItems: const <String>['テスト入金確認'],
        lastEvidenceTimestamp: verifiedAt,
        confidence: EvidenceConfidence.high,
      );

      final readyStep2 = ReadyNowLedgerEntry(
        entryId: 'task-ready-2',
        title: '指名見込み客1件確定',
        priorityRank: 1,
        progressPercent: 40,
        stage: CriticalPathStage.namedProspect,
        dependencyStatus: DependencyStatus.ready,
        completedEvidence: const <String>['連絡先確認済'],
        remainingAcceptanceItems: const <String>['初回導線送付'],
        lastEvidenceTimestamp: verifiedAt,
        confidence: EvidenceConfidence.high,
      );

      final sorted = service.sortReadyNowFirst(<ReadyNowLedgerEntry>[
        missingProof,
        blockedExternal,
        readyStep2,
        readyStep1,
      ]);

      expect(
        sorted.map((e) => e.entryId).toList(),
        equals(<String>[
          'task-ready-1',
          'task-ready-2',
          'task-blocked',
          'task-unknown',
        ]),
      );

      final summary = service.summarize(sorted);
      expect(summary.totalCount, 4);
      expect(summary.readyNowCount, 2);
      expect(summary.blockedExternalCount, 1);
      expect(summary.missingProofUnknownCount, 1);
      expect(summary.allValid, isFalse);
    },
  );
}
