// effort_router.ts — STUB (Win版#132 part 91 hotfix 第 7 弾)
//
// 真実装は PLATFORM #5 cross-instance-pr (Codex#2) 完了待ち:
//   docs/cross-instance-prs/done/20260429_task_budget_effort_router_codex2.md
//
// ai-hub が import しているが Codex#2 の実 file push 未済のため、
// deploy-prod の "Deploy Supabase Edge Functions" step で
//   WARN: failed to read file: open .../effort_router.ts: no such file
//   Error: failed to create the graph
// となり全 deploy ブロック中. 本 stub で hotfix.
//
// Stub 仕様: 常に "medium" effort を返す safe default.
// 完成版は 8-action マトリクス + workload heuristics で動的選択.

export type Effort = "low" | "medium" | "high" | "xhigh";

export interface EffortSelection {
  effort: Effort;
  source: string;
}

// deno-lint-ignore require-await
export async function selectEffort(
  _action: string,
  _body: unknown,
): Promise<EffortSelection> {
  return {
    effort: "medium",
    source: "stub_default",
  };
}
