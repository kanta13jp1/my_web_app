// viral-video-ad-generator Edge Function
// Dark War風バイラル動画広告生成パイプライン
//
// 機能:
// - FAL.ai (fast-sdxl) を使った広告画像生成
// - Hedra を使ったプレゼンター動画生成
// - fal.ai text-to-video (Veo/Kling 等) を使ったシネマティック動画生成
// - 自分株式会社の「21の競合を超える」ストーリーを動画化
// - 生成したメディアをSupabase Storageに保存
// - X投稿用の動画URL + キャプションを返す
//
// POST { "type": "image" | "presenter_video" | "cinematic_video" | "video_script", "template": "dark_war" | "feature_highlight" | "mobile_ux_validation" | "user_growth" | "ai_secretary_site_tour", "lang": "ja" | "en" }
// GET  ?view=templates | ?view=history

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildHedraTextToSpeechAudioGeneration,
  buildHedraUploadedAudioGeneration,
  isHedraInvalidTextToSpeechModelError,
  isHedraMissingTextToSpeechModelError,
  isHedraUploadedAudioUnsupportedError,
  resolveConfiguredHedraTextToSpeechModelId,
  selectBestHedraTextToSpeechModelId,
  selectBestHedraVoiceId,
  stripHedraTextToSpeechModelId,
  withHedraTextToSpeechModelId,
} from "./hedra_tts.ts";
import {
  resolveElevenLabsVoiceId,
  voiceGenderForLabel,
} from "./voice_labels.ts";
import { applyTtsReadings } from "./tts_reading_lexicon.ts";
import {
  buildFalTextToVideoPayload,
  DEFAULT_FAL_TEXT_TO_VIDEO_MODEL,
  extractFalVideoUrl,
  getFalQueueRequestResult,
  getFalQueueRequestStatus,
  isFalExhaustedBalanceError,
  resolveFalApiKey,
  submitFalTextToVideoJob,
} from "./fal_video.ts";
import {
  buildCaptionSrt,
  buildForceStyle,
  burnCaptionsViaTranscoder,
  type CaptionStyle,
  type CaptionTimingConfig,
  DEFAULT_CAPTION_STYLE,
  DEFAULT_CAPTION_TIMING,
} from "./captions.ts";
import {
  type HedraBatchVariant,
  normalizeHedraBatchResponse,
  parseHedraBatchSize,
  parseHedraGenerationIds,
  withHedraBatchSize,
} from "./hedra_batch.ts";
import {
  parseHedraAudioStartMs,
  withHedraAudioStartMs,
} from "./hedra_audio_start.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
// FAL_KEY / FAL_API_KEY のどちらで登録されていても解決する (詳細は fal_video.ts)。
const FAL_KEY = resolveFalApiKey((name) => Deno.env.get(name));
// type=cinematic_video 用の fal.ai text-to-video モデル。secret で
// Veo/Kling/Seedance 等の任意の fal ホストモデルへ差し替え可能。
const FAL_TEXT_TO_VIDEO_MODEL = Deno.env.get("FAL_TEXT_TO_VIDEO_MODEL") ??
  DEFAULT_FAL_TEXT_TO_VIDEO_MODEL;
// モデル固有パラメータ(duration/resolution 等)の JSON 上書き。省略可。
const FAL_TEXT_TO_VIDEO_PARAMS = Deno.env.get("FAL_TEXT_TO_VIDEO_PARAMS") ??
  "";
const HEDRA_API_KEY = Deno.env.get("HEDRA_API_KEY") ?? "";
const HEDRA_API_BASE = "https://api.hedra.com/web-app/public";
// 読み上げ台本(spokenScript)の最大文字数。Hedra の動画生成は台本長に比例して
// 長くなり、長すぎるとワンボタン投稿のクライアント側ポーリング内に完成せず静止画で
// 投稿されてしまう。実測: 145 字は video_ready 到達 / 685 字は processing 滞留。
// 全 TTS 経路(主 ElevenLabs / fallback voice / OpenAI / Hedra native / fallbackText)を
// この単一上限で統一し、どの経路でも短尺動画を保証する。client 側 _maxNarrationChars と同値。
const MAX_SPOKEN_CHARS = 450;
const HEDRA_AVATAR_MODEL_ID = Deno.env.get("HEDRA_AVATAR_MODEL_ID") ??
  "26f0fc66-152b-40ab-abed-76c43df99bc8";
const HEDRA_VOICE_ID = Deno.env.get("HEDRA_VOICE_ID") ?? "";
const HEDRA_TTS_MODEL_ID = Deno.env.get("HEDRA_TTS_MODEL_ID") ?? "";
const HEDRA_UPLOADED_AUDIO_ENABLED = envFlag(
  Deno.env.get("HEDRA_UPLOADED_AUDIO_ENABLED"),
);
const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
const ELEVENLABS_MODEL_ID = Deno.env.get("ELEVENLABS_MODEL_ID") ??
  "eleven_multilingual_v2";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const OPENAI_TTS_MODEL = Deno.env.get("OPENAI_TTS_MODEL") ??
  "gpt-4o-mini-tts";
const OPENAI_TTS_VOICE = Deno.env.get("OPENAI_TTS_VOICE") ?? "nova";
const ELEVENLABS_DEFAULT_FEMALE_VOICE_ID = "21m00Tcm4TlvDq8ikWAM";
const ELEVENLABS_FALLBACK_VOICE_ID =
  Deno.env.get("ELEVENLABS_FALLBACK_VOICE_ID") ??
    ELEVENLABS_DEFAULT_FEMALE_VOICE_ID;
const ELEVENLABS_AI_SECRETARY_VOICE_ID =
  Deno.env.get("ELEVENLABS_AI_SECRETARY_VOICE_ID") ??
    Deno.env.get("ELEVENLABS_SECRETARY_VOICE_ID") ??
    Deno.env.get("ELEVENLABS_VOICE_ID") ??
    ELEVENLABS_DEFAULT_FEMALE_VOICE_ID;
// presenter が男性キャラの時に使う成人男性ナレーター。ElevenLabs 標準の "Daniel"
// を既定にしているので、追加の secret 設定なしでも映像(男性)と音声が一致する。
const ELEVENLABS_MALE_VOICE_ID = Deno.env.get("ELEVENLABS_VOICE_MALE_ID") ??
  "onwK4e9ZLuTAKqWW03F9";
const VIRAL_VIDEO_BUCKET = "viral-ad-videos";

// --- On-screen caption burn-in (H3 / muted-autoplay dwell time) ---------------
// muted-autoplay の X 視聴者向けに、生成済み presenter 動画へ字幕を焼き込む。
// Deno EF は ffmpeg を実行できないため外部のホスト型トランスコーダへ委譲する。
// 全 env が揃わない/どこかで失敗したら必ず素の mp4 へフォールバックし、投稿を
// 絶対にブロックしない (= 既存 fallback_text と同じ graceful-degradation)。
// 既定は OFF。Supabase secrets に以下を設定して初めて有効化される:
//   VVAG_BURN_CAPTIONS=1
//   VVAG_CAPTION_TRANSCODER_URL=<ffmpeg burn-in service endpoint>
//   VVAG_CAPTION_TRANSCODER_KEY=<service api key>  (認証不要なサービスなら省略可)
const VVAG_BURN_CAPTIONS = envFlag(Deno.env.get("VVAG_BURN_CAPTIONS"));
const VVAG_CAPTION_TRANSCODER_URL =
  Deno.env.get("VVAG_CAPTION_TRANSCODER_URL") ?? "";
const VVAG_CAPTION_TRANSCODER_KEY =
  Deno.env.get("VVAG_CAPTION_TRANSCODER_KEY") ?? "";
const VVAG_CAPTION_TIMEOUT_MS = positiveNumberEnv(
  "VVAG_CAPTION_TIMEOUT_MS",
  45000,
);

