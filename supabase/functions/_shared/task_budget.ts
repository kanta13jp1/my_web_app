import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

export type BudgetScope = "ef" | "gha" | "instance" | "month";

export interface TaskBudget {
  scope: BudgetScope;
  scope_id: string;
  limit_usd: number;
  spent_usd: number;
  reset_at: string;
}

export interface BudgetCheckResult {
  ok: boolean;
  remaining_usd: number;
  checked_scopes: TaskBudget[];
  exceeded_scope?: BudgetScope;
  exceeded_scope_id?: string;
  warning?: string;
}

type BudgetRow = {
  scope: BudgetScope;
  scope_id: string;
  limit_usd: number | string;
  spent_usd: number | string;
  reset_at: string;
};

type ModelPrice = {
  input_usd_per_million: number;
  output_usd_per_million: number;
};

const DEFAULT_LIMITS_USD: Record<BudgetScope, number> = {
  month: 5000,
  instance: 400,
  ef: 50,
  gha: 20,
};

const MODEL_PRICE_TABLE: Record<string, ModelPrice> = {
  "gpt-4o-mini": { input_usd_per_million: 0.15, output_usd_per_million: 0.60 },
  "gpt-4o": { input_usd_per_million: 2.50, output_usd_per_million: 10.00 },
  "gpt-5.4-mini": { input_usd_per_million: 0.15, output_usd_per_million: 0.60 },
  "gpt-5.4": { input_usd_per_million: 2.50, output_usd_per_million: 10.00 },
  "claude-haiku-4-5": {
    input_usd_per_million: 1.00,
    output_usd_per_million: 5.00,
  },
  "claude-sonnet-5": {
    input_usd_per_million: 2.00,
    output_usd_per_million: 10.00,
  },
  "claude-sonnet-4-6": {
    input_usd_per_million: 3.00,
    output_usd_per_million: 15.00,
  },
  "claude-opus-4-7": {
    input_usd_per_million: 15.00,
    output_usd_per_million: 75.00,
  },
  "gemini": { input_usd_per_million: 0.35, output_usd_per_million: 1.05 },
  "groq": { input_usd_per_million: 0.05, output_usd_per_million: 0.20 },
  "deepseek": { input_usd_per_million: 0.14, output_usd_per_million: 0.28 },
};

let cachedClient: SupabaseClient | null = null;

function adminClient(): SupabaseClient {
  if (cachedClient) return cachedClient;

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !serviceRoleKey) {
    throw new Error("SUPABASE_URL and SERVICE_ROLE_KEY are required");
  }

  cachedClient = createClient(url, serviceRoleKey);
  return cachedClient;
}

function toUsd(value: number | string): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function normalizeRow(row: BudgetRow): TaskBudget {
  return {
    scope: row.scope,
    scope_id: row.scope_id,
    limit_usd: toUsd(row.limit_usd),
    spent_usd: toUsd(row.spent_usd),
    reset_at: row.reset_at,
  };
}

function currentMonthScopeId(now = new Date()): string {
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

function nextMonthResetIso(now = new Date()): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1))
    .toISOString();
}

function configuredInstanceId(): string | null {
  const value = Deno.env.get("TASK_BUDGET_INSTANCE_ID") ??
    Deno.env.get("INSTANCE_ID") ?? "";
  return value.trim() || null;
}

