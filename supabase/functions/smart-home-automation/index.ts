// Smart Home Automation Edge Function
// スマートホームオートメーション (Google Home/Amazon Alexa/Apple HomeKit競合)
// - デバイス管理
// - ルーティン設定
// - シーン管理
// - エネルギーモニタリング
// - 自動化ルール

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const DEVICE_TYPES = ["light", "thermostat", "lock", "camera", "speaker", "sensor", "switch", "curtain", "robot_vacuum", "air_purifier"];
const DEVICE_STATUSES = ["online", "offline", "error", "updating"];
const TRIGGER_TYPES = ["time", "device_state", "location", "weather", "manual"];
const SCENE_PRESETS = [
  { id: "morning", name: "おはよう", actions: [{ device_type: "light", action: "on", value: 80 }, { device_type: "curtain", action: "open" }] },
  { id: "away", name: "外出", actions: [{ device_type: "light", action: "off" }, { device_type: "lock", action: "lock" }, { device_type: "thermostat", action: "set", value: 20 }] },
  { id: "night", name: "おやすみ", actions: [{ device_type: "light", action: "off" }, { device_type: "lock", action: "lock" }, { device_type: "curtain", action: "close" }] },
  { id: "movie", name: "映画", actions: [{ device_type: "light", action: "dim", value: 10 }, { device_type: "curtain", action: "close" }, { device_type: "speaker", action: "on" }] },
];

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

      if (view === "config") return new Response(JSON.stringify({ success: true, deviceTypes: DEVICE_TYPES, deviceStatuses: DEVICE_STATUSES, triggerTypes: TRIGGER_TYPES, scenePresets: SCENE_PRESETS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "devices") {
        const { data: devices } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "smart_device").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, devices: (devices ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "scenes") {
        const { data: scenes } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "smart_scene").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, scenes: (scenes ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })), presets: SCENE_PRESETS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "automations") {
        const { data: rules } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "smart_automation").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, automations: (rules ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "energy") {
        const { data: logs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "energy_log").order("created_at", { ascending: false }).limit(30);
        let totalKwh = 0;
        const deviceUsage: Record<string, number> = {};
        for (const l of logs ?? []) {
          const m = l.metadata as Record<string, unknown>;
          const kwh = (m.kwh as number) ?? 0;
          totalKwh += kwh;
          const device = (m.device_name as string) ?? "unknown";
          deviceUsage[device] = (deviceUsage[device] ?? 0) + kwh;
        }
        return new Response(JSON.stringify({ success: true, energy: { totalKwh: Math.round(totalKwh * 100) / 100, estimatedCost: Math.round(totalKwh * 27), deviceUsage, logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, deviceTypes: DEVICE_TYPES, scenePresets: SCENE_PRESETS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "add_device") {
        const { name, device_type, room, model } = body;
        if (!name || !device_type) return new Response(JSON.stringify({ success: false, error: "name and device_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const deviceId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "smart_device",
          metadata: { device_id: deviceId, name, device_type, room: room ?? "リビング", model: model ?? "", status: "online", state: {}, last_seen: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, deviceId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "control_device") {
        const { device_id, command, value } = body;
        if (!device_id || !command) return new Response(JSON.stringify({ success: false, error: "device_id and command required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: device } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "smart_device").eq("metadata->>device_id", device_id).maybeSingle();
        if (!device) return new Response(JSON.stringify({ success: false, error: "Device not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const m = device.metadata as Record<string, unknown>;
        const state = { ...(m.state as Record<string, unknown> ?? {}), [command]: value ?? true, last_command: command, last_command_at: new Date().toISOString() };
        await adminClient.from("app_analytics").update({ metadata: { ...m, state, last_seen: new Date().toISOString() } })
          .eq("user_id", user.id).eq("source", "smart_device").eq("metadata->>device_id", device_id);
        return new Response(JSON.stringify({ success: true, command, value, state }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_scene") {
        const { name, actions, preset_id } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const preset = preset_id ? SCENE_PRESETS.find((p) => p.id === preset_id) : null;
        const sceneId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "smart_scene",
          metadata: { scene_id: sceneId, name, actions: actions ?? preset?.actions ?? [], preset_id: preset_id ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, sceneId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_automation") {
        const { name, trigger_type, trigger_config, scene_id, actions } = body;
        if (!name || !trigger_type) return new Response(JSON.stringify({ success: false, error: "name and trigger_type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const automationId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "smart_automation",
          metadata: { automation_id: automationId, name, trigger_type, trigger_config: trigger_config ?? {}, scene_id: scene_id ?? null, actions: actions ?? [], enabled: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, automationId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_energy") {
        const { device_id, device_name, kwh } = body;
        if (!device_id || kwh === undefined) return new Response(JSON.stringify({ success: false, error: "device_id and kwh required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "energy_log",
          metadata: { device_id, device_name: device_name ?? "unknown", kwh, logged_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
