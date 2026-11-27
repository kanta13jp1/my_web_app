import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildHeuristicQueryReport,
  buildQueryRouteDecision,
  parseQueryReport,
} from "./query_report.ts";

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

Deno.test("buildQueryRouteDecision asks clarify on missing query", () => {
  const route = buildQueryRouteDecision(
    "Pleias",
    "status: reformulated",
  );

  assertEquals(route.action, "clarify");
  assertEquals(route.state, "reformulated");
});

Deno.test("parseQueryReport extracts Pleias sentinel envelope only", () => {
  const raw = [
    "<|thought|>Query might seem unclear at first.<|/thought|>",
    "<|query_report_start|>",
    "<|state|>reformulated",
    "<|reformulated_query|>Pleias Open Data Layers enterprise RAG",
    "<|reason|>Focused broad topic on enterprise RAG architecture",
    "<|query_report_end|>",
    "<|answer_start|>Ignored prose<|answer_end|>",
  ].join("\n");
  const report = parseQueryReport(raw);

  assertEquals(report.state, "reformulated");
  assertEquals(
    report.reformulatedQuery,
    "Pleias Open Data Layers enterprise RAG",
  );
  assertEquals(
    report.reason,
    "Focused broad topic on enterprise RAG architecture",
  );
});

Deno.test("parseQueryReport handles partial unclosed sentinel stream", () => {
  const report = parseQueryReport(
    "<|query_report_start|><|state|>unclear<|reason|>Specify target file",
  );

  assertEquals(report.state, "unclear");
  assertEquals(report.reason, "Specify target file");
});

Deno.test("parseQueryReport maps not clear to unclear state", () => {
  const report = parseQueryReport(
    "<|query_report_start|><|state|>not clear<|query_report_end|>",
  );

  assertEquals(report.state, "unclear");
});

Deno.test("buildHeuristicQueryReport detects vague and clear queries", () => {
  const vague = buildQueryRouteDecision(
    "あれを調べて",
    buildHeuristicQueryReport("あれを調べて"),
  );
  assertEquals(vague.action, "clarify");
  assertEquals(vague.state, "unclear");

  const clear = buildQueryRouteDecision(
    "Pleias Open Data Layers",
    buildHeuristicQueryReport("Pleias Open Data Layers"),
  );
  assertEquals(clear.action, "search");
  assertEquals(clear.state, "trivial");
  assertEquals(clear.searchQuery, "Pleias Open Data Layers");
});
