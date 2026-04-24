// ai-hub — AI・エージェント・AI大学統合EF
// Merges (16 EFs): daily-judgment, ai-search, ai-suggest-tags, ai-secretary,
//   ai-summarizer, agent-hub, virtual-organization, my-ai-agent,
//   generate-daily-challenges, trigger-analysis, analyze-reality,
//   local-election-intelligence, ai-university-content,
//   ai-university-streaks, ai-university-badges
// NOTE: ai-assistant stays standalone (1079 lines, complex multi-provider logic)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
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
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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

type InlineImage = {
  base64: string;
  mimeType: string;
  name: string | null;
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
    // 2026-04 時点 xAI 現行モデル. grok-2-latest は廃止 (Model not found エラー).
    // grok-4-1-fast-non-reasoning: 2M context / 低コスト / 非推論用途向け.
    defaultModel: "grok-4-1-fast-non-reasoning",
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
  huggingface: {
    displayName: "Hugging Face",
    envKey: "HUGGINGFACE_TOKEN",
    chatUrl: "https://api-inference.huggingface.co/v1/chat/completions",
    defaultModel: "meta-llama/Llama-3.3-70B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  minimax: {
    displayName: "MiniMax",
    envKey: "MINIMAX_API_KEY",
    chatUrl: "https://api.minimax.chat/v1/chat/completions",
    defaultModel: "MiniMax-Text-01",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  reka: {
    displayName: "Reka AI",
    envKey: "REKA_API_KEY",
    chatUrl: "https://api.reka.ai/v1/chat/completions",
    defaultModel: "reka-flash-3",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  writer: {
    displayName: "Writer Palmyra",
    envKey: "WRITER_API_KEY",
    chatUrl: "https://api.writer.com/v1/chat",
    defaultModel: "palmyra-x5",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  meta: {
    displayName: "Meta Llama",
    envKey: "LLAMA_API_KEY",
    chatUrl: "https://api.llama.com/v1/chat/completions",
    defaultModel: "Llama-4-Scout-17B-16E-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  nebius: {
    displayName: "Nebius AI Studio",
    envKey: "NEBIUS_API_KEY",
    chatUrl: "https://api.studio.nebius.com/v1/chat/completions",
    defaultModel: "meta-llama/Llama-3.3-70B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  replicate: {
    displayName: "Replicate",
    envKey: "REPLICATE_API_TOKEN",
    chatUrl: "https://openai-compat.replicate.com/v1/chat/completions",
    defaultModel: "meta/llama-4-scout-instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  coze: {
    displayName: "Coze (ByteDance)",
    envKey: "COZE_API_KEY",
    chatUrl: "https://api.coze.com/v1/chat/completions",
    defaultModel: "gpt-4o",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  deepinfra: {
    displayName: "DeepInfra",
    envKey: "DEEPINFRA_API_KEY",
    chatUrl: "https://api.deepinfra.com/v1/openai/chat/completions",
    defaultModel: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  liquid: {
    displayName: "Liquid AI",
    envKey: "LIQUID_API_KEY",
    chatUrl: "https://api.liquid.ai/v1/chat/completions",
    defaultModel: "liquid/lfm-40b",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  siliconflow: {
    displayName: "SiliconFlow",
    envKey: "SILICONFLOW_API_KEY",
    chatUrl: "https://api.siliconflow.cn/v1/chat/completions",
    defaultModel: "Qwen/Qwen2.5-72B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  novita_ai: {
    displayName: "Novita AI",
    envKey: "NOVITA_API_KEY",
    chatUrl: "https://api.novita.ai/v3/openai/chat/completions",
    defaultModel: "meta-llama/llama-3.1-70b-instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  atlas_cloud: {
    displayName: "Atlas Cloud",
    envKey: "ATLAS_CLOUD_API_KEY",
    chatUrl: "https://api.atlascloud.ai/v1/chat/completions",
    defaultModel: "deepseek-v3",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  gmi_cloud: {
    displayName: "GMI Cloud",
    envKey: "GMI_CLOUD_API_KEY",
    chatUrl: "https://api.gmicloud.ai/v1/chat/completions",
    defaultModel: "deepseek-v3.2",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  inworld: {
    displayName: "Inworld AI",
    envKey: "INWORLD_API_KEY",
    chatUrl: "https://api.inworld.ai/v1/chat/completions",
    defaultModel: "gpt-4o-mini",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  hyperbolic: {
    displayName: "Hyperbolic Labs",
    envKey: "HYPERBOLIC_API_KEY",
    chatUrl: "https://api.hyperbolic.xyz/v1/chat/completions",
    defaultModel: "meta-llama/Meta-Llama-3.3-70B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  anyscale: {
    displayName: "Anyscale",
    envKey: "ANYSCALE_API_KEY",
    chatUrl: "https://api.endpoints.anyscale.com/v1/chat/completions",
    defaultModel: "meta-llama/Meta-Llama-3.1-70B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
  cerebrium: {
    displayName: "Cerebrium",
    envKey: "CEREBRIUM_API_KEY",
    chatUrl: "https://api.cerebrium.ai/v1/chat/completions",
    defaultModel: "meta-llama/Llama-3.3-70B-Instruct",
    buildBody: OPENAI_COMPAT_BODY,
    parseResponse: OPENAI_COMPAT_PARSE,
  },
};

type Tier = "free" | "budget" | "performance" | "premium";

const TIER_PROVIDERS: Record<Tier, string[]> = {
  free: ["deepseek", "groq", "cerebras", "siliconflow", "novita_ai"],
  budget: [
    "sambanova",
    "arcee_ai",
    "minimax",
    "deepinfra",
    "together_ai",
    "fireworks_ai",
    "moonshot",
  ],
  performance: [
    "openai",
    "google",
    "mistral",
    "cohere",
    "perplexity",
    "nebius",
    "qwen",
  ],
  premium: ["anthropic", "openai", "google"],
};

const TIER_COST_USD_PER_1K: Record<Tier, number> = {
  free: 0.0001,
  budget: 0.001,
  performance: 0.01,
  premium: 0.05,
};

const TIER_ORDER: Tier[] = ["free", "budget", "performance", "premium"];

async function callSingleProvider(
  providerId: string,
  messages: { role: string; content: string }[],
  model?: string,
): Promise<
  {
    ok: boolean;
    text?: string;
    modelUsed?: string;
    error?: string;
    isRetriable: boolean;
  }
> {
  const cfg = PROVIDER_CONFIGS[providerId];
  if (!cfg) return { ok: false, error: "unknown provider", isRetriable: false };
  const apiKey = Deno.env.get(cfg.envKey) ?? "";
  if (!apiKey) {
    return { ok: false, error: "apiKeyRequired", isRetriable: false };
  }
  try {
    let authHeaders: Record<string, string> = {
      Authorization: `Bearer ${apiKey}`,
    };
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
      body: JSON.stringify(cfg.buildBody(messages, model ?? cfg.defaultModel)),
    });
    if (!resp.ok) {
      const isRetriable = resp.status === 429 || resp.status >= 500;
      return { ok: false, error: `HTTP ${resp.status}`, isRetriable };
    }
    const respText = await resp.text();
    let data: unknown;
    try {
      data = JSON.parse(respText);
    } catch {
      return {
        ok: true,
        text: respText.slice(0, 2000),
        modelUsed: model ?? cfg.defaultModel,
        isRetriable: false,
      };
    }
    const content = cfg.parseResponse(data);
    const modelUsed =
      (typeof (data as Record<string, unknown>)?.model === "string"
        ? (data as Record<string, unknown>).model
        : model ?? cfg.defaultModel) as string;
    return { ok: true, text: content, modelUsed, isRetriable: false };
  } catch (e) {
    return { ok: false, error: String(e), isRetriable: true };
  }
}

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

function providerTier(providerId: string): Tier | null {
  for (const tier of TIER_ORDER) {
    if (TIER_PROVIDERS[tier].includes(providerId)) return tier;
  }
  return null;
}

function stripMarkdownCodeFence(text: string): string {
  return text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
}

function parseInlineImage(
  body: Record<string, unknown>,
): { image?: InlineImage; error?: string; status?: number } {
  const rawImage = asString(body.imageBase64);
  if (!rawImage) return {};
  const dataUrlMatch = rawImage.match(/^data:([^;]+);base64,(.+)$/);
  const requestedMimeType = dataUrlMatch?.[1] ?? asString(body.mimeType);
  const mimeType = requestedMimeType || "image/jpeg";
  if (!mimeType.startsWith("image/")) {
    return { error: "mimeType must be an image/* type", status: 400 };
  }
  const base64 = (dataUrlMatch?.[2] ?? rawImage).replace(/\s/g, "");
  if (!base64) return { error: "imageBase64 required", status: 400 };
  if (base64.length > 6_000_000) {
    return { error: "imageBase64 is too large", status: 413 };
  }
  return {
    image: {
      base64,
      mimeType,
      name: asString(body.imageName) || null,
    },
  };
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
    focus:
      "Turns the idea into an operating plan and delegates the first wave of work.",
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
  {
    key: "atlas",
    display_name: "Atlas",
    role_title: "Architect",
    focus: "System architecture and technical tradeoffs.",
  },
  {
    key: "maya",
    display_name: "Maya",
    role_title: "Designer",
    focus: "UX, structure, and interface direction.",
  },
  {
    key: "kai",
    display_name: "Kai",
    role_title: "Frontend Developer",
    focus: "Customer-facing product implementation.",
  },
  {
    key: "dev",
    display_name: "Dev",
    role_title: "Backend Developer",
    focus: "APIs, data flow, and server logic.",
  },
  {
    key: "shield",
    display_name: "Shield",
    role_title: "Security Reviewer",
    focus: "Security, auth, privacy, and abuse review.",
  },
  {
    key: "nova",
    display_name: "Nova",
    role_title: "Researcher",
    focus: "Market, competitors, pricing, and citations.",
  },
  {
    key: "sage",
    display_name: "Sage",
    role_title: "Writer",
    focus: "Copy, docs, emails, and knowledge distillation.",
  },
  {
    key: "piper",
    display_name: "Piper",
    role_title: "Content Strategist",
    focus: "Content calendar and editorial systems.",
  },
  {
    key: "flux",
    display_name: "Flux",
    role_title: "Growth Operator",
    focus: "Acquisition loops and channel experiments.",
  },
  {
    key: "echo",
    display_name: "Echo",
    role_title: "Email Operator",
    focus: "Lifecycle messaging and campaign sequencing.",
  },
  {
    key: "scout",
    display_name: "Scout",
    role_title: "SEO Analyst",
    focus: "Search intent, pages, and ranking opportunities.",
  },
  {
    key: "forge",
    display_name: "Forge",
    role_title: "Automation Builder",
    focus: "Workflow setup and operational automation.",
  },
  {
    key: "pilot",
    display_name: "Pilot",
    role_title: "QA Engineer",
    focus: "Test passes, regressions, and release confidence.",
  },
  {
    key: "pulse",
    display_name: "Pulse",
    role_title: "Analytics Lead",
    focus: "Metrics, instrumentation, and dashboards.",
  },
  {
    key: "loom",
    display_name: "Loom",
    role_title: "Brand Strategist",
    focus: "Narrative, tone, and brand coherence.",
  },
  {
    key: "spark",
    display_name: "Spark",
    role_title: "Experiment Lead",
    focus: "Hypothesis design and iteration loops.",
  },
  {
    key: "orbit",
    display_name: "Orbit",
    role_title: "Integration Engineer",
    focus: "Connectors, APIs, and external systems.",
  },
  {
    key: "beacon",
    display_name: "Beacon",
    role_title: "Sales Ops",
    focus: "Lead routing, pipelines, and qualification logic.",
  },
  {
    key: "ledger",
    display_name: "Ledger",
    role_title: "Business Analyst",
    focus: "Unit economics and scenario modeling.",
  },
  {
    key: "relay",
    display_name: "Relay",
    role_title: "Support Ops",
    focus: "Support workflows and service quality loops.",
  },
  {
    key: "prism",
    display_name: "Prism",
    role_title: "Customer Research",
    focus: "User interviews, pain points, and retention insights.",
  },
];

const COMPANY_CRITERIA_TEMPLATE: CompanyBuilderCriterion[] = [
  {
    key: "market_size",
    label: "Market size",
    weight: 20,
    score: 7,
    rationale: "",
  },
  {
    key: "competition_level",
    label: "Competition level",
    weight: 20,
    score: 6,
    rationale: "",
  },
  {
    key: "niche_uniqueness",
    label: "Niche uniqueness",
    weight: 15,
    score: 8,
    rationale: "",
  },
  {
    key: "revenue_potential",
    label: "Revenue potential",
    weight: 15,
    score: 7,
    rationale: "",
  },
  {
    key: "acquisition_cost",
    label: "Acquisition cost",
    weight: 15,
    score: 6,
    rationale: "",
  },
  {
    key: "channel_accessibility",
    label: "Channel accessibility",
    weight: 15,
    score: 7,
    rationale: "",
  },
];

const COMPANY_INITIAL_TASKS: CompanyTaskBlueprint[] = [
  {
    title: "Map the market and competitor set",
    description:
      "Build a fast market view, identify direct competitors, and capture the opening angle for this company.",
    manager_key: "chief",
    tool_key: "nova",
    priority: "high",
    stage: "gate",
  },
  {
    title: "Shape the MVP and architecture",
    description:
      "Turn the company brief into a first MVP scope, architecture outline, and a release sequence.",
    manager_key: "max",
    tool_key: "atlas",
    priority: "high",
    stage: "product",
  },
  {
    title: "Design landing page structure and voice",
    description:
      "Create the initial narrative, hero promise, and page sections that explain the offer clearly.",
    manager_key: "ivy",
    tool_key: "maya",
    priority: "normal",
    stage: "marketing",
  },
  {
    title: "Draft the first sales motion",
    description:
      "Outline the ICP, outreach hooks, qualification questions, and the first CTA path.",
    manager_key: "sam",
    tool_key: "beacon",
    priority: "normal",
    stage: "sales",
  },
  {
    title: "Model pricing and unit economics",
    description:
      "Estimate pricing, gross margin, CAC sensitivity, and the shortest route to positive economics.",
    manager_key: "finn",
    tool_key: "ledger",
    priority: "normal",
    stage: "finance",
  },
  {
    title: "Prepare onboarding and support loop",
    description:
      "Define onboarding milestones, support touchpoints, and the first retention feedback loop.",
    manager_key: "joy",
    tool_key: "relay",
    priority: "normal",
    stage: "success",
  },
  {
    title: "Review legal and compliance exposure",
    description:
      "List privacy, policy, and compliance issues that need an answer before launch.",
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
  const jsonText = start >= 0 && end > start
    ? candidate.slice(start, end + 1)
    : candidate;
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
  const totalWeight = criteria.reduce((sum, item) => sum + item.weight, 0) ||
    100;
  const weighted =
    criteria.reduce((sum, item) => sum + item.score * item.weight, 0) /
    totalWeight;
  return Math.round(weighted * 10) / 10;
}

function buildFallbackCompanyPlan(
  idea: string,
  threshold: number,
): CompanyBuilderPlan {
  const companyName = deriveCompanyName(idea);
  const criteria = COMPANY_CRITERIA_TEMPLATE.map((item, index) => {
    const adjustment = [0.4, -0.3, 0.8, 0.2, -0.2, 0.4][index] ?? 0;
    const heuristic = clampScore(
      6.4 + adjustment + Math.min(idea.length / 120, 1),
    );
    return {
      ...item,
      score: Math.round(heuristic * 10) / 10,
      rationale:
        `Initial heuristic assessment for ${item.label.toLowerCase()} based on the idea wording and likely launch complexity.`,
    };
  });
  const overall = computeOverallScore(criteria);
  const passed = overall >= threshold;
  return {
    company_name: companyName,
    summary: `A focused AI-native business built from the idea: ${idea}`,
    offer: `Deliver a faster and more opinionated version of ${idea}`,
    audience:
      "Early adopters who already feel the pain and can validate the workflow quickly.",
    business_model:
      "Subscription with a paid pilot or concierge-assisted onboarding.",
    launch_channels: [
      "Direct outreach",
      "Founder-led content",
      "SEO landing pages",
    ],
    recommendation: passed
      ? "The concept clears the first gate. Start with a narrow MVP and validate demand before expanding scope."
      : "The concept needs a sharper niche or cheaper channel before committing to a full build.",
    criteria,
  };
}

function buildCompanyPlanFromModel(
  raw: Record<string, unknown>,
  idea: string,
  threshold: number,
): CompanyBuilderPlan {
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
      score: clampScore(
        asNumber(candidate.score, fallback.criteria[index].score),
      ),
      rationale: asString(candidate.rationale) ||
        fallback.criteria[index].rationale,
    };
  });
  return {
    company_name: asString(raw.company_name) || fallback.company_name,
    summary: asString(raw.summary) || fallback.summary,
    offer: asString(raw.offer) || fallback.offer,
    audience: asString(raw.audience) || fallback.audience,
    business_model: asString(raw.business_model) || fallback.business_model,
    launch_channels: Array.isArray(raw.launch_channels)
      ? raw.launch_channels.map((item) => asString(item)).filter(Boolean).slice(
        0,
        5,
      )
      : fallback.launch_channels,
    recommendation: asString(raw.recommendation) || fallback.recommendation,
    criteria,
  };
}

async function generateCompanyPlan(
  idea: string,
  threshold: number,
  geminiKey: string,
): Promise<CompanyBuilderPlan> {
  const fallback = buildFallbackCompanyPlan(idea, threshold);
  if (geminiKey === "") return fallback;

  const prompt = [
    "You are generating the bootstrap plan for an AI company builder.",
    "Return JSON only.",
    "Score each criterion from 1 to 10.",
    `Idea: ${idea}`,
    `Pass threshold: ${threshold}`,
    `Use exactly these criteria keys in order: ${
      COMPANY_CRITERIA_TEMPLATE.map((item) => item.key).join(", ")
    }`,
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

async function findAgentBySlug(
  admin: SupabaseClient,
  userId: string,
  slug: string,
) {
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
        identity_prompt:
          `${blueprint.focus}\nCompany: ${companyName}\nIdea: ${idea}`,
        permissions_summary:
          "Dedicated manager agent for a single company instance.",
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
      content:
        `${companyName}: ${blueprint.focus}\nIdea: ${idea}\nOffer: ${plan.offer}`,
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

function buildCompanyWorkflowSteps(
  companyName: string,
  plan: CompanyBuilderPlan,
) {
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
      description:
        `Condense the launch recommendation for ${companyName}. ${plan.recommendation}`,
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
      description:
        `${task.description}\nCompany: ${companyName}\nAudience: ${plan.audience}`,
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
  const { data, error } = await admin.from("agent_tasks").insert(inserts)
    .select("*");
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
        ...plan.criteria.map((item) =>
          `- ${item.label}: ${
            item.score.toFixed(1)
          }/10 (${item.weight}%) - ${item.rationale}`
        ),
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
        ...COMPANY_MANAGER_BLUEPRINTS.map((item) =>
          `- ${item.display_name}: ${item.role_title} - ${item.focus}`
        ),
        "",
        "Shared tool agents:",
        ...COMPANY_TOOL_BLUEPRINTS.map((item) =>
          `- ${item.display_name}: ${item.role_title}`
        ),
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

async function getCompanyBuilderDetail(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
) {
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

  if (managerAgentsResult.error) {
    throw new Error(managerAgentsResult.error.message);
  }
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
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await c.auth.getUser();
  return user?.id ?? null;
}

async function evaluateUniversityQuizMaster(
  admin: SupabaseClient,
  userId: string,
) {
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

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data").select(
    "id, metadata, created_at",
  )
    .eq("source", source).filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false }).limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function _deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source).filter(
      "metadata->>user_id",
      "eq",
      userId,
    );
  if (error) throw new Error(error.message);
}

type NoteSearchIndexRow = {
  note_id: number;
  title: string | null;
  content: string | null;
  tags: string[] | null;
  category_id: string | null;
  note_updated_at: string | null;
  text_rank: number | null;
  vector_rank: number | null;
  combined_rank: number | null;
  match_reason: string | null;
};

function buildNoteSearchText(
  title: string | null | undefined,
  content: string | null | undefined,
  tags: string[] | null | undefined,
): string {
  return [
    title ?? "",
    Array.isArray(tags) ? tags.join(" ") : "",
    content ?? "",
  ]
    .join("\n")
    .replace(/\s+/g, " ")
    .trim();
}

function truncateForEmbedding(text: string, maxChars = 3500): string {
  if (text.length <= maxChars) return text;
  return text.slice(0, maxChars);
}

async function embedTextsWithGemini(
  texts: string[],
  apiKey: string,
): Promise<number[][]> {
  if (texts.length === 0) return [];
  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        requests: texts.map((text) => ({
          model: "models/gemini-embedding-001",
          content: {
            parts: [{ text }],
          },
        })),
      }),
    },
  );
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Gemini embedding ${response.status}: ${errorText.slice(0, 500)}`,
    );
  }
  const data = await response.json() as {
    embeddings?: Array<{ values?: number[] }>;
  };
  return (data.embeddings ?? []).map((item) => item.values ?? []);
}

async function syncNoteSearchIndex(
  admin: SupabaseClient,
  userId: string,
): Promise<void> {
  const { error } = await admin.rpc("sync_note_search_index_text", {
    p_user_id: userId,
  });
  if (error) {
    throw new Error(`sync_note_search_index_text failed: ${error.message}`);
  }
}

async function embedPendingNoteSearchRows(
  admin: SupabaseClient,
  userId: string,
  apiKey: string,
  limit = 12,
): Promise<number> {
  const { data, error } = await admin
    .from("note_search_index")
    .select("note_id, title, content, tags")
    .eq("user_id", userId)
    .eq("is_archived", false)
    .is("embedding", null)
    .order("note_updated_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(`note_search_index load failed: ${error.message}`);

  const rows = (data ?? []) as Array<{
    note_id: number;
    title: string | null;
    content: string | null;
    tags: string[] | null;
  }>;
  if (rows.length === 0) return 0;

  const embeddingInputs = rows.map((row) =>
    truncateForEmbedding(buildNoteSearchText(row.title, row.content, row.tags))
  );
  const vectors = await embedTextsWithGemini(embeddingInputs, apiKey);

  await Promise.all(rows.map(async (row, index) => {
    const vector = vectors[index];
    if (!vector || vector.length === 0) return;
    const { error: upsertError } = await admin.rpc(
      "upsert_note_search_embedding",
      {
        p_note_id: row.note_id,
        p_embedding: vector,
      },
    );
    if (upsertError) {
      throw new Error(
        `upsert_note_search_embedding failed: ${upsertError.message}`,
      );
    }
  }));

  return rows.length;
}

async function searchIndexedNotes(
  admin: SupabaseClient,
  userId: string,
  query: string,
  limit: number,
  queryEmbedding: number[] | null,
): Promise<NoteSearchIndexRow[]> {
  const { data, error } = await admin.rpc("search_note_index_hybrid", {
    p_user_id: userId,
    p_query: query,
    p_limit: limit,
    p_query_embedding: queryEmbedding,
  });
  if (error) {
    throw new Error(`search_note_index_hybrid failed: ${error.message}`);
  }
  return (data ?? []) as NoteSearchIndexRow[];
}

async function fallbackTextSearch(
  admin: SupabaseClient,
  userId: string,
  query: string,
  limit: number,
): Promise<NoteSearchIndexRow[]> {
  const escaped = query.replaceAll("%", "\\%").replaceAll("_", "\\_")
    .replaceAll(",", " ");
  const { data, error } = await admin
    .from("notes")
    .select("id, title, content, tags, category_id, updated_at")
    .eq("user_id", userId)
    .eq("is_archived", false)
    .or(`title.ilike.%${escaped}%,content.ilike.%${escaped}%`)
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(`notes fallback search failed: ${error.message}`);

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    note_id: Number(row.id ?? 0),
    title: String(row.title ?? ""),
    content: String(row.content ?? ""),
    tags: Array.isArray(row.tags) ? row.tags.map((tag) => String(tag)) : [],
    category_id: row.category_id == null ? null : String(row.category_id),
    note_updated_at: row.updated_at == null ? null : String(row.updated_at),
    text_rank: null,
    vector_rank: null,
    combined_rank: null,
    match_reason: "text_fallback",
  }));
}

async function invokeAiAssistant(
  authHeader: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (!authHeader) throw new Error("Missing authorization header");
  const response = await fetch(`${SUPABASE_URL}/functions/v1/ai-assistant`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": SUPABASE_ANON_KEY,
      "Authorization": authHeader,
    },
    body: JSON.stringify(payload),
  });
  const rawText = await response.text();
  let parsed: Record<string, unknown> = {};
  if (rawText.trim()) {
    try {
      parsed = JSON.parse(rawText) as Record<string, unknown>;
    } catch {
      parsed = { raw: rawText };
    }
  }
  if (!response.ok) {
    const message = asString(parsed.error ?? parsed.message ?? rawText) ||
      `ai-assistant request failed (${response.status})`;
    throw new Error(message);
  }
  return parsed;
}

async function callGemini(
  prompt: string,
  apiKey: string,
  image?: InlineImage,
): Promise<string> {
  const parts: Record<string, unknown>[] = [{ text: prompt }];
  if (image) {
    parts.push({
      inline_data: {
        mime_type: image.mimeType,
        data: image.base64,
      },
    });
  }
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts }] }),
    },
  );
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Gemini ${res.status}: ${errorText.slice(0, 500)}`);
  }
  const data = await res.json() as {
    candidates?: [{ content: { parts: [{ text: string }] } }];
  };
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

type ManusTaskResult = {
  response: string;
  taskId: string | null;
  taskUrl: string | null;
};

async function callManusTask(
  prompt: string,
  apiKey: string,
  image?: InlineImage,
): Promise<ManusTaskResult> {
  const baseUrl = (Deno.env.get("MANUS_API_BASE_URL") ??
    "https://api.manus.ai/v2").replace(/\/+$/, "");
  const manusPrompt = image
    ? `${prompt}\n\nNote: an image was attached in my-ai-agent, but this Manus task.create integration sends the text prompt only.`
    : prompt;
  const res = await fetch(`${baseUrl}/task.create`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-manus-api-key": apiKey,
    },
    body: JSON.stringify({ prompt: manusPrompt }),
  });
  const rawText = await res.text();
  let data: Record<string, unknown> = {};
  if (rawText.trim()) {
    try {
      data = JSON.parse(rawText) as Record<string, unknown>;
    } catch {
      data = { raw: rawText };
    }
  }
  if (!res.ok) {
    const message = asString(
      pick(data, "error") ?? pick(data, "message") ?? rawText,
    );
    throw new Error(`Manus ${res.status}: ${message.slice(0, 500)}`);
  }

  const taskId = asString(pick(data, "task_id")) ||
    asString(pick(data, "id")) ||
    asString(pick(data, "data", "task_id")) ||
    asString(pick(data, "data", "id")) ||
    null;
  const taskUrl = asString(pick(data, "task_url")) ||
    asString(pick(data, "url")) ||
    asString(pick(data, "data", "task_url")) ||
    asString(pick(data, "data", "url")) ||
    null;
  const detailLines = [
    "Manus task submitted.",
    taskId ? `task_id: ${taskId}` : null,
    taskUrl ? `task_url: ${taskUrl}` : null,
    "Open Manus to monitor the asynchronous execution result.",
  ].filter(Boolean);

  return {
    response: detailLines.join("\n"),
    taskId,
    taskUrl,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const body = req.method === "POST"
      ? await req.json() as Record<string, unknown>
      : {};
    const action = String(
      body.action ?? new URL(req.url).searchParams.get("action") ?? "",
    );
    const userId = await getUserId(req);

    // Actions that require authentication
    const authRequired = [
      "search.query",
      "secretary.task",
      "secretary.history",
      "summarize.text",
      "agent.list",
      "agent.create",
      "agent.run",
      "org.get",
      "my_agent.chat",
      "my_agent.history",
      "challenges.list",
      "trigger.analyze",
      "analyze.reality",
      "company_builder.list",
      "company_builder.get",
      "company_builder.bootstrap",
      // AI大学 v2 (P1〜P4)
      "quiz.fsrs_next",
      "quiz.fsrs_grade",
      "learner.update_profile",
      "quiz.evaluate",
      "quiz.explain",
      "voice.tts",
      "voice.stt",
    ];
    if (authRequired.includes(action) && !userId) {
      return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      case "judgment.get": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const today = new Date().toLocaleDateString("ja-JP");
        const prompt =
          `今日${today}の自己成長・キャリア・健康に関するAI判定をしてください。JSON: {"score":0-100,"judgment":"良好/注意/警戒","advice":"...", "focus_area":"..."}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text });
        }
      }

      case "search.query": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const query = String(body.query ?? "").trim();
        const limit = Math.min(Math.max(Number(body.limit ?? 20), 1), 30);
        if (!query) {
          return json({
            success: true,
            query,
            results: [],
            totalResults: 0,
            searchMode: "text_fallback",
            explanation: "Empty query.",
          });
        }

        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";

        try {
          await syncNoteSearchIndex(admin, userId);
        } catch (error) {
          console.warn("search.query sync failed", error);
        }

        let queryEmbedding: number[] | null = null;
        let searchMode = "text_fallback";

        if (geminiKey) {
          try {
            await embedPendingNoteSearchRows(admin, userId, geminiKey);
            const embeddings = await embedTextsWithGemini(
              [truncateForEmbedding(query, 1200)],
              geminiKey,
            );
            queryEmbedding = embeddings[0] ?? null;
            if (queryEmbedding && queryEmbedding.length > 0) {
              searchMode = "ai";
            }
          } catch (error) {
            console.warn("search.query embedding failed", error);
          }
        }

        let rows: NoteSearchIndexRow[] = [];
        try {
          rows = await searchIndexedNotes(
            admin,
            userId,
            query,
            limit,
            queryEmbedding,
          );
        } catch (error) {
          console.warn("search.query indexed search failed", error);
        }
        if (rows.length === 0) {
          rows = await fallbackTextSearch(admin, userId, query, limit);
          searchMode = "text_fallback";
        }

        const results = rows.map((row) => ({
          id: row.note_id,
          title: row.title ?? "",
          content: row.content ?? "",
          tags: row.tags ?? [],
          category_id: row.category_id,
          updated_at: row.note_updated_at,
          search_score: row.combined_rank ?? row.text_rank ?? row.vector_rank ??
            0,
          search_text_rank: row.text_rank ?? 0,
          search_vector_rank: row.vector_rank ?? 0,
          match_reason: row.match_reason ??
            (queryEmbedding == null ? "text" : "hybrid"),
        }));

        const explanation = searchMode == "ai"
          ? "Supabase pgvector + text similarity hybrid search"
          : "Supabase text similarity fallback search";

        return json({
          success: true,
          query,
          results,
          totalResults: results.length,
          searchMode,
          explanation,
        });
      }

      case "tags.suggest": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const prompt =
          `次のテキストに適切なタグを5つ提案してください: "${body.text}". JSON: {"tags":["tag1","tag2","tag3","tag4","tag5"]}`;
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
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const prompt = `あなたはAI秘書です。以下のタスクを処理してください: ${
          body.task ?? body.message ?? ""
        }. 返答はJSON: {"result":"...","actions":[],"priority":"high|medium|low"}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
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
          const prompt =
            `次のテキストを日本語で200字以内に要約してください:\n\n${text}`;
          const result = await callGemini(prompt, geminiKey);
          await addItem(admin, "summary_log", userId!, {
            original_length: text.length,
            summary: result,
          });
          return json({ success: true, summary: result });
        }
        if (openaiKey) {
          const r = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${openaiKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "gpt-4o-mini",
              messages: [{ role: "user", content: `200字以内で要約: ${text}` }],
              max_tokens: 300,
            }),
          });
          const d = await r.json() as {
            choices?: [{ message: { content: string } }];
          };
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
        return json({
          success: true,
          org: { agents, departments: ["CEO", "CMO", "CTO", "CFO", "COO"] },
        });
      }

      case "my_agent.chat": {
        const message = asString(body.message) || "この画像を分析してください";
        const responseMode = asString(body.response_mode) || "text";
        const requestedProvider = asString(body.provider) ||
          asString(body.ai_provider) || "gemini";
        const agentProvider = requestedProvider === "manus"
          ? "manus"
          : "gemini";
        const parsedImage = parseInlineImage(body);
        if (parsedImage.error) {
          return json({ error: parsedImage.error }, parsedImage.status ?? 400);
        }
        const image = parsedImage.image;
        const history = await listItems(admin, "my_agent_history", userId!, 10);
        const recentContext = history.map((h) => {
          const m = h.metadata as Record<string, unknown>;
          return `User: ${m.message}\nAgent: ${m.response}`;
        }).join("\n");
        const imageInstruction = image
          ? "\n添付画像も確認し、見えている内容・文脈・ユーザーの質問に関係する示唆を含めて回答してください。"
          : "";
        const prompt = `あなたは個人AIエージェントです。${
          recentContext ? "履歴:\n" + recentContext + "\n\n" : ""
        }ユーザーメッセージ: ${message}${imageInstruction}`;
        let response = "";
        let videoMetadata: Record<string, unknown> | null = null;
        let manusMetadata: Record<string, unknown> | null = null;
        if (responseMode === "video") {
          const avatarImageUrl = asString(body.avatarImageUrl) || undefined;
          const voice = asString(body.voice) || undefined;
          const title = asString(body.title) || undefined;
          const conversationContext = asString(body.conversation_context) ||
            undefined;
          const assistantResponse = await invokeAiAssistant(
            req.headers.get("Authorization") ?? "",
            {
              action: "assistant_video_reply",
              message,
              content: prompt,
              useMagi: true,
              ...(avatarImageUrl ? { avatarImageUrl } : {}),
              ...(voice ? { voice } : {}),
              ...(title ? { title } : {}),
              ...(conversationContext ? { conversationContext } : {}),
              ...(image
                ? {
                  imageBase64: image.base64,
                  mimeType: image.mimeType,
                }
                : {}),
            },
          );
          const result = (assistantResponse.result ?? {}) as Record<
            string,
            unknown
          >;
          response = asString(result.script) || "動画回答を準備しました。";
          videoMetadata = {
            provider: asString(result.provider) || "hedra",
            status: asString(result.status) || "submitted",
            video_url: asString(result.videoUrl),
            preview_url: asString(result.previewUrl),
            download_url: asString(result.downloadUrl),
            reason: asString(result.reason),
            id: asString(result.id),
          };
        } else {
          if (agentProvider === "manus") {
            const manusKey = Deno.env.get("MANUS_API_KEY") ?? "";
            if (!manusKey) {
              return json({
                error: "MANUS_API_KEY not configured",
                provider: "manus",
              }, 503);
            }
            const result = await callManusTask(prompt, manusKey, image);
            response = result.response;
            manusMetadata = {
              task_id: result.taskId,
              task_url: result.taskUrl,
            };
          } else {
            const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
            if (!geminiKey) {
              return json({ error: "GEMINI_API_KEY not configured" }, 503);
            }
            response = await callGemini(prompt, geminiKey, image);
          }
        }
        await addItem(admin, "my_agent_history", userId!, {
          message,
          response,
          response_mode: responseMode,
          agent_provider: responseMode === "video" ? "hedra" : agentProvider,
          has_image: Boolean(image),
          image_mime_type: image?.mimeType ?? null,
          image_name: image?.name ?? null,
          image_base64_chars: image?.base64.length ?? 0,
          manus_task_id: manusMetadata?.task_id ?? null,
          manus_task_url: manusMetadata?.task_url ?? null,
          video_provider: videoMetadata?.provider ?? null,
          video_status: videoMetadata?.status ?? null,
          video_url: videoMetadata?.video_url ?? null,
          video_preview_url: videoMetadata?.preview_url ?? null,
          video_download_url: videoMetadata?.download_url ?? null,
          video_reason: videoMetadata?.reason ?? null,
          video_id: videoMetadata?.id ?? null,
        });
        return json({
          success: true,
          response,
          multimodal: Boolean(image),
          response_mode: responseMode,
          provider: responseMode === "video" ? "hedra" : agentProvider,
          manus: manusMetadata,
          video: videoMetadata,
        });
      }

      case "my_agent.history": {
        const items = await listItems(admin, "my_agent_history", userId!);
        return json({ success: true, history: items });
      }

      case "challenges.list": {
        const today = new Date().toISOString().split("T")[0];
        const existing = await listItems(admin, "daily_challenge", userId!, 3);
        if (existing.length > 0) {
          return json({ success: true, challenges: existing });
        }
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) return json({ success: true, challenges: [] });
        const prompt =
          `今日${today}のAI・生産性・健康に関するチャレンジを3つ生成してください。JSON: {"challenges":[{"id":"1","title":"...","description":"...","points":10,"category":"ai|productivity|health"}]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          const parsed = JSON.parse(text.replace(/```json\n?|\n?```/g, ""));
          for (const c of (parsed.challenges ?? [])) {
            await addItem(admin, "daily_challenge", userId!, {
              ...c as Record<string, unknown>,
              date: today,
            });
          }
          return json({ success: true, challenges: parsed.challenges ?? [] });
        } catch {
          return json({ success: true, challenges: [] });
        }
      }

      case "trigger.analyze": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const prompt = `行動トリガー分析: ${
          JSON.stringify(body)
        }. 引き金となる感情・状況・パターンを分析してください。JSON: {"triggers":[],"recommendations":[],"risk_level":"low|medium|high"}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text });
        }
      }

      case "analyze.reality": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const prompt = `現実分析: ${
          body.situation ?? ""
        }. 客観的な状況評価と改善策を提案してください。JSON: {"assessment":"...","score":0-100,"recommendations":[],"next_steps":[]}`;
        const text = await callGemini(prompt, geminiKey);
        try {
          return json({
            success: true,
            ...JSON.parse(text.replace(/```json\n?|\n?```/g, "")),
          });
        } catch {
          return json({ success: true, text });
        }
      }

      case "company_builder.list": {
        const companies = await listItems(
          admin,
          "company_builder_company",
          userId!,
          50,
        );
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

        const threshold = Math.max(
          1,
          Math.min(10, asNumber(body.threshold, 7)),
        );
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        const plan = await generateCompanyPlan(idea, threshold, geminiKey);
        const overallScore = computeOverallScore(plan.criteria);
        const passed = overallScore >= threshold;
        const companyName = plan.company_name;
        const companySlug = slugify(companyName);

        const companyRecord = await addItem(
          admin,
          "company_builder_company",
          userId!,
          {
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
          },
        );

        const companyId = String(companyRecord.id);
        await addCompanyAudit(
          admin,
          userId!,
          companyId,
          "company_builder.bootstrap_requested",
          {
            company_name: companyName,
            overall_score: overallScore,
            passed,
          },
        );

        const toolIds = await ensureSharedToolAgents(admin, userId!);
        const managerIds = await createManagerAgents(
          admin,
          userId!,
          companyId,
          companySlug,
          companyName,
          idea,
        );
        await seedCompanyMemories(
          admin,
          userId!,
          companyId,
          companyName,
          idea,
          plan,
          managerIds,
        );
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
        await addCompanyAudit(
          admin,
          userId!,
          companyId,
          "company_builder.bootstrap_completed",
          {
            company_name: companyName,
            manager_count: Object.keys(managerIds).length,
            tool_agent_count: Object.keys(toolIds).length,
            task_count: taskRows.length,
            workflow_id: workflow.id,
            vault_note_count: vaultNotes.length,
          },
        );

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

      case "university.content_all": {
        const limit = Math.min(Number(body.limit ?? 200), 500);
        const { data } = await admin.from("ai_university_content")
          .select("*")
          .order("published_at", { ascending: false })
          .limit(limit);
        return json({ success: true, items: data ?? [] });
      }

      case "university.upsert": {
        const { error } = await admin.from("ai_university_content").upsert(
          {
            provider: body.provider,
            category: body.category ?? "news",
            title: body.title,
            content: body.content,
            published_at: body.published_at ??
              new Date().toISOString().split("T")[0],
          },
          { onConflict: "provider,category" },
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

      case "university.leaderboard": {
        const limit = Math.min(Number(body.limit ?? 10), 100);
        const { data } = await admin.from("ai_university_leaderboard")
          .select("*")
          .limit(limit);
        return json({ success: true, leaderboard: data ?? [] });
      }

      case "university.streak_update": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data, error } = await admin.rpc("update_ai_university_streak", {
          p_user_id: userId,
        });
        if (error) throw new Error(error.message);
        const row = Array.isArray(data) && data.length > 0
          ? data[0] as {
            current_streak?: number;
            longest_streak?: number;
            is_new_streak_day?: boolean;
          }
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
        if (!badgeId || !badgeName) {
          return json({ error: "badge_id and badge_name required" }, 400);
        }
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
        const lapses = grade === 1
          ? ((existing?.lapses as number) ?? 0) + 1
          : ((existing?.lapses as number) ?? 0);
        let newStability = currentStability;
        let daysUntilNext = 1;
        if (grade === 1) {
          newStability = Math.max(currentStability * 0.5, 0.5);
          daysUntilNext = 1;
        } else if (grade === 2) {
          newStability = currentStability * 0.8;
          daysUntilNext = Math.max(newStability, 1);
        } else if (grade === 3) daysUntilNext = Math.max(currentStability, 1);
        else {
          newStability = currentStability * 1.3;
          daysUntilNext = Math.max(newStability * 1.3, 1);
        }
        const nextDue = new Date();
        nextDue.setDate(nextDue.getDate() + Math.round(daysUntilNext));
        const state = grade === 1
          ? "relearning"
          : reps > 2
          ? "review"
          : "learning";
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
        return json({
          success: true,
          next_due: nextDue.toISOString(),
          stability: newStability,
        });
      }

      // ── AI大学 v2: Memory Agent ──────────────────────────────────────────
      case "learner.update_profile": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const sessionSummary = String(body.session_summary ?? "");
        const scores = body.scores ?? [];
        const claudeKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
        if (!claudeKey) {
          return json({ error: "ANTHROPIC_API_KEY not configured" }, 503);
        }
        const prompt =
          `学習セッションのデータから構造化プロファイルを抽出してください。
セッションサマリー: ${sessionSummary}
スコアデータ: ${JSON.stringify(scores).slice(0, 2000)}
弱点プロバイダー・得意プロバイダー・学習スタイルをJSONで返してください。
形式: {"weak_providers":["..."],"strong_providers":["..."],"preferred_style":"visual|text|voice","insights":"..."}`;
        const claudeResp = await fetch(
          "https://api.anthropic.com/v1/messages",
          {
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
          },
        );
        const claudeData = await claudeResp.json() as Record<string, unknown>;
        const rawText =
          (claudeData.content as Array<{ text: string }>)?.[0]?.text ?? "{}";
        let profileJson: Record<string, unknown> = {};
        try {
          profileJson = JSON.parse(
            rawText.replace(/```json\n?|\n?```/g, "").trim(),
          );
        } catch { /* malformed */ }
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
          total_sessions: ((existingProfile?.total_sessions as number) ?? 0) +
            1,
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
        if (!groqKey) {
          return json({ error: "GROQ_API_KEY not configured" }, 503);
        }
        const groqResp = await fetch(
          "https://api.groq.com/openai/v1/chat/completions",
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${groqKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: "llama-3.3-70b-versatile",
              max_tokens: 100,
              temperature: 0,
              messages: [{
                role: "user",
                content:
                  `問題: ${question}\n模範回答: ${correctAnswer}\nユーザー回答: ${userAnswer}\n\n評価: {"result":"correct|incorrect|partial","confidence":0-100}`,
              }],
              response_format: { type: "json_object" },
            }),
          },
        ).catch(() => null);
        if (!groqResp || !groqResp.ok) {
          const isCorrect = userAnswer.trim().toLowerCase() ===
            correctAnswer.trim().toLowerCase();
          return json({
            success: true,
            result: isCorrect ? "correct" : "incorrect",
            confidence: 100,
            fallback: true,
          });
        }
        const groqData = await groqResp.json() as Record<string, unknown>;
        const raw =
          (groqData.choices as Array<{ message: { content: string } }>)?.[0]
            ?.message?.content ?? '{"result":"incorrect","confidence":0}';
        let evaluation: Record<string, unknown> = {
          result: "incorrect",
          confidence: 0,
        };
        try {
          evaluation = JSON.parse(raw);
        } catch { /* use default */ }
        return json({ success: true, ...evaluation });
      }

      case "quiz.explain": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const question = String(body.question ?? "");
        const userAnswer = String(body.user_answer ?? "");
        const correctAnswer = String(body.correct_answer ?? "");
        const provider = String(body.provider ?? "");
        const claudeKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
        if (!claudeKey) {
          return json({ error: "ANTHROPIC_API_KEY not configured" }, 503);
        }
        const prompt =
          `${provider} についての問題で不正解でした。わかりやすく詳細に解説してください。
問題: ${question}
正解: ${correctAnswer}
ユーザーの回答: ${userAnswer}
なぜ正解がそうなるのか、関連する背景知識も含めて日本語で300字以内で説明してください。`;
        const claudeResp2 = await fetch(
          "https://api.anthropic.com/v1/messages",
          {
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
          },
        );
        const claudeData2 = await claudeResp2.json() as Record<string, unknown>;
        const explanation =
          (claudeData2.content as Array<{ text: string }>)?.[0]?.text ??
            "解説を生成できませんでした。";
        return json({ success: true, explanation });
      }

      // ── AI大学 v2: Voice ─────────────────────────────────────────────────
      case "provider.chat": {
        // 汎用プロバイダー呼び出し (AI大学150社の実装済みAIに統一インターフェースで話しかける)
        // 対応: OpenAI互換 8社 (openai/xai/deepseek/groq/sambanova/openrouter/fireworks/together/arcee_ai)
        //       + 独自API 3社 (mistral/perplexity/cohere) + anthropic/google (MAGI互換)
        const providerId = String(body.provider ?? "");
        const messages = Array.isArray(body.messages) ? body.messages : null;
        const userMsg = String(body.message ?? "");
        if (!providerId) return json({ error: "provider required" }, 400);
        if (!messages && !userMsg) {
          return json({ error: "messages or message required" }, 400);
        }
        const finalMessages = messages ?? [{ role: "user", content: userMsg }];

        const cfg = PROVIDER_CONFIGS[providerId];
        if (!cfg) {
          return json({
            success: false,
            status: "notImplemented",
            message: `Provider "${providerId}" はまだ実装されていません。`,
          }, 400);
        }
        const apiKey = Deno.env.get(cfg.envKey) ?? "";
        if (!apiKey) {
          return json({
            success: false,
            status: "apiKeyRequired",
            secret_needed: cfg.envKey,
            message: `Supabase Secret ${cfg.envKey} を設定してください。`,
          });
        }

        try {
          // 認証方式はプロバイダーごとに異なる
          let authHeaders: Record<string, string> = {
            Authorization: `Bearer ${apiKey}`,
          };
          let fetchUrl = cfg.chatUrl;
          if (providerId === "anthropic") {
            authHeaders = {
              "x-api-key": apiKey,
              "anthropic-version": "2023-06-01",
            };
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
            body: JSON.stringify(
              cfg.buildBody(
                finalMessages,
                String(body.model ?? cfg.defaultModel),
              ),
            ),
          });
          const respText = await resp.text();
          if (!resp.ok) {
            // Free tier / 課金制限検知
            if (
              respText.includes("paid_plan_required") ||
              respText.includes("payment_required") ||
              resp.status === 402 || respText.includes("insufficient_quota") ||
              respText.includes("billing") || respText.includes("credit")
            ) {
              return json({
                success: false,
                status: "paidPlanRequired",
                provider: providerId,
                message:
                  `${cfg.displayName} はプロバイダー側で課金が必要です。`,
                detail: respText.slice(0, 300),
              });
            }
            return json({
              success: false,
              status: "error",
              provider: providerId,
              http_status: resp.status,
              detail: respText.slice(0, 500),
            }, 502);
          }
          let data: unknown;
          try {
            data = JSON.parse(respText);
          } catch {
            return json({
              success: true,
              provider: providerId,
              status: "implemented",
              text: respText.slice(0, 2000),
            });
          }
          const content = cfg.parseResponse(data);
          const modelUsed = pick(data, "model");
          return json({
            success: true,
            provider: providerId,
            status: "implemented",
            text: content,
            model: modelUsed ?? cfg.defaultModel,
          });
        } catch (e) {
          return json({
            success: false,
            status: "error",
            provider: providerId,
            message: String(e),
          }, 500);
        }
      }

      case "provider.chat_auto": {
        const requestedTier = body.tier as Tier | undefined;
        const messages = Array.isArray(body.messages) ? body.messages : null;
        const userMsg = String(body.message ?? "");
        if (!messages && !userMsg) {
          return json({ error: "messages or message required" }, 400);
        }
        const finalMessages = messages ?? [{ role: "user", content: userMsg }];
        const startTierIndex = requestedTier
          ? TIER_ORDER.indexOf(requestedTier)
          : 0;
        if (startTierIndex === -1) return json({ error: "invalid tier" }, 400);

        // Win版#131 part 4: Observability — trace_id / session_id / latency 計測
        const requestStartedAt = performance.now();
        const traceId = String(body.trace_id ?? crypto.randomUUID());
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;

        let resultText: string | undefined;
        let usedProvider: string | undefined;
        let usedTier: Tier | undefined;
        let usedModel: string | undefined;

        outerLoop:
        for (let ti = startTierIndex; ti < TIER_ORDER.length; ti++) {
          const tier = TIER_ORDER[ti];
          const providers = TIER_PROVIDERS[tier].filter((p) =>
            p in PROVIDER_CONFIGS
          );
          for (const pid of providers) {
            const result = await callSingleProvider(
              pid,
              finalMessages,
              undefined,
            );
            if (result.ok && result.text) {
              resultText = result.text;
              usedProvider = pid;
              usedTier = tier;
              usedModel = result.modelUsed;
              break outerLoop;
            }
          }
        }

        if (!resultText || !usedProvider || !usedTier) {
          // Win版#131 part 4: 失敗ケースも観測ログに記録 (flaky provider 検出のため)
          try {
            const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
            const inputChars = finalMessages
              .map((m) => typeof m.content === "string" ? m.content.length : 0)
              .reduce((a, b) => a + b, 0);
            await admin.from("ai_hub_chat_logs").insert({
              provider: "all",
              tier: requestedTier ?? "auto",
              success: false,
              latency_ms: Math.round(performance.now() - requestStartedAt),
              trace_id: traceId,
              session_id: sessionId,
              input_chars: inputChars,
              error_message: "all tiers exhausted",
              action: "provider.chat_auto",
              status_code: 502,
            });
          } catch { /* ignore */ }
          return json({
            success: false,
            status: "allProvidersFailed",
            message: "すべての Tier のプロバイダーが失敗しました",
          }, 502);
        }

        // コスト + 観測データ記録 (best-effort、失敗してもレスポンスには影響しない)
        // Win版#131 part 4: latency_ms / trace_id / session_id / input_chars / output_chars
        const latencyMs = Math.round(performance.now() - requestStartedAt);
        try {
          const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
          const inputChars = finalMessages
            .map((m) => typeof m.content === "string" ? m.content.length : 0)
            .reduce((a, b) => a + b, 0);
          const outputChars = resultText?.length ?? 0;
          const estimatedCost = TIER_COST_USD_PER_1K[usedTier] *
            (inputChars / 1000);
          await admin.from("ai_hub_chat_logs").insert({
            provider: usedProvider,
            tier: usedTier,
            success: true,
            estimated_cost_usd: estimatedCost,
            model: usedModel ?? null,
            latency_ms: latencyMs,
            trace_id: traceId,
            session_id: sessionId,
            input_chars: inputChars,
            output_chars: outputChars,
            action: "provider.chat_auto",
            status_code: 200,
          });
        } catch { /* ignore logging errors */ }

        return json({
          success: true,
          provider: usedProvider,
          tier: usedTier,
          model: usedModel ?? PROVIDER_CONFIGS[usedProvider]?.defaultModel,
          status: "implemented",
          text: resultText,
        });
      }

      case "edge_llm.invoke": {
        const requestedTier = body.tier as Tier | undefined;
        const providerId = asString(body.provider) || undefined;
        const systemPrompt = asString(body.system_prompt);
        const userPrompt = asString(body.user_prompt) ||
          asString(body.prompt) ||
          asString(body.message);
        if (!userPrompt) {
          return json({ error: "user_prompt required" }, 400);
        }

        const responseFormat = asString(body.response_format) === "json"
          ? "json"
          : "text";
        const contextPayload = body.context_data ?? body.context ?? null;
        const contextText = contextPayload == null
          ? ""
          : typeof contextPayload === "string"
          ? contextPayload.trim()
          : JSON.stringify(contextPayload, null, 2);
        const userContentParts = [
          "# User request",
          userPrompt,
        ];
        if (contextText.length > 0) {
          userContentParts.push(
            "\n# Context data\n```json\n" + contextText + "\n```",
          );
        }
        userContentParts.push(
          "\n# Output instructions",
          responseFormat === "json"
            ? "Return valid JSON only. Do not add markdown fences or commentary."
            : "Respond in concise Japanese plain text.",
        );
        const finalMessages = [];
        if (systemPrompt.length > 0) {
          finalMessages.push({
            role: "system",
            content: systemPrompt,
          });
        }
        finalMessages.push({
          role: "user",
          content: userContentParts.join("\n"),
        });

        const requestStartedAt = performance.now();
        const traceId = String(body.trace_id ?? crypto.randomUUID());
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;
        const explicitModel = asString(body.model) || undefined;

        let resultText: string | undefined;
        let usedProvider: string | undefined;
        let usedTier: Tier | undefined;
        let usedModel: string | undefined;
        let failureDetail: string | undefined;

        if (providerId) {
          const cfg = PROVIDER_CONFIGS[providerId];
          if (!cfg) {
            return json({
              success: false,
              status: "notImplemented",
              message: `Provider "${providerId}" is not available in ai-hub`,
            }, 400);
          }
          const apiKey = Deno.env.get(cfg.envKey) ?? "";
          if (!apiKey) {
            return json({
              success: false,
              status: "apiKeyRequired",
              secret_needed: cfg.envKey,
              message: `Supabase Secret ${cfg.envKey} is required`,
            }, 503);
          }
          const result = await callSingleProvider(
            providerId,
            finalMessages,
            explicitModel,
          );
          if (result.ok && result.text) {
            resultText = result.text;
            usedProvider = providerId;
            usedTier = providerTier(providerId) ?? requestedTier ??
              "performance";
            usedModel = result.modelUsed;
          } else {
            failureDetail = result.error ?? "provider failed";
          }
        } else {
          const startTierIndex = requestedTier
            ? TIER_ORDER.indexOf(requestedTier)
            : 0;
          if (startTierIndex === -1) {
            return json({ error: "invalid tier" }, 400);
          }

          outerLoop:
          for (let ti = startTierIndex; ti < TIER_ORDER.length; ti++) {
            const tier = TIER_ORDER[ti];
            const providers = TIER_PROVIDERS[tier].filter((p) =>
              p in PROVIDER_CONFIGS
            );
            for (const pid of providers) {
              const result = await callSingleProvider(
                pid,
                finalMessages,
                explicitModel,
              );
              if (result.ok && result.text) {
                resultText = result.text;
                usedProvider = pid;
                usedTier = tier;
                usedModel = result.modelUsed;
                break outerLoop;
              }
            }
          }
          if (!resultText) {
            failureDetail = "all tiers exhausted";
          }
        }

        const latencyMs = Math.round(performance.now() - requestStartedAt);
        const inputChars = finalMessages
          .map((m) => typeof m.content === "string" ? m.content.length : 0)
          .reduce((a, b) => a + b, 0);

        if (!resultText || !usedProvider || !usedTier) {
          try {
            const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
            await admin.from("ai_hub_chat_logs").insert({
              provider: providerId ?? "all",
              tier: requestedTier ?? "auto",
              success: false,
              latency_ms: latencyMs,
              trace_id: traceId,
              session_id: sessionId,
              input_chars: inputChars,
              error_message: failureDetail ?? "edge_llm.invoke failed",
              action: "edge_llm.invoke",
              status_code: 502,
            });
          } catch {
            // ignore logging errors
          }

          return json({
            success: false,
            status: "providerFailed",
            provider: providerId,
            detail: failureDetail ?? "edge_llm.invoke failed",
          }, 502);
        }

        const outputChars = resultText.length;
        const estimatedCost = TIER_COST_USD_PER_1K[usedTier] *
          (inputChars / 1000);
        let parsedJson: unknown = null;
        let parseError: string | undefined;
        if (responseFormat === "json") {
          try {
            parsedJson = JSON.parse(stripMarkdownCodeFence(resultText));
          } catch (error) {
            parseError = String(error);
          }
        }

        try {
          const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
          await admin.from("ai_hub_chat_logs").insert({
            provider: usedProvider,
            tier: usedTier,
            success: true,
            estimated_cost_usd: estimatedCost,
            model: usedModel ?? null,
            latency_ms: latencyMs,
            trace_id: traceId,
            session_id: sessionId,
            input_chars: inputChars,
            output_chars: outputChars,
            action: "edge_llm.invoke",
            status_code: 200,
          });
        } catch {
          // ignore logging errors
        }

        return json({
          success: true,
          status: "implemented",
          provider: usedProvider,
          tier: usedTier,
          model: usedModel ?? PROVIDER_CONFIGS[usedProvider]?.defaultModel,
          text: resultText,
          response_format: responseFormat,
          parsed_json: parsedJson,
          parse_error: parseError,
          observability: {
            provider: usedProvider,
            model: usedModel ?? PROVIDER_CONFIGS[usedProvider]?.defaultModel,
            latency_ms: latencyMs,
            estimated_cost_usd: estimatedCost,
            trace_id: traceId,
            session_id: sessionId,
            input_chars: inputChars,
            output_chars: outputChars,
            action: "edge_llm.invoke",
            status_code: 200,
          },
        });
      }

      case "provider.list": {
        // UIから呼ばれる: 各プロバイダーのEnv有無だけ返す (APIコールなし・安全)
        const result: Record<
          string,
          { envConfigured: boolean; displayName: string }
        > = {};
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
          return json({
            success: false,
            fallback: "webspeech",
            text,
            reason: "ELEVENLABS_API_KEY not configured",
          });
        }
        const ttsResp = await fetch(
          `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
          {
            method: "POST",
            headers: {
              "xi-api-key": elevenKey,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              text,
              model_id: "eleven_multilingual_v2",
              voice_settings: { stability: 0.5, similarity_boost: 0.75 },
            }),
          },
        );
        if (!ttsResp.ok) {
          const errText = await ttsResp.text();
          // Free-tier / paid-plan-required → フォールバックで Web Speech API 利用を UI に通知
          if (
            errText.includes("paid_plan_required") ||
            errText.includes("payment_required")
          ) {
            return json({
              success: false,
              fallback: "webspeech",
              text,
              reason: "elevenlabs_paid_plan_required",
            });
          }
          return json({
            error: `ElevenLabs error: ${errText}`,
            fallback: "webspeech",
            text,
          }, 502);
        }
        const audioBuffer = await ttsResp.arrayBuffer();
        const bytes = new Uint8Array(audioBuffer);
        let binary = "";
        for (let i = 0; i < bytes.byteLength; i++) {
          binary += String.fromCharCode(bytes[i]);
        }
        const base64Audio = btoa(binary);
        return json({
          success: true,
          audio_base64: base64Audio,
          content_type: "audio/mpeg",
        });
      }

      case "voice.stt": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const audioBase64 = String(body.audio_base64 ?? "");
        const language = String(body.language ?? "ja");
        const deepgramKey = Deno.env.get("DEEPGRAM_API_KEY") ?? "";
        if (!deepgramKey) {
          return json({ error: "DEEPGRAM_API_KEY not configured" }, 503);
        }
        let audioBytes: Uint8Array;
        try {
          audioBytes = Uint8Array.from(
            atob(audioBase64),
            (c) => c.charCodeAt(0),
          );
        } catch {
          return json({ error: "Invalid base64 audio data" }, 400);
        }
        const audioBody = new ArrayBuffer(audioBytes.byteLength);
        new Uint8Array(audioBody).set(audioBytes);
        const dgResp = await fetch(
          `https://api.deepgram.com/v1/listen?language=${language}&model=nova-2&punctuate=true`,
          {
            method: "POST",
            headers: {
              "Authorization": `Token ${deepgramKey}`,
              "Content-Type": "audio/webm",
            },
            body: audioBody,
          },
        );
        if (!dgResp.ok) {
          const errText = await dgResp.text();
          return json({ error: `Deepgram error: ${errText}` }, 502);
        }
        const dgData = await dgResp.json() as Record<string, unknown>;
        const transcript =
          ((dgData.results as Record<string, unknown>)?.channels as Array<
            Record<string, unknown>
          >)?.[0]?.alternatives as Array<{ transcript: string }>;
        const transcriptText = transcript?.[0]?.transcript ?? "";
        return json({ success: true, transcript: transcriptText });
      }

      case "home.recommend": {
        // Windows版#94: home_tier AI おすすめ機能 (VSCode#98)
        // 現状はヒューリスティックで user_feature_usage を集計し、
        // 直近未使用のシステム固定機能を返す (Gemini 推論は次段階)
        const userId = String(body.user_id ?? "");
        if (!userId) return json({ error: "user_id required" }, 400);
        const { data: usage } = await admin.from("user_feature_usage")
          .select("feature_id, last_used_at, use_count")
          .eq("user_id", userId)
          .order("last_used_at", { ascending: false })
          .limit(30);
        const recent = new Set(
          (usage ?? []).map((r: Record<string, unknown>) =>
            String(r.feature_id)
          ),
        );
        const recommendations: Array<Record<string, unknown>> = [];
        const suggestions = [
          {
            id: "ai-search",
            title: "AI 検索",
            reason: "自然言語で過去メモを横断検索",
          },
          {
            id: "daily-judgment",
            title: "今日のデイリー判定",
            reason: "AI が当日の行動を評価",
          },
          {
            id: "ai-assistant-chat",
            title: "AI アシスタントチャット",
            reason: "MAGI 3 モデル並列思考",
          },
          {
            id: "ai-summarizer",
            title: "AI 要約",
            reason: "長文を要点だけに圧縮",
          },
          {
            id: "home-insights",
            title: "成長・支援ダッシュボード",
            reason: "学習・開発・成長の統合ビュー",
          },
          {
            id: "horseracing-predictor",
            title: "競馬 AI 予想",
            reason: "マルチプロバイダーアンサンブル予想",
          },
          {
            id: "ai-university",
            title: "AI 大学",
            reason: "FSRS で AI 最新動向を学習",
          },
        ];
        for (const s of suggestions) {
          if (!recent.has(s.id)) recommendations.push(s);
          if (recommendations.length >= 5) break;
        }
        return json({ success: true, recommendations });
      }

      // ── Observability (Win版#131 part 4 / NotebookLM f56cc07c) ────────────────
      // SQL views (provider_health_view / provider_heatmap_view / session_trace_view)
      // を Flutter から安全に参照するためのラッパー
      case "observability.provider_health": {
        const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
        const { data, error } = await admin
          .from("provider_health_view")
          .select("*")
          .order("total_requests", { ascending: false });
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, providers: data ?? [] });
      }
      case "observability.heatmap": {
        const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
        const provider = body.provider as string | undefined;
        let q = admin.from("provider_heatmap_view").select("*").limit(500);
        if (provider) q = q.eq("provider", provider);
        const { data, error } = await q;
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, cells: data ?? [] });
      }
      case "observability.sessions": {
        const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
        const limit = Math.min(Number(body.limit ?? 50), 200);
        const { data, error } = await admin
          .from("session_trace_view")
          .select("*")
          .order("started_at", { ascending: false })
          .limit(limit);
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, sessions: data ?? [] });
      }
      case "observability.session_steps": {
        const sessionId = String(body.session_id ?? "");
        if (!sessionId) return json({ error: "session_id required" }, 400);
        const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
        const { data, error } = await admin
          .from("ai_hub_chat_logs")
          .select(
            "id, provider, tier, action, success, latency_ms, status_code, error_message, " +
              "input_chars, output_chars, estimated_cost_usd, model, trace_id, created_at",
          )
          .eq("session_id", sessionId)
          .order("created_at", { ascending: true });
        if (error) return json({ error: error.message }, 400);
        return json({ success: true, steps: data ?? [] });
      }

      // ---- Election analysis (Gemini direct, JSON mode) ----
      case "election.analyze": {
        const geminiApiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiApiKey) {
          return json({ success: false, error: "GEMINI_API_KEY not set" }, 500);
        }
        const prompt = `
あなたは優秀な政治アナリスト・リサーチャーです。
国民民主党の統一地方選に向けた「700人必達」目標（現状約340人、純増目標約360人）の月次KPI管理、および現在の所属地方議員の最新情報を調査・整理してください。

必ず以下のJSONスキーマに従った形式で出力してください。JSON以外のテキストは含めないでください。

{
  "type": "object",
  "properties": {
    "politicians": {
      "type": "array",
      "description": "現在ネット上で確認できる国民民主党の所属地方議員のリスト（代表的な数名〜10名程度をピックアップしてください）",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "number" },
          "name": { "type": "string" },
          "region": { "type": "string", "description": "都道府県" },
          "municipality": { "type": "string", "description": "市区町村（県議の場合は空文字または県名）" },
          "type": { "type": "string", "description": "県議、市議、区議、町議など" },
          "gender": { "type": "string", "description": "男性 または 女性" },
          "age": { "type": "number", "description": "年齢が不明な場合は推測値または0" },
          "profile": { "type": "string", "description": "簡易プロフィール" }
        },
        "required": ["id", "name", "region", "municipality", "type", "gender", "age", "profile"]
      }
    },
    "monthlyKpi": {
      "type": "object",
      "description": "統一地方選700人倍増に向けた工程管理KPI（都道府県連ごとの配分シミュレーション）",
      "properties": {
        "targetTotal": { "type": "number", "description": "700" },
        "currentTotal": { "type": "number", "description": "340" },
        "requiredAddition": { "type": "number", "description": "360" },
        "message": { "type": "string", "description": "工程管理の重要性を伝えるメッセージ" },
        "regions": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "current": { "type": "number" },
              "target": { "type": "number" },
              "newCandidates": { "type": "number" },
              "supportCount": { "type": "number" },
              "expectedEndorsement": { "type": "string" }
            },
            "required": ["name","current","target","newCandidates","supportCount","expectedEndorsement"]
          }
        }
      },
      "required": ["targetTotal","currentTotal","requiredAddition","message","regions"]
    }
  },
  "required": ["politicians","monthlyKpi"]
}
`;
        try {
          const r = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
            {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: {
                  responseMimeType: "application/json",
                  temperature: 0.2,
                },
              }),
            },
          );
          if (!r.ok) {
            const errBody = await r.text();
            return json({
              success: false,
              error: `Gemini ${r.status}: ${errBody}`,
            }, 500);
          }
          const data = await r.json();
          const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
          if (!text) {
            return json(
              { success: false, error: "Empty Gemini response" },
              500,
            );
          }
          const parsed = JSON.parse(text);
          return json({
            success: true,
            politicians: parsed.politicians ?? [],
            monthlyKpi: parsed.monthlyKpi ?? {},
            generatedAt: new Date().toISOString(),
          });
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          return json({ success: false, error: msg }, 500);
        }
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
