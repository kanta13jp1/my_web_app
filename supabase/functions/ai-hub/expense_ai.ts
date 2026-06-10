type UnknownRecord = Record<string, unknown>;

export type ExpenseAiProviderRequest = {
  provider: string;
  model?: string;
  messages: { role: string; content: string }[];
};

export type ExpenseAiProviderResult = {
  ok: boolean;
  text?: string;
  modelUsed?: string;
  error?: string;
  isRetriable?: boolean;
};

export type ExpenseAiProviderInvoker = (
  request: ExpenseAiProviderRequest,
) => Promise<ExpenseAiProviderResult>;

type QueryResult = {
  data?: unknown | null;
  error?: { message?: string } | null;
};

export type ExpenseAiDbQuery = {
  select(columns?: string): ExpenseAiDbQuery;
  eq(column: string, value: string): ExpenseAiDbQuery;
  gte(column: string, value: string): ExpenseAiDbQuery;
  lt(column: string, value: string): ExpenseAiDbQuery;
  order(column: string, options?: { ascending?: boolean }): ExpenseAiDbQuery;
  limit(
    count: number,
  ): Promise<{ data?: unknown[] | null; error?: { message?: string } | null }>;
  upsert(
    value: UnknownRecord,
    options?: { onConflict?: string },
  ): {
    select(columns?: string): {
      single(): Promise<QueryResult>;
    };
  };
  insert(value: UnknownRecord | UnknownRecord[]): Promise<QueryResult>;
};

export type ExpenseAiDb = {
  from(table: string): ExpenseAiDbQuery;
};

export type ExpenseLine = {
  id?: string;
  source: string;
  posted_at?: string | null;
  description: string;
  amount: number;
};

export type ExpenseClassification = {
  classification_key: string;
  expense_source: string;
  expense_id: string | null;
  posted_at: string | null;
  description: string;
  amount: number;
  category: string;
  subcategory: string;
  confidence: number;
  status: "auto_confirmed" | "needs_review";
  classifier: string;
};

export type WeeklySpendingCoachingResult = {
  status: "ai_generated" | "deterministic_fallback";
  week_start: string;
  period_start: string;
  period_end: string;
  actions: UnknownRecord[];
  payload: UnknownRecord;
  provider: string | null;
  model: string | null;
  warnings: string[];
};

export class ExpenseAiError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "ExpenseAiError";
    this.status = status;
  }
}

const CATEGORY_RULES: Array<{
  category: string;
  subcategory: string;
  confidence: number;
  keywords: string[];
}> = [
  {
    category: "housing",
    subcategory: "rent",
    confidence: 0.9,
    keywords: ["家賃", "住宅", "rent", "housing"],
  },
  {
    category: "debt",
    subcategory: "repayment",
    confidence: 0.88,
    keywords: ["返済", "ローン", "loan", "card loan", "mobit", "acom"],
  },
  {
    category: "food",
    subcategory: "meal",
    confidence: 0.82,
    keywords: [
      "外食",
      "食費",
      "コンビニ",
      "restaurant",
      "lunch",
      "dinner",
      "cafe",
      "starbucks",
      "grocery",
    ],
  },
  {
    category: "utilities",
    subcategory: "life_line",
    confidence: 0.84,
    keywords: ["電気", "ガス", "水道", "utility", "utilities"],
  },
  {
    category: "communications",
    subcategory: "mobile_internet",
    confidence: 0.84,
    keywords: ["通信", "携帯", "スマホ", "docomo", "softbank", "wifi", "sim"],
  },
  {
    category: "subscription",
    subcategory: "digital",
    confidence: 0.86,
    keywords: [
      "サブスク",
      "subscription",
      "netflix",
      "spotify",
      "apple music",
      "youtube",
      "amazon prime",
      "openai",
      "claude",
    ],
  },
  {
    category: "shopping",
    subcategory: "daily_goods",
    confidence: 0.78,
    keywords: ["amazon", "楽天", "shopping", "store", "ドラッグ"],
  },
  {
    category: "transport",
    subcategory: "transit",
    confidence: 0.8,
    keywords: ["交通", "電車", "バス", "suica", "pasmo", "taxi", "uber"],
  },
  {
    category: "medical",
    subcategory: "healthcare",
    confidence: 0.78,
    keywords: ["医療", "病院", "薬局", "clinic", "pharmacy"],
  },
];

export function isExpenseAiAction(action: string): boolean {
  return action === "expense.classify" ||
    action === "classify-expense" ||
    action === "expense.weekly_coaching.generate";
}

