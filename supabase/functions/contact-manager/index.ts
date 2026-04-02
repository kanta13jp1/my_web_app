// Contact Manager Edge Function
// 連絡先管理 (Google Contacts/Microsoft競合)
// - 連絡先 CRUD
// - グループ分け
// - 検索・フィルタ
// - インタラクション履歴
//
// GET  → 連絡先一覧 / グループ / 検索 / 履歴
// POST → 追加 / 更新 / グループ作成 / インタラクション記録

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
      const view = url.searchParams.get("view"); // 'groups' | 'search' | 'interactions'
      const group = url.searchParams.get("group");
      const query = url.searchParams.get("q");
      const contactId = url.searchParams.get("contact_id");

      if (view === "interactions" && contactId) {
        const { data: interactions } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "contact_interaction")
          .eq("metadata->>contact_id", contactId)
          .order("created_at", { ascending: false })
          .limit(20);

        return new Response(
          JSON.stringify({
            success: true,
            interactions: (interactions ?? []).map((i) => ({
              ...(i.metadata as Record<string, unknown>),
              recordedAt: i.created_at,
            })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "groups") {
        const { data: contacts } = await adminClient
          .from("app_analytics")
          .select("metadata")
          .eq("user_id", user.id)
          .eq("source", "contact");

        const groups = new Map<string, number>();
        for (const c of contacts ?? []) {
          const meta = c.metadata as Record<string, unknown>;
          const g = (meta?.group as string) ?? "未分類";
          groups.set(g, (groups.get(g) ?? 0) + 1);
        }

        return new Response(
          JSON.stringify({
            success: true,
            groups: [...groups.entries()].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Contact list
      const { data: contacts } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "contact")
        .order("created_at", { ascending: false })
        .limit(100);

      let contactList = (contacts ?? []).map((c) => ({
        ...(c.metadata as Record<string, unknown>),
        addedAt: c.created_at,
      }));

      if (group) {
        contactList = contactList.filter((c) => (c.group as string ?? "未分類") === group);
      }

      if (query) {
        const q = query.toLowerCase();
        contactList = contactList.filter((c) => {
          const name = ((c.name as string) ?? "").toLowerCase();
          const email = ((c.email as string) ?? "").toLowerCase();
          const company = ((c.company as string) ?? "").toLowerCase();
          return name.includes(q) || email.includes(q) || company.includes(q);
        });
      }

      return new Response(
        JSON.stringify({ success: true, contacts: contactList, total: contactList.length }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "add") {
        const { name, email, phone, company, group: groupName, notes } = body;
        if (!name) {
          return new Response(
            JSON.stringify({ success: false, error: "name required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const contactIdNew = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "contact",
          metadata: {
            contact_id: contactIdNew,
            name,
            email: email ?? "",
            phone: phone ?? "",
            company: company ?? "",
            group: groupName ?? "未分類",
            notes: notes ?? "",
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, contactId: contactIdNew, contact: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "record_interaction") {
        const { contact_id, type, notes } = body;
        if (!contact_id || !type) {
          return new Response(
            JSON.stringify({ success: false, error: "contact_id and type required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const validTypes = ["meeting", "call", "email", "message", "other"];
        if (!validTypes.includes(type)) {
          return new Response(
            JSON.stringify({ success: false, error: `type must be one of: ${validTypes.join(", ")}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "contact_interaction",
          metadata: {
            contact_id,
            type,
            notes: notes ?? "",
          },
          created_at: new Date().toISOString(),
        });

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, recorded: true }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
    console.error("contact-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
