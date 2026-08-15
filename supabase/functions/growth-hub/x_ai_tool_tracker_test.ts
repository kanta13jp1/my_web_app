import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildAiToolTrackerPost,
  parseAiToolWatchSources,
} from "./x_ai_tool_tracker.ts";
import { classifyPostArchetype } from "./x_post_archetype.ts";
import { contentSimilarity } from "./x_duplicate_content.ts";

const URL =
  "https://my-web-app-b67f4.web.app/?utm_source=x&utm_content=ai_tool_tracker";

// docs/ai-tool-watch/latest-report.json の実形を写したフィクスチャ。
function report(overrides: Record<string, unknown> = {}): unknown {
  return {
    checked_at: "2026-07-12T22:08:46Z",
    previous_checked_at: "2026-07-11T22:09:19Z",
    active_groups: ["codex-runtime", "hooks", "integration"],
    high_priority_groups: ["codex-runtime", "hooks"],
    sources: [
      {
        name: "Claude Code changelog",
        url: "https://code.claude.com/docs/en/changelog",
        changed: false,
        first_seen: false,
        error: null,
        keyword_groups: {},
      },
      {
        name: "Codex changelog",
        url: "https://developers.openai.com/codex/changelog",
        changed: true,
        first_seen: false,
        error: null,
        latest_signal:
          "2026-07-09 / Codex joins the ChatGPT desktop app on macOS",
        keyword_groups: {
          "codex-runtime": ["GPT-5.5", "model picker", "worktree"],
          "hooks": ["hook"],
        },
      },
      {
        name: "Gemini Code Assist release notes",
        url:
          "https://developers.google.com/gemini-code-assist/resources/release-notes",
        changed: true,
        first_seen: false,
        error: null,
        keyword_groups: {
          "integration": ["MCP", "IDE extension"],
        },
      },
    ],
    ...overrides,
  };
}

Deno.test("buildAiToolTrackerPost skips no-change days and thin data", () => {
  // 変化 0 件の日は候補を作らない(playbook step 3)。
  const unchanged = report({
    sources: (report() as Record<string, unknown>).sources as unknown[],
  }) as Record<string, unknown>;
  const allUnchanged = (unchanged.sources as Record<string, unknown>[]).map(
    (source) => ({ ...source, changed: false }),
  );
  assertEquals(
    buildAiToolTrackerPost(report({ sources: allUnchanged }), URL),
    null,
  );
  // ソース数が MIN 未満(データ欠損日)も見送り。
  assertEquals(
    buildAiToolTrackerPost(report({ sources: [] }), URL),
    null,
  );
  // checked_at 不正も見送り(日付キーが作れない)。
  assertEquals(
    buildAiToolTrackerPost(report({ checked_at: "not-a-date" }), URL),
    null,
  );
});

Deno.test("buildAiToolTrackerPost composes a post-A style lead from the report", () => {
  const post = buildAiToolTrackerPost(report(), URL);
  assert(post !== null);
  // JST 日付ラベル(UTC 22:08 = JST 翌 07:08)。
  assert(post!.text.includes("AIコーディングツール定点観測 2026/7/13"));
  assert(post!.text.includes("取得日時: 2026-07-12T22:08:46Z"));
  assert(post!.text.includes("監視ソース: 3件"));
  assert(post!.text.includes("24hで更新検知: 2件"));
  assert(post!.text.includes("アクティブ話題群: 3群"));
  assert(post!.text.includes("高優先シグナル: codex-runtime、hooks"));
  // 更新検知ソースは名前+実キーワード(固有名詞)で列挙される。
  assert(post!.text.includes("・Codex changelog: GPT-5.5 / model picker"));
  assert(post!.text.includes("・Gemini Code Assist release notes: MCP"));
  assertEquals(post!.changedCount, 2);
  assertEquals(post!.sourceCount, 3);
  // 冪等キーは JST 日付。
  assertEquals(post!.candidateKey, "ai-tool-tracker:2026-07-13");
  // 出典 URL は更新検知ソースのもの。
  assertEquals(post!.sourceUrls.length, 2);
});

Deno.test("buildAiToolTrackerPost replies carry roster, alerts, and final URL", () => {
  const post = buildAiToolTrackerPost(report(), URL);
  assert(post !== null);
  const [roster, alerts, cta] = post!.replyTexts;
  // 名簿相当: 全監視対象を更新マーク付きで列挙。
  assert(roster.includes("監視対象の全ソース"));
  assert(roster.includes("🔄 Codex changelog(24hで更新)"));
  assert(roster.includes("・Claude Code changelog"));
  // アラート: エラー無し時は正常巡回の明示。
  assert(alerts.includes("取得エラーなし。全3ソース正常巡回。"));
  // URL は最終リプライのみ(link-in-reply の実測勝ち構造)。
  assert(cta.includes(URL));
  assert(!post!.text.includes(URL));
  assert(!roster.includes(URL));
});

