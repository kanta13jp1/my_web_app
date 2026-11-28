export type CompressionProvider = "google" | "openai" | "groq" | "anthropic";

export type CompressionAdapter =
  | "gemini_generate_content"
  | "openai_chat_completions"
  | "anthropic_messages";

export interface CompressionProfile {
  profileId: string;
  provider: CompressionProvider;
  model: string;
  adapter: CompressionAdapter;
  endpointTemplate: string;
  authHeader: string;
  authPrefix: string;
  authEnvVar: string;
  inputUsdPer1m: number;
  outputUsdPer1m: number;
  maxOutputTokens: number;
}

export interface CompressionRouteDecision {
  profileId: string;
  provider: CompressionProvider;
  model: string;
  adapter: CompressionAdapter;
  endpoint: string;
  authHeader: string;
  authPrefix: string;
  authEnvVar: string;
  source: "default_config" | "env_override" | "explicit_override";
  baselineModel: string;
}

export interface CompressionCostMetrics {
  activeModel: string;
  baselineModel: string;
  inputTokens: number;
  outputTokens: number;
  activeCostUsd: number;
  baselineCostUsd: number;
  savingsUsd: number;
  savingsPct: number;
}

export interface CompressionQualityResult {
  passed: boolean;
  contextRecallScore: number;
  compressionRatio: number;
  missingSections: string[];
  missingAnchors: string[];
}

export const DEFAULT_COMPRESSION_PROFILE_ID = "gemini_flash_low_cost";
export const BASELINE_COMPRESSION_PROFILE_ID = "claude_sonnet_baseline";

export const DEFAULT_COMPRESSION_PROFILES: Record<
  string,
  CompressionProfile
> = {
  gemini_flash_low_cost: {
    profileId: "gemini_flash_low_cost",
    provider: "google",
    model: "gemini-2.5-flash",
    adapter: "gemini_generate_content",
    endpointTemplate:
      "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    authHeader: "x-goog-api-key",
    authPrefix: "",
    authEnvVar: "GEMINI_API_KEY",
    inputUsdPer1m: 0.15,
    outputUsdPer1m: 0.60,
    maxOutputTokens: 1024,
  },
  gemini_flash_lite: {
    profileId: "gemini_flash_lite",
    provider: "google",
    model: "gemini-2.5-flash-lite",
    adapter: "gemini_generate_content",
    endpointTemplate:
      "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    authHeader: "x-goog-api-key",
    authPrefix: "",
    authEnvVar: "GEMINI_API_KEY",
    inputUsdPer1m: 0.10,
    outputUsdPer1m: 0.40,
    maxOutputTokens: 1024,
  },
  gpt_mini: {
    profileId: "gpt_mini",
    provider: "openai",
    model: "gpt-5.4-mini",
    adapter: "openai_chat_completions",
    endpointTemplate: "https://api.openai.com/v1/chat/completions",
    authHeader: "Authorization",
    authPrefix: "Bearer ",
    authEnvVar: "OPENAI_API_KEY",
    inputUsdPer1m: 0.15,
    outputUsdPer1m: 0.60,
    maxOutputTokens: 1024,
  },
  groq_llama_fast: {
    profileId: "groq_llama_fast",
    provider: "groq",
    model: "llama-3.3-70b-versatile",
    adapter: "openai_chat_completions",
    endpointTemplate: "https://api.groq.com/openai/v1/chat/completions",
    authHeader: "Authorization",
    authPrefix: "Bearer ",
    authEnvVar: "GROQ_API_KEY",
    inputUsdPer1m: 0.05,
    outputUsdPer1m: 0.20,
    maxOutputTokens: 1024,
  },
  claude_haiku: {
    profileId: "claude_haiku",
    provider: "anthropic",
    model: "claude-haiku-4-5",
    adapter: "anthropic_messages",
    endpointTemplate: "https://api.anthropic.com/v1/messages",
    authHeader: "x-api-key",
    authPrefix: "",
    authEnvVar: "ANTHROPIC_API_KEY",
    inputUsdPer1m: 1.00,
    outputUsdPer1m: 5.00,
    maxOutputTokens: 1024,
  },
  claude_sonnet_baseline: {
    profileId: "claude_sonnet_baseline",
    provider: "anthropic",
    model: "claude-sonnet-4-6",
    adapter: "anthropic_messages",
    endpointTemplate: "https://api.anthropic.com/v1/messages",
    authHeader: "x-api-key",
    authPrefix: "",
    authEnvVar: "ANTHROPIC_API_KEY",
    inputUsdPer1m: 3.00,
    outputUsdPer1m: 15.00,
    maxOutputTokens: 1024,
  },
};

