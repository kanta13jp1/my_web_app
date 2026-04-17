// ai-hub — AI・エージェント・AI大学統合EF
// Merges (16 EFs): daily-judgment, ai-search, ai-suggest-tags, ai-secretary,
//   ai-summarizer, agent-hub, virtual-organization, my-ai-agent,
//   generate-daily-challenges, trigger-analysis, analyze-reality,
//   local-election-intelligence, ai-university-content,
//   ai-university-streaks, ai-university-badges
// NOTE: ai-assistant stays standalone (1079 lines, complex multi-provider logic)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const QUIZ_MASTER_3 = {
  badge_id: "quiz_master_3",
  badge_name: "クイズ3冠",
  icon_emoji: "🥉",
  condition: "3社以上でクイズ正解",
};
const QUIZ_MASTER_ALL = {
  badge_id: "quiz_master_all",
  badge_name: "全社制覇",
  icon_emoji: "🏆",
  condition: "全アクティブプロバイダーでクイズ正解",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

// AI大学プロバイダー統一呼び出し設定 (Phase 2)
// OpenAI 互換 + 独自 API の chat completion エンドポイントを束ねる
type ProviderConfig = {
  displayName: string;
  envKey: string;
  chatUrl: string;
  defaultModel: string;
  extraHeaders?: Record<string, string>;
  buildBody: (messages: unknown[], model: string) => Record<string, unknown>;
  parseResponse: (data: unknown) => string;
};

function pick(obj: unknown, ...path: (string | number)[]): unknown {
  let cur: unknown = obj;
  for (const key of path) {
    if (cur === null || cur === undefined) return undefined;
    if (typeof key === "number" && Array.isArray(cur)) {
      cur = cur[key];
    } else if (typeof cur === "object") {
      cur = (cur as Record<string, unknown>)[String(key)];
    } else {
      return undefined;
    }
  }
  return cur;
}

const OPENAI_COMPAT_BODY = (messages: unknown[], model: string) => ({
  model,
  messages,
  max_tokens: 512,
  temperature: 0.7,
});
const OPENAI_COMPAT_PARSE = (data: unknown): string =>
  String(pick(data, "choices", 0, "message", "content") ?? "");

const PROVIDER_CONFIGS: Record<string, ProviderConfig> = {
  // OpenAI 互換グループ (7社)
  openai: {
    displayName: "OpenAI",
    envKey: "OPENAI_API_KEY",
    chatUrl: "https://api.openai.com/v1/chat/completions",
    defaultModel: "gpt-4o-mini",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  x: {
    displayName: "xAI Grok",
    envKey: "XAI_API_KEY",
    chatUrl: "https://api.x.ai/v1/chat/completions",
    defaultModel: "grok-2-latest",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  deepseek: {
    displayName: "DeepSeek",
    envKey: "DEEPSEEK_API_KEY",
    chatUrl: "https://api.deepseek.com/v1/chat/completions",
    defaultModel: "deepseek-chat",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  groq: {
    displayName: "Groq",
    envKey: "GROQ_API_KEY",
    chatUrl: "https://api.groq.com/openai/v1/chat/completions",
    defaultModel: "llama-3.3-70b-versatile",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  sambanova: {
    displayName: "SambaNova",
    envKey: "SAMBANOVA_API_KEY",
    chatUrl: "https://api.sambanova.ai/v1/chat/completions",
    defaultModel: "Meta-Llama-3.3-70B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  openrouter: {
    displayName: "OpenRouter",
    envKey: "OPENROUTER_API_KEY",
    chatUrl: "https://openrouter.ai/api/v1/chat/completions",
    defaultModel: "openai/gpt-4o-mini",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  arcee_ai: {
    displayName: "Arcee AI Trinity",
    envKey: "ARCEE_API_KEY",
    chatUrl: "https://api.arcee.ai/v1/chat/completions",
    defaultModel: "trinity-mini",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  fireworks_ai: {
    displayName: "Fireworks AI",
    envKey: "FIREWORKS_API_KEY",
    chatUrl: "https://api.fireworks.ai/inference/v1/chat/completions",
    defaultModel: "accounts/fireworks/models/llama-v3p3-70b-instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  together_ai: {
    displayName: "Together AI",
    envKey: "TOGETHER_API_KEY",
    chatUrl: "https://api.together.xyz/v1/chat/completions",
    defaultModel: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  mistral: {
    displayName: "Mistral AI",
    envKey: "MISTRAL_API_KEY",
    chatUrl: "https://api.mistral.ai/v1/chat/completions",
    defaultModel: "mistral-small-latest",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  perplexity: {
    displayName: "Perplexity",
    envKey: "PERPLEXITY_API_KEY",
    chatUrl: "https://api.perplexity.ai/chat/completions",
    defaultModel: "sonar",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  // Cohere も Bearer + body スキーマが OpenAI 非互換
  cohere: {
    displayName: "Cohere",
    envKey: "COHERE_API_KEY",
    chatUrl: "https://api.cohere.com/v2/chat",
    defaultModel: "command-r-plus-08-2024",
    buildBody: (messages, model) => ({ model, messages }),
    parseResponse: (data) =>
      String(pick(data, "message", "content", 0, "text") ?? ""),
  },
  // Anthropic は x-api-key ヘッダ認証 — provider.chat ハンドラ側で Authorization を抑制する
  anthropic: {
    displayName: "Anthropic Claude",
    envKey: "ANTHROPIC_API_KEY",
    chatUrl: "https://api.anthropic.com/v1/messages",
    defaultModel: "claude-haiku-4-5-20251001",
    buildBody: (messages, model) => ({
      model,
      max_tokens: 512,
      messages: (messages as { role: string; content: string }[]).filter(
        (m) => m.role !== "system",
      ),
    }),
    parseResponse: (data) => String(pick(data, "content", 0, "text") ?? ""),
  },
  // Google Gemini は Bearer ではなく ?key=xxx クエリ認証 — provider.chat で特殊分岐
  google: {
    displayName: "Google Gemini",
    envKey: "GEMINI_API_KEY",
    chatUrl:
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
    defaultModel: "gemini-2.5-flash",
    buildBody: (messages, _model) => ({
      contents: (messages as { role: string; content: string }[]).map((m) => ({
        role: m.role === "assistant" ? "model" : "user",
        parts: [{ text: m.content }],
      })),
    }),
    parseResponse: (data) =>
      String(pick(data, "candidates", 0, "content", "parts", 0, "text") ?? ""),
  },
  cerebras: {
    displayName: "Cerebras",
    envKey: "CEREBRAS_API_KEY",
    chatUrl: "https://api.cerebras.ai/v1/chat/completions",
    defaultModel: "llama-3.3-70b",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  nvidia: {
    displayName: "NVIDIA NIM",
    envKey: "NVIDIA_API_KEY",
    chatUrl: "https://integrate.api.nvidia.com/v1/chat/completions",
    defaultModel: "meta/llama-3.1-70b-instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  moonshot: {
    displayName: "Moonshot (Kimi)",
    envKey: "MOONSHOT_API_KEY",
    chatUrl: "https://api.moonshot.cn/v1/chat/completions",
    defaultModel: "moonshot-v1-8k",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  ai21: {
    displayName: "AI21 Jamba",
    envKey: "AI21_API_KEY",
    chatUrl: "https://api.ai21.com/studio/v1/chat/completions",
    defaultModel: "jamba-1.5-mini",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  "01ai": {
    displayName: "01.AI (Yi)",
    envKey: "YI_API_KEY",
    chatUrl: "https://api.lingyiwanwu.com/v1/chat/completions",
    defaultModel: "yi-lightning",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  zhipu: {
    displayName: "Zhipu AI (GLM)",
    envKey: "ZHIPU_API_KEY",
    chatUrl: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
    defaultModel: "glm-4-flash",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  qwen: {
    displayName: "Alibaba Qwen",
    envKey: "DASHSCOPE_API_KEY",
    chatUrl:
      "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
    defaultModel: "qwen-plus",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  inflection: {
    displayName: "Inflection Pi",
    envKey: "INFLECTION_API_KEY",
    chatUrl: "https://api.inflection.ai/v1/chat/completions",
    defaultModel: "inflection_3_pi",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  allenai: {
    displayName: "Allen AI (OLMo)",
    envKey: "ALLENAI_API_KEY",
    chatUrl: "https://olmo-community.api.allenai.org/v1/chat/completions",
    defaultModel: "allenai/OLMo-2-0325-32B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
};

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

type CompanyBuilderCriterion = {
  key: string;
  label: string;
  weight: number;
  score: number;
  rationale: string;
};

type CompanyAgentBlueprint = {
  key: string;
  display_name: string;
  role_title: string;
  focus: string;
};

type CompanyTaskBlueprint = {
  title: string;
  description: string;
  manager_key: string;
  tool_key: string;
  priority: "low" | "normal" | "high";
  stage: string;
};

type CompanyBuilderPlan = {
  company_name: string;
  summary: string;
  offer: string;
  audience: string;
  business_model: string;
  launch_channels: string[];
  recommendation: string;
  criteria: CompanyBuilderCriterion[];
};

const COMPANY_MANAGER_BLUEPRINTS: CompanyAgentBlueprint[] = [
  {
    key: "chief",
    display_name: "Chief",
    role_title: "Business Generator",
    focus: "Turns the idea into an operating plan and delegates the first wave of work.",
  },
  {
    key: "max",
    display_name: "Max",
    role_title: "Product Manager",
    focus: "Shapes the MVP, scope, and roadmap from the company brief.",
  },
  {
    key: "ivy",
    display_name: "Ivy",
    role_title: "Marketing Lead",
    focus: "Owns positioning, channels, messaging, and launch momentum.",
  },
  {
    key: "sam",
    display_name: "Sam",
    role_title: "Sales Strategist",
    focus: "Designs the sales motion, outbound hooks, and validation calls.",
  },
  {
    key: "finn",
    display_name: "Finn",
    role_title: "Financial Analyst",
    focus: "Checks pricing, margin, CAC risk, and revenue shape.",
  },
  {
    key: "joy",
    display_name: "Joy",
    role_title: "Customer Success Lead",
    focus: "Defines onboarding, retention loops, and support signals.",
  },
  {
    key: "lex",
    display_name: "Lex",
    role_title: "Legal Advisor",
    focus: "Flags compliance, policy, privacy, and contract concerns early.",
  },
];

const COMPANY_TOOL_BLUEPRINTS: CompanyAgentBlueprint[] = [
  { key: "atlas", display_name: "Atlas", role_title: "Architect", focus: "System architecture and technical tradeoffs." },
  { key: "maya", display_name: "Maya", role_title: "Designer", focus: "UX, structure, and interface direction." },
  { key: "kai", display_name: "Kai", role_title: "Frontend Developer", focus: "Customer-facing product implementation." },
  { key: "dev", display_name: "Dev", role_title: "Backend Developer", focus: "APIs, data flow, and server logic." },
  { key: "shield", display_name: "Shield", role_title: "Security Reviewer", focus: "Security, auth, privacy, and abuse review." },
  { key: "nova", display_name: "Nova", role_title: "Researcher", focus: "Market, competitors, pricing, and citations." },
  { key: "sage", display_name: "Sage", role_title: "Writer", focus: "Copy, docs, emails, and knowledge distillation." },
  { key: "piper", display_name: "Piper", role_title: "Content Strategist", focus: "Content calendar and editorial systems." },
  { key: "flux", display_name: "Flux", role_title: "Growth Operator", focus: "Acquisition loops and channel experiments." },
  { key: "echo", display_name: "Echo", role_title: "Email Operator", focus: "Lifecycle messaging and campaign sequencing." },
  { key: "scout", display_name: "Scout", role_title: "SEO Analyst", focus: "Search intent, pages, and ranking opportunities." },
  { key: "forge", display_name: "Forge", role_title: "Automation Builder", focus: "Workflow setup and operational automation." },
  { key: "pilot", display_name: "Pilot", role_title: "QA Engineer", focus: "Test passes, regressions, and release confidence." },
  { key: "pulse", display_name: "Pulse", role_title: "Analytics Lead", focus: "Metrics, instrumentation, and dashboards." },
  { key: "loom", display_name: "Loom", role_title: "Brand Strategist", focus: "Narrative, tone, and brand coherence." },
  { key: "spark", display_name: "Spark", role_title: "Experiment Lead", focus: "Hypothesis design and iteration loops." },
  { key: "orbit", display_name: "Orbit", role_title: "Integration Engineer", focus: "Connectors, APIs, and external systems." },
  { key: "beacon", display_name: "Beacon", role_title: "Sales Ops", focus: "Lead routing, pipelines, and qualification logic." },
  { key: "ledger", display_name: "Ledger", role_title: "Business Analyst", focus: "Unit economics and scenario modeling." },
  { key: "relay", display_name: "Relay", role_title: "Support Ops", focus: "Support workflows and service quality loops." },
  { key: "prism", display_name: "Prism", role_title: "Customer Research", focus: "User interviews, pain points, and retention insights." },
];

const COMPANY_CRITERIA_TEMPLATE: CompanyBuilderCriterion[] = [
  { key: "market_size", label: "Market size", weight: 20, score: 7, rationale: "" },
  { key: "competition_level", label: "Competition level", weight: 20, score: 6, rationale: "" },
  { key: "niche_uniqueness", label: "Niche uniqueness", weight: 15, score: 8, rationale: "" },
  { key: "revenue_potential", label: "Revenue potential", weight: 15, score: 7, rationale: "" },
  { key: "acquisition_cost", label: "Acquisition cost", weight: 15, score: 6, rationale: "" },
  { key: "channel_accessibility", label: "Channel accessibility", weight: 15, score: 7, rationale: "" },
];

const COMPANY_INITIAL_TASKS: CompanyTaskBlueprint[] = [
  {
    title: "Map the market and competitor set",
    description: "Build a fast market view, identify direct competitors, and capture the opening angle for this company.",
    manager_key: "chief",
    tool_key: "nova",
    priority: "high",
    stage: "gate",
  },
  {
    title: "Shape the MVP and architecture",
    description: "Turn the company brief into a first MVP scope, architecture outline, and a release sequence.",
    manager_key: "max",
    tool_key: "atlas",
    priority: "high",
    stage: "product",
  },
  {
    title: "Design landing page structure and voice",
    description: "Create the initial narrative, hero promise, and page sections that explain the offer clearly.",
    manager_key: "ivy",
    tool_key: "maya",
    priority: "normal",
    stage: "marketing",
  },
  {
    title: "Draft the first sales motion",
    description: "Outline the ICP, outreach hooks, qualification questions, and the first CTA path.",
    manager_key: "sam",
    tool_key: "beacon",
    priority: "normal",
    stage: "sales",
  },
  {
    title: "Model pricing and unit economics",
    description: "Estimate pricing, gross margin, CAC sensitivity, and the shortest route to positive economics.",
    manager_key: "finn",
    tool_key: "ledger",
    priority: "normal",
    stage: "finance",
  },
  {
    title: "Prepare onboarding and support loop",
    description: "Define onboarding milestones, support touchpoints, and the first retention feedback loop.",
    manager_key: "joy",
    tool_key: "relay",
    priority: "normal",
    stage: "success",
  },
  {
    title: "Review legal and compliance exposure",
    description: "List privacy, policy, and compliance issues that need an answer before launch.",
    manager_key: "lex",
    tool_key: "shield",
    priority: "high",
    stage: "legal",
  },
];

function clampScore(value: number): number {
  return Math.max(1, Math.min(10, value));
}

function capitalizeWord(value: string): string {
  if (value.length <= 1) return value.toUpperCase();
  return value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
}

function deriveCompanyName(idea: string): string {
  const cleaned = idea.replace(/\s+/g, " ").trim();
  if (cleaned === "") return "AI Company";
  const asciiWords = cleaned
    .replace(/[^A-Za-z0-9 ]+/g, " ")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 3)
    .map(capitalizeWord);
  if (asciiWords.length > 0) return asciiWords.join(" ");
  return `${cleaned.slice(0, 18)} Company`;
}

function slugify(value: string): string {
  const slug = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "business";
}

function extractJsonObject(raw: string): Record<string, unknown> | null {
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1].trim() : raw.trim();
  const start = candidate.indexOf("{");
  const end = candidate.lastIndexOf("}");
  const jsonText = start >= 0 && end > start ? candidate.slice(start, end + 1) : candidate;
  try {
    const parsed = JSON.parse(jsonText);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function computeOverallScore(criteria: CompanyBuilderCriterion[]): number {
  const totalWeight = criteria.reduce((sum, item) => sum + item.weight, 0) || 100;
  const weighted = criteria.reduce((sum, item) => sum + item.score * item.weight, 0) / totalWeight;
  return Math.round(weighted * 10) / 10;
}

function buildFallbackCompanyPlan(idea: string, threshold: number): CompanyBuilderPlan {
  const companyName = deriveCompanyName(idea);
  const criteria = COMPANY_CRITERIA_TEMPLATE.map((item, index) => {
    const adjustment = [0.4, -0.3, 0.8, 0.2, -0.2, 0.4][index] ?? 0;
    const heuristic = clampScore(6.4 + adjustment + Math.min(idea.length / 120, 1));
    return {
      ...item,
      score: Math.round(heuristic * 10) / 10,
      rationale: `Initial heuristic assessment for ${item.label.toLowerCase()} based on the idea wording and likely launch complexity.`,
    };
  });
  const overall = computeOverallScore(criteria);
  const passed = overall >= threshold;
  return {
    company_name: companyName,
    summary: `A focused AI-native business built from the idea: ${idea}`,
    offer: `Deliver a faster and more opinionated version of ${idea}`,
    audience: "Early adopters who already feel the pain and can validate the workflow quickly.",
    business_model: "Subscription with a paid pilot or concierge-assisted onboarding.",
    launch_channels: ["Direct outreach", "Founder-led content", "SEO landing pages"],
    recommendation: passed
      ? "The concept clears the first gate. Start with a narrow MVP and validate demand before expanding scope."
      : "The concept needs a sharper niche or cheaper channel before committing to a full build.",
    criteria,
  };
}

function buildCompanyPlanFromModel(raw: Record<string, unknown>, idea: string, threshold: number): CompanyBuilderPlan {
  const fallback = buildFallbackCompanyPlan(idea, threshold);
  const rawCriteria = Array.isArray(raw.criteria) ? raw.criteria : [];
  const criteria = COMPANY_CRITERIA_TEMPLATE.map((template, index) => {
    const source = rawCriteria[index];
    if (!source || typeof source !== "object" || Array.isArray(source)) {
      return fallback.criteria[index];
    }
    const candidate = source as Record<string, unknown>;
    return {
      key: asString(candidate.key) || template.key,
      label: asString(candidate.label) || template.label,
      weight: asNumber(candidate.weight, template.weight),
      score: clampScore(asNumber(candidate.score, fallback.criteria[index].score)),
      rationale: asString(candidate.rationale) || fallback.criteria[index].rationale,
    };
  });
  return {
    company_name: asString(raw.company_name) || fallback.company_name,
    summary: asString(raw.summary) || fallback.summary,
    offer: asString(raw.offer) || fallback.offer,
    audience: asString(raw.audience) || fallback.audience,
    business_model: asString(raw.business_model) || fallback.business_model,
    launch_channels: Array.isArray(raw.launch_channels)
      ? raw.launch_channels.map((item) => asString(item)).filter(Boolean).slice(0, 5)
      : fallback.launch_channels,
    recommendation: asString(raw.recommendation) || fallback.recommendation,
    criteria,
  };
}

async function generateCompanyPlan(idea: string, threshold: number, geminiKey: string): Promise<CompanyBuilderPlan> {
  const fallback = buildFallbackCompanyPlan(idea, threshold);
  if (geminiKey === "") return fallback;

  const prompt = [
    "You are generating the bootstrap plan for an AI company builder.",
    "Return JSON only.",
    "Score each criterion from 1 to 10.",
    `Idea: ${idea}`,
    `Pass threshold: ${threshold}`,
    `Use exactly these criteria keys in order: ${COMPANY_CRITERIA_TEMPLATE.map((item) => item.key).join(", ")}`,
    JSON.stringify({
      company_name: "string",
      summary: "string",
      offer: "string",
      audience: "string",
      business_model: "string",
      launch_channels: ["channel 1", "channel 2"],
      recommendation: "string",
      criteria: COMPANY_CRITERIA_TEMPLATE.map((item) => ({
        key: item.key,
        label: item.label,
        weight: item.weight,
        score: 7,
        rationale: "string",
      })),
    }),
  ].join("\n");

  const responseText = await callGemini(prompt, geminiKey);
  const parsed = extractJsonObject(responseText);
  return parsed ? buildCompanyPlanFromModel(parsed, idea, threshold) : fallback;
}

async function findAgentBySlug(admin: SupabaseClient, userId: string, slug: string) {
  const { data, error } = await admin
    .from("agents")
    .select("*")
    .eq("user_id", userId)
    .eq("slug", slug)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data as Record<string, unknown> | null;
}

async function ensureSharedToolAgents(admin: SupabaseClient, userId: string) {
  const toolIds: Record<string, string> = {};
  for (const blueprint of COMPANY_TOOL_BLUEPRINTS) {
    const slug = `company-tool-${blueprint.key}`;
    const existing = await findAgentBySlug(admin, userId, slug);
    if (existing?.id) {
      toolIds[blueprint.key] = String(existing.id);
      continue;
    }
    const { data, error } = await admin
      .from("agents")
      .insert({
        user_id: userId,
        slug,
        display_name: blueprint.display_name,
        role_title: blueprint.role_title,
        department: "AI Company Builder",
        status: "active",
        identity_prompt: blueprint.focus,
        permissions_summary: "Shared tool agent for AI Company Builder runs.",
        metadata: {
          system: "company_builder",
          layer: "tool",
          shared_pool: true,
          tool_key: blueprint.key,
          focus: blueprint.focus,
        },
      })
      .select("*")
      .single();
    if (error) throw new Error(error.message);
    toolIds[blueprint.key] = String(data.id);
  }
  return toolIds;
}

async function createManagerAgents(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  companySlug: string,
  companyName: string,
  idea: string,
) {
  const managerIds: Record<string, string> = {};
  for (const blueprint of COMPANY_MANAGER_BLUEPRINTS) {
    const slug = `${companySlug}-${companyId.slice(0, 8)}-${blueprint.key}`;
    const { data, error } = await admin
      .from("agents")
      .insert({
        user_id: userId,
        slug,
        display_name: blueprint.display_name,
        role_title: blueprint.role_title,
        department: companyName,
        status: "active",
        identity_prompt: `${blueprint.focus}\nCompany: ${companyName}\nIdea: ${idea}`,
        permissions_summary: "Dedicated manager agent for a single company instance.",
        metadata: {
          system: "company_builder",
          layer: "business",
          company_id: companyId,
          company_slug: companySlug,
          company_name: companyName,
          manager_key: blueprint.key,
          focus: blueprint.focus,
        },
      })
      .select("*")
      .single();
    if (error) throw new Error(error.message);
    managerIds[blueprint.key] = String(data.id);
  }
  return managerIds;
}

async function seedCompanyMemories(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  companyName: string,
  idea: string,
  plan: CompanyBuilderPlan,
  managerIds: Record<string, string>,
) {
  const inserts = COMPANY_MANAGER_BLUEPRINTS
    .filter((blueprint) => managerIds[blueprint.key])
    .map((blueprint) => ({
      user_id: userId,
      agent_id: managerIds[blueprint.key],
      memory_layer: "knowledge",
      source: "company_builder_bootstrap",
      content: `${companyName}: ${blueprint.focus}\nIdea: ${idea}\nOffer: ${plan.offer}`,
      metadata: {
        system: "company_builder",
        company_id: companyId,
        company_name: companyName,
        manager_key: blueprint.key,
      },
    }));
  if (inserts.length === 0) return;
  const { error } = await admin.from("agent_memories").insert(inserts);
  if (error) throw new Error(error.message);
}

function buildCompanyWorkflowSteps(companyName: string, plan: CompanyBuilderPlan) {
  return COMPANY_INITIAL_TASKS.map((task) => ({
    key: `${task.stage}-${task.tool_key}`,
    title: task.title,
    manager_key: task.manager_key,
    tool_key: task.tool_key,
    description: `${task.description} Focus company: ${companyName}.`,
    status: "queued",
  })).concat([
    {
      key: "launch-summary",
      title: "Summarize launch recommendation",
      manager_key: "chief",
      tool_key: "sage",
      description: `Condense the launch recommendation for ${companyName}. ${plan.recommendation}`,
      status: "queued",
    },
  ]);
}

async function seedCompanyTasks(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  companyName: string,
  plan: CompanyBuilderPlan,
  managerIds: Record<string, string>,
  toolIds: Record<string, string>,
) {
  const inserts = COMPANY_INITIAL_TASKS
    .filter((task) => managerIds[task.manager_key] && toolIds[task.tool_key])
    .map((task) => ({
      user_id: userId,
      supervisor_agent_id: managerIds[task.manager_key],
      assignee_agent_id: toolIds[task.tool_key],
      title: task.title,
      description: `${task.description}\nCompany: ${companyName}\nAudience: ${plan.audience}`,
      status: "queued",
      priority: task.priority,
      task_type: "company_builder_bootstrap",
      source: "company_builder_bootstrap",
      metadata: {
        system: "company_builder",
        company_id: companyId,
        company_name: companyName,
        manager_key: task.manager_key,
        tool_key: task.tool_key,
        stage: task.stage,
      },
    }));
  if (inserts.length === 0) return [];
  const { data, error } = await admin.from("agent_tasks").insert(inserts).select("*");
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function seedCompanyVault(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  companySlug: string,
  companyName: string,
  threshold: number,
  plan: CompanyBuilderPlan,
) {
  const overall = computeOverallScore(plan.criteria);
  const passed = overall >= threshold;
  const notes = [
    {
      title: `${companyName} Brief`,
      category: "company_builder",
      tags: ["ai-company-builder", companySlug, "brief"],
      content: [
        `# ${companyName}`,
        "",
        `Idea: ${plan.summary}`,
        "",
        `Offer: ${plan.offer}`,
        "",
        `Audience: ${plan.audience}`,
        "",
        `Business model: ${plan.business_model}`,
        "",
        `Launch channels: ${plan.launch_channels.join(", ")}`,
      ].join("\n"),
      metadata: {
        system: "company_builder",
        company_id: companyId,
        note_type: "brief",
        path: `companies/${companySlug}/brief.md`,
      },
    },
    {
      title: `${companyName} Gate`,
      category: "company_builder",
      tags: ["ai-company-builder", companySlug, "gate"],
      content: [
        `# ${companyName} Gate Analysis`,
        "",
        `Threshold: ${threshold.toFixed(1)}`,
        `Overall: ${overall.toFixed(1)}`,
        `Passed: ${passed ? "yes" : "no"}`,
        "",
        ...plan.criteria.map((item) => `- ${item.label}: ${item.score.toFixed(1)}/10 (${item.weight}%) - ${item.rationale}`),
        "",
        `Recommendation: ${plan.recommendation}`,
      ].join("\n"),
      metadata: {
        system: "company_builder",
        company_id: companyId,
        note_type: "gate",
        path: `companies/${companySlug}/gate.md`,
      },
    },
    {
      title: `${companyName} Operating System`,
      category: "company_builder",
      tags: ["ai-company-builder", companySlug, "operating-system"],
      content: [
        `# ${companyName} Operating System`,
        "",
        "Managers:",
        ...COMPANY_MANAGER_BLUEPRINTS.map((item) => `- ${item.display_name}: ${item.role_title} - ${item.focus}`),
        "",
        "Shared tool agents:",
        ...COMPANY_TOOL_BLUEPRINTS.map((item) => `- ${item.display_name}: ${item.role_title}`),
      ].join("\n"),
      metadata: {
        system: "company_builder",
        company_id: companyId,
        note_type: "operating_system",
        path: `companies/${companySlug}/operating-system.md`,
      },
    },
  ];

  const noteRows = [];
  for (const note of notes) {
    const item = await addItem(admin, "wiki_page", userId, {
      title: note.title,
      content: note.content,
      category: note.category,
      tags: note.tags,
      ...note.metadata,
      company_id: companyId,
    });
    noteRows.push(item);
  }
  return noteRows;
}

async function addCompanyAudit(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  resource: string,
  details: Record<string, unknown>,
) {
  await addItem(admin, "audit_trail", userId, {
    audit_action: "company_builder",
    company_id: companyId,
    resource,
    details: { company_id: companyId, ...details },
    timestamp: new Date().toISOString(),
  });
}

async function getCompanyBuilderDetail(admin: SupabaseClient, userId: string, companyId: string) {
  const { data: company, error: companyError } = await admin
    .from("hub_data")
    .select("id, metadata, created_at")
    .eq("id", companyId)
    .eq("source", "company_builder_company")
    .filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (companyError) throw new Error(companyError.message);
  if (!company) return null;

  const [
    managerAgentsResult,
    toolAgentsResult,
    tasksResult,
    memoriesResult,
    notesResult,
    workflowsResult,
    auditsResult,
  ] = await Promise.all([
    admin.from("agents").select("*")
      .eq("user_id", userId)
      .filter("metadata->>company_id", "eq", companyId)
      .order("created_at", { ascending: true }),
    admin.from("agents").select("*")
      .eq("user_id", userId)
      .filter("metadata->>system", "eq", "company_builder")
      .filter("metadata->>shared_pool", "eq", "true")
      .order("created_at", { ascending: true }),
    admin.from("agent_tasks").select("*")
      .eq("user_id", userId)
      .filter("metadata->>company_id", "eq", companyId)
      .order("created_at", { ascending: false }),
    admin.from("agent_memories").select("*")
      .eq("user_id", userId)
      .filter("metadata->>company_id", "eq", companyId)
      .order("created_at", { ascending: false })
      .limit(40),
    admin.from("hub_data").select("id, metadata, created_at")
      .eq("source", "wiki_page")
      .filter("metadata->>company_id", "eq", companyId)
      .order("created_at", { ascending: false }),
    admin.from("hub_data").select("id, metadata, created_at")
      .eq("source", "ai_workflow")
      .filter("metadata->>company_id", "eq", companyId)
      .order("created_at", { ascending: false }),
    admin.from("hub_data").select("id, metadata, created_at")
      .eq("source", "audit_trail")
      .filter("metadata->>company_id", "eq", companyId)
      .order("created_at", { ascending: false })
      .limit(40),
  ]);

  if (managerAgentsResult.error) throw new Error(managerAgentsResult.error.message);
  if (toolAgentsResult.error) throw new Error(toolAgentsResult.error.message);
  if (tasksResult.error) throw new Error(tasksResult.error.message);
  if (memoriesResult.error) throw new Error(memoriesResult.error.message);
  if (notesResult.error) throw new Error(notesResult.error.message);
  if (workflowsResult.error) throw new Error(workflowsResult.error.message);
  if (auditsResult.error) throw new Error(auditsResult.error.message);

  return {
    company,
    manager_agents: managerAgentsResult.data ?? [],
    tool_agents: toolAgentsResult.data ?? [],
    tasks: tasksResult.data ?? [],
    memories: memoriesResult.data ?? [],
    vault_notes: notesResult.data ?? [],
    workflows: workflowsResult.data ?? [],
    audit_entries: auditsResult.data ?? [],
  };
}

async function getUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await c.auth.getUser();
  return user?.id ?? null;
}

async function evaluateUniversityQuizMaster(admin: SupabaseClient, userId: string) {
  const { data: scoreRows, error: scoreErr } = await admin
    .from("ai_university_scores")
    .select("provider_id")
    .eq("user_id", userId)
    .eq("quiz_correct", true);
  if (scoreErr) throw new Error(scoreErr.message);

  const correctSet = new Set<string>();
  for (const row of scoreRows ?? []) {
    const providerId = asString((row as { provider_id?: unknown }).provider_id);
    if (providerId) correctSet.add(providerId);
  }

  const { data: providerRows, error: providerErr } = await admin
    .from("ai_university_content")
    .select("provider")
    .eq("is_active", true);
  if (providerErr) throw new Error(providerErr.message);

  const providerSet = new Set<string>();
  for (const row of providerRows ?? []) {
    const provider = asString((row as { provider?: unknown }).provider);
    if (provider) providerSet.add(provider);
  }

  const awarded: string[] = [];
  if (correctSet.size >= 3) {
    const { data, error } = await admin.rpc("award_ai_university_badge", {
      p_user_id: userId,
      p_badge_id: QUIZ_MASTER_3.badge_id,
      p_badge_name: QUIZ_MASTER_3.badge_name,
      p_icon_emoji: QUIZ_MASTER_3.icon_emoji,
      p_condition: QUIZ_MASTER_3.condition,
    });
    if (error) throw new Error(error.message);
    if (data === true) awarded.push(QUIZ_MASTER_3.badge_id);
  }

  if (providerSet.size > 0 && correctSet.size >= providerSet.size) {
    const { data, error } = await admin.rpc("award_ai_university_badge", {
      p_user_id: userId,
      p_badge_id: QUIZ_MASTER_ALL.badge_id,
      p_badge_name: QUIZ_MASTER_ALL.badge_name,
      p_icon_emoji: QUIZ_MASTER_ALL.icon_emoji,
      p_condition: QUIZ_MASTER_ALL.condition,
    });
    if (error) throw new Error(error.message);
    if (data === true) awarded.push(QUIZ_MASTER_ALL.badge_id);
  }

  return {
    correct_count: correctSet.size,
    total_providers: providerSet.size,
    awarded,
  };
}

async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("hub_data").select("id, metadata, created_at")
    .eq("source", source).filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false }).limit(limit);
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

async function _deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source).filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

async function callGemini(prompt: string, apiKey: string): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
    }
  );
  const data = await res.json() as { candidates?: [{ content: { parts: [{ text: string }] } }] };
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const body = req.method === "POST" ? await req.json() as Record<string, unknown> : {};
    const action = String(body.action ?? new URL(req.url).searchParams.get("action") ?? "");
    const userId = await getUserId(req);

    // Actions that require authentication
    const authRequired = [
      "secretary.task", "secretary.history",
      "summarize.text",
      "agent.list", "agent.create", "agent.run",
      "org.get",
      "my_agent.chat", "my_agent.history",
      "challenges.list",
      "trigger.analyze", "analyze.reality",
      "company_builder.list", "company_builder.get", "company_builder.bootstrap",
      // AI大学 v2 (P1〜P4)
      "quiz.fsrs_next", "quiz.fsrs_grade",
      "learner.update_profile",
      "quiz.evaluate", "quiz.explain",
      "voice.tts", "voice.stt",
    ];
    if (authRequired.includes(action) && !userId) {
      return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      case "judgment.get": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const today = new Date().toLocaleDateString("ja-JP");
        const prompt = `今日${today}の自己成長・キャリア・健康に関するAI判定をしてください。JSON: {"score":0-100,"judgment":"良好/注意/警戒","advice":"...", "focus_area":"..."}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "search.query": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `検索クエリ「${body.query}」に対して、関連する情報を5件列挙してください。JSON: {"results":[{"title":"...","summary":"...","relevance":0-100}]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, query: body.query, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "tags.suggest": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `次のテキストに適切なタグを5つ提案してください: "${body.text}". JSON: {"tags":["tag1","tag2","tag3","tag4","tag5"]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          const parsed = JSON.parse(text.replace(/```json\n?|\n?```/g, ""));
          return json({ success: true, tags: parsed.tags ?? [] });
        } catch {
          return json({ success: true, tags: [] });
        }
      }

      case "secretary.task": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `あなたはAI秘書です。以下のタスクを処理してください: ${body.task ?? body.message ?? ""}. 返答はJSON: {"result":"...","actions":[],"priority":"high|medium|low"}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "secretary.history": {
        const items = await listItems(admin, "secretary_log", userId!);
        return json({ success: true, history: items });
      }

      case "summarize.text": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
        const text = String(body.text ?? "");
        if (!text) return json({ error: "text required" }, 400);
        if (geminiKey) {
          const prompt = `次のテキストを日本語で200字以内に要約してください:\n\n${text}`;
          const result = await callGemini(prompt, geminiKey);
          await addItem(admin, "summary_log", userId!, { original_length: text.length, summary: result });
          return json({ success: true, summary: result });
        }
        if (openaiKey) {
          const r = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: { Authorization: `Bearer ${openaiKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ model: "gpt-4o-mini", messages: [{ role: "user", content: `200字以内で要約: ${text}` }], max_tokens: 300 }),
          });
          const d = await r.json() as { choices?: [{ message: { content: string } }] };
          const summary = d.choices?.[0]?.message?.content ?? "";
          return json({ success: true, summary });
        }
        return json({ error: "No AI API key configured" }, 503);
      }

      case "agent.list": {
        const items = await listItems(admin, "agent_config", userId!);
        return json({ success: true, agents: items });
      }

      case "agent.create": {
        const item = await addItem(admin, "agent_config", userId!, {
          name: body.name,
          role: body.role ?? "assistant",
          department: body.department ?? "general",
          personality: body.personality ?? {},
          status: "active",
        });
        return json({ success: true, agent: item });
      }

      case "agent.run": {
        const item = await addItem(admin, "agent_run_log", userId!, {
          agent_id: body.agent_id,
          task: body.task,
          status: "queued",
        });
        return json({ success: true, run: item });
      }

      case "org.get": {
        const agents = await listItems(admin, "agent_config", userId!, 20);
        return json({ success: true, org: { agents, departments: ["CEO", "CMO", "CTO", "CFO", "COO"] } });
      }

      case "my_agent.chat": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const history = await listItems(admin, "my_agent_history", userId!, 10);
        const recentContext = history.map((h) => {
          const m = h.metadata as Record<string, unknown>;
          return `User: ${m.message}\nAgent: ${m.response}`;
        }).join("\n");
        const prompt = `あなたは個人AIエージェントです。${recentContext ? "履歴:\n" + recentContext + "\n\n" : ""}ユーザーメッセージ: ${body.message}`;
        const response = await callGemini(prompt, geminiKey);
        await addItem(admin, "my_agent_history", userId!, { message: body.message, response });
        return json({ success: true, response });
      }

      case "my_agent.history": {
        const items = await listItems(admin, "my_agent_history", userId!);
        return json({ success: true, history: items });
      }

      case "challenges.list": {
        const today = new Date().toISOString().split("T")[0];
        const existing = await listItems(admin, "daily_challenge", userId!, 3);
        if (existing.length > 0) return json({ success: true, challenges: existing });
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ success: true, challenges: [] });
        const prompt = `今日${today}のAI・生産性・健康に関するチャレンジを3つ生成してください。JSON: {"challenges":[{"id":"1","title":"...","description":"...","points":10,"category":"ai|productivity|health"}]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          const parsed = JSON.parse(text.replace(/```json\n?|\n?```/g, ""));
          for (const c of (parsed.challenges ?? [])) {
            await addItem(admin, "daily_challenge", userId!, { ...c as Record<string, unknown>, date: today });
          }
          return json({ success: true, challenges: parsed.challenges ?? [] });
        } catch {
          return json({ success: true, challenges: [] });
        }
      }

      case "trigger.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `行動トリガー分析: ${JSON.stringify(body)}. 引き金となる感情・状況・パターンを分析してください。JSON: {"triggers":[],"recommendations":[],"risk_level":"low|medium|high"}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "analyze.reality": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `現実分析: ${body.situation ?? ""}. 客観的な状況評価と改善策を提案してください。JSON: {"assessment":"...","score":0-100,"recommendations":[],"next_steps":[]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "election.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 503);
        const prompt = `選挙情勢分析: 地域=${body.region}, 候補者=${JSON.stringify(body.candidates ?? [])}. 勝率予測と戦略提案をしてください。JSON: {"predictions":[],"strategy":"...","key_issues":[]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({ success: true, ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")) });
        } catch {
          return json({ success: true, text });
        }
      }

      case "company_builder.list": {
        const companies = await listItems(admin, "company_builder_company", userId!, 50);
        return json({ success: true, companies });
      }

      case "company_builder.get": {
        const companyId = asString(body.company_id);
        if (!companyId) return json({ error: "company_id required" }, 400);
        const detail = await getCompanyBuilderDetail(admin, userId!, companyId);
        if (!detail) return json({ error: "Company not found" }, 404);
        return json({ success: true, ...detail });
      }

      case "company_builder.bootstrap": {
        const idea = asString(body.idea);
        if (!idea) return json({ error: "idea required" }, 400);

        const threshold = Math.max(1, Math.min(10, asNumber(body.threshold, 7)));
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        const plan = await generateCompanyPlan(idea, threshold, geminiKey);
        const overallScore = computeOverallScore(plan.criteria);
        const passed = overallScore >= threshold;
        const companyName = plan.company_name;
        const companySlug = slugify(companyName);

        const companyRecord = await addItem(admin, "company_builder_company", userId!, {
          system: "company_builder",
          idea,
          threshold,
          company_name: companyName,
          company_slug: companySlug,
          summary: plan.summary,
          offer: plan.offer,
          audience: plan.audience,
          business_model: plan.business_model,
          launch_channels: plan.launch_channels,
          recommendation: plan.recommendation,
          criteria: plan.criteria,
          overall_score: overallScore,
          passed,
          manager_count: COMPANY_MANAGER_BLUEPRINTS.length,
          tool_agent_count: COMPANY_TOOL_BLUEPRINTS.length,
          status: passed ? "approved" : "revise",
        });

        const companyId = String(companyRecord.id);
        await addCompanyAudit(admin, userId!, companyId, "company_builder.bootstrap_requested", {
          company_name: companyName,
          overall_score: overallScore,
          passed,
        });

        const toolIds = await ensureSharedToolAgents(admin, userId!);
        const managerIds = await createManagerAgents(
          admin,
          userId!,
          companyId,
          companySlug,
          companyName,
          idea,
        );
        await seedCompanyMemories(admin, userId!, companyId, companyName, idea, plan, managerIds);
        const taskRows = await seedCompanyTasks(
          admin,
          userId!,
          companyId,
          companyName,
          plan,
          managerIds,
          toolIds,
        );
        const workflow = await addItem(admin, "ai_workflow", userId!, {
          system: "company_builder",
          company_id: companyId,
          name: `${companyName} Operating Workflow`,
          description: `Bootstrap workflow for ${companyName}`,
          template_key: "ai-company-builder",
          trigger_type: "manual",
          status: "active",
          steps: buildCompanyWorkflowSteps(companyName, plan),
        });
        const vaultNotes = await seedCompanyVault(
          admin,
          userId!,
          companyId,
          companySlug,
          companyName,
          threshold,
          plan,
        );
        await addCompanyAudit(admin, userId!, companyId, "company_builder.bootstrap_completed", {
          company_name: companyName,
          manager_count: Object.keys(managerIds).length,
          tool_agent_count: Object.keys(toolIds).length,
          task_count: taskRows.length,
          workflow_id: workflow.id,
          vault_note_count: vaultNotes.length,
        });

        const detail = await getCompanyBuilderDetail(admin, userId!, companyId);
        return json({
          success: true,
          company_id: companyId,
          overall_score: overallScore,
          passed,
          ...detail,
        });
      }

      case "university.content": {
        const { data } = await admin.from("ai_university_content")
          .select("*")
          .eq("provider", String(body.provider ?? ""))
          .eq("category", String(body.category ?? "news"))
          .order("published_at", { ascending: false })
          .limit(10);
        return json({ success: true, content: data ?? [] });
      }

      case "university.upsert": {
        const { error } = await admin.from("ai_university_content").upsert(
          {
            provider: body.provider,
            category: body.category ?? "news",
            title: body.title,
            content: body.content,
            published_at: body.published_at ?? new Date().toISOString().split("T")[0],
          },
          { onConflict: "provider,category" }
        );
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "university.streak": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data: streak } = await admin.from("ai_university_streaks")
          .select("*")
          .eq("user_id", userId)
          .maybeSingle();
        return json({ success: true, streak: streak ?? null });
      }

      case "university.streak_update": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data, error } = await admin.rpc("update_ai_university_streak", {
          p_user_id: userId,
        });
        if (error) throw new Error(error.message);
        const row = Array.isArray(data) && data.length > 0
          ? data[0] as { current_streak?: number; longest_streak?: number; is_new_streak_day?: boolean }
          : null;
        return json({
          success: true,
          current_streak: row?.current_streak ?? 1,
          longest_streak: row?.longest_streak ?? 1,
          is_new_streak_day: row?.is_new_streak_day ?? true,
        });
      }

      case "university.badges": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data: badges } = await admin.from("ai_university_badges")
          .select("*")
          .eq("user_id", userId)
          .order("awarded_at", { ascending: false });
        return json({ success: true, badges: badges ?? [] });
      }

      case "university.award_badge": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const badgeId = asString(body.badge_id ?? body.badge_type);
        const badgeName = asString(body.badge_name);
        if (!badgeId || !badgeName) return json({ error: "badge_id and badge_name required" }, 400);
        const { data, error } = await admin.rpc("award_ai_university_badge", {
          p_user_id: userId,
          p_badge_id: badgeId,
          p_badge_name: badgeName,
          p_icon_emoji: asString(body.icon_emoji),
          p_condition: asString(body.condition) || null,
        });
        if (error) throw new Error(error.message);
        return json({ success: true, newly_awarded: data === true });
      }

      case "university.record_score": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const providerId = asString(body.provider_id);
        if (!providerId) return json({ error: "provider_id required" }, 400);

        const quizCorrect = body.quiz_correct === true;
        const now = new Date().toISOString();
        const { data: existing, error: existingErr } = await admin
          .from("ai_university_scores")
          .select("id, quiz_correct")
          .eq("user_id", userId)
          .eq("provider_id", providerId)
          .maybeSingle();
        if (existingErr) throw new Error(existingErr.message);

        const row = existing as { id?: string; quiz_correct?: boolean } | null;
        const wasCorrect = row?.quiz_correct === true;
        const isNewProvider = row == null;
        const newlyCorrect = !wasCorrect && quizCorrect;

        if (row?.id) {
          const { error } = await admin
            .from("ai_university_scores")
            .update({
              quiz_correct: wasCorrect || quizCorrect,
              studied_at: now,
            })
            .eq("id", row.id);
          if (error) throw new Error(error.message);
        } else {
          const { error } = await admin
            .from("ai_university_scores")
            .insert({
              user_id: userId,
              provider_id: providerId,
              quiz_correct: quizCorrect,
              studied_at: now,
            });
          if (error) throw new Error(error.message);
        }

        let awardedBadges: string[] = [];
        let correctCount = 0;
        let totalProviders = 0;
        if (newlyCorrect) {
          const evaluation = await evaluateUniversityQuizMaster(admin, userId);
          awardedBadges = evaluation.awarded;
          correctCount = evaluation.correct_count;
          totalProviders = evaluation.total_providers;
        }

        return json({
          success: true,
          is_new_provider: isNewProvider,
          newly_correct: newlyCorrect,
          awarded_badges: awardedBadges,
          correct_count: correctCount,
          total_providers: totalProviders,
        });
      }

      // ── AI大学 v2: FSRS スペース反復 ────────────────────────────────────
      case "quiz.fsrs_next": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const provider = String(body.provider ?? "");
        const limit = Number(body.limit ?? 10);
        const { data, error } = await admin
          .from("ai_university_fsrs_cards")
          .select("*")
          .eq("user_id", userId)
          .eq("provider", provider)
          .lte("due_date", new Date().toISOString())
          .order("due_date", { ascending: true })
          .limit(limit);
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, cards: data ?? [] });
      }

      case "quiz.fsrs_grade": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const questionId = String(body.question_id ?? "");
        const provider = String(body.provider ?? "");
        const grade = Number(body.grade ?? 3);
        const { data: existing } = await admin
          .from("ai_university_fsrs_cards")
          .select("stability, reps, lapses")
          .eq("user_id", userId)
          .eq("provider", provider)
          .eq("question_id", questionId)
          .maybeSingle();
        const currentStability = (existing?.stability as number) ?? 1.0;
        const reps = ((existing?.reps as number) ?? 0) + 1;
        const lapses = grade === 1 ? ((existing?.lapses as number) ?? 0) + 1 : ((existing?.lapses as number) ?? 0);
        let newStability = currentStability;
        let daysUntilNext = 1;
        if (grade === 1) { newStability = Math.max(currentStability * 0.5, 0.5); daysUntilNext = 1; }
        else if (grade === 2) { newStability = currentStability * 0.8; daysUntilNext = Math.max(newStability, 1); }
        else if (grade === 3) { daysUntilNext = Math.max(currentStability, 1); }
        else { newStability = currentStability * 1.3; daysUntilNext = Math.max(newStability * 1.3, 1); }
        const nextDue = new Date();
        nextDue.setDate(nextDue.getDate() + Math.round(daysUntilNext));
        const state = grade === 1 ? "relearning" : reps > 2 ? "review" : "learning";
        const { error } = await admin
          .from("ai_university_fsrs_cards")
          .upsert({
            user_id: userId,
            provider,
            question_id: questionId,
            due_date: nextDue.toISOString(),
            stability: newStability,
            reps,
            lapses,
            last_review: new Date().toISOString(),
            state,
          }, { onConflict: "user_id,provider,question_id" });
        if (error) return json({ error: error.message }, 500);
        return json({ success: true, next_due: nextDue.toISOString(), stability: newStability });
      }

      // ── AI大学 v2: Memory Agent ──────────────────────────────────────────
      case "learner.update_profile": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const sessionSummary = String(body.session_summary ?? "");
        const scores = body.scores ?? [];
        const claudeKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
        if (!claudeKey) return json({ error: "ANTHROPIC_API_KEY not configured" }, 503);
        const prompt = `学習セッションのデータから構造化プロファイルを抽出してください。
セッションサマリー: ${sessionSummary}
スコアデータ: ${JSON.stringify(scores).slice(0, 2000)}
弱点プロバイダー・得意プロバイダー・学習スタイルをJSONで返してください。
形式: {"weak_providers":["..."],"strong_providers":["..."],"preferred_style":"visual|text|voice","insights":"..."}`;
        const claudeResp = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "x-api-key": claudeKey,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-6",
            max_tokens: 512,
            messages: [{ role: "user", content: prompt }],
          }),
        });
        const claudeData = await claudeResp.json() as Record<string, unknown>;
        const rawText = (claudeData.content as Array<{text: string}>)?.[0]?.text ?? "{}";
        let profileJson: Record<string, unknown> = {};
        try { profileJson = JSON.parse(rawText.replace(/```json\n?|\n?```/g, "").trim()); } catch { /* malformed */ }
        const { data: existingProfile } = await admin
          .from("ai_university_learner_profiles")
          .select("total_sessions")
          .eq("user_id", userId)
          .maybeSingle();
        await admin.from("ai_university_learner_profiles").upsert({
          user_id: userId,
          weak_providers: profileJson.weak_providers ?? [],
          strong_providers: profileJson.strong_providers ?? [],
          preferred_style: profileJson.preferred_style ?? "text",
          profile_json: profileJson,
          total_sessions: ((existingProfile?.total_sessions as number) ?? 0) + 1,
          updated_at: new Date().toISOString(),
        }, { onConflict: "user_id" });
        return json({ success: true, profile_json: profileJson });
      }

      // ── AI大学 v2: Hybrid LLM ────────────────────────────────────────────
      case "quiz.evaluate": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const question = String(body.question ?? "");
        const userAnswer = String(body.user_answer ?? "");
        const correctAnswer = String(body.correct_answer ?? "");
        const groqKey = Deno.env.get("GROQ_API_KEY") ?? "";
        if (!groqKey) return json({ error: "GROQ_API_KEY not configured" }, 503);
        const groqResp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: { "Authorization": `Bearer ${groqKey}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "llama-3.3-70b-versatile",
            max_tokens: 100,
            temperature: 0,
            messages: [{
              role: "user",
              content: `問題: ${question}\n模範回答: ${correctAnswer}\nユーザー回答: ${userAnswer}\n\n評価: {"result":"correct|incorrect|partial","confidence":0-100}`,
            }],
            response_format: { type: "json_object" },
          }),
        }).catch(() => null);
        if (!groqResp || !groqResp.ok) {
          const isCorrect = userAnswer.trim().toLowerCase() === correctAnswer.trim().toLowerCase();
          return json({ success: true, result: isCorrect ? "correct" : "incorrect", confidence: 100, fallback: true });
        }
        const groqData = await groqResp.json() as Record<string, unknown>;
        const raw = (groqData.choices as Array<{message: {content: string}}>)?.[0]?.message?.content ?? '{"result":"incorrect","confidence":0}';
        let evaluation: Record<string, unknown> = { result: "incorrect", confidence: 0 };
        try { evaluation = JSON.parse(raw); } catch { /* use default */ }
        return json({ success: true, ...evaluation });
      }

      case "quiz.explain": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const question = String(body.question ?? "");
        const userAnswer = String(body.user_answer ?? "");
        const correctAnswer = String(body.correct_answer ?? "");
        const provider = String(body.provider ?? "");
        const claudeKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
        if (!claudeKey) return json({ error: "ANTHROPIC_API_KEY not configured" }, 503);
        const prompt = `${provider} についての問題で不正解でした。わかりやすく詳細に解説してください。
問題: ${question}
正解: ${correctAnswer}
ユーザーの回答: ${userAnswer}
なぜ正解がそうなるのか、関連する背景知識も含めて日本語で300字以内で説明してください。`;
        const claudeResp2 = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "x-api-key": claudeKey,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-6",
            max_tokens: 512,
            messages: [{ role: "user", content: prompt }],
          }),
        });
        const claudeData2 = await claudeResp2.json() as Record<string, unknown>;
        const explanation = (claudeData2.content as Array<{text: string}>)?.[0]?.text ?? "解説を生成できませんでした。";
        return json({ success: true, explanation });
      }

      // ── AI大学 v2: Voice ─────────────────────────────────────────────────
      case "provider.chat": {
        // 汎用プロバイダー呼び出し (AI大学82社の実装済みAIに統一インターフェースで話しかける)
        // 対応: OpenAI互換 8社 (openai/xai/deepseek/groq/sambanova/openrouter/fireworks/together/arcee_ai)
        //       + 独自API 3社 (mistral/perplexity/cohere) + anthropic/google (MAGI互換)
        const providerId = String(body.provider ?? "");
        const messages = Array.isArray(body.messages) ? body.messages : null;
        const userMsg = String(body.message ?? "");
        if (!providerId) return json({ error: "provider required" }, 400);
        if (!messages && !userMsg) return json({ error: "messages or message required" }, 400);
        const finalMessages = messages ?? [{ role: "user", content: userMsg }];

        const cfg = PROVIDER_CONFIGS[providerId];
        if (!cfg) {
          return json({ success: false, status: "notImplemented", message: `Provider "${providerId}" はまだ実装されていません。` }, 400);
        }
        const apiKey = Deno.env.get(cfg.envKey) ?? "";
        if (!apiKey) {
          return json({ success: false, status: "apiKeyRequired", secret_needed: cfg.envKey, message: `Supabase Secret ${cfg.envKey} を設定してください。` });
        }

        try {
          // 認証方式はプロバイダーごとに異なる
          let authHeaders: Record<string, string> = { Authorization: `Bearer ${apiKey}` };
          let fetchUrl = cfg.chatUrl;
          if (providerId === "anthropic") {
            authHeaders = { "x-api-key": apiKey, "anthropic-version": "2023-06-01" };
          } else if (providerId === "google") {
            authHeaders = {};
            fetchUrl = `${cfg.chatUrl}?key=${apiKey}`;
          }
          const resp = await fetch(fetchUrl, {
            method: "POST",
            headers: {
              ...authHeaders,
              "Content-Type": "application/json",
              ...(cfg.extraHeaders ?? {}),
            },
            body: JSON.stringify(cfg.buildBody(finalMessages, String(body.model ?? cfg.defaultModel))),
          });
          const respText = await resp.text();
          if (!resp.ok) {
            // Free tier / 課金制限検知
            if (respText.includes("paid_plan_required") || respText.includes("payment_required") ||
                resp.status === 402 || respText.includes("insufficient_quota") ||
                respText.includes("billing") || respText.includes("credit")) {
              return json({ success: false, status: "paidPlanRequired", provider: providerId, message: `${cfg.displayName} はプロバイダー側で課金が必要です。`, detail: respText.slice(0, 300) });
            }
            return json({ success: false, status: "error", provider: providerId, http_status: resp.status, detail: respText.slice(0, 500) }, 502);
          }
          let data: unknown;
          try {
            data = JSON.parse(respText);
          } catch {
            return json({ success: true, provider: providerId, status: "implemented", text: respText.slice(0, 2000) });
          }
          const content = cfg.parseResponse(data);
          const modelUsed = pick(data, "model");
          return json({ success: true, provider: providerId, status: "implemented", text: content, model: modelUsed ?? cfg.defaultModel });
        } catch (e) {
          return json({ success: false, status: "error", provider: providerId, message: String(e) }, 500);
        }
      }

      case "provider.list": {
        // UIから呼ばれる: 各プロバイダーのEnv有無だけ返す (APIコールなし・安全)
        const result: Record<string, { envConfigured: boolean; displayName: string }> = {};
        for (const [id, cfg] of Object.entries(PROVIDER_CONFIGS)) {
          result[id] = {
            envConfigured: (Deno.env.get(cfg.envKey) ?? "") !== "",
            displayName: cfg.displayName,
          };
        }
        return json({ success: true, providers: result });
      }

      case "voice.tts": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const text = String(body.text ?? "").slice(0, 5000);
        const voiceId = String(body.voice_id ?? "21m00Tcm4TlvDq8ikWAM");
        const elevenKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
        if (!elevenKey) {
          return json({ success: false, fallback: "webspeech", text, reason: "ELEVENLABS_API_KEY not configured" });
        }
        const ttsResp = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
          method: "POST",
          headers: { "xi-api-key": elevenKey, "Content-Type": "application/json" },
          body: JSON.stringify({
            text,
            model_id: "eleven_multilingual_v2",
            voice_settings: { stability: 0.5, similarity_boost: 0.75 },
          }),
        });
        if (!ttsResp.ok) {
          const errText = await ttsResp.text();
          // Free-tier / paid-plan-required → フォールバックで Web Speech API 利用を UI に通知
          if (errText.includes("paid_plan_required") || errText.includes("payment_required")) {
            return json({ success: false, fallback: "webspeech", text, reason: "elevenlabs_paid_plan_required" });
          }
          return json({ error: `ElevenLabs error: ${errText}`, fallback: "webspeech", text }, 502);
        }
        const audioBuffer = await ttsResp.arrayBuffer();
        const bytes = new Uint8Array(audioBuffer);
        let binary = "";
        for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
        const base64Audio = btoa(binary);
        return json({ success: true, audio_base64: base64Audio, content_type: "audio/mpeg" });
      }

      case "voice.stt": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const audioBase64 = String(body.audio_base64 ?? "");
        const language = String(body.language ?? "ja");
        const deepgramKey = Deno.env.get("DEEPGRAM_API_KEY") ?? "";
        if (!deepgramKey) return json({ error: "DEEPGRAM_API_KEY not configured" }, 503);
        let audioBytes: Uint8Array;
        try {
          audioBytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
        } catch {
          return json({ error: "Invalid base64 audio data" }, 400);
        }
        const dgResp = await fetch(
          `https://api.deepgram.com/v1/listen?language=${language}&model=nova-2&punctuate=true`,
          {
            method: "POST",
            headers: { "Authorization": `Token ${deepgramKey}`, "Content-Type": "audio/webm" },
            body: audioBytes,
          },
        );
        if (!dgResp.ok) {
          const errText = await dgResp.text();
          return json({ error: `Deepgram error: ${errText}` }, 502);
        }
        const dgData = await dgResp.json() as Record<string, unknown>;
        const transcript = ((dgData.results as Record<string, unknown>)?.channels as Array<Record<string, unknown>>)?.[0]?.alternatives as Array<{transcript: string}>;
        const transcriptText = transcript?.[0]?.transcript ?? "";
        return json({ success: true, transcript: transcriptText });
      }


      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
