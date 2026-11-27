import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_checkpoint_resume_service.dart';

void main() {
  test('runOrResume completes all steps and emits progress stream updates',
      () async {
    final service = AiCheckpointResumeService();
    addTearDown(service.dispose);

    final emittedStatuses = <AiCheckpointTaskStatus>[];
    final sub = service.progressStream.listen((task) {
      emittedStatuses.add(task.status);
    });
    addTearDown(sub.cancel);

    final result = await service.runOrResume(
      taskId: 'pipeline-1',
      steps: [
        AiCheckpointPipelineStep(
          name: 'fetch',
          execute: (_) async => 'context-a',
        ),
        AiCheckpointPipelineStep(
          name: 'reason',
          execute: (ctx) async => 'done:${ctx.stepOutputs['fetch']}',
        ),
      ],
    );

    await Future<void>.delayed(Duration.zero);

    expect(result.status, AiCheckpointTaskStatus.completed);
    expect(result.lastCompletedStepIndex, 1);
    expect(result.progressRatio, 1.0);
    expect(result.stepOutputs['reason'], 'done:context-a');
    expect(emittedStatuses.first, AiCheckpointTaskStatus.running);
    expect(emittedStatuses.last, AiCheckpointTaskStatus.completed);
  });

  test('runOrResume resumes from failed step without re-running step 0',
      () async {
    final service = AiCheckpointResumeService();
    addTearDown(service.dispose);

    final calls = <String>[];
    var failSecondStep = true;

    final steps = [
      AiCheckpointPipelineStep(
        name: 'step_0',
        execute: (_) async {
          calls.add('step_0');
          return 'ok-0';
        },
      ),
      AiCheckpointPipelineStep(
        name: 'step_1',
        execute: (_) async {
          calls.add('step_1');
          if (failSecondStep) {
            throw StateError('transient ai error');
          }
          return 'ok-1';
        },
      ),
      AiCheckpointPipelineStep(
        name: 'step_2',
        execute: (ctx) async {
          calls.add('step_2');
          return '${ctx.stepOutputs['step_0']}+${ctx.stepOutputs['step_1']}';
        },
      ),
    ];

    final firstRun = await service.runOrResume(
      taskId: 'pipeline-resume',
      steps: steps,
      maxRetries: 3,
    );
    expect(firstRun.status, AiCheckpointTaskStatus.retrying);
    expect(firstRun.lastCompletedStepIndex, 0);
    expect(firstRun.resumeStartIndex, 1);
    expect(calls, ['step_0', 'step_1']);

    failSecondStep = false;
    final resumed = await service.runOrResume(
      taskId: 'pipeline-resume',
      steps: steps,
      maxRetries: 3,
    );
    expect(resumed.status, AiCheckpointTaskStatus.completed);
    expect(resumed.stepOutputs['step_2'], 'ok-0+ok-1');
    expect(calls, ['step_0', 'step_1', 'step_1', 'step_2']);
  });

  test('runOrResume isolates to DLQ after maxRetries and replays safely',
      () async {
    final service = AiCheckpointResumeService();
    addTearDown(service.dispose);

    var shouldFail = true;
    final calls = <String>[];
    final steps = [
      AiCheckpointPipelineStep(
        name: 'prepare',
        execute: (_) async {
          calls.add('prepare');
          return 'ready';
        },
      ),
      AiCheckpointPipelineStep(
        name: 'infer',
        execute: (_) async {
          calls.add('infer');
          if (shouldFail) {
            throw StateError('503 unavailable');
          }
          return 'inferred';
        },
      ),
    ];

    final attempt1 = await service.runOrResume(
      taskId: 'pipeline-dlq',
      steps: steps,
      maxRetries: 2,
    );
    expect(attempt1.status, AiCheckpointTaskStatus.retrying);

    final attempt2 = await service.runOrResume(
      taskId: 'pipeline-dlq',
      steps: steps,
      maxRetries: 2,
    );
    expect(attempt2.status, AiCheckpointTaskStatus.dlq);
    expect(attempt2.quarantinedAt, isNotNull);

    final dlq = await service.listDlq();
    expect(dlq.length, 1);
    expect(dlq.first.taskId, 'pipeline-dlq');

    // Quarantined tasks are skipped until manually replayed.
    final skipped = await service.runOrResume(
      taskId: 'pipeline-dlq',
      steps: steps,
      maxRetries: 2,
    );
    expect(skipped.status, AiCheckpointTaskStatus.dlq);
    expect(calls, ['prepare', 'infer', 'infer']);

    shouldFail = false;
    final replayed = await service.replayFromDlq('pipeline-dlq');
    expect(replayed?.status, AiCheckpointTaskStatus.pending);
    expect(replayed?.attemptCount, 0);

    final completed = await service.runOrResume(
      taskId: 'pipeline-dlq',
      steps: steps,
      maxRetries: 2,
    );
    expect(completed.status, AiCheckpointTaskStatus.completed);
    expect(await service.listDlq(), isEmpty);
    expect(calls, ['prepare', 'infer', 'infer', 'infer']);
  });
}
