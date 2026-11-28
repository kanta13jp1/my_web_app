export type CheckpointTaskStatus =
  | "pending"
  | "running"
  | "retrying"
  | "completed"
  | "dlq";

export type CheckpointStepStatus = "pending" | "completed" | "failed";

export const CHECKPOINT_STATUS_LABELS = {
  pending: "待機中",
  running: "実行中",
  retrying: "再試行待ち",
  completed: "完了",
  dlq: "DLQ隔離",
} as const satisfies Record<CheckpointTaskStatus, string>;

export const CHECKPOINT_STEP_STATUS_LABELS = {
  pending: "未実行",
  completed: "完了",
  failed: "失敗",
} as const satisfies Record<CheckpointStepStatus, string>;

export const DEFAULT_CHECKPOINT_MAX_RETRIES = 3;

export interface CheckpointStepRecord {
  index: number;
  name: string;
  status: CheckpointStepStatus;
  errorMessage: string | null;
  completedAt: string | null;
}

export interface AiCheckpointTask {
  taskId: string;
  status: CheckpointTaskStatus;
  attemptCount: number;
  maxRetries: number;
  lastCompletedStepIndex: number;
  steps: CheckpointStepRecord[];
  stepOutputs: Record<string, unknown>;
  lastError: string | null;
  quarantinedAt: string | null;
  updatedAt: string;
}

export interface CheckpointStore {
  loadTask(taskId: string): Promise<AiCheckpointTask | null>;
  saveTask(task: AiCheckpointTask): Promise<void>;
  moveToDlq(task: AiCheckpointTask): Promise<void>;
  listDlq(): Promise<AiCheckpointTask[]>;
}

export class InMemoryCheckpointStore implements CheckpointStore {
  private readonly tasks = new Map<string, AiCheckpointTask>();
  private readonly dlq = new Map<string, AiCheckpointTask>();

  loadTask(taskId: string): Promise<AiCheckpointTask | null> {
    const found = this.tasks.get(taskId);
    return Promise.resolve(found ? structuredClone(found) : null);
  }

  saveTask(task: AiCheckpointTask): Promise<void> {
    this.tasks.set(task.taskId, structuredClone(task));
    if (task.status !== "dlq") {
      this.dlq.delete(task.taskId);
    }
    return Promise.resolve();
  }

  moveToDlq(task: AiCheckpointTask): Promise<void> {
    const copy = structuredClone(task);
    this.tasks.set(task.taskId, copy);
    this.dlq.set(task.taskId, copy);
    return Promise.resolve();
  }

  listDlq(): Promise<AiCheckpointTask[]> {
    return Promise.resolve(
      Array.from(this.dlq.values()).map((item) => structuredClone(item)),
    );
  }
}

export interface AiPipelineStepContext {
  taskId: string;
  stepIndex: number;
  stepOutputs: Record<string, unknown>;
}

export interface AiPipelineStep {
  name: string;
  execute(ctx: AiPipelineStepContext): Promise<unknown>;
}

export interface RunCheckpointPipelineOptions {
  taskId: string;
  steps: readonly AiPipelineStep[];
  store: CheckpointStore;
  maxRetries?: number;
  nowIso?: () => string;
}

export function computeResumeStartIndex(task: AiCheckpointTask): number {
  const nextIndex = task.lastCompletedStepIndex + 1;
  if (nextIndex < 0) return 0;
  return Math.min(nextIndex, task.steps.length);
}

function createInitialTask(
  taskId: string,
  steps: readonly AiPipelineStep[],
  maxRetries: number,
  nowIso: string,
): AiCheckpointTask {
  return {
    taskId,
    status: "pending",
    attemptCount: 0,
    maxRetries,
    lastCompletedStepIndex: -1,
    steps: steps.map((step, index) => ({
      index,
      name: step.name,
      status: "pending",
      errorMessage: null,
      completedAt: null,
    })),
    stepOutputs: {},
    lastError: null,
    quarantinedAt: null,
    updatedAt: nowIso,
  };
}

export async function runCheckpointPipeline(
  options: RunCheckpointPipelineOptions,
): Promise<AiCheckpointTask> {
  const now = options.nowIso ?? (() => new Date().toISOString());
  const maxRetries = Math.max(
    1,
    options.maxRetries ?? DEFAULT_CHECKPOINT_MAX_RETRIES,
  );
  const existing = await options.store.loadTask(options.taskId);
  const task = existing ??
    createInitialTask(options.taskId, options.steps, maxRetries, now());

  if (task.status === "completed" || task.status === "dlq") {
    return task;
  }

  const startIndex = computeResumeStartIndex(task);
  task.status = "running";
  task.updatedAt = now();
  await options.store.saveTask(task);

  for (let i = startIndex; i < options.steps.length; i++) {
    const step = options.steps[i];
    try {
      const output = await step.execute({
        taskId: task.taskId,
        stepIndex: i,
        stepOutputs: { ...task.stepOutputs },
      });
      const completedAt = now();
      task.stepOutputs[step.name] = output;
      task.lastCompletedStepIndex = i;
      task.steps[i] = {
        index: i,
        name: step.name,
        status: "completed",
        errorMessage: null,
        completedAt,
      };
      task.lastError = null;
      task.updatedAt = completedAt;
      await options.store.saveTask(task);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const failedAt = now();
      task.attemptCount += 1;
      task.lastError = message;
      task.steps[i] = {
        index: i,
        name: step.name,
        status: "failed",
        errorMessage: message,
        completedAt: null,
      };
      task.updatedAt = failedAt;

      if (task.attemptCount >= task.maxRetries) {
        task.status = "dlq";
        task.quarantinedAt = failedAt;
        await options.store.moveToDlq(task);
      } else {
        task.status = "retrying";
        await options.store.saveTask(task);
      }
      return task;
    }
  }

  task.status = "completed";
  task.updatedAt = now();
  await options.store.saveTask(task);
  return task;
}

export async function replayFromDlq(
  taskId: string,
  store: CheckpointStore,
  nowIso?: () => string,
): Promise<AiCheckpointTask | null> {
  const now = nowIso ?? (() => new Date().toISOString());
  const task = await store.loadTask(taskId);
  if (!task || task.status !== "dlq") {
    return task;
  }

  task.status = "pending";
  task.attemptCount = 0;
  task.quarantinedAt = null;
  task.lastError = null;
  task.updatedAt = now();
  await store.saveTask(task);
  return task;
}
