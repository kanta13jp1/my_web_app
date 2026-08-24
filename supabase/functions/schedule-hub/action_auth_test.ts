import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  PUBLIC_ACTIONS,
  requiredAuthLevel,
  SERVICE_ROLE_ONLY_ACTIONS,
} from "./action_auth.ts";

Deno.test("Stripe account readiness is service-role only", () => {
  assertEquals(
    requiredAuthLevel("billing.get_stripe_account_readiness"),
    "service_role",
  );
});

Deno.test("blog/x 書き込み系 4 action は service_role 必須", () => {
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

Deno.test("notion/wbs/reminders 書き込み系 7 action は service_role 必須", () => {
  for (
    const action of [
      "notion.sync_wbs",
      "notion.preflight_wbs",
      "notion.sync_roadmap",
      "notion.sync_memory_index",
      "notion.fix_wbs_all_instances",
      "wbs.unblock_dependents",
      "reminders.study",
    ]
  ) {
    assertEquals(requiredAuthLevel(action), "service_role");
  }
});

Deno.test("read-only public action + 非ログイン支援者導線は public のまま", () => {
  for (
    const action of [
      "health.check",
      "blog.recent_posted",
      "maintenance.list_active",
      "billing.create_supporter_checkout_session",
    ]
  ) {
    assertEquals(requiredAuthLevel(action), "public");
  }
});

Deno.test("digest.run は user レベルへ降格 (public から削除)", () => {
  assertEquals(requiredAuthLevel("digest.run"), "user");
  assertEquals(PUBLIC_ACTIONS.includes("digest.run"), false);
  assertEquals(SERVICE_ROLE_ONLY_ACTIONS.includes("digest.run"), false);
});

Deno.test("動画クレジット購入はログイン user JWT 必須", () => {
  const action = "billing.create_video_credit_checkout_session";
  assertEquals(requiredAuthLevel(action), "user");
  assertEquals(PUBLIC_ACTIONS.includes(action), false);
  assertEquals(SERVICE_ROLE_ONLY_ACTIONS.includes(action), false);
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
