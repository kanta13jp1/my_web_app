import {
  addMonths,
  type AnomalyDbQuery,
  type AnomalyDetectionDb,
  type AnomalyExpenseRow,
  computeCategoryAnomalies,
  handleDetectAnomaliesAction,
  handleScanAllAction,
  resolveTargetMonth,
  severityFor,
} from "./anomaly_detection.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Assertion failed:\nactual:   ${JSON.stringify(actual)}\nexpected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}

function assertThrows(fn: () => unknown, includes: string) {
  let thrown = false;
  try {
    fn();
  } catch (err) {
    thrown = true;
    const message = err instanceof Error ? err.message : String(err);
    if (!message.includes(includes)) {
      throw new Error(
        `expected error containing "${includes}", got: ${message}`,
      );
    }
  }
  if (!thrown) throw new Error(`expected error containing "${includes}"`);
}

function row(
  posted: string,
  amount: number,
  category: string,
  status = "auto_confirmed",
): AnomalyExpenseRow {
  return { posted_at: posted, amount, category, status };
}

Deno.test("addMonths handles year boundaries", () => {
  assertEquals(addMonths("2026-01-01", -3), "2025-10-01");
  assertEquals(addMonths("2026-12-01", 1), "2027-01-01");
});

Deno.test("resolveTargetMonth accepts YYYY-MM and YYYY-MM-01", () => {
  assertEquals(
    resolveTargetMonth("2026-07-21T00:00:00Z", "2026-06"),
    "2026-06-01",
  );
  assertEquals(
    resolveTargetMonth("2026-07-21T00:00:00Z", "2026-06-01"),
    "2026-06-01",
  );
  assertThrows(
    () => resolveTargetMonth("2026-07-21T00:00:00Z", "2026/06"),
    "target_month",
  );
  assertThrows(
    () => resolveTargetMonth("2026-07-21T00:00:00Z", "2026-13"),
    "out of range",
  );
});

Deno.test("resolveTargetMonth defaults to previous complete month in JST", () => {
  assertEquals(resolveTargetMonth("2026-07-21T00:30:00Z"), "2026-06-01");
  // 2026-06-30T15:30Z = 2026-07-01T00:30 JST → 前の完了月は 6 月
  assertEquals(resolveTargetMonth("2026-06-30T15:30:00Z"), "2026-06-01");
  // その直前 (JST でまだ 6/30) → 前の完了月は 5 月
  assertEquals(resolveTargetMonth("2026-06-30T14:30:00Z"), "2026-05-01");
});

Deno.test("severity tiers are deterministic", () => {
  assertEquals(severityFor(0.2), "low");
  assertEquals(severityFor(0.49), "low");
  assertEquals(severityFor(0.5), "medium");
  assertEquals(severityFor(0.99), "medium");
  assertEquals(severityFor(1.0), "high");
});

Deno.test("computeCategoryAnomalies flags >=20% deviation vs 3-month average", () => {
  const rows = [
    row("2026-03-05", 30000, "food"),
    row("2026-04-05", 30000, "food"),
    row("2026-05-05", 30000, "food"),
    row("2026-06-05", 39000, "food"),
  ];
  const outcome = computeCategoryAnomalies({ rows, targetMonth: "2026-06-01" });
  assertEquals(outcome.anomalies.length, 1);
  const anomaly = outcome.anomalies[0];
  assertEquals(anomaly.category, "food");
  assertEquals(anomaly.expected, 30000);
  assertEquals(anomaly.actual, 39000);
  assertEquals(anomaly.delta, 9000);
  assertEquals(anomaly.deviation_ratio, 0.3);
  assertEquals(anomaly.severity, "low");
  assertEquals(anomaly.months_averaged, 3);
});

Deno.test("exactly 20% is flagged, 19.99% is not", () => {
  const base = [
    row("2026-03-05", 30000, "food"),
    row("2026-04-05", 30000, "food"),
    row("2026-05-05", 30000, "food"),
  ];
  const at20 = computeCategoryAnomalies({
    rows: [...base, row("2026-06-05", 36000, "food")],
    targetMonth: "2026-06-01",
  });
  assertEquals(at20.anomalies.length, 1);
  const below = computeCategoryAnomalies({
    rows: [...base, row("2026-06-05", 35999, "food")],
    targetMonth: "2026-06-01",
  });
  assertEquals(below.anomalies.length, 0);
});

