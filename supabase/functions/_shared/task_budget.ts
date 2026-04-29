// task_budget.ts — STUB (Win版#132 part 91 hotfix 第 7 弾)
//
// 真実装は PLATFORM #6 cross-instance-pr (Codex#2) 完了待ち:
//   docs/cross-instance-prs/done/20260429_task_budget_effort_router_codex2.md
//
// ai-hub が import しているが Codex#2 の実 file push 未済のため、
// deploy-prod の "Deploy Supabase Edge Functions" step で
//   WARN: failed to read file: open .../task_budget.ts: no such file
//   Error: failed to create the graph
// となり全 deploy ブロック中. 本 stub で hotfix.
//
// Stub 仕様: budget 制限なし (= 常に ok / remaining_usd: 999999) + cost 0 計算.
// 完成版は month/instance/ef/gha 4 階層 budget + 実 spend tracking.

export type BudgetScope = "month" | "instance" | "ef" | "gha";

export interface BudgetCheckResult {
  ok: boolean;
  remaining_usd: number;
  exceeded_scope?: BudgetScope | null;
  exceeded_scope_id?: string | null;
}

// deno-lint-ignore require-await
export async function checkBudget(
  _scope: BudgetScope,
  _key: string,
): Promise<BudgetCheckResult> {
  return {
    ok: true,
    remaining_usd: 999999,
    exceeded_scope: null,
    exceeded_scope_id: null,
  };
}

export async function recordSpend(
  _scope: BudgetScope,
  _key: string,
  _costUsd: number,
): Promise<void> {
  // no-op stub
  await Promise.resolve();
}

export function calculateApiCost(
  _modelOrProvider: string,
  _inputTokens: number,
  _outputTokens: number,
): number {
  // stub: cost 計算なし
  return 0;
}
