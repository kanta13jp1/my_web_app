import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  NotionDataSourceError,
  queryAllNotionDataSourcePages,
  resolveNotionDataSourceId,
  retrieveAllNotionPagePropertyItems,
} from "./notion_data_source.ts";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.test("resolveNotionDataSourceId prefers an explicit data-source ID", async () => {
  let requests = 0;
  const id = await resolveNotionDataSourceId(
    () => {
      requests++;
      return Promise.resolve(jsonResponse({}));
    },
    { databaseId: "db", dataSourceId: "ab-cd" },
  );

  assertEquals(id, "abcd");
  assertEquals(requests, 0);
});

Deno.test("resolveNotionDataSourceId discovers the only database data source", async () => {
  const paths: string[] = [];
  const id = await resolveNotionDataSourceId(
    (path) => {
      paths.push(path);
      return Promise.resolve(jsonResponse({
        data_sources: [{ id: "12-34", name: "Tasks" }],
      }));
    },
    { databaseId: "db-id" },
  );

  assertEquals(id, "1234");
  assertEquals(paths, ["/databases/dbid"]);
});

Deno.test("resolveNotionDataSourceId requires a selector for multiple sources", async () => {
  const request = () =>
    Promise.resolve(jsonResponse({
      data_sources: [
        { id: "one", name: "Tasks" },
        { id: "two", name: "Archive" },
      ],
    }));

  await assertRejects(
    () => resolveNotionDataSourceId(request, { databaseId: "db" }),
    NotionDataSourceError,
    "multiple data sources",
  );
  assertEquals(
    await resolveNotionDataSourceId(request, {
      databaseId: "db",
      dataSourceName: "Archive",
    }),
    "two",
  );
});

Deno.test("queryAllNotionDataSourcePages follows bounded cursors", async () => {
  const calls: Array<{ path: string; body: Record<string, unknown> }> = [];
  const pages = [
    { results: [{ id: "one" }], has_more: true, next_cursor: "next" },
    { results: [{ id: "two" }], has_more: false, next_cursor: null },
  ];
  const results = await queryAllNotionDataSourcePages(
    (path, init) => {
      calls.push({
        path,
        body: JSON.parse(String(init?.body)) as Record<string, unknown>,
      });
      return Promise.resolve(jsonResponse(pages[calls.length - 1]));
    },
    "source-id",
    { filter: { property: "Status" } },
    { pageSize: 50 },
  );

  assertEquals(results.map((item) => item.id), ["one", "two"]);
  assertEquals(calls, [
    {
      path: "/data_sources/sourceid/query",
      body: { filter: { property: "Status" }, page_size: 50 },
    },
    {
      path: "/data_sources/sourceid/query",
      body: {
        filter: { property: "Status" },
        page_size: 50,
        start_cursor: "next",
      },
    },
  ]);
});

Deno.test("retrieveAllNotionPagePropertyItems gets values after item 25", async () => {
  const paths: string[] = [];
  const pages = [
    {
      object: "list",
      results: [{ relation: { id: "one" } }],
      property_item: { type: "rollup", rollup: { type: "incomplete" } },
      has_more: true,
      next_cursor: "cursor two",
    },
    {
      object: "list",
      results: [{ relation: { id: "two" } }],
      property_item: { type: "rollup", rollup: { type: "number", number: 2 } },
      has_more: false,
      next_cursor: null,
    },
  ];
  const result = await retrieveAllNotionPagePropertyItems(
    (path) => {
      paths.push(path);
      return Promise.resolve(jsonResponse(pages[paths.length - 1]));
    },
    "page-id",
    "relation id",
  );

  assertEquals(result.results.length, 2);
  assertEquals(result.propertyItem, {
    type: "rollup",
    rollup: { type: "number", number: 2 },
  });
  assertEquals(paths, [
    "/pages/pageid/properties/relation%20id?page_size=100",
    "/pages/pageid/properties/relation%20id?page_size=100&start_cursor=cursor+two",
  ]);
});

Deno.test("retrieveAllNotionPagePropertyItems does not double-encode property IDs", async () => {
  let requestedPath = "";
  await retrieveAllNotionPagePropertyItems(
    (path) => {
      requestedPath = path;
      return Promise.resolve(jsonResponse({
        object: "list",
        results: [],
        has_more: false,
        next_cursor: null,
      }));
    },
    "page-id",
    "relation%20id",
  );

  assertEquals(
    requestedPath,
    "/pages/pageid/properties/relation%20id?page_size=100",
  );
});

Deno.test("Notion errors retain bounded upstream details", async () => {
  const error = await assertRejects(
    () =>
      queryAllNotionDataSourcePages(
        () => Promise.resolve(jsonResponse({ code: "validation_error" }, 400)),
        "source",
      ),
    NotionDataSourceError,
    "HTTP 400",
  );

  assertEquals(error.status, 400);
  assertEquals(error.detail, '{"code":"validation_error"}');
});
