// File Storage Manager Edge Function
// ファイルストレージ管理 — アップロード・ダウンロード・共有
// - ファイルメタデータ管理 (Supabase Storage)
// - フォルダ構造
// - ファイル共有URL生成
// - ストレージ使用量追跡
//
// GET  → ファイル一覧 / 使用量 / 共有URL
// POST → アップロード記録 / フォルダ作成 / 共有設定

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
      const view = url.searchParams.get("view"); // 'files' | 'usage' | 'shared' | 'folders'

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

      if (view === "usage") {
        const { data: files } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "file_upload");

        let totalSize = 0;
        let fileCount = 0;
        for (const f of files ?? []) {
          const meta = f.metadata as Record<string, unknown>;
          totalSize += (meta?.size as number) ?? 0;
          fileCount++;
        }

        const { data: profile } = await adminClient
          .from("user_profiles")
          .select("subscription_plan")
          .eq("user_id", user.id)
          .maybeSingle();

        const plan = (profile?.subscription_plan as string) ?? "free";
        const limits: Record<string, number> = { free: 100, pro: 1000, premium: 10000 };
        const limitMb = limits[plan] ?? 100;

        return new Response(
          JSON.stringify({
            success: true,
            usage: {
              totalBytes: totalSize,
              totalMb: Math.round(totalSize / 1048576 * 100) / 100,
              fileCount,
              limitMb,
              usagePercent: Math.round((totalSize / 1048576 / limitMb) * 100),
            },
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "shared") {
        const { data: shared } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "file_share")
          .order("created_at", { ascending: false })
          .limit(20);

        return new Response(
          JSON.stringify({
            success: true,
            shared: (shared ?? []).map((s) => ({
              ...(s.metadata as Record<string, unknown>),
              sharedAt: s.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // デフォルト: ファイル一覧
      const folder = url.searchParams.get("folder") ?? "/";
      const { data: files } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "file_upload")
        .order("created_at", { ascending: false })
        .limit(50);

      const fileList = (files ?? [])
        .filter((f) => {
          const meta = f.metadata as Record<string, unknown>;
          return (meta?.folder as string ?? "/") === folder;
        })
        .map((f) => ({
          ...(f.metadata as Record<string, unknown>),
          uploadedAt: f.created_at,
        }));

      return new Response(
        JSON.stringify({ success: true, files: fileList, folder }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

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

      if (action === "record_upload") {
        const { filename, size, mime_type, folder } = body;
        if (!filename) {
          return new Response(
            JSON.stringify({ success: false, error: "filename required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "file_upload",
          metadata: {
            filename,
            size: size ?? 0,
            mime_type: mime_type ?? "application/octet-stream",
            folder: folder ?? "/",
            file_id: crypto.randomUUID(),
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, file: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "share") {
        const { file_id, expires_hours } = body;
        if (!file_id) {
          return new Response(
            JSON.stringify({ success: false, error: "file_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const shareToken = crypto.randomUUID();
        const expiresAt = new Date(Date.now() + (expires_hours ?? 24) * 3600000).toISOString();

        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "file_share",
          metadata: { file_id, shareToken, expiresAt },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, shareToken, expiresAt }),
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
    console.error("file-storage-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
