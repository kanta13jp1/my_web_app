import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { CORE_HUB_ACTION_REGISTRY } from "./action_registry.ts";
import type { BlogPostRow } from "./blog_view.ts";
import { handleCoreHubRequest } from "./index.ts";

function post(action: string): Request {
  return new Request("https://example.test/functions/v1/core-hub", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action, memo_id: 42, reaction: "👍" }),
  });
}

// Mirrors the real blog_posts schema, rather than the old invented
// excerpt/published_at fixture. Selecting either missing column reproduces
// PostgREST 42703 and therefore the public route's sanitized HTTP 500.
const publicBlogRow: BlogPostRow = {
  id: "public-post",
  title: "Published post",
  content: "Published body",
  content_preview: "Published preview",
  posted_at: "2026-10-03T00:00:00Z",
  url: null,
  tags: ["regression"],
};

function schemaCheckedBlogClient() {
  const calls: unknown[][] = [];
  let selected: string[] = [];
  const filters = new Map<string, unknown>();
  const query = {
    select(columns: string) {
      selected = columns.split(",").map((column) => column.trim());
      return query;
    },
    eq(column: string, value: unknown) {
      filters.set(column, value);
      calls.push(["eq", column, value]);
      return query;
    },
    order(column: string, options: unknown) {
      calls.push(["order", column, options]);
      return query;
    },
    limit(value: number) {
      calls.push(["limit", value]);
      return Promise.resolve(result(false));
    },
    maybeSingle() {
      return Promise.resolve(result(true));
    },
  };
  function result(single: boolean) {
    const missing = selected.find((column) => !(column in publicBlogRow));
    if (missing) {
      return {
        data: null,
        error: {
          code: "42703",
          message: `column blog_posts.${missing} does not exist`,
        },
      };
    }
    assertEquals(filters.get("status"), "posted");
    if (single) assertEquals(filters.get("id"), publicBlogRow.id);
    return { data: single ? publicBlogRow : [publicBlogRow], error: null };
  }
  return {
    calls,
    client: {
      from(table: string) {
        assertEquals(table, "blog_posts");
        return query;
      },
    },
  };
}

for (const action of ["blog.public.list", "blog.public.view"]) {
  for (const format of ["json", "html", "md", "txt"]) {
    Deno.test(`${action} anonymous GET ${format} uses real blog columns`, async () => {
      const { client, calls } = schemaCheckedBlogClient();
      let authenticateCalled = false;
      const response = await handleCoreHubRequest(
        new Request(
          `https://example.test/functions/v1/core-hub?action=${action}&limit=3&format=${format}&id=${publicBlogRow.id}`,
        ),
        {
          createAdminClient: () => client as never,
          authenticateUser: () => {
            authenticateCalled = true;
            return Promise.resolve(null);
          },
          reportError: () => {},
        },
      );
      assertEquals(response.status, 200);
      assertFalse(authenticateCalled);
      if (action === "blog.public.list") {
        assertEquals(calls, [
          ["eq", "status", "posted"],
          ["order", "posted_at", { ascending: false }],
          ["limit", 3],
        ]);
      }
      if (format === "json") {
        const payload = await response.json();
        assertEquals(payload.success, true);
        const row = action === "blog.public.list"
          ? payload.posts[0]
          : payload.post;
        assertEquals(row.id, publicBlogRow.id);
        assertEquals(row.excerpt, publicBlogRow.content_preview);
        assertEquals(row.publishedAt, publicBlogRow.posted_at);
      } else {
        assertEquals(
          (await response.text()).includes(publicBlogRow.title ?? ""),
          true,
        );
      }
    });
  }
}

