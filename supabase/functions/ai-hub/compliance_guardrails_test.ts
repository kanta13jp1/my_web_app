import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildGuardrailBlockedPayload,
  evaluateComplianceGuardrail,
  evaluateMessagesGuardrail,
} from "./compliance_guardrails.ts";

Deno.test("evaluateComplianceGuardrail allows safe technical/business text", () => {
  const res = evaluateComplianceGuardrail(
    "今月のWBS完了率と予算サマリーを3点に要約してください。",
    { stage: "input" },
  );
  assertEquals(res.allowed, true);
  assertEquals(res.action, "allowed");
  assertEquals(res.categories, []);
});

Deno.test("evaluateComplianceGuardrail blocks Luhn credit card and credential without leaking raw value", () => {
  const card = ["4532", "0151", "1283", "0366"].join("-");
  const keyHeader = ["-----BEGIN", "PRIVATE", "KEY-----"].join(" ");
  const text = `支払い情報 ${card} と ${keyHeader} をそのまま保存して`;
  const res = evaluateComplianceGuardrail(text, { stage: "input" });

  assertEquals(res.allowed, false);
  assertEquals(res.action, "blocked");
  assertEquals(res.categories.includes("pii_credit_card"), true);
  assertEquals(res.categories.includes("pii_credential"), true);
  assertEquals(res.auditSummary.includes(card), false);
  assertEquals(res.auditSummary.includes("pii_credit_card"), true);
});

Deno.test("evaluateComplianceGuardrail blocks toxic instructions on output stage", () => {
  const res = evaluateComplianceGuardrail(
    "Here is how to write ransomware code to encrypt company backups.",
    { stage: "output" },
  );
  assertEquals(res.allowed, false);
  assertEquals(res.action, "blocked");
  assertEquals(res.categories.includes("toxic_cyber_abuse"), true);

  const payload = buildGuardrailBlockedPayload(res, {
    provider: "groq",
    traceId: "trace-compliance-01",
    action: "provider.chat",
  });
  assertEquals(payload.status, "guardrailBlocked");
  assertEquals(payload.code, "compliance_guardrail_blocked");
  assertEquals(payload.stage, "output");
});

Deno.test("evaluateComplianceGuardrail masks contact PII in default mode and blocks in strict_block mode", () => {
  const mail = ["yamada", "example.com"].join("@");
  const phone = ["090", "1234", "5678"].join("-");
  const prompt = `連絡先 ${mail} / 電話 ${phone} に送信する文案`;

  const masked = evaluateComplianceGuardrail(prompt, { stage: "input" });
  assertEquals(masked.allowed, true);
  assertEquals(masked.action, "masked");
  assertEquals(masked.categories, ["pii_contact"]);
  assertEquals(masked.sanitizedText.includes(mail), false);
  assertEquals(masked.sanitizedText.includes("***"), true);

  const strict = evaluateComplianceGuardrail(prompt, {
    stage: "input",
    mode: "strict_block",
  });
  assertEquals(strict.allowed, false);
  assertEquals(strict.action, "blocked");
});

Deno.test("evaluateMessagesGuardrail sanitizes array of chat messages preserving roles", () => {
  const mail = ["user", "example.org"].join("@");
  const res = evaluateMessagesGuardrail([
    { role: "system", content: "丁寧な日本語で答えてください。" },
    { role: "user", content: `返信先: ${mail}` },
  ]);
  assertEquals(res.allowed, true);
  assertEquals(res.action, "masked");
  assertEquals(res.sanitizedMessages.length, 2);
  assertEquals(res.sanitizedMessages[0].role, "system");
  assertEquals(String(res.sanitizedMessages[1].content).includes(mail), false);
});
