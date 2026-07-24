// autonomous-ops / transform.ts
//
// GitHub Actions の workflow run 一覧を OMOCHA WORKS「自律オペレーション
// コンソール」の表示ペイロードへ変換する純粋ロジック。
//
// ここはネットワーク・時刻・乱数に依存しない (now は引数で受け取る) ため
// Deno 単体テストで決定的に検証できる。壊れやすい変換の温床を確実に押さえる。

/// 5 体の固定キャラ (ページの人格 = ツイートの世界観の核)。
/// 実データはこのキャラを「通して」流す。置き換えない。
export type AgentId = "H" | "K" | "M" | "B" | "S";

export interface OpsAgentMeta {
  id: AgentId;
  name: string;
  role: string;
  dept: string;
}

export const OPS_AGENTS: readonly OpsAgentMeta[] = [
  { id: "H", name: "HAYATE", role: "開発・自動化", dept: "開発" },
  { id: "K", name: "KANNA", role: "品質・レビュー", dept: "品質" },
  { id: "M", name: "MIYA", role: "データ分析", dept: "分析" },
  { id: "B", name: "BOLT", role: "インフラ監視", dept: "インフラ" },
  { id: "S", name: "SHIORI", role: "業務・文書", dept: "業務" },
] as const;

const AGENT_BY_ID: Record<AgentId, OpsAgentMeta> = Object.fromEntries(
  OPS_AGENTS.map((a) => [a.id, a]),
) as Record<AgentId, OpsAgentMeta>;

// キーワード → キャラ割り当てルール (先頭から順に評価し最初の一致を採用)。
const AGENT_KEYWORDS: ReadonlyArray<readonly [AgentId, readonly string[]]> = [
  ["K", ["lint", "format", "test", "review", "analyze", "codeql", "quality", "e2e", "coverage"]],
  ["B", ["security", "audit", "scan", "health", "monitor", "cron", "schedule", "infra", "deploy-prod", "residual"]],
  ["M", ["wiki", "report", "metric", "analytic", "digest", "compile", "ingest", "research", "crosscheck", "dashboard"]],
  ["S", ["blog", "qiita", "dev.to", "devto", "docs", "note", "publish", "social", "competitor", "x-"]],
  ["H", ["deploy", "build", "release", "ci", "firebase", "hosting", "pipeline", "auto"]],
];

/// ワークフロー名 / パスから担当キャラを決定的に割り当てる。
/// キーワード非該当時は名前ハッシュで 5 体へ安定配分 (実行毎にブレない)。
export function assignAgent(workflowName: string, path = ""): AgentId {
  const hay = `${workflowName} ${path}`.toLowerCase();
  for (const [agentId, keywords] of AGENT_KEYWORDS) {
    if (keywords.some((kw) => hay.includes(kw))) {
      return agentId;
    }
  }
  return OPS_AGENTS[stableHash(workflowName) % OPS_AGENTS.length].id;
}

