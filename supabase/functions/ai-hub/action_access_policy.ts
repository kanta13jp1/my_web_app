export type AiHubActionAccess =
  | "public"
  | "authenticated"
  | "authenticated_or_service_role"
  | "service_role";

export type AiHubAuthorizationContext = {
  userId: string | null;
  isServiceRole: boolean;
};

export type AiHubAuthorizationDecision =
  | { allowed: true }
  | {
    allowed: false;
    status: 400 | 401 | 403;
    error: "Unauthorized" | "Forbidden" | "UnknownAction";
  };

// Anonymous access is limited to read-only content that never calls a paid
// external provider. Anything that spends an API key must not be listed here.
export const PUBLIC_AI_HUB_ACTIONS = new Set([
  "english_reading.list_lessons",
  "english_reading.get_lesson",
  "home.popular",
  "university.content",
  "university.content_all",
  "university.content_by_faculty",
  "university.department_list",
  "university.faculty_list",
  "university.provider_by_department",
  "university.leaderboard",
]);

export const AUTHENTICATED_AI_HUB_ACTIONS = new Set([
  "provider.models",
  "provider.embed",
  "provider.generate",
  "judgment.get",
  "judgment.get.legacy",
  "tags.suggest",
  "search.index_note",
  "provider.list",
  "election.analyze",
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
  "corporate_site.readiness",
  "company_builder.list",
  "company_builder.get",
  "company_builder.bootstrap",
  "company_builder.research.add",
  "company_builder.start",
  "company_builder.pause",
  "company_builder.resume",
  "company_builder.stop",
  "quiz.fsrs_next",
  "quiz.fsrs_grade",
  "quiz.fsrs_stats",
  "university.badges",
  "university.record_score",
  "university.streak",
  "university.streak_update",
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
  "palm_reading.analyze",
  "palm_reading.delete",
  "asset.chat",
  "ai_hub.asset_chat",
  "department_finance_summary",
  "ai_hub.department_finance_summary",
  "payslip.parse",
  "parse-payslip",
  "mario.jev_decide",
  "expense.jev_suggest",
  "expense.jev_search",
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

// Paid LLM gateways: callable by a signed-in user, or by other Edge Functions
// (lifestyle-hub / tools-hub / memory-search-hub / ai-hub internal worker)
// using the service-role key. Never anonymous.
export const AUTHENTICATED_OR_SERVICE_ROLE_AI_HUB_ACTIONS = new Set([
  "provider.chat",
  "provider.chat_auto",
  "edge_llm.invoke",
]);

export const SERVICE_ROLE_AI_HUB_ACTIONS = new Set([
  "observability.provider_health",
  "observability.heatmap",
  "observability.sessions",
  "observability.session_steps",
  "company_builder.worker",
  "company_builder.global_kill_switch",
  "asset.anomaly.scan_all",
  "asset_liability.verify_annual_rate_evidence",
  "university.upsert",
  "university.award_badge",
]);

export function aiHubActionAccess(action: string): AiHubActionAccess | null {
  if (SERVICE_ROLE_AI_HUB_ACTIONS.has(action)) return "service_role";
  if (AUTHENTICATED_OR_SERVICE_ROLE_AI_HUB_ACTIONS.has(action)) {
    return "authenticated_or_service_role";
  }
  if (AUTHENTICATED_AI_HUB_ACTIONS.has(action)) return "authenticated";
  if (PUBLIC_AI_HUB_ACTIONS.has(action)) return "public";
  return null;
}

export function authorizeAiHubAction(
  action: string,
  context: AiHubAuthorizationContext,
): AiHubAuthorizationDecision {
  const access = aiHubActionAccess(action);
  if (access === null) {
    // Fail-closed for any unregistered action. Anonymous callers get 401 so
    // the action registry is not probeable without credentials.
    if (!context.userId && !context.isServiceRole) {
      return { allowed: false, status: 401, error: "Unauthorized" };
    }
    return { allowed: false, status: 400, error: "UnknownAction" };
  }
  if (access === "public") return { allowed: true };
  if (access === "authenticated") {
    // Only the new server-managed provider endpoints accept a machine caller.
    // Existing authenticated actions retain their real-user identity boundary.
    const providerMachineCaller = context.isServiceRole &&
      (action === "provider.models" || action === "provider.generate" ||
        action === "provider.embed");
    return context.userId || providerMachineCaller
      ? { allowed: true }
      : { allowed: false, status: 401, error: "Unauthorized" };
  }
  if (access === "authenticated_or_service_role") {
    return context.userId || context.isServiceRole
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
