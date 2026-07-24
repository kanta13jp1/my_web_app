import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assignAgent,
  buildSnapshot,
  computeKpis,
  type GitHubRun,
  mapLane,
  OPS_AGENTS,
  playfulValueYen,
  stableHash,
  throughputSeries,
  toActivity,
  toTask,
} from "./transform.ts";

const HOUR = 3600000;
// 固定 now (2026-07-24T12:00:00Z) — テストを決定的にする。
const NOW = Date.parse("2026-07-24T12:00:00Z");

function run(partial: Partial<GitHubRun>): GitHubRun {
  return { id: 1, ...partial };
}

Deno.test("assignAgent: キーワードで担当キャラを決定", () => {
  assertEquals(assignAgent("Lint, Format, and Test"), "K");
  assertEquals(assignAgent("Security Check"), "B");
  assertEquals(assignAgent("wiki-compile"), "M");
  assertEquals(assignAgent("blog-publish"), "S");
  assertEquals(assignAgent("Deploy to Firebase Hosting"), "H");
});

Deno.test("assignAgent: 非該当は決定的ハッシュで安定配分", () => {
  const first = assignAgent("完全に無関係な名前 zzz");
  const second = assignAgent("完全に無関係な名前 zzz");
  assertEquals(first, second);
  assert(OPS_AGENTS.some((a) => a.id === first));
});

Deno.test("stableHash: 同入力は同値・非負", () => {
  assertEquals(stableHash("abc"), stableHash("abc"));
  assert(stableHash("abc") >= 0);
});

Deno.test("mapLane: run status を 4 列へ写像 (review=queued 読み替え)", () => {
  assertEquals(mapLane("queued", null), "review");
  assertEquals(mapLane("in_progress", null), "progress");
  assertEquals(mapLane("completed", "success"), "done");
  assertEquals(mapLane("waiting", null), "backlog");
  assertEquals(mapLane("unknown-state", null), "backlog");
});

Deno.test("playfulValueYen: 決定的でレンジ内", () => {
  const r = run({ run_number: 42 });
  assertEquals(playfulValueYen(r), playfulValueYen(r));
  const v = playfulValueYen(r);
  assert(v >= 30000 && v <= 150000, `value out of range: ${v}`);
});

Deno.test("toTask: run → カード (dept はキャラ由来)", () => {
  const task = toTask(
    run({
      run_number: 7,
      name: "Security Check",
      status: "in_progress",
    }),
  );
  assertEquals(task.agentId, "B");
  assertEquals(task.dept, "インフラ");
  assertEquals(task.lane, "progress");
  assertEquals(task.code, "OW-7");
});

Deno.test("toActivity: 完了 run は完了文言", () => {
  const act = toActivity(
    run({
      name: "Lint, Format, and Test",
      status: "completed",
      conclusion: "success",
      updated_at: "2026-07-24T11:30:15Z",
    }),
  );
  assert(act.text.includes("KANNA"));
  assert(act.text.includes("を完了"));
  assertEquals(act.time, "11:30:15");
});

Deno.test("toActivity: 失敗 run は失敗検知文言", () => {
  const act = toActivity(
    run({ name: "ci", status: "completed", conclusion: "failure" }),
  );
  assert(act.text.includes("失敗を検知"));
});

Deno.test("computeKpis: 本日完了数・SLA・スループットを集計", () => {
  const runs: GitHubRun[] = [
    // 本日完了・成功・直近1h以内 (30分の実行)
    run({
      status: "completed",
      conclusion: "success",
      run_started_at: "2026-07-24T11:00:00Z",
      updated_at: "2026-07-24T11:30:00Z",
    }),
    // 本日完了・失敗 (直近1h外)
    run({
      status: "completed",
      conclusion: "failure",
      run_started_at: "2026-07-24T02:00:00Z",
      updated_at: "2026-07-24T02:30:00Z",
    }),
    // 進行中 (完了に数えない)
    run({ status: "in_progress" }),
  ];
  const kpis = computeKpis(runs, NOW);
  assertEquals(kpis.completedToday, 2);
  assertEquals(kpis.throughput, 1); // 直近1h以内の完了は1件
  assertEquals(kpis.slaCompliance, 50); // 成功1 / 完了2
  assertEquals(kpis.revenueImpact, 2 * 23000);
  // 自動化時間 = 30分 + 30分 = 1.0h
  assertEquals(kpis.automatedHours, 1);
});

Deno.test("computeKpis: 完了0件なら SLA=100", () => {
  const kpis = computeKpis([run({ status: "in_progress" })], NOW);
  assertEquals(kpis.completedToday, 0);
  assertEquals(kpis.slaCompliance, 100);
});

Deno.test("throughputSeries: 完了 run を時間バケットへ配分", () => {
  const series = throughputSeries(
    [
      run({
        status: "completed",
        conclusion: "success",
        updated_at: new Date(NOW - HOUR).toISOString(),
      }),
      run({
        status: "completed",
        conclusion: "success",
        updated_at: new Date(NOW - HOUR).toISOString(),
      }),
    ],
    NOW,
    24,
  );
  assertEquals(series.length, 24);
  assertEquals(series.reduce((a, b) => a + b, 0), 2);
});

Deno.test("buildSnapshot: 全体を組み立て、列上限を守る", () => {
  const runs: GitHubRun[] = [];
  for (let i = 0; i < 30; i += 1) {
    runs.push(
      run({
        id: i + 1,
        run_number: i + 1,
        name: "wiki-compile",
        status: "completed",
        conclusion: "success",
        updated_at: new Date(NOW - i * 60000).toISOString(),
      }),
    );
  }
  const snap = buildSnapshot(runs, "kanta13jp1/my_web_app", NOW);
  assertEquals(snap.repo, "kanta13jp1/my_web_app");
  assert(snap.live);
  // 完了列は 4 件上限
  assertEquals(snap.tasks.filter((t) => t.lane === "done").length, 4);
  // 活動は 16 件上限
  assertEquals(snap.activities.length, 16);
  assert(snap.kpis.completedToday >= 1);
});

Deno.test("buildSnapshot: run 空でも壊れない (live=false)", () => {
  const snap = buildSnapshot([], "kanta13jp1/my_web_app", NOW);
  assertEquals(snap.live, false);
  assertEquals(snap.tasks.length, 0);
  assertEquals(snap.activities.length, 0);
  assertEquals(snap.kpis.completedToday, 0);
});