const REQUIRED_SECTIONS = [
  "## Decisions",
  "## Open Tasks",
  "## Key Identifiers",
  "## Constraints",
] as const;

export function resolveCompressionEndpoint(
  profile: CompressionProfile,
): string {
  return profile.endpointTemplate.replace("{model}", profile.model);
}

export function resolveCompressionModelConfig(options: {
  env?: Record<string, string | undefined>;
  profile?: string | null;
  provider?: string | null;
  model?: string | null;
  baselineModel?: string | null;
} = {}): CompressionRouteDecision {
  const env = options.env ?? {};
  const hasExplicitSelector = Boolean(
    options.profile?.trim() ||
      options.provider?.trim() ||
      options.model?.trim(),
  );
  const requestedProfile = (
    options.profile ??
    (hasExplicitSelector ? "" : env["AGENT_MEMORY_COMPRESSION_PROFILE"]) ??
    ""
  ).trim();
  const requestedProvider = (
    options.provider ??
    (hasExplicitSelector ? "" : env["AGENT_MEMORY_COMPRESSION_PROVIDER"]) ??
    ""
  ).trim().toLowerCase();
  const requestedModel = (
    options.model ??
    (hasExplicitSelector ? "" : env["AGENT_MEMORY_COMPRESSION_MODEL"]) ??
    ""
  ).trim();
  const requestedBaseline = (
    options.baselineModel ??
    env["AGENT_MEMORY_COMPRESSION_BASELINE_MODEL"] ??
    ""
  ).trim();

  let active = DEFAULT_COMPRESSION_PROFILES[
    requestedProfile || DEFAULT_COMPRESSION_PROFILE_ID
  ];
  if (!active) {
    throw new Error(`Unknown compression profile: ${requestedProfile}`);
  }

  let source: CompressionRouteDecision["source"] = requestedProfile
    ? "env_override"
    : "default_config";
  if (options.profile || options.provider || options.model) {
    source = "explicit_override";
  }

  const allProfiles = Object.values(DEFAULT_COMPRESSION_PROFILES);
  if (requestedModel) {
    const exact = allProfiles.find(
      (item) =>
        item.model === requestedModel &&
        (!requestedProvider || item.provider === requestedProvider),
    );
    if (exact) {
      active = exact;
    } else {
      const baseTemplate = allProfiles.find(
        (item) => item.provider === (requestedProvider || active.provider),
      ) ?? active;
      active = {
        ...baseTemplate,
        profileId: `custom:${baseTemplate.provider}:${requestedModel}`,
        model: requestedModel,
      };
    }
    if (source === "default_config") {
      source = "env_override";
    }
  } else if (requestedProvider && requestedProvider !== active.provider) {
    const matching = allProfiles
      .filter((item) => item.provider === requestedProvider)
      .sort((a, b) => a.inputUsdPer1m - b.inputUsdPer1m);
    if (matching.length === 0) {
      throw new Error(
        `Unsupported compression provider: ${requestedProvider}`,
      );
    }
    active = matching[0];
    if (source === "default_config") {
      source = "env_override";
    }
  }

  const baselineDefault =
    DEFAULT_COMPRESSION_PROFILES[BASELINE_COMPRESSION_PROFILE_ID];
  const baselineMatched = requestedBaseline
    ? allProfiles.find((item) => item.model === requestedBaseline)
    : undefined;
  const baselineModel = requestedBaseline || baselineMatched?.model ||
    baselineDefault.model;

  return {
    profileId: active.profileId,
    provider: active.provider,
    model: active.model,
    adapter: active.adapter,
    endpoint: resolveCompressionEndpoint(active),
    authHeader: active.authHeader,
    authPrefix: active.authPrefix,
    authEnvVar: active.authEnvVar,
    source,
    baselineModel,
  };
}

