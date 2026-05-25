type UnknownRecord = Record<string, unknown>;

export type DisposableBalanceProviderRequest = {
  provider: string;
  model?: string;
  messages: { role: string; content: string }[];
};

export type DisposableBalanceProviderResult = {
  ok: boolean;
  text?: string;
  modelUsed?: string;
  error?: string;
  isRetriable?: boolean;
};

export type DisposableBalanceProviderInvoker = (
  request: DisposableBalanceProviderRequest,
) => Promise<DisposableBalanceProviderResult>;

type ListResult = {
  data?: unknown[] | null;
  error?: { message?: string } | null;
};

type SingleResult = {
  data?: unknown | null;
  error?: { message?: string } | null;
};

export type DisposableBalanceDbQuery = {
  select(columns?: string): DisposableBalanceDbQuery;
  eq(column: string, value: string): DisposableBalanceDbQuery;
  lte(column: string, value: string): DisposableBalanceDbQuery;
  order(
    column: string,
    options?: { ascending?: boolean },
  ): DisposableBalanceDbQuery;
  limit(count: number): Promise<ListResult>;
  upsert(
    value: UnknownRecord,
    options?: { onConflict?: string },
  ): {
    select(columns?: string): {
      single(): Promise<SingleResult>;
    };
  };
  insert(value: UnknownRecord): Promise<SingleResult>;
};

export type DisposableBalanceDb = {
  from(table: string): DisposableBalanceDbQuery;
};

export type DisposableBalanceAction = {
  action_key: string;
  priority: number;
  title: string;
  instruction: string;
  estimated_seconds: number;
  amount_impact: number;
  category: string;
};

export type DisposableBalanceResult = {
  status: "deterministic" | "ai_actions_generated";
  as_of_date: string;
  next_payday: string;
  days_remaining: number;
  salary_day: number;
  income: number;
  fixed_total: number;
  debt_total: number;
  disposable: number;
  daily_pace: number;
  breakdown: UnknownRecord[];
  required_actions: DisposableBalanceAction[];
  provider: string | null;
  model: string | null;
  warnings: string[];
};

type PayslipRow = {
  pay_date: string;
  net_amount: number;
  company_name: string;
  confidence: number;
};

type RecurringExpenseRow = {
  name: string;
  amount: number;
  day_of_month: number;
  category: string;
  paused_at: string | null;
};

type DebtRow = {
  name: string;
  principal: number;
  monthly_payment: number;
  interest_rate: number;
  lender: string;
  last_updated: string | null;
  paused_at: string | null;
};

export class DisposableBalanceError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "DisposableBalanceError";
    this.status = status;
  }
}

export function isDisposableBalanceAction(action: string): boolean {
  return action === "asset.disposable_balance.compute" ||
    action === "compute-disposable-balance";
}

export function nextPaydayFor(asOfDate: string, salaryDay = 25): string {
  const asOf = parseDate(asOfDate);
  const safeSalaryDay = clampDay(salaryDay);
  const currentMonthPayday = dateUtc(
    asOf.getUTCFullYear(),
    asOf.getUTCMonth() + 1,
    safeSalaryDay,
  );
  const next = asOf.getTime() < currentMonthPayday.getTime()
    ? currentMonthPayday
    : dateUtc(asOf.getUTCFullYear(), asOf.getUTCMonth() + 2, safeSalaryDay);
  return toDateString(next);
}

export function salaryCycleStartFor(asOfDate: string, salaryDay = 25): string {
  const next = parseDate(nextPaydayFor(asOfDate, salaryDay));
  return toDateString(
    dateUtc(next.getUTCFullYear(), next.getUTCMonth(), clampDay(salaryDay)),
  );
}

export function buildDisposableBalance(params: {
  asOfDate: string;
  salaryDay: number;
  payslips: PayslipRow[];
  recurringExpenses: RecurringExpenseRow[];
  debts: DebtRow[];
}): Omit<
  DisposableBalanceResult,
  "status" | "provider" | "model" | "warnings"
