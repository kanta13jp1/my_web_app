import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleRealtimeLockAction,
  REALTIME_LOCK_SOURCE,
  RealtimeLockDb,
  RealtimeLockError,
} from "./realtime_lock.ts";

class MockLockDb implements RealtimeLockDb {
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
        const created = {
          id: `doc-${this.seq++}`,
          source: String(state.insertVal.source ?? ""),
          metadata: (state.insertVal.metadata ?? {}) as Record<string, unknown>,
          created_at: `2026-11-25T00:00:0${this.seq}Z`,
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
      order() {
        return builder;
      },
      limit() {
        return builder;
      },
      single() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      maybeSingle() {
        const res = execute();
        return Promise.resolve({
          data: Array.isArray(res.data) ? res.data[0] ?? null : res.data,
          error: res.error,
        });
      },
      then(onfulfilled?: (value: unknown) => unknown) {
        return Promise.resolve(execute()).then(onfulfilled);
      },
    };
    return builder;
  }
}

Deno.test(
  "creates record at r1, bumps revision atomically, and emits notice",
  async () => {
    const db = new MockLockDb();
    const notices: Array<{ id: string; rev: unknown }> = [];

    const created = await handleRealtimeLockAction({
      action: "realtime_lock.create",
      admin: db,
      userId: "user-1",
      body: { title: "Shift Schedule", content: "Team A", updated_by: "alice" },
    });
    const doc = created.record as Record<string, unknown>;
    assertEquals(doc.revision, 1);

    const saved = await handleRealtimeLockAction({
      action: "realtime_lock.save",
      admin: db,
      userId: "user-1",
      body: {
        record_id: doc.id,
        expected_revision: 1,
        content: "Team A + B",
        updated_by: "alice",
      },
      notifier: (id, payload) => {
        notices.push({ id, rev: payload.new_revision });
        return Promise.resolve();
      },
    });
    assertEquals((saved.record as Record<string, unknown>).revision, 2);
    assertEquals(notices.length, 1);
    assertEquals(notices[0].rev, 2);
    assertEquals(db.rows[0].source, REALTIME_LOCK_SOURCE);
  },
);

Deno.test(
  "blocks stale expected_revision and batch conflict with HTTP 409",
  async () => {
    const db = new MockLockDb();
    const created = await handleRealtimeLockAction({
      action: "realtime_lock.create",
      admin: db,
      userId: "user-1",
      body: { title: "Runbook", content: "v1" },
    });
    const doc = created.record as Record<string, unknown>;

    // Simulate background batch update bumping r1 -> r2.
    const batchRes = await handleRealtimeLockAction({
      action: "realtime_lock.simulate_batch_update",
      admin: db,
      userId: "user-1",
      body: { record_id: doc.id, actor: "nightly-batch" },
    });
    assertEquals((batchRes.record as Record<string, unknown>).revision, 2);

    // User still holding expected_revision=1 must receive 409 Conflict.
    const err = await assertRejects(
      () =>
        handleRealtimeLockAction({
          action: "realtime_lock.save",
          admin: db,
          userId: "user-1",
          body: {
            record_id: doc.id,
            expected_revision: 1,
            content: "stale overwrite attempt",
          },
        }),
      RealtimeLockError,
    );
    assertEquals(err.status, 409);
    assertEquals(err.payload.conflict, true);
    assertEquals(err.payload.current_revision, 2);
    // Stored content remains uncorrupted by stale write.
    assertEquals(
      String(db.rows[0].metadata.content).includes("nightly") ||
        String(db.rows[0].metadata.content).includes("batch-sync"),
      true,
    );
  },
);

Deno.test("enforces ownership isolation on cross-user lock saves", async () => {
  const db = new MockLockDb();
  const created = await handleRealtimeLockAction({
    action: "realtime_lock.create",
    admin: db,
    userId: "user-1",
    body: { title: "Private Doc", content: "v1" },
  });
  const doc = created.record as Record<string, unknown>;

  const err = await assertRejects(
    () =>
      handleRealtimeLockAction({
        action: "realtime_lock.save",
        admin: db,
        userId: "user-2",
        body: { record_id: doc.id, expected_revision: 1, content: "hijack" },
      }),
    RealtimeLockError,
  );
  assertEquals(err.status, 404);
});