// Flutter が送る voice ラベル(gender: "male_narrator"/"female_narrator" /
// tone: "energetic_*"/"calm_*")を ElevenLabs の voiceId に解決する。トーン別
// secret が設定されていればそれを、無ければ性別ベース音声(#3794 と同一)を返す。
function resolveElevenLabsVoiceForLabel(
  voiceLabel: string | undefined,
): string {
  return resolveElevenLabsVoiceId({
    voiceLabel,
    femaleBaseVoiceId: ELEVENLABS_AI_SECRETARY_VOICE_ID,
    maleBaseVoiceId: ELEVENLABS_MALE_VOICE_ID,
    env: (name) => Deno.env.get(name),
  });
}

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
  ai_secretary_site_tour: {
    name: "AI secretary site tour",
    description:
      "Intelligent female AI secretary presenter explains concrete site features without reading the URL aloud.",
    script: {
      ja: [
        "はじめまして。知的で上品なAI秘書として、このサイトの使い方をご案内します。",
        "まずはサイト案内AIに聞くと、迷わず必要な機能へ進めます。",
        "AI大学では、AI企業、最新ニュース、プロンプト活用を体系的に学べます。",
        "ノート、資産管理、英語学習、リリースノートを、ひとつの作業空間でつなげます。",
        "5分だけ試して、役に立つ点と迷った点を教えてください。",
      ],
      en: [
        "Hello. I am your intelligent AI executive secretary for this site tour.",
        "Start with Site Guide AI when you are not sure where to go.",
        "AI University helps you learn AI companies, news, and prompt workflows.",
        "Notes, finance, English learning, and release notes connect in one workspace.",
        "Try it for five minutes and tell us what helped or confused you.",
      ],
    },
    imagePrompt:
      "High-quality 16:9 product tour video key visual. An intelligent adult female AI executive secretary in a tasteful dark suit explains a premium SaaS cockpit. Show concrete app panels for Site Guide AI, AI secretary, AI University, notes, asset management, English reading dashboard, release notes, and supporter checkout. Refined, professional, brand-safe, no nudity, no explicit sexualization, no random text overlays, no URL text.",
    hashtags: ["#buildinpublic", "#FlutterWeb", "#Supabase", "#AI"],
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

function stripSpokenUrls(line: string): string {
  return line
    .replace(/https?:\/\/\S+/gi, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function normalizeSpokenLine(line: string): string {
  let cleaned = stripSpokenUrls(line)
    .replace(/^[\s、。,.・:：;；!！?？-]+/u, "")
    .trim();
  cleaned = cleaned.replace(/^(?:を|へ|に|で|から|まで)\s*/u, "").trim();
  if (/^5分/.test(cleaned)) {
    return `このサイトを${cleaned}`;
  }
  return cleaned;
}

function sanitizeScriptForTemplate(
  templateKey: string,
  lines: string[],
): string[] {
  if (templateKey !== "ai_secretary_site_tour") return lines;
  const cleaned = lines.map(normalizeSpokenLine).filter((line) =>
    line.length > 0
  );
  return cleaned.length > 0
    ? cleaned
    : AD_TEMPLATES.ai_secretary_site_tour.script.ja;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const accessToken = bearerToken(req.headers.get("Authorization"));
    if (!accessToken) {
      return jsonRes({ error: "Authentication required" }, 401);
    }
    const { data: authData, error: authError } = await admin.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return jsonRes({ error: "Invalid authentication" }, 401);
    }
    const authenticatedUserId = authData.user.id;

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
          .eq("user_id", authenticatedUserId)
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
      hedraGenerationIds?: string[];
      hedraBatchGenerationId?: string;
      batchSize?: number;
      confirmBatchCost?: boolean;
      audioStartMs?: number;
      falRequestId?: string;
      preferredModel?: string;
      creativePipeline?: string[];
    };

    const templateKey = body.template ?? "dark_war";
    const lang = (body.lang ?? "ja") as "ja" | "en";
    const type = body.type ?? "image";
    let hedraAudioStartMs: number;
    try {
      hedraAudioStartMs = parseHedraAudioStartMs(body.audioStartMs);
    } catch (error) {
      return jsonRes({ error: String(error) }, 400);
    }
    if (type !== "presenter_video" && hedraAudioStartMs !== 0) {
      return jsonRes({
        error: "audioStartMs is supported only for presenter_video",
      }, 400);
    }
    let hedraBatchSize: number;
    try {
      hedraBatchSize = parseHedraBatchSize(body.batchSize);
    } catch (error) {
      return jsonRes({ error: String(error) }, 400);
    }
    if (type !== "presenter_video" && hedraBatchSize !== 1) {
      return jsonRes({
        error: "batchSize is supported only for presenter_video",
      }, 400);
    }
    let requestedHedraGenerationIds = parseHedraGenerationIds(
      body.hedraGenerationIds,
    );
    const requestedHedraBatchGenerationId = firstNonEmptyString(
      body.hedraBatchGenerationId,
    );
    const isHedraBatchStatusPoll = requestedHedraBatchGenerationId != null ||
      requestedHedraGenerationIds.length > 0;
    if (
      hedraBatchSize > 1 && !isHedraBatchStatusPoll &&
      body.confirmBatchCost !== true
    ) {
      return jsonRes({
        error:
          "confirmBatchCost=true is required when batchSize is greater than 1",
      }, 400);
    }
    if (isHedraBatchStatusPoll) {
      if (
        requestedHedraBatchGenerationId == null ||
        requestedHedraBatchGenerationId.length > 200
      ) {
        return jsonRes({
          error: "hedraBatchGenerationId is required for batch polling",
        }, 400);
      }
      const { data: ownedBatch, error: ownedBatchError } = await admin
        .from("viral_ad_generations")
        .select("batch_size,batch_results")
        .eq("user_id", authenticatedUserId)
        .eq("batch_generation_id", requestedHedraBatchGenerationId)
        .maybeSingle();
      if (ownedBatchError || !ownedBatch) {
        return jsonRes({ error: "Hedra batch group not found" }, 404);
      }
      const storedBatch = normalizeHedraBatchResponse({
        batch_size: ownedBatch.batch_size,
        batch_results: ownedBatch.batch_results,
      });
      requestedHedraGenerationIds = storedBatch.generationIds;
      hedraBatchSize = parseHedraBatchSize(ownedBatch.batch_size);
      if (requestedHedraGenerationIds.length === 0) {
        return jsonRes(
          { error: "Hedra batch group has no generation IDs" },
          409,
        );
      }
    }
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

    const rawScript =
      Array.isArray(body.customScript) && body.customScript.length > 0
        ? body.customScript.map((line) => String(line).trim()).filter((line) =>
          line.length > 0
        ).slice(0, 6)
        : template.script[lang];
    const script = sanitizeScriptForTemplate(templateKey, rawScript);
    const hashtags =
      Array.isArray(body.customHashtags) && body.customHashtags.length > 0
        ? body.customHashtags.map((tag) => String(tag).trim()).filter((tag) =>
          tag.length > 0
        ).slice(0, 6)
        : template.hashtags;
    const caption = script.join("\n") + "\n\n" + hashtags.join(" ");
    const imagePrompt = body.customPrompt ?? template.imagePrompt;

    let generatedImageUrl: string | null = type === "presenter_video"
      ? firstNonEmptyString(body.generatedImageUrl, body.imageUrl)
      : null;
    let generatedVideoUrl: string | null = null;
    let generatedPreviewUrl: string | null = null;
    let generatedDownloadUrl: string | null = null;
    let falJobId: string | null = null;
    let videoProvider: string | null = null;
    let videoStatus: string | null = null;
    let videoReason: string | null = null;
    let storedVideoUrl: string | null = null;
    let storedVideoPath: string | null = null;
    let storedAudioUrl: string | null = null;
    let storedAudioPath: string | null = null;
    let videoAudioProvider: string | null = null;
    let hedraGenerationId: string | null = null;
    let hedraBatchGenerationId: string | null = null;
    let hedraGenerationIds: string[] = [];
    let hedraBatchResults: HedraBatchVariant[] = [];
    let hedraProgress: number | null = null;
    let hedraEtaSec: number | null = null;
    let captionStatus: string | null = null;
    let captionReason: string | null = null;

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
          const hedraVideo = isHedraBatchStatusPoll
            ? await getHedraBatchGenerationStatus(
              HEDRA_API_KEY,
              requestedHedraGenerationIds,
              requestedHedraBatchGenerationId,
              hedraBatchSize,
            )
            : existingGenerationId
            ? await getHedraGenerationStatus(
              HEDRA_API_KEY,
              existingGenerationId,
            )
            : await createHedraPresenterVideo({
              apiKey: HEDRA_API_KEY,
              admin,
              script,
              title: body.title ?? template.name,
              prompt: imagePrompt,
              voice: body.voice ?? defaultVoiceForLang(lang),
              imageUrl: firstNonEmptyString(
                body.imageUrl,
                body.generatedImageUrl,
              ),
              lang,
              requiresUploadedAudio: templateKey === "ai_secretary_site_tour",
              batchSize: hedraBatchSize,
              audioStartMs: hedraAudioStartMs,
            });
          generatedVideoUrl = hedraVideo.videoUrl;
          generatedPreviewUrl = hedraVideo.previewUrl;
          generatedDownloadUrl = hedraVideo.downloadUrl;
          videoProvider = "hedra";
          videoStatus = hedraVideo.status;
          videoReason = hedraVideo.reason;
          storedAudioUrl = hedraVideo.storedAudioUrl ?? null;
          storedAudioPath = hedraVideo.storedAudioPath ?? null;
          videoAudioProvider = hedraVideo.audioProvider ?? null;
          hedraGenerationId = hedraVideo.id;
          hedraBatchGenerationId = hedraVideo.batchGenerationId;
          hedraGenerationIds = hedraVideo.generationIds;
          hedraBatchResults = hedraVideo.batchResults;
          hedraProgress = hedraVideo.progress;
          hedraEtaSec = hedraVideo.etaSec;
          const rawVideoUrl = hedraVideo.batchResults.some(
              isHedraBatchVariantPending,
            )
            ? null
            : firstNonEmptyString(
              hedraVideo.videoUrl,
              hedraVideo.downloadUrl,
            );
          // Hedra 生成 mp4 を Storage へ保存する前に、muted-autoplay 向けの字幕を
          // 焼き込む。フラグ未設定/失敗時は素の mp4 (rawVideoUrl) をそのまま保存する。
          let videoToStore = rawVideoUrl;
          if (rawVideoUrl) {
            const spokenForCaptions = scriptForSpokenAudio(
              script,
              lang,
              body.title ?? template.name,
            ).join("\n").slice(0, MAX_SPOKEN_CHARS);
            const burn = await maybeBurnCaptions({
              videoUrl: rawVideoUrl,
              spokenText: spokenForCaptions,
              lang,
            });
            captionStatus = burn.status;
            captionReason = burn.reason;
            if (burn.videoUrl) {
              // 焼き込み成功: Storage コピーが失敗しても字幕版を返せるよう先に反映。
              videoToStore = burn.videoUrl;
              generatedVideoUrl = burn.videoUrl;
            }
          }
          if (videoToStore) {
            const captioned = captionStatus === "captions_burned";
            const stored = await persistRemoteMediaToStorage(admin, {
              url: videoToStore,
              prefix: "hedra",
              fileName: `${hedraVideo.id ?? crypto.randomUUID()}-${
                storageSafeSegment(templateKey)
              }-${lang}${captioned ? "-captioned" : ""}.mp4`,
              contentType: "video/mp4",
            });
            storedVideoUrl = stored?.url ?? null;
            storedVideoPath = stored?.path ?? null;
            generatedVideoUrl = storedVideoUrl ?? generatedVideoUrl;
            if (generatedVideoUrl && hedraBatchResults.length > 0) {
              hedraBatchResults = hedraBatchResults.map((variant, index) =>
                variant.id === hedraVideo.id ||
                  (hedraVideo.id == null && index === 0)
                  ? { ...variant, videoUrl: generatedVideoUrl }
                  : variant
              );
            }
          }
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

    // シネマティック動画 (fal.ai text-to-video)。presenter_video (Hedra) と違い
    // 顔画像・TTS を必要とせず、customPrompt のアートディレクションだけで
    // 短尺シネマティック映像を生成する。queue API 非同期: 初回は submit して
    // falRequestId を返し、クライアントが falRequestId 付きで再呼び出しして
    // 完成をポーリングする (hedraGenerationId と同型)。
    if (type === "cinematic_video") {
      videoProvider = `fal:${FAL_TEXT_TO_VIDEO_MODEL}`;
      if (!FAL_KEY) {
        videoStatus = "fallback_text";
        videoReason = "FAL_KEY / FAL_API_KEY not configured";
      } else {
        try {
          let falRequestId = firstNonEmptyString(body.falRequestId);
          if (falRequestId == null) {
            const submitted = await submitFalTextToVideoJob({
              apiKey: FAL_KEY,
              modelId: FAL_TEXT_TO_VIDEO_MODEL,
              payload: buildFalTextToVideoPayload({
                prompt: imagePrompt,
                extraParamsJson: FAL_TEXT_TO_VIDEO_PARAMS,
              }),
            });
            falRequestId = submitted.requestId;
            if (falRequestId == null) {
              throw new Error(
                "fal.ai queue submit did not return a request_id",
              );
            }
          }
          falJobId = falRequestId;
          const queueStatus = await getFalQueueRequestStatus({
            apiKey: FAL_KEY,
            modelId: FAL_TEXT_TO_VIDEO_MODEL,
            requestId: falRequestId,
          });
          if (queueStatus.status === "completed") {
            const result = await getFalQueueRequestResult({
              apiKey: FAL_KEY,
              modelId: FAL_TEXT_TO_VIDEO_MODEL,
              requestId: falRequestId,
            });
            const falVideoUrl = extractFalVideoUrl(result);
            if (falVideoUrl == null) {
              videoStatus = "fallback_text";
              videoReason =
                "fal.ai generation completed but no video URL was returned";
            } else {
              generatedVideoUrl = falVideoUrl;
              generatedDownloadUrl = falVideoUrl;
              // fal の出力 URL は恒久保証がないため、再利用ライブラリと同じ
              // Storage バケットへ永続化する (失敗時は fal URL のまま投稿継続)。
              const stored = await persistRemoteMediaToStorage(admin, {
                url: falVideoUrl,
                prefix: "fal",
                fileName: `${falRequestId}-${
                  storageSafeSegment(templateKey)
                }-${lang}.mp4`,
                contentType: "video/mp4",
              });
              storedVideoUrl = stored?.url ?? null;
              storedVideoPath = stored?.path ?? null;
              generatedVideoUrl = storedVideoUrl ?? generatedVideoUrl;
              videoStatus = "video_ready";
            }
          } else if (queueStatus.status === "failed") {
            videoStatus = "fallback_text";
            videoReason = "fal.ai text-to-video generation failed";
          } else {
            videoStatus = "processing";
            videoReason = "fal.ai text-to-video is still processing";
          }
        } catch (error) {
          videoStatus = "fallback_text";
          videoReason = isFalExhaustedBalanceError(error)
            ? "fal.ai のクレジットが不足しています。fal.ai ダッシュボードで残高を補充してください。"
            : error instanceof Error
            ? error.message
            : String(error);
        }
      }
    }

    const hasPendingHedraBatch = hedraBatchResults.some((variant) =>
      isHedraBatchVariantPending(variant)
    );
    const generationStatus = hasPendingHedraBatch
      ? "processing"
      : generatedVideoUrl != null
      ? "video_ready"
      : generatedImageUrl != null
      ? "ready"
      : (type === "presenter_video" || type === "cinematic_video") &&
          videoStatus != null
      ? videoStatus
      : "script_only";

    // 生成履歴をDBに記録
    let recordId: string | null = null;
    try {
      const historyRecord = {
        template_key: templateKey,
        user_id: authenticatedUserId,
        lang,
        type,
        script: JSON.stringify(script),
        caption,
        image_prompt: imagePrompt,
        generated_image_url: generatedImageUrl,
        generated_video_url: storedVideoUrl ?? generatedVideoUrl,
        generated_preview_url: generatedPreviewUrl,
        generated_download_url: generatedDownloadUrl,
        fal_job_id: falJobId,
        hashtags,
        video_provider: videoProvider,
        video_status: videoStatus,
        video_reason: videoReason,
        status: generationStatus,
        batch_generation_id: hedraBatchGenerationId,
        batch_size: hedraBatchSize,
        batch_results: hedraBatchResults,
      };
      if (isHedraBatchStatusPoll && hedraBatchGenerationId) {
        const { data: updated } = await admin
          .from("viral_ad_generations")
          .update(historyRecord)
          .eq("user_id", authenticatedUserId)
          .eq("batch_generation_id", hedraBatchGenerationId)
          .select("id")
          .maybeSingle();
        recordId = updated?.id ?? null;
      }
      if (recordId == null) {
        const { data: inserted } = await admin
          .from("viral_ad_generations")
          .insert(historyRecord)
          .select("id")
          .single();
        recordId = inserted?.id ?? null;
      }
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
      storedVideoUrl,
      storedVideoPath,
      storedAudioUrl,
      storedAudioPath,
      videoAudioProvider,
      hedraGenerationId,
      hedraGenerationIds,
      hedraBatchGenerationId,
      hedraBatchSize,
      hedraBatchResults,
      hedraProgress,
      hedraEtaSec,
      falJobId,
      // cinematic_video のポーリング継続用 ID (falJobId と同値だが、client が
      // hedraGenerationId と対で扱えるよう明示キーでも返す)。進行中のときだけ
      // 返す: 終端状態 (failed / completed-no-URL = fallback_text) でも返すと
      // クライアントが video.url 待ちで最大 7 分半ポーリングし続けてしまう
      // (Hedra 経路の「失敗は即フォールバック」と同じ挙動に揃える)。
      falRequestId: type === "cinematic_video" && videoStatus === "processing"
        ? falJobId
        : null,
      videoProvider,
      videoStatus,
      videoReason,
      captionStatus,
      captionReason,
      status: generatedVideoUrl != null || generatedImageUrl != null
        ? "ready_to_post"
        : generationStatus,
      nextStep: generatedVideoUrl != null
        ? "Call x-media-post with this videoUrl and caption to post to X"
        : generatedImageUrl != null
        ? "Call x-media-post with this imageUrl and caption to post to X"
        : hedraGenerationIds.length > 0
        ? "Hedra generation is still processing. Poll again with hedraGenerationIds."
        : hedraGenerationId != null
        ? "Hedra generation is still processing. Poll again with hedraGenerationId."
        : type === "cinematic_video" && videoStatus === "processing"
        ? "fal.ai text-to-video is still processing. Poll again with falRequestId."
        : type === "cinematic_video"
        ? "fal.ai text-to-video is unavailable. Use the caption for text-only X post or retry after checking FAL_KEY and FAL_TEXT_TO_VIDEO_MODEL."
        : type === "presenter_video" &&
            (videoReason?.includes("ELEVENLABS_API_KEY") ||
              videoReason?.includes("ElevenLabs"))
        ? "Check the ElevenLabs secret, voice ID, credits, and Storage upload path, then retry AI secretary video generation from the logged-in app."
        : type === "presenter_video"
        ? "Hedra video generation is unavailable. Use the caption for text-only X post or retry after checking HEDRA_API_KEY and ELEVENLABS_API_KEY."
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

function bearerToken(header: string | null): string | null {
  const match = header?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
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

function scriptForSpokenAudio(
  script: string[],
  lang: "ja" | "en",
  title?: string,
): string[] {
  if (lang === "ja") {
    const cleaned = script
      .map(normalizeSpokenLine)
      .filter((line) => line.length > 0);
    return cleaned.length > 0
      ? cleaned
      : AD_TEMPLATES.ai_secretary_site_tour.script.ja.map(normalizeSpokenLine);
  }
  return scriptForHedraVoice(script, lang, title)
    .map(normalizeSpokenLine)
    .filter((line) => line.length > 0);
}

type HedraVideoResult = {
  id: string | null;
  status: string;
  videoUrl: string | null;
  previewUrl: string | null;
  downloadUrl: string | null;
  storedAudioUrl?: string | null;
  storedAudioPath?: string | null;
  audioProvider?: string | null;
  progress: number | null;
  etaSec: number | null;
  reason: string | null;
  batchGenerationId: string | null;
  batchSize: number;
  generationIds: string[];
  batchResults: HedraBatchVariant[];
};

async function createHedraPresenterVideo(params: {
  apiKey: string;
  admin: SupabaseClient;
  script: string[];
  title?: string;
  prompt: string;
  voice: string;
  imageUrl: string | null;
  lang: "ja" | "en";
  requiresUploadedAudio?: boolean;
  batchSize: number;
  audioStartMs: number;
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

  const spokenScript = scriptForSpokenAudio(
    params.script,
    params.lang,
    params.title,
  )
    .join("\n");
  // TTS へ渡すテキストにだけ読み辞書を適用する (誤読対策 / 例: 負債→ふさい)。
  // 字幕 (index.ts の spokenForCaptions) は漢字表記のまま維持される。
  const ttsText = applyTtsReadings(spokenScript, params.lang)
    .slice(0, MAX_SPOKEN_CHARS);
  let audioProvider = "hedra_tts";
  let storedAudioUrl: string | null = null;
  let storedAudioPath: string | null = null;
  let audioGeneration: Record<string, unknown>;
  // 音声生成の失敗連鎖を記録し、最終エラーに speech_chain として付記する
  // (= ダッシュボードのログを見ずに応答だけで診断できるようにする)。
  const speechChain: string[] = [];

  // requiresUploadedAudio テンプレ (= ai_secretary_site_tour) はフラグ非依存で
  // アップロード音声経路を使う (壊れた Hedra 内蔵TTSへ落ちるのを構造的に防ぐ)。
  const useUploadedAudioPath =
    (HEDRA_UPLOADED_AUDIO_ENABLED || params.requiresUploadedAudio === true) &&
    Boolean(ELEVENLABS_API_KEY || OPENAI_API_KEY);
  console.log(
    `[vvag-audio] path=${
      useUploadedAudioPath ? "uploaded" : "hedra_tts"
    } requiresUploadedAudio=${params.requiresUploadedAudio === true} ` +
      `elevenlabs=${Boolean(ELEVENLABS_API_KEY)} openai=${
        Boolean(OPENAI_API_KEY)
      }`,
  );
  if (useUploadedAudioPath) {
    try {
      if (!ELEVENLABS_API_KEY) {
        throw new Error("ELEVENLABS_API_KEY not configured");
      }
      const audio = await createElevenLabsSpeechAsset(params.admin, {
        // 動画を短尺に保つための上限。全 TTS 経路で MAX_SPOKEN_CHARS に統一。
        text: ttsText,
        templateTitle: params.title ?? "share-update",
        lang: params.lang,
        voiceId: resolveElevenLabsVoiceForLabel(params.voice),
      });
      audioGeneration = buildHedraUploadedAudioGeneration(audio.url);
      audioProvider = "elevenlabs";
      console.log(
        `[vvag-audio] voice label=${params.voice} → ${
          voiceGenderForLabel(params.voice)
        }`,
      );
      storedAudioUrl = audio.url;
      storedAudioPath = audio.path;
      console.log(`[vvag-audio] ElevenLabs OK storedAudioUrl=${audio.url}`);
    } catch (error) {
      console.error(
        "[vvag-audio] ElevenLabs speech generation failed; falling back",
        providerErrorMessage(error),
      );
      speechChain.push(`elevenlabs=${providerErrorMessage(error)}`);
      if (
        params.requiresUploadedAudio &&
        shouldRetryElevenLabsWithFallbackVoice(error)
      ) {
        const fallbackResult = await tryElevenLabsFallbackVoices(params.admin, {
          text: ttsText,
          templateTitle: params.title ?? "share-update",
          lang: params.lang,
          configuredVoiceId: ELEVENLABS_AI_SECRETARY_VOICE_ID,
          configuredError: error,
        });
        if (fallbackResult.ok) {
          audioGeneration = buildHedraUploadedAudioGeneration(
            fallbackResult.audio.url,
          );
          audioProvider = fallbackResult.audioProvider;
          storedAudioUrl = fallbackResult.audio.url;
          storedAudioPath = fallbackResult.audio.path;
          return await createHedraVideoFromUploadedAudio(params, {
            audioGeneration,
            storedAudioUrl,
            storedAudioPath,
            audioProvider,
            imageUrl,
            fallbackText: ttsText,
          });
        }
        speechChain.push(`fallback_voices=${fallbackResult.reason}`);
      }
      // OpenAI TTS は ElevenLabs 失敗時の無条件フォールバック
      // (従来は requiresUploadedAudio && 音声系エラーの時のみで、
      //  それ以外の失敗が全て壊れた Hedra TTS へ直行していた)。
      if (OPENAI_API_KEY) {
        try {
          const openAiAudio = await createOpenAiSpeechAsset(params.admin, {
            text: ttsText,
            templateTitle: `${params.title ?? "share-update"}-openai-tts`,
            lang: params.lang,
          });
          audioGeneration = buildHedraUploadedAudioGeneration(
            openAiAudio.url,
          );
          audioProvider = "openai_tts_fallback";
          storedAudioUrl = openAiAudio.url;
          storedAudioPath = openAiAudio.path;
          return await createHedraVideoFromUploadedAudio(params, {
            audioGeneration,
            storedAudioUrl,
            storedAudioPath,
            audioProvider,
            imageUrl,
            fallbackText: ttsText,
          });
        } catch (openAiError) {
          speechChain.push(`openai_tts=${providerErrorMessage(openAiError)}`);
        }
      } else {
        speechChain.push("openai_tts=OPENAI_API_KEY not configured");
      }
      console.warn(
        "Premium speech generation failed; falling back to Hedra TTS",
        speechChain.join(" | "),
      );
      audioGeneration = await createHedraTextToSpeechAudioGeneration(params, {
        text: ttsText,
      });
      audioProvider = params.requiresUploadedAudio
        ? "hedra_tts_after_premium_speech_failure"
        : "hedra_tts_after_elevenlabs_failure";
    }
  } else {
    audioGeneration = await createHedraTextToSpeechAudioGeneration(params, {
      text: ttsText,
    });
  }

  try {
    return await createHedraVideoFromUploadedAudio(params, {
      audioGeneration,
      storedAudioUrl,
      storedAudioPath,
      audioProvider,
      imageUrl,
      fallbackText: ttsText,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    // 音声経路(成功時含む)と失敗連鎖を最終エラーへ含め、
    // videoReason だけで根因診断できるようにする。
    const chain = [`audio_provider=${audioProvider}`, ...speechChain];
    throw new Error(`${message}; speech_chain: ${chain.join(" | ")}`);
  }
}

async function createHedraVideoFromUploadedAudio(
  params: {
    apiKey: string;
    title?: string;
    prompt: string;
    voice: string;
    lang: "ja" | "en";
    batchSize: number;
    audioStartMs: number;
  },
  media: {
    audioGeneration: Record<string, unknown>;
    storedAudioUrl: string | null;
    storedAudioPath: string | null;
    audioProvider: string | null;
    imageUrl: string;
    fallbackText: string;
  },
): Promise<HedraVideoResult> {
  const generationBody = withHedraAudioStartMs(
    withHedraBatchSize({
      type: "video",
      ai_model_id: HEDRA_AVATAR_MODEL_ID,
      start_keyframe_url: media.imageUrl,
      audio_generation: media.audioGeneration,
      generated_video_inputs: {
        text_prompt: `${params.title ?? "Share update"}\n${params.prompt}`,
        aspect_ratio: "16:9",
        resolution: "540p",
        enhance_prompt: true,
      },
    }, params.batchSize),
    params.audioStartMs,
  );
  let payload: unknown;
  // Hedra は audio_generation.type="audio" (URL渡し) を拒否するため、
  // アップロード音声は歴史的に実績のあるアセット方式 (audio_id) を最優先で使う。
  const uploadedAudioUrl = media.audioGeneration["type"] === "audio"
    ? firstNonEmptyString(media.audioGeneration["url"])
    : null;
  // アセット化(audio_id)は Hedra 側が一時的に失敗することがあるため 2 回試行する。
  // 全試行失敗した理由は最終エラーへ載せて診断可能にする(従来は console.warn のみで
  // 応答から asset 失敗理由が見えず、壊れた text_to_speech の 400 だけが表面化していた)。
  let assetFailureReason: string | null = null;
  if (uploadedAudioUrl) {
    let audioAssetId: string | null = null;
    for (let attempt = 1; attempt <= 2; attempt += 1) {
      try {
        audioAssetId = await createHedraAudioAssetFromUrl(
          params.apiKey,
          uploadedAudioUrl,
          `${storageSafeSegment(params.title ?? "share-update")}.mp3`,
        );
        break;
      } catch (assetError) {
        assetFailureReason = providerErrorMessage(assetError);
        console.error(
          `[vvag-asset] Hedra audio asset creation failed (attempt ${attempt}/2)`,
          assetFailureReason,
        );
        if (isHedraInsufficientCreditsError(assetError)) {
          throw new Error(hedraInsufficientCreditsMessage(assetError));
        }
        if (attempt < 2) await delay(1500);
      }
    }
    if (audioAssetId) {
      const assetBody = withHedraAudioStartMs(
        withHedraBatchSize({
          type: "video",
          ai_model_id: HEDRA_AVATAR_MODEL_ID,
          start_keyframe_url: media.imageUrl,
          audio_id: audioAssetId,
          generated_video_inputs: {
            text_prompt: `${params.title ?? "Share update"}\n${params.prompt}`,
            aspect_ratio: "16:9",
            resolution: "540p",
            enhance_prompt: true,
          },
        }, params.batchSize),
        params.audioStartMs,
      );
      try {
        const assetPayload = await hedraJsonRequest(
          params.apiKey,
          "/generations",
          { method: "POST", body: assetBody },
        );
        const video = await pollHedraGeneration(
          params.apiKey,
          normalizeHedraVideoResponse(assetPayload),
        );
        return {
          ...video,
          storedAudioUrl: media.storedAudioUrl,
          storedAudioPath: media.storedAudioPath,
          audioProvider: media.audioProvider,
        };
      } catch (generationError) {
        if (isHedraInsufficientCreditsError(generationError)) {
          throw new Error(hedraInsufficientCreditsMessage(generationError));
        }
        // A generation submission can be charged even if its response or a
        // later status request fails. Never auto-submit a second batch here.
        throw generationError;
      }
    }
  }
  try {
    payload = await createHedraGenerationWithTtsModelFallback(
      params.apiKey,
      generationBody,
      media.audioGeneration["type"] === "text_to_speech" &&
        media.audioGeneration["model_id"] != null,
    );
  } catch (error) {
    if (
      media.audioGeneration["type"] !== "text_to_speech" &&
      isHedraUploadedAudioUnsupportedError(error)
    ) {
      try {
        const fallbackAudioGeneration =
          await createHedraTextToSpeechAudioGeneration(
            {
              apiKey: params.apiKey,
              voice: params.voice,
              lang: params.lang,
            },
            { text: media.fallbackText },
          );
        payload = await createHedraGenerationWithTtsModelFallback(
          params.apiKey,
          { ...generationBody, audio_generation: fallbackAudioGeneration },
          fallbackAudioGeneration["model_id"] != null,
        );
        const video = await pollHedraGeneration(
          params.apiKey,
          normalizeHedraVideoResponse(payload),
        );
        return {
          ...video,
          storedAudioUrl: media.storedAudioUrl,
          storedAudioPath: media.storedAudioPath,
          audioProvider: "hedra_tts_after_uploaded_audio_rejected",
        };
      } catch (fallbackError) {
        // audio_id アセット化が失敗して text_to_speech に落ち、さらにそれも失敗した
        // 場合、元の asset 失敗理由を付記して根因(アセット化 or TTS モデル)を判別可能に。
        throw withAudioAssetReason(fallbackError, assetFailureReason);
      }
    }
    throw withAudioAssetReason(error, assetFailureReason);
  }
  const video = await pollHedraGeneration(
    params.apiKey,
    normalizeHedraVideoResponse(payload),
  );
  return {
    ...video,
    storedAudioUrl: media.storedAudioUrl,
    storedAudioPath: media.storedAudioPath,
    audioProvider: media.audioProvider,
  };
}

function withAudioAssetReason(
  error: unknown,
  reason: string | null,
): Error {
  const base = error instanceof Error ? error : new Error(String(error));
  if (!reason) return base;
  return new Error(`${base.message}; audio_asset=${reason}`);
}

// Hedra の 402 「Insufficient credits」を検出する。クレジット不足は動画生成の
// あらゆる経路(asset / text_to_speech)で必ず失敗するため、専用の明確なメッセージへ
// 変換して、cryptic な model missing 400 の連鎖に埋もれないようにする。
function isHedraInsufficientCreditsError(error: unknown): boolean {
  const message = (error instanceof Error ? error.message : String(error))
    .toLowerCase();
  return message.includes("insufficient credits") ||
    /hedra api 402\b/.test(message);
}

function hedraInsufficientCreditsMessage(error: unknown): string {
  const raw = error instanceof Error ? error.message : String(error);
  const match = raw.match(/Required:\s*(\d+),\s*Available:\s*(\d+)/i);
  const detail = match
    ? `必要 ${match[1]} / 残り ${match[2]} クレジット`
    : raw.replace(/\s+/g, " ").trim().slice(0, 200);
  return `Hedra のクレジットが不足しています（${detail}）。` +
    `動画生成には Hedra クレジットの追加が必要です。hedra.com のアカウントで` +
    `クレジットをトップアップしてから、もう一度「動画生成」をお試しください。`;
}

function providerErrorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  return message.replace(/\s+/g, " ").trim().slice(0, 500);
}

function shouldRetryElevenLabsWithFallbackVoice(error: unknown): boolean {
  const message = providerErrorMessage(error);
  return message.includes("paid_plan_required") ||
    message.includes("payment_required") ||
    message.includes("free users cannot use") ||
    message.includes("library voices") ||
    message.includes("voice_not_found");
}

type ElevenLabsVoice = {
  voice_id?: string;
  name?: string;
  category?: string;
  labels?: Record<string, string>;
};

type ElevenLabsFallbackResult =
  | { ok: true; audio: StoredMedia; audioProvider: string }
  | { ok: false; reason: string };

async function tryElevenLabsFallbackVoices(
  admin: SupabaseClient,
  params: {
    text: string;
    templateTitle: string;
    lang: "ja" | "en";
    configuredVoiceId: string;
    configuredError: unknown;
  },
): Promise<ElevenLabsFallbackResult> {
  const candidateVoiceIds = await resolveElevenLabsFallbackVoiceIds(
    params.configuredVoiceId,
    params.lang,
  );
  const errors: string[] = [];
  for (const voiceId of candidateVoiceIds) {
    try {
      const audio = await createElevenLabsSpeechAsset(admin, {
        text: params.text,
        templateTitle: `${params.templateTitle}-fallback`,
        lang: params.lang,
        voiceId,
      });
      return { ok: true, audio, audioProvider: "elevenlabs_fallback" };
    } catch (error) {
      errors.push(`${redactVoiceId(voiceId)}=${providerErrorMessage(error)}`);
    }
  }
  const listed = candidateVoiceIds.length > 0
    ? errors.join("; ")
    : "no fallback voices discovered";
  return {
    ok: false,
    reason:
      `ElevenLabs speech generation failed with configured voice and fallback voices: configured=${
        providerErrorMessage(params.configuredError)
      }; fallback=${listed}`,
  };
}

async function resolveElevenLabsFallbackVoiceIds(
  configuredVoiceId: string,
  lang: "ja" | "en",
): Promise<string[]> {
  const ids = new Set<string>();
  if (ELEVENLABS_FALLBACK_VOICE_ID !== configuredVoiceId) {
    ids.add(ELEVENLABS_FALLBACK_VOICE_ID);
  }
  try {
    const voices = await fetchElevenLabsVoices();
    voices
      .filter((voice) => voice.voice_id && voice.voice_id !== configuredVoiceId)
      .sort((a, b) =>
        elevenLabsVoiceScore(b, lang) - elevenLabsVoiceScore(a, lang)
      )
      .slice(0, 4)
      .forEach((voice) => ids.add(voice.voice_id as string));
  } catch (error) {
    console.warn(
      "ElevenLabs voice discovery failed",
      providerErrorMessage(error),
    );
  }
  return [...ids].slice(0, 4);
}

async function fetchElevenLabsVoices(): Promise<ElevenLabsVoice[]> {
  const response = await fetch("https://api.elevenlabs.io/v1/voices", {
    headers: { "xi-api-key": ELEVENLABS_API_KEY },
  });
  if (!response.ok) {
    const raw = await response.text();
    throw new Error(`ElevenLabs voices API ${response.status}: ${raw}`);
  }
  const payload = await response.json() as { voices?: ElevenLabsVoice[] };
  return Array.isArray(payload.voices) ? payload.voices : [];
}

function elevenLabsVoiceScore(
  voice: ElevenLabsVoice,
  lang: "ja" | "en",
): number {
  const labels = Object.values(voice.labels ?? {}).join(" ");
  const haystack = `${voice.name ?? ""} ${voice.category ?? ""} ${labels}`
    .toLowerCase();
  let score = 0;
  if (haystack.includes("female") || haystack.includes("woman")) score += 20;
  if (haystack.includes("warm") || haystack.includes("professional")) {
    score += 5;
  }
  if (haystack.includes("premade") || haystack.includes("generated")) {
    score += 4;
  }
  if (haystack.includes("cloned")) score += 2;
  if (
    lang === "ja" &&
    (haystack.includes("japanese") || haystack.includes("multilingual"))
  ) {
    score += 6;
  }
  if (haystack.includes("male") || haystack.includes("man")) score -= 20;
  if (haystack.includes("library")) score -= 8;
  return score;
}

function redactVoiceId(voiceId: string): string {
  if (voiceId.length <= 8) return "voice";
  return `${voiceId.slice(0, 4)}...${voiceId.slice(-4)}`;
}

async function createHedraTextToSpeechAudioGeneration(
  params: {
    apiKey: string;
    voice: string;
    lang: "ja" | "en";
  },
  options: { text: string },
): Promise<Record<string, unknown>> {
  const voiceId = await resolveHedraVoiceId(
    params.apiKey,
    params.voice,
    params.lang,
  );
  const ttsModelId = await resolveHedraTextToSpeechModelId(params.apiKey);
  const hedraLanguage = hedraLanguageForLang(params.lang);
  return buildHedraTextToSpeechAudioGeneration({
    voiceId,
    modelId: ttsModelId,
    text: options.text,
    language: hedraLanguage,
  });
}

type StoredMedia = {
  url: string;
  path: string;
};

async function createElevenLabsSpeechAsset(
  admin: SupabaseClient,
  params: {
    text: string;
    templateTitle: string;
    lang: "ja" | "en";
    voiceId?: string;
  },
): Promise<StoredMedia> {
  const text = params.text.trim();
  if (!text) throw new Error("ElevenLabs speech text is empty");
  const voiceId = params.voiceId ?? ELEVENLABS_AI_SECRETARY_VOICE_ID;
  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${
      encodeURIComponent(voiceId)
    }`,
    {
      method: "POST",
      headers: {
        "xi-api-key": ELEVENLABS_API_KEY,
        "Accept": "audio/mpeg",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        text,
        model_id: ELEVENLABS_MODEL_ID,
        voice_settings: {
          stability: 0.58,
          similarity_boost: 0.82,
          style: 0.28,
          use_speaker_boost: true,
        },
      }),
    },
  );
  if (!response.ok) {
    const raw = await response.text();
    throw new Error(`ElevenLabs API ${response.status}: ${raw}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  const path = mediaStoragePath({
    prefix: "elevenlabs",
    fileName: `${crypto.randomUUID()}-${
      storageSafeSegment(params.templateTitle)
    }-${params.lang}.mp3`,
  });
  const { error } = await admin.storage
    .from(VIRAL_VIDEO_BUCKET)
    .upload(path, bytes, {
      contentType: "audio/mpeg",
      cacheControl: "604800",
      upsert: false,
    });
  if (error) {
    const fallback = await uploadBytesToStorage(admin, {
      bytes,
      path,
      contentType: "application/octet-stream",
    });
    if (!fallback.ok) {
      throw new Error(
        `ElevenLabs audio upload failed: ${error.message}; octet-stream retry failed: ${fallback.error}`,
      );
    }
  }
  const { data } = admin.storage.from(VIRAL_VIDEO_BUCKET).getPublicUrl(path);
  return { url: data.publicUrl, path };
}

async function createOpenAiSpeechAsset(
  admin: SupabaseClient,
  params: {
    text: string;
    templateTitle: string;
    lang: "ja" | "en";
  },
): Promise<StoredMedia> {
  const text = params.text.trim();
  if (!text) throw new Error("OpenAI speech text is empty");
  const modelCandidates = uniqueNonEmptyStrings([
    OPENAI_TTS_MODEL,
    "gpt-4o-mini-tts",
    "tts-1-hd",
    "tts-1",
  ]);
  const voiceCandidates = uniqueNonEmptyStrings([
    OPENAI_TTS_VOICE,
    "nova",
    "shimmer",
    "alloy",
  ]);
  const errors: string[] = [];
  for (const model of modelCandidates) {
    for (const voice of voiceCandidates) {
      try {
        const response = await fetch("https://api.openai.com/v1/audio/speech", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${OPENAI_API_KEY}`,
            "Accept": "audio/mpeg",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model,
            voice,
            input: text,
          }),
        });
        if (!response.ok) {
          const raw = await response.text();
          errors.push(
            `${model}/${voice}=OpenAI API ${response.status}: ${raw}`,
          );
          continue;
        }
        const bytes = new Uint8Array(await response.arrayBuffer());
        return await uploadAudioAsset(admin, {
          bytes,
          prefix: "openai-tts",
          templateTitle: params.templateTitle,
          lang: params.lang,
        });
      } catch (error) {
        errors.push(`${model}/${voice}=${providerErrorMessage(error)}`);
      }
    }
  }
  throw new Error(
    `OpenAI speech generation failed: ${errors.join("; ").slice(0, 900)}`,
  );
}

async function uploadAudioAsset(
  admin: SupabaseClient,
  params: {
    bytes: Uint8Array;
    prefix: string;
    templateTitle: string;
    lang: "ja" | "en";
  },
): Promise<StoredMedia> {
  const path = mediaStoragePath({
    prefix: params.prefix,
    fileName: `${crypto.randomUUID()}-${
      storageSafeSegment(params.templateTitle)
    }-${params.lang}.mp3`,
  });
  const { error } = await admin.storage
    .from(VIRAL_VIDEO_BUCKET)
    .upload(path, params.bytes, {
      contentType: "audio/mpeg",
      cacheControl: "604800",
      upsert: false,
    });
  if (error) {
    const fallback = await uploadBytesToStorage(admin, {
      bytes: params.bytes,
      path,
      contentType: "application/octet-stream",
    });
    if (!fallback.ok) {
      throw new Error(
        `${params.prefix} audio upload failed: ${error.message}; octet-stream retry failed: ${fallback.error}`,
      );
    }
  }
  const { data } = admin.storage.from(VIRAL_VIDEO_BUCKET).getPublicUrl(path);
  return { url: data.publicUrl, path };
}

async function uploadBytesToStorage(
  admin: SupabaseClient,
  params: {
    bytes: Uint8Array;
    path: string;
    contentType: string;
  },
): Promise<{ ok: true } | { ok: false; error: string }> {
  const { error } = await admin.storage
    .from(VIRAL_VIDEO_BUCKET)
    .upload(params.path, params.bytes, {
      contentType: params.contentType,
      cacheControl: "604800",
      upsert: false,
    });
  if (error) {
    return { ok: false, error: error.message };
  }
  return { ok: true };
}

async function createHedraAudioAssetFromUrl(
  apiKey: string,
  url: string,
  name: string,
): Promise<string> {
  // 動画生成失敗の主因である「音声アセット化」の各段階を Supabase ログに記録し、
  // どの段階(download / create asset / upload)で失敗したかを特定可能にする。
  console.log(`[vvag-asset] download start url=${url.slice(0, 140)}`);
  const download = await fetch(url);
  if (!download.ok) {
    const body = await download.text().catch(() => "");
    console.error(
      `[vvag-asset] download failed status=${download.status} body=${
        body.slice(0, 200)
      }`,
    );
    throw new Error(
      `uploaded audio download failed with ${download.status}: ${
        body.trim().slice(0, 200) || download.statusText
      }`,
    );
  }
  const bytes = new Uint8Array(await download.arrayBuffer());
  console.log(
    `[vvag-asset] downloaded bytes=${bytes.byteLength}; creating Hedra asset`,
  );
  const created = await hedraJsonRequest(apiKey, "/assets", {
    method: "POST",
    body: { name, type: "audio" },
  });
  const assetId = extractHedraAssetId(created);
  if (!assetId) {
    console.error(
      `[vvag-asset] create asset returned no id payload=${
        JSON.stringify(created).slice(0, 300)
      }`,
    );
    throw new Error("Hedra asset id was missing from create asset response");
  }
  console.log(`[vvag-asset] asset created id=${assetId}; uploading bytes`);
  const form = new FormData();
  const buffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(buffer).set(bytes);
  form.append("file", new Blob([buffer], { type: "audio/mpeg" }), name);
  const uploaded = await fetch(
    `${HEDRA_API_BASE}/assets/${encodeURIComponent(assetId)}/upload`,
    { method: "POST", headers: { "X-API-Key": apiKey }, body: form },
  );
  if (!uploaded.ok) {
    const rawText = await uploaded.text();
    console.error(
      `[vvag-asset] upload failed status=${uploaded.status} body=${
        rawText.slice(0, 200)
      }`,
    );
    throw new Error(
      `Hedra asset upload ${uploaded.status}: ${
        rawText.trim() || uploaded.statusText
      }`,
    );
  }
  console.log(`[vvag-asset] upload OK asset=${assetId}`);
  return assetId;
}

function extractHedraAssetId(payload: unknown): string | null {
  const record = asRecord(payload);
  const data = asRecord(record?.["data"]);
  const asset = asRecord(record?.["asset"]);
  return firstNonEmptyString(
    record?.["id"],
    record?.["asset_id"],
    data?.["id"],
    data?.["asset_id"],
    asset?.["id"],
    asset?.["asset_id"],
  );
}

async function persistRemoteMediaToStorage(
  admin: SupabaseClient,
  params: {
    url: string;
    prefix: string;
    fileName: string;
    contentType: string;
  },
): Promise<StoredMedia | null> {
  try {
    const response = await fetch(params.url);
    if (!response.ok) {
      throw new Error(`download failed with ${response.status}`);
    }
    const bytes = new Uint8Array(await response.arrayBuffer());
    const path = mediaStoragePath({
      prefix: params.prefix,
      fileName: params.fileName,
    });
    const { error } = await admin.storage
      .from(VIRAL_VIDEO_BUCKET)
      .upload(path, bytes, {
        contentType: params.contentType,
        cacheControl: "604800",
        upsert: true,
      });
    if (error) throw error;
    const { data } = admin.storage.from(VIRAL_VIDEO_BUCKET).getPublicUrl(path);
    return { url: data.publicUrl, path };
  } catch (error) {
    console.warn("Remote media storage copy failed", error);
    return null;
  }
}

// 生成済み Hedra 動画へ字幕を焼き込む。フラグ/transcoder が未設定、SRT が空、
// あるいは焼き込みが失敗した場合は videoUrl=null を返し、呼び出し側は素の mp4 へ
// フォールバックする。status/reason は診断用に応答へ載せる (DB スキーマは変更しない)。
async function maybeBurnCaptions(params: {
  videoUrl: string;
  spokenText: string;
  lang: "ja" | "en";
}): Promise<
  { status: string; reason: string | null; videoUrl: string | null }
> {
  if (!VVAG_BURN_CAPTIONS) {
    return { status: "captions_disabled", reason: null, videoUrl: null };
  }
  if (!VVAG_CAPTION_TRANSCODER_URL) {
    return {
      status: "captions_skipped",
      reason: "VVAG_CAPTION_TRANSCODER_URL not configured",
      videoUrl: null,
    };
  }
  try {
    const srt = buildCaptionSrt(
      params.spokenText,
      params.lang,
      captionTimingFromEnv(),
    );
    if (!srt.trim()) {
      return {
        status: "captions_skipped",
        reason: "no spoken script lines to caption",
        videoUrl: null,
      };
    }
    const style = captionStyleFromEnv();
    const result = await burnCaptionsViaTranscoder({
      endpoint: VVAG_CAPTION_TRANSCODER_URL,
      apiKey: VVAG_CAPTION_TRANSCODER_KEY || null,
      timeoutMs: VVAG_CAPTION_TIMEOUT_MS,
      request: {
        videoUrl: params.videoUrl,
        mp4Url: params.videoUrl,
        srt,
        subtitleFormat: "srt",
        format: "mp4",
        resolution: "540p",
        style,
        forceStyle: buildForceStyle(style),
        // 実測動画長へ SRT を線形リスケール(トランスコーダ側 ffprobe)。推定
        // 話速との乖離や Hedra の頭出し余白による字幕ずれを吸収する。
        stretchToVideo: true,
        leadInMs: positiveNumberEnv("VVAG_CAPTION_LEAD_MS", 0),
        tailPadMs: positiveNumberEnv("VVAG_CAPTION_TAIL_MS", 300),
      },
    });
    if (result.ok) {
      console.log(
        `[vvag-caption] burned OK lang=${params.lang} url=${
          result.url.slice(0, 140)
        }`,
      );
      return { status: "captions_burned", reason: null, videoUrl: result.url };
    }
    console.warn(
      `[vvag-caption] burn failed; using un-captioned mp4: ${result.reason}`,
    );
    return { status: "captions_failed", reason: result.reason, videoUrl: null };
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    console.warn(
      `[vvag-caption] burn threw; using un-captioned mp4: ${reason}`,
    );
    return { status: "captions_failed", reason, videoUrl: null };
  }
}

function captionTimingFromEnv(): CaptionTimingConfig {
  return {
    ...DEFAULT_CAPTION_TIMING,
    jaCharsPerSecond: positiveNumberEnv(
      "VVAG_CAPTION_JA_CPS",
      DEFAULT_CAPTION_TIMING.jaCharsPerSecond,
    ),
    enCharsPerSecond: positiveNumberEnv(
      "VVAG_CAPTION_EN_CPS",
      DEFAULT_CAPTION_TIMING.enCharsPerSecond,
    ),
  };
}

function captionStyleFromEnv(): CaptionStyle {
  return {
    ...DEFAULT_CAPTION_STYLE,
    fontName: Deno.env.get("VVAG_CAPTION_FONT_NAME")?.trim() ||
      DEFAULT_CAPTION_STYLE.fontName,
    fontSizePx: positiveNumberEnv(
      "VVAG_CAPTION_FONT_SIZE",
      DEFAULT_CAPTION_STYLE.fontSizePx,
    ),
  };
}

function positiveNumberEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (raw == null || raw.trim().length === 0) return fallback;
  const parsed = Number(raw.trim());
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function mediaStoragePath(
  params: { prefix: string; fileName: string },
): string {
  const datePrefix = new Date().toISOString().slice(0, 10);
  return [
    storageSafeSegment(params.prefix),
    datePrefix,
    storageSafeSegment(params.fileName),
  ].join("/");
}

function storageSafeSegment(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") ||
    "asset";
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
    if (isHedraMissingTextToSpeechModelError(error)) {
      const resolvedTtsModelId = await resolveHedraTextToSpeechModelId(apiKey);
      if (resolvedTtsModelId) {
        return await hedraJsonRequest(apiKey, "/generations", {
          method: "POST",
          body: withHedraTextToSpeechModelId(body, resolvedTtsModelId),
        });
      }
    }
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

async function getHedraBatchGenerationStatus(
  apiKey: string,
  generationIds: string[],
  batchGenerationId: string | null,
  batchSize: number,
): Promise<HedraVideoResult> {
  const results = await Promise.all(
    generationIds.map((generationId) =>
      getHedraGenerationStatus(apiKey, generationId)
    ),
  );
  return combineHedraBatchResults(
    results,
    batchGenerationId,
    batchSize,
  );
}

async function pollHedraGeneration(
  apiKey: string,
  initial: HedraVideoResult,
): Promise<HedraVideoResult> {
  if (initial.generationIds.length > 1) {
    let current = initial;
    for (const delayMs of [3000, 5000, 8000, 10000, 10000]) {
      if (current.batchResults.every(isHedraBatchVariantTerminal)) {
        return current;
      }
      await delay(delayMs);
      current = await getHedraBatchGenerationStatus(
        apiKey,
        current.generationIds,
        current.batchGenerationId,
        current.batchSize,
      );
    }
    return current;
  }
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

function combineHedraBatchResults(
  results: HedraVideoResult[],
  batchGenerationId: string | null,
  batchSize: number,
): HedraVideoResult {
  const variants = results.map((result) => ({
    id: result.id,
    status: result.status,
    videoUrl: result.videoUrl,
    previewUrl: result.previewUrl,
    downloadUrl: result.downloadUrl,
    progress: result.progress,
    etaSec: result.etaSec,
    reason: result.reason,
  }));
  const primary =
    results.find((result) =>
      result.videoUrl != null || result.downloadUrl != null
    ) ?? results[0];
  const allTerminal = variants.every(isHedraBatchVariantTerminal);
  const hasFailure = variants.some((variant) =>
    ["failed", "error", "canceled", "cancelled"].includes(
      variant.status.toLowerCase(),
    )
  );
  return {
    id: primary?.id ?? null,
    status: allTerminal ? (hasFailure ? "partial" : "completed") : "processing",
    videoUrl: primary?.videoUrl ?? null,
    previewUrl: primary?.previewUrl ?? null,
    downloadUrl: primary?.downloadUrl ?? null,
    progress: variants.length === 0
      ? null
      : variants.reduce((sum, item) => sum + (item.progress ?? 0), 0) /
        variants.length,
    etaSec: variants
      .map((item) => item.etaSec)
      .filter((value): value is number => value != null)
      .reduce((max, value) => Math.max(max, value), 0) || null,
    reason:
      results.map((result) => result.reason).find((reason) => reason != null) ??
        null,
    batchGenerationId,
    batchSize,
    generationIds: variants
      .map((variant) => variant.id)
      .filter((id): id is string => id != null),
    batchResults: variants,
  };
}

function isHedraBatchVariantTerminal(variant: HedraBatchVariant): boolean {
  if (variant.videoUrl || variant.downloadUrl) return true;
  return ["complete", "completed", "failed", "error", "canceled", "cancelled"]
    .includes(variant.status.toLowerCase());
}

function isHedraBatchVariantPending(variant: HedraBatchVariant): boolean {
  return !isHedraBatchVariantTerminal(variant);
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
  const voiceId = selectBestHedraVoiceId(voices, {
    lang,
    preferredVoice: configured || preferredVoice,
  });
  if (!voiceId) {
    throw new Error("Hedra voice_id could not be resolved");
  }
  return voiceId;
}

async function resolveHedraTextToSpeechModelId(
  apiKey: string,
): Promise<string | null> {
  const configured = resolveConfiguredHedraTextToSpeechModelId(
    HEDRA_TTS_MODEL_ID,
  );
  if (configured) {
    console.log(`[vvag-tts] using configured HEDRA_TTS_MODEL_ID=${configured}`);
    return configured;
  }
  console.log(
    `[vvag-tts] HEDRA_TTS_MODEL_ID unset/invalid (raw=${
      HEDRA_TTS_MODEL_ID ? "set-but-non-uuid" : "empty"
    }); discovering via /models`,
  );
  try {
    const payload = await hedraJsonRequest(apiKey, "/models", {
      method: "GET",
    });
    const models = extractHedraModelList(payload);
    const selected = selectBestHedraTextToSpeechModelId(models);
    console.log(
      `[vvag-tts] /models returned ${models.length} models; selected=${
        selected ??
          "NONE (no text_to_speech model matched → text_to_speech will 400)"
      }`,
    );
    return selected;
  } catch (error) {
    console.error(
      "[vvag-tts] Hedra TTS model discovery failed",
      providerErrorMessage(error),
    );
    return null;
  }
}

function extractHedraModelList(payload: unknown): unknown[] {
  if (Array.isArray(payload)) return payload;
  const record = asRecord(payload);
  if (!record) return [];
  for (const key of ["data", "models", "items", "results"]) {
    const value = record[key];
    if (Array.isArray(value)) return value;
    const nested = asRecord(value);
    if (nested) {
      const nestedModels = extractHedraModelList(nested);
      if (nestedModels.length > 0) return nestedModels;
    }
  }
  return [];
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
  const batch = normalizeHedraBatchResponse(payload);
  const record = asRecord(payload) ?? {};
  const video = asRecord(record["video"]);
  const result = asRecord(record["result"]);
  const batchResults = Array.isArray(record["batch_results"])
    ? record["batch_results"]
    : [];
  const firstBatchResult = asRecord(batchResults[0]);
  const asset = asRecord(record["asset"]);
  const primaryBatchResult =
    batch.variants.find((variant) =>
      variant.videoUrl != null || variant.downloadUrl != null
    ) ?? batch.variants[0];
  return {
    id: firstNonEmptyString(
      record["id"],
      record["generation_id"],
      record["video_id"],
      primaryBatchResult?.id,
      firstBatchResult?.["id"],
      video?.["id"],
      result?.["id"],
    ),
    status: firstNonEmptyString(
      record["status"],
      primaryBatchResult?.status,
      firstBatchResult?.["status"],
      video?.["status"],
      result?.["status"],
    ) ?? "submitted",
    videoUrl: firstNonEmptyString(
      primaryBatchResult?.videoUrl,
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
      primaryBatchResult?.previewUrl,
      record["preview_url"],
      record["streaming_url"],
      record["thumbnail_url"],
      video?.["preview_url"],
      result?.["preview_url"],
    ),
    downloadUrl: firstNonEmptyString(
      primaryBatchResult?.downloadUrl,
      record["download_url"],
      video?.["download_url"],
      result?.["download_url"],
    ),
    progress: firstNumber(
      record["progress"],
      primaryBatchResult?.progress,
      firstBatchResult?.["progress"],
      result?.["progress"],
    ),
    etaSec: firstNumber(
      record["eta_sec"],
      primaryBatchResult?.etaSec,
      result?.["eta_sec"],
    ),
    reason: firstNonEmptyString(
      record["error_message"],
      record["error"],
      firstBatchResult?.["error"],
      result?.["error_message"],
      result?.["error"],
    ),
    batchGenerationId: batch.batchGenerationId,
    batchSize: batch.batchSize,
    generationIds: batch.generationIds,
    batchResults: batch.variants,
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

function uniqueNonEmptyStrings(values: unknown[]): string[] {
  const seen = new Set<string>();
  for (const value of values) {
    const text = typeof value === "string" ? value.trim() : "";
    if (text.length > 0) seen.add(text);
  }
  return [...seen];
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

function envFlag(value: string | null | undefined): boolean {
  return ["1", "true", "yes", "on"].includes(
    (value ?? "").trim().toLowerCase(),
  );
}