export function classifyExpenseDeterministic(
  expense: ExpenseLine,
): ExpenseClassification {
  const text = expense.description.toLowerCase();
  for (const rule of CATEGORY_RULES) {
    if (rule.keywords.some((keyword) => text.includes(keyword.toLowerCase()))) {
      return buildClassification(expense, {
        category: rule.category,
        subcategory: rule.subcategory,
        confidence: rule.confidence,
        classifier: "deterministic_rules",
      });
    }
  }
  return buildClassification(expense, {
    category: "other",
    subcategory: "needs_review",
    confidence: 0.45,
    classifier: "deterministic_rules",
  });
}

export async function handleClassifyExpenseAction(options: {
  db: ExpenseAiDb;
  body: UnknownRecord;
  userId: string;
  invokeProvider?: ExpenseAiProviderInvoker;
}): Promise<{
  status: "classified";
  classifications: ExpenseClassification[];
  auto_confirmed_count: number;
  review_count: number;
  warnings: string[];
}> {
  const traceId = readString(options.body.trace_id) || crypto.randomUUID();
  const expenses = readExpenseLines(options.body).slice(0, 100);
  if (expenses.length === 0) {
    throw new ExpenseAiError("expense or expenses is required", 400);
  }
  const warnings: string[] = [];
  const classifications: ExpenseClassification[] = [];
  const aiEnabled = options.body.enable_ai === true ||
    Deno.env.get("EXPENSE_CLASSIFY_AI_ENABLED") === "true";

  for (const expense of expenses) {
    let classification = classifyExpenseDeterministic(expense);
    if (
      aiEnabled && classification.confidence < 0.7 && options.invokeProvider
    ) {
      const providerResult = await options.invokeProvider({
        provider: "google",
        model: readString(options.body.model) || "gemini-2.5-flash",
        messages: buildExpenseClassificationMessages(expense),
      });
      if (providerResult.ok && providerResult.text) {
        const providerClassification = parseProviderClassification(
          expense,
          providerResult.text,
          providerResult.modelUsed ?? "llm_fallback",
        );
        if (
          providerClassification &&
          providerClassification.confidence >= classification.confidence
        ) {
          classification = providerClassification;
        }
      } else {
        warnings.push(
          `AI classify fallback skipped: ${providerResult.error ?? "empty"}`,
        );
        if (options.body.dry_run !== true) {
          await options.db.from("expense_classification_failures").insert({
            user_id: options.userId,
            trace_id: traceId,
            expense_source: expense.source,
            expense_id: expense.id ?? null,
            description: expense.description,
            error_message: providerResult.error ?? "empty provider response",
          });
        }
      }
    }

    classifications.push(classification);
    if (options.body.dry_run !== true) {
      const { error } = await options.db.from("expense_classifications")
        .upsert({
          user_id: options.userId,
          ...classification,
          trace_id: traceId,
        }, { onConflict: "user_id,classification_key" })
        .select("id")
        .single();
      if (error) {
        throw new ExpenseAiError(
          `expense_classifications upsert failed: ${
            error.message ?? "unknown"
          }`,
          500,
        );
      }
    }
  }

  return {
    status: "classified",
    classifications,
    auto_confirmed_count:
      classifications.filter((item) => item.status === "auto_confirmed").length,
    review_count:
      classifications.filter((item) => item.status === "needs_review").length,
    warnings,
  };
}

