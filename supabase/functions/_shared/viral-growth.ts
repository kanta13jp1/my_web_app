import {
  asNumber,
  asRecord,
  asString,
  asStringArray,
  buildUtmUrl,
} from "./edge.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const VIDEO_PROVIDER_URL = Deno.env.get("VIRAL_VIDEO_PROVIDER_URL") ?? "";
const VIDEO_PROVIDER_API_KEY = Deno.env.get("VIRAL_VIDEO_PROVIDER_API_KEY") ??
  "";
const VIDEO_PROVIDER_NAME = Deno.env.get("VIRAL_VIDEO_PROVIDER_NAME") ||
  "generic-video-provider";
const VIDEO_PROVIDER_CALLBACK_URL = Deno.env.get("VIRAL_VIDEO_CALLBACK_URL") ??
  "";

export interface ViralCampaignInput {
  appName: string;
  productSummary: string;
  landingUrl?: string;
  targetAudience?: string;
  valueProposition?: string;
  painPoint?: string;
  differentiators?: string[];
  seedHooks?: string[];
  constraints?: string[];
  tone?: string;
  adStyle?: string;
  desiredDurationSec?: number;
}

export interface ViralStoryboardScene {
  sceneNo: number;
  durationSec: number;
  visual: string;
  overlayText: string;
  voiceover: string;
  motion: string;
}

export interface ViralCampaignBrief {
  campaignId: string;
  conceptName: string;
  audience: string;
  primaryHook: string;
  secondaryHooks: string[];
  cta: string;
  xPostText: string;
  hashtags: string[];
  overlayLines: string[];
  shareAngles: string[];
  complianceNotes: string[];
  renderPrompt: string;
  desiredDurationSec: number;
  viralScore: number;
  landingUrl: string;
  scenes: ViralStoryboardScene[];
}

export interface ViralSharePack {
  campaignId: string;
  landingUrl: string;
  trackingUrl: string;
  xPosts: string[];
  replyPrompts: string[];
  communityPrompts: string[];
  referralPrompt: string;
  viralLoops: string[];
  checklist: string[];
  scoreSummary: string;
}

export interface ViralRenderJobResult {
  provider: string;
  status: string;
  jobId: string;
  providerJobId: string | null;
  assetUrl: string | null;
  thumbnailUrl: string | null;
  raw: Record<string, unknown>;
}

export interface ViralMetricsInput {
  impressions?: number;
  clicks?: number;
  signups?: number;
  reposts?: number;
  likes?: number;
  comments?: number;
  shares?: number;
  spendYen?: number;
}

export async function generateViralBrief(
  input: ViralCampaignInput,
): Promise<ViralCampaignBrief> {
  const normalized = normalizeInput(input);
  const fallback = buildFallbackViralBrief(normalized);
  if (OPENAI_API_KEY === "") {
    return fallback;
  }

  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.5,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "Create truthful short-form performance-marketing concepts for X. Make them punchy, specific, and non-deceptive. Return JSON only.",
          },
          {
            role: "user",
            content: JSON.stringify({
              request:
                "Generate a 15-30 second viral ad brief with scenes, captions, X post copy, and guardrails.",
              input: normalized,
            }),
          },
        ],
      }),
    });
    if (!response.ok) {
      return fallback;
    }

    const json = await response.json();
    const content = asString(json?.choices?.[0]?.message?.content);
    if (content === "") {
      return fallback;
    }
    return sanitizeBrief(JSON.parse(content), fallback);
  } catch {
    return fallback;
  }
}

export function buildSharePack(
  brief: ViralCampaignBrief,
  overrides: { landingUrl?: string; channel?: string } = {},
): ViralSharePack {
  const landingUrl = asString(overrides.landingUrl) || brief.landingUrl;
  const trackingUrl = buildUtmUrl(landingUrl, {
    utm_source: overrides.channel || "x",
    utm_medium: "viral_share",
    utm_campaign: brief.campaignId,
  });
  return {
    campaignId: brief.campaignId,
    landingUrl,
    trackingUrl,
    xPosts: buildXVariants(brief, trackingUrl, 3),
    replyPrompts: [
      `${brief.primaryHook} と感じる瞬間、ありますか？`,
      `いま一番ムダだと感じる時間は何ですか？`,
      `${brief.conceptName} のどこが一番刺さりますか？`,
    ],
    communityPrompts: [
      "投稿直後15分で返信欄を育てる",
      "共感コメントを引用リポストして2本目へつなぐ",
      "公開メモ・公開プロフィール・紹介導線を同じキャンペーンIDで束ねる",
    ],
    referralPrompt:
      "刺さった人には『同じ悩みの1人に送ってください』を固定返信で添える",
    viralLoops: [
      "動画本編 -> 固定返信リンク -> 公開メモ深掘り",
      "高反応フックを別字幕で翌日に再投下",
      "返信で課題を回収して3本目の訴求へ変換",
    ],
    checklist: [
      "冒頭3秒で損失回避を伝える",
      "CTAは1つに絞る",
      "実在しない成果や機能を入れない",
      "リンク先でも同じ約束を繰り返す",
    ],
    scoreSummary: `Viral score ${brief.viralScore}/100`,
  };
}

