import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.105.1";

const DEFAULT_ALLOWED_ORIGINS = ["https://my-web-app-b67f4.web.app"];
const MAX_BODY_BYTES = 4_096;
const RATE_LIMIT_REQUESTS = 12;
const RATE_LIMIT_WINDOW_MS = 60_000;
const DECISION_MIN_TOUCHES = 10;
const DECISION_TARGET_CVR = 5;

export const ACCESS_POLICY = Object.freeze({
  methods: ["POST"] as const,
  authorization: "admin_or_service_role",
  aggregateOnly: true,
  rateLimit: {
    requests: RATE_LIMIT_REQUESTS,
    windowSeconds: RATE_LIMIT_WINDOW_MS / 1_000,
  },
});

interface WeeklyDigestRequest {
  /** ISO date string for the END of the current week window (inclusive). */
  endDate?: string;
}

interface DateRange {
  startDate: string;
  endDate: string;
}

interface ChannelMetrics {
  id: string;
  label: string;
  touches: number;
  signupSubmits: number;
  cvr: number;
  touchesDelta: number;
  signupSubmitsDelta: number;
}

interface WeeklyDecision {
  id: string;
  week: DateRange;
  owner: string;
  priorityChannel: { id: string; label: string };
  threshold: {
    metric: "cvr_percent";
    operator: ">=";
    target: number;
    minimumTouches: number;
  };
  nextAction: string;
  dueDate: string;
  outcome: {
    status: "pending";
    measureWeek: DateRange;
  };
}

interface PreviousDecisionOutcome {
  decisionId: string;
  decisionWeek: DateRange;
  measuredWeek: DateRange;
  owner: string;
  priorityChannel: { id: string; label: string };
  threshold: WeeklyDecision["threshold"];
  nextAction: string;
  dueDate: string;
  actual: { cvr: number; touches: number; signupSubmits: number };
  status: "met" | "missed" | "insufficient_sample";
}

interface WeeklyDigest {
  currentWeek: DateRange;
  priorWeek: DateRange;
  channels: ChannelMetrics[];
  importPreviews: { id: string; label: string; count: number; delta: number }[];
  signupSubmitTotal: number;
  signupSubmitDelta: number;
  referralsCompleted: number;
  referralsDelta: number;
  importCtaClicks: number;
  publicMemoCtaClicks: number;
  decision: WeeklyDecision;
  previousDecisionOutcome: PreviousDecisionOutcome;
  brief: string;
}

type AdminClient = SupabaseClient;

interface AuthorizedCaller {
  actorKey: string;
  decisionOwner: string;
  admin: AdminClient;
}

interface AuthorizationFailure {
  status: 401 | 403 | 503;
  error: "unauthorized" | "admin_required" | "service_unavailable";
}

type AuthorizationResult = AuthorizedCaller | AuthorizationFailure;

export interface DigestDependencies {
  allowedOrigins: string[];
  authorize(request: Request): Promise<AuthorizationResult>;
  fetchAnalyticsRows(
    admin: AdminClient,
    startDate: string,
    endDate: string,
  ): Promise<Array<Record<string, unknown>>>;
  fetchReferralCount(
    admin: AdminClient,
    startDate: string,
    endDate: string,
  ): Promise<number>;
  allowRequest(actorKey: string, nowMs: number): boolean;
  now(): Date;
}

interface AuthDependencies {
  serviceRoleKey: string;
  admin: AdminClient;
  getUser(
    authorization: string,
  ): Promise<{ id: string } | null>;
  getAdminProfile(
    userId: string,
  ): Promise<{ is_admin?: boolean; role?: string } | null>;
}

