// viral-video-ad-generator Edge Function
// Dark War風バイラル動画広告生成パイプライン
//
// 機能:
// - FAL.ai (fast-sdxl) を使った広告画像生成
// - Hedra を使ったプレゼンター動画生成
// - 自分株式会社の「21の競合を超える」ストーリーを動画化
// - 生成したメディアをSupabase Storageに保存
// - X投稿用の動画URL + キャプションを返す
//
// POST { "type": "image" | "presenter_video" | "video_script", "template": "dark_war" | "feature_highlight" | "mobile_ux_validation" | "user_growth", "lang": "ja" | "en" }
// GET  ?view=templates | ?view=history

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildHedraTextToSpeechAudioGeneration,
  isHedraInvalidTextToSpeechModelError,
  resolveConfiguredHedraTextToSpeechModelId,
  stripHedraTextToSpeechModelId,
} from "./hedra_tts.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const FAL_KEY = Deno.env.get("FAL_KEY") ?? "";
const HEDRA_API_KEY = Deno.env.get("HEDRA_API_KEY") ?? "";
const HEDRA_API_BASE = "https://api.hedra.com/web-app/public";
const HEDRA_AVATAR_MODEL_ID = Deno.env.get("HEDRA_AVATAR_MODEL_ID") ??
  "26f0fc66-152b-40ab-abed-76c43df99bc8";
const HEDRA_VOICE_ID = Deno.env.get("HEDRA_VOICE_ID") ?? "";
const HEDRA_TTS_MODEL_ID = Deno.env.get("HEDRA_TTS_MODEL_ID") ?? "";

