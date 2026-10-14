import { assertEquals, assertRejects, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyJevExpense, JEV_CRITERIA, JEV_SEARCH_CRITERIA, JevExpenseError } from "./jev_expense.ts";
import { authorizeAiHubAction } from "./action_access_policy.ts";

function answer() {
  return { type: "choice", choice: "cafe_snack", confidence: 0.95,
    probabilities: Object.fromEntries(Object.keys(JEV_CRITERIA).map((id) => [id, id === "cafe_snack" ? 1 : 0])) };
}
function fixture() {
  let calls = 0;
  let reservations = 0;
  const options = {
    userId: "test-user", anonymous: false, body: { memo: "カフェでコーヒー", consent: true } as Record<string, unknown>,
    apiKey: "synthetic-test-key",
    reserve: (_id: string) => { reservations++; return Promise.resolve(true); },
    fetcher: ((_url, init) => {
      calls++;
      assertEquals(_url, "https://api.typesafe.ai/v1/systemone");
      assertEquals(init?.redirect, "error");
      const payload = JSON.parse(String(init?.body));
      assertEquals(payload.questions.classification.criteria, JEV_CRITERIA);
      assertEquals(payload.state, "カフェでコーヒー");
      assert(init?.signal);
      return Promise.resolve(Response.json({ answers: { classification: answer() } }));
    }) as typeof fetch,
  };
  return { options, calls: () => calls, reservations: () => reservations };
}
Deno.test("Jev action rejects unauthenticated access", () => {
  assertEquals(authorizeAiHubAction("expense.jev_suggest", { userId: null, isServiceRole: false }).allowed, false);
});
Deno.test("fixed schema, one reservation and one provider request", async () => {
  const f = fixture();
  f.options.body.endpoint = "https://attacker.invalid";
  f.options.body.criteria = { attack: "override" };
  const result = await classifyJevExpense(f.options);
  assertEquals(result, { answers: { classification: answer() } });
  assertEquals(f.calls(), 1);
  assertEquals(f.reservations(), 1);
});
for (const [name, patch, status] of [
  ["missing auth", { userId: null }, 401],
  ["anonymous auth", { anonymous: true }, 401],
  ["missing consent", { body: { memo: "coffee" } }, 400],
  ["empty memo", { body: { memo: "  ", consent: true } }, 400],
  ["oversize memo", { body: { memo: "a".repeat(501), consent: true } }, 400],
  ["missing secret", { apiKey: "" }, 503],
] as const) {
  Deno.test(`reject ${name} before reservation or provider`, async () => {
    const f = fixture();
    const error = await assertRejects(() => classifyJevExpense({ ...f.options, ...patch }), JevExpenseError);
    assertEquals(error.status, status);
    assertEquals(f.calls(), 0);
    assertEquals(f.reservations(), 0);
  });
}
Deno.test("quota failure and quota exhaustion never call provider", async () => {
  for (const reserve of [() => Promise.resolve(false), () => Promise.reject(new Error("db"))]) {
    const f = fixture();
    await assertRejects(() => classifyJevExpense({ ...f.options, reserve }), JevExpenseError);
    assertEquals(f.calls(), 0);
  }
});
Deno.test("invalid and unavailable upstream fails without leaking details or retrying", async () => {
  for (const response of [
    Response.json({ secret: "do-not-echo" }, { status: 429 }),
    Response.json({ answers: { classification: { ...answer(), choice: "unknown" } } }),
    Response.json({ answers: { classification: { ...answer(), confidence: 2 } } }),
    Response.json({ answers: { classification: { ...answer(), probabilities: {} } } }),
    new Response("invalid json"),
  ]) {
    const f = fixture(); let calls = 0;
    f.options.fetcher = (() => { calls++; return Promise.resolve(response); }) as typeof fetch;
    const error = await assertRejects(() => classifyJevExpense(f.options), JevExpenseError);
    assertEquals(error.status, 502);
    assert(!error.message.includes("do-not-echo"));
    assertEquals(calls, 1);
  }
});
Deno.test("aborted provider returns a controlled error", async () => {
  const f = fixture();
  f.options.fetcher = (() => Promise.reject(new DOMException("secret", "TimeoutError"))) as typeof fetch;
  const error = await assertRejects(() => classifyJevExpense(f.options), JevExpenseError);
  assertEquals(error.code, "provider_unavailable");
});

Deno.test("semantic search uses the authenticated action and fixed binary schema", async () => {
  assertEquals(authorizeAiHubAction("expense.jev_search", { userId: null, isServiceRole: false }).allowed, false);
  assertEquals(authorizeAiHubAction("expense.jev_search", { userId: "test-user", isServiceRole: false }).allowed, true);
  const f = fixture();
  let calls = 0;
  const binary = { type: "choice", choice: "match", confidence: 0.9, probabilities: { match: 0.9, not_match: 0.1 } };
  const result = await classifyJevExpense({ ...f.options, semanticSearch: true,
    body: { memo: "人工メモと検索条件", consent: true, criteria: { injected: "no" }, endpoint: "https://attacker.invalid" },
    fetcher: ((_url, init) => {
      calls++;
      assertEquals(_url, "https://api.typesafe.ai/v1/systemone");
      assertEquals(init?.redirect, "error");
      const payload = JSON.parse(String(init?.body));
      assertEquals(payload.questions.classification.criteria, JEV_SEARCH_CRITERIA);
      assertEquals(payload.state, "人工メモと検索条件");
      return Promise.resolve(Response.json({ answers: { classification: binary } }));
    }) as typeof fetch,
  });
  assertEquals(result, { answers: { classification: binary } });
  assertEquals(calls, 1);
  assertEquals(f.reservations(), 1);
});
for (const [name, patch] of [
  ["missing authentication", { userId: null }],
  ["anonymous account", { anonymous: true }],
  ["missing consent", { body: { memo: "人工例" } }],
  ["exhausted quota", { reserve: () => Promise.resolve(false) }],
] as const) {
  Deno.test(`semantic search rejects ${name} before provider`, async () => {
    const f = fixture();
    await assertRejects(() => classifyJevExpense({ ...f.options, semanticSearch: true, ...patch }), JevExpenseError);
    assertEquals(f.calls(), 0);
  });
}
Deno.test("semantic search rejects category answers and invalid binary probabilities", async () => {
  for (const value of [answer(), { type: "choice", choice: "match", confidence: 0.9, probabilities: { match: 2, not_match: -1 } }]) {
    const f = fixture();
    const error = await assertRejects(() => classifyJevExpense({ ...f.options, semanticSearch: true,
      fetcher: (() => Promise.resolve(Response.json({ answers: { classification: value } }))) as typeof fetch,
    }), JevExpenseError);
    assertEquals(error.code, "invalid_provider_response");
  }
});
