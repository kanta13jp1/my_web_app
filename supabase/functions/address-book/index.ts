// Address Book Edge Function
// アドレス帳 (Google Contacts/Microsoft Outlook競合)
// - 連絡先管理
// - グループ分け
// - ラベル
// - インポート/エクスポート (vCard)
// - 重複検出

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CONTACT_LABELS = ["family", "friend", "work", "school", "vip", "other"];
const PHONE_TYPES = ["mobile", "home", "work", "fax", "other"];
const EMAIL_TYPES = ["personal", "work", "other"];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");
      const label = url.searchParams.get("label");
      const group = url.searchParams.get("group");
      const q = url.searchParams.get("q");

      if (view === "labels") return new Response(JSON.stringify({ success: true, labels: CONTACT_LABELS, phoneTypes: PHONE_TYPES, emailTypes: EMAIL_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "groups") {
        const { data: groups } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "contact_group").order("created_at", { ascending: true });
        return new Response(JSON.stringify({ success: true, groups: (groups ?? []).map((g) => ({ ...(g.metadata as Record<string, unknown>), createdAt: g.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "duplicates") {
        const { data: contacts } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "address_contact");
        const nameMap = new Map<string, Array<Record<string, unknown>>>();
        for (const c of contacts ?? []) {
          const m = c.metadata as Record<string, unknown>;
          const name = ((m.name as string) ?? "").toLowerCase().trim();
          if (name) {
            if (!nameMap.has(name)) nameMap.set(name, []);
            nameMap.get(name)!.push(m);
          }
        }
        const duplicates = [...nameMap.entries()].filter(([, list]) => list.length > 1).map(([name, list]) => ({ name, count: list.length, contacts: list }));
        return new Response(JSON.stringify({ success: true, duplicates, totalDuplicateGroups: duplicates.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "export") {
        const { data: contacts } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "address_contact");
        let vcard = "";
        for (const c of contacts ?? []) {
          const m = c.metadata as Record<string, unknown>;
          vcard += "BEGIN:VCARD\nVERSION:3.0\n";
          vcard += `FN:${m.name ?? ""}\n`;
          if (m.email) vcard += `EMAIL:${m.email}\n`;
          if (m.phone) vcard += `TEL:${m.phone}\n`;
          if (m.organization) vcard += `ORG:${m.organization}\n`;
          if (m.title) vcard += `TITLE:${m.title}\n`;
          if (m.address) vcard += `ADR:;;${m.address};;;;\n`;
          if (m.notes) vcard += `NOTE:${m.notes}\n`;
          vcard += "END:VCARD\n\n";
        }
        return new Response(vcard, { headers: { ...corsHeaders, "Content-Type": "text/vcard", "Content-Disposition": "attachment; filename=contacts.vcf" } });
      }

      if (view === "stats") {
        const { data: contacts } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "address_contact");
        const labelCount: Record<string, number> = {};
        for (const c of contacts ?? []) {
          const l = ((c.metadata as Record<string, unknown>).label as string) ?? "other";
          labelCount[l] = (labelCount[l] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true, stats: { totalContacts: (contacts ?? []).length, labelBreakdown: labelCount },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: list contacts
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "address_contact")
        .order("metadata->>name", { ascending: true });
      if (label) query = query.eq("metadata->>label", label);
      if (group) query = query.eq("metadata->>group_id", group);
      const { data: contacts } = await query;
      let results = (contacts ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at }));
      if (q) results = results.filter((c) => JSON.stringify(c).toLowerCase().includes(q.toLowerCase()));
      return new Response(JSON.stringify({ success: true, contacts: results, total: results.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "add_contact") {
        const { name, email, phone, phone_type, organization, title: jobTitle, address, label: contactLabel, notes, birthday, group_id } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const contactId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "address_contact",
          metadata: {
            contact_id: contactId, name, email: email ?? "", phone: phone ?? "",
            phone_type: phone_type ?? "mobile", organization: organization ?? "",
            title: jobTitle ?? "", address: address ?? "",
            label: contactLabel ?? "other", notes: notes ?? "",
            birthday: birthday ?? null, group_id: group_id ?? null,
            is_favorite: false,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, contactId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_group") {
        const { name, description } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const groupId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "contact_group",
          metadata: { group_id: groupId, name, description: description ?? "", member_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, groupId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "toggle_favorite") {
        const { contact_id } = body;
        if (!contact_id) return new Response(JSON.stringify({ success: false, error: "contact_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "address_contact").eq("metadata->>contact_id", contact_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Contact not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = existing.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, is_favorite: !meta.is_favorite },
        }).eq("user_id", user.id).eq("source", "address_contact").eq("metadata->>contact_id", contact_id);
        return new Response(JSON.stringify({ success: true, isFavorite: !meta.is_favorite }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete_contact") {
        const { contact_id } = body;
        if (!contact_id) return new Response(JSON.stringify({ success: false, error: "contact_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "address_contact").eq("metadata->>contact_id", contact_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