export function buildXVariants(
  brief: ViralCampaignBrief,
  landingUrl: string,
  count = 3,
): string[] {
  const variants = [
    composeXPostText(
      `${brief.primaryHook}\n${brief.overlayLines[1] ?? brief.cta}`,
      landingUrl,
      brief.hashtags,
    ),
    composeXPostText(
      `${brief.secondaryHooks[0] ?? brief.primaryHook}\n${brief.cta}`,
      landingUrl,
      brief.hashtags,
    ),
    composeXPostText(
      `${brief.shareAngles[0] ?? brief.primaryHook}\n${
        brief.overlayLines[2] ?? brief.cta
      }`,
      landingUrl,
      brief.hashtags,
    ),
  ];
  return [...new Set(variants)].slice(0, count);
}

export function composeXPostText(
  body: string,
  landingUrl: string,
  hashtags: string[],
): string {
  const tagLine = hashtags
    .map((tag) => tag.startsWith("#") ? tag : `#${tag}`)
    .join(" ");
  const reserve = [asString(landingUrl), tagLine].filter((entry) =>
    entry !== ""
  )
    .join("\n");
  const trimmedBody = asString(body);
  const joined = [trimmedBody, reserve].filter((entry) => entry !== "").join(
    "\n",
  );
  if (joined.length <= 280) {
    return joined;
  }
  const available = Math.max(40, 280 - reserve.length - (reserve ? 1 : 0));
  return [
    `${trimmedBody.slice(0, available - 1).trimEnd()}…`,
    reserve,
  ].filter((entry) => entry !== "").join("\n");
}

export function calculateViralMetrics(
  input: ViralMetricsInput,
): Record<string, number> {
  const impressions = Math.max(0, asNumber(input.impressions));
  const clicks = Math.max(0, asNumber(input.clicks));
  const signups = Math.max(0, asNumber(input.signups));
  const reposts = Math.max(0, asNumber(input.reposts));
  const likes = Math.max(0, asNumber(input.likes));
  const comments = Math.max(0, asNumber(input.comments));
  const shares = Math.max(0, asNumber(input.shares) || reposts);
  const spendYen = Math.max(0, asNumber(input.spendYen));
  const engagements = likes + comments + reposts;
  return {
    impressions,
    clicks,
    signups,
    reposts,
    likes,
    comments,
    shares,
    spendYen,
    ctr: ratio(clicks, impressions),
    signupRate: ratio(signups, clicks),
    engagementRate: ratio(engagements, impressions),
    amplificationRate: ratio(shares, impressions),
    costPerSignup: signups === 0 ? 0 : Math.round(spendYen / signups),
  };
}

export async function queueViralVideoRender(
  brief: ViralCampaignBrief,
  options: {
    aspectRatio?: string;
    dryRun?: boolean;
    callbackUrl?: string;
    providerPayload?: Record<string, unknown>;
  } = {},
): Promise<ViralRenderJobResult> {
  const callbackUrl = asString(options.callbackUrl) ||
    VIDEO_PROVIDER_CALLBACK_URL;
  if (options.dryRun || VIDEO_PROVIDER_URL === "") {
    return {
      provider: VIDEO_PROVIDER_NAME,
      status: VIDEO_PROVIDER_URL === "" ? "awaiting_provider" : "dry_run",
      jobId: `viral-job-${brief.campaignId}`,
      providerJobId: null,
      assetUrl: null,
      thumbnailUrl: null,
      raw: {
        prompt: brief.renderPrompt,
        callbackUrl,
      },
    };
  }

  const payload: Record<string, unknown> = {
    title: brief.conceptName,
    prompt: brief.renderPrompt,
    duration_seconds: brief.desiredDurationSec,
    aspect_ratio: asString(options.aspectRatio) || "9:16",
    scenes: brief.scenes,
    overlay_lines: brief.overlayLines,
    cta: brief.cta,
    callback_url: callbackUrl || undefined,
    metadata: {
      campaign_id: brief.campaignId,
      landing_url: brief.landingUrl,
      primary_hook: brief.primaryHook,
    },
    ...(options.providerPayload ?? {}),
  };

  const response = await fetch(VIDEO_PROVIDER_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(VIDEO_PROVIDER_API_KEY === ""
        ? {}
        : { Authorization: `Bearer ${VIDEO_PROVIDER_API_KEY}` }),
    },
    body: JSON.stringify(payload),
  });
  const result = safeParseJson(await response.text());
  if (!response.ok) {
    throw new Error(
      `Video provider error ${response.status}: ${JSON.stringify(result)}`,
    );
  }

  const providerJobId = asString(
    result.job_id ?? result.jobId ?? result.id ?? result.render_id,
  ) || null;
  const assetUrl = asString(
    result.asset_url ?? result.assetUrl ?? result.video_url ??
      result.output_url,
  ) || null;
  const thumbnailUrl = asString(
    result.thumbnail_url ?? result.thumbnailUrl ?? result.poster_url,
  ) || null;
  return {
    provider: VIDEO_PROVIDER_NAME,
    status: asString(result.status ?? result.state) ||
      (assetUrl ? "completed" : "queued"),
    jobId: providerJobId || `viral-job-${brief.campaignId}`,
    providerJobId,
    assetUrl,
    thumbnailUrl,
    raw: result,
  };
}

