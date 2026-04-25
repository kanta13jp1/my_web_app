// tools-hub — 個人生産性ツール統合EF
// Merges (30 EFs): password-generator, password-vault, currency-converter,
//   weather-widget, qr-code-generator, markdown-renderer, pomodoro-timer,
//   focus-timer, clipboard-history, quick-note, goal-tracker, contact-manager,
//   reading-list, bookmark-manager, bookmark-sync, tag-manager, template-library,
//   address-book, emergency-contacts, news-rss-aggregator, changelog-manager,
//   multi-language, habit-tracker, habit-gamification, virtual-pet, poll-survey,
//   form-builder, note-sharing-enhanced, content-versioning, mindmap-diagram
//
// GET/POST ?action=<action> or body { action: "..." }
// All data stored in hub_data table (source column = feature name)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function parseBooleanish(value: unknown, defaultValue: boolean): boolean {
  if (typeof value === "boolean") return value;
  const normalized = String(value ?? "").trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "off"].includes(normalized)) return false;
  return defaultValue;
}

function getHarveyBaseUrl(region: unknown): string {
  const normalized = String(region ?? "").trim().toLowerCase();
  if (normalized === "eu") return "https://eu.api.harvey.ai";
  if (normalized === "au") return "https://au.api.harvey.ai";
  return "https://api.harvey.ai";
}

function normalizeHarveyKnowledgeSources(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) {
    return value.map((item) => asRecord(item)).filter((item): item is Record<string, unknown> => item !== null);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) {
        return parsed.map((item) => asRecord(item)).filter((item): item is Record<string, unknown> => item !== null);
      }
    } catch {
      return [];
    }
  }
  return [];
}

async function callHarveyCompletion(body: Record<string, unknown>) {
  const token = Deno.env.get("HARVEY_API_KEY") ?? "";
  if (!token) {
    return { ok: false, status: 503, error: "HARVEY_API_KEY not configured" };
  }

  const prompt = String(body.prompt ?? "").trim();
  if (!prompt) {
    return { ok: false, status: 400, error: "prompt is required" };
  }

  const includeCitations = parseBooleanish(
    body.include_citations ?? body.includeCitations,
    true,
  );
  const modeRaw = String(body.mode ?? "draft").trim().toLowerCase();
  const mode = modeRaw === "assist" ? "assist" : "draft";
  const clientMatterId = String(
    body.client_matter_id ?? body.clientMatterId ?? "",
  ).trim();
  const model = String(body.model ?? "").trim();
  const knowledgeSources = normalizeHarveyKnowledgeSources(
    body.knowledge_sources ?? body.knowledgeSources,
  );
  if (
    knowledgeSources.length === 0 &&
    parseBooleanish(body.use_web ?? body.useWeb, false)
  ) {
    knowledgeSources.push({ type: "web" });
  }

  const form = new FormData();
  form.set("prompt", prompt);
  form.set("stream", "false");
  form.set("mode", mode);
  if (clientMatterId) form.set("client_matter_id", clientMatterId);
  if (knowledgeSources.length > 0) {
    form.set("knowledge_sources", JSON.stringify(knowledgeSources));
  }
  if (model) form.set("model", model);

  const baseUrl = getHarveyBaseUrl(body.region);
  const endpoint =
    `${baseUrl}/api/v2/completion?include_citations=${includeCitations ? "true" : "false"}`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: form,
  });
  const rawText = await response.text();

  let parsed: Record<string, unknown> = {};
  try {
    parsed = asRecord(JSON.parse(rawText)) ?? {};
  } catch {
    parsed = {};
  }

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      error: String(
        parsed.error ??
          parsed.message ??
          `Harvey API error: ${response.status}`,
      ),
      details: rawText.slice(0, 500),
    };
  }

  return {
    ok: true,
    status: response.status,
    data: {
      provider: "harvey",
      mode,
      base_url: baseUrl,
      response: String(parsed.response ?? ""),
      response_with_citations: parsed.response_with_citations ?? null,
      sources: Array.isArray(parsed.sources) ? parsed.sources : [],
      model: model.length > 0 ? model : parsed.model ?? null,
      used_knowledge_sources: knowledgeSources,
    },
  };
}

function wbsPriorityRank(priority: unknown): number {
  const value = String(priority ?? "").toLowerCase();
  if (value === "high") return 3;
  if (value === "medium") return 2;
  if (value === "low") return 1;
  return 0;
}

function isFeatureRequestTask(task: Record<string, unknown>): boolean {
  const category = String(task.category ?? "");
  const title = String(task.title ?? "");
  return category === "ユーザー要望" || title.startsWith("[追加要望]");
}

function wbsTaskSortBucket(task: Record<string, unknown>): number {
  const status = String(task.status ?? "");
  if (status === "completed") return 4;
  if (isFeatureRequestTask(task)) return 0;
  if (status === "in_progress") return 1;
  if (status === "pending") return 2;
  if (status === "blocked") return 3;
  return 3;
}

function compareOptionalDate(a: unknown, b: unknown): number {
  const aValue = typeof a === "string" && a ? Date.parse(a) : Number.NaN;
  const bValue = typeof b === "string" && b ? Date.parse(b) : Number.NaN;
  const aMissing = Number.isNaN(aValue);
  const bMissing = Number.isNaN(bValue);
  if (aMissing && bMissing) return 0;
  if (aMissing) return 1;
  if (bMissing) return -1;
  return aValue - bValue;
}

function compareWbsTasks(a: Record<string, unknown>, b: Record<string, unknown>): number {
  const bucketCmp = wbsTaskSortBucket(a) - wbsTaskSortBucket(b);
  if (bucketCmp !== 0) return bucketCmp;

  const priorityCmp = wbsPriorityRank(b.priority) - wbsPriorityRank(a.priority);
  if (priorityCmp !== 0) return priorityCmp;

  const categoryOrderCmp = Number(a.category_order ?? 999) - Number(b.category_order ?? 999);
  if (categoryOrderCmp !== 0) return categoryOrderCmp;

  const endDateCmp = compareOptionalDate(a.end_date, b.end_date);
  if (endDateCmp !== 0) return endDateCmp;

  const updatedAtCmp = compareOptionalDate(b.updated_at, a.updated_at);
  if (updatedAtCmp !== 0) return updatedAtCmp;

  return String(a.title ?? "").localeCompare(String(b.title ?? ""));
}

const WBS_INSTANCE_VALUES = [
  "codex",     // OpenAI Codex CLI
  "gemini",    // Google Gemini Code Assist
  "copilot",   // GitHub Copilot Chat / Inline
  "vscode",
  "win",
  "ps1",
  "ps2",
  "ps3",
  "ps4",
  "ps5",
  "ps6",
  "web",
  "mobile",
  "schedule",
  "gha",
  "user",      // ユーザー手動操作タスク (法人登記/銀行口座/外部面談等)
];

const WBS_OPEN_STATUSES = ["pending", "in_progress", "blocked"];

function normalizeWbsInstance(value: unknown): string {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "windows") return "win";
  if (normalized === "ps") return "ps1";
  if (normalized === "co-pilot" || normalized === "github-copilot") return "copilot";
  return WBS_INSTANCE_VALUES.includes(normalized) ? normalized : "codex";
}

function wbsTaskLane(task: Record<string, unknown>): string {
  return normalizeWbsInstance(task.owner_instance ?? task.instance);
}

function wbsDeadline(task: Record<string, unknown>): string {
  return String(task.planned_end_date ?? task.end_date ?? "");
}

function wbsOverdueDays(task: Record<string, unknown>, today: Date): number {
  const raw = wbsDeadline(task);
  if (!raw) return 0;
  const due = new Date(`${raw.slice(0, 10)}T00:00:00.000Z`);
  if (Number.isNaN(due.getTime()) || due >= today) return 0;
  return Math.ceil((today.getTime() - due.getTime()) / 86_400_000);
}

function wbsStaleDays(task: Record<string, unknown>, now: Date): number {
  const raw = String(task.updated_at ?? "");
  if (!raw) return 0;
  const updated = new Date(raw);
  if (Number.isNaN(updated.getTime()) || updated >= now) return 0;
  return Math.floor((now.getTime() - updated.getTime()) / 86_400_000);
}

function wbsRescueScore(task: Record<string, unknown>, now: Date): number {
  const today = new Date(now.toISOString().slice(0, 10));
  const status = String(task.status ?? "");
  const overdueDays = wbsOverdueDays(task, today);
  const staleDays = wbsStaleDays(task, now);
  return (status === "blocked" ? 500 : 0) +
    (overdueDays * 30) +
    (staleDays >= 3 ? staleDays * 12 : 0) +
    (wbsPriorityRank(task.priority) * 25) +
    (isFeatureRequestTask(task) ? 40 : 0) +
    (status === "in_progress" ? 20 : 0);
}

function buildWbsWorkload(tasks: Array<Record<string, unknown>>, now: Date) {
  const today = new Date(now.toISOString().slice(0, 10));
  const workload = WBS_INSTANCE_VALUES.map((instance) => {
    const laneTasks = tasks.filter((task) => wbsTaskLane(task) === instance);
    const openTasks = laneTasks.filter((task) =>
      WBS_OPEN_STATUSES.includes(String(task.status ?? ""))
    );
    const blockedTasks = openTasks.filter((task) => task.status === "blocked").length;
    const overdueTasks = openTasks.filter((task) => wbsOverdueDays(task, today) > 0).length;
    const staleTasks = openTasks.filter((task) => wbsStaleDays(task, now) >= 3).length;
    const highPriorityTasks = openTasks.filter((task) => task.priority === "high").length;
    const rescueScore = openTasks.reduce((sum, task) => sum + wbsRescueScore(task, now), 0);
    return {
      instance,
      open_tasks: openTasks.length,
      blocked_tasks: blockedTasks,
      overdue_tasks: overdueTasks,
      stale_tasks: staleTasks,
      high_priority_tasks: highPriorityTasks,
      rescue_score: rescueScore,
    };
  });
  return workload.sort((a, b) => b.rescue_score - a.rescue_score || b.open_tasks - a.open_tasks);
}

function pickWbsRescueCandidate(
  tasks: Array<Record<string, unknown>>,
  targetInstance: string,
  now: Date,
): Record<string, unknown> | null {
  const candidates = tasks.filter((task) => {
    const lane = wbsTaskLane(task);
    const status = String(task.status ?? "");
    return lane !== targetInstance && WBS_OPEN_STATUSES.includes(status);
  });
  candidates.sort((a, b) => wbsRescueScore(b, now) - wbsRescueScore(a, now));
  return candidates.find((task) => wbsRescueScore(task, now) > 0) ?? candidates[0] ?? null;
}

