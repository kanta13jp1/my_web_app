// get-public-memo-preview
// Public endpoint (no auth required) that returns SEO metadata for a public memo.
// Used by the index.html SEO shell to set page-specific meta tags before Flutter loads.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const EXCERPT_LENGTH = 120;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const idParam = url.searchParams.get("id");
    const memoId = idParam ? parseInt(idParam, 10) : NaN;

    if (isNaN(memoId) || memoId <= 0) {
      return jsonResponse({ success: false, error: "Invalid memo id." }, 400);
    }

    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      return jsonResponse(
        { success: false, error: "Missing runtime env." },
        500,
      );
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

    if (error) throw error;
    if (!data) {
      return jsonResponse({ success: false, error: "Memo not found." }, 404);
    }

    const title = data["title"]?.toString() ?? "";
    const rawContent = data["content"]?.toString() ?? "";
    const category = data["category"]?.toString() ?? "";

    // Strip Markdown syntax for excerpt
    const plainText = rawContent
      .replace(/#{1,6}\s+/g, "")
      .replace(/\*{1,2}(.+?)\*{1,2}/g, "$1")
      .replace(/`{1,3}[^`]*`{1,3}/g, "")
      .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
      .replace(/\n+/g, " ")
      .trim();

    const excerpt = plainText.length > EXCERPT_LENGTH
      ? plainText.slice(0, EXCERPT_LENGTH) + "…"
      : plainText;

    return jsonResponse({
      success: true,
      id: memoId,
      title,
      excerpt,
      category,
      pageTitle: `${title} - 自分株式会社`,
      ogDescription: excerpt ||
        `自分株式会社の公開メモ: ${title}`,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return jsonResponse({ success: false, error: msg }, 500);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
