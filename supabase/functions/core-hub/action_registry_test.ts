import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  CORE_HUB_ACTION_REGISTRY,
  type CoreHubAuthPolicy,
} from "./action_registry.ts";

const EXPECTED_ACTIONS: Record<CoreHubAuthPolicy, string[]> = {
  anonymous: [
    "blog.public.list",
    "blog.public.view",
    "memo.public.list",
    "memo.public.related",
    "memo.public.search",
    "memo.public.view",
    "memo.react.list",
    "memo.react.toggle",
    "page.share_generate",
  ],
  service_role: [
    "design.audit.upsert",
    "design.rollout.upsert",
    "discord.notify",
    "notification.broadcast_release",
    "notify.feature_request",
    "slack.notify",
    "system.proactive_diagnostics",
  ],
  user: [
    "achievements.add",
    "achievements.list",
    "analytics.summary",
    "design.screens.list",
    "feature_request.analyze_attachment",
    "feature_request.existing_issues",
    "feature_request.list",
    "feature_request.submit",
    "feature_request.vote",
    "feedback.submit",
    "memo.ogp",
    "memo.react",
    "memo.share",
    "memo.share_list",
    "note.comment.add",
    "note.comment.delete",
    "note.comment.list",
    "notification.create",
    "notification.list",
    "notification.mark_all",
    "notification.mark_read",
    "notify.feature",
    "ogp.fetch",
    "onboarding.complete",
    "onboarding.get",
    "personal.dashboard",
    "system.status",
    "user.profile",
    "user.update",
  ],
};

Deno.test("all 45 dispatcher actions have one explicit auth policy", async () => {
  const actual: Record<CoreHubAuthPolicy, string[]> = {
    anonymous: [],
    service_role: [],
    user: [],
  };
  for (
    const [action, definition] of Object.entries(
      CORE_HUB_ACTION_REGISTRY,
    )
  ) {
    actual[definition.auth].push(action);
  }
  for (const actions of Object.values(actual)) actions.sort();

  assertEquals(actual, EXPECTED_ACTIONS);
  assertEquals(Object.keys(CORE_HUB_ACTION_REGISTRY).length, 45);

  const indexSource = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  const switchActions = Array.from(
    indexSource.matchAll(/^\s*case\s+"([^"]+)"/gm),
    (match) => match[1],
  ).sort();
  assertEquals(switchActions, Object.keys(CORE_HUB_ACTION_REGISTRY).sort());
});