Deno.test("rejected rows are excluded from sums", () => {
  const rows = [
    row("2026-05-05", 30000, "food"),
    row("2026-06-05", 30000, "food"),
    row("2026-06-06", 50000, "food", "rejected"),
  ];
  const outcome = computeCategoryAnomalies({ rows, targetMonth: "2026-06-01" });
  // rejected を除くと 30000 vs 30000 → 異常なし
  assertEquals(outcome.anomalies.length, 0);
});

Deno.test("months without rows are treated as unrecorded, not zero", () => {
  // 記録が 5 月に始まったユーザー: 3-4 月をゼロ扱いすると平均が萎んで
  // 偽陽性になる。行がある月 (5月) のみで平均する。
  const rows = [
    row("2026-05-05", 30000, "food"),
    row("2026-06-05", 33000, "food"),
  ];
  const outcome = computeCategoryAnomalies({ rows, targetMonth: "2026-06-01" });
  assertEquals(outcome.anomalies.length, 0);
  const spike = computeCategoryAnomalies({
    rows: [row("2026-05-05", 30000, "food"), row("2026-06-05", 60000, "food")],
    targetMonth: "2026-06-01",
  });
  assertEquals(spike.anomalies.length, 1);
  assertEquals(spike.anomalies[0].months_averaged, 1);
  assertEquals(spike.anomalies[0].severity, "high");
});

Deno.test("skip reasons: no_prior_history / no_target_data / nonpositive_expected", () => {
  const outcome = computeCategoryAnomalies({
    rows: [
      // food: 対象月のみ → no_prior_history
      row("2026-06-05", 10000, "food"),
      // utilities: 前歴のみ → no_target_data
      row("2026-05-05", 8000, "utilities"),
      // refunds: 前月合計が負 → nonpositive_expected
      row("2026-05-05", -5000, "refunds"),
      row("2026-06-05", 1000, "refunds"),
    ],
    targetMonth: "2026-06-01",
  });
  assertEquals(outcome.anomalies.length, 0);
  assertEquals(outcome.skipped, [
    { category: "food", reason: "no_prior_history" },
    { category: "refunds", reason: "nonpositive_expected" },
    { category: "utilities", reason: "no_target_data" },
  ]);
});

class FakeQuery implements AnomalyDbQuery {
  constructor(
    private readonly table: string,
    private readonly db: FakeAnomalyDb,
  ) {}

  select(): AnomalyDbQuery {
    return this;
  }
  eq(): AnomalyDbQuery {
    return this;
  }
  neq(): AnomalyDbQuery {
    return this;
  }
  gte(): AnomalyDbQuery {
    return this;
  }
  lt(): AnomalyDbQuery {
    return this;
  }
  order(): AnomalyDbQuery {
    return this;
  }
  range(from: number, to: number) {
    const rows = this.db.rowsFor(this.table).slice(from, to + 1);
    return Promise.resolve({ data: rows, error: null });
  }
  upsert(
    value: Record<string, unknown>,
    options?: { onConflict?: string },
  ) {
    this.db.upserts.push({
      table: this.table,
      value,
      onConflict: options?.onConflict ?? "",
    });
    return Promise.resolve({ error: null });
  }
}

class FakeAnomalyDb implements AnomalyDetectionDb {
  upserts: Array<{
    table: string;
    value: Record<string, unknown>;
    onConflict: string;
  }> = [];

  constructor(
    private readonly rows: Record<string, Record<string, unknown>[]>,
  ) {}

  from(table: string): AnomalyDbQuery {
    return new FakeQuery(table, this);
  }

  rowsFor(table: string) {
    return this.rows[table] ?? [];
  }
}

