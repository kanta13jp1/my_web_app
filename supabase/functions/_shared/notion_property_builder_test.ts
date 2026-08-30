import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildNotionProperties,
  buildSingleNotionProperty,
  detectTitleCollision,
  extractNotionErrorDetail,
  NOTION_RICH_TEXT_LIMIT,
  NotionPropertyBuildError,
  wrapNotionPropertyValue,
} from "./notion_property_builder.ts";

Deno.test("wraps each property type into the Notion API shape", () => {
  assertEquals(
    wrapNotionPropertyValue({ name: "Name", type: "title" }, "Hello"),
    { title: [{ text: { content: "Hello" } }] },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Memo", type: "rich_text" }, "note"),
    { rich_text: [{ text: { content: "note" } }] },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Amount", type: "number" }, 123),
    { number: 123 },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Stage", type: "select" }, "done"),
    { select: { name: "done" } },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Tags", type: "multi_select" }, ["a", "b"]),
    { multi_select: [{ name: "a" }, { name: "b" }] },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Done", type: "checkbox" }, true),
    { checkbox: true },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Link", type: "url" }, "https://x.dev"),
    { url: "https://x.dev" },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Owner", type: "people" }, ["u1", "u2"]),
    { people: [{ id: "u1" }, { id: "u2" }] },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Parent", type: "relation" }, "rel1"),
    { relation: [{ id: "rel1" }] },
  );
});

Deno.test("number accepts numeric strings and rejects non-numbers", () => {
  assertEquals(
    wrapNotionPropertyValue({ name: "Amount", type: "number" }, "42"),
    { number: 42 },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Amount", type: "number" }, null),
    { number: null },
  );
  assertThrows(
    () => wrapNotionPropertyValue({ name: "Amount", type: "number" }, "n/a"),
    NotionPropertyBuildError,
  );
});

Deno.test("date accepts an ISO string or a { start, end } object", () => {
  assertEquals(
    wrapNotionPropertyValue({ name: "Due", type: "date" }, "2026-07-16"),
    { date: { start: "2026-07-16" } },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Span", type: "date" }, {
      start: "2026-07-16",
      end: "2026-07-20",
    }),
    { date: { start: "2026-07-16", end: "2026-07-20" } },
  );
  assertThrows(
    () => wrapNotionPropertyValue({ name: "Span", type: "date" }, { end: "x" }),
    NotionPropertyBuildError,
  );
});

Deno.test("select and multi_select clear correctly on null / empty", () => {
  assertEquals(
    wrapNotionPropertyValue({ name: "Stage", type: "select" }, null),
    { select: null },
  );
  assertEquals(
    wrapNotionPropertyValue({ name: "Tags", type: "multi_select" }, null),
    { multi_select: [] },
  );
});

Deno.test("rich_text splits content over the 2000 char limit", () => {
  const long = "x".repeat(NOTION_RICH_TEXT_LIMIT + 500);
  const wrapped = wrapNotionPropertyValue(
    { name: "Memo", type: "rich_text" },
    long,
  ) as { rich_text: Array<{ text: { content: string } }> };
  assertEquals(wrapped.rich_text.length, 2);
  assertEquals(wrapped.rich_text[0].text.content.length, NOTION_RICH_TEXT_LIMIT);
  assertEquals(wrapped.rich_text[1].text.content.length, 500);
});

Deno.test("detects a non-title property named 'title'", () => {
  assertEquals(
    detectTitleCollision({ name: "title", type: "rich_text" }) !== null,
    true,
  );
  assertEquals(
    detectTitleCollision({ name: "Title", type: "number" }) !== null,
    true,
  );
  // A real title property named "title" is fine.
  assertEquals(detectTitleCollision({ name: "title", type: "title" }), null);
  assertEquals(detectTitleCollision({ name: "Memo", type: "rich_text" }), null);
});

Deno.test("buildNotionProperties warns on title collision by default", () => {
  const result = buildNotionProperties(
    [
      { name: "title", type: "rich_text" },
      { name: "Amount", type: "number" },
    ],
    { title: "hello", Amount: 10 },
  );
  assertEquals(result.warnings.length, 1);
  assertEquals(result.properties.Amount, { number: 10 });
});

Deno.test("buildNotionProperties throws on title collision in strict mode", () => {
  assertThrows(
    () =>
      buildNotionProperties(
        [{ name: "title", type: "select" }],
        { title: "x" },
        { strictTitleCollision: true },
      ),
    NotionPropertyBuildError,
  );
});

Deno.test("buildNotionProperties skips missing and undefined values", () => {
  const result = buildNotionProperties(
    [
      { name: "Name", type: "title" },
      { name: "Memo", type: "rich_text" },
      { name: "Amount", type: "number" },
    ],
    { Name: "Task", Amount: undefined },
  );
  // Memo has no key, Amount is undefined -> both skipped.
  assertEquals(Object.keys(result.properties), ["Name"]);
  assertEquals(result.properties.Name, { title: [{ text: { content: "Task" } }] });
});

Deno.test("buildNotionProperties rejects duplicate and empty names", () => {
  assertThrows(
    () =>
      buildNotionProperties(
        [
          { name: "Amount", type: "number" },
          { name: "Amount", type: "number" },
        ],
        {},
      ),
    NotionPropertyBuildError,
  );
  assertThrows(
    () => buildNotionProperties([{ name: "  ", type: "number" }], {}),
    NotionPropertyBuildError,
  );
});

Deno.test("buildSingleNotionProperty keys the wrapped value by name", () => {
  assertEquals(
    buildSingleNotionProperty({ name: "Amount", type: "number" }, 5),
    { Amount: { number: 5 } },
  );
});

Deno.test("extractNotionErrorDetail parses a structured error body", () => {
  const body = JSON.stringify({
    object: "error",
    status: 400,
    code: "validation_error",
    message: "Amount is expected to be number.",
    request_id: "req-123",
  });
  const detail = extractNotionErrorDetail(400, body);
  assertEquals(detail.code, "validation_error");
  assertEquals(detail.message, "Amount is expected to be number.");
  assertEquals(detail.requestId, "req-123");
  assertEquals(
    detail.detail,
    "Notion API error HTTP 400 [validation_error]: Amount is expected to be number. (request_id=req-123)",
  );
});

Deno.test("extractNotionErrorDetail degrades gracefully on non-JSON body", () => {
  const detail = extractNotionErrorDetail(502, "<html>bad gateway</html>");
  assertEquals(detail.code, "unknown");
  assertEquals(detail.status, 502);
  assertEquals(detail.detail.includes("bad gateway"), true);
});
