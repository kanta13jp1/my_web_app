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
// POST { "type": "image" | "presenter_video" | "video_script", "template": "dark_war" | "feature_highlight" | "ai_secretary_site_tour" | "mobile_ux_validation" | "user_growth", "lang": "ja" | "en" }
// GET  ?view=templates | ?view=history

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildHedraTextToSpeechAudioGeneration,
  extractHedraTextToSpeechModelId,
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
const HEDRA_TTS_MODEL_ID = Deno.env.get("HEDRA_TTS_MODEL_ID") ??
  Deno.env.get("HEDRA_TEXT_TO_SPEECH_MODEL_ID") ?? "";
const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
const ELEVENLABS_LEGACY_FALLBACK_VOICE_ID = "JBFqnCBsd6RMkjVDRZzb";
const ELEVENLABS_SECRETARY_VOICE_ID =
  Deno.env.get("ELEVENLABS_SECRETARY_VOICE_ID") ?? "21m00Tcm4TlvDq8ikWAM";
const ELEVENLABS_VOICE_ID = Deno.env.get("ELEVENLABS_VOICE_ID") ??
  ELEVENLABS_LEGACY_FALLBACK_VOICE_ID;
const ELEVENLABS_CURATED_FEMALE_VOICE_IDS: ElevenLabsVoiceCandidate[] = [
  { id: "EXAVITQu4vr4xnSDxMaL", profile: "curated_female_sarah" },
  { id: "pFZP5JQG7iQjIQuC4Bku", profile: "curated_female_lily" },
  { id: "Xb7hH8MSUJpSbSDYk0k2", profile: "curated_female_alice" },
  { id: "XrExE9yKIg1WjnnlVkGX", profile: "curated_female_matilda" },
  { id: "LcfcDJNUP1GQjkzn1xUU", profile: "curated_female_emily" },
  { id: "XB0fDUnXU5powFXDhCwa", profile: "curated_female_charlotte" },
  { id: "AZnzlk1XvdvUeBnXmlld", profile: "curated_female_domi" },
  { id: "MF3mGyEYCl7XYWbV9V6O", profile: "curated_female_elli" },
  { id: "ThT5KcBeYPX3keUQqHPh", profile: "curated_female_dorothy" },
  { id: "oWAxZDx7w5VEj9dCyTzz", profile: "curated_female_grace" },
  { id: "jBpfuIE2acCO8z3wKNLl", profile: "curated_female_gigi" },
  { id: "zrHiDhphv9ZnVXBqCLjz", profile: "curated_female_mimi" },
];
const ELEVENLABS_MODEL_ID = Deno.env.get("ELEVENLABS_MODEL_ID") ??
  "eleven_multilingual_v2";
const ELEVENLABS_OUTPUT_FORMAT = Deno.env.get("ELEVENLABS_OUTPUT_FORMAT") ??
  "mp3_44100_128";
