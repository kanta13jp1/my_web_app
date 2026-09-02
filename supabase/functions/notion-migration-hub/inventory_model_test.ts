import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  countNotionKinds,
  NOTION_MIGRATION_API_VERSION,
  notionAttachmentRows,
  notionDurablePayload,
  notionInventoryRow,
  notionObjectTitle,
  notionParentSourceId,
} from "./inventory_model.ts";

Deno.test("uses the current Notion API and extracts page titles", () => {
  assertEquals(NOTION_MIGRATION_API_VERSION, "2026-03-11");
  const page = {
    object: "page",
    id: "page-1",
    parent: { type: "page_id", page_id: "parent-1" },
    properties: {
      Name: {
        type: "title",
        title: [{ plain_text: "Migration page" }],
      },
    },
  };

  assertEquals(notionObjectTitle(page), "Migration page");
  assertEquals(notionParentSourceId(page), "page:parent-1");
  const row = notionInventoryRow({
    batchId: "batch-1",
    userId: "user-1",
    object: page,
    seenAt: "2026-08-23T00:00:00.000Z",
  });
  assertEquals(row?.source_id, "page:page-1");
  assertEquals(row?.metadata.inventory_expanded, false);
});

Deno.test("does not persist expiring Notion file URLs in inventory", () => {
  const rows = notionAttachmentRows({
    batchId: "batch-1",
    userId: "user-1",
    seenAt: "2026-08-23T00:00:00.000Z",
    block: {
      object: "block",
      id: "block-1",
      type: "image",
      image: {
        type: "file",
        caption: [{ plain_text: "Architecture" }],
        file: {
          url: "https://temporary.example/private-token",
          expiry_time: "2026-08-23T01:00:00.000Z",
        },
      },
    },
  });

  assertEquals(rows.length, 1);
  assertEquals(rows[0].title, "Architecture");
  assertEquals(rows[0].metadata.expiry_time, "2026-08-23T01:00:00.000Z");
  assertMatch(JSON.stringify(rows), /^((?!private-token).)*$/);
});

Deno.test("removes only expiring URLs from durable source payloads", () => {
  const payload = notionDurablePayload({
    public_url: "https://example.com/keep",
    properties: {
      Files: {
        files: [
          {
            name: "private.pdf",
            file: {
              url: "https://temporary.example/private-token",
              expiry_time: "2026-08-23T01:00:00.000Z",
            },
          },
        ],
      },
    },
  });

  assertMatch(JSON.stringify(payload), /^((?!private-token).)*$/);
  assertEquals(
    (payload as Record<string, unknown>).public_url,
    "https://example.com/keep",
  );
});

Deno.test("counts inventory kinds for progress summaries", () => {
  const base = {
    batch_id: "batch-1",
    user_id: "user-1",
    source_id: "page:1",
    parent_source_id: null,
    source_kind: "page",
    title: "Page",
    source_path: "Page",
    source_updated_at: null,
    metadata: {},
  };
  assertEquals(
    countNotionKinds([
      base,
      { ...base, source_id: "page:2" },
      { ...base, source_id: "block:1", source_kind: "block" },
    ]),
    { page: 2, block: 1 },
  );
});

Deno.test("classifies form views and child pages as first-class items", () => {
  const form = notionInventoryRow({
    batchId: "batch-1",
    userId: "user-1",
    seenAt: "2026-08-23T00:00:00.000Z",
    object: { object: "view", id: "view-1", type: "form", name: "Intake" },
  });
  const child = notionInventoryRow({
    batchId: "batch-1",
    userId: "user-1",
    seenAt: "2026-08-23T00:00:00.000Z",
    object: {
      object: "block",
      id: "page-2",
      type: "child_page",
      child_page: { title: "Nested" },
    },
  });

  assertEquals(form?.source_kind, "form");
  assertEquals(form?.title, "Intake");
  assertEquals(child?.source_kind, "page");
  assertEquals(child?.metadata.inventory_expanded, false);
});
