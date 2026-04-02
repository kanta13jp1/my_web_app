// Screen Recording & Screenshot Manager Edge Function
// 画面録画・スクリーンショット管理 (Discord/Zoom/Loom競合)
// - 録画メタデータ保存
// - スクリーンショット管理
// - アノテーション
// - 共有リンク
// - ストレージ統計

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const RECORDING_TYPES = ["screen", "camera", "screen_camera", "audio_only"];
const MEDIA_STATUSES = ["recording", "processing", "ready", "archived", "deleted"];
const ANNOTATION_TYPES = ["arrow", "rectangle", "circle", "text", "highlight", "blur"];

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
      const recordingId = url.searchParams.get("recording_id");

      if (view === "types") {
        return new Response(JSON.stringify({ success: true, recordingTypes: RECORDING_TYPES, statuses: MEDIA_STATUSES, annotationTypes: ANNOTATION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "detail" && recordingId) {
        const { data: recording } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "screen_recording").eq("metadata->>recording_id", recordingId).maybeSingle();
        if (!recording) return new Response(JSON.stringify({ success: false, error: "Recording not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: annotations } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "recording_annotation").eq("metadata->>recording_id", recordingId);
        return new Response(JSON.stringify({
          success: true,
          recording: { ...(recording.metadata as Record<string, unknown>), createdAt: recording.created_at },
          annotations: (annotations ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "screenshots") {
        const { data: screenshots } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "screenshot")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, screenshots: (screenshots ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: recordings } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "screen_recording");
        const { data: screenshots } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "screenshot");
        let totalDuration = 0;
        let totalSize = 0;
        for (const r of recordings ?? []) {
          const m = r.metadata as Record<string, unknown>;
          totalDuration += ((m.duration_seconds as number) ?? 0);
          totalSize += ((m.file_size_mb as number) ?? 0);
        }
        for (const s of screenshots ?? []) {
          totalSize += (((s.metadata as Record<string, unknown>).file_size_mb as number) ?? 0);
        }
        const sharedCount = (recordings ?? []).filter((r) => (r.metadata as Record<string, unknown>).is_shared).length;
        return new Response(JSON.stringify({
          success: true, stats: {
            totalRecordings: (recordings ?? []).length,
            totalScreenshots: (screenshots ?? []).length,
            totalDurationMinutes: Math.round(totalDuration / 60),
            totalSizeMB: Math.round(totalSize * 10) / 10,
            sharedCount,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: all recordings
      const { data: recordings } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "screen_recording")
        .order("created_at", { ascending: false }).limit(30);
      return new Response(JSON.stringify({ success: true, recordings: (recordings ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "save_recording") {
        const { title, type, duration_seconds, file_size_mb, resolution, file_url } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const recordingId = crypto.randomUUID();
        const shareCode = crypto.randomUUID().substring(0, 8).toUpperCase();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "screen_recording",
          metadata: {
            recording_id: recordingId, title, type: type ?? "screen",
            duration_seconds: duration_seconds ?? 0, file_size_mb: file_size_mb ?? 0,
            resolution: resolution ?? "1920x1080", file_url: file_url ?? null,
            status: "ready", is_shared: false, share_code: shareCode,
            view_count: 0, transcript: null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recordingId, shareCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "save_screenshot") {
        const { title, file_size_mb, resolution, file_url } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const screenshotId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "screenshot",
          metadata: {
            screenshot_id: screenshotId, title, file_size_mb: file_size_mb ?? 0,
            resolution: resolution ?? "1920x1080", file_url: file_url ?? null,
            is_shared: false,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, screenshotId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_annotation") {
        const { recording_id, type: annType, timestamp_seconds, data: annData } = body;
        if (!recording_id || !annType) return new Response(JSON.stringify({ success: false, error: "recording_id and type required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const annotationId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "recording_annotation",
          metadata: {
            annotation_id: annotationId, recording_id,
            type: annType, timestamp_seconds: timestamp_seconds ?? 0,
            data: annData ?? {},
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, annotationId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "toggle_share") {
        const { recording_id } = body;
        if (!recording_id) return new Response(JSON.stringify({ success: false, error: "recording_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "screen_recording").eq("metadata->>recording_id", recording_id).maybeSingle();
        if (!existing) return new Response(JSON.stringify({ success: false, error: "Recording not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = existing.metadata as Record<string, unknown>;
        const newShared = !meta.is_shared;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, is_shared: newShared },
        }).eq("user_id", user.id).eq("source", "screen_recording").eq("metadata->>recording_id", recording_id);
        return new Response(JSON.stringify({ success: true, is_shared: newShared }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