export async function authorizeRequest(
  request: Request,
  dependencies: AuthDependencies,
): Promise<AuthorizationResult> {
  const authorization = request.headers.get("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  if (!match) return { status: 401, error: "unauthorized" };
  const token = match[1].trim();

  if (
    dependencies.serviceRoleKey !== "" &&
    constantTimeEqual(token, dependencies.serviceRoleKey)
  ) {
    return {
      actorKey: "service_role",
      decisionOwner: "service_role",
      admin: dependencies.admin,
    };
  }

  let user: { id: string } | null;
  try {
    user = await dependencies.getUser(authorization);
  } catch {
    return { status: 503, error: "service_unavailable" };
  }
  if (!user) return { status: 401, error: "unauthorized" };

  let profile: { is_admin?: boolean; role?: string } | null;
  try {
    profile = await dependencies.getAdminProfile(user.id);
  } catch {
    return { status: 503, error: "service_unavailable" };
  }
  if (profile?.is_admin !== true && profile?.role !== "admin") {
    return { status: 403, error: "admin_required" };
  }

  return {
    actorKey: user.id,
    decisionOwner: user.id,
    admin: dependencies.admin,
  };
}

export function createHandler(dependencies: DigestDependencies) {
  return async (request: Request): Promise<Response> => {
    const cors = corsHeaders(request, dependencies.allowedOrigins);
    const origin = request.headers.get("origin");
    if (origin !== null && !cors["Access-Control-Allow-Origin"]) {
      return jsonResponse({ success: false, error: "origin_not_allowed" }, 403);
    }
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      return jsonResponse(
        { success: false, error: "method_not_allowed" },
        405,
        cors,
      );
    }

    const authorization = await dependencies.authorize(request);
    if ("status" in authorization) {
      return jsonResponse(
        { success: false, error: authorization.error },
        authorization.status,
        cors,
      );
    }
    const requestTime = dependencies.now();
    if (
      !dependencies.allowRequest(authorization.actorKey, requestTime.getTime())
    ) {
      return jsonResponse(
        { success: false, error: "rate_limited" },
        429,
        { ...cors, "Retry-After": "60" },
      );
    }

    const parsed = await parseRequest(request);
    if (parsed instanceof Response) return withCors(parsed, cors);

    try {
      const { currentWeek, priorWeek } = buildWeekRanges(
        parsed.endDate,
        requestTime,
      );
      const [currentRows, priorRows, referralCurrent, referralPrior] =
        await Promise.all([
          dependencies.fetchAnalyticsRows(
            authorization.admin,
            currentWeek.startDate,
            currentWeek.endDate,
          ),
          dependencies.fetchAnalyticsRows(
            authorization.admin,
            priorWeek.startDate,
            priorWeek.endDate,
          ),
          dependencies.fetchReferralCount(
            authorization.admin,
            currentWeek.startDate,
            currentWeek.endDate,
          ),
          dependencies.fetchReferralCount(
            authorization.admin,
            priorWeek.startDate,
            priorWeek.endDate,
          ),
        ]);

      const currentCounts = aggregateSourceCounts(currentRows);
      const priorCounts = aggregateSourceCounts(priorRows);
      const channels = buildChannelMetrics(currentCounts, priorCounts);
      const priorChannels = buildChannelMetrics(priorCounts, {});

      const importPreviewDefs = [
        { id: "notion", label: "Notion", key: "import_preview_notion" },
        { id: "evernote", label: "Evernote", key: "import_preview_evernote" },
        { id: "markdown", label: "Markdown", key: "import_preview_markdown" },
      ];
      const importPreviews = importPreviewDefs.map((definition) => ({
        id: definition.id,
        label: definition.label,
        count: currentCounts[definition.key] ?? 0,
        delta: (currentCounts[definition.key] ?? 0) -
          (priorCounts[definition.key] ?? 0),
      }));
      const signupSubmitTotal = channels.reduce(
        (sum, channel) => sum + channel.signupSubmits,
        0,
      );
      const priorSignupTotal = priorChannels.reduce(
        (sum, channel) => sum + channel.signupSubmits,
        0,
      );
      const decision = buildWeeklyDecision(
        currentWeek,
        channels,
        authorization.decisionOwner,
      );
      const previousDecisionOutcome = buildPreviousDecisionOutcome(
        priorWeek,
        currentWeek,
        priorChannels,
        channels,
        authorization.decisionOwner,
      );

      const digest: WeeklyDigest = {
        currentWeek,
        priorWeek,
        channels,
        importPreviews,
        signupSubmitTotal,
        signupSubmitDelta: signupSubmitTotal - priorSignupTotal,
        referralsCompleted: referralCurrent,
        referralsDelta: referralCurrent - referralPrior,
        importCtaClicks: currentCounts["import_signup_cta"] ?? 0,
        publicMemoCtaClicks: currentCounts["public_memo_signup_cta"] ?? 0,
        decision,
        previousDecisionOutcome,
        brief: buildBrief({
          currentWeek,
          channels,
          importPreviews,
          signupSubmitTotal,
          signupSubmitDelta: signupSubmitTotal - priorSignupTotal,
          referralsCompleted: referralCurrent,
          referralsDelta: referralCurrent - referralPrior,
          decision,
          previousDecisionOutcome,
        }),
      };

      return jsonResponse(
        { success: true, digest, accessPolicy: ACCESS_POLICY },
        200,
        cors,
      );
    } catch {
      return jsonResponse(
        { success: false, error: "digest_unavailable" },
        503,
        cors,
      );
    }
  };
}

