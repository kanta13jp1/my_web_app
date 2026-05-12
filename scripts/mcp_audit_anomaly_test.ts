import {
  type AuditRow,
  buildSlackPayload,
  evaluateMcpAuditAnomalies,
} from "./mcp_audit_anomaly.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function row(
  client_id: string,
  minutesAgo: number,
  response_status = 200,
  tool_name = "wbs.tasks.list",
  id: string = crypto.randomUUID(),
  cross_server_trace?: string,
): AuditRow {
  const invoked = new Date(Date.UTC(2026, 4, 9, 0, 0, 0));
  invoked.setUTCMinutes(invoked.getUTCMinutes() - minutesAgo);
  return {
    id,
    client_id,
    tool_name,
    response_status,
    invoked_at: invoked.toISOString(),
    cross_server_trace,
  };
}

Deno.test("evaluateMcpAuditAnomalies returns empty for quiet clients", () => {
  const now = new Date(Date.UTC(2026, 4, 9, 0, 0, 0));
  const rows = [
    row("client-a", 2),
    row("client-a", 8),
    row("client-a", 20),
    row("client-b", 3),
  ];
  const anomalies = evaluateMcpAuditAnomalies(rows, now, {
    minInvocationThreshold: 5,
    minFailureThreshold: 5,
  });
  assert(anomalies.length === 0, "quiet clients should not alert");
});

Deno.test("evaluateMcpAuditAnomalies detects recent invocation bursts", () => {
  const now = new Date(Date.UTC(2026, 4, 9, 0, 0, 0));
  const baseline = [
    row("client-a", 30),
    row("client-a", 40),
    row("client-a", 50),
  ];
  const burst = Array.from({ length: 8 }, (_, i) => row("client-a", i % 4));
  const anomalies = evaluateMcpAuditAnomalies([...baseline, ...burst], now, {
    minInvocationThreshold: 5,
    minFailureThreshold: 5,
  });
  assert(anomalies.length === 1, "burst should alert");
  assert(anomalies[0].client_id === "client-a", "client-a should alert");
  assert(anomalies[0].recent_count === 8, "recent count should be retained");
});

Deno.test("evaluateMcpAuditAnomalies detects failure bursts", () => {
  const now = new Date(Date.UTC(2026, 4, 9, 0, 0, 0));
  const rows = Array.from(
    { length: 6 },
    (_, i) => row("client-a", i % 4, 401, "memory.search"),
  );
  const anomalies = evaluateMcpAuditAnomalies(rows, now, {
    minInvocationThreshold: 50,
    minFailureThreshold: 5,
  });
  assert(anomalies.length === 1, "failure burst should alert");
  assert(
    anomalies[0].recent_failures === 6,
    "failure count should be retained",
  );
});

Deno.test("evaluateMcpAuditAnomalies detects cross-server traces", () => {
  const now = new Date(Date.UTC(2026, 4, 9, 0, 0, 0));
  const rows = [
    row("client-a", 1, 200, "memory.search", "a1", "trace-1"),
    row("client-b", 1, 200, "wbs.tasks.list", "b1", "trace-1"),
  ];
  const anomalies = evaluateMcpAuditAnomalies(rows, now, {
    minInvocationThreshold: 50,
    minFailureThreshold: 50,
  });
  assert(anomalies.length === 2, "both clients in cross trace should alert");
  assert(
    anomalies.every((anomaly) => anomaly.score >= 0.9),
    "cross trace should have high score",
  );
});

Deno.test("buildSlackPayload includes top anomaly details", () => {
  const payload = buildSlackPayload({
    checked_at: "2026-05-09T00:00:00.000Z",
    rows_scanned: 1,
    recent_window_minutes: 5,
    baseline_hours: 24,
    dry_run: false,
    suspend_enabled: false,
    anomalies: [{
      client_id: "client-a",
      score: 0.91,
      recent_count: 31,
      recent_failures: 0,
      distinct_tools: 1,
      invocation_threshold: 30,
      failure_threshold: 10,
      reasons: ["recent invocation count 31 exceeded threshold 30"],
      recent_row_ids: ["row-1"],
    }],
  });
  const text = JSON.stringify(payload);
  assert(text.includes("client-a"), "payload should include client id");
  assert(text.includes("score=0.91"), "payload should include score");
});