function serviceRolePost(
  action: string,
  body: Record<string, unknown>,
): Request {
  return new Request("https://example.test/functions/v1/core-hub", {
    method: "POST",
    headers: {
      authorization: "Bearer expected-service-role-key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ action, ...body }),
  });
}

for (const action of ["memo.react.list", "memo.react.toggle"]) {
  Deno.test(`${action} reaches the route without authentication`, async () => {
    let authenticateCalled = false;
    const response = await handleCoreHubRequest(post(action), {
      createAdminClient: () => ({}) as never,
      authenticateUser: () => {
        authenticateCalled = true;
        return Promise.resolve(null);
      },
      handleMemoReaction: (input) =>
        Promise.resolve({
          status: 200,
          payload: { routedAction: input.action },
        }),
      reportError: () => {},
    });

    assertEquals(response.status, 200);
    assertEquals(await response.json(), { routedAction: action });
    assertFalse(authenticateCalled);
  });
}

Deno.test("unknown actions return 400 before authentication", async () => {
  let authenticateCalled = false;
  const response = await handleCoreHubRequest(post("memo.react.unknown"), {
    createAdminClient: () => {
      throw new Error("admin client must not be created");
    },
    authenticateUser: () => {
      authenticateCalled = true;
      return Promise.resolve(null);
    },
    reportError: () => {},
  });

  assertEquals(response.status, 400);
  assertEquals(await response.json(), {
    error: "Unknown action: memo.react.unknown",
  });
  assertFalse(authenticateCalled);
});

Deno.test("unexpected route exceptions are sanitized", async () => {
  let reportedError: unknown;
  const response = await handleCoreHubRequest(post("memo.react.list"), {
    createAdminClient: () => ({}) as never,
    handleMemoReaction: () => {
      throw new Error("database password leaked in backend message");
    },
    reportError: (error) => {
      reportedError = error;
    },
  });

  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "Internal server error" });
  assertEquals(reportedError instanceof Error, true);
});

Deno.test("returned backend errors are sanitized", async () => {
  const response = await handleCoreHubRequest(post("memo.react.toggle"), {
    createAdminClient: () => ({}) as never,
    handleMemoReaction: () =>
      Promise.resolve({
        status: 500,
        payload: { error: "database password leaked in backend message" },
      }),
    reportError: () => {},
  });

  assertEquals(response.status, 500);
  assertEquals(await response.json(), { error: "Internal server error" });
});

Deno.test("user actions still require an authenticated user", async () => {
  const response = await handleCoreHubRequest(post("memo.share"), {
    authenticateUser: () => Promise.resolve(null),
    reportError: () => {},
  });
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "Unauthorized" });
});

Deno.test("service-role actions reject an anonymous bearer", async () => {
  const response = await handleCoreHubRequest(post("slack.notify"), {
    serviceRoleKey: "expected-service-role-key",
    reportError: () => {},
  });
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "Unauthorized" });
});

for (
  const [action, body] of [
    [
      "design.audit.upsert",
      { route: "/example", compliance: Array(7).fill(true) },
    ],
    [
      "design.rollout.upsert",
      {
        route: "/example",
        stage: "applied",
        figma_mcp: "applied",
        ai_designer: "applied",
        design_skills: "applied",
        design_md: "applied",
      },
    ],
  ] as const
) {
  Deno.test(`${action} accepts the registered service role`, async () => {
    const response = await handleCoreHubRequest(serviceRolePost(action, body), {
      createAdminClient: () =>
        ({
          from: () => ({
            upsert: () => Promise.resolve({ error: null }),
          }),
        }) as never,
      serviceRoleKey: "expected-service-role-key",
      reportError: () => {},
    });

    assertEquals(response.status, 200);
    assertEquals(await response.json(), { success: true });
  });
}

Deno.test("all protected actions enforce their registered auth policy", async (t) => {
  for (
    const [action, definition] of Object.entries(
      CORE_HUB_ACTION_REGISTRY,
    )
  ) {
    if (definition.auth === "anonymous") continue;

    await t.step(`${action} requires ${definition.auth}`, async () => {
      let authenticateCalled = false;
      const response = await handleCoreHubRequest(post(action), {
        createAdminClient: () => {
          throw new Error("admin client must not be created");
        },
        authenticateUser: () => {
          authenticateCalled = true;
          return Promise.resolve(null);
        },
        serviceRoleKey: "expected-service-role-key",
        reportError: () => {},
      });

      assertEquals(response.status, 401);
      assertEquals(await response.json(), { error: "Unauthorized" });
      assertEquals(authenticateCalled, definition.auth === "user");
    });
  }
});
