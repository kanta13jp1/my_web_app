import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleScheduleHubRequest } from "./index.ts";
import { ACTION_POLICIES, SCHEDULE_HUB_ACTIONS } from "./action_auth.ts";

function request(action: string, body: Record<string, unknown> = {}) {
  return new Request("https://fixture.invalid/schedule-hub", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...body, action }),
  });
}

Deno.test("real handler rejects every protected action before client creation", async () => {
  for (const action of SCHEDULE_HUB_ACTIONS) {
    for (const user of [null, "user-a"]) {
      const policy = ACTION_POLICIES[action];
      if (policy.auth === "public" || (policy.auth === "user" && user)) continue;
      let clients = 0;
      const response = await handleScheduleHubRequest(request(action), {
        getUserId: () => Promise.resolve(user),
        isServiceRoleRequest: () => false,
        createAdmin: () => {
          clients++;
          throw new Error("must not reach privileged client");
        },
      });
      assertEquals(response.status, 401, `${action}:${user}`);
      assertEquals(clients, 0, action);
    }
  }
});

Deno.test("real handler rejects unknown action before auth and database", async () => {
  let calls = 0;
  const response = await handleScheduleHubRequest(request("unknown.action"), {
    getUserId: () => { calls++; return Promise.resolve("user-a"); },
    isServiceRoleRequest: () => { calls++; return true; },
    createAdmin: () => { calls++; throw new Error("unexpected"); },
  });
  assertEquals(response.status, 400);
  assertEquals(calls, 0);
});

type Admin = ReturnType<NonNullable<
  Parameters<typeof handleScheduleHubRequest>[1]
>["createAdmin"]>;

Deno.test("service role reaches shared maintenance delete handler", async () => {
  const deleted: string[] = [];
  const admin = {
    from(table: string) {
      assertEquals(table, "maintenance_windows");
      return { delete: () => ({ eq: (_key: string, id: string) => {
        deleted.push(id);
        return Promise.resolve({ error: null });
      } }) };
    },
  } as unknown as Admin;
  const response = await handleScheduleHubRequest(request("maintenance.delete", { id: "window-a" }), {
    getUserId: () => Promise.resolve(null),
    isServiceRoleRequest: () => true,
    createAdmin: () => admin,
  });
  assertEquals(response.status, 200);
  assertEquals(deleted, ["window-a"]);
});

Deno.test("manager handler cannot overwrite another owner's stored task", async () => {
  for (const owner of ["user-a", "user-b"]) {
    let stored = { user_id: owner, name: "original" };
    const predicates: [string, unknown][] = [];
    const admin = {
      from(table: string) {
        assertEquals(table, "hub_data");
        return { update(payload: { metadata: typeof stored }) {
          const query = {
            eq(key: string, value: unknown) { predicates.push([key, value]); return query; },
            filter(key: string, op: string, value: unknown) {
              assertEquals(op, "eq");
              predicates.push([key, value]);
              return query;
            },
            then(resolve: (result: { error: null }) => unknown) {
              const row: Record<string, unknown> = {
                id: "task-1", source: "scheduled_task", "metadata->>user_id": stored.user_id,
              };
              if (predicates.every(([key, value]) => row[key] === value)) stored = payload.metadata;
              return Promise.resolve(resolve({ error: null }));
            },
          };
          return query;
        } };
      },
    } as unknown as Admin;
    const response = await handleScheduleHubRequest(request("manager.update", {
      id: "task-1", name: "changed", user_id: "user-b",
    }), {
      getUserId: () => Promise.resolve("user-a"),
      isServiceRoleRequest: () => false,
      createAdmin: () => admin,
    });
    assertEquals(response.status, 200);
    assertEquals(stored.name, owner === "user-a" ? "changed" : "original");
    assertEquals(stored.user_id, owner);
  }
});