async function parseRequest(
  request: Request,
): Promise<WeeklyDigestRequest | Response> {
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
    return jsonResponse({ success: false, error: "payload_too_large" }, 413);
  }
  const contentType = (request.headers.get("content-type") ?? "").toLowerCase();
  if (!contentType.startsWith("application/json")) {
    return jsonResponse(
      { success: false, error: "content_type_must_be_json" },
      415,
    );
  }
  const raw = await request.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
    return jsonResponse({ success: false, error: "payload_too_large" }, 413);
  }

  let body: Record<string, unknown>;
  try {
    const decoded = raw.trim() === "" ? {} : JSON.parse(raw);
    if (
      typeof decoded !== "object" || decoded === null || Array.isArray(decoded)
    ) {
      throw new Error("invalid_json");
    }
    body = decoded as Record<string, unknown>;
  } catch {
    return jsonResponse({ success: false, error: "invalid_json" }, 400);
  }

  const endDate = body.endDate;
  if (endDate !== undefined && !isIsoDate(endDate)) {
    return jsonResponse({ success: false, error: "invalid_end_date" }, 422);
  }
  return { endDate: endDate as string | undefined };
}

export function buildWeekRanges(
  endDateInput: string | undefined,
  now = new Date(),
): { currentWeek: DateRange; priorWeek: DateRange } {
  const end = endDateInput
    ? new Date(`${endDateInput}T00:00:00.000Z`)
    : new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    );
  const currentStart = addUtcDays(end, -6);
  const priorEnd = addUtcDays(currentStart, -1);
  const priorStart = addUtcDays(priorEnd, -6);
  return {
    currentWeek: { startDate: fmt(currentStart), endDate: fmt(end) },
    priorWeek: { startDate: fmt(priorStart), endDate: fmt(priorEnd) },
  };
}

const CHANNEL_DEFINITIONS = [
  {
    id: "landing",
    label: "ランディングページ",
    touch: "touch_landing",
    signup: "signup_submit_landing",
  },
  {
    id: "profile",
    label: "X profile",
    touch: "touch_profile",
    signup: "signup_submit_profile",
  },
  {
    id: "import",
    label: "インポート",
    touch: "touch_import",
    signup: "signup_submit_import",
  },
  {
    id: "public_memo",
    label: "公開メモ",
    touch: "touch_public_memo",
    signup: "signup_submit_public_memo",
  },
  {
    id: "referral",
    label: "紹介",
    touch: "touch_referral",
    signup: "signup_submit_referral",
  },
  {
    id: "comparison",
    label: "競合比較ページ",
    touch: "touch_comparison",
    signup: "signup_submit_comparison",
  },
  {
    id: "guitar",
    label: "ギタースタジオ",
    touch: "touch_guitar_gallery",
    signup: "signup_submit_guitar",
  },
] as const;

