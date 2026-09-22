// media-hub — メディア・ドキュメント管理統合EF
// Merges (18 EFs): video-audio-manager, voice-memo-transcriber, screen-recorder,
//   live-streaming, video-meeting-manager, music-playlist-manager, photo-gallery-manager,
//   podcast-manager, ai-image-generator, viral-video-generator, viral-video-ad-generator,
//   ocr-document-scanner, virtual-whiteboard, whiteboard-canvas, document-collaboration,
//   document-esignature, meeting-manager, audio-effects-processor
//
// GET/POST ?action=<action> or body { action: "..." }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, traceparent, tracestate, baggage, sentry-trace",
  "Access-Control-Max-Age": "86400",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const GENERATED_IMAGE_BUCKET = "ai-generated-images";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return null;
  const bearer = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (SERVICE_ROLE_KEY && bearer === SERVICE_ROLE_KEY) return "service_role";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user?.id ?? null;
}

type OpenAiImageData = {
  url?: string;
  b64_json?: string;
  revised_prompt?: string;
};

type OpenAiImageResponse = {
  data?: OpenAiImageData[];
  error?: { message?: string };
};

const supportedImageModels = new Set([
  "gpt-image-1.5",
  "gpt-image-1",
  "gpt-image-1-mini",
  "dall-e-3",
]);

function normalizeImageModel(value: unknown): string | null {
  const raw = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!raw) return null;
  if (raw === "image-gen-2" || raw === "gpt-image-2") return "gpt-image-1.5";
  return supportedImageModels.has(raw) ? raw : null;
}

function imageModelCandidates(body: Record<string, unknown>): string[] {
  const candidates = [
    normalizeImageModel(body.preferredModel ?? body.model),
    ...(
      Array.isArray(body.creativePipeline)
        ? body.creativePipeline.map((item) => normalizeImageModel(item))
        : []
    ),
    "gpt-image-1.5",
    "gpt-image-1",
    "dall-e-3",
  ].filter((item): item is string => Boolean(item));
  return [...new Set(candidates)];
}

