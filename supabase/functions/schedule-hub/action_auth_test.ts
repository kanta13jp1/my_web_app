import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  PUBLIC_ACTIONS,
  requiredAuthLevel,
  SERVICE_ROLE_ONLY_ACTIONS,
} from "./action_auth.ts";

Deno.test("書き込み系 4 action は service_role 必須", () => {
  for (
    const action of [
      "blog.auto_publish",
      "blog.create",
      "blog.backfill_from_apis",
      "x.post_with_media",
    ]
  ) {
    assertEquals(requiredAuthLevel(action), "service_role");
  }
});

Deno.test("read-only public action は public のまま", () => {
  for (
    const action of [
      "health.check",
      "blog.recent_posted",
      "maintenance.list_active",
      "digest.run",
    ]
  ) {
    assertEquals(requiredAuthLevel(action), "public");
  }
});

Deno.test("未知 / user 向け action は user JWT 必須", () => {
  assertEquals(requiredAuthLevel("billing.status"), "user");
  assertEquals(requiredAuthLevel("blog.list"), "user");
  assertEquals(requiredAuthLevel("blog.publish_post"), "user");
  assertEquals(requiredAuthLevel(""), "user");
  assertEquals(requiredAuthLevel("nonexistent.action"), "user");
});

Deno.test("service_role 集合と public 集合は重複しない", () => {
  for (const action of SERVICE_ROLE_ONLY_ACTIONS) {
    assertEquals(PUBLIC_ACTIONS.includes(action), false);
  }
});
