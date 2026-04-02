// Feature Request Manager Edge Function
// 機能リクエストの完全 CRUD + 投票 + ステータス管理
// ユーザーが機能リクエストを投稿・投票し、開発の優先度を決める
//
// GET  → リクエスト一覧 (投票数順/最新順/ステータス別)
// POST → リクエスト作成 / 投票 / ステータス更新

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
    if (req.method === "GET") {
      const url = new URL(req.url);
      const sort = url.searchParams.get("sort") ?? "votes"; // 'votes' | 'newest' | 'oldest'
      const status = url.searchParams.get("status"); // 'open' | 'planned' | 'in_progress' | 'completed' | 'rejected'
      const limit = parseInt(url.searchParams.get("limit") ?? "50", 10);
      const view = url.searchParams.get("view"); // 'summary' | null

      const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
      });

      if (view === "summary") {
        // ステータス別集計
        const { data, error } = await adminClient
          .from("feature_requests")
          .select("status");

        if (error) throw error;

        const counts: Record<string, number> = {};
        for (const r of data ?? []) {
          const s = (r.status as string) ?? "unknown";
          counts[s] = (counts[s] ?? 0) + 1;
        }

        return new Response(
          JSON.stringify({
            success: true,
            summary: counts,
            total: (data ?? []).length,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // リクエスト一覧
      const orderField = sort === "newest" ? "created_at" : sort === "oldest" ? "created_at" : "votes";
      const ascending = sort === "oldest";

      let query = adminClient
        .from("feature_requests")
        .select("*")
        .order(orderField, { ascending })
        .limit(limit);

      if (status) query = query.eq("status", status);

      const { data, error } = await query;
      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, requests: data ?? [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create") {
        // 新規リクエスト作成 (認証必須)
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

        const { title, description, category } = body;
        if (!title) {
          return new Response(
            JSON.stringify({ success: false, error: "title is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { data, error } = await adminClient
          .from("feature_requests")
          .insert({
            title,
            description: description ?? "",
            category: category ?? "general",
            status: "open",
            votes: 1,
            user_id: user.id,
            created_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, request: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "vote") {
        // 投票 (認証必須)
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
          return new Response(
            JSON.stringify({ success: false, error: "Authorization required" }),
            { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { request_id } = body;
        if (!request_id) {
          return new Response(
            JSON.stringify({ success: false, error: "request_id is required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        // 現在の投票数を取得してインクリメント
        const { data: current } = await adminClient
          .from("feature_requests")
          .select("votes")
          .eq("id", request_id)
          .single();

        if (!current) {
          return new Response(
            JSON.stringify({ success: false, error: "Request not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient
          .from("feature_requests")
          .update({ votes: (current.votes ?? 0) + 1 })
          .eq("id", request_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, request: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "update_status") {
        // ステータス更新 (管理者)
        const { request_id, status: newStatus } = body;

        if (!request_id || !newStatus) {
          return new Response(
            JSON.stringify({ success: false, error: "request_id and status are required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { data, error } = await adminClient
          .from("feature_requests")
          .update({ status: newStatus })
          .eq("id", request_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, request: data }),
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
    console.error("feature-request-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