function buildChannelMetrics(
  current: Record<string, number>,
  prior: Record<string, number>,
): ChannelMetrics[] {
  return CHANNEL_DEFINITIONS.map((definition) => {
    const touches = current[definition.touch] ?? 0;
    const signupSubmits = current[definition.signup] ?? 0;
    return {
      id: definition.id,
      label: definition.label,
      touches,
      signupSubmits,
      cvr: touches > 0 ? Math.round((signupSubmits / touches) * 100) : 0,
      touchesDelta: touches - (prior[definition.touch] ?? 0),
      signupSubmitsDelta: signupSubmits - (prior[definition.signup] ?? 0),
    };
  });
}

function buildWeeklyDecision(
  week: DateRange,
  channels: ChannelMetrics[],
  owner: string,
): WeeklyDecision {
  const priority = selectPriorityChannel(channels);
  const measureStart = addIsoDays(week.endDate, 1);
  const dueDate = addIsoDays(week.endDate, 7);
  const nextAction = priority.touches < DECISION_MIN_TOUCHES
    ? `${priority.label}で${DECISION_MIN_TOUCHES}タッチ以上を計測し、CTA仮説を1つ検証する。`
    : priority.cvr < DECISION_TARGET_CVR
    ? `${priority.label}のCTA導線を1つ改善し、CVR ${DECISION_TARGET_CVR}%以上を検証する。`
    : `${priority.label}の勝ち筋を維持し、流入を増やしてCVR ${DECISION_TARGET_CVR}%以上を再検証する。`;
  return {
    id:
      `growth-weekly:${week.endDate}:${priority.id}:cvr-${DECISION_TARGET_CVR}`,
    week,
    owner,
    priorityChannel: { id: priority.id, label: priority.label },
    threshold: decisionThreshold(),
    nextAction,
    dueDate,
    outcome: {
      status: "pending",
      measureWeek: { startDate: measureStart, endDate: dueDate },
    },
  };
}

function buildPreviousDecisionOutcome(
  decisionWeek: DateRange,
  measuredWeek: DateRange,
  priorChannels: ChannelMetrics[],
  currentChannels: ChannelMetrics[],
  owner: string,
): PreviousDecisionOutcome {
  const priorDecision = buildWeeklyDecision(decisionWeek, priorChannels, owner);
  const actual = currentChannels.find(
    (channel) => channel.id === priorDecision.priorityChannel.id,
  ) ?? selectPriorityChannel(priorChannels);
  const status = actual.touches < DECISION_MIN_TOUCHES
    ? "insufficient_sample"
    : actual.cvr >= DECISION_TARGET_CVR
    ? "met"
    : "missed";
  return {
    decisionId: priorDecision.id,
    decisionWeek,
    measuredWeek,
    owner: priorDecision.owner,
    priorityChannel: priorDecision.priorityChannel,
    threshold: priorDecision.threshold,
    nextAction: priorDecision.nextAction,
    dueDate: priorDecision.dueDate,
    actual: {
      cvr: actual.cvr,
      touches: actual.touches,
      signupSubmits: actual.signupSubmits,
    },
    status,
  };
}

function decisionThreshold(): WeeklyDecision["threshold"] {
  return {
    metric: "cvr_percent",
    operator: ">=",
    target: DECISION_TARGET_CVR,
    minimumTouches: DECISION_MIN_TOUCHES,
  };
}

