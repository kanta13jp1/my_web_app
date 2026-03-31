// Content Moderation Edge Function
// ユーザー生成コンテンツの安全性チェック
// - 禁止ワード検出
// - スパム判定
// - 不適切コンテンツフラグ
// - モデレーションログ
//
// GET  → モデレーションログ / ルール一覧 / 統計
// POST → コンテンツチェック / ルール更新 / フラグ操作

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// 基本禁止パターン
const DEFAULT_RULES = [
  { key: "spam_links", pattern: "http[s]?://[^ ]*\\.(ru|cn|tk|ml|ga|cf)/", label: "スパムリンク", severity: "high" },
  { key: "excessive_caps", pattern: "[A-Z]{20,}", label: "過度な大文字", severity: "low" },
  { key: "repeated_chars", pattern: "(.)\\1{9,}", label: "文字の過度な繰り返し", severity: "low" },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'rules' | 'logs' | 'stats'

      if (view === "rules") {
        return new Response(
          JSON.stringify({ success: true, rules: DEFAULT_RULES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "logs") {
        const { data: logs } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .eq("source", "content_moderation")
          .order("created_at", { ascending: false })
          .limit(50);

        return new Response(
          JSON.stringify({
            success: true,
            logs: (logs ?? []).map((l) => ({
              ...(l.metadata as Record<string, unknown>),
              userId: l.user_id,
              checkedAt: l.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: 統計
      const { data: allLogs } = await adminClient
        .from("app_analytics")
        .select("metadata")
        .eq("source", "content_moderation");

      let flagged = 0, clean = 0;
      for (const l of allLogs ?? []) {
        if ((l.metadata as Record<string, unknown>)?.flagged) flagged++;
        else clean++;
      }

      return new Response(
        JSON.stringify({
          success: true,
          stats: { totalChecks: flagged + clean, flagged, clean, flagRate: (flagged + clean) > 0 ? Math.round((flagged / (flagged + clean)) * 100) : 0 },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "check") {
        const { content, content_type } = body;
        if (!content) {
          return new Response(
            JSON.stringify({ success: false, error: "content is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // ルールチェック
        const violations: Array<{ rule: string; label: string; severity: string }> = [];
        for (const rule of DEFAULT_RULES) {
          try {
            const regex = new RegExp(rule.pattern, "gi");
            if (regex.test(content)) {
              violations.push({ rule: rule.key, label: rule.label, severity: rule.severity });
            }
          } catch {
            // 無効な正規表現はスキップ
          }
        }

        const flagged = violations.some((v) => v.severity === "high");

        // ログ記録
        await adminClient.from("app_analytics").insert({
          source: "content_moderation",
          metadata: {
            content_type: content_type ?? "text",
            contentLength: content.length,
            flagged,
            violations,
            checkedAt: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, flagged, violations, safe: !flagged }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("content-moderation error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
