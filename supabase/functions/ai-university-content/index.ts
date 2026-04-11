// ai-university-content — AI大学コンテンツ配信・更新EF
//
// AI大学のキラーコンテンツ (Google/OpenAI/Anthropic/Microsoft/Meta/X/DeepSeek ほか)
// をDB駆動で配信する。プロバイダー数は固定せず随時追加可能。
//
// GET  ?action=get_all                           → 全プロバイダーのアクティブコンテンツ一覧
// GET  ?action=get_by_provider&provider=google   → 指定プロバイダーのコンテンツ一覧
// POST { action: "get_all" }                     → 同上 (POST版)
// POST { action: "get_by_provider", provider }   → 同上 (POST版)
// POST { action: "upsert_news", provider, title, content, source_url?, published_at? }
//      → Claude Schedule (ai-university-update) がニュースカテゴリを更新
//      ※ Authorization: Bearer <SERVICE_ROLE_KEY> 必須
//
// テーブル: ai_university_content
//   (provider, category, title, content, source_url, published_at, sort_order, is_active)
//
// RLS: SELECT は is_active=true の全行を全ユーザーに公開 / INSERT/UPDATE は service_role のみ

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const VALID_CATEGORIES = new Set([
  "overview",
  "models",
  "api",
  "pricing",
  "news",
  "tutorial",
]);

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

function isServiceRoleAuthorized(req: Request): boolean {
  if (SERVICE_ROLE_KEY === "") return false;
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  return token !== "" && token === SERVICE_ROLE_KEY;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
    return jsonResponse(
      { success: false, error: "ai-university-content: misconfigured" },
      500,
    );
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── Parse action + params from GET or POST ────────────────────────────────
  let action = "";
  let params: Record<string, unknown> = {};

  if (req.method === "GET") {
    const url = new URL(req.url);
    action = url.searchParams.get("action") ?? "get_all";
    params = {
      provider: url.searchParams.get("provider") ?? undefined,
      category: url.searchParams.get("category") ?? undefined,
      limit: url.searchParams.get("limit") ?? undefined,
    };
  } else if (req.method === "POST") {
    try {
      params = await req.json();
    } catch {
      params = {};
    }
    action = asString(params.action) || "get_all";
  } else {
    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  }

  try {
    // ── action: get_all ────────────────────────────────────────────────────
    if (action === "get_all") {
      const limit = Math.max(1, Math.min(500, asNumber(params.limit, 200)));
      const { data, error } = await admin
        .from("ai_university_content")
        .select(
          "id, provider, category, title, content, source_url, published_at, sort_order, updated_at",
        )
        .eq("is_active", true)
        .order("provider", { ascending: true })
        .order("sort_order", { ascending: true })
        .order("updated_at", { ascending: false })
        .limit(limit);

      if (error) throw error;

      // プロバイダー別にグルーピング (Flutter クライアントで使いやすい形)
      const byProvider: Record<string, unknown[]> = {};
      for (const row of data ?? []) {
        const key = asString(
          (row as Record<string, unknown>).provider,
        );
        if (key === "") continue;
        (byProvider[key] ??= []).push(row);
      }

      return jsonResponse({
        success: true,
        items: data ?? [],
        byProvider,
        count: (data ?? []).length,
      });
    }

    // ── action: get_by_provider ────────────────────────────────────────────
    if (action === "get_by_provider") {
      const provider = asString(params.provider);
      if (provider === "") {
        return jsonResponse(
          { success: false, error: "provider is required" },
          400,
        );
      }

      const category = asString(params.category);
      const limit = Math.max(1, Math.min(200, asNumber(params.limit, 50)));

      let query = admin
        .from("ai_university_content")
        .select(
          "id, provider, category, title, content, source_url, published_at, sort_order, updated_at",
        )
        .eq("is_active", true)
        .eq("provider", provider)
        .order("sort_order", { ascending: true })
        .order("updated_at", { ascending: false })
        .limit(limit);

      if (category !== "") {
        query = query.eq("category", category);
      }

      const { data, error } = await query;
      if (error) throw error;

      return jsonResponse({
        success: true,
        provider,
        items: data ?? [],
        count: (data ?? []).length,
      });
    }

    // ── action: upsert_news (service-role only) ────────────────────────────
    if (action === "upsert_news") {
      if (!isServiceRoleAuthorized(req)) {
        return jsonResponse(
          { success: false, error: "unauthorized: service role required" },
          401,
        );
      }

      const provider = asString(params.provider);
      const title = asString(params.title);
      const content = asString(params.content);
      const categoryInput = asString(params.category);
      const category = categoryInput === "" ? "news" : categoryInput;

      if (provider === "" || title === "" || content === "") {
        return jsonResponse(
          {
            success: false,
            error: "provider, title, content are required",
          },
          400,
        );
      }

      if (!VALID_CATEGORIES.has(category)) {
        return jsonResponse(
          {
            success: false,
            error:
              `invalid category: ${category}. valid: ${[...VALID_CATEGORIES].join(",")}`,
          },
          400,
        );
      }

      const sourceUrl = asString(params.source_url);
      const publishedAtInput = asString(params.published_at);
      const publishedAt = /^\d{4}-\d{2}-\d{2}$/.test(publishedAtInput)
        ? publishedAtInput
        : new Date().toISOString().slice(0, 10);
      const sortOrder = asNumber(params.sort_order, 1);

      // 既存の (provider, category, title) レコードを探して UPSERT
      // 同一タイトルは更新、新規はインサート
      const { data: existing, error: selectErr } = await admin
        .from("ai_university_content")
        .select("id")
        .eq("provider", provider)
        .eq("category", category)
        .eq("title", title)
        .maybeSingle();

      if (selectErr) throw selectErr;

      if (existing && typeof existing === "object" && "id" in existing) {
        const { data: updated, error: updateErr } = await admin
          .from("ai_university_content")
          .update({
            content,
            source_url: sourceUrl === "" ? null : sourceUrl,
            published_at: publishedAt,
            sort_order: sortOrder,
            is_active: true,
            updated_at: new Date().toISOString(),
          })
          .eq("id", (existing as { id: string }).id)
          .select()
          .single();
        if (updateErr) throw updateErr;
        return jsonResponse({ success: true, mode: "update", item: updated });
      }

      const { data: inserted, error: insertErr } = await admin
        .from("ai_university_content")
        .insert({
          provider,
          category,
          title,
          content,
          source_url: sourceUrl === "" ? null : sourceUrl,
          published_at: publishedAt,
          sort_order: sortOrder,
          is_active: true,
        })
        .select()
        .single();
      if (insertErr) throw insertErr;

      return jsonResponse({ success: true, mode: "insert", item: inserted });
    }

    return jsonResponse(
      { success: false, error: `Unknown action: ${action}` },
      400,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("ai-university-content error:", err);
    return jsonResponse({ success: false, error: message }, 500);
  }
});
