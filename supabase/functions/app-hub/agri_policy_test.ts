import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AGRI_POLICY_SOURCE,
  AgriPolicyActionError,
  AgriPolicyDb,
  handleAgriPolicyAction,
} from "./agri_policy.ts";

class MockAgriPolicyDb implements AgriPolicyDb {
  rows: Array<{
    id: string;
    source: string;
    metadata: Record<string, unknown>;
    created_at: string;
  }> = [];
  private seq = 1;

  from(_table: string) {
    const state: {
      op: "select" | "insert" | "update";
      insertVal?: Record<string, unknown>;
      updateVal?: Record<string, unknown>;
      eqFilters: Array<[string, unknown]>;
      jsonFilters: Array<[string, string]>;
    } = {
      op: "select",
      eqFilters: [],
      jsonFilters: [],
    };

    const execute = () => {
      if (state.op === "insert" && state.insertVal) {
        const idx = this.seq++;
        const created = {
          id: `agri-${idx}`,
          source: String(state.insertVal.source ?? ""),
          metadata: (state.insertVal.metadata ?? {}) as Record<string, unknown>,
          created_at: `2026-11-26T00:00:${String(idx).padStart(2, "0")}Z`,
        };
        this.rows.push(created);
        return { data: created, error: null };
      }

      const matches = this.rows.filter((row) => {
        for (const [col, val] of state.eqFilters) {
          if (col === "id" && row.id !== val) return false;
          if (col === "source" && row.source !== val) return false;
        }
        for (const [expr, expected] of state.jsonFilters) {
          const field = expr.replace("metadata->>", "");
          if (String(row.metadata[field] ?? "") !== expected) {
            return false;
          }
        }
        return true;
      });

      if (state.op === "update" && state.updateVal) {
        if (matches.length === 0) {
          return { data: null, error: null };
        }
        matches[0].metadata = (state.updateVal.metadata ?? {}) as Record<
          string,
          unknown
        >;
        return { data: matches[0], error: null };
      }

      return { data: matches, error: null };
    };

    const builder = {
      select(_columns: string) {
        return builder;
      },
      insert(values: Record<string, unknown>) {
        state.op = "insert";
        state.insertVal = values;
        return builder;
      },
      update(values: Record<string, unknown>) {
        state.op = "update";
        state.updateVal = values;
        return builder;
      },
      eq(col: string, val: unknown) {
        state.eqFilters.push([col, val]);
        return builder;
      },
      filter(col: string, _op: string, val: unknown) {
        state.jsonFilters.push([col, String(val)]);
        return builder;
      },
      order(_col: string, _opts?: { ascending?: boolean }) {
        return builder;
      },
      limit(_count: number) {
        return builder;
      },
      single() {
        return Promise.resolve(execute());
      },
      maybeSingle() {
        const res = execute();
        const first = Array.isArray(res.data)
          ? (res.data[0] ?? null)
          : res.data;
        return Promise.resolve({ data: first, error: res.error });
      },
      then(onfulfilled?: (value: unknown) => unknown) {
        return Promise.resolve(execute()).then(onfulfilled);
      },
    };

    return builder;
  }
}

Deno.test("agri_policy.seed_defaults & list sort by date", async () => {
  const db = new MockAgriPolicyDb();
  const seeded = await handleAgriPolicyAction({
    action: "agri_policy.list",
    admin: db,
    body: { seed_if_empty: true },
    userId: "user-1",
  });

  const events = seeded.events as Array<Record<string, unknown>>;
  assertEquals(events.length, 5);
  assertEquals(events[0].event_date, "2018-04-01");
  assertEquals(events[4].event_date, "2027-04-01");
  assertEquals(db.rows[0].source, AGRI_POLICY_SOURCE);

  const reseed = await handleAgriPolicyAction({
    action: "agri_policy.seed_defaults",
    admin: db,
    body: {},
    userId: "user-1",
  });
  assertEquals(reseed.inserted_count, 0);
});

Deno.test("agri_policy.list filters by tag, keyword & edges", async () => {
  const db = new MockAgriPolicyDb();
  await handleAgriPolicyAction({
    action: "agri_policy.seed_defaults",
    admin: db,
    body: {},
    userId: "user-1",
  });

  const byTag = await handleAgriPolicyAction({
    action: "agri_policy.list",
    admin: db,
    body: { tag: "マルキン制度" },
    userId: "user-1",
  });
  const tagEvents = byTag.events as Array<Record<string, unknown>>;
  assertEquals(tagEvents.length, 1);
  assertEquals(tagEvents[0].fiscal_year, 2019);

  const byQuery = await handleAgriPolicyAction({
    action: "agri_policy.list",
    admin: db,
    body: { query: "減反廃止" },
    userId: "user-1",
  });
  const qEvents = byQuery.events as Array<Record<string, unknown>>;
  assertEquals(qEvents.length, 2);
  const edges = byQuery.knowledge_edges as Array<Record<string, unknown>>;
  assertEquals(edges.length, 1);
});

Deno.test("agri_policy.create and update fact_check_status", async () => {
  const db = new MockAgriPolicyDb();
  const created = await handleAgriPolicyAction({
    action: "agri_policy.create",
    admin: db,
    body: {
      event_date: "2026-06-01",
      title: "備蓄米放出スキームの運用検証",
      tags: ["備蓄米", "減反廃止"],
      related_nodes: ["農林水産省", "備蓄米"],
      fact_check_status: "unverified",
      source_citation: "国会審議録 2026-06",
      policy_impact_notes: "市場流通量の変化を追跡中。",
    },
    userId: "user-1",
  });

  const event = created.event as Record<string, unknown>;
  assertEquals(event.fact_check_status, "unverified");
  assertEquals(event.verified_at, null);

  const updated = await handleAgriPolicyAction({
    action: "agri_policy.update",
    admin: db,
    body: {
      id: event.id,
      fact_check_status: "verified",
      source_citation: "農林水産省 公式統計 2026-06",
    },
    userId: "user-1",
  });

  const updEvent = updated.event as Record<string, unknown>;
  assertEquals(updEvent.fact_check_status, "verified");
  assertEquals(updEvent.source_citation, "農林水産省 公式統計 2026-06");
  assertEquals(typeof updEvent.verified_at, "string");
});

Deno.test("agri_policy validates date and ownership", async () => {
  const db = new MockAgriPolicyDb();
  await assertRejects(
    () =>
      handleAgriPolicyAction({
        action: "agri_policy.create",
        admin: db,
        body: { title: "テスト", event_date: "invalid-date" },
        userId: "user-1",
      }),
    AgriPolicyActionError,
  );

  const created = await handleAgriPolicyAction({
    action: "agri_policy.create",
    admin: db,
    body: { title: "User A event", event_date: "2026-01-01" },
    userId: "user-a",
  });
  const event = created.event as Record<string, unknown>;

  await assertRejects(
    () =>
      handleAgriPolicyAction({
        action: "agri_policy.update",
        admin: db,
        body: { id: event.id, fact_check_status: "verified" },
        userId: "user-b",
      }),
    AgriPolicyActionError,
  );
});