const ELEVENLABS_LANGUAGE_CODE = Deno.env.get("ELEVENLABS_LANGUAGE_CODE") ?? "";
const GENERATED_VIDEO_BUCKET = "viral-ad-videos";
const MAX_STORED_VIDEO_BYTES = 100 * 1024 * 1024;

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
  ai_secretary_site_tour: {
    name: "AI秘書サイトツアー",
    description:
      "知的で上品に魅力的なAI秘書が、サイトの主要機能を詳しく案内する高品質動画",
    script: {
      ja: [
        "はじめまして。知的で上品なAI秘書が、自分株式会社を案内します。",
        "AI秘書に聞けば、次に開くべき機能や作業の入口がすぐ分かります。",
        "AI大学では、AIニュースや主要AI企業を体系的に学び、仕事に転用できます。",
        "ノート、仕事ログ、資産管理、英語学習を同じ場所でつなぎます。",
        "迷ったら5分だけ触って、役に立つ点と詰まった点を教えてください。",
        "https://my-web-app-b67f4.web.app/",
      ],
      en: [
        "Hello. Your elegant AI executive secretary will guide you through this site.",
        "Ask the AI secretary and you can quickly find the right feature or workflow.",
        "AI University helps you learn AI news and major AI companies systematically.",
        "Notes, work logs, finance, and English learning connect in one workspace.",
        "Try it for five minutes and tell us what helped or what felt confusing.",
        "https://my-web-app-b67f4.web.app/",
      ],
    },
    imagePrompt:
      "A sophisticated adult AI executive secretary in a tasteful fitted dark suit, intelligent and subtly alluring expression, premium futuristic office, holographic dashboard panels showing AI assistant, AI University, notes, finance, work logs, English learning, cinematic lighting, elegant luxury SaaS commercial, brand-safe, no nudity, no explicit sexualization, 16:9",
    hashtags: ["#AI秘書", "#AI大学", "#buildinpublic", "#FlutterWeb"],
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
    name: "初回ユーザー募集ストーリー",
    description: "X経由で最初の実ユーザーを探すための正直な募集動画",
    script: {
      ja: [
        "AI仕事OSの最初の実ユーザーを探しています。",
        "学習、仕事ログ、資産、メモを1つの画面にまとめる実験です。",
        "5分だけ触って、使えそうな点と困った点を教えてください。",
        "知人頼みではなく、Xから最初の1人を探しています。",
        "https://my-web-app-b67f4.web.app/",
      ],
      en: [
        "I'm looking for the first real user of AI Work OS.",
        "It brings learning, work logs, finance, and notes into one workspace.",
        "Try it for five minutes and tell me what works or breaks.",
        "I'm looking for the first user through X, not warm contacts.",
        "https://my-web-app-b67f4.web.app/",
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
    let videoAudioProvider: string | null = null;
    let videoAudioReason: string | null = null;
    let videoAudioAssetId: string | null = null;
    let videoAudioVoiceId: string | null = null;
    let videoAudioVoiceProfile: string | null = null;
    let hedraGenerationId: string | null = null;
    let hedraProgress: number | null = null;
    let hedraEtaSec: number | null = null;
    let storedVideoUrl: string | null = null;
    let storedVideoPath: string | null = null;
    let storedVideoMimeType: string | null = null;
    let storedVideoSizeBytes: number | null = null;
    let videoStorageError: string | null = null;

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
          videoAudioProvider = hedraVideo.audioProvider ?? null;
          videoAudioReason = hedraVideo.audioReason ?? null;
          videoAudioAssetId = hedraVideo.audioAssetId ?? null;
          videoAudioVoiceId = hedraVideo.audioVoiceId ?? null;
          videoAudioVoiceProfile = hedraVideo.audioVoiceProfile ?? null;
          hedraGenerationId = hedraVideo.id;
          hedraProgress = hedraVideo.progress;
          hedraEtaSec = hedraVideo.etaSec;
          const videoSourceUrl = firstNonEmptyString(
            hedraVideo.downloadUrl,
            hedraVideo.videoUrl,
          );
          if (videoSourceUrl) {
            try {
              const storedVideo = await persistGeneratedVideoToStorage(admin, {
                sourceUrl: videoSourceUrl,
                generationId: hedraVideo.id,
                templateKey,
                lang,
              });
              storedVideoUrl = storedVideo.url;
              storedVideoPath = storedVideo.path;
              storedVideoMimeType = storedVideo.contentType;
              storedVideoSizeBytes = storedVideo.sizeBytes;
              generatedVideoUrl = storedVideo.url;
              generatedDownloadUrl = storedVideo.url;
            } catch (error) {
              videoStorageError = error instanceof Error
                ? error.message
                : String(error);
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
          video_audio_provider: videoAudioProvider,
          video_audio_reason: videoAudioReason,
          video_audio_asset_id: videoAudioAssetId,
          hedra_generation_id: hedraGenerationId,
          hedra_progress: hedraProgress,
          hedra_eta_sec: hedraEtaSec,
          stored_video_url: storedVideoUrl,
          stored_video_path: storedVideoPath,
          stored_video_mime_type: storedVideoMimeType,
          stored_video_size_bytes: storedVideoSizeBytes,
          video_storage_error: videoStorageError,
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
      videoAudioProvider,
      videoAudioReason,
      videoAudioAssetId,
      videoAudioVoiceId,
      videoAudioVoiceProfile,
      storedVideoUrl,
      storedVideoPath,
      storedVideoMimeType,
      storedVideoSizeBytes,
      videoStorageError,
      status: generatedVideoUrl != null || generatedImageUrl != null
        ? "ready_to_post"
        : generationStatus,
      nextStep: storedVideoUrl != null
        ? "Use storedVideoUrl and caption for the next X post; the video is now hosted from Supabase Storage."
        : generatedVideoUrl != null
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

function stripUrlsForVoiceover(line: string): string {
  return line
    .replace(/\[([^\]]+)\]\(https?:\/\/[^\s)]+\)/g, "$1")
    .replace(/https?:\/\/[^\s　)]+/g, "")
    .replace(/\bmy-web-app-b67f4\.web\.app\/?[^\s　)]*/gi, "")
    .replace(/\s+/g, " ")
    .replace(/^Open\s+to try it\.?$/i, "Try it for five minutes.")
    .replace(/\s+([。．、，,.!?！？])/g, "$1")
    .replace(/[→:：\-–—|｜]\s*$/g, "")
    .replace(/^(を|から|で|へ|に)\s*/, "")
    .trim();
}

function voiceoverLinesWithoutUrls(script: string[]): string[] {
  return script
    .map(stripUrlsForVoiceover)
    .filter((line) => line.length > 0)
    .slice(0, 6);
}

function scriptForHedraVoice(
  script: string[],
  lang: "ja" | "en",
  title?: string,
): string[] {
  const sanitized = voiceoverLinesWithoutUrls(script);
  if (lang === "en") {
    return sanitized.length > 0
      ? sanitized
      : ["Try it for five minutes and tell us what felt useful."];
  }
  const englishTitle = hedraEnglishTitle(title);
  return [
    `${englishTitle} has been updated.`,
    "This short video introduces the newest improvement in the app.",
    "The creative workflow combines GPT image two, GPT five point five, and Seedance two point zero.",
    "Try it for five minutes, then share what helped and what felt confusing.",
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
  audioProvider?: string | null;
  audioReason?: string | null;
  audioAssetId?: string | null;
  audioVoiceId?: string | null;
  audioVoiceProfile?: string | null;
};

type ElevenLabsSpeech = {
  bytes: Uint8Array;
  contentType: string;
  filename: string;
  voiceId: string;
  voiceProfile: string;
  warning: string | null;
};

type ElevenLabsVoiceCandidate = {
  id: string;
  profile: string;
};

type StoredVideo = {
  url: string;
  path: string;
  contentType: string;
  sizeBytes: number;
};

async function persistGeneratedVideoToStorage(
  admin: SupabaseClient,
  params: {
    sourceUrl: string;
    generationId: string | null;
    templateKey: string;
    lang: string;
  },
): Promise<StoredVideo> {
  const response = await fetch(params.sourceUrl);
  if (!response.ok) {
    const rawText = await response.text().catch(() => "");
    throw new Error(
      `Generated video download ${response.status}: ${
        rawText.trim() || response.statusText
      }`,
    );
  }

  const contentType = normalizeVideoContentType(
    response.headers.get("content-type"),
  );
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength === 0) {
    throw new Error("Generated video download was empty");
  }
  if (bytes.byteLength > MAX_STORED_VIDEO_BYTES) {
    throw new Error(
      `Generated video is too large to store (${bytes.byteLength} bytes)`,
    );
  }

  const datePrefix = new Date().toISOString().slice(0, 10);
  const generationSegment = storageSafeSegment(
    params.generationId ?? crypto.randomUUID(),
  );
  const path = [
    "hedra",
    datePrefix,
    `${generationSegment}-${storageSafeSegment(params.templateKey)}-${
      storageSafeSegment(params.lang)
    }.${extensionForVideoContentType(contentType)}`,
  ].join("/");

  const { error } = await admin.storage
    .from(GENERATED_VIDEO_BUCKET)
    .upload(path, bytes, {
      contentType,
      cacheControl: "604800",
      upsert: true,
    });
  if (error) {
    throw new Error(`Supabase Storage upload failed: ${error.message}`);
  }

  const { data } = admin.storage.from(GENERATED_VIDEO_BUCKET).getPublicUrl(
    path,
  );
  if (!data.publicUrl) {
    throw new Error("Supabase Storage did not return a public video URL");
  }

  return {
    url: data.publicUrl,
    path,
    contentType,
    sizeBytes: bytes.byteLength,
  };
}

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
  const hedraLanguage = hedraLanguageForLang(params.lang);
  const ttsScript = scriptForHedraVoice(
    params.script,
    params.lang,
    params.title,
  )
    .join("\n");
  let audioProvider = "hedra";
  let audioReason: string | null = null;
  let audioAssetId: string | null = null;
  let audioVoiceId: string | null = null;
  let audioVoiceProfile: string | null = null;
  if (ELEVENLABS_API_KEY) {
    try {
      const speech = await generateElevenLabsSpeech({
        apiKey: ELEVENLABS_API_KEY,
        text: scriptForElevenLabsVoice(params.script, params.lang, params.title)
          .join("\n")
          .slice(0, 1800),
        lang: params.lang,
        voice: params.voice,
      });
      audioAssetId = await createHedraAudioAssetFromElevenLabs(
        params.apiKey,
        speech,
      );
      audioProvider = "elevenlabs";
      audioVoiceId = speech.voiceId;
      audioVoiceProfile = speech.voiceProfile;
      audioReason = speech.warning;
    } catch (error) {
      audioReason = `ElevenLabs audio failed; fell back to Hedra TTS: ${
        error instanceof Error ? error.message : String(error)
      }`;
    }
  } else {
    audioReason = "ELEVENLABS_API_KEY not configured; using Hedra TTS";
  }
  const generationBody: Record<string, unknown> = {
    type: "video",
    ai_model_id: HEDRA_AVATAR_MODEL_ID,
    start_keyframe_url: imageUrl,
    generated_video_inputs: {
      text_prompt: `${params.title ?? "Share update"}\n${params.prompt}`,
      ai_model_id: HEDRA_AVATAR_MODEL_ID,
      aspect_ratio: "16:9",
      resolution: "540p",
      enhance_prompt: true,
    },
  };
  let canRetryWithoutTtsModel = false;
  if (audioAssetId) {
    generationBody.audio_id = audioAssetId;
  } else {
    const ttsModelId = await resolveHedraTextToSpeechModelId(params.apiKey);
    if (!ttsModelId) {
      throw new Error(
        `Hedra text_to_speech model_id could not be resolved. Configure HEDRA_TTS_MODEL_ID or restore ElevenLabs audio assets.${
          audioReason ? ` audio fallback detail: ${audioReason}` : ""
        }`,
      );
    }
    canRetryWithoutTtsModel = true;
    generationBody.audio_generation = buildHedraTextToSpeechAudioGeneration({
      voiceId,
      modelId: ttsModelId,
      text: ttsScript.slice(0, 1800),
      language: hedraLanguage,
    });
  }
  const payload = await createHedraGenerationWithTtsModelFallback(
    params.apiKey,
    generationBody,
    canRetryWithoutTtsModel,
  )
    .catch((error) => {
      if (!audioReason) throw error;
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`${message}; audio fallback detail: ${audioReason}`);
    });
  const result = await pollHedraGeneration(
    params.apiKey,
    normalizeHedraVideoResponse(payload),
  );
  return {
    ...result,
    audioProvider,
    audioReason: result.audioReason ?? audioReason,
    audioAssetId,
    audioVoiceId,
    audioVoiceProfile,
  };
}