/// 文字列 → 非負 32bit ハッシュ (FNV-1a 変種 / 決定的)。
export function stableHash(input: string): number {
  let h = 2166136261;
  for (let i = 0; i < input.length; i += 1) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export type Lane = "backlog" | "progress" | "review" | "done";

/// GitHub run の status/conclusion を 4 列カンバンへ写像する。
///
/// run には「レビュー」状態が無いため、grill-me の決定に従い
/// **レビュー列は queued (実行キュー待ち) を読み替えて表示**する。
///   - requested/waiting/pending → backlog (着手前)
///   - queued                    → review  (キュー待ち = レビュー列に読み替え)
///   - in_progress               → progress
///   - completed                 → done
export function mapLane(status: string, _conclusion: string | null): Lane {
  switch (status) {
    case "queued":
      return "review";
    case "in_progress":
    case "pending":
      return "progress";
    case "requested":
    case "waiting":
      return "backlog";
    case "completed":
      return "done";
    default:
      return "backlog";
  }
}

// ─────────────────────────────────────────────────────────────
// 入出力の型
// ─────────────────────────────────────────────────────────────

/// GitHub REST: list workflow runs のうち本変換が使うフィールドのみ。
export interface GitHubRun {
  id: number;
  name?: string | null;
  display_title?: string | null;
  path?: string | null;
  run_number?: number | null;
  status?: string | null;
  conclusion?: string | null;
  run_started_at?: string | null;
  updated_at?: string | null;
  created_at?: string | null;
}

export interface OpsTask {
  code: string;
  dept: string;
  title: string;
  valueYen: number;
  lane: Lane;
  agentId: AgentId | null;
}

export interface OpsActivity {
  text: string;
  time: string; // HH:MM:SS (UTC)
  agentId: AgentId | null;
}

export interface OpsKpis {
  completedToday: number;
  automatedHours: number;
  revenueImpact: number;
  slaCompliance: number;
  throughput: number;
}

export interface OpsSnapshot {
  generatedAt: string;
  repo: string;
  live: boolean; // 実データ由来か (false=データ無し)
  tasks: OpsTask[];
  activities: OpsActivity[];
  kpis: OpsKpis;
  throughputHistory: number[];
}

// ─────────────────────────────────────────────────────────────
// 変換ヘルパー
// ─────────────────────────────────────────────────────────────

function parseTime(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : null;
}

function fmtClockUtc(ms: number): string {
  const d = new Date(ms);
  const h = String(d.getUTCHours()).padStart(2, "0");
  const m = String(d.getUTCMinutes()).padStart(2, "0");
  const s = String(d.getUTCSeconds()).padStart(2, "0");
  return `${h}:${m}:${s}`;
}

/// run から演出用の「売上インパクト」的な金額を決定的に導出する。
/// GitHub に相当データは無いため run_number / id を種にした遊びの値
/// (¥30,000〜¥150,000 レンジ)。実売上ではない旨は docs に明記。
export function playfulValueYen(run: GitHubRun): number {
  const seed = stableHash(String(run.run_number ?? run.id ?? 0));
  return 30000 + (seed % 121) * 1000;
}

function runTitle(run: GitHubRun): string {
  return (
    (run.display_title && run.display_title.trim()) ||
    (run.name && run.name.trim()) ||
    `run #${run.run_number ?? run.id}`
  );
}

function runCode(run: GitHubRun): string {
  const n = run.run_number ?? (run.id % 10000);
  return `OW-${n}`;
}

/// 単一 run → タスクカード。
export function toTask(run: GitHubRun): OpsTask {
  const agentId = assignAgent(run.name ?? "", run.path ?? "");
  return {
    code: runCode(run),
    dept: AGENT_BY_ID[agentId].dept,
    title: runTitle(run),
    valueYen: playfulValueYen(run),
    lane: mapLane(run.status ?? "", run.conclusion ?? null),
    agentId,
  };
}

function conclusionVerb(run: GitHubRun): string {
  if ((run.status ?? "") !== "completed") {
    return run.status === "in_progress" ? "を実行中" : "をキュー待ち";
  }
  switch (run.conclusion) {
    case "success":
      return "を完了";
    case "failure":
    case "timed_out":
      return "で失敗を検知";
    case "cancelled":
      return "を中断";
    default:
      return "を処理";
  }
}

/// run → 活動ログ 1 行。
export function toActivity(run: GitHubRun): OpsActivity {
  const agentId = assignAgent(run.name ?? "", run.path ?? "");
  const ms = parseTime(run.updated_at) ?? parseTime(run.created_at) ?? 0;
  return {
    text: `${AGENT_BY_ID[agentId].name} が「${runTitle(run)}」${conclusionVerb(run)}`,
    time: fmtClockUtc(ms),
    agentId,
  };
}

const DAY_MS = 86400000;
const HOUR_MS = 3600000;

/// run 群 → KPI。now は UTC epoch(ms)。
export function computeKpis(runs: GitHubRun[], now: number): OpsKpis {
  const dayStart = Math.floor(now / DAY_MS) * DAY_MS;
  let completedToday = 0;
  let automatedMs = 0;
  let completedTotal = 0;
  let successTotal = 0;
  let lastHourCompleted = 0;

  for (const run of runs) {
    if ((run.status ?? "") !== "completed") continue;
    completedTotal += 1;
    if (run.conclusion === "success") successTotal += 1;
    const end = parseTime(run.updated_at);
    const begin = parseTime(run.run_started_at) ?? parseTime(run.created_at);
    if (end !== null && end >= dayStart) {
      completedToday += 1;
      if (begin !== null && end >= begin) {
        automatedMs += end - begin;
      }
    }
    if (end !== null && now - end <= HOUR_MS) {
      lastHourCompleted += 1;
    }
  }

  const slaCompliance = completedTotal === 0
    ? 100
    : Math.round((successTotal / completedTotal) * 1000) / 10;

  return {
    completedToday,
    automatedHours: Math.round((automatedMs / HOUR_MS) * 10) / 10,
    // 演出値: 完了数 × 固定単価 (実売上ではない)。
    revenueImpact: completedToday * 23000,
    slaCompliance,
    throughput: lastHourCompleted,
  };
}

/// 直近 buckets 時間ぶんの「1 時間あたり完了 run 数」系列。
export function throughputSeries(
  runs: GitHubRun[],
  now: number,
  buckets = 24,
): number[] {
  const series = new Array<number>(buckets).fill(0);
  const windowStart = now - buckets * HOUR_MS;
  for (const run of runs) {
    if ((run.status ?? "") !== "completed") continue;
    const end = parseTime(run.updated_at);
    if (end === null || end < windowStart || end > now) continue;
    const idx = Math.min(
      buckets - 1,
      Math.floor((end - windowStart) / HOUR_MS),
    );
    series[idx] += 1;
  }
  return series;
}

/// run 一覧 → 表示スナップショット全体。
export function buildSnapshot(
  runs: GitHubRun[],
  repo: string,
  now: number,
): OpsSnapshot {
  // updated_at 降順で安定ソート (新しい活動が上)。
  const sorted = [...runs].sort((a, b) => {
    const ta = parseTime(a.updated_at) ?? 0;
    const tb = parseTime(b.updated_at) ?? 0;
    return tb - ta;
  });

  const tasksByLane: Record<Lane, OpsTask[]> = {
    backlog: [],
    progress: [],
    review: [],
    done: [],
  };
  for (const run of sorted) {
    const task = toTask(run);
    tasksByLane[task.lane].push(task);
  }
  // 各列は上限を設けて UI 破綻を防ぐ (完了列は直近のみ)。
  const tasks: OpsTask[] = [
    ...tasksByLane.backlog.slice(0, 3),
    ...tasksByLane.progress.slice(0, 6),
    ...tasksByLane.review.slice(0, 4),
    ...tasksByLane.done.slice(0, 4),
  ];

  const activities = sorted.slice(0, 16).map(toActivity);

  return {
    generatedAt: new Date(now).toISOString(),
    repo,
    live: runs.length > 0,
    tasks,
    activities,
    kpis: computeKpis(sorted, now),
    throughputHistory: throughputSeries(sorted, now),
  };
}
