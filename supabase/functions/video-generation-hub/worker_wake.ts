export type WorkerWakeConfiguration = {
  url: string;
  token: string;
};

export function loadWorkerWakeConfiguration(
  readEnvironment: (key: string) => string | undefined = Deno.env.get,
): WorkerWakeConfiguration | null {
  const rawUrl = (readEnvironment("VIDEO_WORKER_WAKE_URL") ?? "").trim();
  const token = (readEnvironment("VIDEO_WORKER_WAKE_TOKEN") ?? "").trim();
  let url: URL | null = null;
  try {
    url = new URL(rawUrl);
  } catch (_) {
    return null;
  }
  if (
    !url || url.protocol !== "https:" || url.username || url.password ||
    url.search || url.hash || token.length < 32 || token.length > 256
  ) {
    return null;
  }
  return { url: url.toString(), token };
}

export async function wakeVideoWorker(
  jobId: string,
  configuration: WorkerWakeConfiguration,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const response = await fetchImpl(configuration.url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${configuration.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ job_id: jobId }),
    signal: AbortSignal.timeout(12_000),
  });
  if (response.status !== 200 && response.status !== 202) {
    try {
      await response.body?.cancel();
    } catch (_) {
      // The status code is authoritative; body cleanup is best-effort.
    }
    throw new Error("worker_wake_failed");
  }
}