function scriptForElevenLabsVoice(
  script: string[],
  _lang: "ja" | "en",
  title?: string,
): string[] {
  const lines = voiceoverLinesWithoutUrls(script);
  if (lines.length > 0) return lines;
  return [title?.trim() || "Share update"];
}

async function generateElevenLabsSpeech(params: {
  apiKey: string;
  text: string;
  lang: "ja" | "en";
  voice: string;
}): Promise<ElevenLabsSpeech> {
  const candidates = await resolveElevenLabsVoiceCandidates(
    params.apiKey,
    params.voice,
    params.lang,
  );
  const errors: string[] = [];
  for (const voice of candidates) {
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${
        encodeURIComponent(voice.id)
      }?output_format=${encodeURIComponent(ELEVENLABS_OUTPUT_FORMAT)}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "xi-api-key": params.apiKey,
        },
        body: JSON.stringify({
          ...elevenLabsTextToSpeechBody(params.text),
        }),
      },
    );
    if (response.ok) {
      return {
        bytes: new Uint8Array(await response.arrayBuffer()),
        contentType: response.headers.get("content-type") ?? "audio/mpeg",
        filename: `elevenlabs-share-${Date.now()}.mp3`,
        voiceId: voice.id,
        voiceProfile: voice.profile,
        warning: errors.length === 0
          ? null
          : `ElevenLabs voice fallback used after: ${errors.join(" | ")}`,
      };
    }
    const rawText = await response.text();
    errors.push(
      `${voice.profile}:${response.status}:${
        rawText.trim() || response.statusText
      }`,
    );
  }
  throw new Error(
    `ElevenLabs API failed for all voice candidates: ${errors.join(" | ")}`,
  );
}