> {
  const salaryDay = clampDay(params.salaryDay);
  const asOf = parseDate(params.asOfDate);
  const asOfDate = toDateString(asOf);
  const nextPayday = nextPaydayFor(asOfDate, salaryDay);
  const cycleStart = salaryCycleStartFor(asOfDate, salaryDay);
  const daysRemaining = Math.max(
    1,
    Math.ceil(
      (parseDate(nextPayday).getTime() - asOf.getTime()) / 86400000,
    ) - 1,
  );

  const currentPayslip = params.payslips
    .filter((row) => row.pay_date >= cycleStart && row.pay_date < nextPayday)
    .sort((a, b) => b.pay_date.localeCompare(a.pay_date))[0] ?? null;
  const fallbackPayslip = params.payslips
    .slice()
    .sort((a, b) => b.pay_date.localeCompare(a.pay_date))[0] ?? null;
  const income = Math.round(
    (currentPayslip ?? fallbackPayslip)?.net_amount ?? 0,
  );
  const activeRecurring = params.recurringExpenses.filter((row) =>
    !row.paused_at
  );
  const activeDebts = params.debts.filter((row) => !row.paused_at);
  const fixedTotal = Math.round(
    activeRecurring.reduce((sum, row) => sum + Math.max(0, row.amount), 0),
  );
  const debtTotal = Math.round(
    activeDebts.reduce((sum, row) => sum + Math.max(0, row.monthly_payment), 0),
  );
  const disposable = income - fixedTotal - debtTotal;
  const dailyPace = Math.round(disposable / daysRemaining);
  const requiredActions = buildRequiredActions({
    asOfDate,
    cycleStart,
    currentPayslip,
    fallbackPayslip,
    recurringExpenses: activeRecurring,
    debts: activeDebts,
  });

  return {
    as_of_date: asOfDate,
    next_payday: nextPayday,
    days_remaining: daysRemaining,
    salary_day: salaryDay,
    income,
    fixed_total: fixedTotal,
    debt_total: debtTotal,
    disposable,
    daily_pace: dailyPace,
    breakdown: [
      { label: "income", amount: income, source: "payslips.net_amount" },
      {
        label: "fixed_expenses",
        amount: -fixedTotal,
        count: activeRecurring.length,
      },
      { label: "debt_payments", amount: -debtTotal, count: activeDebts.length },
    ],
    required_actions: requiredActions,
  };
}

