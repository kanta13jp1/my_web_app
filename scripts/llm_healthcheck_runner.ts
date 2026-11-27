import {
  validateProbeUrl,
} from "../supabase/functions/_shared/ssrf_probe_guard.ts";

export interface RunnerEndpointTarget {
  provider_name: string;
  endpoint_url: string;
  method?: "GET" | "HEAD";
  timeout_ms?: number;
}

export interface RunnerProbeOutcome {
  provider_name: string;
  endpoint_url: string;
  status: "healthy" | "degraded" | "down";
  http_status: number | null;
  latency_ms: number;
  error_type: string | null;
  error_message: string | null;
}

export async function runScheduledHealthcheck(params: {
  targets: readonly RunnerEndpointTarget[];
  dryRun: boolean;
  webhookUrl?: string;
  fetcher?: typeof fetch;
  nowMs?: () => number;
}): Promise<{
  checked_at: string;
  dry_run: boolean;
  total_targets: number;
  down_count: number;
  results: RunnerProbeOutcome[];
  alert_delivery: string;
}> {
  const fetcher = params.fetcher ?? fetch;
  const nowMs = params.nowMs ?? (() => Date.now());
  const results: RunnerProbeOutcome[] = [];

  for (const target of params.targets) {
    const check = validateProbeUrl(target.endpoint_url);
    if (!check.ok) {
      results.push({
        provider_name: target.provider_name,
        endpoint_url: target.endpoint_url,
        status: "down",
        http_status: null,
        latency_ms: 0,
        error_type: "ssrf_blocked",
        error_message: check.reason ?? "Blocked URL",
      });
      continue;
    }

    if (params.dryRun) {
      results.push({
        provider_name: target.provider_name,
        endpoint_url: check.normalizedUrl,
        status: "healthy",
        http_status: 200,
        latency_ms: 1,
        error_type: null,
        error_message: null,
      });
      continue;
    }

    const timeoutMs = Math.max(500, Math.min(15000, target.timeout_ms ?? 5000));
    const started = nowMs();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const resp = await fetcher(check.normalizedUrl, {
        method: target.method ?? "GET",
        redirect: "manual",
        signal: controller.signal,
      });
      const latency = Math.max(0, Math.round(nowMs() - started));
      if (resp.status >= 200 && resp.status < 300) {
        results.push({
          provider_name: target.provider_name,
          endpoint_url: check.normalizedUrl,
          status: latency > timeoutMs * 0.8 ? "degraded" : "healthy",
          http_status: resp.status,
          latency_ms: latency,
          error_type: null,
          error_message: null,
        });
      } else {
        results.push({
          provider_name: target.provider_name,
          endpoint_url: check.normalizedUrl,
          status: "down",
          http_status: resp.status,
          latency_ms: latency,
          error_type: "http_error",
          error_message: `HTTP ${resp.status}`,
        });
      }
    } catch (err) {
      const latency = Math.max(0, Math.round(nowMs() - started));
      const isAbort = err instanceof Error && err.name === "AbortError";
      results.push({
        provider_name: target.provider_name,
        endpoint_url: check.normalizedUrl,
        status: "down",
        http_status: null,
        latency_ms: latency,
        error_type: isAbort ? "timeout" : "network_error",
        error_message: err instanceof Error ? err.message : String(err),
      });
    } finally {
      clearTimeout(timer);
    }
  }

  const downResults = results.filter((r) => r.status === "down");
  let alertDelivery = "not_needed";
  if (downResults.length > 0) {
    const hook = (params.webhookUrl ?? "").trim();
    if (params.dryRun) {
      alertDelivery = "dry_run_skipped";
    } else if (!hook) {
      alertDelivery = "logged_no_webhook";
    } else {
      const hookCheck = validateProbeUrl(hook);
      if (!hookCheck.ok) {
        alertDelivery = "skipped_unsafe_webhook";
      } else {
        try {
          const resp = await fetcher(hookCheck.normalizedUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            redirect: "manual",
            body: JSON.stringify({
              down_count: downResults.length,
              providers: downResults.map((r) => r.provider_name),
            }),
          });
          alertDelivery = resp.ok ? "notified" : `webhook_http_${resp.status}`;
        } catch {
          alertDelivery = "webhook_error_non_blocking";
        }
      }
    }
  }

  return {
    checked_at: new Date().toISOString(),
    dry_run: params.dryRun,
    total_targets: results.length,
    down_count: downResults.length,
    results,
    alert_delivery: alertDelivery,
  };
}

if (import.meta.main) {
  const args = new Set(Deno.args);
  const dryRun = args.has("--dry-run") ||
    Deno.env.get("DRY_RUN_INPUT") !== "false";
  const rawTargets = (
    Deno.env.get("LLM_HEALTHCHECK_TARGETS_JSON") ?? ""
  ).trim();
  let targets: RunnerEndpointTarget[] = [];
  if (rawTargets) {
    try {
      const parsed = JSON.parse(rawTargets);
      if (Array.isArray(parsed)) {
        targets = parsed as RunnerEndpointTarget[];
      }
    } catch {
      targets = [];
    }
  }
  const summary = await runScheduledHealthcheck({
    targets,
    dryRun,
    webhookUrl: Deno.env.get("LLM_HEALTHCHECK_WEBHOOK_URL") ?? "",
  });
  await Deno.writeTextFile(
    "llm-healthcheck-report.json",
    `${JSON.stringify(summary, null, 2)}\n`,
  );
  const mdLines = [
    "## New LLM Provider Healthcheck Report",
    `- Checked at: ${summary.checked_at}`,
    `- Total targets: ${summary.total_targets}`,
    `- Down count: ${summary.down_count}`,
    `- Alert delivery: ${summary.alert_delivery}`,
  ];
  await Deno.writeTextFile(
    "llm-healthcheck-report.md",
    `${mdLines.join("\n")}\n`,
  );
}
