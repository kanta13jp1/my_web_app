import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/jev_mario_stage_telemetry_service.dart';

JevMarioBackendRun _run(
  String backend, {
  JevMarioStageId stage = JevMarioStageId.world1_2,
  JevMarioAssistance assistance = JevMarioAssistance.assisted,
  JevMarioInferenceKind kind = JevMarioInferenceKind.live,
  bool cleared = false,
  String? evidence,
  String? failure,
}) {
  return JevMarioBackendRun(
    backendId: backend,
    stage: stage,
    assistance: assistance,
    inferenceKind: kind,
    cleared: cleared,
    clearEvidenceId: evidence,
    failureReason: failure,
  );
}

void main() {
  const service = JevMarioStageTelemetryService();

  group('stage profiles', () {
    test('World 1-1 overworld and World 1-2 underground are independent', () {
      expect(JevMarioStageId.world1_1.theme, 'overworld');
      expect(JevMarioStageId.world1_2.theme, 'underground');
      expect(
        service.validateStageProfiles(JevMarioStageRegistry.all).isValid,
        isTrue,
      );
      final world11 =
          JevMarioStageRegistry.profileFor(JevMarioStageId.world1_1);
      final world12 =
          JevMarioStageRegistry.profileFor(JevMarioStageId.world1_2);
      expect(world11.preservedUnmodified, isTrue);
      expect(world11.telemetryNamespace, isNot(world12.telemetryNamespace));
      expect(world11.audioProfileId, isNot(world12.audioProfileId));
      expect(world11.recordingProfileId, isNot(world12.recordingProfileId));
    });

    test('rejects shared profiles and a modified World 1-1', () {
      const shared = JevMarioStageProfile(
        stage: JevMarioStageId.world1_2,
        telemetryNamespace: 'jev_mario.world1_1',
        audioProfileId: 'overworld_original',
        recordingProfileId: 'overworld_default',
        preservedUnmodified: false,
      );
      const modified = JevMarioStageProfile(
        stage: JevMarioStageId.world1_1,
        telemetryNamespace: 'jev_mario.world1_1',
        audioProfileId: 'overworld_original',
        recordingProfileId: 'overworld_default',
        preservedUnmodified: false,
      );
      final modifiedProfiles = <JevMarioStageProfile>[modified, shared];
      final errors = service.validateStageProfiles(modifiedProfiles).errors;
      expect(
        errors,
        containsAll(<String>[
          'telemetry_namespace_must_be_distinct',
          'audio_profile_must_be_distinct',
          'recording_profile_must_be_distinct',
          'world1_1_must_be_preserved_unmodified',
        ]),
      );
      expect(
        service.validateStageProfiles(<JevMarioStageProfile>[
          JevMarioStageRegistry.world11,
        ]).errors,
        contains('missing_stage:world1_2'),
      );
    });
  });

  group('stage-specific reset isolation', () {
    test('resetting World 1-2 never mutates World 1-1 records', () {
      var store = JevMarioStageTelemetryStore();
      store = store.record(
        stage: JevMarioStageId.world1_1,
        name: 'jump',
        frame: 120,
      );
      store = store.record(
        stage: JevMarioStageId.world1_1,
        name: 'goal',
        frame: 400,
        cleared: true,
      );
      store = store.record(
        stage: JevMarioStageId.world1_2,
        name: 'pipe_enter',
        frame: 90,
      );
      store = store.record(
        stage: JevMarioStageId.world1_2,
        name: 'fall',
        frame: 150,
        died: true,
      );

      final before11State = store.stateOf(JevMarioStageId.world1_1);
      final before11Events = store.eventsOf(JevMarioStageId.world1_1);
      expect(store.stateOf(JevMarioStageId.world1_2).deaths, 1);

      final reset = store.resetStage(JevMarioStageId.world1_2);

      final after11State = reset.stateOf(JevMarioStageId.world1_1);
      final after11Events = reset.eventsOf(JevMarioStageId.world1_1);
      expect(reset.stateOf(JevMarioStageId.world1_2).isPristine, isTrue);
      expect(reset.eventsOf(JevMarioStageId.world1_2), isEmpty);
      expect(after11State.frames, before11State.frames);
      expect(after11State.cleared, isTrue);
      expect(after11Events.length, before11Events.length);
      // 元のストアは不変。
      expect(store.stateOf(JevMarioStageId.world1_2).deaths, 1);
    });

    test('events carry the stage-specific telemetry namespace', () {
      final store = JevMarioStageTelemetryStore()
          .record(stage: JevMarioStageId.world1_2, name: 'enter', frame: 1)
          .record(stage: JevMarioStageId.world1_1, name: 'enter', frame: 1);
      expect(
        store.eventsOf(JevMarioStageId.world1_2).single.namespace,
        'jev_mario.world1_2',
      );
      expect(
        store.eventsOf(JevMarioStageId.world1_1).single.namespace,
        'jev_mario.world1_1',
      );
    });
  });

  group('four-backend comparison', () {
    test('accepts four distinct backends with honest clear evidence', () {
      final runs = <JevMarioBackendRun>[
        _run('backend_a', cleared: true, evidence: 'replay-001'),
        _run('backend_b', failure: 'timeout'),
        _run('backend_c', assistance: JevMarioAssistance.none),
        _run('backend_d'),
      ];
      expect(service.validateBackendRuns(runs).isValid, isTrue);

      final summaries = service.summarizeByBackend(runs);
      expect(summaries.length, 4);
      final a = summaries.firstWhere((item) => item.backendId == 'backend_a');
      final b = summaries.firstWhere((item) => item.backendId == 'backend_b');
      final c = summaries.firstWhere((item) => item.backendId == 'backend_c');
      expect(a.verifiedClearCount, 1);
      expect(b.failureCount, 1);
      expect(b.verifiedClearCount, 0);
      expect(c.assistedRunCount, 0);
    });

    test('rejects fabricated clears and wrong backend counts', () {
      final errors = service.validateBackendRuns(<JevMarioBackendRun>[
        _run('backend_a', cleared: true),
        _run(
          'backend_b',
          cleared: true,
          evidence: 'replay-002',
          kind: JevMarioInferenceKind.mock,
        ),
        _run('backend_c', evidence: 'replay-003'),
      ]).errors;
      expect(
        errors,
        containsAll(<String>[
          'clear_requires_evidence:backend_a',
          'mock_run_cannot_claim_clear:backend_b',
          'evidence_without_clear:backend_c',
          'exactly_4_distinct_backends_required',
        ]),
      );
    });

    test('mock clears are never counted as verified clears', () {
      final summaries = service.summarizeByBackend(<JevMarioBackendRun>[
        _run(
          'backend_a',
          cleared: true,
          evidence: 'replay-009',
          kind: JevMarioInferenceKind.mock,
        ),
      ]);
      expect(summaries.single.verifiedClearCount, 0);
    });
  });
}
