export type AiHubActionAccess = "public" | "authenticated" | "service_role";

export type AiHubAuthorizationContext = {
  userId: string | null;
  isServiceRole: boolean;
};

export type AiHubAuthorizationDecision =
  | { allowed: true }
  | {
    allowed: false;
    status: 401 | 403;
    error: "Unauthorized" | "Forbidden";
  };

export const AUTHENTICATED_AI_HUB_ACTIONS = new Set([
  "search.query",
  "task.clarity.evaluate",
  "secretary.task",
  "secretary.history",
  "summarize.text",
  "agent.list",
  "agent.create",
  "agent.run",
  "agent.tool_policy.evaluate",
  "org.get",
  "my_agent.chat",
  "my_agent.history",
  "challenges.list",
  "trigger.analyze",
  "analyze.reality",
  "company_builder.list",
  "company_builder.get",
  "company_builder.bootstrap",
  "company_builder.research.add",
  "company_builder.start",
  "company_builder.pause",
  "company_builder.resume",
  "company_builder.stop",
  "company_builder.global_kill_switch",
  "quiz.fsrs_next",
  "quiz.fsrs_grade",
  "quiz.fsrs_stats",
  "university.rlhf_signal",
  "university.rlhf_snapshot",
  "user_data.finetune_readiness",
  "learner.update_profile",
  "quiz.evaluate",
  "quiz.explain",
  "kpi.monthly_summary",
  "asset.market_price.fetch",
  "asset.investment.market_price.fetch",
  "ai_hub.fetch_market_price",
  "asset.monthly_report.generate",
  "asset_liability.monthly_report.generate",
  "asset_subscription.analyze_statement",
  "asset.chat",
  "ai_hub.asset_chat",
  "department_finance_summary",
  "ai_hub.department_finance_summary",
  "payslip.parse",
  "parse-payslip",
  "expense.classify",
  "classify-expense",
  "expense.weekly_coaching.generate",
  "asset.disposable_balance.compute",
  "compute-disposable-balance",
  "asset.anomaly.detect",
  "detect-anomalies",
  "knowledge_graph.status",
  "knowledge_graph.upload",
  "knowledge_graph.query",
  "knowledge_graph.delete_document",
  "voice.tts",
  "voice.catalog",
  "voice.usage",
  "voice.dubbing.generate",
  "voice.stt",
  "voice.cartesia_session.start",
  "voice.cartesia_session.finish",
  "english_reading.submit_attempt",
  "english_reading.ability",
  "english_reading.generate_lesson",
  "home.recommend",
]);

export const SERVICE_ROLE_AI_HUB_ACTIONS = new Set([
  "observability.provider_health",
  "observability.heatmap",
  "observability.sessions",
  "observability.session_steps",
]);

export function aiHubActionAccess(action: string): AiHubActionAccess {
  if (SERVICE_ROLE_AI_HUB_ACTIONS.has(action)) return "service_role";
  if (AUTHENTICATED_AI_HUB_ACTIONS.has(action)) return "authenticated";
  return "public";
}

export function authorizeAiHubAction(
  action: string,
  context: AiHubAuthorizationContext,
): AiHubAuthorizationDecision {
  const access = aiHubActionAccess(action);
  if (access === "public") return { allowed: true };
  if (access === "authenticated") {
    return context.userId
      ? { allowed: true }
      : { allowed: false, status: 401, error: "Unauthorized" };
  }
  if (context.isServiceRole) return { allowed: true };
  return context.userId
    ? { allowed: false, status: 403, error: "Forbidden" }
    : { allowed: false, status: 401, error: "Unauthorized" };
}

export function resolveAuthenticatedUserId(
  authenticatedUserId: string,
  requestedUserId: unknown,
): { userId: string } | { status: 403; error: "Forbidden" } {
  const requested = typeof requestedUserId === "string"
    ? requestedUserId.trim()
    : "";
  if (requested && requested !== authenticatedUserId) {
    return { status: 403, error: "Forbidden" };
  }
  return { userId: authenticatedUserId };
}
