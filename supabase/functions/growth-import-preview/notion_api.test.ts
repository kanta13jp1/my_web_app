import {
  fetchNotionBlockTree,
  fetchNotionJsonWithRetry,
  notionBlocksToText,
} from "./notion_api.ts";

function assertEquals<T>(actual: T, expected: T, msg?: string): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(
      `assertEquals failed: expected ${expectedJson}, got ${actualJson}${
        msg ? ` - ${msg}` : ""
      }`,
    );
  }
}

function assertStrictEquals<T>(actual: T, expected: T, msg?: string): void {
  if (actual !== expected) {
    throw new Error(
      `assertStrictEquals failed: expected ${String(expected)}, got ${
        String(actual)
      }${msg ? ` - ${msg}` : ""}`,
    );
  }
}

Deno.test("fetchNotionJsonWithRetry retries after a 429 response", async () => {
  let callCount = 0;
  const sleepCalls: number[] = [];

  const data = await fetchNotionJsonWithRetry<{ ok: boolean }>(
    "https://api.notion.com/v1/search",
    { method: "POST" },
    {
      fetchImpl: () => {
        callCount++;
        if (callCount === 1) {
          return Promise.resolve(new Response("rate limited", {
            status: 429,
            headers: { "Retry-After": "2" },
          }));
        }
        return Promise.resolve(Response.json({ ok: true }));
      },
      sleep: (ms) => {
        sleepCalls.push(ms);
        return Promise.resolve();
      },
      maxRetries: 2,
    },
  );

  assertEquals(data, { ok: true });
  assertStrictEquals(callCount, 2);
  assertEquals(sleepCalls, [2000]);
});

Deno.test("notionBlocksToText renders nested headings, bullets, and todos", () => {
  const text = notionBlocksToText([
    {
      type: "heading_1",
      heading_1: { rich_text: [{ plain_text: "Project Alpha" }] },
    },
    {
      type: "paragraph",
      paragraph: { rich_text: [{ plain_text: "Overview" }] },
      children: [
        {
          type: "bulleted_list_item",
          bulleted_list_item: { rich_text: [{ plain_text: "Task 1" }] },
        },
        {
          type: "to_do",
          to_do: { rich_text: [{ plain_text: "Ship it" }], checked: true },
        },
      ],
    },
  ]);

  assertEquals(
    text,
    "# Project Alpha\nOverview\n  - Task 1\n  - [x] Ship it",
  );
});

Deno.test("fetchNotionBlockTree handles pagination and depth warnings", async () => {
  const urlCalls: string[] = [];

  const fetchImpl: typeof fetch = (input) => {
    const url = input.toString();
    urlCalls.push(url);

    if (url.includes("/blocks/root/children") && !url.includes("start_cursor")) {
      return Promise.resolve(Response.json({
        results: [
          {
            id: "heading",
            type: "heading_2",
            heading_2: { rich_text: [{ plain_text: "Section" }] },
            has_children: false,
          },
        ],
        has_more: true,
        next_cursor: "cursor-2",
      }));
    }

    if (url.includes("/blocks/root/children") && url.includes("cursor-2")) {
      return Promise.resolve(Response.json({
        results: [
          {
            id: "toggle-1",
            type: "toggle",
            toggle: { rich_text: [{ plain_text: "Details" }] },
            has_children: true,
          },
        ],
        has_more: false,
        next_cursor: null,
      }));
    }

    if (url.includes("/blocks/toggle-1/children")) {
      return Promise.resolve(Response.json({
        results: [
          {
            id: "nested-1",
            type: "paragraph",
            paragraph: { rich_text: [{ plain_text: "Nested body" }] },
            has_children: true,
          },
        ],
        has_more: false,
        next_cursor: null,
      }));
    }

    return Promise.reject(new Error(`Unexpected URL: ${url}`));
  };

  const result = await fetchNotionBlockTree("root", {
    headers: { Authorization: "Bearer token" },
    fetchImpl,
    maxDepth: 1,
    maxBlocks: 10,
  });

  assertStrictEquals(result.blocks.length, 2);
  assertStrictEquals(result.blocks[1].children?.length ?? 0, 1);
  assertStrictEquals(result.blocks[1].children?.[0].children?.length ?? 0, 0);
  assertEquals(result.warnings, [
    "Nested Notion blocks deeper than 2 levels were truncated in the preview.",
  ]);
  assertStrictEquals(urlCalls.length, 3);
});

Deno.test("fetchNotionBlockTree strips unused Notion metadata to save memory", async () => {
  const fetchImpl: typeof fetch = () =>
    Promise.resolve(Response.json({
      results: [
        {
          id: "b1",
          type: "paragraph",
          object: "block",
          created_time: "2026-01-01T00:00:00.000Z",
          last_edited_time: "2026-01-02T00:00:00.000Z",
          created_by: { object: "user", id: "u1" },
          last_edited_by: { object: "user", id: "u2" },
          parent: { type: "page_id", page_id: "p1" },
          archived: false,
          has_children: false,
          paragraph: {
            color: "default",
            rich_text: [
              {
                plain_text: "hi",
                type: "text",
                annotations: {
                  bold: true,
                  italic: false,
                  color: "red",
                },
                href: "https://example.com",
                text: { content: "hi", link: { url: "https://example.com" } },
              },
            ],
          },
        },
      ],
      has_more: false,
      next_cursor: null,
    }));

  const result = await fetchNotionBlockTree("root", {
    headers: { Authorization: "Bearer token" },
    fetchImpl,
  });

  assertStrictEquals(result.blocks.length, 1);
  const block = result.blocks[0];
  assertEquals(Object.keys(block).sort(), ["id", "paragraph", "type"]);
  const paragraph = block.paragraph as { rich_text: { plain_text: string }[] };
  assertEquals(paragraph.rich_text, [{ plain_text: "hi" }]);
  assertStrictEquals((block as Record<string, unknown>).created_time, undefined);
  assertStrictEquals((block as Record<string, unknown>).parent, undefined);
});