export async function handleDisposableBalanceAction(options: {
  db: DisposableBalanceDb;
  body: UnknownRecord;
  userId: string;
  invokeProvider?: DisposableBalanceProviderInvoker;
}): Promise<DisposableBalanceResult> {
  const asOfDate = normalizeDate(
    options.body.as_of_date ?? options.body.asOfDate,
    new Date(),
  );
  const salaryDay = clampDay(readNumber(options.body.salary_day, 25));
  const traceId = readString(options.body.trace_id) || crypto.randomUUID();
  const warnings: string[] = [];

  try {
    const [payslips, recurringExpenses, debts] = await Promise.all([
      loadPayslips(options.db, options.userId, asOfDate),
      loadRecurringExpenses(options.db, options.userId),
      loadDebts(options.db, options.userId),
    ]);
    const base = buildDisposableBalance({
      asOfDate,
      salaryDay,
      payslips,
      recurringExpenses,
      debts,
    });
    let requiredActions = base.required_actions;
    let status: DisposableBalanceResult["status"] = "deterministic";
    let provider: string | null = null;
    let model: string | null = null;

    const aiEnabled = options.body.enable_ai_actions === true ||
      Deno.env.get("DISPOSABLE_BALANCE_AI_ENABLED") === "true";
    if (aiEnabled && options.invokeProvider) {
      const providerResult = await options.invokeProvider({
        provider: "google",
        model: readString(options.body.model) || "gemini-2.5-pro",
        messages: buildDisposableBalanceMessages(base),
      });
      if (providerResult.ok && providerResult.text) {
        const providerActions = parseProviderActions(providerResult.text);
        if (providerActions.length > 0) {
          requiredActions = mergeActions(requiredActions, providerActions);
          status = "ai_actions_generated";
          provider = "google";
          model = providerResult.modelUsed ?? "gemini-2.5-pro";
        }
      } else {
        warnings.push(
          `AI actions skipped: ${providerResult.error ?? "empty response"}`,
        );
      }
    }

    const result: DisposableBalanceResult = {
      status,
      ...base,
      required_actions: requiredActions,
      provider,
      model,
      warnings,
    };

    if (options.body.dry_run !== true) {
      const { error } = await options.db.from("disposable_balance_runs")
        .upsert({
          user_id: options.userId,
          as_of_date: result.as_of_date,
          next_payday: result.next_payday,
          days_remaining: result.days_remaining,
          income: result.income,
          fixed_total: result.fixed_total,
          debt_total: result.debt_total,
          disposable: result.disposable,
          daily_pace: result.daily_pace,
          breakdown: result.breakdown,
          required_actions: result.required_actions,
          provider: result.provider,
          model: result.model,
          status: result.status,
          trace_id: traceId,
        }, { onConflict: "user_id,as_of_date" })
        .select("id")
        .single();
      if (error) {
        throw new DisposableBalanceError(
          `disposable_balance_runs upsert failed: ${
            error.message ?? "unknown"
          }`,
          500,
        );
      }
    }
    return result;
  } catch (error) {
    if (options.body.dry_run !== true) {
      await options.db.from("disposable_balance_failures").insert({
        user_id: options.userId,
        as_of_date: asOfDate,
        trace_id: traceId,
        error_message: error instanceof Error ? error.message : String(error),
        recovery_plan:
          "Retry after confirming payslips, recurring_expenses, and debts tables are migrated.",
      });
    }
    throw error;
  }
}

async function loadPayslips(
  db: DisposableBalanceDb,
  userId: string,
  asOfDate: string,
): Promise<PayslipRow[]> {
  const { data, error } = await db.from("payslips")
    .select("pay_date,net_amount,company_name,confidence")
    .eq("user_id", userId)
    .lte("pay_date", asOfDate)
    .order("pay_date", { ascending: false })
    .limit(6);
  if (error) {
    throw new DisposableBalanceError(
      `payslips load failed: ${error.message ?? "unknown"}`,
      500,
    );
  }
  return (data ?? []).map((row) => {
    const record = asRecord(row) ?? {};
    return {
      pay_date: readString(record.pay_date),
      net_amount: readNumber(record.net_amount, 0),
      company_name: readString(record.company_name),
      confidence: readNumber(record.confidence, 0),
    };
  }).filter((row) => row.pay_date !== "");
}

async function loadRecurringExpenses(
  db: DisposableBalanceDb,
  userId: string,
): Promise<RecurringExpenseRow[]> {
  const { data, error } = await db.from("recurring_expenses")
    .select("name,amount,day_of_month,category,paused_at")
    .eq("user_id", userId)
    .order("day_of_month", { ascending: true })
    .limit(200);
  if (error) {
    throw new DisposableBalanceError(
      `recurring_expenses load failed: ${error.message ?? "unknown"}`,
      500,
    );
  }
  return (data ?? []).map((row) => {
    const record = asRecord(row) ?? {};
    return {
      name: readString(record.name),
      amount: readNumber(record.amount, 0),
      day_of_month: clampDay(readNumber(record.day_of_month, 1)),
      category: readString(record.category) || "fixed",
      paused_at: readString(record.paused_at) || null,
    };
  }).filter((row) => row.name !== "");
}