function buildWbsRebalanceSuggestions(
  tasks: Array<Record<string, unknown>>,
  now: Date,
): Array<Record<string, unknown>> {
  const workload = buildWbsWorkload(tasks, now);
  const idleInstances = workload.filter((lane) => lane.open_tasks === 0).map((lane) => lane.instance);
  const suggestions: Array<Record<string, unknown>> = [];
  for (const target of idleInstances) {
    const candidate = pickWbsRescueCandidate(tasks, target, now);
    if (!candidate) continue;
    suggestions.push({
      target_instance: target,
      from_instance: wbsTaskLane(candidate),
      task_id: candidate.id,
      title: candidate.title,
      reason: "target_idle_and_source_has_stalled_work",
      rescue_score: wbsRescueScore(candidate, now),
    });
  }
  return suggestions;
}

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

// Generic CRUD on hub_data by source
async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("hub_data")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

// ===== Horse Racing Multi-Provider Ensemble (Windows版#94) =====
// Quota/failure 時に自動 fallback + 複数プロバイダーで1レースの予想を蓄積
// して精度を向上させる。shared chat 基盤 (ai-hub) と独立させているのは
// horse racing 固有のプロンプト・JSON schema・コスト追跡が混ざらないため。

type HorseProviderConfig = {
  provider: string;
  model: string;
  apiKeyEnv: string;
  estimatedCostUsd: number;
};

const HORSE_PROVIDER_CHAIN: HorseProviderConfig[] = [
  { provider: "google", model: "gemini-2.5-flash", apiKeyEnv: "GEMINI_API_KEY", estimatedCostUsd: 0.0005 },
  { provider: "openai", model: "gpt-4o-mini", apiKeyEnv: "OPENAI_API_KEY", estimatedCostUsd: 0.002 },
  { provider: "anthropic", model: "claude-haiku-4-5", apiKeyEnv: "ANTHROPIC_API_KEY", estimatedCostUsd: 0.003 },
  { provider: "xai", model: "grok-4-1-fast-non-reasoning", apiKeyEnv: "XAI_API_KEY", estimatedCostUsd: 0.002 },
];

type ProviderPredictionResult = {
  success: boolean;
  prediction?: {
    first: string;
    second: string;
    third: string;
    confidence: number;
    reasoning: string;
  };
  error?: {
    http_status?: number;
    reason: string;
    detail?: string;
    is_quota: boolean;
  };
  latency_ms: number;
};

function buildHorseRacePrompt(race: Record<string, unknown>, entries: Record<string, unknown>[]): string {
  const entryText = entries.map((e) =>
    `馬番${e.horse_number} ${e.horse_name} (騎手:${e.jockey ?? "不明"}, 単勝${e.win_odds ?? "?"}倍, ${e.popularity ?? "?"}番人気)`
  ).join("\n");
  return `競馬レース「${race.race_name}」(${race.venue ?? ""}/${race.course_type ?? "芝"}${race.distance ?? ""}m/${race.grade ?? ""}) の3連単予想をしてください。\n出走馬:\n${entryText}\n\nJSON形式のみで回答 (前後に説明文を入れない): {"first":"予想馬名1","second":"予想馬名2","third":"予想馬名3","confidence":0.0,"reasoning":"根拠"}`;
}

async function callProviderForHorsePrediction(
  cfg: HorseProviderConfig,
  prompt: string,
): Promise<ProviderPredictionResult> {
  const apiKey = Deno.env.get(cfg.apiKeyEnv) ?? "";
  if (!apiKey) {
    return {
      success: false,
      error: { reason: `${cfg.apiKeyEnv} not configured`, is_quota: false },
      latency_ms: 0,
    };
  }
  const startMs = Date.now();
  try {
    let res: Response;
    let rawText = "";

    if (cfg.provider === "google") {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${cfg.model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
        },
      );
      if (res.ok) {
        const data = await res.json() as { candidates?: Array<{ content: { parts: Array<{ text: string }> } }> };
        rawText = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      }
    } else if (cfg.provider === "openai" || cfg.provider === "xai") {
      const url = cfg.provider === "openai"
        ? "https://api.openai.com/v1/chat/completions"
        : "https://api.x.ai/v1/chat/completions";
      res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: cfg.model,
          messages: [
            { role: "system", content: "あなたは競馬予想AIです。必ずJSONのみで回答してください。" },
            { role: "user", content: prompt },
          ],
          temperature: 0.3,
          response_format: { type: "json_object" },
        }),
      });
      if (res.ok) {
        const data = await res.json() as { choices?: Array<{ message: { content: string } }> };
        rawText = data.choices?.[0]?.message?.content ?? "";
      }
    } else if (cfg.provider === "anthropic") {
      res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: cfg.model,
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }],
        }),
      });
      if (res.ok) {
        const data = await res.json() as { content?: Array<{ text: string }> };
        rawText = data.content?.[0]?.text ?? "";
      }
    } else {
      return {
        success: false,
        error: { reason: `unknown provider: ${cfg.provider}`, is_quota: false },
        latency_ms: Date.now() - startMs,
      };
    }

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      const isQuota = res.status === 429 ||
        /quota|rate.?limit|RESOURCE_EXHAUSTED|insufficient_quota/i.test(errText);
      return {
        success: false,
        error: {
          http_status: res.status,
          reason: `${cfg.provider} HTTP ${res.status}`,
          detail: errText.slice(0, 200),
          is_quota: isQuota,
        },
        latency_ms: Date.now() - startMs,
      };
    }

    let pred: Record<string, unknown>;
    try {
      pred = JSON.parse(rawText.replace(/```json\n?|\n?```/g, "").trim());
    } catch (parseErr) {
      return {
        success: false,
        error: {
          reason: `JSON.parse failed: ${parseErr}`,
          detail: rawText.slice(0, 200),
          is_quota: false,
        },
        latency_ms: Date.now() - startMs,
      };
    }

    return {
      success: true,
      prediction: {
        first: String(pred.first ?? ""),
        second: String(pred.second ?? ""),
        third: String(pred.third ?? ""),
        confidence: Number(pred.confidence ?? 0.5),
        reasoning: String(pred.reasoning ?? ""),
      },
      latency_ms: Date.now() - startMs,
    };
  } catch (err) {
    return {
      success: false,
      error: { reason: `exception: ${String(err).slice(0, 200)}`, is_quota: false },
      latency_ms: Date.now() - startMs,
    };
  }
}

