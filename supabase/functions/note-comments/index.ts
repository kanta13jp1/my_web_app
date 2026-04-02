/**
 * note-comments — GET list / POST add / DELETE remove
 *
 * GET  ?note_id=<n>             → { comments: [{id, content, created_at},...] }
 * POST { note_id, content }     → { ok: true, comment: {id, content, created_at} }
 * DELETE { id }                 → { ok: true }
 *
 * All operations require a valid JWT (user must own the note).
 */
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function getUserIdFromJwt(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return null;
  try {
    // JWT payload is base64url-encoded second segment
    const parts = token.split(".");
    if (parts.length < 2) return null;
    const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
    return payload.sub ?? null;
  } catch {
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  if (SUPABASE_URL === "" || SUPABASE_ANON_KEY === "") {
    return json({ error: "misconfigured" }, 500);
  }

  const userId = getUserIdFromJwt(req);
  if (!userId) {
    return json({ error: "unauthorized" }, 401);
  }

  // Use ANON_KEY + user JWT so RLS policies on note_comments apply at DB level.
  // SERVICE_ROLE_KEY is intentionally NOT used for user-scoped operations.
  const authHeader = req.headers.get("authorization") ?? "";
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ── GET ──────────────────────────────────────────────────────────────────────
  if (req.method === "GET") {
    const noteId = Number.parseInt(
      new URL(req.url).searchParams.get("note_id") ?? "",
      10,
    );
    if (!Number.isFinite(noteId) || noteId <= 0) {
      return json({ error: "invalid note_id" }, 400);
    }

    // Verify the note belongs to the requesting user
    const { data: note } = await client
      .from("notes")
      .select("id")
      .eq("id", noteId)
      .eq("user_id", userId)
      .maybeSingle();

    if (!note) {
      return json({ error: "note not found" }, 404);
    }

    const { data, error } = await client
      .from("note_comments")
      .select("id, content, created_at, updated_at")
      .eq("note_id", noteId)
      .eq("user_id", userId)
      .order("created_at", { ascending: true });

    if (error) {
      return json({ error: error.message }, 500);
    }

    return json({ comments: data ?? [] });
  }

  // ── POST ─────────────────────────────────────────────────────────────────────
  if (req.method === "POST") {
    // deno-lint-ignore no-explicit-any
    let body: any;
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid json" }, 400);
    }

    const noteId = Number.parseInt(String(body.note_id ?? ""), 10);
    const content = String(body.content ?? "").trim();

    if (!Number.isFinite(noteId) || noteId <= 0) {
      return json({ error: "invalid note_id" }, 400);
    }
    if (content.length === 0) {
      return json({ error: "content is required" }, 400);
    }
    if (content.length > 2000) {
      return json({ error: "content too long (max 2000 chars)" }, 400);
    }

    // Verify note ownership
    const { data: note } = await client
      .from("notes")
      .select("id")
      .eq("id", noteId)
      .eq("user_id", userId)
      .maybeSingle();

    if (!note) {
      return json({ error: "note not found" }, 404);
    }

    const { data, error } = await client
      .from("note_comments")
      .insert({ note_id: noteId, user_id: userId, content })
      .select("id, content, created_at, updated_at")
      .single();

    if (error) {
      return json({ error: error.message }, 500);
    }

    return json({ ok: true, comment: data });
  }

  // ── DELETE ───────────────────────────────────────────────────────────────────
  if (req.method === "DELETE") {
    // deno-lint-ignore no-explicit-any
    let body: any;
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid json" }, 400);
    }

    const commentId = String(body.id ?? "").trim();
    if (!commentId) {
      return json({ error: "id is required" }, 400);
    }

    const { error } = await client
      .from("note_comments")
      .delete()
      .eq("id", commentId)
      .eq("user_id", userId);

    if (error) {
      return json({ error: error.message }, 500);
    }

    return json({ ok: true });
  }

  return json({ error: "method not allowed" }, 405);
});