function selectPriorityChannel(channels: ChannelMetrics[]): ChannelMetrics {
  const populated = channels.filter((channel) => channel.touches > 0);
  const candidates = populated.length > 0 ? populated : channels;
  return [...candidates].sort((left, right) => {
    const leftBelow = left.cvr < DECISION_TARGET_CVR ? 1 : 0;
    const rightBelow = right.cvr < DECISION_TARGET_CVR ? 1 : 0;
    if (leftBelow !== rightBelow) return rightBelow - leftBelow;
    if (left.touches !== right.touches) return right.touches - left.touches;
    if (left.cvr !== right.cvr) return left.cvr - right.cvr;
    return left.id.localeCompare(right.id);
  })[0] ?? {
    id: "landing",
    label: "ランディングページ",
    touches: 0,
    signupSubmits: 0,
    cvr: 0,
    touchesDelta: 0,
    signupSubmitsDelta: 0,
  };
}

function buildBrief({
  currentWeek,
  channels,
  importPreviews,
  signupSubmitTotal,
  signupSubmitDelta,
  referralsCompleted,
  referralsDelta,
  decision,
  previousDecisionOutcome,
}: {
  currentWeek: DateRange;
  channels: ChannelMetrics[];
  importPreviews: { id: string; label: string; count: number; delta: number }[];
  signupSubmitTotal: number;
  signupSubmitDelta: number;
  referralsCompleted: number;
  referralsDelta: number;
  decision: WeeklyDecision;
  previousDecisionOutcome: PreviousDecisionOutcome;
}): string {
  const arrow = (value: number) =>
    value > 0 ? `↑${value}` : value < 0 ? `↓${Math.abs(value)}` : "→";
  const lines = [
    "## 自分株式会社 週次 Growth Digest",
    `期間: ${currentWeek.startDate} ～ ${currentWeek.endDate}`,
    "",
    `### サインアップ CTA クリック 合計: ${signupSubmitTotal} ${
      arrow(signupSubmitDelta)
    }`,
    "",
    "### チャネル別",
  ];
  for (const channel of channels) {
    lines.push(
      `- **${channel.label}**: タッチ ${channel.touches}${
        arrow(channel.touchesDelta)
      } / CTA ${channel.signupSubmits}${
        arrow(channel.signupSubmitsDelta)
      } / CVR ${channel.cvr}%`,
    );
  }
  lines.push("", "### インポートプレビュー");
  for (const preview of importPreviews) {
    lines.push(`- ${preview.label}: ${preview.count} ${arrow(preview.delta)}`);
  }
  lines.push(
    "",
    `### リファラル成立: ${referralsCompleted} ${arrow(referralsDelta)}`,
    "",
    "### 今週の意思決定",
    `- Decision ID: ${decision.id}`,
    `- Owner: ${decision.owner}`,
    `- 優先チャネル: ${decision.priorityChannel.label}`,
    `- 閾値: ${decision.threshold.minimumTouches}タッチ以上 / CVR ${decision.threshold.target}%以上`,
    `- Next action: ${decision.nextAction}`,
    `- Due: ${decision.dueDate}`,
    "",
    "### 前週actionのoutcome",
    `- Decision ID: ${previousDecisionOutcome.decisionId}`,
    `- ${previousDecisionOutcome.priorityChannel.label}: ${previousDecisionOutcome.status} / ${previousDecisionOutcome.actual.touches}タッチ / CVR ${previousDecisionOutcome.actual.cvr}%`,
    "",
    `> 前週比: CTA ${arrow(signupSubmitDelta)} / referral ${
      arrow(referralsDelta)
    }`,
  );
  return lines.join("\n");
}

function aggregateSourceCounts(
  rows: Array<Record<string, unknown>>,
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const row of rows) {
    const sourceDetails = toMap(row.source_details);
    for (const [key, rawValue] of Object.entries(sourceDetails)) {
      const value = toNumber(rawValue);
      if (value <= 0) continue;
      counts[key] = (counts[key] ?? 0) + value;
    }
  }
  return counts;
}

