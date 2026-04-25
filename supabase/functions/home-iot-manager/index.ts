// Home IoT Manager Edge Function
// スマートホーム・IoT管理 (Google Home/Amazon Alexa競合)
// - デバイス登録・管理
// - センサーデータ記録
// - 自動化ルール (IFTTT風)
// - シーン管理
// - デバイス統計
//
// GET  → デバイス一覧 / センサーデータ / ルール / シーン / 統計
// POST → デバイス登録 / データ記録 / ルール作成 / シーン実行

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const DEVICE_TYPES = ["light", "thermostat", "camera", "lock", "speaker", "sensor", "plug", "switch", "curtain", "other"];

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
      const deviceId = url.searchParams.get("device_id");

      if (view === "device_types") {
        return new Response(JSON.stringify({ success: true, deviceTypes: DEVICE_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "sensor_data" && deviceId) {
        const hours = parseInt(url.searchParams.get("hours") ?? "24");
        const since = new Date(Date.now() - hours * 3600000).toISOString();
        const { data: readings } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "iot_reading").eq("metadata->>device_id", deviceId)
          .gte("created_at", since).order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          readings: (readings ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), recordedAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "rules") {
        const { data: rules } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "iot_rule")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          rules: (rules ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "scenes") {
        const { data: scenes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "iot_scene")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          scenes: (scenes ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: devices } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "iot_device");
        const online = (devices ?? []).filter((d) => (d.metadata as Record<string, unknown>).status === "online").length;
        const typeCounts: Record<string, number> = {};
        for (const d of devices ?? []) {
          const t = ((d.metadata as Record<string, unknown>).device_type as string) ?? "other";
          typeCounts[t] = (typeCounts[t] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalDevices: (devices ?? []).length, onlineDevices: online, typeCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: device list
      const { data: devices } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "iot_device")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        devices: (devices ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "register_device") {
        const { name, device_type, room, manufacturer, model } = body;
        if (!name || !device_type) {
          return new Response(JSON.stringify({ success: false, error: "name and device_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const deviceId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "iot_device",
          metadata: { device_id: deviceId, name, device_type, room: room ?? null, manufacturer: manufacturer ?? null, model: model ?? null, status: "online" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, deviceId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_reading") {
        const { device_id, metric, value, unit } = body;
        if (!device_id || !metric || value === undefined) {
          return new Response(JSON.stringify({ success: false, error: "device_id, metric, value required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "iot_reading",
          metadata: { device_id, metric, value, unit: unit ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recorded: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_rule") {
        const { name, trigger_device_id, trigger_condition, action_device_id, action_command, is_enabled } = body;
        if (!name || !trigger_device_id || !action_device_id) {
          return new Response(JSON.stringify({ success: false, error: "name, trigger_device_id, action_device_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const ruleId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "iot_rule",
          metadata: { rule_id: ruleId, name, trigger_device_id, trigger_condition: trigger_condition ?? null, action_device_id, action_command: action_command ?? null, is_enabled: is_enabled ?? true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, ruleId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_scene") {
        const { name, actions: sceneActions } = body;
        if (!name || !sceneActions) {
          return new Response(JSON.stringify({ success: false, error: "name and actions required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const sceneId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "iot_scene",
          metadata: { scene_id: sceneId, name, actions: sceneActions },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, sceneId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