async function loadDebts(
  db: DisposableBalanceDb,
  userId: string,
): Promise<DebtRow[]> {
  const { data, error } = await db.from("debts")
    .select(
      "name,principal,monthly_payment,interest_rate,lender,last_updated,paused_at",
    )
    .eq("user_id", userId)
    .order("last_updated", { ascending: true })
    .limit(200);
  if (error) {
    throw new DisposableBalanceError(
      `debts load failed: ${error.message ?? "unknown"}`,
      500,
    );
  }
  return (data ?? []).map((row) => {
    const record = asRecord(row) ?? {};
    return {
      name: readString(record.name),
      principal: readNumber(record.principal, 0),
      monthly_payment: readNumber(record.monthly_payment, 0),
      interest_rate: readNumber(record.interest_rate, 0),
      lender: readString(record.lender),
      last_updated: readString(record.last_updated) || null,
      paused_at: readString(record.paused_at) || null,
    };
  }).filter((row) => row.name !== "");
}

function buildRequiredActions(params: {
  asOfDate: string;
  cycleStart: string;
  currentPayslip: PayslipRow | null;
  fallbackPayslip: PayslipRow | null;
  recurringExpenses: RecurringExpenseRow[];
  debts: DebtRow[];
}): DisposableBalanceAction[] {
  const actions: DisposableBalanceAction[] = [];
  if (!params.currentPayslip) {
    actions.push({
      action_key: "upload_current_payslip",
      priority: 1,
      title: "Current payslip is missing",
      instruction:
        "Upload the latest payslip PDF so income is calculated from source data (10 sec).",
      estimated_seconds: 10,
      amount_impact: params.fallbackPayslip?.net_amount ?? 0,
      category: "data_gap",
    });
  }
  if (params.recurringExpenses.length === 0) {
    actions.push({
      action_key: "add_recurring_expenses",
      priority: actions.length + 1,
      title: "Fixed expenses are not registered",
      instruction:
        "Add rent, utilities, and subscriptions to recurring expenses (180 sec).",
      estimated_seconds: 180,
      amount_impact: 0,
      category: "data_gap",
    });
  }
  for (const debt of params.debts) {
    if (!debt.last_updated) continue;
    const ageDays = Math.floor(
      (parseDate(params.asOfDate).getTime() -
        parseDate(debt.last_updated).getTime()) /
        86400000,
    );
    if (ageDays >= 60) {
      actions.push({
        action_key: `refresh_debt_${slugify(debt.name)}`,
        priority: actions.length + 1,
        title: `${debt.name} balance is stale`,
        instruction:
          `Enter the current ${debt.name} balance before deciding repayment order (60 sec).`,
        estimated_seconds: 60,
        amount_impact: debt.monthly_payment,
        category: "debt_refresh",
      });
      break;
    }
  }
  const duplicate = findDuplicateSubscription(params.recurringExpenses);
  if (duplicate) {
    actions.push({
      action_key: `cancel_duplicate_${duplicate.group}`,
      priority: actions.length + 1,
      title: `${duplicate.group} subscriptions overlap`,
      instruction:
        `Choose one ${duplicate.group} subscription and cancel the other to save about ${
          formatYen(duplicate.savings)
        } per month (120 sec).`,
      estimated_seconds: 120,
      amount_impact: duplicate.savings,
      category: "savings",
    });
  }
  return actions
    .sort((a, b) => a.priority - b.priority)
    .map((action, index) => ({ ...action, priority: index + 1 }))
    .slice(0, 5);
}

function findDuplicateSubscription(expenses: RecurringExpenseRow[]) {
  const groups: Record<string, RecurringExpenseRow[]> = {};
  for (const expense of expenses) {
    const name = expense.name.toLowerCase();
    const group = name.includes("spotify") || name.includes("apple music") ||
        name.includes("youtube music")
      ? "music"
      : name.includes("netflix") || name.includes("hulu") ||
          name.includes("disney")
      ? "video"
      : null;
    if (group) {
      groups[group] = [...(groups[group] ?? []), expense];
    }
  }
  for (const [group, rows] of Object.entries(groups)) {
    if (rows.length > 1) {
      const savings = Math.round(
        rows.map((row) => row.amount).sort((a, b) => a - b)[0],
      );
      return { group, savings };
    }
  }
  return null;
}

