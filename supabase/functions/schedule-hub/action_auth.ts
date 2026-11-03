// schedule-hub action authorization contract.
// Every switch action must be listed here with both its caller boundary and
// side-effect class. Unknown actions are rejected before a service client is
// created; adding a handler without adding a policy is therefore fail-closed.

export type ActionAuthLevel = "public" | "service_role" | "user";

export type ActionSideEffect =
  | "read_only"
  | "user_scoped_write"
  | "payment_write"
  | "owner_credential_read"
  | "owner_credential_write"
  | "system_write"
  | "disabled";

export interface ActionPolicy {
  auth: ActionAuthLevel;
  sideEffect: ActionSideEffect;
}

export const ACTION_POLICIES = {
  "billing.get_stripe_account_readiness": {
    auth: "service_role",
    sideEffect: "owner_credential_read",
  },
  "billing.status": { auth: "user", sideEffect: "read_only" },
  "billing.create_checkout_session": {
    auth: "user",
    sideEffect: "payment_write",
  },
  "billing.create_supporter_checkout_session": {
    auth: "public",
    sideEffect: "payment_write",
  },
  "billing.create_video_credit_checkout_session": {
    auth: "user",
    sideEffect: "payment_write",
  },
  "billing.create_portal_session": {
    auth: "user",
    sideEffect: "payment_write",
  },
  "maintenance.list_active": { auth: "public", sideEffect: "read_only" },
  "maintenance.list": { auth: "user", sideEffect: "read_only" },
  "maintenance.create": { auth: "user", sideEffect: "user_scoped_write" },
  "maintenance.update": { auth: "user", sideEffect: "user_scoped_write" },
  "maintenance.delete": { auth: "user", sideEffect: "user_scoped_write" },
  "digest.run": { auth: "user", sideEffect: "read_only" },
  "digest.daily_summary": { auth: "user", sideEffect: "read_only" },
  "manager.list": { auth: "user", sideEffect: "read_only" },
  "manager.create": { auth: "user", sideEffect: "user_scoped_write" },
  "manager.update": { auth: "user", sideEffect: "user_scoped_write" },
  "manager.delete": { auth: "user", sideEffect: "user_scoped_write" },
  "x.post": { auth: "service_role", sideEffect: "owner_credential_write" },
  "x.history": { auth: "user", sideEffect: "read_only" },
  "x.post_with_media": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.list": { auth: "user", sideEffect: "read_only" },
  "blog.create": { auth: "service_role", sideEffect: "system_write" },
  "blog.publish": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.delete": { auth: "user", sideEffect: "user_scoped_write" },
  "blog.auto_publish": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.publish_post": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.update_post": { auth: "service_role", sideEffect: "system_write" },
  "blog.delete_post": { auth: "service_role", sideEffect: "system_write" },
  "blog.insert_post": { auth: "service_role", sideEffect: "system_write" },
  "blog.news_signal_draft": {
    auth: "service_role",
    sideEffect: "system_write",
  },
  "blog.news_signal_lint": { auth: "user", sideEffect: "read_only" },
  "blog.backfill_from_apis": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.recent_posted": { auth: "public", sideEffect: "read_only" },
  "blog.qiita_list": {
    auth: "service_role",
    sideEffect: "owner_credential_read",
  },
  "blog.qiita_comments": {
    auth: "service_role",
    sideEffect: "owner_credential_read",
  },
  "blog.qiita_comment_post": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.qiita_likers": {
    auth: "service_role",
    sideEffect: "owner_credential_read",
  },
  "blog.qiita_follow": { auth: "user", sideEffect: "disabled" },
  "blog.qiita_delete": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.qiita_update": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.devto_list": {
    auth: "service_role",
    sideEffect: "owner_credential_read",
  },
  "blog.devto_sync_engagement": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.sync_engagement": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "blog.devto_delete": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "reminders.study": { auth: "service_role", sideEffect: "system_write" },
  "health.check": { auth: "public", sideEffect: "read_only" },
  "notion.preflight_wbs": {
    auth: "service_role",
    sideEffect: "owner_credential_read",
  },
  "notion.sync_wbs": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "notion.sync_roadmap": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "notion.sync_memory_index": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "notion.sync_wiki_index": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "notion.fix_wbs_all_instances": {
    auth: "service_role",
    sideEffect: "owner_credential_write",
  },
  "wbs.unblock_dependents": {
    auth: "service_role",
    sideEffect: "system_write",
  },
} as const satisfies Record<string, ActionPolicy>;

export type ScheduleHubAction = keyof typeof ACTION_POLICIES;

export const SCHEDULE_HUB_ACTIONS = Object.freeze(
  Object.keys(ACTION_POLICIES) as ScheduleHubAction[],
);

export const PUBLIC_ACTIONS: readonly string[] = Object.freeze(
  SCHEDULE_HUB_ACTIONS.filter(
    (action) => ACTION_POLICIES[action].auth === "public",
  ),
);

export const SERVICE_ROLE_ONLY_ACTIONS: readonly string[] = Object.freeze(
  SCHEDULE_HUB_ACTIONS.filter(
    (action) => ACTION_POLICIES[action].auth === "service_role",
  ),
);

export function actionPolicy(action: string): ActionPolicy | null {
  if (!Object.prototype.hasOwnProperty.call(ACTION_POLICIES, action)) {
    return null;
  }
  return ACTION_POLICIES[action as ScheduleHubAction];
}

export function requiredAuthLevel(action: string): ActionAuthLevel | null {
  return actionPolicy(action)?.auth ?? null;
}

export interface ActionAuthorizationContext {
  authenticatedUser: boolean;
  serviceRoleRequest: boolean;
}

export type ActionAuthorizationDecision =
  | { allowed: true; policy: ActionPolicy }
  | { allowed: false; error: "Unauthorized"; status: 401 }
  | { allowed: false; error: "UnknownAction"; status: 400 };

export function authorizeAction(
  action: string,
  context: ActionAuthorizationContext,
): ActionAuthorizationDecision {
  const policy = actionPolicy(action);
  if (!policy) {
    return { allowed: false, error: "UnknownAction", status: 400 };
  }

  const allowed = context.serviceRoleRequest ||
    policy.auth === "public" ||
    (policy.auth === "user" && context.authenticatedUser);
  if (!allowed) {
    return { allowed: false, error: "Unauthorized", status: 401 };
  }
  return { allowed: true, policy };
}