function imageSizeForModel(model: string, requested: string): string {
  if (model.startsWith("gpt-image-")) {
    if (requested === "1792x1024") return "1536x1024";
    if (requested === "1024x1792") return "1024x1536";
    return ["1024x1024", "1536x1024", "1024x1536", "auto"].includes(requested)
      ? requested
      : "1536x1024";
  }
  return ["1024x1024", "1024x1792", "1792x1024"].includes(requested)
    ? requested
    : "1792x1024";
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function storageSafeSegment(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") ||
    "anonymous";
}

async function persistGeneratedImageToStorage(
  admin: SupabaseClient,
  b64Json: string,
  userId: string,
): Promise<string | null> {
  try {
    const bytes = base64ToBytes(b64Json);
    const datePrefix = new Date().toISOString().slice(0, 10);
    const path = [
      "openai",
      storageSafeSegment(userId),
      datePrefix,
      `${crypto.randomUUID()}.png`,
    ].join("/");
    const { error } = await admin.storage
      .from(GENERATED_IMAGE_BUCKET)
      .upload(path, bytes, {
        contentType: "image/png",
        cacheControl: "604800",
        upsert: false,
      });
    if (error) throw error;
    const { data } = admin.storage.from(GENERATED_IMAGE_BUCKET).getPublicUrl(
      path,
    );
    return data.publicUrl;
  } catch (error) {
    console.warn("Generated image storage upload failed", error);
    return null;
  }
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin.from("hub_data")
    .select("id, metadata, created_at")
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function addItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  meta: Record<string, unknown>,
) {
  const { data, error } = await admin.from("hub_data")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at").single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin.from("hub_data")
    .delete().eq("id", id).eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const body: Record<string, unknown> = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const action = (body.action as string) ?? url.searchParams.get("action") ??
      "";
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);

    switch (action) {
      // ── Video & Audio Manager ────────────────────────────────────────────────
      case "media.list":
        return json({
          success: true,
          items: await listItems(admin, "media_item", userId),
        });
      case "media.add": {
        const item = await addItem(admin, "media_item", userId, {
          type: body.type ?? "video",
          url: body.url,
          title: body.title,
          duration_sec: body.duration_sec,
          thumbnail: body.thumbnail,
          tags: body.tags ?? [],
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
          audio_url: body.audio_url,
          transcript: body.transcript ?? "",
          duration_sec: body.duration_sec,
          status: body.transcript ? "done" : "pending",
        });
        return json({ success: true, memo: item });
      }
      case "transcribe.list":
        return json({
          success: true,
          memos: await listItems(admin, "voice_memo", userId),
        });
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
          started_at: new Date().toISOString(),
          status: "recording",
          title: body.title ?? "",
        });
        return json({ success: true, session: item });
      }
      case "recording.stop": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "saved",
              stopped_at: new Date().toISOString(),
              url: body.url,
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "screen_recording");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "recording.list":
        return json({
          success: true,
          recordings: await listItems(admin, "screen_recording", userId),
        });
      case "screenshot.list":
        return json({
          success: true,
          screenshots: await listItems(admin, "screenshot", userId),
        });
      case "screenshot.save": {
        const item = await addItem(admin, "screenshot", userId, {
          url: body.url ?? "",
          title: body.title ?? "",
          captured_at: new Date().toISOString(),
        });
        return json({ success: true, screenshot: item });
      }

      // ── Live Streaming ───────────────────────────────────────────────────────
      case "stream.create": {
        const streamKey = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
        const item = await addItem(admin, "live_stream", userId, {
          title: body.title,
          stream_key: streamKey,
          status: "created",
          platform: body.platform ?? "custom",
          scheduled_at: body.scheduled_at,
        });
        return json({ success: true, stream: item, stream_key: streamKey });
      }
      case "stream.start": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "live",
              started_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "live_stream");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "stream.end": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              user_id: userId,
              status: "ended",
              ended_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "live_stream");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "stream.list":
        return json({
          success: true,
          streams: await listItems(admin, "live_stream", userId),
        });

      // ── Video Meetings ───────────────────────────────────────────────────────
      case "meeting.create": {
        const roomId = crypto.randomUUID().slice(0, 8);
        const item = await addItem(admin, "video_meeting", userId, {
          title: body.title,
          room_id: roomId,
          scheduled_at: body.scheduled_at,
          participants: body.participants ?? [],
          status: "scheduled",
        });
        return json({ success: true, meeting: item, room_id: roomId });
      }
      case "meeting.list":
        return json({
          success: true,
          meetings: await listItems(admin, "video_meeting", userId),
        });
      case "meeting.notes": {
        const item = await addItem(admin, "meeting_notes", userId, {
          meeting_id: body.meeting_id,
          notes: body.notes,
          action_items: body.action_items ?? [],
        });
        return json({ success: true, notes: item });
      }

      // ── Music Playlists ──────────────────────────────────────────────────────
      case "playlist.list":
        return json({
          success: true,
          playlists: await listItems(admin, "playlist", userId),
        });
      case "playlist.create": {
        const item = await addItem(admin, "playlist", userId, {
          name: body.name,
          description: body.description,
          tracks: body.tracks ?? [],
          is_public: body.is_public ?? false,
        });
        return json({ success: true, playlist: item });
      }
      case "playlist.tracks": {
        const plId = String(body.playlist_id ?? body.playlistId ?? "");
        const playlists = await listItems(admin, "playlist", userId, 100);
        const pl = playlists.find((p) => p.id === plId);
        if (!pl) return json({ success: true, tracks: [] });
        const meta = pl.metadata as Record<string, unknown>;
        return json({
          success: true,
          tracks: (meta.tracks as unknown[]) ?? [],
        });
      }
      case "playlist.add_track": {
        const playlists = await listItems(admin, "playlist", userId, 100);
        const plId2 = String(body.playlist_id ?? body.playlistId ?? "");
        const pl = playlists.find((p) => p.id === plId2);
        if (!pl) return json({ error: "Playlist not found" }, 404);
        const meta = pl.metadata as Record<string, unknown>;
        const tracks = (meta.tracks as unknown[]) ?? [];
        const newTrack = body.track ??
          { title: body.title, artist: body.artist };
        tracks.push(newTrack);
        await admin.from("hub_data").update({ metadata: { ...meta, tracks } })
          .eq("id", pl.id);
        return json({ success: true, track_count: tracks.length });
      }
      case "playlist.delete": {
        await deleteItem(admin, "playlist", userId, String(body.id ?? ""));
        return json({ success: true });
      }

      // ── Photo Gallery ────────────────────────────────────────────────────────
      case "gallery.list":
        return json({
          success: true,
          albums: await listItems(admin, "photo_album", userId),
        });
      case "gallery.create_album": {
        const item = await addItem(admin, "photo_album", userId, {
          name: body.name,
          description: body.description,
          cover_url: body.cover_url,
          photos: [],
        });
        return json({ success: true, album: item });
      }
      case "gallery.add_photo": {
        const item = await addItem(admin, "photo", userId, {
          album_id: body.album_id,
          url: body.url,
          caption: body.caption,
          taken_at: body.taken_at,
        });
        return json({ success: true, photo: item });
      }
      case "gallery.list_photos": {
        const allPhotos = await listItems(admin, "photo", userId, 200);
        const albumId = String(body.album_id ?? body.albumId ?? "");
        const photos = albumId
          ? allPhotos.filter((p: Record<string, unknown>) =>
            (p.metadata as Record<string, unknown>)?.album_id === albumId
          )
          : allPhotos;
        return json({ success: true, photos });
      }

      // ── Podcast Manager ──────────────────────────────────────────────────────
      case "podcast.list":
        return json({
          success: true,
          podcasts: await listItems(admin, "podcast", userId),
        });
      case "podcast.subscribe": {
        const item = await addItem(admin, "podcast", userId, {
          feed_url: body.feed_url,
          title: body.title,
          description: body.description,
        });
        return json({ success: true, podcast: item });
      }
      case "podcast.episodes":
        return json({
          success: true,
          episodes: await listItems(admin, "podcast_episode", userId),
        });

      // ── AI Image Generator ───────────────────────────────────────────────────
      case "image.generate": {
        const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
        if (!openaiKey) {
          return json({ error: "OPENAI_API_KEY not configured" }, 503);
        }
        const prompt = String(body.prompt ?? "").trim();
        if (!prompt) return json({ error: "prompt required" }, 400);

        const requestedSize = String(body.size ?? "1024x1024");
        const requestedStyle = String(body.style ?? "vivid");
        const style = requestedStyle === "natural" ? "natural" : "vivid";
        const requestedQuality = String(body.quality ?? "medium");
        const quality =
          ["low", "medium", "high", "auto"].includes(requestedQuality)
            ? requestedQuality
            : "medium";
        const returnB64 = body.returnB64 === true;
        const persist = body.persist !== false;
        const errors: Array<{ model: string; status: number; error: string }> =
          [];
        let generated: OpenAiImageData | undefined;
        let usedModel = "";
        let usedSize = "";

        for (const model of imageModelCandidates(body)) {
          const size = imageSizeForModel(model, requestedSize);
          const payload: Record<string, unknown> = {
            prompt,
            n: 1,
            size,
            model,
          };
          if (model.startsWith("gpt-image-")) {
            payload.quality = quality;
            payload.output_format = "png";
          } else {
            payload.style = style;
            payload.response_format = "url";
          }

          const res = await fetch(
            "https://api.openai.com/v1/images/generations",
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${openaiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(payload),
            },
          );
          const raw = await res.text();
          let result: OpenAiImageResponse;
          try {
            result = JSON.parse(raw);
          } catch {
            errors.push({
              model,
              status: res.status,
              error: raw.slice(0, 500),
            });
            continue;
          }
          if (!res.ok) {
            errors.push({
              model,
              status: res.status,
              error: result.error?.message ?? raw.slice(0, 500),
            });
            continue;
          }
          generated = result.data?.[0];
          usedModel = model;
          usedSize = size;
          break;
        }

        const imageUrl = generated?.url ?? "";
        const b64Json = generated?.b64_json ?? "";
        const storedImageUrl = !imageUrl && b64Json
          ? await persistGeneratedImageToStorage(admin, b64Json, userId)
          : null;
        const publicImageUrl = imageUrl || storedImageUrl || "";
        const dataUrl = b64Json ? `data:image/png;base64,${b64Json}` : "";
        if (!imageUrl && !b64Json) {
          return json({
            success: false,
            error: "OpenAI image response did not include url or b64_json",
            errors,
          }, 502);
        }

        const item = persist
          ? await addItem(admin, "ai_image", userId, {
            prompt,
            url: publicImageUrl || dataUrl,
            size: usedSize,
            style,
            quality,
            provider: "openai",
            model: usedModel,
            requested_model: body.preferredModel ?? body.model ?? null,
            revised_prompt: generated?.revised_prompt ?? null,
          })
          : null;
        return json({
          success: true,
          image: item,
          url: publicImageUrl || dataUrl,
          storageUrl: storedImageUrl,
          b64Json: returnB64 ? b64Json : undefined,
          prompt,
          size: usedSize,
          style,
          quality,
          model: usedModel,
          requestedModel: body.preferredModel ?? body.model ?? null,
          fallbackErrors: errors,
        });
      }
      case "image.list":
        return json({
          success: true,
          images: await listItems(admin, "ai_image", userId),
        });

      // ── Viral Video Generator ────────────────────────────────────────────────
      case "viral_video.create": {
        const item = await addItem(admin, "viral_video", userId, {
          type: body.type ?? "ad",
          script: body.script ?? "",
          style: body.style ?? "energetic",
          topic: body.topic,
          status: "draft",
        });
        return json({ success: true, video: item });
      }
      case "viral_video.list":
        return json({
          success: true,
          videos: await listItems(admin, "viral_video", userId),
        });
      case "viral_video.list_briefs":
        return json({
          success: true,
          briefs: await listItems(admin, "viral_video", userId),
        });

      // ── OCR Document Scanner ─────────────────────────────────────────────────
      case "ocr.scan": {
        const item = await addItem(admin, "ocr_scan", userId, {
          image_url: body.image_url,
          extracted_text: body.extracted_text ?? "",
          status: body.extracted_text ? "done" : "pending",
          language: body.language ?? "ja",
        });
        return json({ success: true, scan: item });
      }
      case "ocr.list":
        return json({
          success: true,
          scans: await listItems(admin, "ocr_scan", userId),
        });

      // ── Virtual Whiteboard ───────────────────────────────────────────────────
      case "whiteboard.list":
        return json({
          success: true,
          boards: await listItems(admin, "whiteboard", userId),
        });
      case "whiteboard.create": {
        const boardId = crypto.randomUUID();
        const item = await addItem(admin, "whiteboard", userId, {
          board_id: boardId,
          title: body.title ?? "新しいホワイトボード",
          elements: body.elements ?? [],
          is_shared: body.is_shared ?? false,
        });
        return json({ success: true, board: item, board_id: boardId });
      }
      case "whiteboard.update": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              ...body,
              user_id: userId,
              updated_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "whiteboard");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }
      case "whiteboard.delete": {
        await deleteItem(admin, "whiteboard", userId, String(body.id ?? ""));
        return json({ success: true });
      }
      case "whiteboard.get": {
        const boards = await listItems(admin, "whiteboard", userId);
        const board = boards.find((b: Record<string, unknown>) =>
          b.board_id === body.board_id || b.id === body.board_id
        );
        return json({ success: true, board: board ?? null });
      }
      case "whiteboard.config": {
        const config = await listItems(admin, "whiteboard_config", userId);
        return json({ success: true, config: config[0] ?? {} });
      }
      case "whiteboard.add_element": {
        const board = (await listItems(admin, "whiteboard", userId)).find((
          b: Record<string, unknown>,
        ) => b.board_id === body.board_id);
        if (!board) return json({ error: "Board not found" }, 404);
        const elements =
          Array.isArray((board as Record<string, unknown>).elements)
            ? (board as Record<string, unknown>).elements as unknown[]
            : [];
        elements.push({ ...body.element, id: crypto.randomUUID() });
        await admin.from("hub_data").update({
          metadata: {
            ...(board as Record<string, unknown>),
            elements,
            updated_at: new Date().toISOString(),
          },
        })
          .eq("id", String((board as Record<string, unknown>).id ?? "")).eq(
            "source",
            "whiteboard",
          );
        return json({ success: true });
      }

      // ── Document Collaboration ───────────────────────────────────────────────
      case "doc.list":
        return json({
          success: true,
          docs: await listItems(admin, "collab_doc", userId),
        });
      case "doc.create": {
        const docId = crypto.randomUUID();
        const item = await addItem(admin, "collab_doc", userId, {
          doc_id: docId,
          title: body.title,
          content: body.content ?? "",
          collaborators: body.collaborators ?? [],
          version: 1,
        });
        return json({ success: true, doc: item, doc_id: docId });
      }
      case "doc.update": {
        const { error } = await admin.from("hub_data")
          .update({
            metadata: {
              ...body,
              user_id: userId,
              updated_at: new Date().toISOString(),
            },
          })
          .eq("id", String(body.id ?? "")).eq("source", "collab_doc");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      // ── Document E-Signature ─────────────────────────────────────────────────
      case "esign.create_request": {
        const signId = crypto.randomUUID();
        const item = await addItem(admin, "esign_request", userId, {
          sign_id: signId,
          document_url: body.document_url,
          title: body.title,
          signers: body.signers ?? [],
          status: "pending",
        });
        return json({ success: true, request: item, sign_id: signId });
      }
      case "esign.sign": {
        const item = await addItem(admin, "esign_signature", userId, {
          sign_id: body.sign_id,
          signature_data: body.signature_data,
          signed_at: new Date().toISOString(),
        });
        return json({ success: true, signature: item });
      }
      case "esign.list":
        return json({
          success: true,
          requests: await listItems(admin, "esign_request", userId),
        });

      // ── Podcast Manager ──────────────────────────────────────────────────────
      case "podcast.channels":
        return json({
          success: true,
          channels: await listItems(admin, "podcast_channel", userId),
        });
      case "podcast.channel.add": {
        const item = await addItem(admin, "podcast_channel", userId, {
          title: body.title ?? "",
          url: body.url ?? "",
          category: body.category ?? "technology",
        });
        return json({ success: true, channel: item });
      }
      case "podcast.episode.save": {
        const item = await addItem(admin, "podcast_episode", userId, {
          title: body.title ?? "",
          audio_url: body.audio_url ?? "",
          channel_id: body.channel_id ?? "",
          duration_sec: body.duration_sec ?? 0,
          played: false,
        });
        return json({ success: true, episode: item });
      }

      // ── Audio Effects ────────────────────────────────────────────────────────
      case "audio.catalog": {
        const effects = [
          {
            id: "reverb_hall",
            name: "Hall Reverb",
            description: "広大なホールの残響",
            category: "reverb",
          },
          {
            id: "reverb_room",
            name: "Room Reverb",
            description: "小部屋の自然な響き",
            category: "reverb",
          },
          {
            id: "reverb_plate",
            name: "Plate Reverb",
            description: "プレートリバーブ風の明るい響き",
            category: "reverb",
          },
          {
            id: "delay_slapback",
            name: "Slapback Delay",
            description: "短いディレイ",
            category: "delay",
          },
          {
            id: "delay_ping_pong",
            name: "Ping Pong Delay",
            description: "左右交互のディレイ",
            category: "delay",
          },
          {
            id: "chorus_subtle",
            name: "Subtle Chorus",
            description: "自然なコーラス効果",
            category: "chorus",
          },
          {
            id: "chorus_lush",
            name: "Lush Chorus",
            description: "豊かなコーラス",
            category: "chorus",
          },
          {
            id: "distortion_light",
            name: "Light Distortion",
            description: "軽いオーバードライブ",
            category: "distortion",
          },
          {
            id: "distortion_heavy",
            name: "Heavy Distortion",
            description: "ヘビーなディストーション",
            category: "distortion",
          },
          {
            id: "compressor_light",
            name: "Light Compressor",
            description: "軽いコンプレッション",
            category: "compressor",
          },
          {
            id: "compressor_medium",
            name: "Medium Compressor",
            description: "中程度のコンプレッション",
            category: "compressor",
          },
          {
            id: "eq_bass_boost",
            name: "Bass Boost",
            description: "低音域を強調",
            category: "eq",
          },
          {
            id: "eq_presence",
            name: "Presence Boost",
            description: "中高域を明瞭化",
            category: "eq",
          },
        ];
        return json({
          success: true,
          effects,
          categories: [
            "reverb",
            "delay",
            "chorus",
            "distortion",
            "compressor",
            "eq",
          ],
          totalEffects: effects.length,
        });
      }
      case "audio.effects": {
        const item = await addItem(admin, "audio_effect", userId, {
          effect: body.effect ?? "reverb",
          audio_url: body.audio_url,
          params: body.params ?? {},
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