function buildDisposableBalanceMessages(
  base: Omit<
    DisposableBalanceResult,
    "status" | "provider" | "model" | "warnings"
  >,
) {
  return [
    {
      role: "system",
      content:
        "You are a concise CEO mentor. Return strict JSON {actions:[{action_key,priority,title,instruction,estimated_seconds,amount_impact,category}]}.",
    },
    {
      role: "user",
      content: JSON.stringify({
        rule:
          "No scolding. Each instruction must use the form 'do X (N sec)' and be based only on the supplied numbers.",
        balance: base,
      }),
    },
  ];
}

function parseProviderActions(text: string): DisposableBalanceAction[] {
  const parsed = extractJsonObject(text);
  const actions = parsed && Array.isArray(parsed.actions) ? parsed.actions : [];
  return actions
    .filter((entry): entry is UnknownRecord =>
      !!entry && typeof entry === "object" && !Array.isArray(entry)
    )
    .map((entry, index) => ({
      action_key: readString(entry.action_key) || `ai_action_${index + 1}`,
      priority: Math.max(1, Math.round(readNumber(entry.priority, index + 1))),
      title: readString(entry.title).slice(0, 120),
      instruction: readString(entry.instruction).slice(0, 280),
      estimated_seconds: Math.max(
        1,
        Math.round(readNumber(entry.estimated_seconds, 60)),
      ),
      amount_impact: Math.max(
        0,
        Math.round(readNumber(entry.amount_impact, 0)),
      ),
      category: readString(entry.category) || "mentor",
    }))
    .filter((entry) => entry.title !== "" && entry.instruction !== "");
}

function mergeActions(
  deterministic: DisposableBalanceAction[],
  aiActions: DisposableBalanceAction[],
): DisposableBalanceAction[] {
  const merged = [...deterministic, ...aiActions];
  const seen = new Set<string>();
  return merged.filter((action) => {
    if (seen.has(action.action_key)) return false;
    seen.add(action.action_key);
    return true;
  }).sort((a, b) => a.priority - b.priority).slice(0, 5)
    .map((action, index) => ({ ...action, priority: index + 1 }));
}

function normalizeDate(value: unknown, fallback: Date): string {
  const raw = readString(value);
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  if (raw) {
    const parsed = Date.parse(raw);
    if (Number.isFinite(parsed)) return toDateString(new Date(parsed));
  }
  return toDateString(fallback);
}

function parseDate(value: string): Date {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) {
    throw new DisposableBalanceError(`Invalid date: ${value}`, 400);
  }
  return dateUtc(Number(match[1]), Number(match[2]), Number(match[3]));
}

function dateUtc(year: number, month: number, day: number): Date {
  const first = new Date(Date.UTC(year, month - 1, 1));
  const lastDay = new Date(Date.UTC(
    first.getUTCFullYear(),
    first.getUTCMonth() + 1,
    0,
  )).getUTCDate();
  return new Date(Date.UTC(
    first.getUTCFullYear(),
    first.getUTCMonth(),
    Math.min(Math.max(1, day), lastDay),
  ));
}

function toDateString(date: Date): string {
  return `${date.getUTCFullYear()}-${
    String(date.getUTCMonth() + 1).padStart(2, "0")
  }-${String(date.getUTCDate()).padStart(2, "0")}`;
}

function clampDay(value: number): number {
  return Math.max(1, Math.min(28, Math.round(value)));
}

function asRecord(value: unknown): UnknownRecord | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as UnknownRecord;
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function readNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value == null) return fallback;
  const parsed = Number(String(value).replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function extractJsonObject(text: string): UnknownRecord | null {
  const trimmed = text.replace(/```json|```/g, "").trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return asRecord(JSON.parse(trimmed.slice(start, end + 1)));
  } catch {
    return null;
  }
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
    .slice(0, 60) || "debt";
}

function formatYen(value: number): string {
  return `JPY ${Math.round(value).toLocaleString("en-US")}`;
}