function budgetChain(
  scope: BudgetScope,
  scopeId: string,
): Array<[BudgetScope, string]> {
  const chain: Array<[BudgetScope, string]> = [
    ["month", currentMonthScopeId()],
  ];
  const instanceId = configuredInstanceId();
  if (instanceId && scope !== "month") {
    chain.push(["instance", instanceId]);
  }
  if (scope !== "month" && scope !== "instance") {
    chain.push([scope, scopeId]);
  } else if (scope === "instance") {
    chain.push([scope, scopeId]);
  }

  const seen = new Set<string>();
  return chain.filter(([chainScope, chainScopeId]) => {
    const key = `${chainScope}:${chainScopeId}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

async function fetchBudget(
  client: SupabaseClient,
  scope: BudgetScope,
  scopeId: string,
): Promise<TaskBudget> {
  const { data, error } = await client
    .from("task_budget")
    .select("scope, scope_id, limit_usd, spent_usd, reset_at")
    .eq("scope", scope)
    .eq("scope_id", scopeId)
    .maybeSingle();

  if (error) throw error;
  if (data) return normalizeRow(data as BudgetRow);

  const inserted = {
    scope,
    scope_id: scopeId,
    limit_usd: DEFAULT_LIMITS_USD[scope],
    spent_usd: 0,
    reset_at: scope === "month" ? nextMonthResetIso() : nextMonthResetIso(),
  };
  const { data: created, error: createError } = await client
    .from("task_budget")
    .upsert(inserted, { onConflict: "scope,scope_id" })
    .select("scope, scope_id, limit_usd, spent_usd, reset_at")
    .single();
  if (createError) throw createError;
  return normalizeRow(created as BudgetRow);
}

async function resetExpiredBudget(
  client: SupabaseClient,
  budget: TaskBudget,
): Promise<TaskBudget> {
  if (new Date(budget.reset_at).getTime() > Date.now()) {
    return budget;
  }

  const resetAt = nextMonthResetIso();
  const { data, error } = await client
    .from("task_budget")
    .update({
      spent_usd: 0,
      reset_at: resetAt,
      updated_at: new Date().toISOString(),
    })
    .eq("scope", budget.scope)
    .eq("scope_id", budget.scope_id)
    .select("scope, scope_id, limit_usd, spent_usd, reset_at")
    .single();
  if (error) throw error;
  return normalizeRow(data as BudgetRow);
}

export async function checkBudget(
  scope: BudgetScope,
  scope_id: string,
): Promise<BudgetCheckResult> {
  try {
    const client = adminClient();
    const checkedScopes: TaskBudget[] = [];
    let remainingUsd = Number.POSITIVE_INFINITY;

    for (const [chainScope, chainScopeId] of budgetChain(scope, scope_id)) {
      const budget = await resetExpiredBudget(
        client,
        await fetchBudget(client, chainScope, chainScopeId),
      );
      checkedScopes.push(budget);

      const remaining = budget.limit_usd - budget.spent_usd;
      remainingUsd = Math.min(remainingUsd, remaining);
      if (remaining <= 0) {
        return {
          ok: false,
          remaining_usd: remaining,
          checked_scopes: checkedScopes,
          exceeded_scope: budget.scope,
          exceeded_scope_id: budget.scope_id,
        };
      }
    }

    return {
      ok: true,
      remaining_usd: Number.isFinite(remainingUsd) ? remainingUsd : 0,
      checked_scopes: checkedScopes,
    };
  } catch (error) {
    return {
      ok: true,
      remaining_usd: Number.POSITIVE_INFINITY,
      checked_scopes: [],
      warning: `budget check skipped: ${String(error)}`,
    };
  }
}

export async function recordSpend(
  scope: BudgetScope,
  scope_id: string,
  amount_usd: number,
): Promise<void> {
  if (!Number.isFinite(amount_usd) || amount_usd <= 0) return;

  const client = adminClient();
  for (const [chainScope, chainScopeId] of budgetChain(scope, scope_id)) {
    const { error } = await client.rpc("record_task_budget_spend", {
      p_scope: chainScope,
      p_scope_id: chainScopeId,
      p_amount_usd: Number(amount_usd.toFixed(8)),
    });
    if (!error) continue;

    const current = await fetchBudget(client, chainScope, chainScopeId);
    await client
      .from("task_budget")
      .update({
        spent_usd: Number((current.spent_usd + amount_usd).toFixed(8)),
        updated_at: new Date().toISOString(),
      })
      .eq("scope", chainScope)
      .eq("scope_id", chainScopeId);
  }
}

export async function resetBudget(
  scope: BudgetScope,
  scope_id: string,
): Promise<void> {
  const client = adminClient();
  const { error } = await client
    .from("task_budget")
    .update({
      spent_usd: 0,
      reset_at: nextMonthResetIso(),
      updated_at: new Date().toISOString(),
    })
    .eq("scope", scope)
    .eq("scope_id", scope_id);
  if (error) throw error;
}

function selectModelPrice(model: string): ModelPrice {
  const normalized = model.trim().toLowerCase();
  for (const [key, value] of Object.entries(MODEL_PRICE_TABLE)) {
    if (normalized.includes(key)) return value;
  }
  return { input_usd_per_million: 1.00, output_usd_per_million: 3.00 };
}

function normalizeTokenCount(value: number): number {
  return Number.isFinite(value) && value > 0 ? value : 0;
}

export function calculateApiCost(
  model: string,
  input_tokens: number,
  output_tokens: number,
): number {
  const price = selectModelPrice(model);
  const inputCost = (normalizeTokenCount(input_tokens) / 1_000_000) *
    price.input_usd_per_million;
  const outputCost = (normalizeTokenCount(output_tokens) / 1_000_000) *
    price.output_usd_per_million;
  return Number((inputCost + outputCost).toFixed(8));
}
