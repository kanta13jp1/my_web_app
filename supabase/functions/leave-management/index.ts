// Leave Management Edge Function
// 休暇管理 (ジョブカン競合)
// - 有給/病欠/特別休暇の申請
// - 承認ワークフロー
// - 残日数管理
// - カレンダー統合
//
// GET  → 休暇一覧 / 残日数 / チーム状況
// POST → 申請 / 承認 / 却下

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

const LEAVE_TYPES = [
  { key: "paid", label: "有給休暇", default_days: 20 },
  { key: "sick", label: "病気休暇", default_days: 10 },
  { key: "special", label: "特別休暇", default_days: 5 },
  { key: "maternity", label: "育児休暇", default_days: 90 },
  { key: "bereavement", label: "忌引休暇", default_days: 5 },
  { key: "unpaid", label: "無給休暇", default_days: 0 },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'balance' | 'history' | 'pending' | 'types'

      if (view === "types") {
        return new Response(
          JSON.stringify({ success: true, types: LEAVE_TYPES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const year = parseInt(url.searchParams.get("year") ?? String(new Date().getFullYear()));

      if (view === "balance") {
        const { data: leaves } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "leave_request")
          .eq("metadata->>status", "approved");

        const usedByType = new Map<string, number>();
        for (const l of leaves ?? []) {
          const meta = l.metadata as Record<string, unknown>;
          const type = (meta?.leave_type as string) ?? "paid";
          const days = (meta?.days as number) ?? 1;
          const reqYear = new Date((meta?.start_date as string) ?? "").getFullYear();
          if (reqYear === year) {
            usedByType.set(type, (usedByType.get(type) ?? 0) + days);
          }
        }

        const balance = LEAVE_TYPES.map((lt) => ({
          type: lt.key,
          label: lt.label,
          total: lt.default_days,
          used: usedByType.get(lt.key) ?? 0,
          remaining: lt.default_days - (usedByType.get(lt.key) ?? 0),
        }));

        return new Response(
          JSON.stringify({ success: true, year, balance }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "pending") {
        const { data: pending } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at, user_id")
          .eq("source", "leave_request")
          .eq("metadata->>status", "pending")
          .order("created_at", { ascending: false });

        return new Response(
          JSON.stringify({
            success: true,
            pending: (pending ?? []).map((p) => ({
              ...(p.metadata as Record<string, unknown>),
              userId: p.user_id,
              requestedAt: p.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Default: history
      const { data: history } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "leave_request")
        .order("created_at", { ascending: false })
        .limit(50);

      return new Response(
        JSON.stringify({
          success: true,
          leaves: (history ?? []).map((h) => ({
            ...(h.metadata as Record<string, unknown>),
            requestedAt: h.created_at,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "request") {
        const { leave_type, start_date, end_date, reason } = body;
        if (!leave_type || !start_date) {
          return new Response(
            JSON.stringify({ success: false, error: "leave_type and start_date required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const end = end_date ?? start_date;
        const start = new Date(start_date);
        const endD = new Date(end);
        const days = Math.max(1, Math.round((endD.getTime() - start.getTime()) / 86400000) + 1);

        const requestId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "leave_request",
          metadata: {
            request_id: requestId,
            leave_type,
            start_date,
            end_date: end,
            days,
            reason: reason ?? "",
            status: "pending",
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, requestId, leave: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "approve" || action === "reject") {
        const { request_id } = body;
        if (!request_id) {
          return new Response(
            JSON.stringify({ success: false, error: "request_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data: existing } = await adminClient
          .from("app_analytics")
          .select("metadata, user_id")
          .eq("source", "leave_request")
          .eq("metadata->>request_id", request_id)
          .maybeSingle();

        if (!existing) {
          return new Response(
            JSON.stringify({ success: false, error: "Request not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const newStatus = action === "approve" ? "approved" : "rejected";
        const { error } = await adminClient
          .from("app_analytics")
          .update({
            metadata: {
              ...(existing.metadata as Record<string, unknown>),
              status: newStatus,
              reviewed_by: user.id,
              reviewed_at: new Date().toISOString(),
            },
          })
          .eq("source", "leave_request")
          .eq("metadata->>request_id", request_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, status: newStatus }),
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
    console.error("leave-management error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