async function resolveElevenLabsVoiceCandidates(
  apiKey: string,
  preferredVoice: string,
  lang: "ja" | "en",
): Promise<ElevenLabsVoiceCandidate[]> {
  const requested = firstNonEmptyString(preferredVoice) ?? "";
  const alias = requested.toLowerCase();
  const secretaryVoiceId = firstNonEmptyString(
    ELEVENLABS_SECRETARY_VOICE_ID,
    ELEVENLABS_VOICE_ID,
  );
  const defaultVoiceId = firstNonEmptyString(
    ELEVENLABS_VOICE_ID,
    secretaryVoiceId,
  );
  const candidates: ElevenLabsVoiceCandidate[] = [];
  if (
    alias === "ai_secretary_female" ||
    alias === "secretary" ||
    alias === "female" ||
    alias === "ja-jp" ||
    alias.includes("secretary") ||
    alias.includes("female")
  ) {
    if (!secretaryVoiceId) {
      throw new Error("ELEVENLABS_SECRETARY_VOICE_ID is empty");
    }
    candidates.push({ id: secretaryVoiceId, profile: "ai_secretary_female" });
    candidates.push(...ELEVENLABS_CURATED_FEMALE_VOICE_IDS);
  }
  if (isLikelyElevenLabsVoiceId(requested)) {
    candidates.push({ id: requested, profile: "custom_request" });
  }
  candidates.push(
    ...await resolveAvailableElevenLabsFemaleVoices(apiKey, lang),
  );
  if (!defaultVoiceId) {
    throw new Error("ELEVENLABS_VOICE_ID is empty");
  }
  candidates.push({
    id: defaultVoiceId,
    profile: lang === "ja" ? "default_ja" : "default",
  });
  return uniqueElevenLabsVoiceCandidates(candidates);
}

