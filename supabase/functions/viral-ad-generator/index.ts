// viral-ad-generator — Generates viral ad content for 自分株式会社
//
// GET  → テンプレート一覧
// POST → { "template": "growth_stats"|"feature_highlight"|"vs_notion"|...,
//           "stats": { users, functions, pages }, "format": "svg"|"html" }
//      → { "svg": "...", "html": "...", "tweetText": "...", "hashtags": [...] }
//
// Dark War スタイルの「数字で魅せる」広告カードをコードで生成。
// SVG は X に直接アップロード可 (PNG変換はフロント側 canvas.toBlob 等で実施)。
// 外部有料APIは不要。

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// ---------------------------------------------------------------------------
// Ad templates
// ---------------------------------------------------------------------------

type AdStats = {
  users?: number;
  functions?: number;
  pages?: number;
  dailyActive?: number;
  competitors?: number;
};

type AdTemplate =
  | "growth_stats"
  | "feature_highlight"
  | "vs_notion"
  | "dark_war"
  | "milestone"
  | "ai_secretary";

function buildGrowthStatsSvg(stats: AdStats): string {
  const users = stats.users ?? 4;
  const functions = stats.functions ?? 223;
  const pages = stats.pages ?? 130;
  const nextMilestone = users < 10 ? 10 : users < 100 ? 100 : Math.ceil(users / 100) * 100;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0f0c29"/>
      <stop offset="50%" style="stop-color:#302b63"/>
      <stop offset="100%" style="stop-color:#24243e"/>
    </linearGradient>
    <linearGradient id="accent" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#6366f1"/>
      <stop offset="100%" style="stop-color:#a855f7"/>
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
      <feMerge><feMergeNode in="coloredBlur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="1200" height="630" fill="url(#bg)"/>

  <!-- Grid lines (subtle) -->
  <line x1="0" y1="315" x2="1200" y2="315" stroke="#ffffff08" stroke-width="1"/>
  <line x1="600" y1="0" x2="600" y2="630" stroke="#ffffff08" stroke-width="1"/>

  <!-- Top accent bar -->
  <rect width="1200" height="6" fill="url(#accent)"/>

  <!-- Logo / Brand -->
  <text x="60" y="80" font-family="Arial,sans-serif" font-size="28" font-weight="bold"
        fill="#6366f1" filter="url(#glow)">自分株式会社</text>
  <text x="60" y="108" font-family="Arial,sans-serif" font-size="14" fill="#8b8fa8">
    AI統合ライフマネジメント | Notion × Slack × GitHub を1つに</text>

  <!-- Main headline -->
  <text x="600" y="190" font-family="Arial,sans-serif" font-size="52" font-weight="900"
        fill="white" text-anchor="middle">
    <tspan fill="url(#accent)">AIが自分の会社</tspan>を動かす</text>
  <text x="600" y="245" font-family="Arial,sans-serif" font-size="20" fill="#c4b5fd"
        text-anchor="middle">21の競合SaaS機能を1アプリに統合 — 完全無料</text>

  <!-- Stats row -->
  <g transform="translate(100, 310)">
    <!-- Users -->
    <rect x="0" y="0" width="280" height="120" rx="12" fill="#ffffff10" stroke="#6366f120" stroke-width="1"/>
    <text x="140" y="55" font-family="Arial,sans-serif" font-size="48" font-weight="900"
          fill="url(#accent)" text-anchor="middle">${users}</text>
    <text x="140" y="90" font-family="Arial,sans-serif" font-size="16" fill="#8b8fa8"
          text-anchor="middle">登録ユーザー</text>
    <text x="140" y="112" font-family="Arial,sans-serif" font-size="12" fill="#6366f1"
          text-anchor="middle">→ 目標: ${nextMilestone}人</text>

    <!-- Functions -->
    <rect x="320" y="0" width="280" height="120" rx="12" fill="#ffffff10" stroke="#6366f120" stroke-width="1"/>
    <text x="460" y="55" font-family="Arial,sans-serif" font-size="48" font-weight="900"
          fill="url(#accent)" text-anchor="middle">${functions}</text>
    <text x="460" y="90" font-family="Arial,sans-serif" font-size="16" fill="#8b8fa8"
          text-anchor="middle">Edge Functions</text>
    <text x="460" y="112" font-family="Arial,sans-serif" font-size="12" fill="#6366f1"
          text-anchor="middle">自動化バックエンド</text>

    <!-- Pages -->
    <rect x="640" y="0" width="280" height="120" rx="12" fill="#ffffff10" stroke="#6366f120" stroke-width="1"/>
    <text x="780" y="55" font-family="Arial,sans-serif" font-size="48" font-weight="900"
          fill="url(#accent)" text-anchor="middle">${pages}</text>
    <text x="780" y="90" font-family="Arial,sans-serif" font-size="16" fill="#8b8fa8"
          text-anchor="middle">実装ページ</text>
    <text x="780" y="112" font-family="Arial,sans-serif" font-size="12" fill="#6366f1"
          text-anchor="middle">全機能が今すぐ使える</text>
  </g>

  <!-- CTA -->
  <rect x="400" y="480" width="400" height="60" rx="30" fill="url(#accent)"/>
  <text x="600" y="519" font-family="Arial,sans-serif" font-size="22" font-weight="bold"
        fill="white" text-anchor="middle">今すぐ無料登録 →</text>

  <!-- URL -->
  <text x="600" y="590" font-family="Arial,sans-serif" font-size="16" fill="#6366f1"
        text-anchor="middle">my-web-app-b67f4.web.app</text>

  <!-- Bottom bar -->
  <rect y="624" width="1200" height="6" fill="url(#accent)"/>
</svg>`;
}

function buildDarkWarSvg(stats: AdStats): string {
  const users = stats.users ?? 4;
  const functions = stats.functions ?? 223;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="fire" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#ff0000"/>
      <stop offset="50%" style="stop-color:#ff6b00"/>
      <stop offset="100%" style="stop-color:#ffd700"/>
    </linearGradient>
    <filter id="flame">
      <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="4" seed="2"/>
      <feColorMatrix type="matrix" values="1 0 0 0 0  0 0.3 0 0 0  0 0 0 0 0  0 0 0 15 -6"/>
    </filter>
  </defs>

  <!-- Black background -->
  <rect width="1200" height="630" fill="#000000"/>

  <!-- Red/orange gradient overlay -->
  <rect width="1200" height="630" fill="url(#fire)" opacity="0.15"/>

  <!-- Warning stripes top -->
  <rect width="1200" height="8" fill="#ff4500"/>

  <!-- Main shock text -->
  <text x="600" y="160" font-family="Impact,Arial Black,sans-serif" font-size="96"
        font-weight="900" fill="#ff4500" text-anchor="middle"
        stroke="#ffd700" stroke-width="2">
    【衝撃】</text>
  <text x="600" y="245" font-family="Impact,Arial Black,sans-serif" font-size="52"
        fill="white" text-anchor="middle">AIが会社全体を</text>
  <text x="600" y="310" font-family="Impact,Arial Black,sans-serif" font-size="52"
        fill="url(#fire)" text-anchor="middle">1人で動かせる時代</text>

  <!-- Stats shock -->
  <text x="600" y="385" font-family="Arial,sans-serif" font-size="24" fill="#cccccc"
        text-anchor="middle">
    ${functions}機能 × AI自動化 × 21競合超え — 今すぐ無料体験</text>

  <!-- Current users as "growing army" -->
  <text x="600" y="440" font-family="Arial,sans-serif" font-size="18" fill="#ffd700"
        text-anchor="middle">現在 ${users}人が使用中 🔥 急成長中</text>

  <!-- URL button -->
  <rect x="350" y="470" width="500" height="70" rx="4" fill="#ff4500"/>
  <rect x="354" y="474" width="492" height="62" rx="2" fill="#000000"/>
  <text x="600" y="515" font-family="Impact,Arial Black,sans-serif" font-size="26"
        fill="#ffd700" text-anchor="middle">▶ my-web-app-b67f4.web.app</text>

  <!-- Bottom bar -->
  <rect y="622" width="1200" height="8" fill="#ff4500"/>
</svg>`;
}

function buildVsNotionSvg(stats: AdStats): string {
  const functions = stats.functions ?? 223;

  const features = [
    ["ノート・メモ", true, true],
    ["AI自動化", true, false],
    ["家計管理", true, false],
    ["競馬予想", true, false],
    ["仮想AI組織", true, false],
    ["完全無料", true, false],
  ];

  const rows = features.map(([name, us, them], i) => {
    const y = 290 + i * 52;
    return `
    <text x="600" y="${y}" font-family="Arial,sans-serif" font-size="18" fill="white"
          text-anchor="middle">${name}</text>
    <text x="270" y="${y}" font-family="Arial,sans-serif" font-size="22"
          fill="${us ? "#22c55e" : "#ef4444"}" text-anchor="middle">${us ? "✓" : "✗"}</text>
    <text x="930" y="${y}" font-family="Arial,sans-serif" font-size="22"
          fill="${them ? "#22c55e" : "#ef4444"}" text-anchor="middle">${them ? "✓" : "✗"}</text>`;
  }).join("");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0a0a1a"/>
      <stop offset="100%" style="stop-color:#1a0a2e"/>
    </linearGradient>
    <linearGradient id="accent2" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#6366f1"/>
      <stop offset="100%" style="stop-color:#22c55e"/>
    </linearGradient>
  </defs>

  <rect width="1200" height="630" fill="url(#bg2)"/>
  <rect width="1200" height="6" fill="url(#accent2)"/>

  <!-- Title -->
  <text x="600" y="80" font-family="Arial,sans-serif" font-size="36" font-weight="900"
        fill="white" text-anchor="middle">自分株式会社 vs Notion</text>
  <text x="600" y="115" font-family="Arial,sans-serif" font-size="18" fill="#8b8fa8"
        text-anchor="middle">${functions}機能を無料で提供 — Notion有料プランを超える機能数</text>

  <!-- Column headers -->
  <rect x="60" y="135" width="540" height="70" rx="8" fill="#6366f120" stroke="#6366f1" stroke-width="1"/>
  <text x="270" y="180" font-family="Arial,sans-serif" font-size="24" font-weight="bold"
        fill="#6366f1" text-anchor="middle">🚀 自分株式会社</text>

  <rect x="600" y="135" width="540" height="70" rx="8" fill="#ffffff10" stroke="#ffffff20" stroke-width="1"/>
  <text x="930" y="180" font-family="Arial,sans-serif" font-size="24" font-weight="bold"
        fill="#8b8fa8" text-anchor="middle">Notion (有料プラン)</text>

  <!-- Separator lines -->
  ${Array.from({ length: 6 }, (_, i) => `
  <line x1="60" y1="${267 + i * 52}" x2="1140" y2="${267 + i * 52}" stroke="#ffffff0a" stroke-width="1"/>`).join("")}

  <!-- Feature rows -->
  ${rows}

  <!-- CTA -->
  <rect x="350" y="620" width="500" height="0" rx="0"/>
  <text x="600" y="598" font-family="Arial,sans-serif" font-size="16" fill="#6366f1"
        text-anchor="middle">▶ my-web-app-b67f4.web.app — 今すぐ無料登録</text>

  <rect y="624" width="1200" height="6" fill="url(#accent2)"/>
</svg>`;
}

function buildAiSecretarySvg(stats: AdStats): string {
  const users = stats.users ?? 4;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg3" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0d1117"/>
      <stop offset="100%" style="stop-color:#161b22"/>
    </linearGradient>
    <linearGradient id="cyan" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" style="stop-color:#22d3ee"/>
      <stop offset="100%" style="stop-color:#818cf8"/>
    </linearGradient>
  </defs>

  <rect width="1200" height="630" fill="url(#bg3)"/>
  <rect width="1200" height="4" fill="url(#cyan)"/>

  <!-- Terminal-style header -->
  <rect x="40" y="40" width="300" height="32" rx="4" fill="#1e2a3a"/>
  <circle cx="62" cy="56" r="7" fill="#ef4444"/>
  <circle cx="85" cy="56" r="7" fill="#eab308"/>
  <circle cx="108" cy="56" r="7" fill="#22c55e"/>
  <text x="135" y="61" font-family="monospace" font-size="12" fill="#4b5563">jibun-kaisha.app — zsh</text>

  <!-- "Terminal output" -->
  <text x="60" y="120" font-family="monospace" font-size="14" fill="#22c55e">$ ./ai-secretary --mode=full-auto</text>
  <text x="60" y="150" font-family="monospace" font-size="14" fill="#818cf8">▶ 12部署 · 20エージェント 起動中...</text>
  <text x="60" y="178" font-family="monospace" font-size="14" fill="#22d3ee">✓ CS自動対応: 毎時実行</text>
  <text x="60" y="206" font-family="monospace" font-size="14" fill="#22d3ee">✓ 日次レポート: 自動生成 · X投稿</text>
  <text x="60" y="234" font-family="monospace" font-size="14" fill="#22d3ee">✓ コードレビュー: PR自動チェック</text>
  <text x="60" y="262" font-family="monospace" font-size="14" fill="#22d3ee">✓ 競合監視: 21社 毎日モニタリング</text>

  <!-- Big message -->
  <text x="600" y="350" font-family="Arial,sans-serif" font-size="48" font-weight="900"
        fill="white" text-anchor="middle">AIが24時間365日</text>
  <text x="600" y="408" font-family="Arial,sans-serif" font-size="48" font-weight="900"
        fill="url(#cyan)" text-anchor="middle">あなたの会社を動かす</text>

  <text x="600" y="460" font-family="Arial,sans-serif" font-size="20" fill="#6b7280"
        text-anchor="middle">既に${users}人が利用中 — Claude Code Schedule × Supabase × Flutter</text>

  <!-- CTA -->
  <rect x="380" y="490" width="440" height="58" rx="29" fill="url(#cyan)"/>
  <text x="600" y="528" font-family="Arial,sans-serif" font-size="20" font-weight="bold"
        fill="#0d1117" text-anchor="middle">無料で始める → web.app</text>

  <rect y="624" width="1200" height="6" fill="url(#cyan)"/>
</svg>`;
}

function getTweetText(template: AdTemplate, stats: AdStats): { text: string; hashtags: string[] } {
  const users = stats.users ?? 4;
  const functions = stats.functions ?? 223;

  const templates: Record<AdTemplate, { text: string; hashtags: string[] }> = {
    growth_stats: {
      text: `🚀 自分株式会社、${functions}機能・${users}人が使用中！\nNotion・Slack・GitHub・Amazonなど21競合SaaSを1アプリで超える挑戦🔥\n完全無料で体験 → https://my-web-app-b67f4.web.app/`,
      hashtags: ["buildinpublic", "FlutterWeb", "Supabase", "AI"],
    },
    dark_war: {
      text: `【衝撃】AIが会社全体を1人で動かせる時代が来た⚡\n${functions}機能のAI統合アプリを無料で体験 → https://my-web-app-b67f4.web.app/`,
      hashtags: ["ClaudeCode", "AI自動化", "buildinpublic"],
    },
    vs_notion: {
      text: `Notionより多機能・完全無料の代替アプリを作っています📝\nメモ×家計管理×AI秘書×競馬予想など${functions}機能を1アプリに！\n→ https://my-web-app-b67f4.web.app/ #buildinpublic`,
      hashtags: ["Notion代替", "FlutterWeb", "buildinpublic"],
    },
    ai_secretary: {
      text: `AIが24時間365日あなたの会社を動かす🤖\nCS自動対応・日次レポート・コードレビューをAIが全自動化\n自分株式会社 → https://my-web-app-b67f4.web.app/`,
      hashtags: ["AI秘書", "ClaudeCode", "Supabase", "buildinpublic"],
    },
    feature_highlight: {
      text: `自分株式会社の${functions}機能を今すぐ無料体験🎯\nNotionのメモ・Slackのチャット・MoneyForwardの家計管理が1アプリで！\n→ https://my-web-app-b67f4.web.app/`,
      hashtags: ["FlutterWeb", "SaaS", "buildinpublic"],
    },
    milestone: {
      text: `🎉 自分株式会社 ${users}人突破！\n次の目標: ${users < 10 ? 10 : Math.ceil(users / 10) * 10}人\n21競合SaaSの機能を1アプリで体験 → https://my-web-app-b67f4.web.app/`,
      hashtags: ["milestone", "buildinpublic", "FlutterWeb"],
    },
  };

  const result = templates[template] ?? templates.growth_stats;
  result.text = result.text.length > 280
    ? result.text.substring(0, 277) + "..."
    : result.text;
  return result;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const auth = req.headers.get("authorization") ?? "";
  if (SERVICE_ROLE_KEY === "" || auth !== `Bearer ${SERVICE_ROLE_KEY}`) {
    return jsonResp({ success: false, error: "Unauthorized" }, 401);
  }

  if (req.method === "GET") {
    return jsonResp({
      success: true,
      templates: [
        { id: "growth_stats", description: "成長統計カード (ユーザー数・機能数)" },
        { id: "dark_war", description: "Dark War スタイルのインパクト広告" },
        { id: "vs_notion", description: "Notion 比較カード" },
        { id: "ai_secretary", description: "AI秘書 ターミナル風カード" },
        { id: "feature_highlight", description: "機能ハイライト" },
        { id: "milestone", description: "マイルストーン達成祝い" },
      ],
    });
  }

  if (req.method !== "POST") {
    return jsonResp({ success: false, error: "GET or POST only" }, 405);
  }

  try {
    const body = await req.json().catch(() => ({})) as {
      template?: AdTemplate;
      stats?: AdStats;
      format?: "svg" | "html";
    };

    const template = body.template ?? "growth_stats";
    const stats = body.stats ?? {};
    const format = body.format ?? "svg";

    let svg: string;
    switch (template) {
      case "dark_war":
        svg = buildDarkWarSvg(stats);
        break;
      case "vs_notion":
        svg = buildVsNotionSvg(stats);
        break;
      case "ai_secretary":
        svg = buildAiSecretarySvg(stats);
        break;
      default:
        svg = buildGrowthStatsSvg(stats);
    }

    const { text, hashtags } = getTweetText(template, stats);
    const tweetText = `${text}\n${hashtags.map((h) => `#${h}`).join(" ")}`;

    const result: Record<string, unknown> = {
      success: true,
      template,
      tweetText: tweetText.length > 280 ? tweetText.substring(0, 277) + "..." : tweetText,
      hashtags,
      svg,
    };

    if (format === "html") {
      result.html = `<!DOCTYPE html><html><body style="margin:0;background:#000">
        <div style="width:1200px;height:630px">${svg}</div>
        </body></html>`;
    }

    return jsonResp(result);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return jsonResp({ success: false, error: msg }, 500);
  }
});

function jsonResp(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
