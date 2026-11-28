import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AiPipelineStep,
  computeResumeStartIndex,
  InMemoryCheckpointStore,
  replayFromDlq,
  runCheckpointPipeline,
} from "./ai_checkpoint_resume.ts";

Deno.test(
  "runCheckpointPipeline completes all steps and skips completed on re-run",
  async () => {
    const store = new InMemoryCheckpointStore();
    const calls: string[] = [];

    const steps: AiPipelineStep[] = [
      {
        name: "extract",
        execute: () => {
          calls.push("extract");
          return Promise.resolve({ tokens: 120 });
        },
      },
      {
        name: "summarize",
        execute: (ctx) => {
          calls.push("summarize");
          return Promise.resolve({
            basedOn: ctx.stepOutputs.extract,
            summary: "ok",
          });
        },
      },
    ];

    const done = await runCheckpointPipeline({
      taskId: "job-1",
      steps,
      store,
      nowIso: () => "2026-11-26T06:00:00Z",
    });

    assertEquals(done.status, "completed");
    assertEquals(done.lastCompletedStepIndex, 1);
    assertEquals(calls, ["extract", "summarize"]);

    const rerun = await runCheckpointPipeline({
      taskId: "job-1",
      steps,
      store,
    });
    assertEquals(rerun.status, "completed");
    assertEquals(calls, ["extract", "summarize"]);
  },
);

Deno.test(
  "runCheckpointPipeline resumes from failed step without re-running step 0",
  async () => {
    const store = new InMemoryCheckpointStore();
    const calls: string[] = [];
    let failStep2 = true;

    const steps: AiPipelineStep[] = [
      {
        name: "step1_fetch",
        execute: () => {
          calls.push("step1_fetch");
          return Promise.resolve("raw-data");
        },
      },
      {
        name: "step2_infer",
        execute: () => {
          calls.push("step2_infer");
          if (failStep2) {
            return Promise.reject(new Error("transient upstream timeout"));
          }
          return Promise.resolve("inferred-json");
        },
      },
      {
        name: "step3_format",
        execute: (ctx) => {
          calls.push("step3_format");
          const prev = ctx.stepOutputs.step2_infer;
          return Promise.resolve(`final:${String(prev)}`);
        },
      },
    ];

    const first = await runCheckpointPipeline({
      taskId: "job-resume",
      steps,
      store,
      maxRetries: 3,
    });

    assertEquals(first.status, "retrying");
    assertEquals(first.attemptCount, 1);
    assertEquals(first.lastCompletedStepIndex, 0);
    assertEquals(computeResumeStartIndex(first), 1);
    assertEquals(calls, ["step1_fetch", "step2_infer"]);

    failStep2 = false;
    const resumed = await runCheckpointPipeline({
      taskId: "job-resume",
      steps,
      store,
      maxRetries: 3,
    });

    assertEquals(resumed.status, "completed");
    assertEquals(resumed.lastCompletedStepIndex, 2);
    assertEquals(resumed.stepOutputs.step3_format, "final:inferred-json");
    assertEquals(calls, [
      "step1_fetch",
      "step2_infer",
      "step2_infer",
      "step3_format",
    ]);
  },
);

Deno.test(
  "runCheckpointPipeline isolates to DLQ after maxRetries and replays safely",
  async () => {
    const store = new InMemoryCheckpointStore();
    let shouldFail = true;
    const stepCalls: string[] = [];

    const steps: AiPipelineStep[] = [
      {
        name: "prepare",
        execute: () => {
          stepCalls.push("prepare");
          return Promise.resolve("prepared");
        },
      },
      {
        name: "invoke_llm",
        execute: () => {
          stepCalls.push("invoke_llm");
          if (shouldFail) {
            return Promise.reject(new Error("503 service unavailable"));
          }
          return Promise.resolve("ok");
        },
      },
    ];

    const attempt1 = await runCheckpointPipeline({
      taskId: "job-dlq",
      steps,
      store,
      maxRetries: 2,
    });
    assertEquals(attempt1.status, "retrying");

    const attempt2 = await runCheckpointPipeline({
      taskId: "job-dlq",
      steps,
      store,
      maxRetries: 2,
    });
    assertEquals(attempt2.status, "dlq");
    assertExists(attempt2.quarantinedAt);

    const dlqItems = await store.listDlq();
    assertEquals(dlqItems.length, 1);
    assertEquals(dlqItems[0].taskId, "job-dlq");

    // Auto-run while quarantined in DLQ is a no-op.
    const blocked = await runCheckpointPipeline({
      taskId: "job-dlq",
      steps,
      store,
      maxRetries: 2,
    });
    assertEquals(blocked.status, "dlq");
    assertEquals(stepCalls, ["prepare", "invoke_llm", "invoke_llm"]);

    // Manual replay resets attemptCount while keeping prepare checkpoint.
    shouldFail = false;
    const replayed = await replayFromDlq("job-dlq", store);
    assertExists(replayed);
    assertEquals(replayed.status, "pending");
    assertEquals(replayed.attemptCount, 0);
    assertEquals(replayed.lastCompletedStepIndex, 0);

    const finished = await runCheckpointPipeline({
      taskId: "job-dlq",
      steps,
      store,
      maxRetries: 2,
    });
    assertEquals(finished.status, "completed");
    assertEquals((await store.listDlq()).length, 0);
    assertEquals(stepCalls, [
      "prepare",
      "invoke_llm",
      "invoke_llm",
      "invoke_llm",
    ]);
  },
);