async function resolveAvailableElevenLabsFemaleVoices(
  apiKey: string,
  lang: "ja" | "en",
): Promise<ElevenLabsVoiceCandidate[]> {
  try {
    const response = await fetch("https://api.elevenlabs.io/v1/voices", {
      headers: { "xi-api-key": apiKey },
    });
    if (!response.ok) return [];
    const payload = await response.json().catch(() => ({})) as unknown;
    const voices = Array.isArray(asRecord(payload)?.["voices"])
      ? asRecord(payload)?.["voices"] as unknown[]
      : Array.isArray(payload)
      ? payload as unknown[]
      : [];
    return voices
      .map((voice) => asRecord(voice))
      .filter((voice): voice is Record<string, unknown> => voice !== null)
      .map((voice) => ({
        voice,
        id: firstNonEmptyString(voice["voice_id"], voice["id"]),
        score: elevenLabsFemaleVoiceScore(voice, lang),
      }))
      .filter((entry) => entry.id != null && entry.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5)
      .map((entry) => ({
        id: entry.id as string,
        profile: `available_female:${
          storageSafeSegment(
            firstNonEmptyString(entry.voice["name"]) ?? "voice",
          )
        }`,
      }));
  } catch {
    return [];
  }
}

function elevenLabsFemaleVoiceScore(
  voice: Record<string, unknown>,
  lang: "ja" | "en",
): number {
  const name = String(voice["name"] ?? "").toLowerCase();
  const labels = asRecord(voice["labels"]) ?? {};
  const description = String(voice["description"] ?? "").toLowerCase();
  const preview = String(voice["preview_url"] ?? "").toLowerCase();
  const category = String(voice["category"] ?? "").toLowerCase();
  const labelsText = Object.entries(labels)
    .map(([key, value]) => `${key}:${String(value).toLowerCase()}`)
    .join(" ");
  const haystack =
    `${name} ${description} ${preview} ${category} ${labelsText}`;
  let score = 0;
  if (haystack.includes("gender:female") || haystack.includes("female")) {
    score += 100;
  }
  if (haystack.includes("woman") || haystack.includes("feminine")) score += 40;
  if (haystack.includes("japanese") || haystack.includes("ja")) score += 25;
  if (lang === "ja" && haystack.includes("multilingual")) score += 15;
  for (
    const marker of [
      "aria",
      "rachel",
      "bella",
      "sarah",
      "laura",
      "jessica",
      "lily",
      "emily",
      "alice",
      "serena",
      "mimi",
      "domi",
      "elli",
      "matilda",
      "dorothy",
      "freya",
    ]
  ) {
    if (name.includes(marker)) score += 20;
  }
  if (/\bmale\b/.test(haystack) || /\bman\b/.test(haystack)) score -= 120;
  return score;
}