function normalizeInput(input: ViralCampaignInput): ViralCampaignInput {
  return {
    appName: asString(input.appName) || "My Web App",
    productSummary: asString(input.productSummary),
    landingUrl: asString(input.landingUrl),
    targetAudience: asString(input.targetAudience) ||
      "time-poor solo builders and people who want to stop wasting time and money",
    valueProposition: asString(input.valueProposition) ||
      "replace scattered tools and impulse loops with one action-focused workspace",
    painPoint: asString(input.painPoint) ||
      "people know what to do but still leak time, attention, and money every day",
    differentiators: asStringArray(input.differentiators, 6),
    seedHooks: asStringArray(input.seedHooks, 6),
    constraints: asStringArray(input.constraints, 6),
    tone: asString(input.tone) || "bold, urgent, practical",
    adStyle: asString(input.adStyle) ||
      "fast-cut short-form ad inspired by aggressive mobile UA pacing, but truthful",
    desiredDurationSec: clampDuration(asNumber(input.desiredDurationSec, 20)),
  };
}

function buildFallbackViralBrief(
  input: ViralCampaignInput,
): ViralCampaignBrief {
  const campaignId = `viral-${
    new Date().toISOString().slice(0, 10).replace(/-/g, "")
  }-${crypto.randomUUID().slice(0, 8)}`;
  const primaryHook = input.seedHooks?.[0] ||
    "お金を増やす前に、浪費を止められるか。";
  const overlayLines = [
    "その5分が、また消えた。",
    "浪費を止める仕組みを先に持つ。",
    "意志力ではなく、毎日の構造を変える。",
    "リンクから、今日の漏れを止める。",
  ];
  const hashtags = ["buildinpublic", "FlutterWeb", "Supabase"];
  const cta = "無料で使って、漏れを止める。";
  const landingUrl = input.landingUrl ?? "";

  return {
    campaignId,
    conceptName: `${input.appName} Viral Discipline Sprint`,
    audience: input.targetAudience ?? "",
    primaryHook,
    secondaryHooks: [
      "節約アプリではなく、浪費を断る訓練。",
      "時間もお金も、漏れを止める方が先。",
      "衝動の前に戻れる構造を置く。",
    ],
    cta,
    xPostText: composeXPostText(
      `${primaryHook}\n${input.productSummary}\n${cta}`,
      landingUrl,
      hashtags,
    ),
    hashtags,
    overlayLines,
    shareAngles: [
      "稼ぐ前に漏れを止める",
      "意志力より構造を変える",
      "散った時間を毎日回収する",
    ],
    complianceNotes: [
      "誇張した収益保証を入れない",
      "存在しない成果データを入れない",
      "実際に使える画面や行動だけを見せる",
    ],
    renderPrompt:
      `${input.adStyle}. 9:16 short-form ad. Show the pain of lost time and money, then reveal ${input.appName} as a focused recovery workflow. Use crisp captions, tight motion, phone UI close-ups, and end with one clear CTA to ${
        landingUrl || "the landing page"
      }.`,
    desiredDurationSec: clampDuration(asNumber(input.desiredDurationSec, 20)),
    viralScore: 73,
    landingUrl,
    scenes: [
      {
        sceneNo: 1,
        durationSec: 4,
        visual: "Thumb opens shopping and social apps late at night",
        overlayText: overlayLines[0],
        voiceover: "また今日も、時間とお金が漏れていく。",
        motion: "Punch-in, timer overlay, high tension",
      },
      {
        sceneNo: 2,
        durationSec: 5,
        visual: "Temptation logs and abstinence streak cards appear in the app",
        overlayText: overlayLines[1],
        voiceover: "必要なのは、稼ぎ方より先に漏れを止める構造。",
        motion: "UI swipe reveal, counters animate",
      },
      {
        sceneNo: 3,
        durationSec: 6,
        visual: "Dashboard highlights regained time and streaks",
        overlayText: overlayLines[2],
        voiceover: "衝動ではなく原則を選べた回数を、毎日積み上げる。",
        motion: "Cards stack in, regained minutes tick up",
      },
      {
        sceneNo: 4,
        durationSec: 5,
        visual: "Simple CTA screen with product name and link area",
        overlayText: overlayLines[3],
        voiceover: "リンクから、今日の漏れを止める。",
        motion: "Soft zoom and CTA pulse",
      },
    ],
  };
}

