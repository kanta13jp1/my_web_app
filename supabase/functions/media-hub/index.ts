// media-hub — メディア・ドキュメント管理統合EF
// Merges (18 EFs): video-audio-manager, voice-memo-transcriber, screen-recorder,
//   live-streaming, video-meeting-manager, music-playlist-manager, photo-gallery-manager,
//   podcast-manager, ai-image-generator, viral-video-generator, viral-video-ad-generator,
//   ocr-document-scanner, virtual-whiteboard, whiteboard-canvas, document-collaboration,
//   document-esignature, meeting-manager, audio-effects-processor
//
// GET/POST ?action=<action> or body { action: "..." }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

async function listItems(admin: SupabaseClient, source: string, userId: string, limit = 50) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(admin: SupabaseClient, source: string, userId: string, meta: Record<string, unknown>) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(admin: SupabaseClient, source: string, userId: string, id: string) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ?? "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Video & Audio Manager ────────────────────────────────────────────────
      case "media.list": return json({ success: true, items: await listItems(admin, "media_item", userId) });
      case "media.add": {
        const item = await addItem(admin, "media_item", userId, {
          type: body.type ?? "video", url: body.url, title: body.title,
          duration_sec: body.duration_sec, thumbnail: body.thumbnail, tags: body.tags ?? [],
        });
        return json({ success: true, item });
      }
      case "media.delete": {
        await deleteItem(admin, "media_item", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Voice Memo Transcription ─────────────────────────────────────────────
      case "transcribe.create": {
        const item = await addItem(admin, "voice_memo", userId, {
          audio_url: body.audio_url, transcript: body.transcript ?? "",
          duration_sec: body.duration_sec, status: body.transcript ? "done" : "pending",
        });
        return json({ success: true, memo: item });
      }
      case "transcribe.list": return json({ success: true, memos: await listItems(admin, "voice_memo", userId) });
      case "transcribe.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId, status: "done" } })
          .eq("id", String(body.id ?? "")).eq("source", "voice_memo");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Screen Recorder ──────────────────────────────────────────────────────
      case "recording.start": {
        const item = await addItem(admin, "screen_recording", userId, {
          started_at: new Date().toISOString(), status: "recording", title: body.title ?? "",
        });
        return json({ success: true, session: item });
      }
      case "recording.stop": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "saved", stopped_at: new Date().toISOString(), url: body.url } })
          .eq("id", String(body.id ?? "")).eq("source", "screen_recording");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "recording.list": return json({ success: true, recordings: await listItems(admin, "screen_recording", userId) });

      // ── Live Streaming ───────────────────────────────────────────────────────
      case "stream.create": {
        const streamKey = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
        const item = await addItem(admin, "live_stream", userId, {
          title: body.title, stream_key: streamKey, status: "created",
          platform: body.platform ?? "custom", scheduled_at: body.scheduled_at,
        });
        return json({ success: true, stream: item, stream_key: streamKey });
      }
      case "stream.start": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "live", started_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "live_stream");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "stream.end": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { user_id: userId, status: "ended", ended_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "live_stream");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "stream.list": return json({ success: true, streams: await listItems(admin, "live_stream", userId) });

      // ── Video Meetings ───────────────────────────────────────────────────────
      case "meeting.create": {
        const roomId = crypto.randomUUID().slice(0, 8);
        const item = await addItem(admin, "video_meeting", userId, {
          title: body.title, room_id: roomId, scheduled_at: body.scheduled_at,
          participants: body.participants ?? [], status: "scheduled",
        });
        return json({ success: true, meeting: item, room_id: roomId });
      }
      case "meeting.list": return json({ success: true, meetings: await listItems(admin, "video_meeting", userId) });
      case "meeting.notes": {
        const item = await addItem(admin, "meeting_notes", userId, {
          meeting_id: body.meeting_id, notes: body.notes, action_items: body.action_items ?? [],
        });
        return json({ success: true, notes: item });
      }

      // ── Music Playlists ──────────────────────────────────────────────────────
      case "playlist.list": return json({ success: true, playlists: await listItems(admin, "playlist", userId) });
      case "playlist.create": {
        const item = await addItem(admin, "playlist", userId, {
          name: body.name, description: body.description, tracks: body.tracks ?? [], is_public: body.is_public ?? false,
        });
        return json({ success: true, playlist: item });
      }
      case "playlist.add_track": {
        const playlists = await listItems(admin, "playlist", userId, 100);
        const pl = playlists.find((p) => p.id === body.playlist_id);
        if (!pl) return json({ error: "Playlist not found" }, 404);
        const meta = pl.metadata as Record<string, unknown>;
        const tracks = (meta.tracks as unknown[]) ?? [];
        tracks.push(body.track);
        await admin.from("hub_data").update({ metadata: { ...meta, tracks } }).eq("id", pl.id);
        return json({ success: true, track_count: tracks.length });
      }
      case "playlist.delete": {
        await deleteItem(admin, "playlist", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Photo Gallery ────────────────────────────────────────────────────────
      case "gallery.list": return json({ success: true, albums: await listItems(admin, "photo_album", userId) });
      case "gallery.create_album": {
        const item = await addItem(admin, "photo_album", userId, {
          name: body.name, description: body.description, cover_url: body.cover_url, photos: [],
        });
        return json({ success: true, album: item });
      }
      case "gallery.add_photo": {
        const item = await addItem(admin, "photo", userId, {
          album_id: body.album_id, url: body.url, caption: body.caption, taken_at: body.taken_at,
        });
        return json({ success: true, photo: item });
      }
      case "gallery.list_photos": return json({ success: true, photos: await listItems(admin, "photo", userId) });

      // ── Podcast Manager ──────────────────────────────────────────────────────
      case "podcast.list": return json({ success: true, podcasts: await listItems(admin, "podcast", userId) });
      case "podcast.subscribe": {
        const item = await addItem(admin, "podcast", userId, {
          feed_url: body.feed_url, title: body.title, description: body.description,
        });
        return json({ success: true, podcast: item });
      }
      case "podcast.episodes": return json({ success: true, episodes: await listItems(admin, "podcast_episode", userId) });

      // ── AI Image Generator ───────────────────────────────────────────────────
      case "image.generate": {
        const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
        if (!openaiKey) return json({ error: "OPENAI_API_KEY not configured" }, 503);
        const res = await fetch("https://api.openai.com/v1/images/generations", {
          method: "POST",
          headers: { "Authorization": `Bearer ${openaiKey}`, "Content-Type": "application/json" },
          body: JSON.stringify({ prompt: body.prompt, n: 1, size: body.size ?? "1024x1024", model: "dall-e-3" }),
        });
        const result = await res.json() as { data?: Array<{ url: string }> };
        const imageUrl = result.data?.[0]?.url ?? "";
        await addItem(admin, "ai_image", userId, { prompt: body.prompt, url: imageUrl });
        return json({ success: true, url: imageUrl, prompt: body.prompt });
      }
      case "image.list": return json({ success: true, images: await listItems(admin, "ai_image", userId) });

      // ── Viral Video Generator ────────────────────────────────────────────────
      case "viral_video.create": {
        const item = await addItem(admin, "viral_video", userId, {
          type: body.type ?? "ad", script: body.script ?? "", style: body.style ?? "energetic",
          topic: body.topic, status: "draft",
        });
        return json({ success: true, video: item });
      }
      case "viral_video.list": return json({ success: true, videos: await listItems(admin, "viral_video", userId) });

      // ── OCR Document Scanner ─────────────────────────────────────────────────
      case "ocr.scan": {
        const item = await addItem(admin, "ocr_scan", userId, {
          image_url: body.image_url, extracted_text: body.extracted_text ?? "",
          status: body.extracted_text ? "done" : "pending", language: body.language ?? "ja",
        });
        return json({ success: true, scan: item });
      }
      case "ocr.list": return json({ success: true, scans: await listItems(admin, "ocr_scan", userId) });

      // ── Virtual Whiteboard ───────────────────────────────────────────────────
      case "whiteboard.list": return json({ success: true, boards: await listItems(admin, "whiteboard", userId) });
      case "whiteboard.create": {
        const boardId = crypto.randomUUID();
        const item = await addItem(admin, "whiteboard", userId, {
          board_id: boardId, title: body.title ?? "新しいホワイトボード",
          elements: body.elements ?? [], is_shared: body.is_shared ?? false,
        });
        return json({ success: true, board: item, board_id: boardId });
      }
      case "whiteboard.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId, updated_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "whiteboard");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "whiteboard.delete": {
        await deleteItem(admin, "whiteboard", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Document Collaboration ───────────────────────────────────────────────
      case "doc.list": return json({ success: true, docs: await listItems(admin, "collab_doc", userId) });
      case "doc.create": {
        const docId = crypto.randomUUID();
        const item = await addItem(admin, "collab_doc", userId, {
          doc_id: docId, title: body.title, content: body.content ?? "",
          collaborators: body.collaborators ?? [], version: 1,
        });
        return json({ success: true, doc: item, doc_id: docId });
      }
      case "doc.update": {
        const { error } = await admin.from("hub_data")
          .update({ metadata: { ...body, user_id: userId, updated_at: new Date().toISOString() } })
          .eq("id", String(body.id ?? "")).eq("source", "collab_doc");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Document E-Signature ─────────────────────────────────────────────────
      case "esign.create_request": {
        const signId = crypto.randomUUID();
        const item = await addItem(admin, "esign_request", userId, {
          sign_id: signId, document_url: body.document_url, title: body.title,
          signers: body.signers ?? [], status: "pending",
        });
        return json({ success: true, request: item, sign_id: signId });
      }
      case "esign.sign": {
        const item = await addItem(admin, "esign_signature", userId, {
          sign_id: body.sign_id, signature_data: body.signature_data,
          signed_at: new Date().toISOString(),
        });
        return json({ success: true, signature: item });
      }
      case "esign.list": return json({ success: true, requests: await listItems(admin, "esign_request", userId) });

      // ── Audio Effects ────────────────────────────────────────────────────────
      case "audio.effects": {
        const item = await addItem(admin, "audio_effect", userId, {
          effect: body.effect ?? "reverb", audio_url: body.audio_url, params: body.params ?? {},
        });
        return json({ success: true, effect_applied: item });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