export function computeCompressionCostSavings(params: {
  inputTokens: number;
  outputTokens: number;
  activeProfile: CompressionProfile;
  baselineProfile?: CompressionProfile;
}): CompressionCostMetrics {
  const baseline = params.baselineProfile ??
    DEFAULT_COMPRESSION_PROFILES[BASELINE_COMPRESSION_PROFILE_ID];
  const inTok = Math.max(0, Math.floor(params.inputTokens));
  const outTok = Math.max(0, Math.floor(params.outputTokens));

  const activeCost = (
    inTok * params.activeProfile.inputUsdPer1m +
    outTok * params.activeProfile.outputUsdPer1m
  ) / 1_000_000;
  const baselineCost = (
    inTok * baseline.inputUsdPer1m +
    outTok * baseline.outputUsdPer1m
  ) / 1_000_000;
  const savings = baselineCost - activeCost;
  const pct = baselineCost > 0 ? (savings / baselineCost) * 100 : 0;

  return {
    activeModel: params.activeProfile.model,
    baselineModel: baseline.model,
    inputTokens: inTok,
    outputTokens: outTok,
    activeCostUsd: Number(activeCost.toFixed(6)),
    baselineCostUsd: Number(baselineCost.toFixed(6)),
    savingsUsd: Number(savings.toFixed(6)),
    savingsPct: Number(pct.toFixed(2)),
  };
}

export function evaluateSummaryRestorationQuality(
  rawText: string,
  summaryText: string,
  minRecall = 0.7,
): CompressionQualityResult {
  const anchors = Array.from(
    new Set(rawText.match(/#\d{2,6}\b/g) ?? []),
  );
  const lowered = summaryText.toLowerCase();
  const matched = anchors.filter((item) =>
    lowered.includes(item.toLowerCase())
  );
  const missingAnchors = anchors.filter((item) =>
    !lowered.includes(item.toLowerCase())
  );
  const recall = anchors.length > 0 ? matched.length / anchors.length : 1;

  const missingSections = REQUIRED_SECTIONS.filter(
    (heading) => !lowered.includes(heading.toLowerCase()),
  );
  const rawLen = Math.max(1, rawText.trim().length);
  const ratio = Number(
    (1 - summaryText.trim().length / rawLen).toFixed(4),
  );

  return {
    passed: summaryText.trim().length > 0 &&
      recall >= minRecall &&
      missingSections.length === 0,
    contextRecallScore: Number(recall.toFixed(4)),
    compressionRatio: ratio,
    missingSections: [...missingSections],
    missingAnchors,
  };
}

export function buildCompressionProviderRequest(
  route: CompressionRouteDecision,
  promptText: string,
  credential: string,
): {
  url: string;
  headers: Record<string, string>;
  body: Record<string, unknown>;
} {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    [route.authHeader]: `${route.authPrefix}${credential}`,
  };
  if (route.adapter === "gemini_generate_content") {
    return {
      url: route.endpoint,
      headers,
      body: {
        contents: [{ role: "user", parts: [{ text: promptText }] }],
        generationConfig: { temperature: 0.1, maxOutputTokens: 1024 },
      },
    };
  }
  if (route.adapter === "anthropic_messages") {
    headers["anthropic-version"] = "2023-06-01";
  }
  return {
    url: route.endpoint,
    headers,
    body: {
      model: route.model,
      max_tokens: 1024,
      temperature: 0.1,
      messages: [{ role: "user", content: promptText }],
    },
  };
}
