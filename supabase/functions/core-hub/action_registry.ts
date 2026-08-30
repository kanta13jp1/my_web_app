export type CoreHubAuthPolicy = "anonymous" | "user" | "service_role";

export interface CoreHubActionDefinition {
  auth: CoreHubAuthPolicy;
}

export const CORE_HUB_ACTION_REGISTRY = {
  "memo.share": { auth: "user" },
  "memo.share_list": { auth: "user" },
  "memo.react": { auth: "user" },
  "memo.react.list": { auth: "anonymous" },
  "memo.react.toggle": { auth: "anonymous" },
  "memo.ogp": { auth: "user" },
  "memo.public.view": { auth: "anonymous" },
  "memo.public.list": { auth: "anonymous" },
  "memo.public.search": { auth: "anonymous" },
  "memo.public.related": { auth: "anonymous" },
  "blog.public.view": { auth: "anonymous" },
  "blog.public.list": { auth: "anonymous" },
  "ogp.fetch": { auth: "user" },
  "note.comment.list": { auth: "user" },
  "note.comment.add": { auth: "user" },
  "note.comment.delete": { auth: "user" },
  "notification.list": { auth: "user" },
  "notification.create": { auth: "user" },
  "notification.mark_read": { auth: "user" },
  "notification.mark_all": { auth: "user" },
  "notification.broadcast_release": { auth: "service_role" },
  "slack.notify": { auth: "service_role" },
  "discord.notify": { auth: "service_role" },
  "user.profile": { auth: "user" },
  "user.update": { auth: "user" },
  "onboarding.get": { auth: "user" },
  "onboarding.complete": { auth: "user" },
  "feature_request.list": { auth: "user" },
  "feature_request.vote": { auth: "user" },
  "feature_request.analyze_attachment": { auth: "user" },
  "feature_request.existing_issues": { auth: "user" },
  "feature_request.submit": { auth: "user" },
  "feedback.submit": { auth: "user" },
  "notify.feature": { auth: "user" },
  "notify.feature_request": { auth: "service_role" },
  "personal.dashboard": { auth: "user" },
  "achievements.list": { auth: "user" },
  "achievements.add": { auth: "user" },
  "analytics.summary": { auth: "user" },
  "system.status": { auth: "user" },
  "system.proactive_diagnostics": { auth: "service_role" },
  "page.share_generate": { auth: "anonymous" },
  "design.screens.list": { auth: "user" },
  "design.audit.upsert": { auth: "service_role" },
  "design.rollout.upsert": { auth: "service_role" },
} as const satisfies Record<string, CoreHubActionDefinition>;

export type CoreHubAction = keyof typeof CORE_HUB_ACTION_REGISTRY;

export function coreHubActionDefinition(
  action: string,
): CoreHubActionDefinition | null {
  if (!Object.hasOwn(CORE_HUB_ACTION_REGISTRY, action)) return null;
  return CORE_HUB_ACTION_REGISTRY[action as CoreHubAction];
}

export function isCoreHubAction(action: string): action is CoreHubAction {
  return coreHubActionDefinition(action) !== null;
}
