// QR Code Generator & Manager Edge Function
// QRコード生成・管理 (LINE/Amazon競合)
// - QRコード生成 (URL/テキスト/連絡先/WiFi)
// - スキャン履歴
// - 動的QR (リダイレクト先変更可能)
// - アクセス解析
// - バッチ生成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const QR_TYPES = ["url", "text", "contact", "wifi", "email", "phone", "sms", "location"];

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
      const qrId = url.searchParams.get("qr_id");

      if (view === "types") {
        return new Response(JSON.stringify({ success: true, qrTypes: QR_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "detail" && qrId) {
        const { data: qr } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "qr_code").eq("metadata->>qr_id", qrId).maybeSingle();
        if (!qr) return new Response(JSON.stringify({ success: false, error: "QR code not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Get scan history
        const { data: scans } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "qr_scan").eq("metadata->>qr_id", qrId)
          .order("created_at", { ascending: false }).limit(100);
        return new Response(JSON.stringify({
          success: true,
          qr: { ...(qr.metadata as Record<string, unknown>), createdAt: qr.created_at },
          scans: (scans ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })),
          totalScans: (scans ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "scan_history") {
        const { data: scans } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "qr_scan")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, scans: (scans ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analytics" && qrId) {
        const { data: scans } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "qr_scan").eq("metadata->>qr_id", qrId);
        // Daily scan counts
        const dailyMap = new Map<string, number>();
        for (const s of scans ?? []) {
          const date = (s.created_at as string)?.slice(0, 10) ?? "unknown";
          dailyMap.set(date, (dailyMap.get(date) ?? 0) + 1);
        }
        const dailyScans = [...dailyMap.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([date, count]) => ({ date, count }));
        // Device breakdown
        const deviceMap = new Map<string, number>();
        for (const s of scans ?? []) {
          const device = ((s.metadata as Record<string, unknown>).device as string) ?? "unknown";
          deviceMap.set(device, (deviceMap.get(device) ?? 0) + 1);
        }
        return new Response(JSON.stringify({
          success: true, analytics: {
            totalScans: (scans ?? []).length, dailyScans,
            deviceBreakdown: [...deviceMap.entries()].map(([device, count]) => ({ device, count })),
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: qrs } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "qr_code");
        const { data: scans } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "qr_scan");
        const typeCount: Record<string, number> = {};
        for (const q of qrs ?? []) {
          const t = ((q.metadata as Record<string, unknown>).type as string) ?? "url";
          typeCount[t] = (typeCount[t] ?? 0) + 1;
        }
        const dynamicCount = (qrs ?? []).filter((q) => (q.metadata as Record<string, unknown>).is_dynamic).length;
        return new Response(JSON.stringify({
          success: true, stats: {
            totalQRCodes: (qrs ?? []).length, totalScans: (scans ?? []).length,
            dynamicCount, typeBreakdown: typeCount,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's QR codes
      const { data: qrs } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "qr_code")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({ success: true, qrCodes: (qrs ?? []).map((q) => ({ ...(q.metadata as Record<string, unknown>), createdAt: q.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create") {
        const { type, content, label, is_dynamic, foreground_color, background_color } = body;
        if (!content) return new Response(JSON.stringify({ success: false, error: "content required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const qrId = crypto.randomUUID();
        const shortCode = qrId.substring(0, 8).toUpperCase();

        // Format content based on type
        let encodedContent = content;
        if (type === "wifi") {
          const { ssid, password, encryption } = body;
          encodedContent = `WIFI:T:${encryption ?? "WPA"};S:${ssid ?? content};P:${password ?? ""};;`;
        } else if (type === "contact") {
          const { name, phone, email: contactEmail } = body;
          encodedContent = `BEGIN:VCARD\nVERSION:3.0\nFN:${name ?? content}\nTEL:${phone ?? ""}\nEMAIL:${contactEmail ?? ""}\nEND:VCARD`;
        }

        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "qr_code",
          metadata: {
            qr_id: qrId, type: type ?? "url", content: encodedContent,
            label: label ?? "", short_code: shortCode,
            is_dynamic: is_dynamic ?? false, scan_count: 0,
            foreground_color: foreground_color ?? "#000000",
            background_color: background_color ?? "#FFFFFF",
            redirect_url: is_dynamic ? content : null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, qrId, shortCode, content: encodedContent }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_scan") {
        const { qr_id, device, location } = body;
        if (!qr_id) return new Response(JSON.stringify({ success: false, error: "qr_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "qr_scan",
          metadata: { qr_id, device: device ?? "unknown", location: location ?? null, scanned_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "update_redirect") {
        const { qr_id, new_url } = body;
        if (!qr_id || !new_url) return new Response(JSON.stringify({ success: false, error: "qr_id and new_url required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "qr_code").eq("metadata->>qr_id", qr_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "QR code not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = existing.metadata as Record<string, unknown>;
        if (!meta.is_dynamic) return new Response(JSON.stringify({ success: false, error: "QR code is not dynamic" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, redirect_url: new_url },
        }).eq("user_id", user.id).eq("source", "qr_code").eq("metadata->>qr_id", qr_id);
        return new Response(JSON.stringify({ success: true, newUrl: new_url }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "batch_create") {
        const { items } = body; // [{type, content, label}]
        if (!items || !Array.isArray(items) || items.length === 0) return new Response(JSON.stringify({ success: false, error: "items array required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const results = [];
        for (const item of items.slice(0, 50)) { // Max 50
          const qrId = crypto.randomUUID();
          const shortCode = qrId.substring(0, 8).toUpperCase();
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "qr_code",
            metadata: {
              qr_id: qrId, type: item.type ?? "url", content: item.content,
              label: item.label ?? "", short_code: shortCode,
              is_dynamic: false, scan_count: 0,
              foreground_color: "#000000", background_color: "#FFFFFF",
            },
            created_at: new Date().toISOString(),
          });
          results.push({ qrId, shortCode, content: item.content });
        }
        return new Response(JSON.stringify({ success: true, created: results.length, results }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
