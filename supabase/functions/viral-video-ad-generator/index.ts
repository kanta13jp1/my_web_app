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
// POST { "type": "image" | "presenter_video" | "video_script", "template": "dark_war" | "feature_highlight" | "mobile_ux_validation" | "user_growth" | "ai_secretary_site_tour", "lang": "ja" | "en" }
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
const VIRAL_VIDEO_BUCKET = "viral-ad-videos";

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

    let generatedImageUrl: string | null = null;
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
      } else if (
        templateKey === "ai_secretary_site_tour" && !ELEVENLABS_API_KEY
      ) {
        videoProvider = "hedra";
        videoStatus = "fallback_text";
        videoReason =
          "ELEVENLABS_API_KEY not configured; ai_secretary_site_tour requires ElevenLabs uploaded audio to avoid Hedra text_to_speech model errors.";
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
          hedraProgress = hedraVideo.progress;
          hedraEtaSec = hedraVideo.etaSec;
          const videoToStore = firstNonEmptyString(
            hedraVideo.videoUrl,
            hedraVideo.downloadUrl,
          );
          if (videoToStore) {
            const stored = await persistRemoteMediaToStorage(admin, {
              url: videoToStore,
              prefix: "hedra",
              fileName: `${hedraVideo.id ?? crypto.randomUUID()}-${
                storageSafeSegment(templateKey)
              }-${lang}.mp4`,
              contentType: "video/mp4",
            });
            storedVideoUrl = stored?.url ?? null;
            storedVideoPath = stored?.path ?? null;
            generatedVideoUrl = storedVideoUrl ?? generatedVideoUrl;
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
          generated_video_url: storedVideoUrl ?? generatedVideoUrl,
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
      storedVideoUrl,
      storedVideoPath,
      storedAudioUrl,
      storedAudioPath,
      videoAudioProvider,
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
  let audioProvider = "hedra_tts";
  let storedAudioUrl: string | null = null;
  let storedAudioPath: string | null = null;
  let audioGeneration: Record<string, unknown>;

  if (HEDRA_UPLOADED_AUDIO_ENABLED && ELEVENLABS_API_KEY) {
    try {
      const audio = await createElevenLabsSpeechAsset(params.admin, {
        text: spokenScript.slice(0, 1800),
        templateTitle: params.title ?? "share-update",
        lang: params.lang,
      });
      audioGeneration = buildHedraUploadedAudioGeneration(audio.url);
      audioProvider = "elevenlabs";
      storedAudioUrl = audio.url;
      storedAudioPath = audio.path;
    } catch (error) {
      if (
        params.requiresUploadedAudio &&
        shouldRetryElevenLabsWithFallbackVoice(error)
      ) {
        const fallbackResult = await tryElevenLabsFallbackVoices(params.admin, {
          text: spokenScript.slice(0, 1800),
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
            fallbackText: spokenScript.slice(0, 1800),
          });
        }
        if (OPENAI_API_KEY) {
          try {
            const openAiAudio = await createOpenAiSpeechAsset(params.admin, {
              text: spokenScript.slice(0, 1800),
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
              fallbackText: spokenScript.slice(0, 1800),
            });
          } catch (openAiError) {
            throw new Error(
              `${fallbackResult.reason}; openai_tts=${
                providerErrorMessage(openAiError)
              }`,
            );
          }
        }
        throw new Error(
          `${fallbackResult.reason}; openai_tts=OPENAI_API_KEY not configured`,
        );
      }
      if (params.requiresUploadedAudio) {
        throw new Error(
          `ElevenLabs speech generation failed before Hedra video generation: ${
            providerErrorMessage(error)
          }`,
        );
      }
      console.warn("ElevenLabs speech generation failed; falling back", error);
      audioGeneration = await createHedraTextToSpeechAudioGeneration(params, {
        text: spokenScript.slice(0, 1800),
      });
    }
  } else {
    audioGeneration = await createHedraTextToSpeechAudioGeneration(params, {
      text: spokenScript.slice(0, 1800),
    });
  }

  return await createHedraVideoFromUploadedAudio(params, {
    audioGeneration,
    storedAudioUrl,
    storedAudioPath,
    audioProvider,
    imageUrl,
    fallbackText: spokenScript.slice(0, 1800),
  });
}

async function createHedraVideoFromUploadedAudio(
  params: {
    apiKey: string;
    title?: string;
    prompt: string;
    voice: string;
    lang: "ja" | "en";
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
  const generationBody: Record<string, unknown> = {
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
  };
  let payload: unknown;
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
    }
    throw error;
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
  if (configured) return configured;

  try {
    const payload = await hedraJsonRequest(apiKey, "/models", {
      method: "GET",
    });
    const models = extractHedraModelList(payload);
    return selectBestHedraTextToSpeechModelId(models);
  } catch (error) {
    console.warn(
      "Hedra TTS model discovery failed",
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
