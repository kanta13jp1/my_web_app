import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// Social proof templates for different contexts
const PROOF_TEMPLATES = {
  registration_count: [
    "現在{count}人のユーザーが自分株式会社を利用中！",
    "{count}人が21のSaaS競合を超えるAI統合プラットフォームを体験中",
    "自分株式会社：{count}人のユーザーがNotion・Slack・Xの機能を1つで",
  ],
  feature_count: [
    "{count}以上の機能を無料で利用可能 — 競合21社分のSaaSを1アプリに統合",
    "AIアシスタント含む{count}機能を搭載。Notion+Evernote+MoneyForward+Xの統合体験",
    "Edge Function {count}本稼働中 — 企業レベルのバックエンド基盤",
  ],
  recent_activity: [
    "直近24時間で{count}件のアクティビティ — コミュニティ活発化中！",
    "今週{count}件の新機能リクエスト — ユーザーと共に進化するプラットフォーム",
  ],
  developer_velocity: [
    "今週{count}件のコミット — 毎日進化し続けるプラットフォーム",
    "{count}件の開発実績を達成 — AI駆動の高速開発",
    "12部署20エージェントのAI仮想組織が24時間開発を推進中",
  ],
  competitor_comparison: [
    "Notion: ¥{notionPrice}/月 → 自分株式会社: 無料で同等以上の機能",
    "Slack + Notion + MoneyForward = 月額¥{totalPrice}以上 → 自分株式会社なら無料",
    "21の競合SaaSの機能を1つに統合 — もうアプリの切り替えは不要",
  ],
} as const;

type TemplateKey = keyof typeof PROOF_TEMPLATES;

// Competitor pricing for comparison
const COMPETITOR_PRICES = {
  notion: 1650,
  evernote: 1100,
  moneyforward: 500,
  slack: 1050,
  chatwork: 700,
  jobcan: 400,
  x_premium: 980,
} as const;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "generate";

    if (action === "generate") {
      const proofType = url.searchParams.get("type") as TemplateKey | null;

      // Gather real data
      const { data: { users } } = await supabase.auth.admin.listUsers({ perPage: 1000 });
      const totalUsers = users?.length ?? 0;

      const { data: achievements } = await supabase
        .from("development_achievements")
        .select("id")
        .limit(1000);
      const achievementCount = achievements?.length ?? 0;

      const { data: recentActivity } = await supabase
        .from("app_analytics")
        .select("id")
        .gte("created_at", new Date(Date.now() - 86400000).toISOString())
        .limit(1000);
      const activityCount = recentActivity?.length ?? 0;

      const { data: featureRequests } = await supabase
        .from("app_analytics")
        .select("id")
        .eq("event_type", "feature_request")
        .gte("created_at", new Date(Date.now() - 7 * 86400000).toISOString())
        .limit(100);
      const weeklyRequests = featureRequests?.length ?? 0;

      // Calculate total competitor monthly cost
      const totalCompetitorCost = Object.values(COMPETITOR_PRICES).reduce((sum, p) => sum + p, 0);

      // Generate proofs based on type or all
      const generateProofs = (type: TemplateKey) => {
        const templates = PROOF_TEMPLATES[type];
        return templates.map(template => {
          let text = template;
          text = text.replace("{count}", String(
            type === "registration_count" ? totalUsers :
            type === "feature_count" ? 228 :
            type === "recent_activity" ? (type === "recent_activity" ? activityCount : weeklyRequests) :
            type === "developer_velocity" ? achievementCount :
            0
          ));
          text = text.replace("{notionPrice}", String(COMPETITOR_PRICES.notion));
          text = text.replace("{totalPrice}", String(totalCompetitorCost).replace(/\B(?=(\d{3})+(?!\d))/g, ","));
          return text;
        });
      };

      if (proofType && proofType in PROOF_TEMPLATES) {
        return new Response(
          JSON.stringify({
            type: proofType,
            proofs: generateProofs(proofType),
            data: { totalUsers, achievementCount, activityCount },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Generate all types
      const allProofs: Record<string, string[]> = {};
      for (const type of Object.keys(PROOF_TEMPLATES) as TemplateKey[]) {
        allProofs[type] = generateProofs(type);
      }

      return new Response(
        JSON.stringify({
          proofs: allProofs,
          realTimeData: {
            totalUsers,
            totalFeatures: 228,
            totalAchievements: achievementCount,
            dailyActivity: activityCount,
            weeklyFeatureRequests: weeklyRequests,
            competitorCostSaved: totalCompetitorCost,
            edgeFunctionsDeployed: 100,
            aiAgents: 20,
            departments: 12,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=share_card — Generate share-ready social proof card data
    if (action === "share_card") {
      const platform = url.searchParams.get("platform") ?? "x";

      const { data: { users } } = await supabase.auth.admin.listUsers({ perPage: 1000 });
      const totalUsers = users?.length ?? 0;

      const platformConfigs: Record<string, { maxLength: number; hashtags: string[]; template: string }> = {
        x: {
          maxLength: 280,
          hashtags: ["#buildinpublic", "#FlutterWeb", "#Supabase", "#AI"],
          template: `🚀 自分株式会社 — 21のSaaS競合を超えるAI統合プラットフォーム\n\n現在${totalUsers}人が利用中！\n✅ AI秘書が24時間サポート\n✅ 12部署のAI仮想組織\n✅ 228以上の機能を無料で\n\nhttps://my-web-app-b67f4.web.app/`,
        },
        line: {
          maxLength: 500,
          hashtags: [],
          template: `自分株式会社を使ってみませんか？\nNotion・Slack・MoneyForwardの機能が1つのアプリに統合されています。\n無料で使えます！\nhttps://my-web-app-b67f4.web.app/`,
        },
        email: {
          maxLength: 2000,
          hashtags: [],
          template: `こんにちは！\n\n「自分株式会社」というAI統合ライフマネジメントアプリをご紹介します。\n\nNotion・Evernote・MoneyForward・Slack・Xなど21のSaaSの機能を1つのアプリに統合。\nAI秘書が24時間あなたをサポートし、12部署20エージェントのAI仮想組織が開発を推進しています。\n\n現在${totalUsers}人のユーザーが利用中です。無料でお試しいただけます。\n\nhttps://my-web-app-b67f4.web.app/`,
        },
      };

      const config = platformConfigs[platform] ?? platformConfigs["x"];

      return new Response(
        JSON.stringify({
          platform,
          shareText: config.template,
          hashtags: config.hashtags,
          url: "https://my-web-app-b67f4.web.app/",
          charCount: config.template.length,
          maxLength: config.maxLength,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // action=testimonial_prompts — Generate prompts to collect testimonials
    if (action === "testimonial_prompts") {
      const prompts = [
        "自分株式会社で一番気に入っている機能は何ですか？",
        "自分株式会社を使う前と後で、何が変わりましたか？",
        "友人に自分株式会社を勧めるとしたら、何と言いますか？",
        "自分株式会社のAI秘書を使ってみて、どんな体験でしたか？",
        "他のアプリ（Notion, Slack等）と比べて、自分株式会社の良い点は？",
      ];

      return new Response(
        JSON.stringify({ prompts }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Unknown action",
        validActions: ["generate", "share_card", "testimonial_prompts"],
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
