// ai-hub — AI・エージェント・AI大学統合EF
// Merges (16 EFs): daily-judgment, ai-search, ai-suggest-tags, ai-secretary,
//   ai-summarizer, agent-hub, virtual-organization, my-ai-agent,
//   generate-daily-challenges, trigger-analysis, analyze-reality,
//   local-election-intelligence, ai-university-content,
//   ai-university-streaks, ai-university-badges
// NOTE: ai-assistant stays standalone (1079 lines, complex multi-provider logic)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { checkAndRecordAiUsage, supabaseUsageStore } from "./usage_gate.ts";
import {
  authorizeAiHubAction,
  resolveAuthenticatedUserId,
} from "./action_access_policy.ts";
import {
  AI_CHARACTER_PREAMBLE,
  buildAiSystemPrompt,
  prependCharacter,
} from "../_shared/ai_character_preamble.ts";
import {
  buildExternalFileContextBlock,
  MCP_FILE_CONTEXT_SOURCE,
} from "../_shared/mcp_external_file.ts";
import {
  type AgentToolApproval,
  type AgentToolPolicyDecision,
  evaluateAgentToolPolicy,
} from "../_shared/agent_tool_policy.ts";
import {
  selectClaudeModelForEffort,
  selectEffort,
} from "../_shared/effort_router.ts";
import { requestTraceId } from "../_shared/trace_context.ts";
import {
  calculateApiCost,
  checkBudget,
  recordSpend,
} from "../_shared/task_budget.ts";
import {
  buildOfflineBlockedResponseBody,
  parseOfflineSecureModePolicy,
  shouldBlockExternalProviderCall,
} from "../_shared/offline_secure_mode_guard.ts";
import {
  normalizeAiRouterPreference,
  normalizeAiRoutingTask,
} from "../_shared/ai_router_cost_optimization.ts";
import {
  buildTaskClarityPrompt,
  evaluateTaskClarityHeuristically,
  normalizeTaskClarityResult,
} from "../_shared/task_clarity.ts";
import {
  getUniversityContentByFaculty,
  getUniversityDepartmentList,
  getUniversityFacultyList,
  getUniversityProviderByDepartment,
  UniversityActionError,
} from "./university_faculty_actions.ts";
import {
  handleMonthlyAssetReportAction,
  isMonthlyAssetReportAiSummaryEnabled,
  MonthlyAssetReportActionError,
  type MonthlyAssetReportDb,
  normalizeMonthlyAssetReportProvider,
} from "./monthly_asset_report.ts";
import { AssetChatActionError, handleAssetChatAction } from "./asset_chat.ts";
import { createSupabaseAssetChatStore } from "./asset_chat_supabase.ts";
import {
  DepartmentFinanceSummaryActionError,
  type DepartmentFinanceSummaryDb,
  handleDepartmentFinanceSummaryAction,
} from "./department_finance_summary_actions.ts";
import {
  handleParsePayslipAction,
  isPayslipIngestionAction,
  type PayslipDb,
  PayslipIngestionError,
  type PayslipStorage,
} from "./payslip_ingestion.ts";
import {
  type ExpenseAiDb,
  ExpenseAiError,
  handleClassifyExpenseAction,
  handleWeeklySpendingCoachingAction,
} from "./expense_ai.ts";
import {
  type DisposableBalanceDb,
  DisposableBalanceError,
  handleDisposableBalanceAction,
} from "./disposable_balance.ts";
import {
  type AnomalyDetectionDb,
  AnomalyDetectionError,
  handleDetectAnomaliesAction,
  handleScanAllAction,
} from "./anomaly_detection.ts";
import {
  handleMarketPriceAction,
  isMarketPriceLiveFetchEnabled,
  MarketPriceActionError,
  type MarketPriceDb,
} from "./market_price.ts";
import { applyProviderGenerationOptions } from "./provider_generation_options.ts";
import {
  concatenateAudio,
  normalizeVoiceId,
  normalizeVoiceLanguage,
  normalizeVoiceSettings,
  resolveVoiceDubbingModel,
  safeAudioFileName,
  splitVoiceText,
  VOICE_DUBBING_BUCKET,
  voiceCharacterLimit,
} from "./voice_dubbing.ts";
import {
  buildCompanyRuntimePrompt,
  nextCompanyRuntimeRoutingProfile,
  parseCompanyRuntimeQueueMessages,
  selectCompanyRuntimeRouting,
} from "./company_builder_runtime.ts";
import {
  buildExtractiveResearchFallback,
  buildResearchCitationContext,
  canonicalResearchUrl,
  chunkResearchMarkdown,
  ensureCitationFooter,
  fetchPublicResearchDocument,
  normalizeResearchCitations,
  type ResearchCitation,
  sha256Hex,
} from "./company_research.ts";
import {
  CORPORATE_SITE_READINESS_DISCLAIMER,
  generateCorporateSiteHtml,
  reviewCorporateSiteDocument,
  validateCorporateSiteProfile,
} from "./corporate_site_readiness.ts";
import {
  assertA2AVersion,
  buildCompanyAgentCard,
  COMPANY_A2A_CONTENT_TYPE,
  COMPANY_A2A_PROTOCOL_VERSION,
  companyTaskToA2A,
  decodeA2APageToken,
  encodeA2APageToken,
  parseA2ASendMessage,
} from "./company_a2a.ts";
import { rankBm25 } from "../memory-search-hub/search/bm25.ts";
import { embedTextWithGemini } from "../memory-search-hub/search/vector.ts";
import {
  buildSubscriptionStatementPrompt,
  parseSubscriptionStatementResponse,
} from "./subscription_statement_scan.ts";
import {
  createWriterKnowledgeGraphGateway,
  handleWriterKnowledgeGraphAction,
  WriterKnowledgeGraphError,
} from "./writer_knowledge_graph.ts";
import { createSupabaseWriterKnowledgeGraphStore } from "./writer_knowledge_graph_supabase.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, a2a-version, a2a-extensions, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Expose-Headers": "A2A-Version, WWW-Authenticate",
  "Access-Control-Max-Age": "86400",
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

function a2aJson(
  data: unknown,
  status = 200,
  extraHeaders: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "A2A-Version": COMPANY_A2A_PROTOCOL_VERSION,
      "Content-Type": COMPANY_A2A_CONTENT_TYPE,
      ...Object.fromEntries(new Headers(extraHeaders)),
    },
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
  buildBody: (
    messages: unknown[],
    model: string,
    inlineFiles?: ProviderInlineFile[],
  ) => Record<string, unknown>;
  parseResponse: (data: unknown) => string;
};

type InlineImage = {
  base64: string;
  mimeType: string;
  name: string | null;
};

type ProviderInlineFile = {
  base64: string;
  mimeType: string;
  name?: string | null;
};

type ProviderCallOptions = {
  maxTokens?: number;
  /// この 1 呼び出しの timeout (ms)。未指定なら providerFetchTimeoutMs()。
  /// chat_auto はリクエスト全体予算から残り時間を配分して渡す。
  timeoutMs?: number;
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

function buildGoogleGeminiBody(
  messages: unknown[],
  inlineFiles: ProviderInlineFile[] = [],
): Record<string, unknown> {
  const contents = (messages as { role: string; content: string }[]).map(
    (m) => {
      const parts: Record<string, unknown>[] = [{ text: m.content }];
      return {
        role: m.role === "assistant" ? "model" : "user",
        parts,
      };
    },
  );
  if (inlineFiles.length > 0) {
    if (contents.length === 0) {
      contents.push({ role: "user", parts: [] });
    }
    const target = contents[contents.length - 1];
    for (const file of inlineFiles) {
      target.parts.push({
        inline_data: {
          mime_type: file.mimeType,
          data: file.base64,
        },
      });
    }
  }
  return { contents };
}

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
    defaultModel: "deepseek-v4-flash",
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
    buildBody: (messages, _model, inlineFiles) =>
      buildGoogleGeminiBody(messages, inlineFiles),
    parseResponse: (data) =>
      String(pick(data, "candidates", 0, "content", "parts", 0, "text") ?? ""),
  },
  // Master Brain 提案 #1 (Win版#132 part 29 / 2026-04-26): バッチ処理向け軽量・低コスト Gemini
  // 用途: competitor-monitoring / ai-university-update 等の大量バッチ推論
  // コスト目安: gemini-2.5-flash-lite は通常 flash の 1/3 価格・1M tokens context
  google_flash_lite: {
    displayName: "Google Gemini Flash-Lite",
    envKey: "GEMINI_API_KEY",
    chatUrl:
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent",
    defaultModel: "gemini-2.5-flash-lite",
    buildBody: (messages, _model, inlineFiles) =>
      buildGoogleGeminiBody(messages, inlineFiles),
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
  // 実障害(2026-07-07): free 先頭の遅延プロバイダが chat_auto の時間予算を
  // 焼き尽くし 2 連続 503。高速推論ホスト(groq/cerebras)を先頭に置く。
  // key 未設定のプロバイダは callSingleProvider が即 fail するので無害。
  free: ["groq", "cerebras", "deepseek", "siliconflow", "novita_ai"],
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

const TIER_ORDER: Tier[] = ["free", "budget", "performance", "premium"];

function effortToTier(effort: "low" | "medium" | "high" | "xhigh"): Tier {
  switch (effort) {
    case "low":
      return "free";
    case "medium":
      return "budget";
    case "high":
      return "performance";
    case "xhigh":
      return "premium";
  }
}

function routedClaudeModel(effort: "low" | "medium" | "high" | "xhigh") {
  return selectClaudeModelForEffort(effort, {
    haikuModel: Deno.env.get("CLAUDE_ROUTER_HAIKU_MODEL"),
    sonnetModel: Deno.env.get("CLAUDE_ROUTER_SONNET_MODEL"),
  });
}

function estimateTokensFromChars(chars: number): number {
  return Math.max(1, Math.ceil(Math.max(0, chars) / 4));
}

function providerUsageTokens(data: unknown): {
  inputTokens?: number;
  outputTokens?: number;
} {
  const input = pick(data, "usage", "input_tokens") ??
    pick(data, "usage", "prompt_tokens") ??
    pick(data, "usageMetadata", "promptTokenCount");
  const output = pick(data, "usage", "output_tokens") ??
    pick(data, "usage", "completion_tokens") ??
    pick(data, "usageMetadata", "candidatesTokenCount");
  const normalize = (value: unknown): number | undefined =>
    typeof value === "number" && Number.isFinite(value) && value >= 0
      ? Math.round(value)
      : undefined;
  return {
    inputTokens: normalize(input),
    outputTokens: normalize(output),
  };
}

function normalizeMaxTokens(value: unknown): number | undefined {
  const raw = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(raw) || raw <= 0) return undefined;
  return Math.max(64, Math.min(8192, Math.round(raw)));
}

function providerFinishReason(data: unknown): string | null {
  const raw = pick(data, "choices", 0, "finish_reason") ??
    pick(data, "candidates", 0, "finishReason") ??
    pick(data, "stop_reason");
  return typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : null;
}

function isProviderOutputLengthLimited(reason: string | null): boolean {
  const normalized = reason?.toLowerCase().replace(/[_\s-]+/g, "") ?? "";
  return normalized === "length" || normalized === "maxtokens" ||
    normalized === "maxoutputtokens";
}

function isProviderPaymentRequired(
  status: number,
  responseText: string,
): boolean {
  const text = responseText.toLowerCase();
  return status === 402 ||
    text.includes("paid_plan_required") ||
    text.includes("payment_required") ||
    text.includes("insufficient_quota") ||
    text.includes("positive balance") ||
    text.includes("add balance") ||
    text.includes("top-up") ||
    text.includes("billing") ||
    text.includes("credit");
}

async function callSingleProvider(
  providerId: string,
  messages: { role: string; content: string }[],
  model?: string,
  inlineFiles?: ProviderInlineFile[],
  options?: ProviderCallOptions,
): Promise<
  {
    ok: boolean;
    text?: string;
    modelUsed?: string;
    inputTokens?: number;
    outputTokens?: number;
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
    } else if (providerId === "google" || providerId === "google_flash_lite") {
      authHeaders = {};
      fetchUrl = `${cfg.chatUrl}?key=${apiKey}`;
    }
    // プロバイダがハング/遅延すると edge function が wall-clock 上限を超えて
    // ランタイムに kill され 502 になる。AbortController で時間を区切り、
    // タイムアウトは catch で {ok:false, isRetriable:true} に落ちて別プロバイダ
    // へのフォールバックに繋がる (502 を避ける)。
    const controller = new AbortController();
    const timeoutId = setTimeout(
      () => controller.abort(),
      options?.timeoutMs ?? providerFetchTimeoutMs(),
    );
    let resp: Response;
    let respText: string;
    try {
      resp = await fetch(fetchUrl, {
        method: "POST",
        headers: {
          ...authHeaders,
          "Content-Type": "application/json",
          ...(cfg.extraHeaders ?? {}),
        },
        body: JSON.stringify(
          applyProviderGenerationOptions(
            providerId,
            cfg.buildBody(messages, model ?? cfg.defaultModel, inlineFiles),
            options,
          ),
        ),
        signal: controller.signal,
      });
      respText = await resp.text();
    } finally {
      clearTimeout(timeoutId);
    }
    if (!resp.ok) {
      const paymentRequired = isProviderPaymentRequired(resp.status, respText);
      const isRetriable = paymentRequired || resp.status === 429 ||
        resp.status >= 500;
      return {
        ok: false,
        error: paymentRequired
          ? `paidPlanRequired: ${providerId}: ${respText.slice(0, 240)}`
          : `HTTP ${resp.status}: ${respText.slice(0, 240)}`,
        isRetriable,
      };
    }
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
    const finishReason = providerFinishReason(data);
    if (content && isProviderOutputLengthLimited(finishReason)) {
      return {
        ok: false,
        error: `outputLengthLimited: ${providerId}: ${finishReason}`,
        modelUsed: model ?? cfg.defaultModel,
        isRetriable: true,
      };
    }
    const modelUsed =
      (typeof (data as Record<string, unknown>)?.model === "string"
        ? (data as Record<string, unknown>).model
        : model ?? cfg.defaultModel) as string;
    const usage = providerUsageTokens(data);
    return {
      ok: true,
      text: content,
      modelUsed,
      inputTokens: usage.inputTokens,
      outputTokens: usage.outputTokens,
      isRetriable: false,
    };
  } catch (e) {
    return { ok: false, error: String(e), isRetriable: true };
  }
}

/// LLM プロバイダ呼び出しのタイムアウト (ms)。遅延/ハングするプロバイダで edge
/// function が wall-clock 上限を超えて 502 になるのを防ぐ。`AI_HUB_PROVIDER_TIMEOUT_MS`
/// で調整可 (既定 90s = 正常な LLM 応答には十分長く、無限待機は防ぐ)。
function providerFetchTimeoutMs(): number {
  const raw = Number(Deno.env.get("AI_HUB_PROVIDER_TIMEOUT_MS"));
  return Number.isFinite(raw) && raw > 0 ? raw : 90_000;
}

/// provider.chat_auto の「リクエスト全体」予算 (ms)。実障害(2026-07-06): 各
/// プロバイダ 90s timeout のまま複数プロバイダが遅延すると合計が edge の
/// wall-clock を超え、gateway に ~66s で kill されて生の 502 が返った。
/// `AI_HUB_CHAT_TOTAL_BUDGET_MS` で調整可 (既定 45s)。クライアント側の
/// universal-x-share は 45s timeout + 1 retry — 両者は結合しているので
/// 変更時はセットで見直す。
function chatTotalBudgetMs(): number {
  const raw = Number(Deno.env.get("AI_HUB_CHAT_TOTAL_BUDGET_MS"));
  return Number.isFinite(raw) && raw > 0 ? raw : 45_000;
}

/// chat_auto の 1 プロバイダ呼び出し上限 (ms)。ハングした 1 プロバイダの
/// コストを抑え、予算内で後続プロバイダへ順番を回す。
/// `AI_HUB_CHAT_PER_CALL_MS` で調整可 (既定 20s)。
function chatPerCallTimeoutMs(): number {
  const raw = Number(Deno.env.get("AI_HUB_CHAT_PER_CALL_MS"));
  return Number.isFinite(raw) && raw > 0 ? raw : 20_000;
}

/// 外部プロバイダ / 内部サブ関数呼び出しに providerFetchTimeoutMs() のタイムアウトを
/// 付与する `fetch` ラッパー。遅延/ハングするプロバイダで edge function が wall-clock 上限を
/// 超えてランタイムに kill され 502 になるのを防ぐ (callProvider と同方針の横展開)。
/// abort 時は AbortError を throw → 各 action / serve トップレベルの try/catch が
/// 捕捉し、502 ではなくハンドル済みエラー応答へ落ちる。
async function fetchWithProviderTimeout(
  input: string | URL,
  init: RequestInit = {},
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    providerFetchTimeoutMs(),
  );
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function sanitizeProviderChoiceLogText(
  value: unknown,
  maxLength = 320,
): string | null {
  const raw = asString(value);
  if (!raw) return null;
  return raw
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[email]")
    .replace(/\b\d{5,}\b/g, "[number]")
    .slice(0, maxLength);
}

function normalizeProviderTier(value: unknown): Tier | undefined {
  const raw = asString(value).toLowerCase();
  if (!raw) return undefined;
  switch (raw) {
    case "free":
    case "low":
      return "free";
    case "cheap":
    case "budget":
    case "medium":
      return "budget";
    case "performance":
    case "high":
      return "performance";
    case "premium":
    case "xhigh":
      return "premium";
    default:
      return undefined;
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value
      .flatMap((item) => asStringArray(item))
      .map((item) => item.trim())
      .filter(Boolean);
  }
  if (typeof value === "string") {
    return value.split(/[,\s]+/).map((item) => item.trim()).filter(Boolean);
  }
  return [];
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

async function loadManualRoutingPreference(
  userId: string | null,
  taskValue: unknown,
): Promise<{ task: string; provider: string; model: string | null } | null> {
  if (!userId) return null;
  const task = normalizeAiRoutingTask(taskValue);
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data, error } = await admin
      .from("ai_task_routing_preferences")
      .select("task, provider, model, is_enabled, updated_at")
      .eq("user_id", userId)
      .eq("task", task)
      .eq("is_enabled", true)
      .maybeSingle();
    if (error) {
      console.warn(`[ai-router] preference lookup skipped: ${error.message}`);
      return null;
    }
    const preference = normalizeAiRouterPreference(data);
    if (!preference || !(preference.provider in PROVIDER_CONFIGS)) {
      return null;
    }
    return {
      task: preference.task,
      provider: preference.provider,
      model: preference.model,
    };
  } catch (error) {
    console.warn(`[ai-router] preference lookup failed: ${String(error)}`);
    return null;
  }
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

type CompanyBuilderWeekBlueprint = {
  label: string;
  goal: string;
  ship: string[];
  exit_signal: string;
};

