/**
 * memo-reactions — GET counts / POST toggle reaction
 *
 * GET  ?memo_id=<n>          → { reactions: { "👍": 3, "❤️": 1, … }, userReactions: ["👍"] }
 * POST { memo_id, reaction }  → { ok: true, added: boolean, counts: {…} }
 */
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ALLOWED_REACTIONS = ["👍", "❤️", "🔥", "💡", "🎉"];

async function hashIp(ip: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(`memo-reaction-${ip}`);
  const buf = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 16);
}

function getClientIp(req: Request): string {
  return (
    req.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
    req.headers.get("x-real-ip") ??
    "unknown"
  );
}

async function getCounts(
  client: ReturnType<typeof createClient>,
  memoId: number,
): Promise<Record<string, number>> {
  const { data } = await client
    .from("memo_reactions")
    .select("reaction")
    .eq("memo_id", memoId);

  const counts: Record<string, number> = {};
  for (const r of ALLOWED_REACTIONS) counts[r] = 0;
  for (const row of data ?? []) {
    if (row.reaction in counts) counts[row.reaction]++;
  }
  return counts;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS });
  }

  if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
    return new Response(JSON.stringify({ error: "misconfigured" }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }

  const client = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const ipHash = await hashIp(getClientIp(req));

  // ── GET ──────────────────────────────────────────────────────────────────────
  if (req.method === "GET") {
    const memoId = Number.parseInt(
      new URL(req.url).searchParams.get("memo_id") ?? "",
      10,
    );
    if (!Number.isFinite(memoId) || memoId <= 0) {
      return new Response(JSON.stringify({ error: "invalid memo_id" }), {
        status: 400,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const [counts, userRows] = await Promise.all([
      getCounts(client, memoId),
      client
        .from("memo_reactions")
        .select("reaction")
        .eq("memo_id", memoId)
        .eq("ip_hash", ipHash),
    ]);

    const userReactions = (userRows.data ?? []).map((r) => r.reaction as string);

    return new Response(
      JSON.stringify({ reactions: counts, userReactions }),
      { headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }

  // ── POST ─────────────────────────────────────────────────────────────────────
  if (req.method === "POST") {
    let body: { memo_id?: unknown; reaction?: unknown };
    try {
      body = await req.json().catch(() => ({}));
    } catch {
      return new Response(JSON.stringify({ error: "invalid json" }), {
        status: 400,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const memoId = Number.parseInt(String(body.memo_id ?? ""), 10);
    const reaction = String(body.reaction ?? "");

    if (!Number.isFinite(memoId) || memoId <= 0) {
      return new Response(JSON.stringify({ error: "invalid memo_id" }), {
        status: 400,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }
    if (!ALLOWED_REACTIONS.includes(reaction)) {
      return new Response(JSON.stringify({ error: "invalid reaction" }), {
        status: 400,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // Check if memo is public
    const { data: memo } = await client
      .from("public_memos")
      .select("id")
      .eq("id", memoId)
      .eq("is_public", true)
      .maybeSingle();

    if (!memo) {
      return new Response(JSON.stringify({ error: "memo not found" }), {
        status: 404,
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // Toggle: try insert; if conflict → delete (toggle off)
    const { error: insertErr } = await client.from("memo_reactions").insert({
      memo_id: memoId,
      reaction,
      ip_hash: ipHash,
    });

    let added = true;
    if (insertErr) {
      // Unique constraint violation → remove the reaction (toggle off)
      await client
        .from("memo_reactions")
        .delete()
        .eq("memo_id", memoId)
        .eq("ip_hash", ipHash)
        .eq("reaction", reaction);
      added = false;
    }

    const counts = await getCounts(client, memoId);
    return new Response(JSON.stringify({ ok: true, added, counts }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ error: "method not allowed" }), {
    status: 405,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
});