function sanitizeBrief(
  value: unknown,
  fallback: ViralCampaignBrief,
): ViralCampaignBrief {
  const record = asRecord(value);
  const scenesRaw = Array.isArray(record.scenes) ? record.scenes : [];
  const scenes = scenesRaw
    .map((scene, index) =>
      sanitizeScene(scene, fallback.scenes[index], index + 1)
    )
    .filter((scene) => scene.durationSec > 0);

  return {
    campaignId: asString(record.campaignId) || fallback.campaignId,
    conceptName: asString(record.conceptName) || fallback.conceptName,
    audience: asString(record.audience) || fallback.audience,
    primaryHook: asString(record.primaryHook) || fallback.primaryHook,
    secondaryHooks: fallbackStrings(
      record.secondaryHooks,
      fallback.secondaryHooks,
    ),
    cta: asString(record.cta) || fallback.cta,
    xPostText: composeXPostText(
      asString(record.xPostText) || fallback.xPostText,
      asString(record.landingUrl) || fallback.landingUrl,
      fallbackStrings(record.hashtags, fallback.hashtags),
    ),
    hashtags: fallbackStrings(record.hashtags, fallback.hashtags),
    overlayLines: fallbackStrings(record.overlayLines, fallback.overlayLines),
    shareAngles: fallbackStrings(record.shareAngles, fallback.shareAngles),
    complianceNotes: fallbackStrings(
      record.complianceNotes,
      fallback.complianceNotes,
    ),
    renderPrompt: asString(record.renderPrompt) || fallback.renderPrompt,
    desiredDurationSec: clampDuration(
      asNumber(record.desiredDurationSec, fallback.desiredDurationSec),
    ),
    viralScore: Math.max(
      1,
      Math.min(
        100,
        Math.round(asNumber(record.viralScore, fallback.viralScore)),
      ),
    ),
    landingUrl: asString(record.landingUrl) || fallback.landingUrl,
    scenes: scenes.length > 0 ? scenes : fallback.scenes,
  };
}

function sanitizeScene(
  value: unknown,
  fallback: ViralStoryboardScene | undefined,
  sceneNo: number,
): ViralStoryboardScene {
  const record = asRecord(value);
  return {
    sceneNo: Math.max(
      1,
      Math.round(asNumber(record.sceneNo, fallback?.sceneNo ?? sceneNo)),
    ),
    durationSec: Math.max(
      2,
      Math.round(asNumber(record.durationSec, fallback?.durationSec ?? 4)),
    ),
    visual: asString(record.visual) || fallback?.visual ||
      "Phone UI product shot",
    overlayText: asString(record.overlayText) || fallback?.overlayText ||
      "Move faster",
    voiceover: asString(record.voiceover) || fallback?.voiceover ||
      "Turn waste into action.",
    motion: asString(record.motion) || fallback?.motion || "Simple push-in",
  };
}

function fallbackStrings(value: unknown, fallback: string[]): string[] {
  const normalized = asStringArray(value, fallback.length || 6);
  return normalized.length > 0 ? [...new Set(normalized)] : fallback;
}

function safeParseJson(value: string): Record<string, unknown> {
  if (value.trim() === "") {
    return {};
  }
  try {
    return asRecord(JSON.parse(value));
  } catch {
    return { raw: value };
  }
}

function clampDuration(value: number): number {
  return Math.max(12, Math.min(30, Math.round(value || 20)));
}

function ratio(numerator: number, denominator: number): number {
  return denominator <= 0
    ? 0
    : Math.round((numerator / denominator) * 10000) / 10000;
}
