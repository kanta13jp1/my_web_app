import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildValidationLogEntry,
  validateAiOutput,
} from "./output_validation.ts";

Deno.test("validateAiOutput passes structured markdown output with zero drift", () => {
  const result = validateAiOutput(
    "## 結論\n今月の予算達成率は92%です。\n\n## 根拠\n実績データの集計結果に基づく数値です。",
    { formatContract: "markdown_sections" },
  );

  assertEquals(result.decision, "passed");
  assertEquals(result.allowed, true);
  assertEquals(result.violationCount, 0);
  assertEquals(result.driftScore, 0);
});

Deno.test("validateAiOutput strips JSON fences cleanly and blocks missing required fields", () => {
  const fencedJson = '```json\n{"summary": "OK", "confidence": 0.9}\n```';
  const remediated = validateAiOutput(fencedJson, {
    formatContract: "json_object",
    requiredFields: ["summary", "confidence"],
  });

  assertEquals(remediated.decision, "remediated");
  assertEquals(remediated.allowed, true);
  assertEquals(remediated.remediatedOutput, '{"summary":"OK","confidence":0.9}');
  assertEquals(remediated.violations[0].code, "json_code_fence_stripped");

  const missingField = validateAiOutput('{"summary": "OK"}', {
    formatContract: "json_object",
    requiredFields: ["summary", "confidence"],
  });
  assertEquals(missingField.decision, "blocked");
  assertEquals(missingField.allowed, false);
  assertEquals(missingField.remediatedOutput, "");
  assertEquals(missingField.violations[0].code, "missing_required_field_confidence");
});

Deno.test("validateAiOutput remediates banned tokens and blocks emergent absolute guarantees", () => {
  const placeholderRes = validateAiOutput(
    "## 結論\n確認済み TODO_PLACEHOLDER です。\n\n## 根拠\n検証ログを参照してください。",
    { formatContract: "markdown_sections" },
  );
  assertEquals(placeholderRes.decision, "remediated");
  assertEquals(placeholderRes.allowed, true);
  assertEquals(placeholderRes.remediatedOutput.includes("TODO_PLACEHOLDER"), false);
  assertEquals(placeholderRes.remediatedOutput.includes("[REMOVED]"), true);

  const guaranteeRes = validateAiOutput(
    "## 結論\nこの投資手法は確実に儲かるため安全です。\n\n## 根拠\n過去の一例のみ。",
    { formatContract: "markdown_sections" },
  );
  assertEquals(guaranteeRes.decision, "blocked");
  assertEquals(guaranteeRes.allowed, false);
  assertEquals(
    guaranteeRes.violations.some((v) => v.code === "ungrounded_absolute_guarantee"),
    true,
  );
});

Deno.test("validateAiOutput delegates PII checks and buildValidationLogEntry masks excerpts", () => {
  const mail = ["user", "example.com"].join("@");
  const prompt = `連絡先 ${mail} 宛てのサマリーを作成して`;
  const raw = `## 結論\n送信先 ${mail} を更新します。\n\n## 根拠\n承認済みです。`;

  const result = validateAiOutput(raw, { formatContract: "markdown_sections" });
  assertEquals(result.decision, "remediated");
  assertEquals(result.allowed, true);
  assertEquals(result.remediatedOutput.includes(mail), false);

  const entry = buildValidationLogEntry(prompt, raw, result);
  assertEquals(entry.prompt_excerpt.includes(mail), false);
  assertEquals(entry.original_output_excerpt.includes(mail), false);
  assertEquals(entry.remediated_output_excerpt.includes("***"), true);
  assertEquals(entry.violation_count, result.violationCount);
});

Deno.test("validateAiOutput truncates oversized concise_summary deterministically", () => {
  const longText = "あ".repeat(120);
  const result = validateAiOutput(longText, {
    formatContract: "concise_summary",
    maxLength: 50,
  });

  assertEquals(result.decision, "remediated");
  assertEquals(result.allowed, true);
  assertEquals(result.remediatedOutput.length <= 50, true);
  assertEquals(result.remediatedOutput.endsWith("..."), true);
});
