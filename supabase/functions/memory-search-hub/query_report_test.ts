import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildQueryRouteDecision, parseQueryReport } from "./query_report.ts";

Deno.test("parseQueryReport reads reformulated XML style tags", () => {
  const report = parseQueryReport(`
    <query_report>
      <status>reformulated</status>
      <reformulated_query>Pleias RAG citation token handling</reformulated_query>
      <reason>Original query was too broad.</reason>
    </query_report>
  `);

  assertEquals(report.state, "reformulated");
  assertEquals(
    report.reformulatedQuery,
    "Pleias RAG citation token handling",
  );
  assertEquals(report.reason, "Original query was too broad.");
});

Deno.test("buildQueryRouteDecision reruns search with reformulated query", () => {
  const route = buildQueryRouteDecision(
    "Pleias",
    [
      "state: reformulated",
      "search_query: Pleias Open Data Layers enterprise RAG",
    ].join("\n"),
  );

  assertEquals(route.action, "search");
  assertEquals(route.state, "reformulated");
  assertEquals(route.searchQuery, "Pleias Open Data Layers enterprise RAG");
});

Deno.test("buildQueryRouteDecision stops unclear queries before search", () => {
  const route = buildQueryRouteDecision(
    "あれを調べて",
    JSON.stringify({
      state: "unclear",
      feedback: "対象が不足しています。",
    }),
  );

  assertEquals(route.action, "clarify");
  assertEquals(route.state, "unclear");
  assertEquals(route.feedback, "対象が不足しています。");
});

Deno.test("buildQueryRouteDecision falls back to original query for trivial reports", () => {
  const route = buildQueryRouteDecision(
    "Pleias citation tokens",
    "<|state|>trivial<|/state|>",
  );

  assertEquals(route.action, "search");
  assertEquals(route.state, "trivial");
  assertEquals(route.searchQuery, "Pleias citation tokens");
});

Deno.test("buildQueryRouteDecision asks for clarification when reformulated query is missing", () => {
  const route = buildQueryRouteDecision(
    "Pleias",
    "status: reformulated",
  );

  assertEquals(route.action, "clarify");
  assertEquals(route.state, "reformulated");
});
