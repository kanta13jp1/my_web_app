// Family Sharing Manager Edge Function
// ファミリー共有管理 (Apple Family/Google Family競合)
// - ファミリーグループ管理
// - 共有カレンダー・ToDo
// - 支出共有
// - 位置情報共有
// - ファミリー統計
//
// GET  → グループ一覧 / メンバー / 共有カレンダー / 共有支出 / 統計
// POST → グループ作成 / メンバー追加 / イベント共有 / 支出記録

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const MEMBER_ROLES = ["owner", "admin", "member", "child"];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const groupId = url.searchParams.get("group_id");

      if (view === "roles") {
        return new Response(JSON.stringify({ success: true, roles: MEMBER_ROLES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "members" && groupId) {
        const { data: members } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "family_member").eq("metadata->>group_id", groupId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          members: (members ?? []).map((m) => ({ ...(m.metadata as Record<string, unknown>), joinedAt: m.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "shared_calendar" && groupId) {
        const { data: events } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "family_event").eq("metadata->>group_id", groupId)
          .order("metadata->>date", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          events: (events ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "shared_expenses" && groupId) {
        const { data: expenses } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "family_expense").eq("metadata->>group_id", groupId)
          .order("created_at", { ascending: false }).limit(50);
        let totalSpent = 0;
        const byMember: Record<string, number> = {};
        for (const e of expenses ?? []) {
          const meta = e.metadata as Record<string, unknown>;
          const amount = (meta.amount as number) ?? 0;
          totalSpent += amount;
          const payer = (meta.paid_by as string) ?? "unknown";
          byMember[payer] = (byMember[payer] ?? 0) + amount;
        }
        return new Response(JSON.stringify({
          success: true, totalSpent, byMember,
          expenses: (expenses ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats" && groupId) {
        const { data: members } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "family_member").eq("metadata->>group_id", groupId);
        const { data: events } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "family_event").eq("metadata->>group_id", groupId);
        const { data: expenses } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "family_expense").eq("metadata->>group_id", groupId);
        let totalSpent = 0;
        for (const e of expenses ?? []) totalSpent += ((e.metadata as Record<string, unknown>).amount as number) ?? 0;
        return new Response(JSON.stringify({
          success: true,
          stats: { memberCount: (members ?? []).length, eventCount: (events ?? []).length, expenseCount: (expenses ?? []).length, totalSpent },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: group list
      const { data: groups } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "family_group")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        groups: (groups ?? []).map((g) => ({ ...(g.metadata as Record<string, unknown>), createdAt: g.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_group") {
        const { name, description } = body;
        if (!name) {
          return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const groupId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "family_group",
          metadata: { group_id: groupId, name, description: description ?? null, owner_id: user.id },
          created_at: new Date().toISOString(),
        });
        // Add owner as member
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "family_member",
          metadata: { group_id: groupId, user_id: user.id, display_name: user.email, role: "owner" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, groupId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_member") {
        const { group_id, display_name, email, role } = body;
        if (!group_id || !display_name) {
          return new Response(JSON.stringify({ success: false, error: "group_id and display_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const memberId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "family_member",
          metadata: { group_id, member_id: memberId, display_name, email: email ?? null, role: role ?? "member" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, memberId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_event") {
        const { group_id, title, date, description: desc, all_day } = body;
        if (!group_id || !title || !date) {
          return new Response(JSON.stringify({ success: false, error: "group_id, title, date required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const eventId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "family_event",
          metadata: { group_id, event_id: eventId, title, date, description: desc ?? null, all_day: all_day ?? true, created_by: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, eventId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_expense") {
        const { group_id, title, amount, category, paid_by, split_with } = body;
        if (!group_id || !title || !amount) {
          return new Response(JSON.stringify({ success: false, error: "group_id, title, amount required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const expenseId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "family_expense",
          metadata: { group_id, expense_id: expenseId, title, amount, category: category ?? "other", paid_by: paid_by ?? user.email, split_with: split_with ?? [] },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, expenseId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
