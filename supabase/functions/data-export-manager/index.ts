// Data Export Manager Edge Function
// ユーザーデータのエクスポート・データポータビリティ (GDPR対応)
// - ノート / プロフィール / アクティビティ / 設定の一括エクスポート
// - JSON / CSV 形式対応
// - エクスポート履歴管理
//
// GET  → エクスポート履歴 / ステータス確認
// POST → エクスポートリクエスト作成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

// エクスポート対象テーブル
const EXPORT_TABLES = [
  { key: "profile", table: "user_profiles", userField: "user_id", label: "プロフィール" },
  { key: "notes", table: "notes", userField: "user_id", label: "ノート" },
  { key: "feature_requests", table: "feature_requests", userField: "user_id", label: "機能リクエスト" },
  { key: "notifications", table: "app_notifications", userField: "user_id", label: "通知" },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 認証必須
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'history' | 'available'

      if (view === "available") {
        // エクスポート可能なデータ一覧 + 件数
        const counts: Array<{ key: string; label: string; count: number }> = [];

        for (const t of EXPORT_TABLES) {
          const { count } = await adminClient
            .from(t.table)
            .select("*", { count: "exact", head: true })
            .eq(t.userField, user.id);
          counts.push({ key: t.key, label: t.label, count: count ?? 0 });
        }

        return new Response(
          JSON.stringify({ success: true, available: counts }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: エクスポート履歴
      const { data: history } = await adminClient
        .from("app_analytics")
        .select("created_at, metadata")
        .eq("user_id", user.id)
        .eq("source", "data_export")
        .order("created_at", { ascending: false })
        .limit(20);

      return new Response(
        JSON.stringify({
          success: true,
          history: (history ?? []).map((h) => ({
            date: h.created_at,
            ...(h.metadata as Record<string, unknown> ?? {}),
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { format, tables } = body;
      const exportFormat = format ?? "json";

      if (!["json", "csv"].includes(exportFormat)) {
        return new Response(
          JSON.stringify({ success: false, error: "format must be json or csv" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // エクスポート対象テーブルを決定
      const targetTables = tables && Array.isArray(tables)
        ? EXPORT_TABLES.filter((t) => tables.includes(t.key))
        : [...EXPORT_TABLES];

      if (targetTables.length === 0) {
        return new Response(
          JSON.stringify({ success: false, error: "No valid tables specified" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // データ収集
      const exportData: Record<string, unknown[]> = {};
      let totalRecords = 0;

      for (const t of targetTables) {
        const { data } = await adminClient
          .from(t.table)
          .select("*")
          .eq(t.userField, user.id)
          .order("created_at", { ascending: false });
        exportData[t.key] = data ?? [];
        totalRecords += (data ?? []).length;
      }

      // エクスポート記録を app_analytics に保存
      await adminClient
        .from("app_analytics")
        .insert({
          user_id: user.id,
          source: "data_export",
          metadata: {
            format: exportFormat,
            tables: targetTables.map((t) => t.key),
            totalRecords,
            exportedAt: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });

      if (exportFormat === "csv") {
        // CSV 形式: テーブルごとにセクション分け
        const csvParts: string[] = [];

        for (const [key, rows] of Object.entries(exportData)) {
          if (rows.length === 0) continue;
          csvParts.push(`# ${key}`);
          const headers = Object.keys(rows[0] as Record<string, unknown>);
          csvParts.push(headers.join(","));
          for (const row of rows) {
            const r = row as Record<string, unknown>;
            csvParts.push(headers.map((h) => {
              const val = r[h];
              if (val === null || val === undefined) return "";
              const str = typeof val === "object" ? JSON.stringify(val) : String(val);
              return str.includes(",") || str.includes('"') || str.includes("\n")
                ? `"${str.replace(/"/g, '""')}"` : str;
            }).join(","));
          }
          csvParts.push("");
        }

        return new Response(
          csvParts.join("\n"),
          {
            status: 200,
            headers: {
              ...corsHeaders,
              "Content-Type": "text/csv; charset=utf-8",
              "Content-Disposition": `attachment; filename="export-${new Date().toISOString().slice(0, 10)}.csv"`,
            },
          },
        );
      }

      // JSON 形式
      return new Response(
        JSON.stringify({
          success: true,
          export: {
            format: "json",
            exportedAt: new Date().toISOString(),
            userId: user.id,
            totalRecords,
            data: exportData,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("data-export-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
