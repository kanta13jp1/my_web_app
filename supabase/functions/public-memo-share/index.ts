import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const APP_BASE_URL = "https://my-web-app-b67f4.web.app";
const FUNCTION_BASE_URL =
  "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1";
const EXCERPT_LENGTH = 220;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const requestUrl = new URL(req.url);
    const memoId = Number.parseInt(requestUrl.searchParams.get("id") ?? "", 10);

    if (!Number.isFinite(memoId) || memoId <= 0) {
      return htmlResponse(buildFallbackHtml());
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      return htmlResponse(buildFallbackHtml());
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data, error } = await admin
      .from("public_memos")
      .select("id, title, content, category")
      .eq("id", memoId)
      .eq("is_public", true)
      .maybeSingle();

    if (error || !data) {
      return htmlResponse(buildFallbackHtml());
    }

    const title = data["title"]?.toString().trim() || "Public memo";
    const category = data["category"]?.toString().trim() || "Public memo";
    const rawContent = data["content"]?.toString() ?? "";
    const excerpt = buildExcerpt(rawContent);
    const appUrl = buildAppUrl(memoId);
    const shareUrl = `${FUNCTION_BASE_URL}/public-memo-share?id=${memoId}`;
    const ogImageUrl = `${FUNCTION_BASE_URL}/get-public-memo-ogp?id=${memoId}`;

    return htmlResponse(
      `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0;url=${escapeHtmlAttribute(appUrl)}">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <title>${escapeHtml(title)} | Public memo</title>
  <meta name="description" content="${escapeHtmlAttribute(excerpt)}">
  <link rel="canonical" href="${escapeHtmlAttribute(appUrl)}">

  <meta property="og:type" content="article">
  <meta property="og:title" content="${escapeHtmlAttribute(title)}">
  <meta property="og:description" content="${escapeHtmlAttribute(excerpt)}">
  <meta property="og:url" content="${escapeHtmlAttribute(shareUrl)}">
  <meta property="og:image" content="${escapeHtmlAttribute(ogImageUrl)}">
  <meta property="og:image:alt" content="${escapeHtmlAttribute(title)}">
  <meta property="og:site_name" content="Jibun Inc.">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtmlAttribute(title)}">
  <meta name="twitter:description" content="${escapeHtmlAttribute(excerpt)}">
  <meta name="twitter:image" content="${escapeHtmlAttribute(ogImageUrl)}">
  <meta name="twitter:image:alt" content="${escapeHtmlAttribute(title)}">

  <style>
    body { margin: 0; font-family: "Noto Sans JP", system-ui, sans-serif; background: linear-gradient(135deg, #0f172a, #1d4ed8); color: #e2e8f0; }
    main { max-width: 760px; margin: 0 auto; padding: 56px 24px; }
    .card { background: rgba(15, 23, 42, 0.78); border: 1px solid rgba(148, 163, 184, 0.24); border-radius: 24px; padding: 28px; box-shadow: 0 24px 72px rgba(15, 23, 42, 0.26); }
    .eyebrow { color: #93c5fd; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; margin-bottom: 12px; }
    h1 { margin: 0 0 16px; font-size: 34px; line-height: 1.25; color: #f8fafc; }
    p { margin: 0 0 18px; font-size: 16px; line-height: 1.8; }
    a { color: #bfdbfe; }
  </style>
</head>
<body>
  <main>
    <div class="card">
      <div class="eyebrow">${escapeHtml(category)}</div>
      <h1>${escapeHtml(title)}</h1>
      <p>${escapeHtml(excerpt)}</p>
      <p>If you are not redirected automatically, open <a href="${escapeHtmlAttribute(appUrl)}">the public memo</a>.</p>
    </div>
  </main>
  <script>window.location.replace(${JSON.stringify(appUrl)});</script>
</body>
</html>`,
    );
  } catch {
    return htmlResponse(buildFallbackHtml());
  }
});

function buildAppUrl(memoId: number): string {
  return `${APP_BASE_URL}/public-memo?id=${memoId}&utm_source=public_memo&utm_medium=share&utm_campaign=growth_mission`;
}

function buildExcerpt(content: string): string {
  const plainText = content
    .replace(/#{1,6}\s+/g, "")
    .replace(/\*{1,2}(.+?)\*{1,2}/g, "$1")
    .replace(/`{1,3}[^`]*`{1,3}/g, "")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/\n+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (plainText.length <= EXCERPT_LENGTH) {
    return plainText || "Read the latest public memo on Jibun Inc.";
  }
  return `${plainText.slice(0, EXCERPT_LENGTH - 3)}...`;
}

function buildFallbackHtml(): string {
  const target = `${APP_BASE_URL}/public-memos`;
  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0;url=${escapeHtmlAttribute(target)}">
  <meta name="robots" content="noindex, nofollow">
  <title>Public memo | Jibun Inc.</title>
  <meta name="description" content="Open the public memo directory on Jibun Inc.">
  <script>window.location.replace(${JSON.stringify(target)});</script>
</head>
<body></body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeHtmlAttribute(value: string): string {
  return escapeHtml(value);
}

function htmlResponse(html: string): Response {
  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}