// Dark War風 広告テンプレート定義
const AD_TEMPLATES = {
  dark_war: {
    name: "Dark War風 バトル広告",
    description: "21の競合SaaSと「戦う」スタイルのインパクト動画",
    script: {
      ja: [
        "⚔️ 21のSaaSアプリが、あなたの時間と金を奪っている。",
        "Notion、Slack、MoneyForward、X...",
        "もう終わりにしよう。",
        "自分株式会社 — すべてを1つに。",
        "無料で始める → https://my-web-app-b67f4.web.app/",
      ],
      en: [
        "⚔️ 21 SaaS apps are stealing your time and money.",
        "Notion, Slack, MoneyForward, X...",
        "It ends now.",
        "自分株式会社 — All in one.",
        "Start free → https://my-web-app-b67f4.web.app/",
      ],
    },
    imagePrompt:
      "Epic dark cinematic battle scene, glowing UI interfaces floating in space, apps converging into one powerful orb, dramatic lighting, cyberpunk aesthetic, 16:9 aspect ratio",
    hashtags: ["#buildinpublic", "#FlutterWeb", "#Supabase", "#SaaS"],
  },
  feature_highlight: {
    name: "機能ハイライト広告",
    description: "実装済み機能のスピードショーケース",
    script: {
      ja: [
        "📱 1つのアプリで何ができるか？",
        "AI秘書、家計管理、ノート、SNS、タスク管理...",
        "しかも全部無料。",
        "自分株式会社 — あなたの人生を1画面で。",
        "今すぐ試す → https://my-web-app-b67f4.web.app/",
      ],
      en: [
        "📱 What can one app do?",
        "AI secretary, finance, notes, SNS, tasks...",
        "And it's all free.",
        "自分株式会社 — Your life, one screen.",
        "Try now → https://my-web-app-b67f4.web.app/",
      ],
    },
    imagePrompt:
      "Clean modern app interface collage, multiple feature screens arranged in elegant grid, gradient purple background, material design, 16:9",
    hashtags: ["#ProductHunt", "#IndieHacker", "#FlutterApp"],
  },
  mobile_ux_validation: {
    name: "スマホアプリUX検証動画",
    description: "動くスマホアプリの体験検証を短尺動画にする",
    script: {
      ja: [
        "動くスマホアプリUX検証動画「マイファイナンス」",
        "資産・支出・KGI/CSF/KPIを一画面で確認。",
        "お金の浪費を減らし、判断を能力投資へ戻す。",
        "GPT image2 → GPT-5.5 → Seedance 2.0 の流れで制作。",
        "https://my-web-app-b67f4.web.app/asset-management",
      ],
      en: [
        "Mobile UX validation video: My Finance.",
        "Track assets, spending, and KPI decisions in one screen.",
        "Reduce waste and redirect money into capability.",
        "Produced with GPT image2 -> GPT-5.5 -> Seedance 2.0.",
        "https://my-web-app-b67f4.web.app/asset-management",
      ],
    },
    imagePrompt:
      "A polished moving smartphone app UX validation storyboard for a Japanese personal finance app called My Finance, mobile screens, tap gestures, spending alerts, asset dashboard, clean fintech UI, 16:9",
    hashtags: ["#AI動画", "#FlutterWeb", "#資産管理", "#buildinpublic"],
  },
  user_growth: {
    name: "ユーザー成長ストーリー",
    description: "登録者数増加の軌跡を見せるバイラル動画",
    script: {
      ja: [
        "🚀 0人から始めた。",
        "毎日コードを書いた。",
        "Claude CodeとSupabaseだけで。",
        "今、4人が使っている。次はあなた。",
        "自分株式会社 → https://my-web-app-b67f4.web.app/",
      ],
      en: [
        "🚀 Started from zero.",
        "Coded every single day.",
        "Just Claude Code and Supabase.",
        "4 people use it now. You're next.",
        "自分株式会社 → https://my-web-app-b67f4.web.app/",
      ],
    },
    imagePrompt:
      "Minimalist growth chart animation, single developer at desk, code flying around, user count increasing, warm inspiring colors, 16:9",
    hashtags: ["#buildinpublic", "#solofounder", "#indiedev"],
  },
  competitor_comparison: {
    name: "競合比較広告",
    description: "vs 21競合の料金・機能比較でお得感を訴求",
    script: {
      ja: [
        "💸 Notion ¥1,500/月 + Slack ¥850/月 + MoneyForward ¥500/月...",
        "合計 → 毎月 ¥10,000以上。",
        "自分株式会社 → ¥0。",
        "今すぐ乗り換える → https://my-web-app-b67f4.web.app/",
      ],
      en: [
        "💸 Notion $10/mo + Slack $7.25/mo + more...",
        "Total → $100+/month.",
        "自分株式会社 → $0.",
        "Switch now → https://my-web-app-b67f4.web.app/",
      ],
    },
    imagePrompt:
      "Price comparison infographic, competitor logos with red X marks, self app with green checkmark, money savings visualization, 16:9",
    hashtags: ["#freetool", "#productivity", "#nocode"],
  },
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "templates") {
        const templates = Object.entries(AD_TEMPLATES).map(([key, t]) => ({
          key,
          name: t.name,
          description: t.description,
          hashtags: t.hashtags,
        }));
        return jsonRes({ success: true, templates });
      }

      if (view === "history") {
        const { data } = await admin
          .from("viral_ad_generations")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(20);
        return jsonRes({ success: true, history: data ?? [] });
      }

      return jsonRes({
        success: true,
        templates: Object.keys(AD_TEMPLATES),
        message: "Use ?view=templates or POST to generate",
      });
    }

    if (req.method !== "POST") {
      return jsonRes({ error: "Method not allowed" }, 405);
    }

    const body = await req.json().catch(() => ({})) as {
      type?: string;
      template?: string;
      lang?: string;
      customPrompt?: string;
      customScript?: string[];
      customHashtags?: string[];
      title?: string;
      voice?: string;
      imageUrl?: string;
      generatedImageUrl?: string;
      hedraGenerationId?: string;
      preferredModel?: string;
      creativePipeline?: string[];
    };

    const templateKey = body.template ?? "dark_war";
    const lang = (body.lang ?? "ja") as "ja" | "en";
    const type = body.type ?? "image";
    const preferredModel = typeof body.preferredModel === "string" &&
        body.preferredModel.trim().length > 0
      ? body.preferredModel.trim()
      : null;
    const creativePipeline = Array.isArray(body.creativePipeline)
      ? body.creativePipeline.map((step) => String(step).trim()).filter((
        step,
      ) => step.length > 0).slice(0, 8)
      : [];

    const template = AD_TEMPLATES[templateKey as keyof typeof AD_TEMPLATES];
    if (!template) {
      return jsonRes({
        error: `Unknown template: ${templateKey}. Available: ${
          Object.keys(AD_TEMPLATES).join(", ")
        }`,
      }, 400);
    }

    const script =
      Array.isArray(body.customScript) && body.customScript.length > 0
        ? body.customScript.map((line) => String(line).trim()).filter((line) =>
          line.length > 0
        ).slice(0, 6)
        : template.script[lang];
    const hashtags =
      Array.isArray(body.customHashtags) && body.customHashtags.length > 0
        ? body.customHashtags.map((tag) => String(tag).trim()).filter((tag) =>
          tag.length > 0
        ).slice(0, 6)
        : template.hashtags;
    const caption = script.join("\n") + "\n\n" + hashtags.join(" ");
    const imagePrompt = body.customPrompt ?? template.imagePrompt;

    let generatedImageUrl: string | null = null;
    let generatedVideoUrl: string | null = null;
    let generatedPreviewUrl: string | null = null;
    let generatedDownloadUrl: string | null = null;
    let falJobId: string | null = null;
    let videoProvider: string | null = null;
    let videoStatus: string | null = null;
    let videoReason: string | null = null;
    let hedraGenerationId: string | null = null;
    let hedraProgress: number | null = null;
    let hedraEtaSec: number | null = null;

    // FAL.ai で画像生成 (キーが設定されている場合)
    if (FAL_KEY && type === "image") {
      try {
        const falResp = await fetch("https://fal.run/fal-ai/flux/schnell", {
          method: "POST",
          headers: {
            "Authorization": `Key ${FAL_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            prompt: imagePrompt,
            image_size: "landscape_16_9",
            num_inference_steps: 4,
            num_images: 1,
            enable_safety_checker: true,
          }),
        });

        if (falResp.ok) {
          const falData = await falResp.json() as {
            images?: Array<{ url: string }>;
            request_id?: string;
          };
          generatedImageUrl = falData.images?.[0]?.url ?? null;
          falJobId = falData.request_id ?? null;
        }
      } catch (_e) {
        // FAL.ai失敗時はスクリプトのみ返す
      }
    }

    if (type === "presenter_video") {
      if (!HEDRA_API_KEY) {
        videoProvider = "hedra";
        videoStatus = "fallback_text";
        videoReason = "HEDRA_API_KEY not configured";
      } else {
        try {
          const existingGenerationId = firstNonEmptyString(
            body.hedraGenerationId,
          );
          const hedraVideo = existingGenerationId
            ? await getHedraGenerationStatus(
              HEDRA_API_KEY,
              existingGenerationId,
            )
            : await createHedraPresenterVideo({
              apiKey: HEDRA_API_KEY,
              script,
              title: body.title ?? template.name,
              prompt: imagePrompt,
              voice: body.voice ?? defaultVoiceForLang(lang),
              imageUrl: firstNonEmptyString(
                body.imageUrl,
                body.generatedImageUrl,
              ),
              lang,
            });
          generatedVideoUrl = hedraVideo.videoUrl;
          generatedPreviewUrl = hedraVideo.previewUrl;
          generatedDownloadUrl = hedraVideo.downloadUrl;
          videoProvider = "hedra";
          videoStatus = hedraVideo.status;
          videoReason = hedraVideo.reason;
          hedraGenerationId = hedraVideo.id;
          hedraProgress = hedraVideo.progress;
          hedraEtaSec = hedraVideo.etaSec;
          if (!generatedVideoUrl) {
            videoReason = videoReason ?? "Hedra video is not complete yet";
          }
        } catch (error) {
          videoProvider = "hedra";
          videoStatus = "fallback_text";
          videoReason = error instanceof Error ? error.message : String(error);
        }
      }
    }

    const generationStatus = generatedVideoUrl != null
      ? "video_ready"
      : generatedImageUrl != null
      ? "ready"
      : type === "presenter_video" && videoStatus != null
      ? videoStatus
      : "script_only";

    // 生成履歴をDBに記録
    let recordId: string | null = null;
    try {
      const { data: inserted } = await admin
        .from("viral_ad_generations")
        .insert({
          template_key: templateKey,
          lang,
          type,
          script: JSON.stringify(script),
          caption,
          image_prompt: imagePrompt,
          generated_image_url: generatedImageUrl,
          generated_video_url: generatedVideoUrl,
          generated_preview_url: generatedPreviewUrl,
          generated_download_url: generatedDownloadUrl,
          fal_job_id: falJobId,
          hashtags,
          video_provider: videoProvider,
          video_status: videoStatus,
          video_reason: videoReason,
          status: generationStatus,
        })
        .select("id")
        .single();
      recordId = inserted?.id ?? null;
    } catch (_e) {
      // テーブル未作成の場合は続行
    }

    return jsonRes({
      success: true,
      id: recordId,
      template: templateKey,
      lang,
      type,
      preferredModel,
      creativePipeline,
      caption,
      script,
      hashtags,
      imagePrompt,
      generatedImageUrl,
      generatedVideoUrl,
      generatedPreviewUrl,
      generatedDownloadUrl,
      hedraGenerationId,
      hedraProgress,
      hedraEtaSec,
      falJobId,
      videoProvider,
      videoStatus,
      videoReason,
      status: generatedVideoUrl != null || generatedImageUrl != null
        ? "ready_to_post"
        : generationStatus,
      nextStep: generatedVideoUrl != null
        ? "Call x-media-post with this videoUrl and caption to post to X"
        : generatedImageUrl != null
        ? "Call x-media-post with this imageUrl and caption to post to X"
        : hedraGenerationId != null
        ? "Hedra generation is still processing. Poll again with hedraGenerationId."
        : type === "presenter_video"
        ? "Hedra video generation is unavailable. Use the caption for text-only X post or retry after checking HEDRA_API_KEY."
        : "FAL_KEY not set or generation failed. Use caption for text-only X post via post-x-update",
      textPost: {
        endpoint: "post-x-update",
        body: { text: caption.slice(0, 280) },
      },
    });
  } catch (e) {
    return jsonRes({ error: String(e) }, 500);
  }
});

function jsonRes(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function defaultVoiceForLang(lang: "ja" | "en"): string {
  return lang === "en" ? "en-US" : "ja-JP";
}

function hedraLanguageForLang(_lang: "ja" | "en"): string {
  // Hedra TTS currently rejects "ja" / "Japanese"; use a supported enum value.
  return "English";
}

function scriptForHedraVoice(
  script: string[],
  lang: "ja" | "en",
  title?: string,
): string[] {
  if (lang === "en") return script;
  const englishTitle = hedraEnglishTitle(title);
  const url = script.find((line) => /^https?:\/\//.test(line));
  return [
    `${englishTitle} has been updated.`,
    "This short video introduces the newest improvement in the app.",
    "The creative workflow combines GPT image two, GPT five point five, and Seedance two point zero.",
    url == null
      ? "Open the app to try the latest experience."
      : `Open ${url.replace(/^https?:\/\//, "")} to try it.`,
  ];
}

function hedraEnglishTitle(title?: string): string {
  const trimmed = title?.trim();
  if (!trimmed) return "This app";
  if (trimmed === "マイファイナンス") return "My Finance";
  const isAscii = [...trimmed].every((char) => char.charCodeAt(0) <= 127);
  return isAscii ? trimmed : "This app";
}

type HedraVideoResult = {
  id: string | null;
  status: string;
  videoUrl: string | null;
  previewUrl: string | null;
  downloadUrl: string | null;
  progress: number | null;
  etaSec: number | null;
  reason: string | null;
};

async function createHedraPresenterVideo(params: {
  apiKey: string;
  script: string[];
  title?: string;
  prompt: string;
  voice: string;
  imageUrl: string | null;
  lang: "ja" | "en";
}): Promise<HedraVideoResult> {
  const rawImageUrl = firstNonEmptyString(params.imageUrl);
  if (!rawImageUrl) {
    throw new Error("Hedra avatar video requires imageUrl");
  }
  const imageUrl = normalizeHedraStartKeyframeUrl(rawImageUrl);
  if (!imageUrl) {
    throw new Error(
      "Hedra avatar image must be a public http(s) URL under 2083 characters. Regenerate the share image so it can be stored before video generation.",
    );
  }

  const voiceId = await resolveHedraVoiceId(
    params.apiKey,
    params.voice,
    params.lang,
  );
  const ttsModelId = resolveConfiguredHedraTextToSpeechModelId(
    HEDRA_TTS_MODEL_ID,
  );
  const hedraLanguage = hedraLanguageForLang(params.lang);
  const ttsScript = scriptForHedraVoice(
    params.script,
    params.lang,
    params.title,
  )
    .join("\n");
  const generationBody: Record<string, unknown> = {
    type: "video",
    ai_model_id: HEDRA_AVATAR_MODEL_ID,
    start_keyframe_url: imageUrl,
    audio_generation: buildHedraTextToSpeechAudioGeneration({
      voiceId,
      modelId: ttsModelId,
      text: ttsScript.slice(0, 1800),
      language: hedraLanguage,
    }),
    generated_video_inputs: {
      text_prompt: `${params.title ?? "Share update"}\n${params.prompt}`,
      aspect_ratio: "16:9",
      resolution: "540p",
      enhance_prompt: true,
    },
  };
  const payload = await createHedraGenerationWithTtsModelFallback(
    params.apiKey,
    generationBody,
    ttsModelId != null,
  );
  return await pollHedraGeneration(
    params.apiKey,
    normalizeHedraVideoResponse(payload),
  );
}

async function createHedraGenerationWithTtsModelFallback(
  apiKey: string,
  body: Record<string, unknown>,
  canRetryWithoutTtsModel: boolean,
): Promise<unknown> {
  try {
    return await hedraJsonRequest(apiKey, "/generations", {
      method: "POST",
      body,
    });
  } catch (error) {
    if (
      !canRetryWithoutTtsModel ||
      !isHedraInvalidTextToSpeechModelError(error)
    ) {
      throw error;
    }

    return await hedraJsonRequest(apiKey, "/generations", {
      method: "POST",
      body: stripHedraTextToSpeechModelId(body),
    });
  }
}

async function getHedraGenerationStatus(
  apiKey: string,
  generationId: string,
): Promise<HedraVideoResult> {
  const payload = await hedraJsonRequest(
    apiKey,
    `/generations/${encodeURIComponent(generationId)}/status`,
  );
  const normalized = normalizeHedraVideoResponse(payload);
  return { ...normalized, id: normalized.id ?? generationId };
}

async function pollHedraGeneration(
  apiKey: string,
  initial: HedraVideoResult,
): Promise<HedraVideoResult> {
  let current = initial;
  const generationId = current.id;
  if (!generationId || isHedraTerminal(current)) return current;
  for (const delayMs of [3000, 5000, 8000, 10000, 10000]) {
    await delay(delayMs);
    current = await getHedraGenerationStatus(apiKey, generationId);
    if (isHedraTerminal(current)) return current;
  }
  return current;
}

function isHedraTerminal(result: HedraVideoResult): boolean {
  if (result.videoUrl || result.downloadUrl) return true;
  return ["complete", "completed", "failed", "error", "canceled", "cancelled"]
    .includes(
      result.status.toLowerCase(),
    );
}

async function resolveHedraVoiceId(
  apiKey: string,
  preferredVoice: string,
  lang: "ja" | "en",
): Promise<string> {
  const configured = firstNonEmptyString(HEDRA_VOICE_ID);
  if (configured && isUuid(configured)) return configured;
  if (isUuid(preferredVoice)) return preferredVoice;

  const payload = await hedraJsonRequest(apiKey, "/voices", { method: "GET" });
  const voices = Array.isArray(payload)
    ? payload
    : Array.isArray(asRecord(payload)?.["data"])
    ? asRecord(payload)?.["data"] as unknown[]
    : [];
  const hedraLanguage = hedraLanguageForLang(lang).toLowerCase();
  const languageMarkers = hedraLanguage === "english"
    ? ["en", "english"]
    : [hedraLanguage];
  const languageMatch = voices
    .map((voice) => asRecord(voice))
    .find((voice) => {
      const haystack = `${voice?.["name"] ?? ""} ${
        voice?.["description"] ?? ""
      }`.toLowerCase();
      return languageMarkers.some((marker) =>
        haystack.includes(marker.toLowerCase())
      );
    });
  const fallbackVoice = voices.map((voice) => asRecord(voice)).find((voice) =>
    voice?.["id"]
  );
  const voiceId = firstNonEmptyString(
    languageMatch?.["id"],
    fallbackVoice?.["id"],
  );
  if (!voiceId) {
    throw new Error("Hedra voice_id could not be resolved");
  }
  return voiceId;
}

async function hedraJsonRequest(
  apiKey: string,
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<unknown> {
  const response = await fetch(`${HEDRA_API_BASE}${path}`, {
    method: init.method ?? "GET",
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": apiKey,
    },
    body: init.body == null ? undefined : JSON.stringify(init.body),
  });
  const rawText = await response.text();
  let parsed: unknown = {};
  if (rawText.trim().length > 0) {
    try {
      parsed = JSON.parse(rawText) as unknown;
    } catch {
      parsed = { raw: rawText };
    }
  }

  if (!response.ok) {
    const parsedRecord = asRecord(parsed);
    const message = firstNonEmptyString(
      parsedRecord?.["error"],
      parsedRecord?.["error_message"],
      parsedRecord?.["message"],
      parsedRecord?.["detail"],
      rawText,
    ) ?? `Hedra request failed with status ${response.status}`;
    throw new Error(`Hedra API ${response.status}: ${message}`);
  }

  return parsed;
}

function normalizeHedraVideoResponse(payload: unknown): HedraVideoResult {
  const record = asRecord(payload) ?? {};
  const video = asRecord(record["video"]);
  const result = asRecord(record["result"]);
  const batchResults = Array.isArray(record["batch_results"])
    ? record["batch_results"]
    : [];
  const firstBatchResult = asRecord(batchResults[0]);
  const asset = asRecord(record["asset"]);
  return {
    id: firstNonEmptyString(
      record["id"],
      record["generation_id"],
      record["video_id"],
      firstBatchResult?.["id"],
      video?.["id"],
      result?.["id"],
    ),
    status: firstNonEmptyString(
      record["status"],
      firstBatchResult?.["status"],
      video?.["status"],
      result?.["status"],
    ) ?? "submitted",
    videoUrl: firstNonEmptyString(
      record["download_url"],
      record["url"],
      record["video_url"],
      asset?.["url"],
      video?.["url"],
      video?.["download_url"],
      result?.["url"],
      result?.["download_url"],
    ),
    previewUrl: firstNonEmptyString(
      record["preview_url"],
      record["streaming_url"],
      record["thumbnail_url"],
      video?.["preview_url"],
      result?.["preview_url"],
    ),
    downloadUrl: firstNonEmptyString(
      record["download_url"],
      video?.["download_url"],
      result?.["download_url"],
    ),
    progress: firstNumber(
      record["progress"],
      firstBatchResult?.["progress"],
      result?.["progress"],
    ),
    etaSec: firstNumber(record["eta_sec"], result?.["eta_sec"]),
    reason: firstNonEmptyString(
      record["error_message"],
      record["error"],
      firstBatchResult?.["error"],
      result?.["error_message"],
      result?.["error"],
    ),
  };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isUuid(value: string | null): boolean {
  return value != null &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null
    ? value as Record<string, unknown>
    : null;
}

function firstNonEmptyString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function normalizeHedraStartKeyframeUrl(value: string | null): string | null {
  if (!value) return null;
  if (value.length > 2083) return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" || parsed.protocol === "http:"
      ? value
      : null;
  } catch {
    return null;
  }
}

function firstNumber(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim().length > 0) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) return parsed;
    }
  }
  return null;
}
