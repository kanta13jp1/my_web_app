import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AsyncJobQueryResult,
  type AsyncJobRecord,
  type AsyncJobStatus,
  type AsyncJobStore,
  handleAsyncJobEnqueue,
  handleAsyncJobList,
  handleAsyncJobStatus,
  handleAsyncJobUpdateStatus,
} from "./async_jobs.ts";

class InMemoryAsyncJobStore implements AsyncJobStore {
  rows: AsyncJobRecord[] = [];
  private seq = 0;

  insertJob(
    values: Record<string, unknown>,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord>> {
    this.seq += 1;
    const record: AsyncJobRecord = {
      id: `job-${this.seq}`,
      user_id: String(values.user_id ?? ""),
      job_type: String(values.job_type ?? ""),
      title: String(values.title ?? ""),
      status: "queued",
      progress_percent: Number(values.progress_percent ?? 0),
      request_payload: (values.request_payload as Record<string, unknown>) ??
        {},
      result_payload: null,
      error_message: null,
      created_at: String(values.created_at ?? ""),
      updated_at: String(values.updated_at ?? ""),
      started_at: null,
      completed_at: null,
    };
    this.rows.push(record);
    return Promise.resolve({ data: { ...record }, error: null });
  }

  getJob(
    jobId: string,
    userId: string,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord>> {
    const found = this.rows.find((r) => r.id === jobId && r.user_id === userId);
    return Promise.resolve({ data: found ? { ...found } : null, error: null });
  }

  listJobs(
    userId: string,
    status: AsyncJobStatus | null,
    limit: number,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord[]>> {
    const matched = this.rows
      .filter((r) =>
        r.user_id === userId && (status === null || r.status === status)
      )
      .reverse()
      .slice(0, limit)
      .map((r) => ({ ...r }));
    return Promise.resolve({ data: matched, error: null });
  }

  updateJob(
    jobId: string,
    userId: string,
    updates: Record<string, unknown>,
  ): Promise<AsyncJobQueryResult<AsyncJobRecord>> {
    const found = this.rows.find((r) => r.id === jobId && r.user_id === userId);
    if (!found) {
      return Promise.resolve({ data: null, error: null });
    }
    Object.assign(found, updates);
    return Promise.resolve({ data: { ...found }, error: null });
  }
}

Deno.test("async_job.enqueue returns 202 and enforces user isolation on status/list", async () => {
  const store = new InMemoryAsyncJobStore();
  const enq = await handleAsyncJobEnqueue(
    store,
    "user-a",
    {
      job_type: "monthly_report_export",
      title: "月次レポート集計",
      request_payload: { month: "2026-11" },
    },
    "2026-11-24T00:00:00Z",
  );
  assertEquals(enq.status, 202);
  assertEquals(enq.body.job_id, "job-1");

  const forbidden = await handleAsyncJobStatus(store, "user-b", {
    job_id: "job-1",
  });
  assertEquals(forbidden.status, 404);

  const okStatus = await handleAsyncJobStatus(store, "user-a", {
    job_id: "job-1",
  });
  assertEquals(okStatus.status, 200);
  assertEquals((okStatus.body.job as AsyncJobRecord).status, "queued");

  const list = await handleAsyncJobList(store, "user-a", { limit: 10 });
  assertEquals(list.status, 200);
  assertEquals((list.body.jobs as AsyncJobRecord[]).length, 1);
});

Deno.test("async_job.update_status enforces state machine transitions", async () => {
  const store = new InMemoryAsyncJobStore();
  await handleAsyncJobEnqueue(store, "user-a", {
    job_type: "bulk_aggregation",
  });

  const running = await handleAsyncJobUpdateStatus(store, "user-a", {
    job_id: "job-1",
    status: "running",
    progress_percent: 45,
  });
  assertEquals(running.status, 200);
  assertEquals((running.body.job as AsyncJobRecord).progress_percent, 45);

  const completed = await handleAsyncJobUpdateStatus(store, "user-a", {
    job_id: "job-1",
    status: "completed",
    result_payload: { rows: 120 },
  });
  assertEquals(completed.status, 200);
  assertEquals((completed.body.job as AsyncJobRecord).progress_percent, 100);

  const invalidAfterDone = await handleAsyncJobUpdateStatus(store, "user-a", {
    job_id: "job-1",
    status: "running",
  });
  assertEquals(invalidAfterDone.status, 409);
});
