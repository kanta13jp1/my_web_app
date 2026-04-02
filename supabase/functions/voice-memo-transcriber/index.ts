// Voice Memo Transcriber Edge Function
// 音声メモ・文字起こし (Google Keep/LINE/Discord競合)
// - 音声メモ登録
// - 文字起こし結果管理
// - AI要約付き文字起こし
// - ノートへの変換
//
// GET  → 音声メモ一覧 / 詳細 / 検索
// POST → 音声メモ登録 / 文字起こし完了 / ノート変換

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

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
      const memoId = url.searchParams.get("memo_id");
      const q = url.searchParams.get("q");

      if (view === "detail" && memoId) {
        const { data: memo } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "voice_memo").eq("metadata->>memo_id", memoId).maybeSingle();
        if (!memo) {
          return new Response(JSON.stringify({ success: false, error: "Memo not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({ success: true, memo: { ...(memo.metadata as Record<string, unknown>), createdAt: memo.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "search" && q) {
        const { data: memos } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "voice_memo").order("created_at", { ascending: false }).limit(100);
        const query = q.toLowerCase();
        const filtered = (memos ?? []).filter((m) => {
          const meta = m.metadata as Record<string, unknown>;
          const transcript = ((meta.transcript as string) ?? "").toLowerCase();
          const title = ((meta.title as string) ?? "").toLowerCase();
          return transcript.includes(query) || title.includes(query);
        });
        return new Response(JSON.stringify({
          success: true,
          memos: filtered.map((m) => ({ ...(m.metadata as Record<string, unknown>), createdAt: m.created_at })),
          query: q,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: list
      const { data: memos } = await adminClient.from("app_analytics").select("metadata, created_at").eq("user_id", user.id).eq("source", "voice_memo").order("created_at", { ascending: false }).limit(50);
      return new Response(JSON.stringify({
        success: true,
        memos: (memos ?? []).map((m) => {
          const meta = m.metadata as Record<string, unknown>;
          return {
            memo_id: meta.memo_id,
            title: meta.title,
            duration_seconds: meta.duration_seconds,
            has_transcript: !!meta.transcript,
            status: meta.status,
            createdAt: m.created_at,
          };
        }),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "register") {
        const { title, duration_seconds, file_url, language } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const memoId = crypto.randomUUID();
        const { error } = await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "voice_memo",
          metadata: {
            memo_id: memoId,
            title,
            duration_seconds: duration_seconds ?? 0,
            file_url: file_url ?? null,
            language: language ?? "ja",
            transcript: null,
            summary: null,
            status: "pending", // pending | transcribing | completed
          },
          created_at: new Date().toISOString(),
        });
        if (error) throw error;
        return new Response(JSON.stringify({ success: true, memoId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "complete_transcription") {
        const { memo_id, transcript, summary } = body;
        if (!memo_id || !transcript) {
          return new Response(JSON.stringify({ success: false, error: "memo_id and transcript required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: existing } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "voice_memo").eq("metadata->>memo_id", memo_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Memo not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const meta = existing.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, transcript, summary: summary ?? null, status: "completed", transcribed_at: new Date().toISOString() },
        }).eq("user_id", user.id).eq("source", "voice_memo").eq("metadata->>memo_id", memo_id);

        return new Response(JSON.stringify({ success: true, transcribed: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "convert_to_note") {
        const { memo_id } = body;
        if (!memo_id) {
          return new Response(JSON.stringify({ success: false, error: "memo_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const { data: memo } = await adminClient.from("app_analytics").select("metadata").eq("user_id", user.id).eq("source", "voice_memo").eq("metadata->>memo_id", memo_id).maybeSingle();
        if (!memo) {
          return new Response(JSON.stringify({ success: false, error: "Memo not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        const meta = memo.metadata as Record<string, unknown>;
        if (!meta.transcript) {
          return new Response(JSON.stringify({ success: false, error: "No transcript available" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }

        // Create a note from transcript
        const content = meta.summary
          ? `## 要約\n${meta.summary}\n\n## 文字起こし\n${meta.transcript}`
          : `## 文字起こし\n${meta.transcript}`;

        const { data: note, error } = await adminClient.from("notes").insert({
          user_id: user.id,
          title: `🎤 ${meta.title}`,
          content,
          tags: ["voice-memo", "transcription"],
        }).select().single();

        if (error) throw error;

        // Update memo with note reference
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, converted_to_note_id: note.id },
        }).eq("user_id", user.id).eq("source", "voice_memo").eq("metadata->>memo_id", memo_id);

        return new Response(JSON.stringify({ success: true, noteId: note.id }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