function createProductionDependencies(): DigestDependencies {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  const admin = supabaseUrl !== "" && serviceRoleKey !== ""
    ? createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })
    : null;
  const limiter = createFixedWindowLimiter();
  const allowedOrigins = [
    ...DEFAULT_ALLOWED_ORIGINS,
    ...(Deno.env.get("GROWTH_DIGEST_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
  ];
  return {
    allowedOrigins,
    now: () => new Date(),
    allowRequest: limiter,
    authorize: (request) => {
      if (!supabaseUrl || !anonKey || !serviceRoleKey || admin === null) {
        return Promise.resolve(
          {
            status: 503,
            error: "service_unavailable",
          } as const,
        );
      }
      return authorizeRequest(request, {
        serviceRoleKey,
        admin,
        getUser: async (authorization) => {
          const session = createClient(supabaseUrl, anonKey, {
            global: { headers: { Authorization: authorization } },
            auth: { autoRefreshToken: false, persistSession: false },
          });
          const { data, error } = await session.auth.getUser();
          if (error) return null;
          return data.user ? { id: data.user.id } : null;
        },
        getAdminProfile: async (userId) => {
          const { data, error } = await admin
            .from("user_profiles")
            .select("is_admin, role")
            .eq("user_id", userId)
            .maybeSingle();
          if (error) throw new Error("profile_lookup_failed");
          return data;
        },
      });
    },
    fetchAnalyticsRows: async (client, startDate, rangeEndDate) => {
      const result = await client
        .from("app_analytics")
        .select("date, source_details")
        .gte("date", startDate)
        .lte("date", rangeEndDate);
      if (result.error) throw new Error("analytics_query_failed");
      return result.data ?? [];
    },
    fetchReferralCount: async (client, startDate, rangeEndDate) => {
      const result = await client
        .from("referrals")
        .select("id", { count: "exact", head: true })
        .eq("status", "completed")
        .gte("completed_at", `${startDate}T00:00:00.000Z`)
        .lte("completed_at", `${rangeEndDate}T23:59:59.999Z`);
      if (result.error) throw new Error("referral_query_failed");
      return result.count ?? 0;
    },
  };
}

export function createFixedWindowLimiter(
  limit = RATE_LIMIT_REQUESTS,
  windowMs = RATE_LIMIT_WINDOW_MS,
): (actorKey: string, nowMs: number) => boolean {
  const windows = new Map<string, { startsAt: number; count: number }>();
  return (actorKey, nowMs) => {
    const current = windows.get(actorKey);
    if (!current || nowMs - current.startsAt >= windowMs) {
      windows.set(actorKey, { startsAt: nowMs, count: 1 });
      return true;
    }
    if (current.count >= limit) return false;
    current.count += 1;
    return true;
  };
}

function corsHeaders(
  request: Request,
  allowedOrigins: string[],
): Record<string, string> {
  const origin = request.headers.get("origin") ?? "";
  const allowed = origin !== "" && isAllowedOrigin(origin, allowedOrigins);
  return {
    ...(allowed ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function isAllowedOrigin(origin: string, allowedOrigins: string[]): boolean {
  if (allowedOrigins.includes(origin)) return true;
  try {
    const url = new URL(origin);
    return (url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
      (url.protocol === "http:" || url.protocol === "https:");
  } catch {
    return false;
  }
}

function jsonResponse(
  payload: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...headers,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function withCors(
  response: Response,
  headers: Record<string, string>,
): Response {
  const merged = new Headers(response.headers);
  for (const [key, value] of Object.entries(headers)) merged.set(key, value);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: merged,
  });
}

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let mismatch = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index++) {
    mismatch |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return mismatch === 0;
}

function isIsoDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && fmt(parsed) === value;
}

function addIsoDays(value: string, days: number): string {
  return fmt(addUtcDays(new Date(`${value}T00:00:00.000Z`), days));
}

function addUtcDays(value: Date, days: number): Date {
  const copy = new Date(value);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function fmt(date: Date): string {
  const year = String(date.getUTCFullYear()).padStart(4, "0");
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function toMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

if (import.meta.main) {
  Deno.serve(createHandler(createProductionDependencies()));
}