Deno.test("handleDetectAnomaliesAction persists anomalies idempotently", async () => {
  const db = new FakeAnomalyDb({
    expense_classifications: [
      row("2026-03-05", 30000, "food"),
      row("2026-04-05", 30000, "food"),
      row("2026-05-05", 30000, "food"),
      row("2026-06-05", 60000, "food"),
    ],
  });
  const result = await handleDetectAnomaliesAction({
    db,
    body: { target_month: "2026-06" },
    userId: "user-1",
    nowIso: "2026-07-21T03:00:00Z",
  });
  assertEquals(result.status, "ok");
  assertEquals(result.anomalies_detected, 1);
  assertEquals(result.explanation_enabled, false);
  assertEquals(db.upserts.length, 1);
  const upsert = db.upserts[0];
  assertEquals(upsert.table, "anomaly_detections");
  assertEquals(upsert.onConflict, "user_id,category,target_month");
  assertEquals(upsert.value.user_id, "user-1");
  assertEquals(upsert.value.target_month, "2026-06-01");
  assertEquals(upsert.value.category, "food");
  assertEquals(upsert.value.severity, "high");
  assertEquals(upsert.value.ai_explanation, null);
  // dismissed_at は供給しない = ユーザーの却下を再スキャンで復活させない
  assertEquals("dismissed_at" in upsert.value, false);
});

Deno.test("handleDetectAnomaliesAction requires login", async () => {
  const db = new FakeAnomalyDb({});
  let message = "";
  try {
    await handleDetectAnomaliesAction({
      db,
      body: {},
      userId: "",
      nowIso: "2026-07-21T03:00:00Z",
    });
  } catch (err) {
    message = err instanceof Error ? err.message : String(err);
  }
  assertEquals(message, "login required");
});

Deno.test("explanation flag ON calls provider and stores text", async () => {
  const db = new FakeAnomalyDb({
    expense_classifications: [
      row("2026-05-05", 30000, "food"),
      row("2026-06-05", 60000, "food"),
    ],
  });
  const calls: string[] = [];
  const result = await handleDetectAnomaliesAction({
    db,
    body: { target_month: "2026-06" },
    userId: "user-1",
    nowIso: "2026-07-21T03:00:00Z",
    explanationEnabled: true,
    invokeProvider: (request) => {
      calls.push(request.messages[0].content);
      return Promise.resolve({ ok: true, text: "食費が平均比+100%です。" });
    },
  });
  assertEquals(calls.length, 1);
  assertEquals(result.anomalies[0].ai_explanation, "食費が平均比+100%です。");
  assertEquals(db.upserts[0].value.ai_explanation, "食費が平均比+100%です。");
});

Deno.test("provider failure downgrades to warning, detection still persists", async () => {
  const db = new FakeAnomalyDb({
    expense_classifications: [
      row("2026-05-05", 30000, "food"),
      row("2026-06-05", 60000, "food"),
    ],
  });
  const result = await handleDetectAnomaliesAction({
    db,
    body: { target_month: "2026-06" },
    userId: "user-1",
    nowIso: "2026-07-21T03:00:00Z",
    explanationEnabled: true,
    invokeProvider: () =>
      Promise.resolve({ ok: false, error: "budgetExceeded:ef" }),
  });
  assertEquals(result.anomalies_detected, 1);
  assertEquals(result.anomalies[0].ai_explanation, null);
  assertEquals(result.warnings.length, 1);
  assertEquals(db.upserts.length, 1);
});

// ---- scan_all (#2478) ----

function urow(
  user: string,
  posted: string,
  amount: number,
  category: string,
  status = "auto_confirmed",
): Record<string, unknown> {
  return { user_id: user, posted_at: posted, amount, category, status };
}

type RowPredicate = (r: Record<string, unknown>) => boolean;

class FilteringFakeQuery implements AnomalyDbQuery {
  private filters: RowPredicate[] = [];

  constructor(
    private readonly table: string,
    private readonly db: FilteringFakeDb,
  ) {}