type CompanyBuilderThirtyDayBlueprint = {
  source_title: string;
  source_url: string;
  north_star: string;
  mrr_target: number;
  trial_signups_target: number;
  paid_users_target: number;
  pricing: {
    free: string;
    pro: string;
    team: string;
    rule: string;
  };
  validation_targets: {
    prototype_testers: number;
    useful_votes: number;
    paid_intent: number;
    interviews: number;
    paying_users: number;
  };
  weeks: CompanyBuilderWeekBlueprint[];
  guardrails: string[];
  build_in_public_metrics: string[];
  launch_post_prompt: string;
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
      "Turn the company brief into a one-screen MVP scope, architecture outline, and a release sequence.",
    manager_key: "max",
    tool_key: "atlas",
    priority: "high",
    stage: "product",
  },
  {
    title: "Cut scope to the ugly paid MVP",
    description:
      "Halve the first scope, remove dashboards and polish, and keep only the painful workflow that can be charged for on day one.",
    manager_key: "max",
    tool_key: "kai",
    priority: "high",
    stage: "mvp",
  },
  {
    title: "Design landing page structure and voice",
    description:
      "Create the initial narrative, hero promise, pricing promise, and page sections that explain the offer clearly before the product is polished.",
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
    title: "Run the first 20 customer conversations",
    description:
      "Interview people with the target pain, capture exact wording, and only promote features that users ask for repeatedly.",
    manager_key: "sam",
    tool_key: "prism",
    priority: "high",
    stage: "validation",
  },
  {
    title: "Model pricing and unit economics",
    description:
      "Estimate pricing, gross margin, CAC sensitivity, and the shortest route to positive economics with free, pro, and team tiers.",
    manager_key: "finn",
    tool_key: "ledger",
    priority: "normal",
    stage: "finance",
  },
  {
    title: "Instrument MRR and conversion signals",
    description:
      "Track signups, activated trials, paid users, MRR, churn risk, and requested features from the first public build.",
    manager_key: "finn",
    tool_key: "pulse",
    priority: "high",
    stage: "metrics",
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
  {
    title: "Publish the build-in-public launch log",
    description:
      "Share the problem, shipped scope, usage numbers, paid conversion, mistakes, and next experiment transparently.",
    manager_key: "ivy",
    tool_key: "piper",
    priority: "normal",
    stage: "growth",
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

function buildThirtyDaySaasBlueprint(
  companyName: string,
  idea: string,
  plan: CompanyBuilderPlan,
): CompanyBuilderThirtyDayBlueprint {
  return {
    source_title: "The 30-Day SaaS Blueprint: From Zero to $1,287 MRR",
    source_url:
      "https://dev.to/thegiansorianodev/i-built-a-saas-in-30-days-heres-exactly-what-happened-48j8",
    north_star:
      `Take ${companyName} from zero to a paid validation loop: 312 signups, 41 paying users, and $1,287 MRR in 30 days by solving one painful workflow before expanding scope.`,
    mrr_target: 1287,
    trial_signups_target: 312,
    paid_users_target: 41,
    pricing: {
      free: "Free tier with a tight usage cap for self-serve discovery.",
      pro: "$19/month for the core workflow and saved history.",
      team: "$49/month for collaboration, integrations, and shared visibility.",
      rule:
        "Show pricing on day one; never wait for polish before testing paid intent.",
    },
    validation_targets: {
      prototype_testers: 14,
      useful_votes: 4,
      paid_intent: 2,
      interviews: 20,
      paying_users: 41,
    },
    weeks: [
      {
        label: "Week 1",
        goal: "Ship the ugly paid MVP",
        ship: [
          "One-page landing page",
          "One painful workflow",
          "Copy/export action",
          "Visible free/pro/team pricing",
        ],
        exit_signal:
          "At least 14 testers, 4 useful votes, and 2 people asking to pay.",
      },
      {
        label: "Week 2",
        goal: "Build only user-requested features",
        ship: [
          "API or integration only if users ask for it",
          "Saved history",
          "Data redaction or privacy controls",
          "Activation tracking",
        ],
        exit_signal:
          "A repeatable onboarding path and a clear list of top requested features.",
      },
      {
        label: "Week 3",
        goal: "Launch in public",
        ship: [
          "Transparent launch post",
          "Metrics snapshot",
          "Trial activation follow-up",
          "Founder-led replies and interviews",
        ],
        exit_signal:
          "Public traffic converts into signups and activated trials.",
      },
      {
        label: "Week 4",
        goal: "Improve retention and economics",
        ship: [
          "MRR dashboard",
          "Churn-risk review",
          "Top support fixes",
          "Pricing and limit adjustments",
        ],
        exit_signal:
          "Paid users understand the value, keep using the workflow, and ask for next capabilities.",
      },
    ],
    guardrails: [
      "Use boring, proven infrastructure before inventing new architecture.",
      "No polished dashboards until users prove the workflow matters.",
      "No microservices, logo redesigns, or broad roadmaps before paid signal.",
      "Every new feature needs a user quote, usage signal, or paid conversion reason.",
      "Prefer a narrow painful problem over a broad attractive category.",
    ],
    build_in_public_metrics: [
      "signups",
      "activated_trials",
      "paid_users",
      "mrr",
      "requested_features",
      "mistakes",
      "next_experiment",
    ],
    launch_post_prompt: [
      `I am building ${companyName} in public for 30 days.`,
      `Problem: ${plan.summary || idea}`,
      `Offer: ${plan.offer}`,
      "Week 1 goal: one ugly paid MVP, visible pricing, and direct tester feedback.",
      "I will share signups, activated trials, paid users, MRR, mistakes, and the next experiment every week.",
    ].join("\n"),
  };
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
    "Apply a 30-day SaaS validation discipline: one painful workflow, boring infrastructure, visible pricing on day one, user-requested features only, and weekly build-in-public metrics.",
    "Penalize ideas that need a broad polished platform before the first paid signal.",
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
  blueprint: CompanyBuilderThirtyDayBlueprint,
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
      title: `${companyName} 30-Day SaaS Blueprint`,
      category: "company_builder",
      tags: ["ai-company-builder", companySlug, "30-day-saas", "mrr"],
      content: [
        `# ${companyName} 30-Day SaaS Blueprint`,
        "",
        `Source: ${blueprint.source_title}`,
        blueprint.source_url,
        "",
        `North star: ${blueprint.north_star}`,
        "",
        "Targets:",
        `- MRR: $${blueprint.mrr_target}`,
        `- Trial signups: ${blueprint.trial_signups_target}`,
        `- Paid users: ${blueprint.paid_users_target}`,
        `- Interviews: ${blueprint.validation_targets.interviews}`,
        "",
        "Pricing:",
        `- Free: ${blueprint.pricing.free}`,
        `- Pro: ${blueprint.pricing.pro}`,
        `- Team: ${blueprint.pricing.team}`,
        `- Rule: ${blueprint.pricing.rule}`,
        "",
        "Weekly loop:",
        ...blueprint.weeks.flatMap((week) => [
          `## ${week.label}: ${week.goal}`,
          ...week.ship.map((item) => `- ${item}`),
          `Exit signal: ${week.exit_signal}`,
          "",
        ]),
        "Guardrails:",
        ...blueprint.guardrails.map((item) => `- ${item}`),
        "",
        "Build in public metrics:",
        ...blueprint.build_in_public_metrics.map((item) => `- ${item}`),
      ].join("\n"),
      metadata: {
        system: "company_builder",
        company_id: companyId,
        note_type: "30_day_saas_blueprint",
        path: `companies/${companySlug}/30-day-saas-blueprint.md`,
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
    runtimeControlResult,
    runtimeMasterResult,
    runtimeEventsResult,
    researchSourcesResult,
    routingProfilesResult,
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
    admin.from("company_agent_runtime_controls").select("*")
      .eq("user_id", userId)
      .eq("company_id", companyId)
      .maybeSingle(),
    admin.from("company_agent_runtime_master_controls").select("*")
      .eq("user_id", userId)
      .maybeSingle(),
    admin.from("company_agent_events").select("*")
      .eq("user_id", userId)
      .eq("company_id", companyId)
      .order("occurred_at", { ascending: false })
      .limit(100),
    admin.from("company_research_sources").select(
      "id, source_url, canonical_url, title, excerpt, status, http_status, content_type, last_error, metadata, fetched_at, created_at, updated_at",
    )
      .eq("user_id", userId)
      .eq("company_id", companyId)
      .order("updated_at", { ascending: false })
      .limit(100),
    admin.from("company_runtime_routing_profiles").select("*")
      .eq("user_id", userId)
      .eq("company_id", companyId)
      .order("updated_at", { ascending: false }),
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
  if (runtimeControlResult.error) {
    throw new Error(runtimeControlResult.error.message);
  }
  if (runtimeMasterResult.error) {
    throw new Error(runtimeMasterResult.error.message);
  }
  if (runtimeEventsResult.error) {
    throw new Error(runtimeEventsResult.error.message);
  }
  if (researchSourcesResult.error) {
    throw new Error(researchSourcesResult.error.message);
  }
  if (routingProfilesResult.error) {
    throw new Error(routingProfilesResult.error.message);
  }

  return {
    company,
    manager_agents: managerAgentsResult.data ?? [],
    tool_agents: toolAgentsResult.data ?? [],
    tasks: tasksResult.data ?? [],
    memories: memoriesResult.data ?? [],
    vault_notes: notesResult.data ?? [],
    workflows: workflowsResult.data ?? [],
    audit_entries: auditsResult.data ?? [],
    runtime_control: runtimeControlResult.data,
    runtime_master_control: runtimeMasterResult.data,
    runtime_events: runtimeEventsResult.data ?? [],
    research_sources: researchSourcesResult.data ?? [],
    routing_profiles: routingProfilesResult.data ?? [],
    a2a_agent_card_url:
      `${SUPABASE_URL}/functions/v1/ai-hub/.well-known/agent-card.json`,
  };
}

type InternalAiHubResponse = {
  ok: boolean;
  status: number;
  payload: Record<string, unknown>;
};

type EdgeRuntimeBridge = {
  waitUntil(promise: Promise<unknown>): void;
};

function isServiceRoleRequest(req: Request): boolean {
  const authorization = req.headers.get("Authorization") ?? "";
  return SERVICE_ROLE_KEY !== "" &&
    authorization === `Bearer ${SERVICE_ROLE_KEY}`;
}

async function invokeAiHubInternal(
  body: Record<string, unknown>,
): Promise<InternalAiHubResponse> {
  const response = await fetch(`${SUPABASE_URL}/functions/v1/ai-hub`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      apikey: SERVICE_ROLE_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const raw = await response.json().catch(() => ({}));
  return {
    ok: response.ok,
    status: response.status,
    payload: asRecord(raw) ?? {},
  };
}

function runInBackground(promise: Promise<unknown>): void {
  const runtime = (globalThis as unknown as { EdgeRuntime?: EdgeRuntimeBridge })
    .EdgeRuntime;
  const observed = promise.catch((error) => {
    console.error("company runtime background task failed", error);
  });
  if (runtime) {
    runtime.waitUntil(observed);
  } else {
    void observed;
  }
}

function scheduleCompanyRuntimeWorker(): void {
  runInBackground(invokeAiHubInternal({ action: "company_builder.worker" }));
}

async function addCompanyEvent(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  eventType: string,
  status: string,
  payload: Record<string, unknown> = {},
) {
  const { error } = await admin.from("company_agent_events").insert({
    user_id: userId,
    company_id: companyId,
    event_type: eventType,
    status,
    payload,
  });
  if (error) throw new Error(error.message);
}

async function ensureCompanyRuntimeControl(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  state: "idle" | "blocked",
  lastError: string | null = null,
) {
  const { error: masterError } = await admin
    .from("company_agent_runtime_master_controls")
    .upsert({ user_id: userId }, { onConflict: "user_id" });
  if (masterError) throw new Error(masterError.message);

  const { data, error } = await admin.from("company_agent_runtime_controls")
    .upsert({
      user_id: userId,
      company_id: companyId,
      state,
      last_error: lastError,
    }, { onConflict: "user_id,company_id" })
    .select("*")
    .single();
  if (error) throw new Error(error.message);
  return data as Record<string, unknown>;
}

async function enqueueCompanyRuntime(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  reason: string,
) {
  const { data, error } = await admin.rpc("enqueue_company_agent_runtime", {
    p_user_id: userId,
    p_company_id: companyId,
    p_reason: reason,
  });
  if (error) throw new Error(error.message);
  return data;
}

async function archiveCompanyRuntimeMessage(
  admin: SupabaseClient,
  messageId: number,
) {
  const { error } = await admin.rpc("archive_company_agent_runtime", {
    p_message_id: messageId,
  });
  if (error) throw new Error(error.message);
}

async function getOwnedCompany(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("id", companyId)
    .eq("source", "company_builder_company")
    .filter("metadata->>user_id", "eq", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data as Record<string, unknown> | null;
}

async function embedCompanyResearchDocuments(
  texts: string[],
  apiKey: string,
): Promise<Array<number[] | null>> {
  if (!apiKey || texts.length === 0) return texts.map(() => null);
  const embeddings: Array<number[] | null> = [];
  for (let offset = 0; offset < texts.length; offset += 20) {
    const batch = texts.slice(offset, offset + 20);
    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          requests: batch.map((text) => ({
            model: "models/gemini-embedding-001",
            content: { parts: [{ text: text.slice(0, 3500) }] },
            taskType: "RETRIEVAL_DOCUMENT",
            outputDimensionality: 768,
          })),
        }),
        signal: AbortSignal.timeout(15_000),
      },
    );
    if (!response.ok) {
      throw new Error(`Gemini document embedding returned ${response.status}`);
    }
    const payload = await response.json() as {
      embeddings?: Array<{ values?: number[] }>;
    };
    const values = payload.embeddings ?? [];
    if (values.length !== batch.length) {
      throw new Error("Gemini document embedding count mismatch");
    }
    embeddings.push(
      ...values.map((item) =>
        Array.isArray(item.values) && item.values.length === 768
          ? item.values
          : null
      ),
    );
  }
  return embeddings;
}

const COMPANY_RESEARCH_EMBEDDING_CHUNK_LIMIT = 60;

async function ingestCompanyResearchSource(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  rawUrl: unknown,
): Promise<Record<string, unknown>> {
  if (!await getOwnedCompany(admin, userId, companyId)) {
    throw new Error("Company not found");
  }
  const canonicalUrl = canonicalResearchUrl(rawUrl);
  const sourceUrl = String(rawUrl).trim();
  const { data: source, error: sourceError } = await admin
    .from("company_research_sources")
    .upsert({
      user_id: userId,
      company_id: companyId,
      source_url: sourceUrl,
      canonical_url: canonicalUrl,
      status: "processing",
      last_error: null,
      metadata: { ingestion: "company_builder" },
    }, { onConflict: "user_id,company_id,canonical_url" })
    .select("*")
    .single();
  if (sourceError) throw new Error(sourceError.message);
  const sourceId = asString(source.id);

  try {
    const document = await fetchPublicResearchDocument(sourceUrl);
    const chunks = chunkResearchMarkdown(document.markdown);
    if (chunks.length === 0) {
      throw new Error("Source produced no research chunks");
    }
    const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
    let embeddings = chunks.map(() => null as number[] | null);
    let embeddingStatus = geminiKey ? "failed" : "unavailable";
    if (geminiKey) {
      try {
        const generated = await embedCompanyResearchDocuments(
          chunks.slice(0, COMPANY_RESEARCH_EMBEDDING_CHUNK_LIMIT).map((chunk) =>
            chunk.content
          ),
          geminiKey,
        );
        embeddings = chunks.map((_, index) => generated[index] ?? null);
        embeddingStatus = generated.some(Boolean)
          ? chunks.length > COMPANY_RESEARCH_EMBEDDING_CHUNK_LIMIT
            ? "partial"
            : "ready"
          : "failed";
      } catch (error) {
        console.warn("company research embedding fallback", error);
      }
    }

    const { error: deleteError } = await admin.from("company_research_chunks")
      .delete().eq("source_id", sourceId).eq("user_id", userId)
      .eq("company_id", companyId);
    if (deleteError) throw new Error(deleteError.message);
    const chunkRows = chunks.map((chunk, index) => ({
      source_id: sourceId,
      user_id: userId,
      company_id: companyId,
      chunk_index: chunk.chunkIndex,
      heading: chunk.heading,
      location: chunk.location,
      content: chunk.content,
      embedding: embeddings[index],
      metadata: { source_title: document.title },
    }));
    const { error: chunkError } = await admin.from("company_research_chunks")
      .insert(chunkRows);
    if (chunkError) throw new Error(chunkError.message);

    const { data: ready, error: updateError } = await admin
      .from("company_research_sources")
      .update({
        source_url: document.sourceUrl,
        title: document.title,
        content_markdown: document.markdown,
        excerpt: document.excerpt,
        content_hash: await sha256Hex(document.markdown),
        status: "ready",
        http_status: document.httpStatus,
        content_type: document.contentType,
        last_error: null,
        fetched_at: new Date().toISOString(),
        metadata: {
          ingestion: "company_builder",
          final_canonical_url: document.canonicalUrl,
          chunk_count: chunks.length,
          embedding_status: embeddingStatus,
        },
      })
      .eq("id", sourceId).eq("user_id", userId).eq("company_id", companyId)
      .select("*")
      .single();
    if (updateError) throw new Error(updateError.message);
    await addCompanyEvent(
      admin,
      userId,
      companyId,
      "research_source_ready",
      "ready",
      {
        source_id: sourceId,
        chunk_count: chunks.length,
        embedding_status: embeddingStatus,
      },
    );
    return ready as Record<string, unknown>;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await admin.from("company_research_sources").update({
      status: "failed",
      last_error: message.slice(0, 1000),
      metadata: {
        ingestion: "company_builder",
        fallback: "source_failure_recorded",
      },
    }).eq("id", sourceId).eq("user_id", userId).eq("company_id", companyId);
    await addCompanyEvent(
      admin,
      userId,
      companyId,
      "research_source_failed",
      "failed",
      { source_id: sourceId, error: message.slice(0, 500) },
    );
    throw error;
  }
}

async function searchCompanyResearch(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  query: string,
): Promise<ResearchCitation[]> {
  const { data: sources, error: sourcesError } = await admin
    .from("company_research_sources")
    .select("id, source_url, title, fetched_at")
    .eq("user_id", userId).eq("company_id", companyId).eq("status", "ready")
    .order("updated_at", { ascending: false }).limit(100);
  if (sourcesError) throw new Error(sourcesError.message);
  const sourceMap = new Map(
    ((sources ?? []) as Record<string, unknown>[]).map((
      source,
    ) => [asString(source.id), source]),
  );
  if (sourceMap.size === 0) return [];

  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  let queryEmbedding: number[] | null = null;
  if (geminiKey) {
    try {
      queryEmbedding = await embedTextWithGemini(query, geminiKey);
    } catch (error) {
      console.warn("company research query embedding fallback", error);
    }
  }

  const merged = new Map<string, Record<string, unknown>>();
  const { data: hybridRows, error: hybridError } = await admin.rpc(
    "match_company_research_chunks",
    {
      p_user_id: userId,
      p_company_id: companyId,
      p_query_text: query,
      p_query_embedding: queryEmbedding,
      p_match_count: 12,
      p_match_threshold: 0.05,
    },
  );
  if (hybridError) {
    console.warn("company research database search fallback", hybridError);
  } else {
    for (const row of (hybridRows ?? []) as Record<string, unknown>[]) {
      merged.set(asString(row.chunk_id), row);
    }
  }

  const { data: chunks, error: chunksError } = await admin
    .from("company_research_chunks")
    .select("id, source_id, heading, location, content, updated_at")
    .eq("user_id", userId).eq("company_id", companyId)
    .in("source_id", [...sourceMap.keys()]).limit(300);
  if (chunksError) throw new Error(chunksError.message);
  const documents = ((chunks ?? []) as Record<string, unknown>[]).map(
    (chunk) => {
      const source = sourceMap.get(asString(chunk.source_id)) ?? {};
      return {
        file_path: asString(chunk.id),
        title: asString(source.title),
        content: asString(chunk.content),
        snippet: asString(chunk.content).slice(0, 700),
        updated_at: asString(chunk.updated_at),
        metadata: { chunk, source },
      };
    },
  );
  const lexicalRows = rankBm25(query, documents, 12);
  const maxLexical = Math.max(1, ...lexicalRows.map((row) => row.score));
  for (const lexical of lexicalRows) {
    const metadata = asRecord(lexical.metadata) ?? {};
    const chunk = asRecord(metadata.chunk) ?? {};
    const source = asRecord(metadata.source) ?? {};
    const chunkId = asString(chunk.id);
    const candidate: Record<string, unknown> = {
      chunk_id: chunkId,
      source_id: asString(chunk.source_id),
      source_url: asString(source.source_url),
      title: asString(source.title),
      heading: asString(chunk.heading),
      location: asString(chunk.location),
      content: asString(chunk.content),
      fetched_at: asString(source.fetched_at),
      score: lexical.score / maxLexical,
    };
    const existing = merged.get(chunkId);
    if (!existing || Number(existing.score ?? 0) < Number(candidate.score)) {
      merged.set(chunkId, candidate);
    }
  }

  const ranked = [...merged.values()].sort((left, right) =>
    Number(right.score ?? 0) - Number(left.score ?? 0)
  );
  return normalizeResearchCitations(ranked, 6);
}

async function persistCompanyRoutingOutcome(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  profile: Record<string, unknown>,
  success: boolean,
  provider: string,
  model: string,
) {
  const timestampField = success ? "last_success_at" : "last_failure_at";
  const { data, error } = await admin.from("company_runtime_routing_profiles")
    .upsert({
      user_id: userId,
      company_id: companyId,
      ...profile,
      last_provider: provider || null,
      last_model: model || null,
      [timestampField]: new Date().toISOString(),
    }, { onConflict: "user_id,company_id,routing_key" })
    .select("*")
    .single();
  if (error) throw new Error(error.message);
  return data as Record<string, unknown>;
}

async function consolidateCompanyTaskResult(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
  task: Record<string, unknown>,
  resultText: string,
  citations: ResearchCitation[],
  routingProfile: Record<string, unknown>,
) {
  const metadata = asRecord(task.metadata) ?? {};
  const taskId = asString(task.id);
  const agentId = asString(task.assignee_agent_id);
  const { error: memoryError } = await admin.from("agent_memories").insert({
    user_id: userId,
    agent_id: agentId,
    memory_layer: "knowledge",
    content: resultText,
    source: "company_builder_runtime",
    metadata: {
      system: "company_builder",
      company_id: companyId,
      task_id: taskId,
      stage: metadata.stage,
      citations,
      routing: routingProfile,
    },
  });
  if (memoryError) throw new Error(memoryError.message);
  await addItem(admin, "wiki_page", userId, {
    title: `${asString(task.title) || "Company task"} Result`,
    content: resultText,
    category: "company_builder",
    tags: [
      "ai-company-builder",
      "runtime-result",
      asString(metadata.stage) || "general",
    ],
    system: "company_builder",
    company_id: companyId,
    task_id: taskId,
    note_type: "runtime_result",
    citations,
    routing: routingProfile,
  });
}

async function runCompanyRuntimeWorker(
  admin: SupabaseClient,
): Promise<Record<string, unknown>> {
  const { data: rawMessages, error: readError } = await admin.rpc(
    "read_company_agent_runtime",
    { p_visibility_timeout: 120, p_limit: 1 },
  );
  if (readError) throw new Error(readError.message);

  const messages = parseCompanyRuntimeQueueMessages(rawMessages);
  if (messages.length === 0) {
    return { status: "idle", processed: 0 };
  }

  const message = messages[0];
  const { data: rawClaim, error: claimError } = await admin.rpc(
    "claim_company_agent_task",
    {
      p_user_id: message.userId,
      p_company_id: message.companyId,
    },
  );
  if (claimError) throw new Error(claimError.message);

  const claim = asRecord(rawClaim) ?? {};
  const task = asRecord(claim.task);
  if (!task) {
    await archiveCompanyRuntimeMessage(admin, message.msgId);
    return {
      status: asString(claim.state) || "inactive",
      processed: 0,
      company_id: message.companyId,
    };
  }

  const taskId = asString(task.id);
  const supervisorId = asString(task.supervisor_agent_id);
  const assigneeId = asString(task.assignee_agent_id);
  let success = false;
  let routingSuccess = false;
  let resultText = "";
  let errorMessage: string | null = null;
  let provider = "";
  let model = "";
  let tier = "";
  let prompt = "";
  let fallbackReason: string | null = null;
  let citations: ResearchCitation[] = [];
  let currentRoutingProfile: Record<string, unknown> | null = null;
  let routingDecision = selectCompanyRuntimeRouting(task, null);
  const startedAt = performance.now();

  try {
    const [companyResult, agentsResult, routingResult] = await Promise.all([
      admin.from("hub_data").select("id, metadata, created_at")
        .eq("id", message.companyId)
        .eq("source", "company_builder_company")
        .filter("metadata->>user_id", "eq", message.userId)
        .single(),
      admin.from("agents").select("*")
        .eq("user_id", message.userId)
        .in("id", [supervisorId, assigneeId]),
      admin.from("company_runtime_routing_profiles").select("*")
        .eq("user_id", message.userId)
        .eq("company_id", message.companyId)
        .eq("routing_key", routingDecision.routingKey)
        .maybeSingle(),
    ]);
    if (companyResult.error) throw new Error(companyResult.error.message);
    if (agentsResult.error) throw new Error(agentsResult.error.message);
    if (routingResult.error) throw new Error(routingResult.error.message);

    const agents = (agentsResult.data ?? []) as Record<string, unknown>[];
    const manager = agents.find((agent) => agent.id === supervisorId) ?? null;
    const tool = agents.find((agent) => agent.id === assigneeId) ?? null;
    currentRoutingProfile = routingResult.data as
      | Record<string, unknown>
      | null;
    routingDecision = selectCompanyRuntimeRouting(task, currentRoutingProfile);
    citations = await searchCompanyResearch(
      admin,
      message.userId,
      message.companyId,
      [asString(task.title), asString(task.description)].filter(Boolean).join(
        "\n",
      ),
    );
    prompt = buildCompanyRuntimePrompt(
      companyResult.data as Record<string, unknown>,
      task,
      manager,
      tool,
      buildResearchCitationContext(citations),
    );

    const providerResponse = await invokeAiHubInternal({
      action: "provider.chat_auto",
      internal_user_id: message.userId,
      message: prompt,
      tier: routingDecision.tier,
      max_tokens: 1800,
      session_id: message.companyId,
      trace_id: crypto.randomUUID(),
      routing_use_case: routingDecision.routingKey,
      provider_choice_reason: routingDecision.reason,
    });
    resultText = asString(providerResponse.payload.text);
    success = providerResponse.ok &&
      providerResponse.payload.success === true && resultText !== "";
    routingSuccess = success;
    provider = asString(providerResponse.payload.provider);
    model = asString(providerResponse.payload.model);
    tier = asString(providerResponse.payload.tier);
    if (success) {
      resultText = ensureCitationFooter(resultText, citations);
    } else {
      errorMessage = asString(
        providerResponse.payload.message ?? providerResponse.payload.status,
      ) || `provider.chat_auto returned ${providerResponse.status}`;
      if (citations.length > 0) {
        fallbackReason = errorMessage;
        resultText = buildExtractiveResearchFallback(
          asString(task.title),
          citations,
        );
        success = true;
        provider = "extractive";
        model = "deterministic-citation-fallback";
        tier = routingDecision.tier;
        errorMessage = null;
      }
    }
  } catch (error) {
    errorMessage = error instanceof Error ? error.message : String(error);
  }

  const durationMs = Math.max(0, Math.round(performance.now() - startedAt));
  const inputChars = prompt.length;
  const outputChars = resultText.length;
  const estimatedCost = success
    ? calculateApiCost(
      model || provider,
      estimateTokensFromChars(inputChars),
      estimateTokensFromChars(outputChars),
    )
    : 0;
  const nextRoutingProfile = nextCompanyRuntimeRoutingProfile(
    currentRoutingProfile,
    routingDecision,
    routingSuccess,
    tier,
  );
  const { data: rawFinish, error: finishError } = await admin.rpc(
    "finish_company_agent_task",
    {
      p_user_id: message.userId,
      p_company_id: message.companyId,
      p_task_id: taskId,
      p_success: success,
      p_result: success
        ? {
          text: resultText,
          provider,
          model,
          tier,
          citations,
          routing: nextRoutingProfile,
          routing_provider_success: routingSuccess,
          fallback_reason: fallbackReason,
        }
        : {},
      p_error: errorMessage,
      p_metrics: {
        provider,
        model,
        tier,
        input_chars: inputChars,
        output_chars: outputChars,
        estimated_cost_usd: estimatedCost,
        duration_ms: durationMs,
        routing_provider_success: routingSuccess,
      },
    },
  );
  if (finishError) throw new Error(finishError.message);
  const finish = asRecord(rawFinish) ?? {};
  const finalTaskStatus = asString(finish.task_status);
  const taskCancelled = finalTaskStatus === "cancelled";
  const taskTimedOut = finish.timed_out === true;

  let persistedRoutingProfile = nextRoutingProfile;
  if (!taskCancelled && !taskTimedOut) {
    try {
      persistedRoutingProfile = await persistCompanyRoutingOutcome(
        admin,
        message.userId,
        message.companyId,
        nextRoutingProfile,
        routingSuccess,
        provider,
        model,
      );
      await addCompanyEvent(
        admin,
        message.userId,
        message.companyId,
        "routing_outcome_recorded",
        routingSuccess ? "completed" : "failed",
        {
          task_id: taskId,
          requested_tier: routingDecision.tier,
          used_tier: tier,
          reason: routingDecision.reason,
          decision: persistedRoutingProfile.last_decision,
          next_tier: persistedRoutingProfile.current_tier,
        },
      );
    } catch (error) {
      console.error("company routing profile persistence failed", error);
    }
  }
  if (success && finalTaskStatus === "completed") {
    try {
      await consolidateCompanyTaskResult(
        admin,
        message.userId,
        message.companyId,
        task,
        resultText,
        citations,
        persistedRoutingProfile,
      );
    } catch (error) {
      console.error("company result consolidation failed", error);
      await addCompanyEvent(
        admin,
        message.userId,
        message.companyId,
        "memory_consolidation_failed",
        "failed",
        { task_id: taskId, error: String(error).slice(0, 500) },
      ).catch(() => undefined);
    }
  }

  await archiveCompanyRuntimeMessage(admin, message.msgId);
  const shouldContinue = finish.continue === true;
  if (shouldContinue) {
    await enqueueCompanyRuntime(
      admin,
      message.userId,
      message.companyId,
      success ? "next_task" : "retry_task",
    );
    scheduleCompanyRuntimeWorker();
  }

  return {
    status: asString(finish.state) || "unknown",
    processed: 1,
    company_id: message.companyId,
    task_id: taskId,
    task_status: asString(finish.task_status),
    timed_out: taskTimedOut,
    continue: shouldContinue,
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

function companyA2ARelativePath(req: Request): string | null {
  const pathname = new URL(req.url).pathname;
  const match = pathname.match(/\/a2a(?=\/|$)/);
  if (!match || match.index === undefined) return null;
  return pathname.slice(match.index + match[0].length) || "/";
}

async function activateCompanyA2ATaskRuntime(
  admin: SupabaseClient,
  userId: string,
  companyId: string,
) {
  const { error: controlError } = await admin.rpc(
    "set_company_agent_runtime_state",
    {
      p_user_id: userId,
      p_company_id: companyId,
      p_command: "start",
    },
  );
  if (controlError) throw new Error(controlError.message);
  await enqueueCompanyRuntime(admin, userId, companyId, "a2a_message");
  scheduleCompanyRuntimeWorker();
}

async function createCompanyA2ATask(
  admin: SupabaseClient,
  userId: string,
  value: unknown,
): Promise<Record<string, unknown>> {
  const input = parseA2ASendMessage(value);
  const company = await getOwnedCompany(admin, userId, input.companyId);
  if (!company) throw new Error("TaskNotFoundError: company not found");
  const companyMetadata = asRecord(company.metadata) ?? {};
  if (companyMetadata.passed !== true) {
    throw new Error("UnsupportedOperationError: company gate is not approved");
  }

  const { data: existing, error: existingError } = await admin
    .from("agent_tasks").select("*")
    .eq("user_id", userId)
    .eq("task_type", "company_builder_a2a")
    .filter("metadata->>company_id", "eq", input.companyId)
    .filter("metadata->>a2a_message_id", "eq", input.messageId)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);
  if (existing) {
    if (asString(existing.status) === "queued") {
      await activateCompanyA2ATaskRuntime(admin, userId, input.companyId);
    }
    return existing as Record<string, unknown>;
  }

  const route = input.skillId === "cited-research"
    ? { managerKey: "chief", toolKey: "nova", stage: "research" }
    : input.skillId === "launch-execution"
    ? { managerKey: "ivy", toolKey: "piper", stage: "growth" }
    : { managerKey: "chief", toolKey: "sage", stage: "operations" };
  const [managerResult, toolResult] = await Promise.all([
    admin.from("agents").select("id").eq("user_id", userId)
      .filter("metadata->>company_id", "eq", input.companyId)
      .filter("metadata->>manager_key", "eq", route.managerKey)
      .maybeSingle(),
    admin.from("agents").select("id").eq("user_id", userId)
      .filter("metadata->>system", "eq", "company_builder")
      .filter("metadata->>shared_pool", "eq", "true")
      .filter("metadata->>tool_key", "eq", route.toolKey)
      .maybeSingle(),
  ]);
  if (managerResult.error) throw new Error(managerResult.error.message);
  if (toolResult.error) throw new Error(toolResult.error.message);
  if (!managerResult.data || !toolResult.data) {
    throw new Error(
      "UnsupportedOperationError: company agents are unavailable",
    );
  }

  const { data: task, error: taskError } = await admin.from("agent_tasks")
    .insert({
      user_id: userId,
      supervisor_agent_id: managerResult.data.id,
      assignee_agent_id: toolResult.data.id,
      title: `${input.skillId}: ${
        input.text.replace(/\s+/g, " ").slice(0, 120)
      }`,
      description: input.text,
      status: "queued",
      priority: "normal",
      task_type: "company_builder_a2a",
      source: "company_builder_bootstrap",
      metadata: {
        system: "company_builder",
        company_id: input.companyId,
        company_name: asString(companyMetadata.company_name),
        manager_key: route.managerKey,
        tool_key: route.toolKey,
        stage: route.stage,
        a2a_message_id: input.messageId,
        a2a_context_id: input.contextId,
        a2a_skill_id: input.skillId,
        a2a_message: input.rawMessage,
      },
    }).select("*").single();
  if (taskError) {
    if (taskError.code === "23505") {
      const { data: duplicate, error: duplicateError } = await admin
        .from("agent_tasks").select("*")
        .eq("user_id", userId)
        .eq("task_type", "company_builder_a2a")
        .filter("metadata->>company_id", "eq", input.companyId)
        .filter("metadata->>a2a_message_id", "eq", input.messageId)
        .single();
      if (duplicateError) throw new Error(duplicateError.message);
      if (asString(duplicate.status) === "queued") {
        await activateCompanyA2ATaskRuntime(admin, userId, input.companyId);
      }
      return duplicate as Record<string, unknown>;
    }
    throw new Error(taskError.message);
  }

  await activateCompanyA2ATaskRuntime(admin, userId, input.companyId);
  await addCompanyEvent(
    admin,
    userId,
    input.companyId,
    "a2a_task_submitted",
    "queued",
    { task_id: task.id, message_id: input.messageId, skill_id: input.skillId },
  );
  return task as Record<string, unknown>;
}

async function handleCompanyA2ARequest(
  req: Request,
  body: Record<string, unknown>,
  admin: SupabaseClient,
  userId: string,
): Promise<Response> {
  try {
    assertA2AVersion(req);
  } catch (error) {
    return a2aJson({
      error: { code: "VersionNotSupportedError", message: String(error) },
    }, 400);
  }
  const relative = companyA2ARelativePath(req) ?? "/";

  try {
    if (req.method === "POST" && relative === "/message:send") {
      const task = await createCompanyA2ATask(admin, userId, body);
      return a2aJson({ task: companyTaskToA2A(task) }, 202);
    }

    if (req.method === "GET" && relative === "/tasks") {
      const url = new URL(req.url);
      const requestedPageSize = Number(url.searchParams.get("pageSize"));
      const pageSize = Math.max(
        1,
        Math.min(
          Number.isFinite(requestedPageSize) && requestedPageSize > 0
            ? Math.trunc(requestedPageSize)
            : 50,
          100,
        ),
      );
      const includeArtifacts =
        url.searchParams.get("includeArtifacts") === "true";
      const cursor = decodeA2APageToken(url.searchParams.get("pageToken"));
      if (url.searchParams.has("pageToken") && !cursor) {
        return a2aJson({
          error: { code: "InvalidArgumentError", message: "Invalid pageToken" },
        }, 400);
      }
      let query = admin.from("agent_tasks").select("*")
        .eq("user_id", userId).eq("task_type", "company_builder_a2a")
        .order("updated_at", { ascending: false })
        .order("id", { ascending: false }).limit(pageSize + 1);
      const contextId = asString(url.searchParams.get("contextId"));
      if (contextId.length > 200) {
        return a2aJson({
          error: {
            code: "InvalidArgumentError",
            message: "contextId exceeds 200 characters",
          },
        }, 400);
      }
      if (contextId) {
        query = query.filter("metadata->>a2a_context_id", "eq", contextId);
      }
      if (cursor) {
        query = query.or(
          `updated_at.lt.${cursor.updatedAt},and(updated_at.eq.${cursor.updatedAt},id.lt.${cursor.id})`,
        );
      }
      const { data, error } = await query;
      if (error) throw new Error(error.message);
      const rows = (data ?? []) as Record<string, unknown>[];
      const hasNext = rows.length > pageSize;
      const page = rows.slice(0, pageSize);
      return a2aJson({
        tasks: page.map((task) => companyTaskToA2A(task, includeArtifacts)),
        nextPageToken: hasNext && page.length > 0
          ? encodeA2APageToken(page[page.length - 1])
          : "",
      });
    }

    const cancelMatch = relative.match(/^\/tasks\/([0-9a-f-]{36}):cancel$/i);
    if (req.method === "POST" && cancelMatch) {
      const { data: current, error: currentError } = await admin.from(
        "agent_tasks",
      )
        .select("*").eq("id", cancelMatch[1]).eq("user_id", userId)
        .eq("task_type", "company_builder_a2a").maybeSingle();
      if (currentError) throw new Error(currentError.message);
      if (!current) {
        return a2aJson({
          error: { code: "TaskNotFoundError", message: "Task not found" },
        }, 404);
      }
      if (
        ["completed", "failed", "cancelled"].includes(asString(current.status))
      ) {
        return a2aJson({
          error: {
            code: "TaskNotCancelableError",
            message: "Task is already terminal",
          },
        }, 409);
      }
      const { data: cancelled, error: cancelError } = await admin.from(
        "agent_tasks",
      )
        .update({ status: "cancelled", last_error: "Cancelled through A2A" })
        .eq("id", cancelMatch[1]).eq("user_id", userId)
        .eq("task_type", "company_builder_a2a").select("*").single();
      if (cancelError) throw new Error(cancelError.message);
      const metadata = asRecord(cancelled.metadata) ?? {};
      await addCompanyEvent(
        admin,
        userId,
        asString(metadata.company_id),
        "a2a_task_cancelled",
        "cancelled",
        { task_id: cancelled.id },
      );
      return a2aJson({ task: companyTaskToA2A(cancelled) });
    }

    const getMatch = relative.match(/^\/tasks\/([0-9a-f-]{36})$/i);
    if (req.method === "GET" && getMatch) {
      const { data, error } = await admin.from("agent_tasks").select("*")
        .eq("id", getMatch[1]).eq("user_id", userId)
        .eq("task_type", "company_builder_a2a").maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) {
        return a2aJson({
          error: { code: "TaskNotFoundError", message: "Task not found" },
        }, 404);
      }
      return a2aJson({
        task: companyTaskToA2A(data as Record<string, unknown>),
      });
    }

    return a2aJson({
      error: {
        code: "UnsupportedOperationError",
        message: "A2A operation is not supported",
      },
    }, 404);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const code = message.split(":", 1)[0];
    const status = code === "TaskNotFoundError"
      ? 404
      : code === "UnsupportedOperationError"
      ? 409
      : 400;
    return a2aJson({ error: { code, message } }, status);
  }
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

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type AgentToolGateResult = {
  decision: AgentToolPolicyDecision;
  actorRole: string | null;
  actorAgentId: string | null;
  requestedScopes: string[];
  allowedScopes: string[] | null;
  approval: AgentToolApproval | null;
  sideEffects: string | null;
  auditLogged: boolean;
};

function nullableUuid(value: unknown): string | null {
  const candidate = asString(value);
  return UUID_PATTERN.test(candidate) ? candidate : null;
}

function parseAgentToolApproval(
  body: Record<string, unknown>,
): AgentToolApproval | null {
  const approval = asRecord(body.approval);
  const decision = asString(
    approval?.decision ?? body.approval_decision ?? body.approvalDecision,
  ).toLowerCase();
  if (!["approved", "pending", "rejected"].includes(decision)) return null;
  return {
    decision: decision as AgentToolApproval["decision"],
    approvedBy: asString(
      approval?.approved_by ?? approval?.approvedBy ?? body.approved_by ??
        body.approvedBy,
    ) || null,
    approvedAt: asString(
      approval?.approved_at ?? approval?.approvedAt ?? body.approved_at ??
        body.approvedAt,
    ) || null,
  };
}

function normalizeActorRole(value: unknown): string | null {
  const raw = asString(value).toLowerCase();
  if (!raw) return null;
  if (raw === "ceo" || raw.includes("chief executive")) return "ceo";
  if (raw === "cfo" || raw.includes("financial")) return "cfo";
  if (raw === "cmo" || raw.includes("marketing")) return "cmo";
  if (raw === "cho" || raw.includes("health")) return "cho";
  if (raw === "chro" || raw.includes("people") || raw.includes("hr")) {
    return "chro";
  }
  if (raw.includes("legal")) return "legal";
  return raw;
}

async function loadAgentRole(
  admin: SupabaseClient,
  userId: string,
  actorAgentId: string | null,
): Promise<string | null> {
  if (!actorAgentId) return null;
  const { data, error } = await admin
    .from("agents")
    .select("slug,role_title,department")
    .eq("id", actorAgentId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) return null;
  return normalizeActorRole(data.slug) ?? normalizeActorRole(data.role_title) ??
    normalizeActorRole(data.department);
}

function publicPolicyDecision(decision: AgentToolPolicyDecision) {
  return {
    allowed: decision.allowed,
    requires_approval: decision.requiresApproval,
    missing_scopes: decision.missingScopes,
    high_risk_scopes: decision.highRiskScopes,
    blocked_reason: decision.blockedReason,
  };
}

async function logAgentToolPolicyDecision(
  admin: SupabaseClient,
  userId: string,
  input: AgentToolGateResult,
): Promise<boolean> {
  const payload = {
    ...input.decision.auditPayload,
    side_effects: input.sideEffects,
    policy_source: "ai-hub:agent.tool_policy",
  };
  const { error } = await admin.from("agent_tool_execution_logs").insert({
    user_id: userId,
    actor_agent_id: input.actorAgentId,
    actor_role: input.actorRole,
    tool_name: String(input.decision.auditPayload.tool_name ?? "unknown"),
    allowed: input.decision.allowed,
    blocked_reason: input.decision.blockedReason,
    requested_scopes: input.requestedScopes,
    allowed_scopes: input.allowedScopes,
    high_risk_scopes: input.decision.highRiskScopes,
    requires_approval: input.decision.requiresApproval,
    approval_decision: input.approval?.decision ?? null,
    approved_by: input.approval?.approvedBy ?? null,
    approved_at: input.approval?.approvedAt ?? null,
    side_effects: input.sideEffects,
    payload,
  });
  if (!error) return true;
  console.warn("agent.tool_policy audit insert failed", error.message);
  return false;
}

async function evaluateAgentToolGate(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<AgentToolGateResult> {
  const actorAgentId = nullableUuid(
    body.actor_agent_id ?? body.actorAgentId ?? body.agent_id ?? body.agentId,
  );
  const actorRole = normalizeActorRole(body.actor_role ?? body.actorRole) ??
    await loadAgentRole(admin, userId, actorAgentId);
  const requestedScopes = asStringArray(
    body.requested_scopes ?? body.requestedScopes ?? body.scopes,
  );
  const allowedScopesRaw = body.allowed_scopes ?? body.allowedScopes;
  const allowedScopes =
    allowedScopesRaw === undefined || allowedScopesRaw === null
      ? null
      : asStringArray(allowedScopesRaw);
  const approval = parseAgentToolApproval(body);
  const sideEffects = asString(body.side_effects ?? body.sideEffects) || null;
  const toolName =
    asString(body.tool_name ?? body.toolName ?? body.target_tool) ||
    "agent.run";
  const decision = evaluateAgentToolPolicy({
    actorRole,
    toolName,
    requestedScopes,
    allowedScopes,
    approval,
  });
  const result: AgentToolGateResult = {
    decision,
    actorRole,
    actorAgentId,
    requestedScopes,
    allowedScopes,
    approval,
    sideEffects,
    auditLogged: false,
  };
  result.auditLogged = await logAgentToolPolicyDecision(admin, userId, result);
  return result;
}

const AI_UNIVERSITY_RLHF_SOURCE = "ai_university_rlhf_signal";
const DAILY_JUDGMENT_QUALITY_SOURCE = "daily_judgment_quality_evaluation";

function rlhfLabel(rating: number, helpful: boolean): string {
  if (helpful || rating >= 4) return "positive";
  if (!helpful || rating <= 2) return "negative";
  return "neutral";
}

function rlhfQualityScore(
  positiveSignals: number,
  neutralSignals: number,
  totalSignals: number,
): number {
  if (totalSignals <= 0) return 0;
  return Math.round(
    ((positiveSignals + neutralSignals * 0.5) / totalSignals) * 100,
  );
}

function rlhfNextAction(totalSignals: number, qualityScore: number): string {
  if (totalSignals < 20) {
    return "チューニング前に、まず選好シグナルを20件以上集めましょう。";
  }
  if (qualityScore < 70) {
    return "低評価のレッスンを見直し、弱い解説を再生成しましょう。";
  }
  return "データセットは微調整・評価バッチに利用できる状態です。";
}

function buildRlhfSnapshot(
  rows: Array<{ metadata?: Record<string, unknown> | null }>,
) {
  let positiveSignals = 0;
  let neutralSignals = 0;
  let negativeSignals = 0;
  let ratingSum = 0;
  const providerSignalCounts: Record<string, number> = {};

  for (const row of rows) {
    const metadata = row.metadata ?? {};
    const providerId = asString(metadata.provider_id);
    const rating = Math.min(
      Math.max(Math.round(asNumber(metadata.rating, 3)), 1),
      5,
    );
    const helpful = metadata.helpful === true;
    const label = asString(metadata.quality_label) ||
      rlhfLabel(rating, helpful);

    ratingSum += rating;
    if (providerId) {
      providerSignalCounts[providerId] =
        (providerSignalCounts[providerId] ?? 0) + 1;
    }
    if (label === "positive") positiveSignals += 1;
    else if (label === "negative") negativeSignals += 1;
    else neutralSignals += 1;
  }

  const totalSignals = rows.length;
  const averageRating = totalSignals === 0
    ? 0
    : Math.round((ratingSum / totalSignals) * 10) / 10;
  const qualityScore = rlhfQualityScore(
    positiveSignals,
    neutralSignals,
    totalSignals,
  );

  return {
    total_signals: totalSignals,
    positive_signals: positiveSignals,
    neutral_signals: neutralSignals,
    negative_signals: negativeSignals,
    average_rating: averageRating,
    quality_score: qualityScore,
    ready_for_fine_tune: totalSignals >= 20 && qualityScore >= 70,
    provider_signal_counts: providerSignalCounts,
    next_action: rlhfNextAction(totalSignals, qualityScore),
  };
}

function buildUserDataFineTuneReadiness(
  rlhfRows: Array<{ metadata?: Record<string, unknown> | null }>,
  judgmentRows: Array<{ metadata?: Record<string, unknown> | null }>,
) {
  let positiveSignals = 0;
  let neutralSignals = 0;
  let negativeSignals = 0;
  let ratingSum = 0;
  let judgmentScoreSum = 0;
  let approvedJudgments = 0;
  let reviewJudgments = 0;
  let commentRows = 0;

  for (const row of rlhfRows) {
    const metadata = row.metadata ?? {};
    const rating = Math.min(
      Math.max(Math.round(asNumber(metadata.rating, 3)), 1),
      5,
    );
    const helpful = metadata.helpful === true;
    const label = asString(metadata.quality_label) ||
      rlhfLabel(rating, helpful);
    ratingSum += rating;
    if (asString(metadata.comment)) commentRows += 1;
    if (label === "positive") positiveSignals += 1;
    else if (label === "negative") negativeSignals += 1;
    else neutralSignals += 1;
  }

  for (const row of judgmentRows) {
    const metadata = row.metadata ?? {};
    const evaluation = metadata.quality_evaluation as
      | Record<string, unknown>
      | undefined;
    const score = asNumber(evaluation?.overall_score, 0);
    judgmentScoreSum += score;
    if (score >= 80 || evaluation?.passed === true) approvedJudgments += 1;
    else reviewJudgments += 1;
  }

  const rlhfTotal = rlhfRows.length;
  const judgmentTotal = judgmentRows.length;
  const totalRecords = rlhfTotal + judgmentTotal;
  const rlhfScore = rlhfQualityScore(
    positiveSignals,
    neutralSignals,
    rlhfTotal,
  );
  const averageRating = rlhfTotal === 0
    ? 0
    : Math.round((ratingSum / rlhfTotal) * 10) / 10;
  const judgmentQualityScore = judgmentTotal === 0
    ? 0
    : Math.round(judgmentScoreSum / judgmentTotal);
  const sourceCoverage = [
    rlhfTotal > 0,
    judgmentTotal > 0,
  ].filter(Boolean).length;
  const eligibleRecords = positiveSignals + negativeSignals +
    approvedJudgments;
  const qualityScore = clampPercent(
    rlhfScore * 0.55 + judgmentQualityScore * 0.35 + sourceCoverage * 5,
  );
  const readyForEvalBatch = eligibleRecords >= 20 && qualityScore >= 70;
  const readyForFineTune = eligibleRecords >= 100 && qualityScore >= 80 &&
    sourceCoverage >= 2;
  const piiRisk = commentRows > 0 || judgmentTotal > 0 ? "medium" : "low";
  const nextAction = readyForFineTune
    ? "匿名化済みの JSONL 学習セットを確定し、微調整ジョブの前にオフライン評価を実施しましょう。"
    : readyForEvalBatch
    ? "まず評価バッチを作成し、有効レコードが100件以上になるまで選好ペアを集め続けましょう。"
    : "チューニング前に、「役に立った／改善が必要」の明示的なフィードバックと日々の判断結果をさらに集めましょう。";

  return {
    method: "scale_egp_first_party_data_engine_v1",
    total_records: totalRecords,
    eligible_records: eligibleRecords,
    blocked_records: Math.max(totalRecords - eligibleRecords, 0),
    quality_score: qualityScore,
    ready_for_eval_batch: readyForEvalBatch,
    ready_for_fine_tune: readyForFineTune,
    pii_risk: piiRisk,
    average_rating: averageRating,
    source_counts: {
      ai_university_rlhf: rlhfTotal,
      daily_judgment_quality: judgmentTotal,
    },
    signal_summary: {
      positive_signals: positiveSignals,
      neutral_signals: neutralSignals,
      negative_signals: negativeSignals,
      approved_judgments: approvedJudgments,
      review_judgments: reviewJudgments,
    },
    kgi:
      "安全でない生データの微調整に頼らず、自社プロダクトのデータでAIの回答品質を高めます。",
    csf: [
      "Consent-aware first-party signal collection",
      "De-identification before export",
      "Quality gate before training",
      "Evaluation batch before fine-tune",
    ],
    kpi: {
      eligible_records_target: 100,
      quality_score_target: 80,
      source_coverage_target: 2,
      current_eligible_records: eligibleRecords,
      current_quality_score: qualityScore,
      current_source_coverage: sourceCoverage,
    },
    export_plan: {
      formats: ["jsonl_sft", "preference_pairs", "evaluation_set"],
      governance_steps: [
        "Remove direct identifiers and long free-form comments unless reviewed.",
        "Keep negative examples as preference/improvement pairs, not as SFT gold answers.",
        "Hold back at least 20% as an evaluation set before training.",
      ],
      suggested_holdout_ratio: 0.2,
    },
    next_action: nextAction,
  };
}

type DailyJudgmentQualityCriterion = {
  id: string;
  label: string;
  score: number;
  weight: number;
  reason: string;
};

type DailyJudgmentQualityEvaluation = {
  method: string;
  threshold: number;
  overall_score: number;
  passed: boolean;
  quality_gate: string;
  criteria: DailyJudgmentQualityCriterion[];
  improvement_actions: string[];
  monitoring_cadence: string;
  scale_pattern: Record<string, unknown>;
};

function clampPercent(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function textLengthScore(
  text: string,
  minGood: number,
  maxGood: number,
): number {
  const length = text.trim().length;
  if (length <= 0) return 20;
  if (length >= minGood && length <= maxGood) return 100;
  if (length < minGood) return clampPercent(45 + (length / minGood) * 45);
  const overflowRatio = Math.min((length - maxGood) / maxGood, 1);
  return clampPercent(100 - overflowRatio * 35);
}

function keywordScore(text: string, keywords: string[], base = 45): number {
  const normalized = text.toLowerCase();
  const hits =
    keywords.filter((keyword) => normalized.includes(keyword.toLowerCase()))
      .length;
  return clampPercent(
    base + hits * Math.floor((100 - base) / Math.max(1, keywords.length)),
  );
}

function normalizeDailyJudgmentPayload(
  parsed: Record<string, unknown> | null,
  rawText: string,
): Record<string, unknown> {
  if (parsed) {
    const score = clampPercent(asNumber(parsed.score, 0));
    return {
      score,
      judgment: asString(parsed.judgment) ||
        (score >= 75 ? "良好" : score >= 50 ? "注意" : "警戒"),
      advice: asString(parsed.advice) || rawText.slice(0, 600),
      focus_area: asString(parsed.focus_area) || asString(parsed.focusArea) ||
        "今日の最重要行動",
      kgi: parsed.kgi ?? "今日の意思決定品質を上げる",
      csf: Array.isArray(parsed.csf) ? parsed.csf : [
        "浪費を減らす",
        "最重要タスクに集中する",
      ],
      kpi: parsed.kpi ?? {
        focus_minutes: 90,
        waste_interruptions: 0,
        review_count: 1,
      },
    };
  }
  return {
    score: 50,
    judgment: "要確認",
    advice: rawText.slice(0, 1000),
    focus_area: "今日の最重要行動",
    kgi: "今日の意思決定品質を上げる",
    csf: ["浪費を減らす", "最重要タスクに集中する"],
    kpi: {
      focus_minutes: 90,
      waste_interruptions: 0,
      review_count: 1,
    },
  };
}

function buildDailyJudgmentQualityEvaluation(
  judgment: Record<string, unknown>,
): DailyJudgmentQualityEvaluation {
  const advice = asString(judgment.advice);
  const focusArea = asString(judgment.focus_area ?? judgment.focusArea);
  const kgiText = asString(judgment.kgi);
  const csfText = JSON.stringify(judgment.csf ?? "");
  const kpiText = JSON.stringify(judgment.kpi ?? "");
  const combined = [advice, focusArea, kgiText, csfText, kpiText].join("\n");

  const criteria: DailyJudgmentQualityCriterion[] = [
    {
      id: "kgi_csf_kpi_alignment",
      label: "KGI/CSF/KPI alignment",
      score: keywordScore(
        combined,
        ["kgi", "csf", "kpi", "目標", "成功要因", "数値", "レビュー"],
        35,
      ),
      weight: 30,
      reason: "Checks whether the answer has a measurable goal structure.",
    },
    {
      id: "actionability",
      label: "Actionability",
      score: clampPercent(
        (textLengthScore(advice, 80, 700) +
          keywordScore(
            advice,
            ["今日", "次", "やる", "減らす", "集中", "記録", "確認"],
            35,
          )) / 2,
      ),
      weight: 30,
      reason: "Checks whether the advice can be executed today.",
    },
    {
      id: "context_grounding",
      label: "Context grounding",
      score: clampPercent(
        (focusArea ? 25 : 0) +
          (asNumber(judgment.score, -1) >= 0 ? 25 : 0) +
          (advice.length > 0 ? 20 : 0) +
          (kgiText || csfText !== '""' || kpiText !== '""' ? 30 : 0),
      ),
      weight: 25,
      reason: "Checks whether score, focus, and decision context are present.",
    },
    {
      id: "clarity",
      label: "Clarity",
      score: textLengthScore(combined, 120, 1200),
      weight: 15,
      reason: "Checks whether the response is concise enough to review.",
    },
  ];

  const totalWeight = criteria.reduce((sum, item) => sum + item.weight, 0);
  const overall = clampPercent(
    criteria.reduce((sum, item) => sum + item.score * item.weight, 0) /
      totalWeight,
  );
  const threshold = 80;
  const improvementActions = criteria
    .filter((item) => item.score < threshold)
    .map((item) => {
      if (item.id === "kgi_csf_kpi_alignment") {
        return "Add explicit KGI, CSF, and numeric KPI before relying on the judgment.";
      }
      if (item.id === "actionability") {
        return "Rewrite the advice as one concrete next action for today.";
      }
      if (item.id === "context_grounding") {
        return "Attach score, focus area, and decision context for auditability.";
      }
      return "Shorten the answer and remove vague phrasing.";
    });

  return {
    method: "scale_evaluation_pattern_v1",
    threshold,
    overall_score: overall,
    passed: overall >= threshold,
    quality_gate: overall >= threshold ? "approved" : "needs_review",
    criteria,
    improvement_actions: improvementActions.length > 0
      ? improvementActions
      : ["Monitor outcome and feed the result into the next daily review."],
    monitoring_cadence: "daily",
    scale_pattern: {
      evaluator: "automatic_rubric",
      dimensions: criteria.map((item) => item.id),
      pass_rule: `overall_score >= ${threshold}`,
      feedback_loop: "save evaluation snapshots and review failures weekly",
    },
  };
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

type NoteSearchMetadataRow = {
  id: number;
  created_at: string | null;
  is_pinned: boolean | null;
  is_favorite: boolean | null;
  reminder_date: string | null;
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
  taskType: "RETRIEVAL_DOCUMENT" | "RETRIEVAL_QUERY" = "RETRIEVAL_DOCUMENT",
): Promise<number[][]> {
  if (texts.length === 0) return [];
  const response = await fetchWithProviderTimeout(
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
          embedContentConfig: {
            outputDimensionality: 768,
            taskType,
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
  const vectors = (data.embeddings ?? []).map((item) => item.values ?? []);
  if (
    vectors.length !== texts.length ||
    vectors.some((vector) => vector.length !== 768)
  ) {
    throw new Error(
      `Gemini embedding returned invalid dimensions: ${
        vectors.map((vector) => vector.length).join(",")
      }`,
    );
  }
  return vectors;
}

async function syncNoteSearchIndexNote(
  admin: SupabaseClient,
  userId: string,
  noteId: number,
): Promise<void> {
  const { error } = await admin.rpc("sync_note_search_index_note", {
    p_user_id: userId,
    p_note_id: noteId,
  });
  if (error) {
    throw new Error(`sync_note_search_index_note failed: ${error.message}`);
  }
}

async function embedPendingNoteSearchRows(
  admin: SupabaseClient,
  userId: string,
  apiKey: string,
  limit = 12,
  noteId?: number,
): Promise<number> {
  const baseQuery = admin
    .from("note_search_index")
    .select("note_id, title, content, tags")
    .eq("user_id", userId)
    .eq("is_archived", false);
  const { data, error } = noteId == null
    ? await baseQuery
      .is("embedding", null)
      .order("note_updated_at", { ascending: false })
      .limit(limit)
    : await baseQuery.eq("note_id", noteId).is("embedding", null).limit(1);
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

async function loadNoteSearchMetadata(
  admin: SupabaseClient,
  userId: string,
  noteIds: number[],
): Promise<Map<number, NoteSearchMetadataRow>> {
  if (noteIds.length === 0) return new Map();
  const { data, error } = await admin
    .from("notes")
    .select("id, created_at, is_pinned, is_favorite, reminder_date")
    .eq("user_id", userId)
    .in("id", noteIds);
  if (error) throw new Error(`note search metadata failed: ${error.message}`);
  return new Map(
    ((data ?? []) as NoteSearchMetadataRow[]).map((row) => [row.id, row]),
  );
}

async function invokeAiAssistant(
  authHeader: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (!authHeader) throw new Error("Missing authorization header");
  const response = await fetchWithProviderTimeout(
    `${SUPABASE_URL}/functions/v1/ai-assistant`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": authHeader,
      },
      body: JSON.stringify(payload),
    },
  );
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
  const res = await fetchWithProviderTimeout(
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
  const res = await fetchWithProviderTimeout(`${baseUrl}/task.create`, {
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

type VoiceUsagePayload = {
  tier: string;
  used: number;
  limit: number;
  remaining: number;
  generation_count: number;
  generation_limit: number;
  period_start?: string;
};

async function getVoiceUsage(
  admin: SupabaseClient,
  userId: string,
): Promise<VoiceUsagePayload> {
  const { error: reconciliationError } = await admin.rpc(
    "reconcile_voice_dubbing_quota",
    { p_user_id: userId },
  );
  if (reconciliationError) throw new Error(reconciliationError.message);
  const periodStart = new Date(
    Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1),
  ).toISOString().slice(0, 10);
  const [{ data: subscription, error: subscriptionError }, {
    data: counter,
    error: counterError,
  }] = await Promise.all([
    admin.from("billing_subscriptions").select("tier,status").eq(
      "user_id",
      userId,
    ).maybeSingle(),
    admin.from("billing_usage_counters").select(
      "voice_character_count,voice_generation_count",
    ).eq("user_id", userId).eq("period_start", periodStart).maybeSingle(),
  ]);
  if (subscriptionError) throw new Error(subscriptionError.message);
  if (counterError) throw new Error(counterError.message);

  const subscriptionRecord = subscription as Record<string, unknown> | null;
  const status = asString(subscriptionRecord?.status);
  const tier = status === "active" || status === "trialing"
    ? asString(subscriptionRecord?.tier) || "free"
    : "free";
  const rawUsed = (counter as Record<string, unknown> | null)
    ?.voice_character_count;
  const used = typeof rawUsed === "number"
    ? rawUsed
    : Number(rawUsed ?? 0) || 0;
  const limit = voiceCharacterLimit(tier);
  const rawGenerationCount = (counter as Record<string, unknown> | null)
    ?.voice_generation_count;
  const generationCount = typeof rawGenerationCount === "number"
    ? rawGenerationCount
    : Number(rawGenerationCount ?? 0) || 0;
  const generationLimit = tier === "team" ? 3000 : tier === "pro" ? 1000 : 100;
  return {
    tier,
    used,
    limit,
    remaining: Math.max(limit - used, 0),
    generation_count: generationCount,
    generation_limit: generationLimit,
  };
}

function normalizeVoiceUsagePayload(value: unknown): VoiceUsagePayload & {
  allowed: boolean;
  reason?: string;
} {
  const raw = asRecord(value) ?? {};
  const tier = asString(raw.tier) || "free";
  const limit = Number(raw.limit ?? voiceCharacterLimit(tier));
  const used = Number(raw.used ?? 0);
  const remaining = Number(raw.remaining ?? Math.max(limit - used, 0));
  const generationCount = Number(raw.generation_count ?? 0);
  const generationLimit = Number(
    raw.generation_limit ??
      (tier === "team" ? 3000 : tier === "pro" ? 1000 : 100),
  );
  return {
    allowed: raw.allowed === true,
    tier,
    limit: Number.isFinite(limit) ? limit : voiceCharacterLimit(tier),
    used: Number.isFinite(used) ? used : 0,
    remaining: Number.isFinite(remaining) ? remaining : 0,
    generation_count: Number.isFinite(generationCount) ? generationCount : 0,
    generation_limit: Number.isFinite(generationLimit) ? generationLimit : 100,
    period_start: asString(raw.period_start) || undefined,
    reason: asString(raw.reason) || undefined,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const requestUrl = new URL(req.url);
    if (
      req.method === "GET" &&
      requestUrl.pathname.endsWith("/.well-known/agent-card.json")
    ) {
      return a2aJson(
        buildCompanyAgentCard(`${SUPABASE_URL}/functions/v1/ai-hub`),
        200,
        { "Cache-Control": "public, max-age=3600" },
      );
    }
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const userId = await getUserId(req);
    const a2aPath = companyA2ARelativePath(req);
    if (a2aPath !== null) {
      if (!userId) {
        return a2aJson(
          {
            error: {
              code: "UnauthenticatedError",
              message: "Bearer authentication is required",
            },
          },
          401,
          { "WWW-Authenticate": 'Bearer realm="ai-company-builder"' },
        );
      }
      const body = req.method === "POST"
        ? await req.json() as Record<string, unknown>
        : {};
      return await handleCompanyA2ARequest(req, body, admin, userId);
    }

    const body = req.method === "POST"
      ? await req.json() as Record<string, unknown>
      : {};
    const action = String(
      body.action ?? requestUrl.searchParams.get("action") ?? "",
    );

    const authorization = authorizeAiHubAction(action, {
      userId,
      isServiceRole: isServiceRoleRequest(req),
    });
    if (!authorization.allowed) {
      return json({ error: authorization.error }, authorization.status);
    }

    switch (action) {
      case "knowledge_graph.status":
      case "knowledge_graph.upload":
      case "knowledge_graph.query":
      case "knowledge_graph.delete_document": {
        if (
          ["knowledge_graph.upload", "knowledge_graph.query"].includes(action)
        ) {
          const offlinePolicy = parseOfflineSecureModePolicy(body);
          if (shouldBlockExternalProviderCall(offlinePolicy)) {
            return json(
              buildOfflineBlockedResponseBody(offlinePolicy, {
                action,
                provider: "writer",
              }),
              409,
            );
          }
        }
        const writerApiKey = Deno.env.get("WRITER_API_KEY") ?? "";
        if (action === "knowledge_graph.query" && writerApiKey) {
          const usage = await checkAndRecordAiUsage(
            supabaseUsageStore(admin),
            userId ?? "",
          );
          if (!usage.allowed) {
            return json({
              error: "Monthly AI query limit reached.",
              code: "usage_limit_reached",
            }, 402);
          }
          const budget = await checkBudget("ef", "ai-hub");
          if (!budget.ok) {
            return json({
              error: "AI budget limit reached.",
              code: "budget_limit_reached",
            }, 429);
          }
        }
        const result = await handleWriterKnowledgeGraphAction({
          action,
          body,
          userId: userId ?? "",
          configured: writerApiKey.length > 0,
          store: createSupabaseWriterKnowledgeGraphStore(admin),
          gateway: writerApiKey
            ? createWriterKnowledgeGraphGateway(writerApiKey)
            : null,
        });
        return json(result);
      }

      case "judgment.get": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const today = new Date().toLocaleDateString("ja-JP");
        const prompt = prependCharacter([
          `今日は${today}です。`,
          "自分株式会社のCEOとして、今日の意思決定を日本語で判定してください。",
          "浪費を減らし、時間・お金・健康・体力・知能・集中力を守ることを最重要にしてください。",
          "必ずJSONのみで返してください。",
          '{"score":0-100,"judgment":"良好/注意/警戒","advice":"今日やるべき1-3個の具体行動","focus_area":"最優先領域","kgi":"今日のKGI","csf":["CSF1","CSF2"],"kpi":{"focus_minutes":90,"waste_interruptions":0,"review_count":1}}',
        ].join("\n"));
        const text = await callGemini(prompt, geminiKey);
        const parsed = extractJsonObject(text);
        const payload = normalizeDailyJudgmentPayload(parsed, text);
        const qualityEvaluation = buildDailyJudgmentQualityEvaluation(payload);
        if (userId) {
          try {
            await addItem(admin, "daily_judgment_quality_evaluation", userId, {
              judgment: payload,
              quality_evaluation: qualityEvaluation,
              evaluated_at: new Date().toISOString(),
            });
          } catch (error) {
            console.warn("judgment.get evaluation save failed", error);
          }
        }
        return json({
          success: true,
          ...payload,
          raw_text: text,
          quality_evaluation: qualityEvaluation,
        });
      }

      case "judgment.get.legacy": {
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const today = new Date().toLocaleDateString("ja-JP");
        const prompt = prependCharacter(
          `今日${today}の自己成長・キャリア・健康に関するAI判定をしてください。JSON: {"score":0-100,"judgment":"良好/注意/警戒","advice":"...", "focus_area":"..."}`,
        );
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

      case "kpi.monthly_summary": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const ledger = body.ledger && typeof body.ledger === "object"
          ? body.ledger as Record<string, unknown>
          : {};
        const goals = Array.isArray(body.goals)
          ? body.goals
            .filter((item): item is Record<string, unknown> =>
              item !== null && typeof item === "object"
            )
            .slice(0, 12)
          : [];
        const averageProgress = asNumber(ledger.average_progress, 0);
        const monthOverMonthDelta = asNumber(ledger.month_over_month_delta, 0);
        const goalCount = asNumber(ledger.goal_count, goals.length);
        const completedCount = asNumber(ledger.completed_count, 0);
        const lowProgressGoal = goals.find((goal) =>
          asNumber(goal.progress, 0) < 80
        );
        const fallbackActions = [
          averageProgress < 40
            ? "平均進捗が低いです。今月は最重要 LifeGoal を 1 件に絞り、毎日 15 分の実行枠を固定してください。"
            : averageProgress < 70
            ? "平均進捗は中盤です。50% 未満の目標を 1 件選び、次回レビューまでに +10pt だけ進めてください。"
            : "平均進捗は良好です。完了目前の目標を締め切り、翌月 KPI の準備に 1 手だけ着手してください。",
          monthOverMonthDelta < 0
            ? "前月比が落ちています。新規 KPI を増やすより、既存目標のレビュー頻度を週 2 回に戻してください。"
            : "前月比は改善傾向です。今月の勝ちパターンを 1 行メモに残し、来月の再現性を上げてください。",
          lowProgressGoal
            ? `優先フォロー: ${
              asString(lowProgressGoal.title)
            } を今日の最初の 1 手にしてください。`
            : `今月は ${completedCount}/${goalCount} 件完了です。完了済み KPI の維持条件を 1 つだけ決めてください。`,
        ];
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({
            success: true,
            source: "heuristic",
            advice: fallbackActions.join("\n"),
            actions: fallbackActions,
          });
        }

        const prompt = prependCharacter([
          "あなたは自分株式会社のCFOです。LifeGoals から作った月次 KPI 台帳を見て、今月の達成確率を上げる助言を日本語で返してください。",
          "必ず JSON のみで返してください。",
          'Schema: {"advice":"短い総評","actions":["今日やる1手","今週やる1手","来月に残す判断"]}',
          `Ledger: ${JSON.stringify(ledger)}`,
          `Goals: ${
            JSON.stringify(goals.map((goal) => ({
              title: asString(goal.title),
              level: asString(goal.level),
              progress: asNumber(goal.progress, 0),
              current_month_delta: asNumber(goal.current_month_delta, 0),
              month_over_month_delta: asNumber(
                goal.month_over_month_delta,
                0,
              ),
              target_date: asString(goal.target_date),
            })))
          }`,
        ].join("\n"));

        try {
          const text = await callGemini(prompt, geminiKey);
          const parsed = extractJsonObject(text);
          const actions = Array.isArray(parsed?.actions)
            ? parsed.actions
              .map((item) => asString(item))
              .filter((item) => item.length > 0)
              .slice(0, 4)
            : [];
          const advice = asString(parsed?.advice) || actions.join("\n") ||
            text.trim();
          return json({
            success: true,
            source: "gemini",
            advice,
            actions: actions.length > 0 ? actions : fallbackActions,
            raw_text: text,
          });
        } catch (error) {
          return json({
            success: true,
            source: "heuristic_fallback",
            advice: fallbackActions.join("\n"),
            actions: fallbackActions,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }

      case "search.index_note": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const noteId = Number(body.note_id ?? body.noteId);
        if (!Number.isInteger(noteId) || noteId <= 0) {
          return json({ error: "A valid note_id is required" }, 400);
        }

        const { data: ownedNote, error: noteError } = await admin
          .from("notes")
          .select("id")
          .eq("id", noteId)
          .eq("user_id", userId)
          .maybeSingle();
        if (noteError) {
          return json(
            { error: `Note lookup failed: ${noteError.message}` },
            500,
          );
        }
        if (!ownedNote) return json({ error: "Note not found" }, 404);

        try {
          await syncNoteSearchIndexNote(admin, userId, noteId);
        } catch (error) {
          return json({ error: asString(error) || "Index sync failed" }, 500);
        }

        let embeddingStatus = "not_configured";
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (geminiKey) {
          try {
            const indexed = await embedPendingNoteSearchRows(
              admin,
              userId,
              geminiKey,
              1,
              noteId,
            );
            embeddingStatus = indexed > 0 ? "updated" : "unchanged";
          } catch (error) {
            embeddingStatus = "failed";
            console.warn("search.index_note embedding failed", error);
          }
        }

        return json({
          success: true,
          note_id: noteId,
          embeddingStatus,
        });
      }

      case "task.clarity.evaluate": {
        const title = asString(body.title);
        const description = asString(body.description);
        if (!title) {
          return json({ success: false, error: "title is required." }, 400);
        }

        const input = { title, description };
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        let evaluation = evaluateTaskClarityHeuristically(input);
        if (geminiKey) {
          try {
            const text = await callGemini(
              buildTaskClarityPrompt(input),
              geminiKey,
            );
            evaluation = normalizeTaskClarityResult(
              extractJsonObject(text),
              input,
              "gemini",
            );
          } catch (error) {
            console.warn(
              "task.clarity.evaluate Gemini fallback:",
              error instanceof Error ? error.message : "unknown error",
            );
            evaluation = evaluateTaskClarityHeuristically(
              input,
              "heuristic_fallback",
            );
          }
        }

        return json({
          success: true,
          evaluation: {
            ...evaluation,
            evaluated_at: new Date().toISOString(),
          },
        });
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

        let queryEmbedding: number[] | null = null;
        let searchMode = "text_fallback";

        if (geminiKey) {
          const [pendingResult, queryResult] = await Promise.allSettled([
            embedPendingNoteSearchRows(admin, userId, geminiKey),
            embedTextsWithGemini(
              [truncateForEmbedding(query, 1200)],
              geminiKey,
              "RETRIEVAL_QUERY",
            ),
          ]);
          if (pendingResult.status === "rejected") {
            console.warn(
              "search.query pending embedding failed",
              pendingResult.reason,
            );
          }
          if (queryResult.status === "fulfilled") {
            queryEmbedding = queryResult.value[0] ?? null;
            if (queryEmbedding && queryEmbedding.length > 0) {
              searchMode = "ai";
            }
          } else {
            console.warn("search.query embedding failed", queryResult.reason);
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

        let metadata = new Map<number, NoteSearchMetadataRow>();
        try {
          metadata = await loadNoteSearchMetadata(
            admin,
            userId,
            rows.map((row) => row.note_id),
          );
        } catch (error) {
          console.warn("search.query metadata load failed", error);
        }

        const results = rows.map((row) => {
          const noteMetadata = metadata.get(row.note_id);
          return {
            id: row.note_id,
            title: row.title ?? "",
            content: row.content ?? "",
            tags: row.tags ?? [],
            category_id: row.category_id,
            created_at: noteMetadata?.created_at ?? null,
            updated_at: row.note_updated_at,
            is_pinned: noteMetadata?.is_pinned ?? false,
            is_favorite: noteMetadata?.is_favorite ?? false,
            reminder_date: noteMetadata?.reminder_date ?? null,
            search_score: row.combined_rank ?? row.text_rank ??
              row.vector_rank ?? 0,
            search_text_rank: row.text_rank ?? 0,
            search_vector_rank: row.vector_rank ?? 0,
            match_reason: row.match_reason ??
              (queryEmbedding == null ? "text" : "hybrid"),
          };
        });

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
          const r = await fetchWithProviderTimeout(
            "https://api.openai.com/v1/chat/completions",
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${openaiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                model: "gpt-4o-mini",
                messages: [{
                  role: "user",
                  content: `200字以内で要約: ${text}`,
                }],
                max_tokens: 300,
              }),
            },
          );
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

      case "agent.tool_policy.evaluate": {
        const gate = await evaluateAgentToolGate(admin, userId!, body);
        return json({
          success: gate.decision.allowed,
          decision: publicPolicyDecision(gate.decision),
          actor_role: gate.actorRole,
          actor_agent_id: gate.actorAgentId,
          requested_scopes: gate.requestedScopes,
          allowed_scopes: gate.allowedScopes,
          approval: gate.approval,
          side_effects: gate.sideEffects,
          audit_logged: gate.auditLogged,
        }, gate.decision.allowed ? 200 : 403);
      }

      case "agent.run": {
        const shouldEvaluateToolPolicy = body.tool_name !== undefined ||
          body.toolName !== undefined ||
          body.requested_scopes !== undefined ||
          body.requestedScopes !== undefined ||
          body.scopes !== undefined;
        const gate = shouldEvaluateToolPolicy
          ? await evaluateAgentToolGate(admin, userId!, body)
          : null;
        if (gate && !gate.decision.allowed) {
          return json({
            success: false,
            error: "agent_tool_policy_denied",
            decision: publicPolicyDecision(gate.decision),
            actor_role: gate.actorRole,
            audit_logged: gate.auditLogged,
          }, 403);
        }
        const item = await addItem(admin, "agent_run_log", userId!, {
          agent_id: body.agent_id,
          task: body.task,
          status: "queued",
          tool_policy: gate
            ? {
              decision: publicPolicyDecision(gate.decision),
              actor_role: gate.actorRole,
              actor_agent_id: gate.actorAgentId,
              requested_scopes: gate.requestedScopes,
              allowed_scopes: gate.allowedScopes,
              approval: gate.approval,
              side_effects: gate.sideEffects,
              audit_logged: gate.auditLogged,
            }
            : null,
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
        const requestedContextIds = asStringArray(
          body.context_file_ids ?? body.contextFileIds,
        ).slice(0, 5);
        let externalFileContext = "";
        let attachedContextIds: string[] = [];
        if (requestedContextIds.length > 0) {
          const { data: contextRows, error: contextError } = await admin
            .from("hub_data")
            .select("id,metadata")
            .eq("source", MCP_FILE_CONTEXT_SOURCE)
            .filter("metadata->>user_id", "eq", userId!)
            .filter("metadata->>security_status", "eq", "allowed")
            .in("id", requestedContextIds);
          if (contextError) throw new Error(contextError.message);
          const rowsById = new Map(
            (contextRows ?? []).map((row) => [String(row.id), row]),
          );
          const orderedRows: Record<string, unknown>[] = [];
          for (const id of requestedContextIds) {
            const row = rowsById.get(id);
            if (row) orderedRows.push(row);
          }
          attachedContextIds = orderedRows.map((row) => String(row.id));
          externalFileContext = buildExternalFileContextBlock(orderedRows);
        }
        const imageInstruction = image
          ? "\n添付画像も確認し、見えている内容・文脈・ユーザーの質問に関係する示唆を含めて回答してください。"
          : "";
        const prompt = [
          externalFileContext ? AI_CHARACTER_PREAMBLE : "",
          "あなたは個人AIエージェントです。",
          recentContext ? `履歴:\n${recentContext}` : "",
          externalFileContext,
          `ユーザーメッセージ: ${message}${imageInstruction}`,
        ].filter(Boolean).join("\n\n");
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
          context_file_ids: attachedContextIds,
        });
        return json({
          success: true,
          response,
          multimodal: Boolean(image),
          response_mode: responseMode,
          provider: responseMode === "video" ? "hedra" : agentProvider,
          manus: manusMetadata,
          video: videoMetadata,
          context_file_ids: attachedContextIds,
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

      case "corporate_site.readiness": {
        const mode = asString(body.mode).toLowerCase();
        if (mode !== "review" && mode !== "generate") {
          return json({ error: "mode must be review or generate" }, 400);
        }
        const profile = {
          companyName: asString(body.company_name),
          representativeName: asString(body.representative_name),
          registeredAddress: asString(body.registered_address),
          businessPlanSummary: asString(body.business_plan_summary),
          virtualOffice: body.virtual_office === true,
        };

        try {
          validateCorporateSiteProfile(profile);
          if (mode === "generate") {
            const rawMilestones = Array.isArray(body.wbs_milestones)
              ? body.wbs_milestones
              : asString(body.wbs_milestones).split(/\r?\n/);
            const html = generateCorporateSiteHtml({
              ...profile,
              contact: asString(body.contact),
              wbsMilestones: rawMilestones.map(asString).filter(Boolean),
            });
            return json({
              success: true,
              mode,
              html,
              disclaimer: CORPORATE_SITE_READINESS_DISCLAIMER,
            });
          }

          const sourceUrl = asString(body.url);
          if (!sourceUrl) return json({ error: "url required" }, 400);
          const document = await fetchPublicResearchDocument(sourceUrl);
          const result = reviewCorporateSiteDocument(
            document.markdown,
            profile,
          );
          return json({
            success: true,
            mode,
            source: {
              canonical_url: document.canonicalUrl,
              title: document.title,
              http_status: document.httpStatus,
            },
            result: {
              ready_for_document_review: result.readyForDocumentReview,
              score: result.score,
              checks: result.checks,
              missing_required_items: result.missingRequiredItems,
              manual_review_items: result.manualReviewItems,
              disclaimer: result.disclaimer,
            },
          });
        } catch (error) {
          const message = error instanceof Error
            ? error.message
            : String(error);
          const normalized = message.toLowerCase();
          const invalidInput = normalized.includes("required") ||
            normalized.includes("characters or fewer") ||
            normalized.includes("source url") ||
            normalized.includes("private") ||
            normalized.includes("local network") ||
            normalized.includes("not allowed") ||
            normalized.includes("only http");
          return json({
            success: false,
            status: invalidInput ? "invalid_request" : "site_fetch_failed",
            message,
          }, invalidInput ? 400 : 422);
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

      case "company_builder.research.add": {
        const companyId = asString(body.company_id);
        const sourceUrl = asString(body.source_url ?? body.url);
        if (!companyId) return json({ error: "company_id required" }, 400);
        if (!sourceUrl) return json({ error: "source_url required" }, 400);
        try {
          const source = await ingestCompanyResearchSource(
            admin,
            userId!,
            companyId,
            sourceUrl,
          );
          return json({ success: true, source });
        } catch (error) {
          const message = error instanceof Error
            ? error.message
            : String(error);
          const status = message === "Company not found"
            ? 404
            : message.toLowerCase().includes("private") ||
                message.toLowerCase().includes("source url") ||
                message.toLowerCase().includes("unsupported")
            ? 400
            : 422;
          return json({
            success: false,
            status: "research_ingestion_failed",
            message,
          }, status);
        }
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
        const thirtyDaySaasBlueprint = buildThirtyDaySaasBlueprint(
          companyName,
          idea,
          plan,
        );

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
            thirty_day_saas_blueprint: thirtyDaySaasBlueprint,
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

        await ensureCompanyRuntimeControl(
          admin,
          userId!,
          companyId,
          passed ? "idle" : "blocked",
          passed ? null : plan.recommendation,
        );
        await addCompanyEvent(
          admin,
          userId!,
          companyId,
          passed ? "gate_approved" : "gate_rejected",
          passed ? "idle" : "blocked",
          {
            company_name: companyName,
            overall_score: overallScore,
            threshold,
            recommendation: plan.recommendation,
          },
        );

        if (!passed) {
          await addCompanyAudit(
            admin,
            userId!,
            companyId,
            "company_builder.bootstrap_rejected",
            {
              company_name: companyName,
              overall_score: overallScore,
              threshold,
              recommendation: plan.recommendation,
              fail_closed: true,
            },
          );
          const detail = await getCompanyBuilderDetail(
            admin,
            userId!,
            companyId,
          );
          return json({
            success: true,
            status: "gate_rejected",
            company_id: companyId,
            overall_score: overallScore,
            passed: false,
            ...detail,
          });
        }

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
          thirtyDaySaasBlueprint,
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
            mrr_target: thirtyDaySaasBlueprint.mrr_target,
            paid_users_target: thirtyDaySaasBlueprint.paid_users_target,
          },
        );
        await addCompanyEvent(
          admin,
          userId!,
          companyId,
          "bootstrap_completed",
          "idle",
          {
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

      case "company_builder.start":
      case "company_builder.resume":
      case "company_builder.pause":
      case "company_builder.stop": {
        const companyId = asString(body.company_id);
        if (!companyId) return json({ error: "company_id required" }, 400);
        const detail = await getCompanyBuilderDetail(admin, userId!, companyId);
        if (!detail) return json({ error: "Company not found" }, 404);

        const company = asRecord(detail.company) ?? {};
        const metadata = asRecord(company.metadata) ?? {};
        if (metadata.passed !== true) {
          return json({
            success: false,
            status: "gate_rejected",
            message:
              "The viability gate did not pass. Revise the company idea before starting agents.",
          }, 409);
        }

        const command = action.replace("company_builder.", "");
        const { data: control, error: controlError } = await admin.rpc(
          "set_company_agent_runtime_state",
          {
            p_user_id: userId!,
            p_company_id: companyId,
            p_command: command,
          },
        );
        if (controlError) {
          return json({
            success: false,
            status: "runtime_control_failed",
            message: controlError.message,
          }, 409);
        }

        if (command === "start" || command === "resume") {
          await enqueueCompanyRuntime(
            admin,
            userId!,
            companyId,
            command,
          );
          scheduleCompanyRuntimeWorker();
        }

        return json({
          success: true,
          command,
          runtime_control: control,
        }, command === "start" || command === "resume" ? 202 : 200);
      }

      case "company_builder.global_kill_switch": {
        const enabled = body.enabled !== false;
        const reason = asString(body.reason) ||
          (enabled ? "Stopped by the user" : "Reset by the user");
        const { data, error } = await admin.rpc(
          "set_company_agent_global_kill_switch",
          {
            p_user_id: userId!,
            p_enabled: enabled,
            p_reason: reason,
          },
        );
        if (error) throw new Error(error.message);
        return json({
          success: true,
          global_kill_switch: data,
        });
      }

      case "company_builder.worker": {
        if (!isServiceRoleRequest(req)) {
          return json({ error: "Forbidden" }, 403);
        }
        const result = await runCompanyRuntimeWorker(admin);
        return json({ success: true, ...result }, 202);
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
        const facultyCode = asString(body.faculty_code);
        const departmentCode = asString(body.department_code);
        let query = admin.from("ai_university_content")
          .select("*")
          .eq("is_active", true);

        if (departmentCode) {
          let departmentQuery = admin.from("university_departments")
            .select("id, university_faculties!inner(faculty_code)")
            .eq("department_code", departmentCode);
          if (facultyCode) {
            departmentQuery = departmentQuery.eq(
              "university_faculties.faculty_code",
              facultyCode,
            );
          }
          const { data: departments, error: departmentError } =
            await departmentQuery.limit(1);
          if (departmentError) throw new Error(departmentError.message);
          const departmentId = Array.isArray(departments) &&
              departments.length > 0
            ? asString((departments[0] as { id?: unknown }).id)
            : "";
          if (!departmentId) return json({ success: true, items: [] });
          query = query.eq("department_id", departmentId);
        } else if (facultyCode) {
          const { data: faculties, error: facultyError } = await admin
            .from("university_faculties")
            .select("id")
            .eq("faculty_code", facultyCode)
            .limit(1);
          if (facultyError) throw new Error(facultyError.message);
          const facultyId = Array.isArray(faculties) && faculties.length > 0
            ? asString((faculties[0] as { id?: unknown }).id)
            : "";
          if (!facultyId) return json({ success: true, items: [] });
          query = query.eq("faculty_id", facultyId);
        }

        const { data, error } = await query
          .order("published_at", { ascending: false })
          .limit(limit);
        if (error) throw new Error(error.message);
        return json({ success: true, items: data ?? [] });
      }

      case "university.faculty_list": {
        const result = await getUniversityFacultyList(admin);
        return json({ success: true, ...result });
      }

      case "university.department_list": {
        const result = await getUniversityDepartmentList(admin, body);
        return json({ success: true, ...result });
      }

      case "university.provider_by_department": {
        const result = await getUniversityProviderByDepartment(admin, body);
        return json({ success: true, ...result });
      }

      case "university.content_by_faculty": {
        const result = await getUniversityContentByFaculty(admin, body);
        return json({ success: true, ...result });
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

      case "university.rlhf_signal": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const providerId = asString(body.provider_id);
        if (!providerId) return json({ error: "provider_id required" }, 400);

        const rating = Math.min(
          Math.max(Math.round(asNumber(body.rating, 3)), 1),
          5,
        );
        const helpful = body.helpful === true;
        const qualityLabel = rlhfLabel(rating, helpful);
        const row = await addItem(
          admin,
          AI_UNIVERSITY_RLHF_SOURCE,
          userId,
          {
            provider_id: providerId,
            content_id: asString(body.content_id) || `${providerId}-overview`,
            content_title: asString(body.content_title) || providerId,
            rating,
            helpful,
            comment: asString(body.comment),
            quality_label: qualityLabel,
            collection_pattern: "scale_rlhf_preference_signal",
            improvement_use: qualityLabel === "negative"
              ? "regenerate_or_rewrite_lesson"
              : "candidate_training_example",
            captured_at: new Date().toISOString(),
          },
        );

        return json({
          success: true,
          signal: row,
          quality_label: qualityLabel,
        });
      }

      case "university.rlhf_snapshot": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const rows = await listItems(
          admin,
          AI_UNIVERSITY_RLHF_SOURCE,
          userId,
          500,
        ) as Array<{ metadata?: Record<string, unknown> | null }>;
        return json({ success: true, snapshot: buildRlhfSnapshot(rows) });
      }

      // ===== 英語速読カリキュラム =====
      case "english_reading.list_lessons": {
        const level = Math.round(asNumber(body.level, 0));
        let query = admin.from("english_reading_lessons")
          .select(
            "id, lesson_code, level, cefr, title, topic, target_wpm, passage, word_count, questions, source",
          )
          .eq("is_active", true);
        if (level > 0) query = query.eq("level", level);
        const { data, error } = await query
          .order("level", { ascending: true })
          .order("lesson_code", { ascending: true })
          .limit(200);
        if (error) throw new Error(error.message);
        return json({ success: true, lessons: data ?? [] });
      }

      case "english_reading.get_lesson": {
        const code = asString(body.lesson_code);
        const id = asString(body.lesson_id);
        if (!code && !id) {
          return json({ error: "lesson_code or lesson_id required" }, 400);
        }
        let query = admin.from("english_reading_lessons")
          .select(
            "id, lesson_code, level, cefr, title, topic, target_wpm, passage, word_count, questions, source",
          )
          .eq("is_active", true);
        query = id ? query.eq("id", id) : query.eq("lesson_code", code);
        const { data, error } = await query.limit(1).maybeSingle();
        if (error) throw new Error(error.message);
        return json({ success: true, lesson: data ?? null });
      }

      case "english_reading.generate_lesson": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({ error: "GEMINI_API_KEY not configured" }, 503);
        }
        const level = Math.min(
          Math.max(Math.round(asNumber(body.level, 3)), 1),
          6,
        );
        // ユーザー入力 topic はプロンプト注入面を絞るため空白正規化 + 80 字上限。
        const topic = asString(body.topic).replace(/\s+/g, " ").slice(0, 80)
          .trim();
        // 濫用 / API コスト対策: 1 ユーザーの当日 AI 生成数に上限を設ける。
        const userPrefix = userId.slice(0, 8);
        const dayStart = new Date();
        dayStart.setUTCHours(0, 0, 0, 0);
        const { count: genToday } = await admin
          .from("english_reading_lessons")
          .select("id", { count: "exact", head: true })
          .eq("source", "ai")
          .ilike("lesson_code", `AI-L%-${userPrefix}-%`)
          .gte("created_at", dayStart.toISOString());
        if ((genToday ?? 0) >= 30) {
          return json(
            { error: "daily AI lesson generation limit reached" },
            429,
          );
        }
        const levelMetaTable: Record<
          number,
          { cefr: string; target: number; words: number }
        > = {
          1: { cefr: "A2", target: 100, words: 90 },
          2: { cefr: "B1", target: 150, words: 120 },
          3: { cefr: "B1+", target: 180, words: 150 },
          4: { cefr: "B2", target: 220, words: 200 },
          5: { cefr: "C1", target: 260, words: 230 },
          6: { cefr: "C2", target: 300, words: 250 },
        };
        const meta = levelMetaTable[level] ??
          { cefr: "B1", target: 150, words: 120 };
        const prompt =
          `You are an expert English reading-fluency teacher for Japanese adult learners. ` +
          `Generate ONE original English reading passage at CEFR level ${meta.cefr}. ` +
          (topic
            ? `Topic: ${topic}. `
            : `Choose an engaging non-fiction topic suitable for adults. `) +
          `Requirements: about ${meta.words} words of natural, coherent prose; ` +
          `do NOT put a title inside the passage body; ` +
          `then exactly 4 multiple-choice comprehension questions in English, ` +
          `each with 4 options and exactly one correct answer, plus a short Japanese explanation. ` +
          `Return STRICT JSON only (no markdown fences) of shape: ` +
          `{"title": string, "topic": string, "passage": string, ` +
          `"questions": [{"q": string, "choices": [string,string,string,string], ` +
          `"answer_index": number, "explanation": string}]}`;

        let raw = "";
        try {
          raw = await callGemini(prompt, geminiKey);
        } catch (e) {
          return json({ error: `generation failed: ${String(e)}` }, 502);
        }
        const parsed = extractJsonObject(raw);
        if (!parsed) {
          return json({ error: "could not parse generated lesson" }, 502);
        }
        const passage = asString(parsed.passage);
        if (!passage) return json({ error: "empty passage generated" }, 502);

        const rawQuestions = Array.isArray(parsed.questions)
          ? parsed.questions
          : [];
        const questions = rawQuestions
          .slice(0, 6)
          .map((q) => {
            const obj = (q ?? {}) as Record<string, unknown>;
            const choices = Array.isArray(obj.choices)
              ? obj.choices
                .map((c) => asString(c))
                .filter((c) => c.length > 0)
                .slice(0, 6)
              : [];
            const maxIdx = Math.max(0, choices.length - 1);
            return {
              q: asString(obj.q),
              choices,
              answer_index: Math.min(
                Math.max(Math.round(asNumber(obj.answer_index, 0)), 0),
                maxIdx,
              ),
              explanation: asString(obj.explanation),
            };
          })
          .filter((q) => q.q.length > 0 && q.choices.length >= 2);

        // 内容理解クイズが 0 問の劣化教材は保存せず拒否する。
        if (questions.length === 0) {
          return json(
            { error: "no valid comprehension questions generated" },
            502,
          );
        }

        const wordCount = passage.trim().split(/\s+/).filter((w) =>
          w.length > 0
        ).length;
        const lessonCode = `AI-L${level}-${userId.slice(0, 8)}-${Date.now()}`;
        const title = asString(parsed.title) || `AI Lesson (Level ${level})`;
        const topicOut = asString(parsed.topic) || topic || "general";

        const { data, error } = await admin
          .from("english_reading_lessons")
          .insert({
            lesson_code: lessonCode,
            level,
            cefr: meta.cefr,
            title,
            topic: topicOut,
            target_wpm: meta.target,
            passage,
            word_count: wordCount,
            questions,
            source: "ai",
          })
          .select(
            "id, lesson_code, level, cefr, title, topic, target_wpm, passage, word_count, questions, source",
          )
          .single();
        if (error) throw new Error(error.message);
        return json({ success: true, lesson: data });
      }

      case "english_reading.submit_attempt": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const lessonCode = asString(body.lesson_code);
        const lessonId = asString(body.lesson_id);
        const level = Math.min(
          Math.max(Math.round(asNumber(body.level, 1)), 1),
          6,
        );
        const mode = asString(body.mode) === "rsvp" ? "rsvp" : "measure";
        const wordCount = Math.max(0, Math.round(asNumber(body.word_count, 0)));
        const elapsedMs = Math.max(0, Math.round(asNumber(body.elapsed_ms, 0)));
        const correct = Math.max(
          0,
          Math.round(asNumber(body.comprehension_correct, 0)),
        );
        const total = Math.max(
          0,
          Math.round(asNumber(body.comprehension_total, 0)),
        );

        // WPM = words / minutes (ゼロ除算ガード)。実効 WPM = WPM × 理解率。
        const minutes = elapsedMs / 60000;
        const wpm = wordCount > 0 && minutes > 0
          ? Math.round(wordCount / minutes)
          : 0;
        const ratio = total > 0 ? Math.min(Math.max(correct / total, 0), 1) : 1;
        const effectiveWpm = wpm > 0 ? Math.round(wpm * ratio) : 0;

        const insertRow: Record<string, unknown> = {
          user_id: userId,
          lesson_code: lessonCode || null,
          level,
          mode,
          word_count: wordCount,
          elapsed_ms: elapsedMs,
          wpm,
          comprehension_correct: correct,
          comprehension_total: total,
          effective_wpm: effectiveWpm,
        };
        if (lessonId) insertRow.lesson_id = lessonId;

        const { data, error } = await admin
          .from("english_reading_attempts")
          .insert(insertRow)
          .select("*")
          .single();
        if (error) throw new Error(error.message);

        // 読書も AI大学 学習ストリークへ算入 (best-effort)。
        try {
          await admin.rpc("update_ai_university_streak", { p_user_id: userId });
        } catch (streakErr) {
          // 試行記録は保存済み。streak 更新失敗は致命的でないが観測可能にする。
          console.warn(
            "english_reading.submit_attempt streak update failed",
            String(streakErr),
          );
        }

        return json({
          success: true,
          attempt: data,
          wpm,
          effective_wpm: effectiveWpm,
        });
      }

      case "english_reading.ability": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const { data, error } = await admin
          .from("english_reading_attempts")
          .select(
            "id, lesson_code, level, mode, word_count, elapsed_ms, wpm, comprehension_correct, comprehension_total, effective_wpm, created_at",
          )
          .eq("user_id", userId)
          .order("created_at", { ascending: false })
          .limit(200);
        if (error) throw new Error(error.message);
        return json({ success: true, attempts: data ?? [] });
      }

      case "user_data.finetune_readiness": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const [rlhfRows, judgmentRows] = await Promise.all([
          listItems(admin, AI_UNIVERSITY_RLHF_SOURCE, userId, 1000),
          listItems(admin, DAILY_JUDGMENT_QUALITY_SOURCE, userId, 500),
        ]) as [
          Array<{ metadata?: Record<string, unknown> | null }>,
          Array<{ metadata?: Record<string, unknown> | null }>,
        ];
        return json({
          success: true,
          snapshot: buildUserDataFineTuneReadiness(rlhfRows, judgmentRows),
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

      case "quiz.fsrs_stats": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const provider = String(body.provider ?? "");
        const todayIso = new Date().toISOString();
        const baseQ = admin
          .from("ai_university_fsrs_cards")
          .select("stability, reps, lapses, state, due_date")
          .eq("user_id", userId);
        const q = provider ? baseQ.eq("provider", provider) : baseQ;
        const { data, error } = await q;
        if (error) return json({ error: error.message }, 500);
        const cards = (data ?? []) as Array<Record<string, unknown>>;
        const totalCards = cards.length;
        const dueToday = cards.filter((c) =>
          String(c.due_date ?? "") <= todayIso
        ).length;
        const totalReps = cards.reduce((s, c) => s + (Number(c.reps) || 0), 0);
        const totalLapses = cards.reduce(
          (s, c) => s + (Number(c.lapses) || 0),
          0,
        );
        const avgStability = totalCards > 0
          ? cards.reduce((s, c) => s + (Number(c.stability) || 1), 0) /
            totalCards
          : 0;
        const retentionRate = totalReps > 0
          ? Math.round((1 - totalLapses / totalReps) * 100)
          : null;
        return json({
          success: true,
          provider: provider || "all",
          total_cards: totalCards,
          due_today: dueToday,
          total_reviews: totalReps,
          avg_stability: Math.round(avgStability * 10) / 10,
          retention_rate: retentionRate,
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
        const claudeResp = await fetchWithProviderTimeout(
          "https://api.anthropic.com/v1/messages",
          {
            method: "POST",
            headers: {
              "x-api-key": claudeKey,
              "anthropic-version": "2023-06-01",
              "content-type": "application/json",
            },
            body: JSON.stringify({
              // Master Brain 提案 #2 (Win版#132 part 29 / 2026-04-26):
              // 高精度合成は claude-opus-4-7 にアップグレード (旧: sonnet-4-6)
              model: "claude-opus-4-7",
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
        const groqResp = await fetchWithProviderTimeout(
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
        const claudeResp2 = await fetchWithProviderTimeout(
          "https://api.anthropic.com/v1/messages",
          {
            method: "POST",
            headers: {
              "x-api-key": claudeKey,
              "anthropic-version": "2023-06-01",
              "content-type": "application/json",
            },
            body: JSON.stringify({
              // Master Brain 提案 #2 (Win版#132 part 29 / 2026-04-26):
              // 高精度合成は claude-opus-4-7 にアップグレード (旧: sonnet-4-6)
              model: "claude-opus-4-7",
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
      case "asset_liability.verify_annual_rate_evidence": {
        const parsedImage = parseInlineImage(body);
        if (parsedImage.error) {
          return json({ error: parsedImage.error }, parsedImage.status ?? 400);
        }
        const image = parsedImage.image;
        if (!image) {
          return json({ error: "imageBase64 required" }, 400);
        }
        const accountName = asString(body.accountName) || "unknown account";
        const submittedAnnualRate = asNumber(
          body.submittedAnnualRate,
          Number.NaN,
        );
        if (!Number.isFinite(submittedAnnualRate) || submittedAnnualRate < 0) {
          return json({ error: "submittedAnnualRate required" }, 400);
        }
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        if (shouldBlockExternalProviderCall(offlinePolicy)) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action: "asset_liability.verify_annual_rate_evidence",
              provider: "google",
            }),
            409,
          );
        }
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({
            success: false,
            status: "apiKeyRequired",
            secret_needed: "GEMINI_API_KEY",
            message: "Supabase Secret GEMINI_API_KEY is required.",
          });
        }

        const submittedPercent = submittedAnnualRate * 100;
        const prompt = [
          "You are verifying annual interest rate evidence for a personal finance board.",
          "Inspect the attached screenshot. It must visibly contain the annual interest rate/APR for the named account.",
          `Account name: ${accountName}`,
          `User-entered annual rate: ${submittedPercent.toFixed(4)}%`,
          "Return JSON only with keys: verified, detected_annual_rate_percent, confidence, summary, reason.",
          "Set verified=true only when the screenshot clearly shows the same annual rate for this account. Do not infer missing rates.",
          "If the screenshot is unreadable, unrelated, or the rate differs, set verified=false.",
        ].join("\n");
        const raw = await callGemini(prompt, geminiKey, image);
        let parsed: Record<string, unknown> = {};
        try {
          parsed = JSON.parse(stripMarkdownCodeFence(raw)) as Record<
            string,
            unknown
          >;
        } catch {
          parsed = { summary: raw, verified: false };
        }
        const detectedPercent = asNumber(
          parsed.detected_annual_rate_percent,
          Number.NaN,
        );
        const detectedAnnualRate = Number.isFinite(detectedPercent)
          ? detectedPercent / 100
          : null;
        const rateMatches = detectedAnnualRate !== null &&
          Math.abs(detectedAnnualRate - submittedAnnualRate) <= 0.001;
        const verified = parsed.verified === true && rateMatches;
        const summary = asString(parsed.summary) ||
          asString(parsed.reason) ||
          (verified
            ? "Annual rate evidence matches the entered value."
            : "Annual rate evidence could not be verified.");
        return json({
          success: true,
          provider: "google",
          status: verified ? "verified" : "needs_review",
          verified,
          detected_annual_rate: detectedAnnualRate,
          detected_annual_rate_percent: detectedPercent,
          summary,
          confidence: asNumber(parsed.confidence, 0),
        });
      }

      case "asset_subscription.analyze_statement": {
        const parsedImage = parseInlineImage(body);
        if (parsedImage.error) {
          return json({ error: parsedImage.error }, parsedImage.status ?? 400);
        }
        const image = parsedImage.image;
        if (!image) {
          return json({ error: "imageBase64 required" }, 400);
        }
        if (
          !["image/png", "image/jpeg", "image/webp"].includes(image.mimeType)
        ) {
          return json({ error: "PNG, JPEG, or WebP image required" }, 400);
        }
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        if (shouldBlockExternalProviderCall(offlinePolicy)) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action: "asset_subscription.analyze_statement",
              provider: "google",
            }),
            409,
          );
        }
        const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
        if (!geminiKey) {
          return json({
            success: false,
            status: "apiKeyRequired",
            secret_needed: "GEMINI_API_KEY",
            message: "Supabase Secret GEMINI_API_KEY is required.",
          });
        }
        const raw = await callGemini(
          buildSubscriptionStatementPrompt(),
          geminiKey,
          image,
        );
        const candidates = parseSubscriptionStatementResponse(raw);
        return json({
          success: true,
          provider: "google",
          model: "gemini-2.5-flash",
          candidates,
          candidate_count: candidates.length,
          image_persisted: false,
        });
      }

      case "payslip.parse":
      case "parse-payslip": {
        if (!isPayslipIngestionAction(action)) {
          return json({ error: "Invalid payslip action" }, 400);
        }
        const result = await handleParsePayslipAction({
          db: admin as unknown as PayslipDb,
          storage: admin.storage as unknown as PayslipStorage,
          body,
          userId: userId ?? "",
          invokeProvider: async (request) => {
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
                isRetriable: false,
              };
            }
            return await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
              request.inlineFiles,
            );
          },
        });
        return json({ success: true, ...result });
      }

      case "expense.classify":
      case "classify-expense": {
        const result = await handleClassifyExpenseAction({
          db: admin as unknown as ExpenseAiDb,
          body,
          userId: userId ?? "",
          invokeProvider: async (request) => {
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
                isRetriable: false,
              };
            }
            return await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
            );
          },
        });
        return json({ success: true, ...result });
      }

      case "expense.weekly_coaching.generate": {
        const result = await handleWeeklySpendingCoachingAction({
          db: admin as unknown as ExpenseAiDb,
          body,
          userId: userId ?? "",
          invokeProvider: async (request) => {
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
                isRetriable: false,
              };
            }
            return await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
            );
          },
        });
        return json({ success: true, ...result });
      }

      case "asset.disposable_balance.compute":
      case "compute-disposable-balance": {
        const result = await handleDisposableBalanceAction({
          db: admin as unknown as DisposableBalanceDb,
          body,
          userId: userId ?? "",
          invokeProvider: async (request) => {
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
                isRetriable: false,
              };
            }
            return await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
            );
          },
        });
        return json({ success: true, ...result });
      }

      case "asset.anomaly.scan_all": {
        // daily-anomaly-scan.yml (cron) 専用: schedule-hub の service_role
        // レベルと同じく Bearer === SERVICE_ROLE_KEY の生比較で認可する
        // (service role JWT は auth.getUser() で user にならないため
        //  authRequired リストでは扱えない)。
        const bearer = (req.headers.get("Authorization") ?? "")
          .replace(/^Bearer\s+/i, "");
        if (!SERVICE_ROLE_KEY || bearer !== SERVICE_ROLE_KEY) {
          return json({ error: "Unauthorized" }, 401);
        }
        const result = await handleScanAllAction({
          db: admin as unknown as AnomalyDetectionDb,
          body,
        });
        return json({ success: true, ...result });
      }

      case "asset.anomaly.detect":
      case "detect-anomalies": {
        const explanationEnabled =
          (Deno.env.get("ANOMALY_AI_EXPLANATION_ENABLED") ?? "")
            .toLowerCase() === "true";
        const result = await handleDetectAnomaliesAction({
          db: admin as unknown as AnomalyDetectionDb,
          body,
          userId: userId ?? "",
          explanationEnabled,
          invokeProvider: async (request) => {
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
              };
            }
            return await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
            );
          },
        });
        return json({ success: true, ...result });
      }

      case "asset.market_price.fetch":
      case "asset.investment.market_price.fetch":
      case "ai_hub.fetch_market_price": {
        const result = await handleMarketPriceAction({
          db: admin as unknown as MarketPriceDb,
          body,
          userId: userId ?? "",
          liveFetchEnabled: isMarketPriceLiveFetchEnabled(body),
        });
        return json({ success: true, ...result });
      }

      case "department_finance_summary":
      case "ai_hub.department_finance_summary": {
        const result = await handleDepartmentFinanceSummaryAction({
          db: admin as unknown as DepartmentFinanceSummaryDb,
          body,
          userId: userId ?? "",
        });
        return json({ success: true, ...result });
      }

      case "asset.monthly_report.generate":
      case "asset_liability.monthly_report.generate": {
        const aiSummaryEnabled = isMonthlyAssetReportAiSummaryEnabled(body);
        const requestedProvider = normalizeMonthlyAssetReportProvider(
          body.provider_preference ?? body.provider,
        );
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        if (
          aiSummaryEnabled && shouldBlockExternalProviderCall(offlinePolicy)
        ) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action,
              provider: requestedProvider,
            }),
            409,
          );
        }
        const traceId = requestTraceId(req, body.trace_id);
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;
        const providerChoiceReason =
          sanitizeProviderChoiceLogText(body.provider_choice_reason) ??
            "asset monthly report provider preference";
        const routingUseCase =
          sanitizeProviderChoiceLogText(body.routing_use_case, 80) ??
            "asset_monthly_report";
        const result = await handleMonthlyAssetReportAction({
          db: admin as unknown as MonthlyAssetReportDb,
          body,
          userId: userId ?? "",
          aiSummaryEnabled,
          invokeProvider: async (request) => {
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
                isRetriable: false,
              };
            }
            const requestStartedAt = performance.now();
            const providerResult = await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
            );
            try {
              const inputChars = request.messages
                .map((message) =>
                  typeof message.content === "string"
                    ? message.content.length
                    : 0
                )
                .reduce((sum, count) => sum + count, 0);
              const outputChars = providerResult.text?.length ?? 0;
              const estimatedCost = providerResult.ok
                ? calculateApiCost(
                  providerResult.modelUsed ?? request.model ?? request.provider,
                  estimateTokensFromChars(inputChars),
                  estimateTokensFromChars(outputChars),
                )
                : 0;
              await admin.from("ai_hub_chat_logs").insert({
                provider: request.provider,
                success: providerResult.ok,
                estimated_cost_usd: estimatedCost,
                model: providerResult.modelUsed ?? request.model ?? null,
                latency_ms: Math.round(performance.now() - requestStartedAt),
                trace_id: traceId,
                session_id: sessionId,
                input_chars: inputChars,
                output_chars: outputChars,
                action,
                status_code: providerResult.ok ? 200 : 502,
                error_message: providerResult.ok
                  ? null
                  : providerResult.error ?? "monthly report provider failed",
                provider_choice_reason: providerChoiceReason,
                routing_use_case: routingUseCase,
              });
              if (providerResult.ok && estimatedCost > 0) {
                await recordSpend("ef", "ai-hub", estimatedCost);
              }
            } catch { /* ignore observability failures */ }
            return providerResult;
          },
        });
        return json({ success: true, ...result });
      }

      case "asset.chat":
      case "ai_hub.asset_chat": {
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        const requestedProvider = String(body.provider ?? "google").trim() ||
          "google";
        if (shouldBlockExternalProviderCall(offlinePolicy)) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action,
              provider: requestedProvider,
            }),
            409,
          );
        }
        const authorization = req.headers.get("Authorization") ?? "";
        const userScopedClient = createClient(
          SUPABASE_URL,
          SUPABASE_ANON_KEY,
          { global: { headers: { Authorization: authorization } } },
        );
        const traceId = requestTraceId(req, body.trace_id);
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;
        const providerChoiceReason =
          sanitizeProviderChoiceLogText(body.provider_choice_reason) ??
            "asset chat provider preference";
        const routingUseCase =
          sanitizeProviderChoiceLogText(body.routing_use_case, 80) ??
            "asset_chat";
        const result = await handleAssetChatAction({
          store: createSupabaseAssetChatStore(userScopedClient),
          body,
          userId: userId ?? "",
          invokeProvider: async (request) => {
            const usage = await checkAndRecordAiUsage(
              supabaseUsageStore(admin),
              userId ?? "",
            );
            if (!usage.allowed) {
              return {
                ok: false,
                error: "usageLimitReached: free_limit_reached",
                httpStatus: 402,
                isRetriable: false,
              };
            }
            const budget = await checkBudget("ef", "ai-hub");
            if (!budget.ok) {
              return {
                ok: false,
                error: `budgetExceeded:${budget.exceeded_scope ?? "unknown"}`,
                httpStatus: 429,
                isRetriable: false,
              };
            }
            const startedAt = performance.now();
            const providerResult = await callSingleProvider(
              request.provider,
              request.messages,
              request.model,
              undefined,
              {
                maxTokens: normalizeMaxTokens(
                  body.max_tokens ?? body.maxTokens,
                ),
              },
            );
            const inputChars = request.messages.reduce(
              (sum, item) => sum + item.content.length,
              0,
            );
            const outputChars = providerResult.text?.length ?? 0;
            const estimatedCost = providerResult.ok
              ? calculateApiCost(
                providerResult.modelUsed ?? request.model ?? request.provider,
                estimateTokensFromChars(inputChars),
                estimateTokensFromChars(outputChars),
              )
              : 0;
            try {
              await admin.from("ai_hub_chat_logs").insert({
                provider: request.provider,
                tier: providerTier(request.provider) ?? "direct",
                success: providerResult.ok,
                estimated_cost_usd: estimatedCost,
                model: providerResult.modelUsed ?? request.model ?? null,
                latency_ms: Math.round(performance.now() - startedAt),
                trace_id: traceId,
                session_id: sessionId,
                input_chars: inputChars,
                output_chars: outputChars,
                error_message: providerResult.ok
                  ? null
                  : providerResult.error ?? "asset chat provider failed",
                action: "ai_hub.asset_chat",
                status_code: providerResult.ok ? 200 : 502,
                provider_choice_reason: providerChoiceReason,
                routing_use_case: routingUseCase,
              });
              if (providerResult.ok && estimatedCost > 0) {
                await recordSpend("ef", "ai-hub", estimatedCost);
              }
            } catch {
              // Observability must not make a successful chat fail.
            }
            return { ...providerResult, estimatedCostUsd: estimatedCost };
          },
        });
        return json({ success: true, ...result });
      }

      case "provider.chat": {
        // 汎用プロバイダー呼び出し (AI大学150社の実装済みAIに統一インターフェースで話しかける)
        // 対応: OpenAI互換 8社 (openai/xai/deepseek/groq/sambanova/openrouter/fireworks/together/arcee_ai)
        //       + 独自API 3社 (mistral/perplexity/cohere) + anthropic/google (MAGI互換)
        const providerId = String(body.provider ?? "");
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        const messages = Array.isArray(body.messages) ? body.messages : null;
        const userMsg = String(body.message ?? "");
        if (!providerId) return json({ error: "provider required" }, 400);
        if (!messages && !userMsg) {
          return json({ error: "messages or message required" }, 400);
        }
        if (shouldBlockExternalProviderCall(offlinePolicy)) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action: "provider.chat",
              provider: providerId,
            }),
            409,
          );
        }
        const finalMessages = messages ?? [{ role: "user", content: userMsg }];
        const requestStartedAt = performance.now();
        const traceId = requestTraceId(req, body.trace_id);
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;
        const providerChoiceReason = sanitizeProviderChoiceLogText(
          body.provider_choice_reason,
        );
        const routingUseCase = sanitizeProviderChoiceLogText(
          body.routing_use_case,
          80,
        );
        const requestedMaxTokens = normalizeMaxTokens(
          body.max_tokens ?? body.maxTokens,
        );
        const inputChars = finalMessages
          .map((m) => typeof m.content === "string" ? m.content.length : 0)
          .reduce((a, b) => a + b, 0);

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

        // フリーミアム上限ゲート + 使用量メータリング (#3645 / #3646)
        if (userId) {
          const usage = await checkAndRecordAiUsage(
            supabaseUsageStore(admin),
            userId,
          );
          if (!usage.allowed) {
            return json({
              success: false,
              status: "usageLimitReached",
              code: "free_limit_reached",
              upgrade_required: true,
              used: usage.used,
              limit: usage.limit,
              upgrade_url: "/billing",
              message:
                `無料プランの今月のAI利用上限(${
                  usage.limit ?? 0
                }回)に達しました。` +
                `Pro にアップグレードすると無制限に利用できます。`,
            }, 402);
          }
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
          } else if (
            providerId === "google" || providerId === "google_flash_lite"
          ) {
            authHeaders = {};
            fetchUrl = `${cfg.chatUrl}?key=${apiKey}`;
          }
          const requestedModel = String(body.model ?? cfg.defaultModel);
          const logProviderChat = async (
            params: {
              success: boolean;
              statusCode: number;
              model?: string | null;
              outputChars?: number | null;
              estimatedCostUsd?: number | null;
              errorMessage?: string | null;
            },
          ) => {
            try {
              const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
              await admin.from("ai_hub_chat_logs").insert({
                provider: providerId,
                tier: providerTier(providerId) ?? "direct",
                success: params.success,
                estimated_cost_usd: params.estimatedCostUsd ?? null,
                model: params.model ?? requestedModel,
                latency_ms: Math.round(performance.now() - requestStartedAt),
                trace_id: traceId,
                session_id: sessionId,
                input_chars: inputChars,
                output_chars: params.outputChars ?? null,
                error_message: params.errorMessage ?? null,
                action: "provider.chat",
                status_code: params.statusCode,
                provider_choice_reason: providerChoiceReason,
                routing_use_case: routingUseCase,
              });
            } catch {
              // ignore logging errors
            }
          };
          const resp = await fetchWithProviderTimeout(fetchUrl, {
            method: "POST",
            headers: {
              ...authHeaders,
              "Content-Type": "application/json",
              ...(cfg.extraHeaders ?? {}),
            },
            body: JSON.stringify(
              applyProviderGenerationOptions(
                providerId,
                cfg.buildBody(finalMessages, requestedModel),
                { maxTokens: requestedMaxTokens },
              ),
            ),
          });
          const respText = await resp.text();
          if (!resp.ok) {
            // Free tier / 課金制限検知
            if (isProviderPaymentRequired(resp.status, respText)) {
              await logProviderChat({
                success: false,
                statusCode: resp.status,
                errorMessage: respText.slice(0, 500),
              });
              return json({
                success: false,
                status: "paidPlanRequired",
                provider: providerId,
                message:
                  `${cfg.displayName} はプロバイダー側で課金が必要です。`,
                detail: respText.slice(0, 300),
              });
            }
            await logProviderChat({
              success: false,
              statusCode: resp.status,
              errorMessage: respText.slice(0, 500),
            });
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
            const outputChars = respText.slice(0, 2000).length;
            const estimatedCost = calculateApiCost(
              requestedModel,
              estimateTokensFromChars(inputChars),
              estimateTokensFromChars(outputChars),
            );
            await logProviderChat({
              success: true,
              statusCode: 200,
              model: requestedModel,
              outputChars,
              estimatedCostUsd: estimatedCost,
            });
            await recordSpend("ef", "ai-hub", estimatedCost);
            return json({
              success: true,
              provider: providerId,
              status: "implemented",
              text: respText.slice(0, 2000),
              observability: {
                provider: providerId,
                model: requestedModel,
                estimated_cost_usd: estimatedCost,
                trace_id: traceId,
                session_id: sessionId,
                input_chars: inputChars,
                output_chars: outputChars,
                action: "provider.chat",
                status_code: 200,
                provider_choice_reason: providerChoiceReason,
                routing_use_case: routingUseCase,
              },
            });
          }
          const content = cfg.parseResponse(data);
          const finishReason = providerFinishReason(data);
          const modelUsed = pick(data, "model");
          const outputChars = content.length;
          const usedModel = String(modelUsed ?? requestedModel);
          // 本文が空のレスポンスは成功扱いにしない。reasoning モデルが
          // 推論で予算を使い切ると finish_reason=length かつ本文が空になり、
          // 旧コードは success:true(空文字)で返してフォールバック連鎖を
          // 止め、無駄なコストだけ計上していた。
          const lengthLimited = isProviderOutputLengthLimited(finishReason);
          if (!content.trim() || lengthLimited) {
            const failureStatus = !content.trim()
              ? "emptyOutput"
              : "outputLengthLimited";
            await logProviderChat({
              success: false,
              statusCode: 502,
              model: usedModel,
              outputChars,
              errorMessage: `${failureStatus}: ${finishReason ?? "no-content"}`,
            });
            return json({
              success: false,
              status: failureStatus,
              provider: providerId,
              model: usedModel,
              finish_reason: finishReason,
              message:
                "AI応答が空、または出力上限で途中終了しました。max_tokens を増やすか、別プロバイダーを試してください。",
            }, 502);
          }
          const estimatedCost = calculateApiCost(
            usedModel,
            estimateTokensFromChars(inputChars),
            estimateTokensFromChars(outputChars),
          );
          await logProviderChat({
            success: true,
            statusCode: 200,
            model: usedModel,
            outputChars,
            estimatedCostUsd: estimatedCost,
          });
          await recordSpend("ef", "ai-hub", estimatedCost);
          return json({
            success: true,
            provider: providerId,
            status: "implemented",
            text: content,
            model: usedModel,
            observability: {
              provider: providerId,
              model: usedModel,
              estimated_cost_usd: estimatedCost,
              trace_id: traceId,
              session_id: sessionId,
              input_chars: inputChars,
              output_chars: outputChars,
              action: "provider.chat",
              status_code: 200,
              provider_choice_reason: providerChoiceReason,
              routing_use_case: routingUseCase,
            },
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
        const effortSelection = await selectEffort("provider.chat_auto", body);
        const claudeRoute = routedClaudeModel(effortSelection.effort);
        const internalUsageUserId = isServiceRoleRequest(req)
          ? nullableUuid(body.internal_user_id)
          : null;
        const routingUserId = userId ?? internalUsageUserId;
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        const requestedTier = normalizeProviderTier(body.tier);
        const messages = Array.isArray(body.messages) ? body.messages : null;
        const userMsg = String(body.message ?? "");
        if (!messages && !userMsg) {
          return json({ error: "messages or message required" }, 400);
        }
        if (shouldBlockExternalProviderCall(offlinePolicy)) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action: "provider.chat_auto",
            }),
            409,
          );
        }
        const budget = await checkBudget("ef", "ai-hub");
        if (!budget.ok) {
          return json({
            success: false,
            status: "budgetExceeded",
            remaining_usd: budget.remaining_usd,
            exceeded_scope: budget.exceeded_scope,
            exceeded_scope_id: budget.exceeded_scope_id,
          }, 429);
        }

        // フリーミアム上限ゲート + 使用量メータリング (#3645 / #3646)
        if (routingUserId) {
          const usage = await checkAndRecordAiUsage(
            supabaseUsageStore(admin),
            routingUserId,
          );
          if (!usage.allowed) {
            return json({
              success: false,
              status: "usageLimitReached",
              code: "free_limit_reached",
              upgrade_required: true,
              used: usage.used,
              limit: usage.limit,
              upgrade_url: "/billing",
              message:
                `無料プランの今月のAI利用上限(${
                  usage.limit ?? 0
                }回)に達しました。` +
                `Pro にアップグレードすると無制限に利用できます。`,
            }, 402);
          }
        }
        const finalMessages = messages ?? [{ role: "user", content: userMsg }];
        const routedTier = requestedTier ??
          effortToTier(effortSelection.effort);
        const startTierIndex = TIER_ORDER.indexOf(routedTier);
        if (startTierIndex === -1) return json({ error: "invalid tier" }, 400);

        // Win版#131 part 4: Observability — trace_id / session_id / latency 計測
        const requestStartedAt = performance.now();
        const traceId = requestTraceId(req, body.trace_id);
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;
        const providerChoiceReason = sanitizeProviderChoiceLogText(
          body.provider_choice_reason,
        );
        const routingUseCase = sanitizeProviderChoiceLogText(
          body.routing_use_case,
          80,
        );
        const requestedMaxTokens = normalizeMaxTokens(
          body.max_tokens ?? body.maxTokens,
        );

        let resultText: string | undefined;
        let usedProvider: string | undefined;
        let usedTier: Tier | undefined;
        let usedModel: string | undefined;
        let usedInputTokens: number | undefined;
        let usedOutputTokens: number | undefined;

        // リクエスト全体の時間予算。実障害(2026-07-06): 予算なしで遅延プロバイダを
        // 順に待つと edge の wall-clock を超え、gateway 502 でクライアントに
        // 66 秒待たせた。予算内で per-call 上限を配分し、残りが尽きたら即返す。
        const chatBudgetMs = chatTotalBudgetMs();
        let budgetExhausted = false;
        // どのプロバイダが予算を焼いたかを可視化する試行トレイル。全滅時の
        // error_message へ付加し、Supabase Logs だけでチェーン健全性を診断
        // できるようにする(従来は "budget exhausted" の一言で真犯人が不明)。
        const attemptTrail: string[] = [];
        const manualPreference = await loadManualRoutingPreference(
          routingUserId,
          routingUseCase ?? body.task ?? body.task_type ?? body.action_key,
        );
        if (manualPreference) {
          const remainingMs = chatBudgetMs -
            (performance.now() - requestStartedAt);
          if (remainingMs >= 2_000) {
            const attemptStartedAt = performance.now();
            const result = await callSingleProvider(
              manualPreference.provider,
              finalMessages,
              manualPreference.model ??
                (manualPreference.provider === "anthropic"
                  ? claudeRoute.model
                  : undefined),
              undefined,
              {
                maxTokens: requestedMaxTokens,
                timeoutMs: Math.min(
                  providerFetchTimeoutMs(),
                  chatPerCallTimeoutMs(),
                  remainingMs,
                ),
              },
            );
            if (result.ok && result.text) {
              resultText = result.text;
              usedProvider = manualPreference.provider;
              usedTier = providerTier(manualPreference.provider) ?? routedTier;
              usedModel = result.modelUsed;
              usedInputTokens = result.inputTokens;
              usedOutputTokens = result.outputTokens;
            } else {
              const attemptMs = Math.round(
                performance.now() - attemptStartedAt,
              );
              const attemptError = (result.error ?? "unknown").slice(0, 80);
              attemptTrail.push(
                `manual:${manualPreference.provider}:${attemptMs}ms ${attemptError}`,
              );
            }
          } else {
            budgetExhausted = true;
            attemptTrail.push(
              `budget-stop before manual:${manualPreference.provider}`,
            );
          }
        }
        if (!resultText) {
          outerLoop:
          for (let ti = startTierIndex; ti < TIER_ORDER.length; ti++) {
            const tier = TIER_ORDER[ti];
            const providers = TIER_PROVIDERS[tier].filter((p) =>
              p in PROVIDER_CONFIGS
            );
            for (const pid of providers) {
              const remainingMs = chatBudgetMs -
                (performance.now() - requestStartedAt);
              if (remainingMs < 2_000) {
                budgetExhausted = true;
                attemptTrail.push(`budget-stop before ${pid}`);
                break outerLoop;
              }
              const attemptStartedAt = performance.now();
              const result = await callSingleProvider(
                pid,
                finalMessages,
                pid === "anthropic" ? claudeRoute.model : undefined,
                undefined,
                {
                  maxTokens: requestedMaxTokens,
                  timeoutMs: Math.min(
                    providerFetchTimeoutMs(),
                    chatPerCallTimeoutMs(),
                    remainingMs,
                  ),
                },
              );
              if (result.ok && result.text) {
                resultText = result.text;
                usedProvider = pid;
                usedTier = tier;
                usedModel = result.modelUsed;
                usedInputTokens = result.inputTokens;
                usedOutputTokens = result.outputTokens;
                break outerLoop;
              }
              const attemptMs = Math.round(
                performance.now() - attemptStartedAt,
              );
              const attemptError = (result.error ?? "unknown").slice(0, 80);
              attemptTrail.push(`${pid}:${attemptMs}ms ${attemptError}`);
              console.warn(
                `[chat_auto] provider failed: ${pid} tier=${tier} ${attemptMs}ms ${attemptError}`,
              );
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
              // 予算切れと全プロバイダ失敗を区別し、per-provider の試行
              // トレイルで真犯人(遅延/死亡プロバイダ)まで特定可能に。
              error_message: ((budgetExhausted
                ? "budget exhausted"
                : "all tiers exhausted") +
                (attemptTrail.length > 0
                  ? ` | ${attemptTrail.join("; ")}`
                  : "")).slice(0, 500),
              action: "provider.chat_auto",
              status_code: 503,
              routing_effort: effortSelection.effort,
              routing_source: effortSelection.source,
              provider_choice_reason: providerChoiceReason,
              routing_use_case: routingUseCase,
            });
          } catch { /* ignore */ }
          // 503 = ハンドリング済みの exhaustion (runtime kill の生 502 と区別)。
          // traceId を返しクライアント側から attempt 単位で相関可能にする。
          return json({
            success: false,
            status: "allProvidersFailed",
            message: budgetExhausted
              ? "時間予算内にプロバイダー応答が得られませんでした"
              : "すべての Tier のプロバイダーが失敗しました",
            traceId: traceId ?? null,
          }, 503);
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
          const inputTokens = usedInputTokens ??
            estimateTokensFromChars(inputChars);
          const outputTokens = usedOutputTokens ??
            estimateTokensFromChars(outputChars);
          const estimatedCost = calculateApiCost(
            usedModel ?? usedProvider,
            inputTokens,
            outputTokens,
          );
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
            input_tokens: inputTokens,
            output_tokens: outputTokens,
            action: "provider.chat_auto",
            status_code: 200,
            routing_effort: effortSelection.effort,
            routing_source: effortSelection.source,
            provider_choice_reason: providerChoiceReason,
            routing_use_case: routingUseCase,
          });
          await recordSpend("ef", "ai-hub", estimatedCost);
        } catch { /* ignore logging errors */ }

        return json({
          success: true,
          provider: usedProvider,
          tier: usedTier,
          model: usedModel ?? PROVIDER_CONFIGS[usedProvider]?.defaultModel,
          effort: effortSelection.effort,
          effort_source: effortSelection.source,
          claude_route: usedProvider === "anthropic" ? claudeRoute : null,
          status: "implemented",
          text: resultText,
          provider_choice_reason: providerChoiceReason,
          routing_use_case: routingUseCase,
        });
      }

      case "edge_llm.invoke": {
        const effortSelection = await selectEffort("edge_llm.invoke", body);
        const claudeRoute = routedClaudeModel(effortSelection.effort);
        const offlinePolicy = parseOfflineSecureModePolicy(body);
        const requestedTier = normalizeProviderTier(body.tier);
        const providerId = asString(body.provider) || undefined;
        const systemPrompt = asString(body.system_prompt);
        const userPrompt = asString(body.user_prompt) ||
          asString(body.prompt) ||
          asString(body.message);
        if (!userPrompt) {
          return json({ error: "user_prompt required" }, 400);
        }
        if (shouldBlockExternalProviderCall(offlinePolicy)) {
          return json(
            buildOfflineBlockedResponseBody(offlinePolicy, {
              action: "edge_llm.invoke",
              provider: providerId,
            }),
            409,
          );
        }
        const budget = await checkBudget("ef", "ai-hub");
        if (!budget.ok) {
          return json({
            success: false,
            status: "budgetExceeded",
            remaining_usd: budget.remaining_usd,
            exceeded_scope: budget.exceeded_scope,
            exceeded_scope_id: budget.exceeded_scope_id,
          }, 429);
        }

        const requestedResponseFormat = asString(body.response_format);
        const responseFormat = requestedResponseFormat === "json"
          ? "json"
          : requestedResponseFormat === "markdown"
          ? "markdown"
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
            : responseFormat === "markdown"
            ? "Respond in concise Japanese Markdown. Put code snippets in fenced code blocks and include the language tag."
            : "Respond in concise Japanese plain text.",
        );
        const finalMessages = [];
        // Keep the stable character/application prefix before the request-time
        // UTC context so prompt caches can still reuse the longest prefix.
        const composedSystemPrompt = buildAiSystemPrompt({
          applicationInstructions: systemPrompt,
          outputFormat: responseFormat === "json"
            ? "json"
            : responseFormat === "markdown"
            ? "markdown"
            : "plain_text",
        });
        finalMessages.push({
          role: "system",
          content: composedSystemPrompt,
        });
        finalMessages.push({
          role: "user",
          content: userContentParts.join("\n"),
        });

        const requestStartedAt = performance.now();
        const traceId = requestTraceId(req, body.trace_id);
        const sessionId = body.session_id != null
          ? String(body.session_id)
          : null;
        const explicitModel = asString(body.model) || undefined;
        const routingUseCase = sanitizeProviderChoiceLogText(
          body.routing_use_case ?? body.task ?? body.task_type,
          80,
        );

        let resultText: string | undefined;
        let usedProvider: string | undefined;
        let usedTier: Tier | undefined;
        let usedModel: string | undefined;
        let usedInputTokens: number | undefined;
        let usedOutputTokens: number | undefined;
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
            explicitModel ??
              (providerId === "anthropic" ? claudeRoute.model : undefined),
          );
          if (result.ok && result.text) {
            resultText = result.text;
            usedProvider = providerId;
            usedTier = providerTier(providerId) ?? requestedTier ??
              "performance";
            usedModel = result.modelUsed;
            usedInputTokens = result.inputTokens;
            usedOutputTokens = result.outputTokens;
          } else if (result.isRetriable) {
            // Quota/rate-limit: try fallback chain (anthropic → google → openai)
            const fallbackChain = ["anthropic", "google", "openai"].filter(
              (p) => p !== providerId && p in PROVIDER_CONFIGS,
            );
            for (const fbPid of fallbackChain) {
              const fbResult = await callSingleProvider(
                fbPid,
                finalMessages,
                fbPid === "anthropic" ? claudeRoute.model : undefined,
              );
              if (fbResult.ok && fbResult.text) {
                console.warn(
                  `[ai-hub] quota fallback: ${providerId} → ${fbPid}`,
                );
                resultText = fbResult.text;
                usedProvider = fbPid;
                usedTier = providerTier(fbPid) ?? "performance";
                usedModel = fbResult.modelUsed;
                usedInputTokens = fbResult.inputTokens;
                usedOutputTokens = fbResult.outputTokens;
                break;
              }
            }
            if (!resultText) {
              failureDetail = `${
                result.error ?? "quota exceeded"
              } (all fallbacks failed)`;
            }
          } else {
            failureDetail = result.error ?? "provider failed";
          }
        } else {
          const routedTier = requestedTier ??
            effortToTier(effortSelection.effort);
          const startTierIndex = TIER_ORDER.indexOf(routedTier);
          if (startTierIndex === -1) {
            return json({ error: "invalid tier" }, 400);
          }

          const manualPreference = await loadManualRoutingPreference(
            userId,
            routingUseCase ?? body.task ?? body.task_type ?? body.action_key,
          );
          if (manualPreference) {
            const result = await callSingleProvider(
              manualPreference.provider,
              finalMessages,
              manualPreference.model ??
                (manualPreference.provider === "anthropic"
                  ? claudeRoute.model
                  : undefined),
            );
            if (result.ok && result.text) {
              resultText = result.text;
              usedProvider = manualPreference.provider;
              usedTier = providerTier(manualPreference.provider) ?? routedTier;
              usedModel = result.modelUsed;
              usedInputTokens = result.inputTokens;
              usedOutputTokens = result.outputTokens;
            } else {
              failureDetail = `manual preference failed: ${
                result.error ?? manualPreference.provider
              }`;
            }
          }

          if (!resultText) {
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
                  explicitModel ??
                    (pid === "anthropic" ? claudeRoute.model : undefined),
                );
                if (result.ok && result.text) {
                  resultText = result.text;
                  usedProvider = pid;
                  usedTier = tier;
                  usedModel = result.modelUsed;
                  usedInputTokens = result.inputTokens;
                  usedOutputTokens = result.outputTokens;
                  break outerLoop;
                }
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
              routing_effort: effortSelection.effort,
              routing_source: effortSelection.source,
              routing_use_case: routingUseCase,
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
        const inputTokens = usedInputTokens ??
          estimateTokensFromChars(inputChars);
        const outputTokens = usedOutputTokens ??
          estimateTokensFromChars(outputChars);
        const estimatedCost = calculateApiCost(
          usedModel ?? usedProvider,
          inputTokens,
          outputTokens,
        );
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
            input_tokens: inputTokens,
            output_tokens: outputTokens,
            action: "edge_llm.invoke",
            status_code: 200,
            routing_effort: effortSelection.effort,
            routing_source: effortSelection.source,
            routing_use_case: routingUseCase,
          });
          await recordSpend("ef", "ai-hub", estimatedCost);
        } catch {
          // ignore logging errors
        }

        return json({
          success: true,
          status: "implemented",
          provider: usedProvider,
          tier: usedTier,
          model: usedModel ?? PROVIDER_CONFIGS[usedProvider]?.defaultModel,
          effort: effortSelection.effort,
          effort_source: effortSelection.source,
          claude_route: usedProvider === "anthropic" ? claudeRoute : null,
          text: resultText,
          response_format: responseFormat,
          parsed_json: parsedJson,
          parse_error: parseError,
          observability: {
            provider: usedProvider,
            model: usedModel ?? PROVIDER_CONFIGS[usedProvider]?.defaultModel,
            latency_ms: latencyMs,
            estimated_cost_usd: estimatedCost,
            effort: effortSelection.effort,
            trace_id: traceId,
            session_id: sessionId,
            input_chars: inputChars,
            output_chars: outputChars,
            action: "edge_llm.invoke",
            status_code: 200,
            routing_use_case: routingUseCase,
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

      case "voice.cartesia_session.start": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const cartesiaKey = Deno.env.get("CARTESIA_API_KEY") ?? "";
        const voiceId = Deno.env.get("CARTESIA_VOICE_ID") ?? "";
        if (!cartesiaKey || !voiceId) {
          return json({
            success: false,
            available: false,
            reason: !cartesiaKey
              ? "CARTESIA_API_KEY not configured"
              : "CARTESIA_VOICE_ID not configured",
          });
        }

        const issuedSince = new Date();
        issuedSince.setUTCHours(0, 0, 0, 0);
        const { count: issuedToday, error: countError } = await admin
          .from("hub_data")
          .select("id", { count: "exact", head: true })
          .eq("source", "cartesia_voice_token_issuance")
          .filter("metadata->>user_id", "eq", userId)
          .gte("created_at", issuedSince.toISOString());
        if (countError) {
          return json({ error: countError.message }, 500);
        }
        if ((issuedToday ?? 0) >= 12) {
          return json({
            success: false,
            available: false,
            reason: "Daily Cartesia voice session limit reached",
          }, 429);
        }

        const apiVersion = "2026-03-01";
        const maxSessionSeconds = 300;
        const tokenResponse = await fetchWithProviderTimeout(
          "https://api.cartesia.ai/access-token",
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${cartesiaKey}`,
              "Cartesia-Version": apiVersion,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              grants: { tts: true },
              expires_in: maxSessionSeconds + 30,
            }),
          },
        );
        if (!tokenResponse.ok) {
          const providerError = (await tokenResponse.text()).slice(0, 500);
          return json({
            success: false,
            available: false,
            reason:
              `Cartesia access token failed (${tokenResponse.status}): ${providerError}`,
          }, 502);
        }
        const tokenPayload = await tokenResponse.json() as {
          token?: string;
        };
        const accessToken = String(tokenPayload.token ?? "");
        if (!accessToken) {
          return json({
            success: false,
            available: false,
            reason: "Cartesia access token response was empty",
          }, 502);
        }

        await addItem(admin, "cartesia_voice_token_issuance", userId, {
          grants: ["tts"],
          expires_in: maxSessionSeconds + 30,
          model_id: "sonic-3-2026-01-12",
        });
        return json({
          success: true,
          available: true,
          access_token: accessToken,
          websocket_url: "wss://api.cartesia.ai/tts/websocket",
          api_version: apiVersion,
          model_id: "sonic-3-2026-01-12",
          voice_id: voiceId,
          max_session_seconds: maxSessionSeconds,
        });
      }

      case "voice.cartesia_session.finish": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const sessionId = String(body.session_id ?? "").trim().slice(0, 80);
        if (!sessionId) return json({ error: "session_id required" }, 400);

        const { data: existing } = await admin.from("hub_data")
          .select("id")
          .eq("source", "support_ticket")
          .filter("metadata->>user_id", "eq", userId)
          .filter("metadata->>voice_session_id", "eq", sessionId)
          .maybeSingle();
        if (existing?.id) {
          return json({
            success: true,
            ticket_id: existing.id,
            duplicate: true,
          });
        }

        const rawTranscript = Array.isArray(body.transcript)
          ? body.transcript
          : [];
        const transcript: Array<Record<string, string>> = [];
        let totalCharacters = 0;
        for (const rawEntry of rawTranscript.slice(0, 80)) {
          if (!rawEntry || typeof rawEntry !== "object") continue;
          const entry = rawEntry as Record<string, unknown>;
          const role = String(entry.role ?? "");
          if (role !== "user" && role !== "assistant") continue;
          const text = String(entry.text ?? "").trim().slice(0, 2000);
          if (!text || totalCharacters + text.length > 16000) continue;
          totalCharacters += text.length;
          transcript.push({
            role,
            text,
            recorded_at: String(entry.recorded_at ?? "").slice(0, 40),
          });
        }
        if (transcript.length === 0) {
          return json({ error: "transcript required" }, 400);
        }
        const durationSeconds = Math.max(
          0,
          Math.min(300, Math.floor(Number(body.duration_seconds) || 0)),
        );
        const assistantCharacterCount = transcript
          .filter((entry) => entry.role === "assistant")
          .reduce((sum, entry) => sum + entry.text.length, 0);
        const message = transcript.map((entry) =>
          `${entry.role === "user" ? "User" : "AI"}: ${entry.text}`
        ).join("\n\n");
        const ticket = await addItem(admin, "support_ticket", userId, {
          title: `Voice support session ${new Date().toISOString()}`,
          message,
          status: "open",
          channel: "cartesia_voice",
          provider: "cartesia",
          model_id: "sonic-3-2026-01-12",
          voice_session_id: sessionId,
          duration_seconds: durationSeconds,
          assistant_character_count: assistantCharacterCount,
          reported_assistant_character_count: Math.max(
            0,
            Math.floor(Number(body.assistant_character_count) || 0),
          ),
          transcript,
        });
        return json({
          success: true,
          ticket_id: ticket.id,
          usage: {
            duration_seconds: durationSeconds,
            assistant_character_count: assistantCharacterCount,
          },
        });
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
        try {
          const ttsResp = await fetchWithProviderTimeout(
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
            const errorId = crypto.randomUUID();
            console.error("voice.tts provider failure", {
              errorId,
              status: ttsResp.status,
              detail: errText.slice(0, 500),
            });
            return json({
              error: "elevenlabs_tts_unavailable",
              error_id: errorId,
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
        } catch (error) {
          const errorId = crypto.randomUUID();
          console.error("voice.tts unavailable", {
            errorId,
            detail: String(error).slice(0, 500),
          });
          return json({
            error: "elevenlabs_tts_unavailable",
            error_id: errorId,
            fallback: "webspeech",
            text,
          }, 502);
        }
      }

      case "voice.catalog": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const elevenKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
        if (!elevenKey) {
          return json({ error: "ELEVENLABS_API_KEY not configured" }, 503);
        }
        const search = asString(body.search).slice(0, 80);
        const requestedPage = Number(asString(body.page_token) || "0");
        const page = Number.isInteger(requestedPage) && requestedPage >= 0
          ? Math.min(requestedPage, 100)
          : 0;
        const params = new URLSearchParams({
          page_size: "100",
          page: String(page),
          sort: "trending",
        });
        if (search) params.set("search", search);
        try {
          const response = await fetchWithProviderTimeout(
            `https://api.elevenlabs.io/v1/shared-voices?${params}`,
            { headers: { "xi-api-key": elevenKey } },
          );
          const rawText = await response.text();
          if (!response.ok) {
            const errorId = crypto.randomUUID();
            console.error("voice.catalog provider failure", {
              errorId,
              status: response.status,
              detail: rawText.slice(0, 500),
            });
            return json({
              error: "voice_catalog_unavailable",
              error_id: errorId,
            }, 502);
          }
          const payload = JSON.parse(rawText) as Record<string, unknown>;
          const voices = Array.isArray(payload.voices)
            ? payload.voices.flatMap((item) => {
              const voice = asRecord(item);
              const id = asString(voice?.voice_id);
              if (!voice || !id) return [];
              const labels = {
                language: asString(voice.language),
                accent: asString(voice.accent),
                gender: asString(voice.gender),
                age: asString(voice.age),
                style: asString(voice.descriptive),
                use_case: asString(voice.use_case),
              };
              return [{
                id,
                name: asString(voice.name) || "Voice",
                category: asString(voice.category),
                description: asString(voice.description),
                preview_url: asString(voice.preview_url),
                public_owner_id: asString(voice.public_owner_id),
                labels,
              }];
            })
            : [];
          return json({
            success: true,
            voices,
            has_more: payload.has_more === true,
            next_page_token: payload.has_more === true
              ? String(page + 1)
              : null,
            total_count: Number(payload.total_count ?? voices.length),
          });
        } catch (error) {
          const errorId = crypto.randomUUID();
          console.error("voice.catalog unavailable", {
            errorId,
            detail: String(error).slice(0, 500),
          });
          return json({
            error: "voice_catalog_unavailable",
            error_id: errorId,
          }, 502);
        }
      }

      case "voice.usage": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        try {
          return json({
            success: true,
            usage: await getVoiceUsage(admin, userId),
          });
        } catch (error) {
          const errorId = crypto.randomUUID();
          console.error("voice.usage unavailable", {
            errorId,
            detail: String(error).slice(0, 500),
          });
          return json({
            error: "voice_usage_unavailable",
            error_id: errorId,
          }, 503);
        }
      }

      case "voice.dubbing.generate": {
        if (!userId) return json({ error: "Unauthorized" }, 401);
        const elevenKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
        if (!elevenKey) {
          return json({ error: "ELEVENLABS_API_KEY not configured" }, 503);
        }

        const text = asString(body.text).replace(/\r\n/g, "\n");
        if (!text) return json({ error: "text required" }, 400);

        let model: ReturnType<typeof resolveVoiceDubbingModel>;
        let language: string;
        let voiceId: string;
        try {
          model = resolveVoiceDubbingModel(body.model_id);
          language = normalizeVoiceLanguage(body.language, model);
          voiceId = normalizeVoiceId(body.voice_id);
        } catch (error) {
          return json({ error: String(error).replace("Error: ", "") }, 400);
        }
        if (text.length > model.totalLimit) {
          return json({
            error: "text_too_long",
            model_id: model.id,
            max_characters: model.totalLimit,
          }, 400);
        }

        const settings = normalizeVoiceSettings(body.voice_settings);
        const chunks = splitVoiceText(text, model.chunkLimit);
        const reservedCharacters = chunks.reduce(
          (total, chunk) => total + chunk.length,
          0,
        );
        const requestId = asString(body.idempotency_key).toLowerCase();
        if (
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
            .test(
              requestId,
            )
        ) {
          return json({ error: "invalid_idempotency_key" }, 400);
        }
        const fileName = safeAudioFileName(body.file_name);
        const requestHash = await sha256Hex(JSON.stringify({
          text,
          fileName,
          modelId: model.id,
          language,
          voiceId,
          settings,
        }));

        const { data: claimData, error: claimError } = await admin.rpc(
          "claim_voice_character_quota",
          {
            p_user_id: userId,
            p_request_id: requestId,
            p_request_hash: requestHash,
            p_characters: reservedCharacters,
          },
        );
        if (claimError) {
          const errorId = crypto.randomUUID();
          console.error("voice.dubbing quota claim failed", {
            errorId,
            detail: claimError.message.slice(0, 500),
          });
          return json({
            error: "voice_quota_unavailable",
            error_id: errorId,
          }, 503);
        }
        const claim = asRecord(claimData) ?? {};
        if (claim.replayed === true) {
          const replay = asRecord(claim.result) ?? {};
          const replayPath = asString(replay.storage_path);
          if (!replayPath.startsWith(`${userId}/`)) {
            return json({ error: "voice_replay_unavailable" }, 503);
          }
          const { data: signed, error: signedError } = await admin.storage
            .from(VOICE_DUBBING_BUCKET)
            .createSignedUrl(replayPath, 3600);
          if (signedError || !signed?.signedUrl) {
            return json({ error: "voice_replay_unavailable" }, 503);
          }
          let replayUsage: VoiceUsagePayload;
          try {
            replayUsage = await getVoiceUsage(admin, userId);
          } catch (error) {
            const errorId = crypto.randomUUID();
            console.error("voice.dubbing replay usage unavailable", {
              errorId,
              requestId,
              detail: String(error).slice(0, 500),
            });
            return json({
              error: "voice_usage_unavailable",
              error_id: errorId,
            }, 503);
          }
          return json({
            ...replay,
            success: true,
            replayed: true,
            audio_url: signed.signedUrl,
            expires_at: new Date(Date.now() + 3_600_000).toISOString(),
            usage: replayUsage,
          });
        }
        const usage = normalizeVoiceUsagePayload(claimData);
        if (!usage.allowed) {
          const conflict = usage.reason === "request_in_progress" ||
            usage.reason === "idempotency_conflict" ||
            usage.reason === "retry_with_new_request_id";
          return json(
            { success: false, error: usage.reason, usage },
            conflict ? 409 : 429,
          );
        }

        let uploadedPath: string | null = null;
        let billedCharacters = 0;
        let startedCharacters = 0;
        let providerCallAmbiguous = false;
        let completionUncertain = false;
        try {
          const audioChunks: Uint8Array[] = [];
          const requestIds: string[] = [];
          for (const chunk of chunks) {
            const requestBody: Record<string, unknown> = {
              text: chunk,
              model_id: model.id,
              language_code: language,
              voice_settings: model.id === "eleven_v3"
                ? {
                  stability: settings.stability,
                  style: settings.style,
                  speed: settings.speed,
                }
                : settings,
            };
            if (model.requestStitching && requestIds.length > 0) {
              requestBody.previous_request_ids = requestIds.slice(-3);
            }
            const { error: startError } = await admin.rpc(
              "start_voice_dubbing_chunk",
              {
                p_user_id: userId,
                p_request_id: requestId,
                p_characters: chunk.length,
              },
            );
            if (startError) {
              throw new Error("voice_job_chunk_start_failed");
            }
            startedCharacters += chunk.length;
            let response: Response;
            try {
              response = await fetchWithProviderTimeout(
                `https://api.elevenlabs.io/v1/text-to-speech/${
                  encodeURIComponent(voiceId)
                }?output_format=mp3_44100_128`,
                {
                  method: "POST",
                  headers: {
                    "xi-api-key": elevenKey,
                    "Content-Type": "application/json",
                  },
                  body: JSON.stringify(requestBody),
                },
              );
            } catch (error) {
              providerCallAmbiguous = true;
              throw error;
            }
            if (!response.ok) {
              providerCallAmbiguous = false;
              const providerDetail = (await response.text()).slice(0, 500);
              console.error("voice.dubbing provider failure", {
                requestId,
                status: response.status,
                detail: providerDetail,
              });
              throw new Error("elevenlabs_generation_failed");
            }
            providerCallAmbiguous = true;
            const audioBuffer = await response.arrayBuffer();
            billedCharacters += chunk.length;
            providerCallAmbiguous = false;
            const providerRequestId = response.headers.get("request-id");
            if (providerRequestId) requestIds.push(providerRequestId);
            audioChunks.push(new Uint8Array(audioBuffer));
          }

          uploadedPath = `${userId}/${
            new Date().toISOString().slice(0, 7)
          }/${crypto.randomUUID()}-${fileName}`;
          const combinedAudio = concatenateAudio(audioChunks);
          const { error: uploadError } = await admin.storage
            .from(VOICE_DUBBING_BUCKET)
            .upload(uploadedPath, combinedAudio, {
              contentType: "audio/mpeg",
              cacheControl: "3600",
              upsert: false,
            });
          if (uploadError) {
            throw new Error(`Audio upload failed: ${uploadError.message}`);
          }

          const { data: signed, error: signedError } = await admin.storage
            .from(VOICE_DUBBING_BUCKET)
            .createSignedUrl(uploadedPath, 3600);
          if (signedError || !signed?.signedUrl) {
            throw new Error(
              `Audio signing failed: ${signedError?.message ?? "no URL"}`,
            );
          }
          const storedResult = {
            success: true,
            storage_path: uploadedPath,
            file_name: fileName,
            content_type: "audio/mpeg",
            character_count: text.length,
            chunk_count: chunks.length,
            model_id: model.id,
            language,
          };
          const { data: finishData, error: finishError } = await admin.rpc(
            "finish_voice_dubbing_job",
            {
              p_user_id: userId,
              p_request_id: requestId,
              p_status: "completed",
              p_billed_characters: billedCharacters,
              p_result: storedResult,
              p_error_code: null,
            },
          );
          const finish = asRecord(finishData);
          if (finishError || asString(finish?.status) !== "completed") {
            const { data: persistedJob, error: persistedJobError } = await admin
              .from("voice_dubbing_jobs")
              .select("status,result")
              .eq("user_id", userId)
              .eq("request_id", requestId)
              .maybeSingle();
            const persisted = asRecord(persistedJob);
            const persistedResult = asRecord(persisted?.result);
            const completionPersisted =
              asString(persisted?.status) === "completed" &&
              asString(persistedResult?.storage_path) === uploadedPath;
            if (!completionPersisted) {
              if (finishError || persistedJobError) {
                completionUncertain = true;
              }
              throw new Error("voice_job_completion_failed");
            }
          }
          return json({
            ...storedResult,
            audio_url: signed.signedUrl,
            expires_at: new Date(Date.now() + 3_600_000).toISOString(),
            usage,
          });
        } catch (error) {
          const errorId = crypto.randomUUID();
          if (completionUncertain) {
            console.error("voice.dubbing completion state uncertain", {
              errorId,
              requestId,
              billedCharacters,
              uploadedPath,
              detail: String(error).slice(0, 700),
            });
            return json({
              error: "voice_completion_pending",
              error_id: errorId,
              billed_characters: billedCharacters,
            }, 503);
          }
          const accountedCharacters = providerCallAmbiguous
            ? Math.max(billedCharacters, startedCharacters)
            : billedCharacters;
          const { data: failureFinishData, error: finishError } = await admin
            .rpc(
              "finish_voice_dubbing_job",
              {
                p_user_id: userId,
                p_request_id: requestId,
                p_status: "failed",
                p_billed_characters: accountedCharacters,
                p_result: null,
                p_error_code: "voice_generation_failed",
              },
            );
          const failureFinish = asRecord(failureFinishData);
          const failureStatus = asString(failureFinish?.status);
          const finalizedAsFailure = failureStatus === "failed" ||
            failureStatus === "expired";
          if (finishError || !finalizedAsFailure) {
            console.error("voice.dubbing failure state uncertain", {
              errorId,
              requestId,
              failureStatus,
              uploadedPath,
              detail: String(error).slice(0, 700),
              reconciliationError: finishError?.message.slice(0, 500),
            });
            return json({
              error: finishError || failureStatus === "completed"
                ? "voice_completion_pending"
                : "voice_quota_reconciliation_required",
              error_id: errorId,
              billed_characters: accountedCharacters,
            }, 503);
          }
          if (uploadedPath) {
            const { error: removeError } = await admin.storage
              .from(VOICE_DUBBING_BUCKET).remove([
                uploadedPath,
              ]);
            if (removeError) {
              console.error("voice.dubbing cleanup failed", {
                requestId,
                detail: removeError.message.slice(0, 500),
              });
            }
          }
          console.error("voice.dubbing generation failed", {
            errorId,
            requestId,
            billedCharacters,
            startedCharacters,
            accountedCharacters,
            providerCallAmbiguous,
            detail: String(error).slice(0, 700),
            reconciliationError: finishError?.message.slice(0, 500),
          });
          return json({
            error: "voice_generation_failed",
            error_id: errorId,
            billed_characters: accountedCharacters,
          }, 502);
        }
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
        const dgResp = await fetchWithProviderTimeout(
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
        const recommendationScope = resolveAuthenticatedUserId(
          userId!,
          body.user_id,
        );
        if ("error" in recommendationScope) {
          return json(
            { error: recommendationScope.error },
            recommendationScope.status,
          );
        }
        const { data: usage } = await admin.from("user_feature_usage")
          .select("feature_route, tapped_at")
          .eq("user_id", recommendationScope.userId)
          .order("tapped_at", { ascending: false })
          .limit(30);
        const recent = new Set(
          (usage ?? []).map((r: Record<string, unknown>) =>
            String(r.feature_route)
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

      case "home.popular": {
        const limit = Math.min(Math.max(Number(body.limit ?? 8), 1), 20);
        const windowDays = Math.min(
          Math.max(Number(body.window_days ?? 30), 1),
          365,
        );
        const since = new Date(
          Date.now() - windowDays * 24 * 60 * 60 * 1000,
        ).toISOString();
        const { data, error } = await admin.from("user_feature_usage")
          .select("feature_route, feature_label, tapped_at")
          .gte("tapped_at", since)
          .limit(2000);
        if (error) return json({ error: error.message }, 400);

        const byRoute = new Map<
          string,
          { feature_route: string; feature_label: string; use_count: number }
        >();
        for (const row of data ?? []) {
          const rawRoute = String(row.feature_route ?? "").trim();
          if (!rawRoute) continue;
          const route = rawRoute.startsWith("/") ? rawRoute : `/${rawRoute}`;
          const current = byRoute.get(route) ?? {
            feature_route: route,
            feature_label: String(row.feature_label ?? route),
            use_count: 0,
          };
          current.use_count += 1;
          if (!current.feature_label || current.feature_label === route) {
            current.feature_label = String(row.feature_label ?? route);
          }
          byRoute.set(route, current);
        }

        const features = [...byRoute.values()]
          .sort((a, b) =>
            b.use_count - a.use_count ||
            a.feature_label.localeCompare(b.feature_label)
          )
          .slice(0, limit);
        return json({ success: true, features });
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
          const r = await fetchWithProviderTimeout(
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
    if (err instanceof UniversityActionError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof MonthlyAssetReportActionError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof AssetChatActionError) {
      return json({ error: err.message, code: err.code }, err.status);
    }
    if (err instanceof DepartmentFinanceSummaryActionError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof PayslipIngestionError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof ExpenseAiError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof DisposableBalanceError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof AnomalyDetectionError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof MarketPriceActionError) {
      return json({ error: err.message }, err.status);
    }
    if (err instanceof WriterKnowledgeGraphError) {
      return json({ error: err.message, code: err.code }, err.status);
    }
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