export async function handleWeeklySpendingCoachingAction(options: {
  db: ExpenseAiDb;
  body: UnknownRecord;
  userId: string;
  invokeProvider?: ExpenseAiProviderInvoker;
  generatedAt?: Date;
}): Promise<WeeklySpendingCoachingResult> {
  const generatedAt = options.generatedAt ?? new Date();
  const period = normalizeCoachingPeriod(options.body, generatedAt);
  const currentTotals = readTotals(
    options.body.current_category_totals ?? options.body.current_period,
  );
  const previousTotals = readTotals(
    options.body.previous_category_totals ?? options.body.previous_period,
  );
  const payload = buildSpendingDeltaPayload(currentTotals, previousTotals);
  let actions = buildDeterministicCoachingActions(payload);
  let status: WeeklySpendingCoachingResult["status"] = "deterministic_fallback";
  let provider: string | null = null;
  let model: string | null = null;
  const warnings: string[] = [];

  const aiEnabled = options.body.enable_ai === true ||
    Deno.env.get("SPENDING_COACHING_AI_ENABLED") === "true";
  if (aiEnabled && options.invokeProvider) {
    const providerResult = await options.invokeProvider({
      provider: "google",
      model: readString(options.body.model) || "gemini-2.5-pro",
      messages: buildWeeklyCoachingMessages(payload),
    });
    if (providerResult.ok && providerResult.text) {
      const providerActions = parseProviderActions(providerResult.text);
      if (providerActions.length > 0) {
        actions = providerActions.slice(0, 5);
        status = "ai_generated";
        provider = "google";
        model = providerResult.modelUsed ?? "gemini-2.5-pro";
      }
    } else {
      warnings.push(
        `AI coaching fallback used: ${providerResult.error ?? "empty"}`,
      );
    }
  }

  if (options.body.dry_run !== true) {
    const { error } = await options.db.from("weekly_spending_coaching_cards")
      .upsert({
        user_id: options.userId,
        week_start: period.weekStart,
        period_start: period.periodStart,
        period_end: period.periodEnd,
        provider,
        model,
        status,
        payload,
        actions,
        generated_at: generatedAt.toISOString(),
      }, { onConflict: "user_id,week_start" })
      .select("id")
      .single();
    if (error) {
      throw new ExpenseAiError(
        `weekly_spending_coaching_cards upsert failed: ${
          error.message ?? "unknown"
        }`,
        500,
      );
    }
  }

  return {
    status,
    week_start: period.weekStart,
    period_start: period.periodStart,
    period_end: period.periodEnd,
    actions,
    payload,
    provider,
    model,
    warnings,
  };
}

function buildClassification(
  expense: ExpenseLine,
  decision: {
    category: string;
    subcategory: string;
    confidence: number;
    classifier: string;
  },
): ExpenseClassification {
  const confidence = clamp01(decision.confidence);
  return {
    classification_key: buildClassificationKey(expense),
    expense_source: expense.source,
    expense_id: expense.id ?? null,
    posted_at: expense.posted_at ?? null,
    description: expense.description,
    amount: expense.amount,
    category: decision.category,
    subcategory: decision.subcategory,
    confidence,
    status: confidence >= 0.7 ? "auto_confirmed" : "needs_review",
    classifier: decision.classifier,
  };
}

function buildClassificationKey(expense: ExpenseLine): string {
  if (expense.id) return `${expense.source}:${expense.id}`;
  return [
    expense.source,
    expense.posted_at ?? "no-date",
    Math.round(expense.amount * 100),
    expense.description.trim().toLowerCase().slice(0, 80),
  ].join(":");
}

function readExpenseLines(body: UnknownRecord): ExpenseLine[] {
  const source = readString(body.source) || "manual";
  const raw = Array.isArray(body.expenses)
    ? body.expenses
    : body.expense && typeof body.expense === "object"
    ? [body.expense]
    : body.description
    ? [body]
    : [];
  return raw
    .filter((entry): entry is UnknownRecord =>
      !!entry && typeof entry === "object" && !Array.isArray(entry)
    )
    .map((entry) => ({
      id: readString(entry.id) || readString(entry.expense_id) || undefined,
      source: readString(entry.source) || source,
      posted_at: readDate(entry.posted_at ?? entry.date),
      description: readString(entry.description),
      amount: Math.abs(readNumber(entry.amount, 0)),
    }))
    .filter((entry) => entry.description !== "" && entry.amount > 0);
}

function buildExpenseClassificationMessages(expense: ExpenseLine) {
  return [
    {
      role: "system",
      content:
        "Classify one personal-finance expense. Return only JSON with category, subcategory, confidence.",
    },
    {
      role: "user",
      content: JSON.stringify({
        allowed_categories: CATEGORY_RULES.map((rule) => rule.category).concat([
          "other",
        ]),
        expense,
      }),
    },
  ];
}

function parseProviderClassification(
  expense: ExpenseLine,
  text: string,
  classifier: string,
): ExpenseClassification | null {
  const parsed = extractJsonObject(text);
  if (!parsed) return null;
  const category = readString(parsed.category) || "other";
  const subcategory = readString(parsed.subcategory) || "needs_review";
  return buildClassification(expense, {
    category,
    subcategory,
    confidence: readNumber(parsed.confidence, 0.5),
    classifier,
  });
}

