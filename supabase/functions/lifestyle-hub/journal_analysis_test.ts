import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildJournalInsight,
  coerceJournalInsight,
  extractFirstJsonObject,
} from "./journal_analysis.ts";

Deno.test("buildJournalInsight detects spending and stress triggers", () => {
  const insight = buildJournalInsight({
    note: "セールで余計な購入をしそうになり、仕事の締切でストレスも強かった。",
    moodScore: 2,
    stressScore: 5,
    sleepHours: 5,
  });

  assertEquals(insight.focus_area, "spending");
  assertEquals(insight.risk_level, "high");
  assertEquals(insight.trigger_tags.includes("支出トリガー"), true);
  assertEquals(insight.trigger_tags.includes("高ストレス"), true);
  assertEquals(insight.next_actions.length > 0, true);
});

Deno.test("extractFirstJsonObject parses JSON wrapped in prose", () => {
  const parsed = extractFirstJsonObject(
    '結果です: {"summary":"ok","next_actions":["a"]} 以上',
  );

  assertEquals(parsed?.summary, "ok");
});

Deno.test("coerceJournalInsight keeps fallback when AI JSON is partial", () => {
  const fallback = buildJournalInsight({
    note: "よく眠れて安定していた。",
    moodScore: 4,
    stressScore: 1,
    sleepHours: 8,
  });
  const insight = coerceJournalInsight({ summary: "短い要約" }, fallback);

  assertEquals(insight.summary, "短い要約");
  assertEquals(insight.next_actions, fallback.next_actions);
  assertEquals(insight.risk_level, fallback.risk_level);
});
