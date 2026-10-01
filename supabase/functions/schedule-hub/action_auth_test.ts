import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ACTION_POLICIES,
  actionPolicy,
  authorizeAction,
  PUBLIC_ACTIONS,
  requiredAuthLevel,
  SCHEDULE_HUB_ACTIONS,
  SERVICE_ROLE_ONLY_ACTIONS,
  type ScheduleHubAction,
} from "./action_auth.ts";

Deno.test("all 53 switch actions exactly match the policy registry", async () => {
  const indexSource = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  const switchActions = [...indexSource.matchAll(/^\s*case\s+"([^"]+)"\s*:/gm)]
    .map((match) => match[1]);

  assertEquals(switchActions.length, 53);
  assertEquals(new Set(switchActions).size, switchActions.length);
  assertEquals(new Set(SCHEDULE_HUB_ACTIONS).size, SCHEDULE_HUB_ACTIONS.length);
  assertEquals(
    [...switchActions].sort(),
    [...SCHEDULE_HUB_ACTIONS].sort(),
  );
});

Deno.test("anonymous, user, and service-role handler matrix is exhaustive", () => {
  for (const action of SCHEDULE_HUB_ACTIONS) {
    const policy = ACTION_POLICIES[action];
    const anonymous = authorizeAction(action, {
      authenticatedUser: false,
      serviceRoleRequest: false,
    });
    const user = authorizeAction(action, {
      authenticatedUser: true,
      serviceRoleRequest: false,
    });
    const serviceRole = authorizeAction(action, {
      authenticatedUser: false,
      serviceRoleRequest: true,
    });

    assertEquals(anonymous.allowed, policy.auth === "public", `${action}: anon`);
    assertEquals(user.allowed, policy.auth !== "service_role", `${action}: user`);
    assertEquals(serviceRole.allowed, true, `${action}: service role`);
  }
});

Deno.test("unknown and empty actions fail closed before authentication", () => {
  for (const action of ["", "nonexistent.action", "blog.publish.typo"]) {
    assertEquals(actionPolicy(action), null);
    assertEquals(requiredAuthLevel(action), null);
    assertEquals(
      authorizeAction(action, {
        authenticatedUser: false,
        serviceRoleRequest: false,
      }),
      { allowed: false, error: "UnknownAction", status: 400 },
    );
    assertEquals(
      authorizeAction(action, {
        authenticatedUser: true,
        serviceRoleRequest: false,
      }),
      { allowed: false, error: "UnknownAction", status: 400 },
    );
    assertEquals(
      authorizeAction(action, {
        authenticatedUser: false,
        serviceRoleRequest: true,
      }),
      { allowed: false, error: "UnknownAction", status: 400 },
    );
  }
});

Deno.test("owner credentials and shared system writes require service role", () => {
  for (const action of SCHEDULE_HUB_ACTIONS) {
    const policy = ACTION_POLICIES[action];
    if (
      policy.sideEffect === "owner_credential_read" ||
      policy.sideEffect === "owner_credential_write" ||
      policy.sideEffect === "system_write"
    ) {
      assertEquals(policy.auth, "service_role", action);
    }
  }
});

Deno.test("owner publish, update, delete, and Notion routes are protected", () => {
  const protectedActions: readonly ScheduleHubAction[] = [
    "x.post",
    "blog.publish",
    "blog.publish_post",
    "blog.update_post",
    "blog.delete_post",
    "blog.insert_post",
    "blog.news_signal_draft",
    "blog.qiita_list",
    "blog.qiita_comments",
    "blog.qiita_comment_post",
    "blog.qiita_likers",
    "blog.qiita_delete",
    "blog.qiita_update",
    "blog.devto_list",
    "blog.devto_sync_engagement",
    "blog.sync_engagement",
    "blog.devto_delete",
    "notion.sync_wiki_index",
  ];

  for (const action of protectedActions) {
    assertEquals(requiredAuthLevel(action), "service_role", action);
    assertEquals(SERVICE_ROLE_ONLY_ACTIONS.includes(action), true, action);
  }
});

Deno.test("public actions remain a narrow explicit allowlist", () => {
  assertEquals([...PUBLIC_ACTIONS].sort(), [
    "billing.create_supporter_checkout_session",
    "blog.recent_posted",
    "health.check",
    "maintenance.list_active",
  ]);
  assert(PUBLIC_ACTIONS.every((action) => actionPolicy(action) !== null));
});