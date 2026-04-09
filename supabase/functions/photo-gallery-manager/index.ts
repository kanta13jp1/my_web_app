// Photo Gallery Manager Edge Function
// 写真ギャラリー管理 (Google Photos/Facebook/LINE競合)
// - アルバム作成・管理
// - 写真メタデータ (EXIF/タグ/場所)
// - 共有アルバム
// - AI自動タグ付け
// - フォトタイムライン
//
// GET  → アルバム一覧 / 写真一覧 / タイムライン / 共有 / 統計
// POST → アルバム作成 / 写真追加 / タグ付け / 共有設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const AUTO_TAGS = ["風景", "人物", "食べ物", "動物", "建物", "花", "海", "山", "夜景", "スポーツ"];

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

      if (view === "albums") {
        const { data: albums } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "photo_album")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          albums: (albums ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "photos") {
        const albumId = url.searchParams.get("album_id");
        let query = adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "photo_item")
          .order("created_at", { ascending: false });
        if (albumId) query = query.eq("metadata->>album_id", albumId);
        const { data: photos } = await query.limit(100);
        return new Response(JSON.stringify({
          success: true,
          photos: (photos ?? []).map((p) => ({ ...(p.metadata as Record<string, unknown>), createdAt: p.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "timeline") {
        const year = url.searchParams.get("year") ?? new Date().getFullYear().toString();
        const { data: photos } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "photo_item")
          .gte("created_at", `${year}-01-01`).lte("created_at", `${year}-12-31`)
          .order("created_at", { ascending: false });
        // Group by month
        const timeline: Record<string, number> = {};
        for (let m = 1; m <= 12; m++) timeline[`${year}-${String(m).padStart(2, "0")}`] = 0;
        for (const p of photos ?? []) {
          const month = p.created_at?.substring(0, 7);
          if (month && timeline[month] !== undefined) timeline[month]++;
        }
        return new Response(JSON.stringify({ success: true, year, timeline, totalPhotos: (photos ?? []).length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "shared") {
        const { data: shared } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "photo_album").eq("metadata->>is_shared", "true")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          sharedAlbums: (shared ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        // アルバムと写真を並列取得
        const [{ data: albums }, { data: photos }] = await Promise.all([
          adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "photo_album"),
          adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "photo_item"),
        ]);
        const tagCounts: Record<string, number> = {};
        for (const p of photos ?? []) {
          const tags = ((p.metadata as Record<string, unknown>).tags as string[]) ?? [];
          for (const t of tags) tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { totalAlbums: (albums ?? []).length, totalPhotos: (photos ?? []).length, tagCounts },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, views: ["albums", "photos", "timeline", "shared", "stats"] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_album") {
        const { title, description, cover_url, is_shared } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const albumId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "photo_album",
          metadata: { album_id: albumId, title, description: description ?? null, cover_url: cover_url ?? null, is_shared: is_shared ?? false, photo_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, albumId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_photo") {
        const { album_id, url, filename, tags, location, taken_at } = body;
        if (!url) {
          return new Response(JSON.stringify({ success: false, error: "url required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const photoId = crypto.randomUUID();
        // AI auto-tagging simulation
        const autoTags = tags ?? [AUTO_TAGS[Math.floor(Math.random() * AUTO_TAGS.length)]];
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "photo_item",
          metadata: { photo_id: photoId, album_id: album_id ?? null, url, filename: filename ?? null, tags: autoTags, location: location ?? null, taken_at: taken_at ?? new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, photoId, tags: autoTags }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "tag_photo") {
        const { photo_id, tags } = body;
        if (!photo_id || !tags) {
          return new Response(JSON.stringify({ success: false, error: "photo_id and tags required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "photo_item").eq("metadata->>photo_id", photo_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Photo not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const currentTags = (meta.tags as string[]) ?? [];
        const merged = [...new Set([...currentTags, ...tags])];
        await adminClient.from("app_analytics").update({ metadata: { ...meta, tags: merged } })
          .eq("user_id", user.id).eq("source", "photo_item").eq("metadata->>photo_id", photo_id);
        return new Response(JSON.stringify({ success: true, tags: merged }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "share_album") {
        const { album_id, is_shared } = body;
        if (!album_id) {
          return new Response(JSON.stringify({ success: false, error: "album_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "photo_album").eq("metadata->>album_id", album_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Album not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        await adminClient.from("app_analytics").update({ metadata: { ...(existing.metadata as Record<string, unknown>), is_shared: is_shared ?? true } })
          .eq("user_id", user.id).eq("source", "photo_album").eq("metadata->>album_id", album_id);
        return new Response(JSON.stringify({ success: true, shared: is_shared ?? true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