  select(): AnomalyDbQuery {
    return this;
  }
  eq(column: string, value: string): AnomalyDbQuery {
    this.filters.push((r) => String(r[column] ?? "") === value);
    return this;
  }
  neq(column: string, value: string): AnomalyDbQuery {
    this.filters.push((r) => String(r[column] ?? "") !== value);
    return this;
  }
  gte(column: string, value: string): AnomalyDbQuery {
    this.filters.push((r) => String(r[column] ?? "") >= value);
    return this;
  }
  lt(column: string, value: string): AnomalyDbQuery {
    this.filters.push((r) => String(r[column] ?? "") < value);
    return this;
  }
  order(): AnomalyDbQuery {
    return this;
  }
  range(from: number, to: number) {
    const rows = this.db
      .rowsFor(this.table)
      .filter((r) => this.filters.every((f) => f(r)));
    return Promise.resolve({ data: rows.slice(from, to + 1), error: null });
  }
  upsert(
    value: Record<string, unknown>,
    options?: { onConflict?: string },
  ) {
    if (this.db.failUpsertUserIds.has(String(value.user_id ?? ""))) {
      return Promise.resolve({ error: { message: "forced upsert failure" } });
    }
    this.db.upserts.push({
      table: this.table,
      value,
      onConflict: options?.onConflict ?? "",
    });
    return Promise.resolve({ error: null });
  }
}

class FilteringFakeDb implements AnomalyDetectionDb {
  upserts: Array<{
    table: string;
    value: Record<string, unknown>;
    onConflict: string;
  }> = [];
  failUpsertUserIds = new Set<string>();

  constructor(
    private readonly rows: Record<string, Record<string, unknown>[]>,
  ) {}

  from(table: string): AnomalyDbQuery {
    return new FilteringFakeQuery(table, this);
  }

  rowsFor(table: string) {
    return this.rows[table] ?? [];
  }
}

function twoUserRows(): Record<string, unknown>[] {
  return [
    urow("user-a", "2026-03-05", 30000, "food"),
    urow("user-a", "2026-04-05", 30000, "food"),
    urow("user-a", "2026-05-05", 30000, "food"),
    urow("user-a", "2026-06-05", 60000, "food"),
    urow("user-b", "2026-03-05", 30000, "food"),
    urow("user-b", "2026-04-05", 30000, "food"),
    urow("user-b", "2026-05-05", 30000, "food"),
    urow("user-b", "2026-06-05", 30000, "food"),
  ];
}

Deno.test("handleScanAllAction scans distinct users and aggregates", async () => {
  const db = new FilteringFakeDb({ expense_classifications: twoUserRows() });
  const result = await handleScanAllAction({
    db,
    body: { target_month: "2026-06" },
    nowIso: "2026-07-22T03:00:00Z",
  });
  assertEquals(result.status, "ok");
  assertEquals(result.target_month, "2026-06-01");
  assertEquals(result.dry_run, false);
  assertEquals(result.users_scanned, 2);
  assertEquals(result.users_failed, 0);
  assertEquals(result.anomalies_total, 1);
  assertEquals(db.upserts.length, 1);
  assertEquals(db.upserts[0].value.user_id, "user-a");
});

Deno.test("handleScanAllAction dry_run computes but persists nothing", async () => {
  const db = new FilteringFakeDb({ expense_classifications: twoUserRows() });
  const result = await handleScanAllAction({
    db,
    body: { target_month: "2026-06", dry_run: true },
    nowIso: "2026-07-22T03:00:00Z",
  });
  assertEquals(result.dry_run, true);
  assertEquals(result.anomalies_total, 1);
  assertEquals(db.upserts.length, 0);
});

Deno.test("handleScanAllAction isolates per-user failures", async () => {
  const rows = twoUserRows();
  // user-b にも異常を持たせ、user-a の書込だけ失敗させて隔離を検証する。
  rows[7] = urow("user-b", "2026-06-05", 60000, "food");
  const db = new FilteringFakeDb({ expense_classifications: rows });
  db.failUpsertUserIds.add("user-a");
  const result = await handleScanAllAction({
    db,
    body: { target_month: "2026-06" },
    nowIso: "2026-07-22T03:00:00Z",
  });
  assertEquals(result.users_scanned, 1);
  assertEquals(result.users_failed, 1);
  assertEquals(result.failures[0].user_id, "user-a");
  assertEquals(result.anomalies_total, 1);
  assertEquals(db.upserts.length, 1);
  assertEquals(db.upserts[0].value.user_id, "user-b");
});
