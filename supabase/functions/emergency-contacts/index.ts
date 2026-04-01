// Emergency Contacts & Safety Edge Function
// 緊急連絡先・安否確認管理
// - 緊急連絡先登録
// - 医療情報管理
// - 安否確認送信・回答
// - 位置情報共有
// - 緊急時マニュアル

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const BLOOD_TYPES = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "unknown"];
const SAFETY_STATUSES = ["safe", "need_help", "injured", "unreachable", "unknown"];

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
      if (view === "options") return new Response(JSON.stringify({ success: true, bloodTypes: BLOOD_TYPES, safetyStatuses: SAFETY_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (view === "medical") {
        const { data: medical } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "medical_info").maybeSingle();
        return new Response(JSON.stringify({ success: true, medicalInfo: medical ? (medical.metadata as Record<string, unknown>) : null }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "safety_checks") {
        const { data: checks } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "safety_check").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, checks: (checks ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (view === "stats") {
        const { data: contacts } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "emergency_contact");
        const { data: checks } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "safety_check");
        return new Response(JSON.stringify({ success: true, stats: { totalContacts: (contacts ?? []).length, totalChecks: (checks ?? []).length } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: contacts } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "emergency_contact").order("created_at", { ascending: true });
      return new Response(JSON.stringify({ success: true, contacts: (contacts ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;
      if (action === "add_contact") {
        const { name, phone, email, relationship, is_primary } = body;
        if (!name || !phone) return new Response(JSON.stringify({ success: false, error: "name and phone required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const contactId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "emergency_contact", metadata: { contact_id: contactId, name, phone, email: email ?? null, relationship: relationship ?? null, is_primary: is_primary ?? false }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, contactId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "save_medical") {
        const { blood_type, allergies, medications, conditions, insurance_number, doctor_name, doctor_phone } = body;
        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "medical_info").maybeSingle();
        const data = { blood_type: blood_type ?? "unknown", allergies: allergies ?? [], medications: medications ?? [], conditions: conditions ?? [], insurance_number: insurance_number ?? null, doctor_name: doctor_name ?? null, doctor_phone: doctor_phone ?? null };
        if (existing) {
          await adminClient.from("app_analytics").update({ metadata: data }).eq("user_id", user.id).eq("source", "medical_info");
        } else {
          await adminClient.from("app_analytics").insert({ user_id: user.id, source: "medical_info", metadata: data, created_at: new Date().toISOString() });
        }
        return new Response(JSON.stringify({ success: true, saved: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      if (action === "send_safety_check") {
        const { event_name, message } = body;
        if (!event_name) return new Response(JSON.stringify({ success: false, error: "event_name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const checkId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({ user_id: user.id, source: "safety_check", metadata: { check_id: checkId, event_name, message: message ?? null, my_status: "safe", sent_at: new Date().toISOString(), responses: [] }, created_at: new Date().toISOString() });
        return new Response(JSON.stringify({ success: true, checkId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