async function persistEnsemblePrediction(
  admin: SupabaseClient,
  raceId: string,
  cfg: HorseProviderConfig,
  result: ProviderPredictionResult,
): Promise<void> {
  if (!result.success || !result.prediction) return;
  await admin.from("horse_race_predictions_ensemble").upsert({
    race_id: raceId,
    provider: cfg.provider,
    model: cfg.model,
    first_pick: result.prediction.first,
    second_pick: result.prediction.second,
    third_pick: result.prediction.third,
    confidence: result.prediction.confidence,
    reasoning: result.prediction.reasoning,
    prediction_json: result.prediction,
    estimated_cost_usd: cfg.estimatedCostUsd,
    latency_ms: result.latency_ms,
  }, { onConflict: "race_id,provider,model" });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ?? "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    // ── Stateless utilities (no auth needed) ────────────────────────────────
    if (action === "generate_password") {
      const length = Number(body.length ?? 16);
      const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-_";
      const arr = new Uint8Array(length);
      crypto.getRandomValues(arr);
      const password = Array.from(arr, (b) => chars[b % chars.length]).join("");
      return json({ success: true, password });
    }

    if (action === "generate_qr") {
      const text = String(body.text ?? "");
      const size = Number(body.size ?? 200);
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
      return json({ success: true, qr_url: qrUrl, text });
    }

    if (action === "convert_currency") {
      const from = String(body.from ?? "USD").toUpperCase();
      const to = String(body.to ?? "JPY").toUpperCase();
      const amount = Number(body.amount ?? 1);
      const res = await fetch(`https://open.er-api.com/v6/latest/${from}`).catch(() => null);
      if (!res || !res.ok) return json({ error: "Exchange rate API unavailable" }, 502);
      const rates = (await res.json() as { rates: Record<string, number> }).rates;
      const rate = rates[to];
      if (!rate) return json({ error: `Unknown currency: ${to}` }, 400);
      return json({ success: true, from, to, amount, rate, result: amount * rate });
    }

    if (action === "get_weather") {
      const city = String(body.city ?? "Tokyo");
      const res = await fetch(`https://wttr.in/${encodeURIComponent(city)}?format=j1`).catch(() => null);
      if (!res || !res.ok) return json({ error: "Weather API unavailable" }, 502);
      const data = await res.json() as Record<string, unknown>;
      return json({ success: true, city, weather: data });
    }

    if (action === "render_markdown") {
      // Client-side rendering preferred; return raw markdown with metadata
      const markdown = String(body.markdown ?? "");
      return json({ success: true, markdown, length: markdown.length });
    }

    if (action === "translate") {
      const text = String(body.text ?? "");
      const target = String(body.target ?? "ja");
      const source = String(body.source ?? "auto");
      const res = await fetch(
        `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${source}|${target}`
      ).catch(() => null);
      if (!res || !res.ok) return json({ error: "Translation API unavailable" }, 502);
      const result = await res.json() as { responseData?: { translatedText?: string } };
      return json({ success: true, original: text, translated: result.responseData?.translatedText ?? text, target });
    }

    // ── Horse Racing + WBS 自動化パイプライン (auth不要 — GitHub Actions / 全インスタンス hook対応) ─────────
    // PS#6 S22 (2026-04-20): wbs.* は SERVICE_ROLE_KEY で admin 操作 (全インスタンスの session hook / wrap-up 更新経路)
    if (action.startsWith("horseracing.") || action.startsWith("wbs.")) {
      switch (action) {
        case "horseracing.today": {
          const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
          const type = String(body.type ?? "all");
          
          let query = admin
            .from("horse_races")
            .select("*, horse_entries(*), horse_predictions(*), horse_results(*)")
            .eq("race_date", targetDate);
            
          if (type === "jra") query = query.eq("source", "jra");
          else if (type === "nar") query = query.eq("source", "nar");
            
          const { data: races, error: re } = await query.order("post_time", { ascending: true });
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [], date: targetDate });
        }
        case "horseracing.list_races": {
          const { data: races, error: re } = await admin
            .from("horse_races")
            .select("*, horse_predictions(id,first_pick,second_pick,third_pick,confidence), horse_results(first_place,second_place,third_place,is_prediction_correct,trifecta_paid)")
            .order("race_date", { ascending: false })
            .limit(50);
          if (re) throw new Error(re.message);
          return json({ success: true, races: races ?? [] });
        }
        case "horseracing.predict_all": {
          // Windows版#94: quota fallback chain 対応
          // 1) レース毎に HORSE_PROVIDER_CHAIN を順に試行 (quota時は次プロバイダー)
          // 2) 成功した予想を horse_predictions (互換維持) + horse_race_predictions_ensemble に両方記録
          // 3) 全プロバイダーquota時のみ残りレースを早期skip
          const targetDate = String(body.date ?? new Date().toISOString().split("T")[0]);
          const { data: races } = await admin.from("horse_races")
            .select("*, horse_entries(*), horse_predictions(id)")
            .eq("race_date", targetDate).eq("status", "scheduled");
          if (!races || races.length === 0) return json({ success: true, predictions: [], message: "本日のレースなし" });
          // deno-lint-ignore no-explicit-any
          const allUnpredicted = races.filter((r: any) => !r.horse_predictions || r.horse_predictions.length === 0);
          if (allUnpredicted.length === 0) return json({ success: true, predictions: [], message: "全レース予想済" });
          // Windows版#94b: EF 150s timeout 対策として 1 回あたり最大 limit 件まで処理
          // (4 providers × 長レースで 120s urllib timeout に到達するため)
          const maxBatch = Math.max(1, Math.min(50, Number(body.limit ?? 20)));
          const unpredicted = allUnpredicted.slice(0, maxBatch);
          const remaining = Math.max(0, allUnpredicted.length - unpredicted.length);
          const results: Array<Record<string, unknown>> = [];
          const failures: Array<Record<string, unknown>> = [];
          const providerStats: Record<string, { attempts: number; hits: number; quotas: number }> = {};
          for (const cfg of HORSE_PROVIDER_CHAIN) {
            providerStats[cfg.provider] = { attempts: 0, hits: 0, quotas: 0 };
          }
          const exhaustedProviders = new Set<string>();

          for (const race of unpredicted) {
            if (exhaustedProviders.size >= HORSE_PROVIDER_CHAIN.length) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: "skipped: all providers exhausted (quota)",
              });
              continue;
            }
            // deno-lint-ignore no-explicit-any
            const entries = (race.horse_entries as any[]) ?? [];
            if (entries.length < 3) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: `entries < 3 (${entries.length}頭)`,
              });
              continue;
            }
            const prompt = buildHorseRacePrompt(race, entries);
            let succeededCfg: HorseProviderConfig | null = null;
            let succeededResult: ProviderPredictionResult | null = null;
            const perRaceFailures: Array<Record<string, unknown>> = [];

            for (const cfg of HORSE_PROVIDER_CHAIN) {
              if (exhaustedProviders.has(cfg.provider)) continue;
              providerStats[cfg.provider].attempts += 1;
              const result = await callProviderForHorsePrediction(cfg, prompt);
              if (result.success) {
                providerStats[cfg.provider].hits += 1;
                succeededCfg = cfg;
                succeededResult = result;
                break;
              }
              perRaceFailures.push({
                provider: cfg.provider,
                model: cfg.model,
                reason: result.error?.reason,
                http_status: result.error?.http_status,
                is_quota: result.error?.is_quota ?? false,
              });
              if (result.error?.is_quota) {
                providerStats[cfg.provider].quotas += 1;
                exhaustedProviders.add(cfg.provider);
                console.warn(`[predict_all] ${cfg.provider} quota exceeded — fallback to next provider.`);
              }
            }

            if (!succeededCfg || !succeededResult || !succeededResult.prediction) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: "all providers failed",
                provider_failures: perRaceFailures,
              });
              continue;
            }

            // 1) ensemble table に記録 (プロバイダー別蓄積)
            await persistEnsemblePrediction(admin, race.id, succeededCfg, succeededResult);

            // 2) 互換維持: horse_predictions (代表1件) に最初の成功プロバイダー結果を入れる
            const pred = succeededResult.prediction;
            const { error: ie } = await admin.from("horse_predictions").upsert({
              race_id: race.id,
              first_pick: pred.first || entries[0].horse_name,
              second_pick: pred.second || entries[1].horse_name,
              third_pick: pred.third || entries[2].horse_name,
              confidence: pred.confidence,
              ai_reasoning: pred.reasoning,
              ai_model: `${succeededCfg.provider}:${succeededCfg.model}`,
            }, { onConflict: "race_id" });
            if (ie) {
              failures.push({
                race_id: race.id,
                race_name: race.race_name,
                reason: `horse_predictions upsert failed: ${ie.message}`,
              });
            } else {
              results.push({
                race_id: race.id,
                race_name: race.race_name,
                provider: succeededCfg.provider,
                model: succeededCfg.model,
                ...pred,
              });
            }
          }
          return json({
            success: true,
            predictions: results,
            count: results.length,
            failures,
            failure_count: failures.length,
            provider_stats: providerStats,
            exhausted_providers: Array.from(exhaustedProviders),
            remaining,
            batch_size: unpredicted.length,
            total_unpredicted: allUnpredicted.length,
          });
        }
        case "horseracing.predict_ensemble": {
          // 1レースに対し全プロバイダーで並列予想 → ensemble table に記録
          // body: { race_id, providers?: string[], force?: boolean }
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const whitelist: string[] | null = Array.isArray(body.providers) ? body.providers.map(String) : null;
          const force = Boolean(body.force ?? false);
          const { data: race, error: re } = await admin.from("horse_races")
            .select("*, horse_entries(*)")
            .eq("id", raceId)
            .maybeSingle();
          if (re) throw new Error(re.message);
          if (!race) return json({ error: "race not found" }, 404);
          // deno-lint-ignore no-explicit-any
          const entries = ((race as any).horse_entries as any[]) ?? [];
          if (entries.length < 3) return json({ error: `entries < 3 (${entries.length})` }, 400);

          const targetCfgs = whitelist
            ? HORSE_PROVIDER_CHAIN.filter((c) => whitelist.includes(c.provider))
            : HORSE_PROVIDER_CHAIN;
          if (targetCfgs.length === 0) return json({ error: "no providers selected" }, 400);

          // 既に予想済みの provider は skip (force=true でやり直し)
          let existing: Set<string> = new Set();
          if (!force) {
            const { data: ex } = await admin.from("horse_race_predictions_ensemble")
              .select("provider, model")
              .eq("race_id", raceId);
            existing = new Set((ex ?? []).map((r: Record<string, unknown>) => `${r.provider}:${r.model}`));
          }

          const prompt = buildHorseRacePrompt(race as Record<string, unknown>, entries);
          const jobs = targetCfgs
            .filter((cfg) => !existing.has(`${cfg.provider}:${cfg.model}`))
            .map(async (cfg) => {
              const result = await callProviderForHorsePrediction(cfg, prompt);
              if (result.success) {
                await persistEnsemblePrediction(admin, raceId, cfg, result);
              }
              return { cfg, result };
            });
          const settled = await Promise.all(jobs);
          const succeeded = settled.filter((s) => s.result.success);
          const failed = settled.filter((s) => !s.result.success);
          return json({
            success: true,
            race_id: raceId,
            attempted: settled.length,
            succeeded: succeeded.map((s) => ({
              provider: s.cfg.provider,
              model: s.cfg.model,
              prediction: s.result.prediction,
              latency_ms: s.result.latency_ms,
            })),
            failed: failed.map((s) => ({
              provider: s.cfg.provider,
              model: s.cfg.model,
              reason: s.result.error?.reason,
              is_quota: s.result.error?.is_quota ?? false,
            })),
            skipped_already_predicted: targetCfgs.length - settled.length,
          });
        }
        case "horseracing.consensus": {
          // 1レースの全予想をプロバイダー横断で集計しコンセンサスを返す
          // body: { race_id }
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const { data: preds, error: pe } = await admin.from("horse_race_predictions_ensemble")
            .select("provider, model, first_pick, second_pick, third_pick, confidence, reasoning, predicted_at")
            .eq("race_id", raceId)
            .order("predicted_at", { ascending: true });
          if (pe) throw new Error(pe.message);
          const rows = preds ?? [];
          if (rows.length === 0) {
            return json({ success: true, race_id: raceId, consensus: null, predictions: [] });
          }
          // 1着票数 + 信頼度加重集計
          const firstVotes: Record<string, { votes: number; weighted: number; providers: string[] }> = {};
          for (const p of rows) {
            const horse = String(p.first_pick ?? "").trim();
            if (!horse) continue;
            if (!firstVotes[horse]) firstVotes[horse] = { votes: 0, weighted: 0, providers: [] };
            firstVotes[horse].votes += 1;
            firstVotes[horse].weighted += Number(p.confidence ?? 0.5);
            firstVotes[horse].providers.push(`${p.provider}:${p.model}`);
          }
          const sortedFirst = Object.entries(firstVotes)
            .sort((a, b) => b[1].weighted - a[1].weighted);
          const top = sortedFirst[0];
          const agreementRate = top ? top[1].votes / rows.length : 0;
          return json({
            success: true,
            race_id: raceId,
            predictions: rows,
            total_providers: rows.length,
            consensus: top ? {
              first_pick: top[0],
              votes: top[1].votes,
              weighted_score: Math.round(top[1].weighted * 1000) / 1000,
              providers: top[1].providers,
              agreement_rate: Math.round(agreementRate * 1000) / 1000,
            } : null,
            first_pick_distribution: sortedFirst.map(([horse, v]) => ({
              horse,
              votes: v.votes,
              weighted: Math.round(v.weighted * 1000) / 1000,
              providers: v.providers,
            })),
          });
        }
        case "horseracing.provider_leaderboard": {
          const { data, error: le } = await admin.from("horse_provider_leaderboard")
            .select("*");
          if (le) throw new Error(le.message);
          return json({ success: true, leaderboard: data ?? [] });
        }
        case "horseracing.evaluate_accuracy": {
          // 結果確定済みレースの ensemble 予想を全てスコアリング
          // body: { race_id? } (指定時は1レース、省略時は最新50レース)
          const raceId = body.race_id ? String(body.race_id) : null;
          const resultsQuery = admin.from("horse_results")
            .select("race_id, first_place, second_place, third_place");
          const { data: resultsRows, error: resErr } = raceId
            ? await resultsQuery.eq("race_id", raceId)
            : await resultsQuery.order("created_at", { ascending: false }).limit(50);
          if (resErr) throw new Error(resErr.message);
          if (!resultsRows || resultsRows.length === 0) {
            return json({ success: true, evaluated: 0, message: "no finalized results" });
          }
          let evaluated = 0;
          for (const r of resultsRows as Array<Record<string, unknown>>) {
            const rid = String(r.race_id);
            const { data: preds } = await admin.from("horse_race_predictions_ensemble")
              .select("provider, model, first_pick, second_pick, third_pick")
              .eq("race_id", rid);
            for (const p of (preds ?? []) as Array<Record<string, unknown>>) {
              const firstCorrect = String(p.first_pick ?? "").trim() === String(r.first_place ?? "").trim();
              const trifectaCorrect = firstCorrect
                && String(p.second_pick ?? "").trim() === String(r.second_place ?? "").trim()
                && String(p.third_pick ?? "").trim() === String(r.third_place ?? "").trim();
              await admin.from("horse_prediction_accuracy").upsert({
                race_id: rid,
                provider: p.provider,
                model: p.model,
                predicted_first: p.first_pick,
                predicted_second: p.second_pick,
                predicted_third: p.third_pick,
                actual_first: r.first_place,
                actual_second: r.second_place,
                actual_third: r.third_place,
                first_correct: firstCorrect,
                trifecta_correct: trifectaCorrect,
              }, { onConflict: "race_id,provider,model" });
              evaluated += 1;
            }
          }
          return json({ success: true, evaluated, races_processed: resultsRows.length });
        }
        case "horseracing.predictions": {
          const { data: preds, error: pe } = await admin.from("horse_predictions")
            .select("*, horse_races(race_name,race_date,venue,grade,course_type,distance)")
            .order("created_at", { ascending: false }).limit(Number(body.limit ?? 50));
          if (pe) throw new Error(pe.message);
          const raceIds = (preds ?? []).map((p: Record<string, unknown>) => p.race_id as string).filter(Boolean);
          const resultsMap: Record<string, unknown> = {};
          if (raceIds.length > 0) {
            const { data: hrs } = await admin.from("horse_results")
              .select("race_id,first_place,second_place,third_place,trifecta_paid,is_prediction_correct")
              .in("race_id", raceIds);
            (hrs ?? []).forEach((r: Record<string, unknown>) => { resultsMap[r.race_id as string] = r; });
          }
          const enriched = (preds ?? []).map((p: Record<string, unknown>) => ({
            ...p, horse_results: resultsMap[p.race_id as string] ?? null,
          }));
          return json({ success: true, predictions: enriched });
        }
        case "horseracing.store_results": {
          const raceId = String(body.race_id ?? "");
          if (!raceId) return json({ error: "race_id required" }, 400);
          const pred = await admin.from("horse_predictions").select("first_pick,second_pick,third_pick").eq("race_id", raceId).maybeSingle();
          const isCorrect = pred.data
            ? (pred.data.first_pick === body.first_place && pred.data.second_pick === body.second_place && pred.data.third_pick === body.third_place)
            : null;
          const { error: re } = await admin.from("horse_results").upsert({
            race_id: raceId, first_place: body.first_place, second_place: body.second_place,
            third_place: body.third_place, trifecta_paid: body.trifecta_paid ?? null,
            winner_odds: body.winner_odds ?? null, is_prediction_correct: isCorrect,
          }, { onConflict: "race_id" });
          await admin.from("horse_races").update({ status: "completed" }).eq("id", raceId);
          if (re) throw new Error(re.message);
          return json({ success: true, is_correct: isCorrect });
        }
        case "horseracing.accuracy": {
          const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();
          const { data: recentHits } = await admin.from("horse_results")
            .select("race_id, is_prediction_correct, trifecta_paid, horse_races(race_name, race_date)")
            .eq("is_prediction_correct", true).order("fetched_at", { ascending: false }).limit(5);
          return json({ success: true, stats: stats ?? {}, recent_hits: recentHits ?? [] });
        }
        // ─── WBS (Work Breakdown Structure) actions (Win版#128) ─────────
        case "wbs.list_tasks": {
          // インスタンス + status でフィルタしてタスク一覧取得
          // body: { instance?: 'codex'|'vscode'|'win'|'ps1'..'ps6'|'web'|'mobile'|'schedule'|'gha',
          //        status?: 'pending'|'in_progress'|'completed'|'blocked',
          //        updated_since?: 'YYYY-MM-DDTHH:MM:SSZ' (ISO-8601),
          //        limit?: 50 }
          const inst = body.instance as string | undefined;
          const status = body.status as string | undefined;
          const updatedSince = body.updated_since as string | undefined;
          const limit = Math.min(Number(body.limit ?? 50), 200);
          let q = admin.from("wbs_tasks")
            .select("id, category, category_icon, category_order, title, description, instance, status, progress, start_date, end_date, milestone_code, priority, updated_at");
          if (inst && inst !== "all") {
            q = q.eq("instance", inst);
          }
          if (status) q = q.eq("status", status);
          if (updatedSince) q = q.gte("updated_at", updatedSince);
          const { data, error } = await q;
          if (error) throw new Error(error.message);
          const sortedTasks = [...(data ?? [])].sort(compareWbsTasks).slice(0, limit);
          // milestone 情報も同時取得
          const { data: milestones } = await admin.from("wbs_milestones")
            .select("code, name, target_date, goal_users, color");
          return json({
            success: true,
            tasks: sortedTasks,
            milestones: milestones ?? [],
            total: data?.length ?? 0,
          });
        }
        case "wbs.update_progress": {
          // body: { id, progress?: 0-100, status?: 'in_progress'|'completed'|'blocked',
          //        recovery_plan?: string, end_date?: 'YYYY-MM-DD' (リスケ用),
          //        planned_end_date?: 'YYYY-MM-DD', note?: string }
          // Win版#131 part 10: 遅延時 recovery_plan 必須化
          // Win版#131 part 14 / T2-Win: defense-in-depth EF validation
          //   DB trigger `wbs_enforce_recovery_plan_trg` も同仕様を block
          const id = String(body.id ?? "");
          if (!id) return json({ error: "id required" }, 400);
          const update: Record<string, unknown> = {};
          if (body.progress !== undefined) {
            const p = Math.max(0, Math.min(100, Number(body.progress)));
            update.progress = p;
            if (p === 100 && !body.status) update.status = "completed";
          }
          if (body.status) update.status = String(body.status);
          if (body.recovery_plan !== undefined) {
            update.recovery_plan = String(body.recovery_plan);
            update.recovery_planned_at = new Date().toISOString();
          }
          if (body.end_date !== undefined) {
            update.end_date = String(body.end_date);
            const { data: cur } = await admin.from("wbs_tasks")
              .select("rescheduled_count").eq("id", id).single();
            update.rescheduled_count =
              ((cur?.rescheduled_count as number) ?? 0) + 1;
          }
          if (body.planned_end_date !== undefined) {
            update.planned_end_date = String(body.planned_end_date);
          }
          if (Object.keys(update).length === 0) {
            return json({ error: "progress, status, recovery_plan, end_date, or planned_end_date required" }, 400);
          }

          // Win版#131 part 14 / T2-Win:
          // 遅延判定 = COALESCE(planned_end_date, end_date) < CURRENT_DATE AND status != 'completed'
          // 遅延中 + recovery_plan 空のまま保存しようとしたら EF level で 400 block
          // (DB trigger も同仕様を CHECK 違反として投げるが UX として事前検出)
          const willStatus = (update.status ?? null) as string | null;
          if (willStatus !== "completed") {
            const { data: cur } = await admin.from("wbs_tasks")
              .select("planned_end_date, end_date, recovery_plan, status")
              .eq("id", id).maybeSingle();
            if (cur) {
              const deadlineRaw =
                (update.planned_end_date as string | undefined) ??
                (cur.planned_end_date as string | null) ??
                (update.end_date as string | undefined) ??
                (cur.end_date as string | null);
              const recoveryPlanFinal =
                (update.recovery_plan as string | undefined) ??
                (cur.recovery_plan as string | null) ??
                "";
              const mergedStatus = willStatus ?? (cur.status as string | null);
              if (
                mergedStatus !== "completed" &&
                deadlineRaw &&
                new Date(deadlineRaw) <
                  new Date(new Date().toISOString().split("T")[0]) &&
                recoveryPlanFinal.trim().length === 0
              ) {
                return json({
                  error:
                    "遅延タスクには recovery_plan 必須 (deadline=" +
                    deadlineRaw + ")",
                  hint:
                    'recovery_plan 例: "Win版に並行で UI 着手", "scope 縮小: 5社→3社"',
                  code: "RECOVERY_PLAN_REQUIRED",
                }, 400);
              }
            }
          }

          const { data, error } = await admin.from("wbs_tasks")
            .update(update).eq("id", id)
            .select("id, title, status, progress, recovery_plan, end_date, planned_end_date, rescheduled_count")
            .single();
          if (error) {
            // DB trigger (wbs_enforce_recovery_plan_trg) が投げた場合は 400 に格上げ
            if (error.code === "23514" || /recovery_plan/.test(error.message)) {
              return json({
                error: error.message,
                code: "RECOVERY_PLAN_REQUIRED",
              }, 400);
            }
            throw new Error(error.message);
          }
          return json({ success: true, task: data });
        }
        case "wbs.delayed_tasks": {
          // Win版#131 part 10: 遅延中タスク一覧 (recovery_status: on_track / has_recovery_plan / delay_no_plan)
          const { data, error } = await admin.from("wbs_delayed_tasks_view")
            .select("*")
            .order("delay_days", { ascending: false });
          if (error) throw new Error(error.message);
          return json({ success: true, tasks: data ?? [] });
        }
        case "wbs.milestone_risk": {
          // Win版#131 part 14 / T9-Win: マイルストーン risk 一覧
          // (VSCode版 T9-VSCode で badge 表示に使用)
          // view `wbs_milestone_risk_view` 既存 (part 13 `20260420140000`)
          // defensive: view 未 deploy / 0 rows でも 200 返す
          try {
            const { data, error } = await admin
              .from("wbs_milestone_risk_view")
              .select("*");
            if (error) {
              return json({
                success: false,
                milestones: [],
                error: error.message,
              }, 200);
            }
            return json({ success: true, milestones: data ?? [] });
          } catch (e) {
            return json({
              success: false,
              milestones: [],
              error: String(e),
            }, 200);
          }
        }
        case "wbs.project_overview": {
          // Win版#131 part 20: プロジェクト全体概観 (AI 報告用)
          // Win版#131 part 23: defensive — view 未 deploy / 0 rows でも 200 返す
          try {
            const { data, error } = await admin
              .from("wbs_project_overview_view")
              .select("*").maybeSingle();
            if (error) {
              return json({ success: false, overview: null, error: error.message }, 200);
            }
            return json({ success: true, overview: data });
          } catch (e) {
            return json({ success: false, overview: null, error: String(e) }, 200);
          }
        }
        case "wbs.auto_repair_dependencies": {
          // Win版#131 part 20: 依存関係スケジュール自動修復
          // Win版#131 part 23: defensive — RPC 未 deploy でも 200 返す
          try {
            const { data, error } = await admin.rpc(
              "wbs_auto_repair_dependencies",
            );
            if (error) {
              return json({ success: false, repairs: [], error: error.message }, 200);
            }
            return json({ success: true, repairs: data ?? [] });
          } catch (e) {
            return json({ success: false, repairs: [], error: String(e) }, 200);
          }
        }
        case "wbs.ai_status_report": {
          // Win版#131 part 20: AI による WBS 概観レポート生成
          // Win版#131 part 23: defensive — view/RPC 失敗でも 200 返す
          // 1) overview view から health snapshot 取得
          // 2) ai-hub:provider.chat (groq) に prompt 投げる
          const { data: overview, error: oErr } = await admin
            .from("wbs_project_overview_view").select("*").maybeSingle();
          if (oErr) {
            return json({
              success: false,
              report: "WBS overview view 未 deploy または読み込み失敗",
              error: oErr.message,
              snapshot: null,
            }, 200);
          }
          const { data: delayed } = await admin
            .from("wbs_delayed_tasks_view")
            .select("title, instance, delay_days, recovery_plan, recovery_status")
            .order("delay_days", { ascending: false })
            .limit(10);
          const { data: risks } = await admin
            .from("wbs_milestone_risk_view").select("*");
          const prompt =
            `自分株式会社 WBS プロジェクト健全性 snapshot:\n\n` +
            `総タスク: ${overview?.total_tasks} (完了 ${overview?.done_tasks} / ` +
            `進行中 ${overview?.in_progress_tasks} / 未着手 ${overview?.pending_tasks} / ` +
            `ブロック ${overview?.blocked_tasks})\n` +
            `遅延: ${overview?.overdue_tasks} (うちリカバリー案未記入 ${overview?.overdue_no_recovery})\n` +
            `担当 instance 数: ${overview?.active_instances}\n` +
            `進行中タスクの平均進捗: ${overview?.avg_in_progress_pct}%\n` +
            `担当別: ${JSON.stringify(overview?.by_instance ?? {})}\n\n` +
            `遅延 TOP10:\n${(delayed ?? []).map((t: Record<string, unknown>, i: number) =>
              `${i + 1}. [${t.instance}] ${t.title} - ${t.delay_days}日遅延 - ${t.recovery_status}`).join("\n")}\n\n` +
            `マイルストーン risk:\n${(risks ?? []).map((m: Record<string, unknown>) =>
              `- ${m.code}: ${m.risk_status} (残${m.days_left}日 / 工数${m.remaining_hours}h / 利用可能${m.available_hours}h)`).join("\n")}\n\n` +
            `この snapshot を 300 字以内で経営者向けに「健康状態 / 即対処 / 提案」の 3 セクションで報告してください。`;
          try {
            const aiResp = await fetch(
              `${SUPABASE_URL}/functions/v1/ai-hub`,
              {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  action: "provider.chat",
                  provider: "groq",
                  message: prompt,
                }),
              },
            );
            const aiData = await aiResp.json() as Record<string, unknown>;
            return json({
              success: true,
              report: aiData.success === true
                ? String(aiData.text ?? "")
                : "AI レポート取得失敗 (Groq 未設定の可能性)",
              snapshot: { overview, delayed, risks },
            });
          } catch (e) {
            return json({
              success: false,
              report: "AI レポート生成エラー",
              error: String(e),
              snapshot: { overview, delayed, risks },
            }, 200);
          }
        }
        case "wbs.bulk_update": {
          // body: { updates: [{id, progress?, status?}, ...] }
          const updates = (body.updates as Array<Record<string, unknown>>) ?? [];
          if (updates.length === 0) return json({ error: "updates required" }, 400);
          const results: Array<Record<string, unknown>> = [];
          for (const u of updates) {
            const id = String(u.id ?? "");
            if (!id) { results.push({ error: "id required", input: u }); continue; }
            const upd: Record<string, unknown> = {};
            if (u.progress !== undefined) {
              const p = Math.max(0, Math.min(100, Number(u.progress)));
              upd.progress = p;
              if (p === 100 && !u.status) upd.status = "completed";
            }
            if (u.status) upd.status = String(u.status);
            if (Object.keys(upd).length === 0) {
              results.push({ id, skipped: "no fields" });
              continue;
            }
            const { error } = await admin.from("wbs_tasks").update(upd).eq("id", id);
            results.push({ id, success: !error, error: error?.message });
          }
          const ok = results.filter((r) => r.success).length;
          return json({ success: true, updated: ok, total: results.length, results });
        }
        case "wbs.add_task": {
          // body: { category, title, instance, owner_instance?, description?,
          //        priority?, end_date?, planned_end_date?, milestone_code? }
          // PS#6 S23 (2026-04-21): instance を required 化 (ALL leak 防止)
          // 2026-04-25: 'all' を廃止し、codex を正式な instance として追加。
          const category = String(body.category ?? "");
          const title = String(body.title ?? "");
          const instance = String(body.instance ?? "");
          const validInstances = WBS_INSTANCE_VALUES;
          const validOwnerInstances = validInstances;
          if (!category || !title) {
            return json({ error: "category and title required" }, 400);
          }
          if (!instance || !validInstances.includes(instance)) {
            return json({
              error: `instance required (one of: ${validInstances.join(", ")})`,
            }, 400);
          }
          const ownerInstance = body.owner_instance !== undefined
            ? String(body.owner_instance)
            : instance;
          if (!ownerInstance || !validOwnerInstances.includes(ownerInstance)) {
            return json({
              error:
                `owner_instance required (one of: ${validOwnerInstances.join(", ")})`,
            }, 400);
          }
          const { data, error } = await admin.from("wbs_tasks").insert({
            category,
            category_icon: String(body.category_icon ?? "📋"),
            title,
            description: body.description ?? null,
            instance,
            owner_instance: ownerInstance,
            status: "pending",
            progress: 0,
            priority: String(body.priority ?? "medium"),
            end_date: body.end_date ?? null,
            planned_end_date: body.planned_end_date ?? body.end_date ?? null,
            milestone_code: body.milestone_code ?? null,
          }).select("id, title, owner_instance").single();
          if (error) throw new Error(error.message);
          return json({ success: true, task: data });
        }
        case "wbs.priority_for_instance": {
          // 指定インスタンスの優先タスク TOP 5 を返す (session-start-check 用)
          // 担当なしの場合は他 instance の滞留タスクを自担当へ救援 reassign する。
          // body: { instance: 'codex'|'vscode'|'win'|'ps1'..'ps6'|'web'|'mobile'|'schedule'|'gha',
          //         auto_reassign?: true, limit?: 5 }
          const rawInstance = String(body.instance ?? "").trim();
          if (!rawInstance) return json({ error: "instance required" }, 400);
          if (!WBS_INSTANCE_VALUES.includes(rawInstance.toLowerCase()) &&
              !["windows", "ps"].includes(rawInstance.toLowerCase())) {
            return json({
              error: `instance must be one of: ${WBS_INSTANCE_VALUES.join(", ")}`,
            }, 400);
          }
          const inst = normalizeWbsInstance(rawInstance);
          const limit = Math.min(Math.max(Number(body.limit ?? 5), 1), 20);
          const autoReassign = parseBooleanish(body.auto_reassign ?? body.autoReassign, true);
          const taskSelect =
            "id, category, category_order, title, status, progress, priority, end_date, planned_end_date, updated_at, instance, owner_instance, recovery_plan";
          const { data, error } = await admin.from("wbs_tasks")
            .select(taskSelect)
            .eq("instance", inst)
            .in("status", ["pending", "in_progress", "blocked"]);
          if (error) throw new Error(error.message);
          let topTasks = ([...(data ?? [])] as Array<Record<string, unknown>>)
            .sort(compareWbsTasks)
            .slice(0, limit);

          const { data: allOpen, error: allErr } = await admin.from("wbs_tasks")
            .select(taskSelect)
            .in("status", ["pending", "in_progress", "blocked"]);
          if (allErr) throw new Error(allErr.message);
          const now = new Date();
          const openTasks = [...(allOpen ?? [])] as Array<Record<string, unknown>>;
          const workload = buildWbsWorkload(openTasks, now);
          const rebalanceSuggestions = buildWbsRebalanceSuggestions(openTasks, now);
          let reassignedTask: Record<string, unknown> | null = null;

          if (topTasks.length === 0 && autoReassign) {
            const candidate = pickWbsRescueCandidate(openTasks, inst, now);
            if (candidate) {
              const update: Record<string, unknown> = {
                instance: inst,
                owner_instance: inst,
              };
              const needsRecoveryPlan =
                wbsOverdueDays(candidate, new Date(now.toISOString().slice(0, 10))) > 0 &&
                String(candidate.recovery_plan ?? "").trim().length === 0;
              if (needsRecoveryPlan) {
                update.recovery_plan =
                  `担当作業が空いた ${inst} が救援として引き取り、次セッションで最小単位に分割して進める。`;
                update.recovery_planned_at = now.toISOString();
              }
              const { data: updated, error: updateErr } = await admin.from("wbs_tasks")
                .update(update)
                .eq("id", String(candidate.id))
                .select(taskSelect)
                .single();
              if (updateErr) throw new Error(updateErr.message);
              reassignedTask = updated as Record<string, unknown>;
              topTasks = [reassignedTask];
            }
          }

          // user タスク (手動操作が必要なタスク) も合わせて返す + Slack 通知
          const { data: userTasksRaw } = await admin.from("wbs_tasks")
            .select("id, title, category, status, progress, priority, end_date")
            .eq("instance", "user")
            .in("status", ["pending", "in_progress", "blocked"])
            .order("end_date", { ascending: true, nullsFirst: false })
            .limit(10);
          const userTasks = userTasksRaw ?? [];

          // Slack 通知: user タスクがある場合 (セッション開始時)
          if (userTasks.length > 0 && body.notify_slack !== false) {
            const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
            if (webhookUrl) {
              const icon = (p: string) => p === "high" ? "🔴" : p === "low" ? "🟢" : "🟡";
              const lines = [
                `🙋 *[WBS] ユーザー手動タスク ${userTasks.length} 件* (要対応)`,
                "",
                ...userTasks.slice(0, 5).map((t, i) => {
                  const due = t.end_date ? ` | 期限 ${t.end_date}` : "";
                  return `${i + 1}. ${icon(String(t.priority ?? "medium"))} *${t.title}* — ${t.category}${due}`;
                }),
                userTasks.length > 5 ? `…他 ${userTasks.length - 5} 件` : "",
                "",
                `🔗 https://my-web-app-b67f4.web.app/project-gantt`,
              ].filter((l) => l !== "");
              fetch(webhookUrl, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ text: lines.join("\n"), mrkdwn: true }),
              }).catch(() => {/* fire-and-forget */});
            }
          }

          return json({
            success: true,
            instance: inst,
            top_tasks: topTasks,
            user_tasks: userTasks,
            user_tasks_count: userTasks.length,
            workload,
            rebalance_suggestions: rebalanceSuggestions,
            auto_reassign: autoReassign,
            reassigned_task: reassignedTask,
          });
        }
        case "wbs.instance_workload": {
          // body: { instance?: string } 任意。全 instance の負荷と救援候補を返す。
          const taskSelect =
            "id, category, category_order, title, status, progress, priority, end_date, planned_end_date, updated_at, instance, owner_instance, recovery_plan";
          const { data, error } = await admin.from("wbs_tasks")
            .select(taskSelect)
            .in("status", ["pending", "in_progress", "blocked"]);
          if (error) throw new Error(error.message);
          const now = new Date();
          const openTasks = [...(data ?? [])] as Array<Record<string, unknown>>;
          return json({
            success: true,
            instance: body.instance ? normalizeWbsInstance(body.instance) : null,
            workload: buildWbsWorkload(openTasks, now),
            rebalance_suggestions: buildWbsRebalanceSuggestions(openTasks, now),
          });
        }

        // ─── WBS Rebalance (Win版#132 part 17) ────────────────────────────
        // 自 instance に task が無い時、他 instance の滞留 task を suggest。
        // 設計: docs/WBS_REBALANCE.md
        case "wbs.rebalance_suggest": {
          const myInstance = String(body.my_instance ?? "");
          const limitN = Math.min(Number(body.limit ?? 5), 20);
          if (!myInstance) return json({ error: "my_instance required" }, 400);

          // 1. 自 instance の active task 数 fetch
          const { count: myActiveCount } = await admin.from("wbs_tasks")
            .select("id", { count: "exact", head: true })
            .eq("instance", myInstance)
            .in("status", ["pending", "in_progress", "blocked"]);

          // 2. 他 instance の active task 取得 (rebalance 候補)
          const { data: otherTasks, error } = await admin.from("wbs_tasks")
            .select("id, category, title, instance, owner_instance, status, progress, priority, end_date, updated_at, last_rebalanced_at")
            .neq("instance", myInstance)
            .in("status", ["pending", "in_progress", "blocked"])
            .neq("priority", "completed")
            .limit(200);
          if (error) throw new Error(error.message);

          // 3. 抑制ルール: PS 専任 / IPO 専決 / 期限直前は除外
          const NOW = Date.now();
          const HOUR = 3600 * 1000;
          const filtered = (otherTasks ?? []).filter((t) => {
            const cat = String(t.category ?? "");
            const title = String(t.title ?? "");
            // PS#1 専任 (Rule17)
            if (cat.startsWith("rule17-")) return false;
            // PS#2 専任 (T-1 dispatch)
            if (cat.startsWith("blog-") || title.includes("T-1")) return false;
            // PS#5 専任 (urgent on-call)
            if (t.priority === "high" && cat === "bug") return false;
            // IPO 専決 (CEO 固定)
            if (cat === "business-ipo") return false;
            // 期限直前 (1 日切ってる) は元担当継続
            if (t.end_date) {
              const dueMs = new Date(t.end_date).getTime();
              if (dueMs - NOW < 24 * HOUR && t.priority === "high") return false;
            }
            // 7 日以内に rebalance 済 = loop 防止
            if (t.last_rebalanced_at) {
              const lastMs = new Date(t.last_rebalanced_at).getTime();
              if (NOW - lastMs < 7 * 24 * HOUR) return false;
            }
            return true;
          });

          // 4. stale_score 計算
          const scored = filtered.map((t) => {
            let score = 0;
            const reasons: string[] = [];
            const dueMs = t.end_date ? new Date(t.end_date).getTime() : null;
            const updMs = t.updated_at ? new Date(t.updated_at).getTime() : null;

            // 期限ペナルティ
            if (dueMs !== null) {
              if (dueMs < NOW) { score += 50; reasons.push("期限超過"); }
              else if (dueMs - NOW < 3 * 24 * HOUR) { score += 30; reasons.push("期限間近 (3 日以内)"); }
              else if (dueMs - NOW < 7 * 24 * HOUR) { score += 15; reasons.push("期限間近 (7 日以内)"); }
            }
            // 進捗停滞ペナルティ
            if (updMs !== null) {
              const hoursSince = (NOW - updMs) / HOUR;
              if (hoursSince > 168) { score += 30; reasons.push("7 日停滞"); }
              else if (hoursSince > 72) { score += 20; reasons.push("3 日停滞"); }
              else if (hoursSince > 24) { score += 10; reasons.push("1 日停滞"); }
              // half-way 50-90% で 48h 以上 stuck
              const progress = Number(t.progress ?? 0);
              if (progress >= 50 && progress < 90 && hoursSince > 48) {
                score += 25;
                reasons.push("half-way stuck (50-90%)");
              }
            }
            // priority bonus
            if (t.priority === "high") { score += 20; reasons.push("priority=high"); }
            else if (t.priority === "medium") { score += 10; }

            return {
              id: t.id,
              title: t.title,
              category: t.category,
              current_instance: t.instance,
              current_owner: t.owner_instance,
              progress: t.progress,
              priority: t.priority,
              end_date: t.end_date,
              updated_at: t.updated_at,
              stale_score: score,
              stale_reasons: reasons,
            };
          });

          // 5. score 高い順 sort + limit
          const candidates = scored
            .filter((s) => s.stale_score > 0)
            .sort((a, b) => b.stale_score - a.stale_score)
            .slice(0, limitN);

          return json({
            success: true,
            my_instance: myInstance,
            my_active_count: myActiveCount ?? 0,
            candidates,
          });
        }

        // ─── WBS Claim Task (Win版#132 part 17) ───────────────────────────
        // 他 instance の task を自担当に変更。audit log + cooldown + guard。
        case "wbs.claim_task": {
          const taskId = String(body.task_id ?? "");
          const myInstance = String(body.my_instance ?? "");
          const reason = String(body.reason ?? "manual_review");
          const triggeredBy = String(body.triggered_by ?? "user");

          if (!taskId) return json({ error: "task_id required" }, 400);
          if (!myInstance) return json({ error: "my_instance required" }, 400);

          // 1. task fetch
          const { data: task, error: fetchErr } = await admin
            .from("wbs_tasks")
            .select("id, instance, owner_instance, status, category, title, last_rebalanced_at")
            .eq("id", taskId)
            .maybeSingle();
          if (fetchErr) throw new Error(fetchErr.message);
          if (!task) return json({ error: "task not found" }, 404);

          // 2. guard checks
          if (task.status === "completed") {
            return json({ error: "completed task cannot be claimed", reason: "completed_protect" }, 409);
          }
          if (task.instance === myInstance) {
            return json({ success: false, reason: "already_owner", task_id: taskId });
          }
          if (task.category === "business-ipo") {
            return json({ error: "business-ipo は CEO 専決 / claim 不可", reason: "ipo_protect" }, 403);
          }
          // 7 日 cooldown
          if (task.last_rebalanced_at) {
            const lastMs = new Date(task.last_rebalanced_at).getTime();
            if (Date.now() - lastMs < 7 * 24 * 3600 * 1000) {
              return json({ error: "7 日以内に既に rebalance 済 / cooldown 中", reason: "cooldown" }, 429);
            }
          }

          // 3. update wbs_tasks
          const fromInstance = String(task.instance ?? "");
          const fromOwner = String(task.owner_instance ?? "");
          const nowIso = new Date().toISOString();

          const { error: updErr } = await admin
            .from("wbs_tasks")
            .update({
              instance: myInstance,
              owner_instance: myInstance,
              status: task.status === "blocked" || task.status === "pending" ? "in_progress" : task.status,
              last_rebalanced_at: nowIso,
              updated_at: nowIso,
            })
            .eq("id", taskId);
          if (updErr) {
            return json({ error: `update_failed: ${updErr.message}` }, 500);
          }

          // increment rebalance_count (best-effort)
          try {
            const { error: countErr } = await admin.rpc("increment_wbs_rebalance_count", {
              p_task_id: taskId,
            });
            if (countErr) {
              console.warn(`increment_wbs_rebalance_count failed: ${countErr.message}`);
            }
          } catch (err) {
            console.warn(`increment_wbs_rebalance_count threw: ${String(err)}`);
          }

          // 4. audit log INSERT
          const { error: logErr } = await admin
            .from("wbs_rebalance_log")
            .insert({
              task_id: taskId,
              from_instance: fromInstance,
              to_instance: myInstance,
              from_owner: fromOwner,
              to_owner: myInstance,
              reason,
              triggered_by: triggeredBy,
              metadata: { task_title: task.title, task_category: task.category },
            });
          if (logErr) {
            // log failure は non-fatal
            console.warn(`rebalance_log insert failed: ${logErr.message}`);
          }

          return json({
            success: true,
            task_id: taskId,
            from_instance: fromInstance,
            to_instance: myInstance,
            status: "in_progress",
          });
        }
        case "horseracing.register_race": {
          const { data: r, error: re } = await admin.from("horse_races").insert({
            source: "manual", race_name: String(body.name ?? ""),
            race_date: String(body.date ?? new Date().toISOString().split("T")[0]),
            venue: body.venue ?? null, course_type: body.race_type ?? "芝",
            grade: body.grade ?? "未勝利", distance: body.distance ?? null, status: "scheduled",
          }).select("id").single();
          if (re) throw new Error(re.message);
          return json({ success: true, race_id: r?.id });
        }
        case "horseracing.stats": {
          const { data: stats } = await admin.from("horse_accuracy_stats").select("*").maybeSingle();
          return json({ success: true, stats: {
            totalBets: stats?.total_predictions ?? 0, wins: stats?.correct_count ?? 0,
            winRate: stats?.hit_rate_pct ?? 0, totalPayout: stats?.total_payout ?? 0,
            maxPayout: stats?.max_payout ?? 0,
          }});
        }
        default:
          return json({ error: `Unknown horseracing/wbs action: ${action}` }, 400);
      }
    }

        // ── Authenticated CRUD operations ────────────────────────────────────────
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Bookmarks ───────────────────────────────────────────────────────────
      case "bookmark.list": return json({ success: true, bookmarks: await listItems(admin, "bookmark", userId) });
      case "bookmark.add": {
        const item = await addItem(admin, "bookmark", userId, {
          url: body.url, title: body.title, tags: body.tags ?? [],
        });
        return json({ success: true, bookmark: item });
      }
      case "bookmark.delete": {
        await deleteItem(admin, "bookmark", userId, String(body.id ?? ""));
        return json({ success: true });
      }
      case "bookmark.mark_read": {
        const { data: bm } = await admin.from("hub_data")
          .select("metadata").eq("id", String(body.id ?? "")).eq("source", "bookmark").maybeSingle();
        if (!bm) return json({ success: false, error: "not found" }, 404);
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...(bm.metadata as Record<string, unknown>), read: true } })
          .eq("id", String(body.id ?? "")).eq("source", "bookmark");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "bookmark.sync": {
        const bookmarks = body.bookmarks as unknown[] ?? [];
        for (const bm of bookmarks) {
          await addItem(admin, "bookmark_sync", userId, bm as Record<string, unknown>);
        }
        return json({ success: true, synced: bookmarks.length });
      }

      // ── Quick Notes ─────────────────────────────────────────────────────────
      case "note.list": return json({ success: true, notes: await listItems(admin, "quick_note", userId) });
      case "note.add": {
        const item = await addItem(admin, "quick_note", userId, {
          content: body.content, title: body.title ?? "", tags: body.tags ?? [],
        });
        return json({ success: true, note: item });
      }
      case "note.delete": {
        await deleteItem(admin, "quick_note", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Goals ───────────────────────────────────────────────────────────────
      case "goal.list": return json({ success: true, goals: await listItems(admin, "goal", userId) });
      case "goal.add": {
        const item = await addItem(admin, "goal", userId, {
          title: body.title, description: body.description, deadline: body.deadline,
          timeframe: body.timeframe ?? "short",
          status: "active", milestones: body.milestones ?? [],
        });
        return json({ success: true, goal: item });
      }
      case "goal.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "goal");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "goal.delete": {
        await deleteItem(admin, "goal", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Contacts ────────────────────────────────────────────────────────────
      case "contact.list": return json({ success: true, contacts: await listItems(admin, "contact", userId) });
      case "contact.add": {
        const item = await addItem(admin, "contact", userId, {
          name: body.name, email: body.email, phone: body.phone,
          company: body.company, notes: body.notes,
        });
        return json({ success: true, contact: item });
      }
      case "contact.delete": {
        await deleteItem(admin, "contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Reading List ────────────────────────────────────────────────────────
      case "reading.list": return json({ success: true, items: await listItems(admin, "reading", userId) });
      case "reading.add": {
        const item = await addItem(admin, "reading", userId, {
          url: body.url, title: body.title, author: body.author ?? "", status: "unread",
        });
        return json({ success: true, item });
      }
      case "reading.mark_read": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "read", read_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "reading");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Tags ────────────────────────────────────────────────────────────────
      case "tag.list": return json({ success: true, tags: await listItems(admin, "tag", userId) });
      case "tag.create": {
        const item = await addItem(admin, "tag", userId, { name: body.name, color: body.color });
        return json({ success: true, tag: item });
      }
      case "tag.delete": {
        await deleteItem(admin, "tag", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Templates ───────────────────────────────────────────────────────────
      case "template.list": return json({ success: true, templates: await listItems(admin, "template", userId) });
      case "template.create": {
        const item = await addItem(admin, "template", userId, {
          name: body.name, content: body.content, category: body.category,
        });
        return json({ success: true, template: item });
      }
      case "template.use": {
        const templates = await listItems(admin, "template", userId);
        const found = templates.find((t) => (t.metadata as Record<string, unknown>)?.id === body.id);
        return json({ success: true, content: (found?.metadata as Record<string, unknown>)?.content ?? "" });
      }
      case "template.delete": {
        await deleteItem(admin, "template", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Address Book ─────────────────────────────────────────────────────────
      case "address.list": return json({ success: true, addresses: await listItems(admin, "address", userId) });
      case "address.add": {
        const item = await addItem(admin, "address", userId, {
          name: body.name, street: body.street, city: body.city,
          country: body.country, type: body.type ?? "home",
        });
        return json({ success: true, address: item });
      }
      case "address.delete": {
        await deleteItem(admin, "address", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Emergency Contacts ──────────────────────────────────────────────────
      case "emergency.list": return json({ success: true, contacts: await listItems(admin, "emergency_contact", userId) });
      case "emergency.add": {
        const item = await addItem(admin, "emergency_contact", userId, {
          name: body.name, phone: body.phone, relation: body.relation,
        });
        return json({ success: true, contact: item });
      }
      case "emergency.delete": {
        await deleteItem(admin, "emergency_contact", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Habits ──────────────────────────────────────────────────────────────
      case "habit.list": return json({ success: true, habits: await listItems(admin, "habit_definition", userId) });
      case "habit.create": {
        const item = await addItem(admin, "habit_definition", userId, {
          name: body.name, frequency: body.frequency ?? "daily",
          target: body.target ?? 1, points: body.points ?? 10,
        });
        return json({ success: true, habit: item });
      }
      case "habit.checkin": {
        const item = await addItem(admin, "habit_checkin", userId, {
          habit_id: body.habit_id, note: body.note ?? "", date: new Date().toISOString().slice(0, 10),
        });
        return json({ success: true, checkin: item });
      }
      case "habit.stats": {
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        return json({ success: true, total_checkins: checkins.length, checkins: checkins.slice(0, 30) });
      }

      // ── Habit Gamification (merged from habit-gamification EF) ───────────────
      case "habit.gamification.profile": {
        const habits = await listItems(admin, "habit_definition", userId, 20);
        const checkins = await listItems(admin, "habit_checkin", userId, 200);
        const points = checkins.length * 10;
        const level = Math.floor(points / 100) + 1;
        return json({ success: true, profile: { user_id: userId, points, level, habit_count: habits.length, checkin_count: checkins.length } });
      }
      case "habit.gamification.badges": {
        const badges = await listItems(admin, "habit_badge", userId);
        return json({ success: true, badges });
      }
      case "habit.gamification.challenges": {
        const challenges = await listItems(admin, "habit_challenge", userId, 10);
        return json({ success: true, challenges });
      }
      case "habit.gamification.leaderboard": {
        const { data, error: lbErr } = await admin.from("hub_data")
          .select("metadata")
          .eq("source", "habit_checkin")
          .order("created_at", { ascending: false })
          .limit(100);
        if (lbErr) throw new Error(lbErr.message);
        const counts: Record<string, number> = {};
        for (const row of data ?? []) {
          const uid = (row.metadata as Record<string, unknown>)?.user_id as string;
          if (uid) counts[uid] = (counts[uid] ?? 0) + 1;
        }
        const leaderboard = Object.entries(counts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 20)
          .map(([uid, count], i) => ({ rank: i + 1, user_id: uid, checkins: count }));
        return json({ success: true, leaderboard });
      }
      case "habit.gamification.award": {
        const badge = await addItem(admin, "habit_badge", userId, {
          badge_type: body.badge_type ?? "streak", title: body.title ?? "バッジ", earned_at: new Date().toISOString(),
        });
        return json({ success: true, badge });
      }

      // ── Pomodoro / Focus Timer ───────────────────────────────────────────────
      case "pomodoro.start": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25, started_at: new Date().toISOString(), status: "running",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.complete": {
        const item = await addItem(admin, "pomodoro", userId, {
          duration_min: body.duration_min ?? 25, completed_at: new Date().toISOString(), status: "done",
        });
        return json({ success: true, session: item });
      }
      case "pomodoro.history": return json({ success: true, sessions: await listItems(admin, "pomodoro", userId) });

      case "focus.start": {
        const item = await addItem(admin, "focus_timer", userId, {
          task: body.task_label ?? body.task ?? "",
          duration_minutes: body.duration_minutes ?? 25,
          started_at: new Date().toISOString(),
          status: "active",
        });
        return json({ success: true, session: item });
      }
      case "focus.complete": {
        const { data: fm } = await admin.from("hub_data")
          .select("metadata").eq("id", String(body.session_id ?? "")).eq("source", "focus_timer").maybeSingle();
        if (fm) {
          await admin.from("hub_data")
            .update({ metadata: { ...(fm.metadata as Record<string, unknown>), status: "completed", completed_at: new Date().toISOString() } })
            .eq("id", String(body.session_id ?? "")).eq("source", "focus_timer");
        }
        return json({ success: true });
      }
      case "focus.cancel": {
        const { data: fc } = await admin.from("hub_data")
          .select("metadata").eq("id", String(body.session_id ?? "")).eq("source", "focus_timer").maybeSingle();
        if (fc) {
          await admin.from("hub_data")
            .update({ metadata: { ...(fc.metadata as Record<string, unknown>), status: "cancelled" } })
            .eq("id", String(body.session_id ?? "")).eq("source", "focus_timer");
        }
        return json({ success: true });
      }
      case "focus.stats": {
        const days = parseInt(String(body.days ?? "30"), 10);
        const since = new Date(Date.now() - days * 86400000).toISOString();
        const allItems = await listItems(admin, "focus_timer", userId, 200);
        const recent = allItems.filter((i: Record<string, unknown>) => String(i.created_at ?? "") >= since);
        const completed = recent.filter((i: Record<string, unknown>) => (i.metadata as Record<string, unknown>)?.status === "completed");
        const totalMinutes = completed.reduce((s: number, i: Record<string, unknown>) =>
          s + (Number((i.metadata as Record<string, unknown>)?.duration_minutes) || 25), 0);
        const focusScore = Math.min(100, Math.round(completed.length * 10));
        return json({
          success: true,
          sessions: recent.map((i: Record<string, unknown>) => ({
            ...(i.metadata as Record<string, unknown>), id: i.id, created_at: i.created_at,
          })),
          stats: { total_sessions: completed.length, total_minutes: totalMinutes, focus_score: focusScore },
        });
      }

      // ── Clipboard History ────────────────────────────────────────────────────
      case "clipboard.list": return json({ success: true, items: await listItems(admin, "clipboard", userId, 30) });
      case "clipboard.add": {
        const item = await addItem(admin, "clipboard", userId, { text: body.text, source: body.source ?? "manual" });
        return json({ success: true, item });
      }
      case "clipboard.clear": {
        await admin.from("hub_data")
          .delete().eq("source", "clipboard").filter("metadata->>user_id", "eq", userId);
        return json({ success: true });
      }

      // ── News / RSS ───────────────────────────────────────────────────────────
      case "rss.list_feeds": return json({ success: true, feeds: await listItems(admin, "rss_feed", userId) });
      case "rss.add_feed": {
        const item = await addItem(admin, "rss_feed", userId, { url: body.url, title: body.title });
        return json({ success: true, feed: item });
      }
      case "rss.fetch": {
        const feedUrl = String(body.url ?? "");
        const res = await fetch(feedUrl).catch(() => null);
        if (!res || !res.ok) return json({ error: "Cannot fetch feed" }, 502);
        const text = await res.text();
        return json({ success: true, content: text.slice(0, 5000) });
      }

      // ── Changelog ────────────────────────────────────────────────────────────
      case "changelog.list": return json({ success: true, entries: await listItems(admin, "changelog", userId) });
      case "changelog.create": {
        const item = await addItem(admin, "changelog", userId, {
          version: body.version, title: body.title, changes: body.changes ?? [],
        });
        return json({ success: true, entry: item });
      }

      // ── Mindmap ──────────────────────────────────────────────────────────────
      case "mindmap.list": return json({ success: true, maps: await listItems(admin, "mindmap", userId) });
      case "mindmap.create": {
        const item = await addItem(admin, "mindmap", userId, {
          title: body.title, nodes: body.nodes ?? [], edges: body.edges ?? [],
        });
        return json({ success: true, map: item });
      }
      case "mindmap.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId } })
          .eq("id", String(body.id ?? "")).eq("source", "mindmap");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "mindmap.delete": {
        await deleteItem(admin, "mindmap", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Polls & Forms ────────────────────────────────────────────────────────
      case "poll.list": return json({ success: true, polls: await listItems(admin, "poll", userId, 100) });
      case "poll.create": {
        const item = await addItem(admin, "poll", userId, {
          question: body.question, options: body.options ?? [], votes: {},
        });
        return json({ success: true, poll: item });
      }
      case "poll.vote": {
        const polls = await listItems(admin, "poll", userId, 100);
        const poll = polls.find((p) => p.id === body.poll_id);
        if (!poll) return json({ error: "Poll not found" }, 404);
        const meta = poll.metadata as Record<string, unknown>;
        const votes = (meta.votes as Record<string, number>) ?? {};
        votes[String(body.option ?? "")] = (votes[String(body.option ?? "")] ?? 0) + 1;
        await admin.from("hub_data").update({ metadata: { ...meta, votes } }).eq("id", poll.id);
        return json({ success: true, votes });
      }
      case "form.list": return json({ success: true, forms: await listItems(admin, "form", userId) });
      case "form.create": {
        const item = await addItem(admin, "form", userId, {
          title: body.title, fields: body.fields ?? [], responses: [],
        });
        return json({ success: true, form: item });
      }
      case "form.submit": {
        const item = await addItem(admin, "form_response", userId, {
          form_id: body.form_id, responses: body.responses ?? {},
        });
        return json({ success: true, response: item });
      }

      // ── Note Sharing ─────────────────────────────────────────────────────────
      case "note_share.create": {
        const shareId = crypto.randomUUID();
        const item = await addItem(admin, "note_share", userId, {
          share_id: shareId, content: body.content, title: body.title,
          expires_at: body.expires_at, is_public: body.is_public ?? true,
        });
        return json({ success: true, share_id: shareId, share: item });
      }
      case "note_share.get": {
        const { data } = await admin.from("hub_data")
          .select("metadata, created_at")
          .eq("source", "note_share")
          .filter("metadata->>share_id", "eq", String(body.share_id ?? ""))
          .single();
        return json({ success: true, note: data });
      }

      // ── Content Versioning ───────────────────────────────────────────────────
      case "version.list": return json({ success: true, versions: await listItems(admin, "content_version", userId) });
      case "version.create": {
        const item = await addItem(admin, "content_version", userId, {
          document_id: body.document_id, content: body.content, version: body.version ?? 1,
        });
        return json({ success: true, version: item });
      }

      // ── Password Vault ───────────────────────────────────────────────────────
      case "vault.list": return json({ success: true, entries: await listItems(admin, "password_vault", userId) });
      case "vault.add": {
        const item = await addItem(admin, "password_vault", userId, {
          site: body.site, username: body.username, encrypted_password: body.encrypted_password,
          notes: body.notes,
        });
        return json({ success: true, entry: item });
      }
      case "vault.delete": {
        await deleteItem(admin, "password_vault", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Virtual Pet ──────────────────────────────────────────────────────────
      case "pet.status": {
        const pets = await listItems(admin, "virtual_pet", userId, 1);
        if (pets.length === 0) {
          const pet = await addItem(admin, "virtual_pet", userId, {
            name: "たま", hunger: 50, happiness: 50, age_days: 0, last_fed: new Date().toISOString(),
          });
          return json({ success: true, pet });
        }
        return json({ success: true, pet: pets[0] });
      }
      case "pet.feed": {
        const { data: latest } = await admin.from("hub_data")
          .select("id, metadata").eq("source", "virtual_pet")
          .filter("metadata->>user_id", "eq", userId).order("created_at", { ascending: false }).limit(1).single();
        if (!latest) return json({ error: "No pet found" }, 404);
        const meta = latest.metadata as Record<string, unknown>;
        await admin.from("hub_data").update({
          metadata: { ...meta, hunger: Math.min(100, Number(meta.hunger ?? 50) + 20), last_fed: new Date().toISOString() },
        }).eq("id", latest.id);
        return json({ success: true, message: "Pet fed!" });
      }

      // ── Slack Integration ─────────────────────────────────────────────────────
      case "slack.post": {
        const webhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") ?? "";
        if (!webhookUrl) return json({ error: "SLACK_WEBHOOK_URL not configured" }, 503);
        const text = String(body.text ?? "");
        if (!text) return json({ error: "text is required" }, 400);
        const payload: Record<string, unknown> = { text };
        if (body.channel) payload.channel = body.channel;
        if (body.username) payload.username = body.username;
        const resp = await fetch(webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        if (!resp.ok) return json({ error: `Slack API error: ${resp.status}` }, 502);
        return json({ success: true, message: "Posted to Slack" });
      }

      case "slack.search": {
        const token = Deno.env.get("SLACK_BOT_TOKEN") ?? "";
        if (!token) return json({ error: "SLACK_BOT_TOKEN not configured" }, 503);
        const query = String(body.query ?? "");
        if (!query) return json({ error: "query is required" }, 400);
        const count = Math.min(Number(body.count ?? 10), 50);
        const params = new URLSearchParams({ query, count: String(count) });
        const resp = await fetch(`https://slack.com/api/search.messages?${params}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!resp.ok) return json({ error: `Slack API error: ${resp.status}` }, 502);
        const data = await resp.json() as Record<string, unknown>;
        if (!data.ok) return json({ error: String(data.error ?? "Slack API error") }, 502);
        const msgData = data.messages as Record<string, unknown> | undefined;
        const matches = (msgData?.matches as Record<string, unknown>[] | undefined) ?? [];
        const messages = matches.map((m) => ({
          text: m.text, user: m.username,
          channel: (m.channel as Record<string, unknown> | undefined)?.name,
          ts: m.ts,
        }));
        return json({ success: true, total: msgData?.total ?? 0, messages });
      }

      // ── Legal / Harvey Integration ───────────────────────────────────────────
      case "legal.harvey.complete":
      case "legal-assistant.harvey.complete":
      case "legal-assistant.review": {
        const result = await callHarveyCompletion(body);
        if (!result.ok) {
          return json({
            success: false,
            provider: "harvey",
            error: result.error,
            details: result.details ?? null,
          }, result.status);
        }
        return json({
          success: true,
          ...result.data,
        });
      }

      default:
        return json({
          error: `Unknown action: ${action}`,
          available_actions: [
            "generate_password", "generate_qr", "convert_currency", "get_weather", "render_markdown", "translate",
            "bookmark.list", "bookmark.add", "bookmark.delete", "bookmark.sync",
            "note.list", "note.add", "note.delete",
            "goal.list", "goal.add", "goal.update", "goal.delete",
            "contact.list", "contact.add", "contact.delete",
            "reading.list", "reading.add", "reading.mark_read",
            "tag.list", "tag.create", "tag.delete",
            "template.list", "template.create", "template.use", "template.delete",
            "address.list", "address.add", "address.delete",
            "emergency.list", "emergency.add", "emergency.delete",
            "habit.list", "habit.create", "habit.checkin", "habit.stats",
            "pomodoro.start", "pomodoro.complete", "pomodoro.history",
            "focus.start",
            "clipboard.list", "clipboard.add", "clipboard.clear",
            "rss.list_feeds", "rss.add_feed", "rss.fetch",
            "changelog.list", "changelog.create",
            "mindmap.list", "mindmap.create", "mindmap.update", "mindmap.delete",
            "poll.list", "poll.create", "poll.vote", "form.create", "form.submit",
            "note_share.create", "note_share.get",
            "version.list", "version.create",
            "vault.list", "vault.add", "vault.delete",
            "pet.status", "pet.feed",
            "horseracing.today", "horseracing.list_races", "horseracing.predict_all",
            "horseracing.predict_ensemble", "horseracing.consensus",
            "horseracing.provider_leaderboard", "horseracing.evaluate_accuracy",
            "horseracing.predictions", "horseracing.store_results", "horseracing.accuracy",
            "horseracing.register_race", "horseracing.stats",
            "slack.post", "slack.search",
            "wbs.notify_user_tasks",
            "legal.harvey.complete",
            "legal-assistant.harvey.complete",
            "legal-assistant.review",
          ],
        }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