function normalizeCoachingPeriod(body: UnknownRecord, generatedAt: Date) {
  const startRaw = readDate(body.period_start);
  const endRaw = readDate(body.period_end);
  const fallbackEnd = new Date(Date.UTC(
    generatedAt.getUTCFullYear(),
    generatedAt.getUTCMonth(),
    generatedAt.getUTCDate(),
  ));
  const fallbackStart = new Date(fallbackEnd);
  fallbackStart.setUTCDate(fallbackStart.getUTCDate() - 6);
  const periodStart = startRaw ?? toDateString(fallbackStart);
  const periodEnd = endRaw ?? toDateString(fallbackEnd);
  const weekStart = readDate(body.week_start) ?? periodStart;
  return { weekStart, periodStart, periodEnd };
}

function readTotals(value: unknown): Record<string, number> {
  const record = asRecord(value) ?? {};
  const totals: Record<string, number> = {};
  for (const [key, raw] of Object.entries(record)) {
    const amount = typeof raw === "object" && raw !== null
      ? readNumber((raw as UnknownRecord).amount, 0)
      : readNumber(raw, 0);
    if (amount !== 0) totals[key] = amount;
  }
  return totals;
}

function buildSpendingDeltaPayload(
  currentTotals: Record<string, number>,
  previousTotals: Record<string, number>,
): UnknownRecord {
  const categories = Array.from(
    new Set([...Object.keys(currentTotals), ...Object.keys(previousTotals)]),
  );
  const deltas = categories.map((category) => {
    const current = currentTotals[category] ?? 0;
    const previous = previousTotals[category] ?? 0;
    const delta = current - previous;
    return {
      category,
      current,
      previous,
      delta,
      delta_ratio: previous > 0 ? delta / previous : null,
    };
  }).sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));
  return {
    current_totals: currentTotals,
    previous_totals: previousTotals,
    deltas,
  };
}

function buildDeterministicCoachingActions(payload: UnknownRecord) {
  const deltas = Array.isArray(payload.deltas) ? payload.deltas : [];
  const actions: UnknownRecord[] = [];
  for (const entry of deltas.slice(0, 3)) {
    if (!entry || typeof entry !== "object") continue;
    const row = entry as UnknownRecord;
    const delta = readNumber(row.delta, 0);
    if (delta <= 0) continue;
    const category = readString(row.category) || "spending";
    actions.push({
      action_key: `reduce_${category}`,
      priority: actions.length + 1,
      title: `${category} increased by ${formatYen(delta)}`,
      instruction:
        `CEO action: cap ${category} for the next 7 days and review the top 3 receipts (120 sec).`,
      estimated_savings: Math.round(delta * 0.3),
      tone: "mentor",
    });
  }
  if (actions.length === 0) {
    actions.push({
      action_key: "keep_current_spending_review",
      priority: 1,
      title: "No major spending spike detected",
      instruction:
        "CEO action: keep the current rule and review unclassified expenses once this week (90 sec).",
      estimated_savings: 0,
      tone: "mentor",
    });
  }
  return actions;
}

function buildWeeklyCoachingMessages(payload: UnknownRecord) {
  return [
    {
      role: "system",
      content:
        "You are a concise CEO mentor. Return strict JSON: {actions:[{action_key,priority,title,instruction,estimated_savings,tone}]}",
    },
    {
      role: "user",
      content: JSON.stringify({
        rule:
          "No scolding. Each instruction must be concrete and include an estimated time in seconds.",
        payload,
      }),
    },
  ];
}

function parseProviderActions(text: string): UnknownRecord[] {
  const parsed = extractJsonObject(text);
  const actions = parsed && Array.isArray(parsed.actions) ? parsed.actions : [];
  return actions
    .filter((entry): entry is UnknownRecord =>
      !!entry && typeof entry === "object" && !Array.isArray(entry)
    )
    .map((entry, index) => ({
      action_key: readString(entry.action_key) || `ai_action_${index + 1}`,
      priority: Math.max(1, Math.round(readNumber(entry.priority, index + 1))),
      title: readString(entry.title).slice(0, 140),
      instruction: readString(entry.instruction).slice(0, 320),
      estimated_savings: Math.max(
        0,
        Math.round(readNumber(entry.estimated_savings, 0)),
      ),
      tone: readString(entry.tone) || "mentor",
    }))
    .filter((entry) => entry.title !== "" && entry.instruction !== "");
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

function readDate(value: unknown): string | null {
  const raw = readString(value);
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? toDateString(new Date(parsed)) : null;
}

function toDateString(date: Date): string {
  return `${date.getUTCFullYear()}-${
    String(date.getUTCMonth() + 1).padStart(2, "0")
  }-${String(date.getUTCDate()).padStart(2, "0")}`;
}

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, Math.round(value * 1000) / 1000));
}

function formatYen(value: number): string {
  return `JPY ${Math.round(value).toLocaleString("en-US")}`;
}