Deno.test("buildAiToolTrackerPost surfaces per-source fetch errors as alerts", () => {
  const base = report() as Record<string, unknown>;
  const sources = (base.sources as Record<string, unknown>[]).map((source) =>
    source.name === "Claude Code changelog"
      ? { ...source, error: "HTTP 503" }
      : source
  );
  const post = buildAiToolTrackerPost(report({ sources }), URL);
  assert(post !== null);
  const alerts = post!.replyTexts.find((entry) => entry.includes("アラート"))!;
  assert(alerts.includes("🟡 Claude Code changelog: 取得エラー"));
});

Deno.test("buildAiToolTrackerPost output self-classifies as data_report", () => {
  // R23 自己整合(playbook step 2): この系列自身が data_report バケットへ
  // 入り、Archetype lift の実測を蓄積できる形であることを固定する。
  const post = buildAiToolTrackerPost(report(), URL);
  assert(post !== null);
  const full = [post!.text, ...post!.replyTexts].join("\n");
  assertEquals(classifyPostArchetype(full), "data_report");
});

Deno.test("buildAiToolTrackerPost excludes fetch-error sources from 更新検知 (F1)", () => {
  // 生成側は fetch 失敗(403/timeout)でもエラーページ本文の hash 変化で
  // changed=true を立てる。「実測値」を掲げる系列で偽の検知件数を出さない。
  const base = report() as Record<string, unknown>;
  const sources = (base.sources as Record<string, unknown>[]).map((source) =>
    source.name === "Codex changelog"
      ? { ...source, error: "HTTP 403" }
      : source
  );
  const post = buildAiToolTrackerPost(report({ sources }), URL);
  assert(post !== null);
  // エラー行は検知件数・リード列挙・🔄マークから外れ、アラートには出る。
  assert(post!.text.includes("24hで更新検知: 1件"));
  assert(!post!.text.includes("・Codex changelog"));
  assertEquals(post!.changedCount, 1);
  const roster = post!.replyTexts[0];
  assert(!roster.includes("🔄 Codex changelog"));
  assert(roster.includes("・Codex changelog"));
  const alerts = post!.replyTexts.find((entry) => entry.includes("アラート"))!;
  assert(alerts.includes("🟡 Codex changelog: 取得エラー"));
  // エラー行しか changed が無い日は候補を作らない。
  const onlyErrored = (base.sources as Record<string, unknown>[]).map(
    (source) =>
      source.name === "Codex changelog"
        ? { ...source, error: "HTTP 403" }
        : { ...source, changed: false },
  );
  assertEquals(
    buildAiToolTrackerPost(report({ sources: onlyErrored }), URL),
    null,
  );
});

Deno.test("consecutive-day leads with fresh signals stay under the dup threshold (F2)", () => {
  // リリース週に同一ソース集合が連日更新されるケース: 検知シグナル(実本文
  // 由来の日替わりデータ)がリードの類似度を近似重複ガード閾値(0.9)未満に
  // 下げることを実測で固定する(シグナル無し時代は 0.99 で拒否されていた)。
  const day1 = buildAiToolTrackerPost(report(), URL);
  const day2Sources = (report() as Record<string, unknown>)
    .sources as Record<string, unknown>[];
  const day2 = buildAiToolTrackerPost(
    report({
      checked_at: "2026-07-13T22:08:46Z",
      sources: day2Sources.map((source) =>
        source.name === "Codex changelog"
          ? {
            ...source,
            latest_signal:
              "2026-07-13 / Codex adds parallel worktree execution for large refactors",
          }
          : source.name === "Gemini Code Assist release notes"
          ? {
            ...source,
            latest_signal: "VS Code Gemini Code Assist 2.88.0 / July 13, 2026",
          }
          : source
      ),
    }),
    URL,
  );
  assert(day1 !== null && day2 !== null);
  // シグナルがリードに載っている(情報価値+日替わり可変トークン)。
  assert(day1!.text.includes("Codex joins the ChatGPT desktop app"));
  assert(day2!.text.includes("parallel worktree execution"));
  const similarity = contentSimilarity(day1!.text, day2!.text);
  assert(
    similarity < 0.9,
    `expected < 0.9 (dup guard threshold), got ${similarity}`,
  );
});

Deno.test("parseAiToolWatchSources tolerates junk shapes", () => {
  assertEquals(parseAiToolWatchSources(null), []);
  assertEquals(parseAiToolWatchSources("junk"), []);
  const parsed = parseAiToolWatchSources([
    { name: "A", keyword_groups: { g: ["k1", "k1", ""] }, changed: 1 },
    { keyword_groups: null },
    "junk",
  ]);
  assertEquals(parsed.length, 1);
  assertEquals(parsed[0].keywords, ["k1"]);
  assertEquals(parsed[0].changed, false);
});
