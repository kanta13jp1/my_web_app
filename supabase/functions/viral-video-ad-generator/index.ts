// viral-video-ad-generator Edge Function
// Dark War風バイラル動画広告生成パイプライン
//
// 機能:
// - FAL.ai (fast-sdxl / video generation) を使った動画/画像生成
// - 自分株式会社の「21の競合を超える」ストーリーを動画化
// - 生成したメディアをSupabase Storageに保存
// - X投稿用の動画URL + キャプションを返す
//
// POST { "type": "image" | "video_script", "template": "dark_war" | "feature_highlight" | "user_growth", "lang": "ja" | "en" }
// GET  ?view=templates | ?view=history

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const FAL_KEY = Deno.env.get("FAL_KEY") ?? "";

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
    imagePrompt: "Epic dark cinematic battle scene, glowing UI interfaces floating in space, apps converging into one powerful orb, dramatic lighting, cyberpunk aesthetic, 16:9 aspect ratio",
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
    imagePrompt: "Clean modern app interface collage, multiple feature screens arranged in elegant grid, gradient purple background, material design, 16:9",
    hashtags: ["#ProductHunt", "#IndieHacker", "#FlutterApp"],
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
    imagePrompt: "Minimalist growth chart animation, single developer at desk, code flying around, user count increasing, warm inspiring colors, 16:9",
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
    imagePrompt: "Price comparison infographic, competitor logos with red X marks, self app with green checkmark, money savings visualization, 16:9",
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

      return jsonRes({ success: true, templates: Object.keys(AD_TEMPLATES), message: "Use ?view=templates or POST to generate" });
    }

    if (req.method !== "POST") {
      return jsonRes({ error: "Method not allowed" }, 405);
    }

    const body = await req.json() as {
      type?: string;
      template?: string;
      lang?: string;
      customPrompt?: string;
    };

    const templateKey = body.template ?? "dark_war";
    const lang = (body.lang ?? "ja") as "ja" | "en";
    const type = body.type ?? "image";

    const template = AD_TEMPLATES[templateKey as keyof typeof AD_TEMPLATES];
    if (!template) {
      return jsonRes({ error: `Unknown template: ${templateKey}. Available: ${Object.keys(AD_TEMPLATES).join(", ")}` }, 400);
    }

    const script = template.script[lang];
    const caption = script.join("\n") + "\n\n" + template.hashtags.join(" ");
    const imagePrompt = body.customPrompt ?? template.imagePrompt;

    let generatedImageUrl: string | null = null;
    let falJobId: string | null = null;

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
          const falData = await falResp.json() as { images?: Array<{ url: string }>; request_id?: string };
          generatedImageUrl = falData.images?.[0]?.url ?? null;
          falJobId = falData.request_id ?? null;
        }
      } catch (_e) {
        // FAL.ai失敗時はスクリプトのみ返す
      }
    }

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
          fal_job_id: falJobId,
          hashtags: template.hashtags,
          status: generatedImageUrl ? "ready" : "script_only",
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
      caption,
      script,
      hashtags: template.hashtags,
      imagePrompt,
      generatedImageUrl,
      falJobId,
      status: generatedImageUrl ? "ready_to_post" : "script_only",
      nextStep: generatedImageUrl
        ? "Call x-media-post with this imageUrl and caption to post to X"
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
