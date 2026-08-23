import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  buildSubscriptionStatementPrompt,
  normalizeSubscriptionStatementCandidates,
  parseSubscriptionStatementResponse,
} from "./subscription_statement_scan.ts";

Deno.test("subscription statement prompt prohibits returning sensitive data", () => {
  const prompt = buildSubscriptionStatementPrompt();
  assert(prompt.includes("Never return card numbers"));
  assert(prompt.includes("Return JSON only"));
});

Deno.test("normalizes candidates, strips long numbers, and rejects bad amounts", () => {
  const result = normalizeSubscriptionStatementCandidates({
    candidates: [
      {
        service_name: "Netflix 4111 1111 1111 1111",
        amount_jpy: 1980,
        charged_at: "2026-08-10",
        billing_cycle: "monthly",
        gateway: "direct",
        confidence: 1.4,
        evidence: "monthly row for account 1234567890123456",
      },
      { service_name: "Broken", amount_jpy: -1 },
    ],
  });

  assertEquals(result.length, 1);
  assertEquals(result[0].service_name, "Netflix [number removed]");
  assertEquals(result[0].confidence, 1);
  assertEquals(result[0].evidence, "monthly row for account [number removed]");
});

Deno.test("deduplicates repeated statement rows and parses fenced JSON", () => {
  const result = parseSubscriptionStatementResponse(`\`\`\`json
  {"candidates":[
    {"service_name":"Notion","amount_jpy":1650,"charged_at":"2026-07-01","billing_cycle":"monthly","confidence":0.7},
    {"service_name":"Notion","amount_jpy":1650,"charged_at":"2026-08-01","billing_cycle":"monthly","confidence":0.9}
  ]}
  \`\`\``);

  assertEquals(result.length, 1);
  assertEquals(result[0].charged_at, "2026-08-01");
  assertEquals(result[0].confidence, 0.9);
});

Deno.test("normalizes cycles, gateways, and impossible dates", () => {
  const result = normalizeSubscriptionStatementCandidates([
    {
      service_name: "iCloud+",
      amount_jpy: "15600",
      charged_at: "2026-02-30",
      billing_cycle: "yearly",
      gateway: "google_play",
      confidence: 0.8,
    },
  ]);

  assertEquals(result[0].billing_cycle, "annual");
  assertEquals(result[0].gateway, "googlePlay");
  assertEquals(result[0].charged_at, null);
});
