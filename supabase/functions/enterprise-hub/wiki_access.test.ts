// Exercise the deployed handler expressions without starting serve or using secrets.
// Query double executes predicates over two owners; this is not an RLS integration test.
const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

type Row = {
  id: string;
  source: string;
  created_at?: string;
  metadata: Record<string, unknown>;
};

type DbDouble = {
  rows: Row[];
  from(table: string): unknown;
};

async function addItem(
  admin: DbDouble,
  itemSource: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const query = admin.from("hub_data") as {
    insert(value: { source: string; metadata: Record<string, unknown> }): {
      select(cols: string): { single(): Promise<{ data: Row; error: null | { message: string } }> };
    };
  };
  const { data, error } = await query
    .insert({ source: itemSource, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

function handler(action: string) {
  const start = source.indexOf(`      case "${action}": {`);
  if (start < 0) throw new Error("Missing action");
  const bodyStart = source.indexOf("{", start) + 1;
  const end = source.indexOf("\n      }", bodyStart);
  const fn = new AsyncFunction(
    "admin",
    "userId",
    "body",
    "json",
    "addItem",
    source.slice(bodyStart, end).replace("const changes: Record<string, unknown>", "const changes"),
  );
  return (admin: unknown, userId: string, body: Record<string, unknown>, jsonFn: unknown) =>
    fn(admin, userId, body, jsonFn, addItem);
}

function database(fail: boolean | number = false, concurrent = false) {
  const rows: Row[] = [
    {
      id: "a",
      source: "wiki_page",
      created_at: "2026-01-01T00:00:00Z",
      metadata: {
        user_id: "alice",
        title: "Shared words",
        content: "original",
        category: "parent",
        tags: ["keep"],
        preserved: { block_id: "block" },
      },
    },
    {
      id: "b",
      source: "wiki_page",
      created_at: "2026-01-01T00:00:00Z",
      metadata: { user_id: "bob", title: "Shared words" },
    },
    {
      id: "c",
      source: "sheet_row",
      created_at: "2026-01-01T00:00:00Z",
      metadata: { user_id: "alice", title: "Shared words" },
    },
  ];
  let queryCount = 0;
  let seq = 0;
  return {
    rows,
    from(table: string) {
      if (table !== "hub_data") throw new Error("Unexpected table");
      queryCount += 1;
      const myQueryIndex = queryCount;
      const predicates: ((row: Row) => boolean)[] = [];
      let patch: { metadata: Record<string, unknown> } | undefined;
      let insertion: { source: string; metadata: Record<string, unknown> } | undefined;
      let single = false;
      let from = 0;
      let to = Infinity;
      const orders: { key: string; ascending: boolean }[] = [];
      const query = {
        select(_columns: string) { return query; },
        eq(key: "id" | "source" | "metadata", value: string) {
          predicates.push((row) => key === "metadata"
            ? JSON.stringify(row.metadata) === value
            : row[key] === value);
          return query;
        },
        filter(key: string, op: string, value: string) {
          if (!key.startsWith("metadata->>") || op !== "eq") throw new Error("Unexpected filter");
          const field = key.slice("metadata->>".length);
          predicates.push((row) => row.metadata[field] === value);
          return query;
        },
        ilike(_key: string, _value: string) { return query; },
        order(key: string, options: { ascending: boolean }) { orders.push({ key, ascending: options.ascending }); return query; },
        range(start: number, end: number) { from = start; to = end; return query; },
        limit(_count: number) { return query; },
        update(value: { metadata: Record<string, unknown> }) { patch = value; return query; },
        insert(value: { source: string; metadata: Record<string, unknown> }) { insertion = value; return query; },
        maybeSingle() { single = true; return query; },
        single() { single = true; return query; },
        then(resolve: (result: unknown) => unknown) {
          const shouldFail = fail === true || (typeof fail === "number" && myQueryIndex === fail);
          if (shouldFail) return Promise.resolve(resolve({ data: null, error: { message: "query_failed" } }));
          if (insertion) {
            seq += 1;
            const created: Row = {
              id: `inserted-${seq}`,
              source: insertion.source,
              created_at: `2026-01-02T00:00:${String(seq).padStart(2, "0")}Z`,
              metadata: structuredClone(insertion.metadata),
            };
            rows.push(created);
            return Promise.resolve(resolve({ data: structuredClone(created), error: null }));
          }
          if (patch && concurrent) rows[0].metadata = { ...rows[0].metadata, content: "concurrent edit" };
          const filtered = rows.filter((row) => predicates.every((p) => p(row)));
          filtered.sort((a, b) => {
            for (const order of orders) {
              const left = String((a as unknown as Record<string, unknown>)[order.key] ?? "");
              const right = String((b as unknown as Record<string, unknown>)[order.key] ?? "");
              const compared = left < right ? -1 : left > right ? 1 : 0;
              if (compared) return order.ascending ? compared : -compared;
            }
            return 0;
          });
          const found = filtered.slice(from, to + 1);
          if (patch) for (const row of found) row.metadata = patch.metadata;
          return Promise.resolve(resolve({ data: structuredClone(single ? found[0] ?? null : found), error: null }));
        },
      };
      return query;
    },
  };
}

function json(value: unknown, status = 200) { return { value, status }; }
function check(value: unknown, message: string) { if (!value) throw new Error(message); }

for (const action of ["wiki.list", "kb.search"]) {
  Deno.test(`${action} only returns the authenticated owner's wiki`, async () => {
    const db = database();
    const result = await handler(action)(db, "alice", { query: "Shared" }, json);
    const rows = result.value.pages ?? result.value.results;
    check(rows.length === 1 && rows[0].id === "a", "Cross-owner or cross-source read");
  });
  Deno.test(`${action} propagates query failure`, async () => {
    let failed = false;
    try { await handler(action)(database(true), "alice", {}, json); }
    catch (error) { failed = error instanceof Error && error.message === "query_failed"; }
    check(failed, "Query error was reported as success");
  });
}

for (const id of ["b", "missing", "c"]) {
  Deno.test(`wiki.update rejects inaccessible target ${id}`, async () => {
    const db = database();
    const before = JSON.stringify(db.rows);
    const result = await handler("wiki.update")(db, "alice", { id, content: "overwrite" }, json);
    check(result.status === 404, "Inaccessible update reported success");
    check(JSON.stringify(db.rows) === before, "Inaccessible row changed");
  });
}
Deno.test("wiki.update permits owner and pins ownership to authenticated user", async () => {
  const db = database();
  const result = await handler("wiki.update")(db, "alice", { id: "a", user_id: "bob", content: "updated" }, json);
  check(result.status === 200, "Owner update failed");
  check(db.rows[0].metadata.user_id === "alice", "Ownership changed");
  check(db.rows[0].metadata.content === "updated", "Content was not updated");
  check(db.rows[1].metadata.content === undefined, "Other owner changed");
});
Deno.test("wiki.update propagates query failure", async () => {
  let failed = false;
  try { await handler("wiki.update")(database(true), "alice", { id: "a" }, json); }
  catch (error) { failed = error instanceof Error && error.message === "query_failed"; }
  check(failed, "Query error was reported as success");
});

Deno.test("title-only update preserves content, parent, tags and unrecognized metadata", async () => {
  const db = database();
  const result = await handler("wiki.update")(db, "alice", { id: "a", title: "renamed", preserved: null }, json);
  check(result.status === 200, "Owner update failed");
  const meta = db.rows[0].metadata;
  check(meta.title === "renamed" && meta.content === "original", "Content was lost");
  check(meta.category === "parent" && JSON.stringify(meta.tags) === '["keep"]', "Hierarchy or tags lost");
  check(JSON.stringify(meta.preserved) === '{"block_id":"block"}', "Unrecognized metadata overwritten");
  check(!Object.hasOwn(meta, "id"), "Request control fields persisted");
});
Deno.test("explicit empty content and tags and null parent are retained", async () => {
  const db = database();
  await handler("wiki.update")(db, "alice", { id: "a", content: "", tags: [], category: null }, json);
  check(db.rows[0].metadata.content === "", "Explicit empty content ignored");
  check(db.rows[0].metadata.category === null, "Explicit parent clear ignored");
  check(JSON.stringify(db.rows[0].metadata.tags) === "[]", "Explicit tag clear ignored");
});
Deno.test("concurrent metadata change returns conflict without overwriting", async () => {
  const db = database(false, true);
  const result = await handler("wiki.update")(db, "alice", { id: "a", content: "overwrite" }, json);
  check(result.status === 409, "Concurrent update was not rejected");
  check(db.rows[0].metadata.content === "concurrent edit", "Concurrent content overwritten");
});
Deno.test("wiki.update rejects stale expected_updated_at and accepts matching stamp", async () => {
  const db = database();
  db.rows[0].metadata.updated_at = "2026-11-25T00:00:00Z";
  const stale = await handler("wiki.update")(
    db,
    "alice",
    { id: "a", content: "stale-write", expected_updated_at: "2026-11-24T00:00:00Z" },
    json,
  );
  check(stale.status === 409, "Stale expected_updated_at was not rejected");
  check(db.rows[0].metadata.content === "original", "Stale write modified content");
  const fresh = await handler("wiki.update")(
    db,
    "alice",
    { id: "a", content: "fresh-write", expected_updated_at: "2026-11-25T00:00:00Z" },
    json,
  );
  check(fresh.status === 200, "Matching expected_updated_at failed");
  check(db.rows[0].metadata.content === "fresh-write", "Fresh write did not persist");
});
Deno.test("wiki.update rejects self-parent and cross-owner parent_id", async () => {
  const db = database();
  const selfRef = await handler("wiki.update")(db, "alice", { id: "a", parent_id: "a" }, json);
  check(selfRef.status === 400, "Self-parent was accepted");
  const crossOwner = await handler("wiki.update")(db, "alice", { id: "a", parent_id: "b" }, json);
  check(crossOwner.status === 404, "Cross-owner parent_id was accepted");
});

Deno.test("wiki.list traverses more than 50 owner pages without duplicates", async () => {
  const db = database();
  for (let n = 0; n < 75; n++) {
    db.rows.push({ id: `page-${String(n).padStart(3, "0")}`, source: "wiki_page", metadata: { user_id: "alice" } });
  }
  const first = await handler("wiki.list")(db, "alice", {}, json);
  check(first.value.pages.length === 50 && first.value.next_offset === 50, "Missing continuation");
  const second = await handler("wiki.list")(db, "alice", { offset: first.value.next_offset }, json);
  const ids = [...first.value.pages, ...second.value.pages].map((row: Row) => row.id);
  check(ids.length === 76 && new Set(ids).size === 76, "Page loss or duplication");
  check(!ids.includes("b") && !ids.includes("c"), "Owner/source isolation lost");
  check(second.value.next_offset === null, "Final page has spurious continuation");
  check(first.value.pages[0].id === "page-074", "Stable tie ordering missing");
});
for (const body of [{ offset: -1 }, { offset: 1.5 }, { offset: "0" }, { offset: 1000001 }, { limit: 0 }, { limit: 101 }, { limit: "50" }]) {
  Deno.test(`wiki.list rejects invalid pagination ${JSON.stringify(body)}`, async () => {
    const result = await handler("wiki.list")(database(), "alice", body, json);
    check(result.status === 400, "Invalid pagination accepted");
  });
}
Deno.test("wiki.list exact and empty boundaries do not invent next pages", async () => {
  const db = database();
  const first = await handler("wiki.list")(db, "alice", { limit: 1 }, json);
  check(first.value.pages.length === 1 && first.value.next_offset === null, "Exact boundary incorrect");
  const empty = await handler("wiki.list")(db, "alice", { offset: 10 }, json);
  check(empty.value.pages.length === 0 && empty.value.next_offset === null, "Empty boundary incorrect");
});

Deno.test("wiki.list rejects an unreachable continuation without claiming completion", async () => {
  for (const [offset, limit] of [[1000000, 1], [999999, 2]]) {
    const rows = Array.from({ length: limit + 1 }, (_, n) => ({ id: `boundary-${n}` }));
    const query: Record<string, unknown> = {};
    for (const method of ["select", "eq", "filter", "order", "range"]) {
      query[method] = () => query;
    }
    query.then = (resolve: (value: unknown) => unknown) => Promise.resolve(resolve({ data: rows, error: null }));
    const db = { from: () => query };
    const result = await handler("wiki.list")(db, "alice", { offset, limit }, json);
    check(result.status === 422, "Expected explicit pagination limit error");
    check(result.value.error === "Wiki pagination limit reached; more pages exist", "Limit error did not explain remaining pages");
  }
});
for (const id of ["b", "c", "missing"]) {
  Deno.test(`wiki.get hides inaccessible target ${id}`, async () => {
    const result = await handler("wiki.get")(database(), "alice", { id }, json);
    check(result.status === 404, "Inaccessible page exposed");
  });
}
Deno.test("wiki.get retrieves exact owner page independently of list limit", async () => {
  const db = database();
  for (let n = 0; n < 75; n++) db.rows.push({ id: `z-${n}`, source: "wiki_page", metadata: { user_id: "alice" } });
  const result = await handler("wiki.get")(db, "alice", { id: "a" }, json);
  check(result.status === 200 && result.value.page.metadata.content === "original", "Direct page lookup failed");
});
Deno.test("wiki.get rejects absent id and propagates query errors", async () => {
  const missing = await handler("wiki.get")(database(), "alice", {}, json);
  check(missing.status === 400, "Missing id accepted");
  let failed = false;
  try { await handler("wiki.get")(database(true), "alice", { id: "a" }, json); }
  catch (error) { failed = error instanceof Error && error.message === "query_failed"; }
  check(failed, "Lookup failure reported as success");
});

Deno.test("wiki.get returns owner-scoped deduplicated children and table rows only", async () => {
  const db = database();
  db.rows.push(
    { id: "child-parent", source: "wiki_page", created_at: "2026-01-02T00:00:00Z", metadata: { user_id: "alice", parent_id: "a", title: "Child Parent" } },
    { id: "child-legacy", source: "wiki_page", created_at: "2026-01-03T00:00:00Z", metadata: { user_id: "alice", category: "a", title: "Child Legacy" } },
    { id: "child-both", source: "wiki_page", created_at: "2026-01-04T00:00:00Z", metadata: { user_id: "alice", parent_id: "a", category: "a", title: "Child Both" } },
    { id: "bob-child", source: "wiki_page", created_at: "2026-01-05T00:00:00Z", metadata: { user_id: "bob", parent_id: "a", title: "Bob Child" } },
    { id: "alice-row", source: "sheet_row", created_at: "2026-01-02T00:00:00Z", metadata: { user_id: "alice", sheet_id: "a", data: { content: "Row 1" } } },
    { id: "bob-row", source: "sheet_row", created_at: "2026-01-03T00:00:00Z", metadata: { user_id: "bob", sheet_id: "a", data: { content: "Bob Row" } } },
  );
  const result = await handler("wiki.get")(db, "alice", { id: "a" }, json);
  check(result.status === 200, "wiki.get failed");
  const childIds = result.value.children.map((row: Row) => row.id);
  check(JSON.stringify(childIds) === '["child-both","child-legacy","child-parent"]', `Unexpected children: ${JSON.stringify(childIds)}`);
  check(result.value.children_has_more === false, "Spurious children_has_more");
  const rowIds = result.value.table_rows.map((row: Row) => row.id);
  check(JSON.stringify(rowIds) === '["alice-row"]', `Unexpected table rows: ${JSON.stringify(rowIds)}`);
  check(result.value.table_rows_has_more === false, "Spurious table_rows_has_more");
});

Deno.test("wiki.get caps children and table rows at 100 and signals has_more", async () => {
  const db = database();
  for (let n = 0; n < 105; n++) {
    db.rows.push({
      id: `child-${String(n).padStart(3, "0")}`,
      source: "wiki_page",
      created_at: `2026-02-01T00:00:${String(n % 60).padStart(2, "0")}Z`,
      metadata: { user_id: "alice", parent_id: "a", title: `Sub ${n}` },
    });
    db.rows.push({
      id: `row-${String(n).padStart(3, "0")}`,
      source: "sheet_row",
      created_at: `2026-02-02T00:00:${String(n % 60).padStart(2, "0")}Z`,
      metadata: { user_id: "alice", sheet_id: "a", data: { content: `R${n}` } },
    });
  }
  const result = await handler("wiki.get")(db, "alice", { id: "a" }, json);
  check(result.status === 200, "wiki.get capped lookup failed");
  check(result.value.children.length === 100 && result.value.children_has_more === true, "Children cap/flag incorrect");
  check(result.value.table_rows.length === 100 && result.value.table_rows_has_more === true, "Table row cap/flag incorrect");
});

for (const failQuery of [2, 3, 4]) {
  Deno.test(`wiki.get propagates child/row query failure on step ${failQuery}`, async () => {
    let failed = false;
    try { await handler("wiki.get")(database(failQuery), "alice", { id: "a" }, json); }
    catch (error) { failed = error instanceof Error && error.message === "query_failed"; }
    check(failed, `Query failure step ${failQuery} was swallowed`);
  });
}

Deno.test("wiki.create validates parent_id ownership and stores owner-scoped child", async () => {
  const db = database();
  const created = await handler("wiki.create")(db, "alice", { title: "Sub", content: "Body", parent_id: "a" }, json);
  check(created.status === 200 && created.value.page.metadata.parent_id === "a", "Subpage create failed");
  check(created.value.page.metadata.user_id === "alice", "Owner not pinned on create");
  const crossOwner = await handler("wiki.create")(db, "alice", { title: "Bad", parent_id: "b" }, json);
  check(crossOwner.status === 404, "Cross-owner parent_id accepted on create");
  const missingParent = await handler("wiki.create")(db, "alice", { title: "Bad", parent_id: "missing" }, json);
  check(missingParent.status === 404, "Missing parent_id accepted on create");
  const invalidParent = await handler("wiki.create")(db, "alice", { title: "Bad", parent_id: "  " }, json);
  check(invalidParent.status === 400, "Blank parent_id accepted on create");
});