function uniqueElevenLabsVoiceCandidates(
  candidates: ElevenLabsVoiceCandidate[],
): ElevenLabsVoiceCandidate[] {
  const seen = new Set<string>();
  const unique: ElevenLabsVoiceCandidate[] = [];
  for (const candidate of candidates) {
    if (!candidate.id || seen.has(candidate.id)) continue;
    seen.add(candidate.id);
    unique.push(candidate);
  }
  return unique;
}

function elevenLabsTextToSpeechBody(text: string): Record<string, unknown> {
  const body: Record<string, unknown> = {
    text,
    model_id: ELEVENLABS_MODEL_ID,
    voice_settings: {
      stability: 0.5,
      similarity_boost: 0.75,
      use_speaker_boost: true,
    },
  };
  const configuredLanguage = firstNonEmptyString(ELEVENLABS_LANGUAGE_CODE);
  if (configuredLanguage) body.language_code = configuredLanguage;
  return body;
}

async function resolveHedraTextToSpeechModelId(
  apiKey: string,
): Promise<string | null> {
  const configured = resolveConfiguredHedraTextToSpeechModelId(
    HEDRA_TTS_MODEL_ID,
  );
  if (configured) return configured;
  try {
    return extractHedraTextToSpeechModelId(
      await hedraJsonRequest(apiKey, "/models", { method: "GET" }),
    );
  } catch {
    return null;
  }
}

async function createHedraAudioAssetFromElevenLabs(
  apiKey: string,
  speech: ElevenLabsSpeech,
): Promise<string> {
  const audioAssetId = await createHedraAsset(
    apiKey,
    speech.filename,
    "audio",
  );
  await uploadHedraAsset(apiKey, audioAssetId, speech);
  return audioAssetId;
}

async function createHedraAsset(
  apiKey: string,
  name: string,
  type: "audio" | "image",
): Promise<string> {
  const payload = await hedraJsonRequest(apiKey, "/assets", {
    method: "POST",
    body: { name, type },
  });
  const assetId = extractHedraAssetId(payload);
  if (!assetId) {
    throw new Error("Hedra asset id was missing from create asset response");
  }
  return assetId;
}

async function uploadHedraAsset(
  apiKey: string,
  assetId: string,
  speech: ElevenLabsSpeech,
): Promise<void> {
  const form = new FormData();
  const audioBuffer = new ArrayBuffer(speech.bytes.byteLength);
  new Uint8Array(audioBuffer).set(speech.bytes);
  form.append(
    "file",
    new Blob([audioBuffer], { type: speech.contentType }),
    speech.filename,
  );
  const response = await fetch(
    `${HEDRA_API_BASE}/assets/${encodeURIComponent(assetId)}/upload`,
    {
      method: "POST",
      headers: { "X-API-Key": apiKey },
      body: form,
    },
  );
  if (!response.ok) {
    const rawText = await response.text();
    throw new Error(
      `Hedra asset upload ${response.status}: ${
        rawText.trim() || response.statusText
      }`,
    );
  }
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

function isLikelyElevenLabsVoiceId(value: string): boolean {
  return /^[A-Za-z0-9]{16,}$/.test(value);
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

function storageSafeSegment(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") ||
    "unknown";
}

function normalizeVideoContentType(value: string | null): string {
  const contentType = value?.split(";")[0]?.trim().toLowerCase() ?? "";
  if (
    contentType === "video/mp4" ||
    contentType === "video/webm" ||
    contentType === "video/quicktime" ||
    contentType === "application/octet-stream"
  ) {
    return contentType;
  }
  return "video/mp4";
}

function extensionForVideoContentType(contentType: string): string {
  if (contentType === "video/webm") return "webm";
  if (contentType === "video/quicktime") return "mov";
  return "mp4";
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
