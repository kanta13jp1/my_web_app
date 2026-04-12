// core-hub — コアUI・メモ・通知・ユーザー管理統合EF
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
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return null;
  const c = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const {
    data: { user },
  } = await c.auth.getUser();
  return user?.id ?? null;
}

async function listItems(
  admin: SupabaseClient,
  source: string,
  userId: string,
  limit = 50,
) {
  const { data, error } = await admin
    .from("app_analytics")
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
  const { data, error } = await admin
    .from("app_analytics")
    .insert({ source, metadata: { ...meta, user_id: userId } })
    .select("id, metadata, created_at")
    .single();
  if (error) throw new Error(error.message);
  return data;
}

async function deleteItem(
  admin: SupabaseClient,
  source: string,
  userId: string,
  id: string,
) {
  const { error } = await admin
    .from("app_analytics")
    .delete()
    .eq("id", id)
    .eq("source", source)
    .filter("metadata->>user_id", "eq", userId);
  if (error) throw new Error(error.message);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    // deno-lint-ignore no-explicit-any
    let body: Record<string, any> = {};
    if (req.method !== "GET") {
      try {
        body = await req.json();
      } catch {
        body = {};
      }
    }

    const action: string = body.action ?? "";
    const userId = await getUserId(req);
    if (!userId) {
      return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ---- Memo sharing ----
      case "memo.share": {
        const item = await addItem(admin, "memo_share", userId, {
          memo_id: body.memo_id,
          title: body.title,
          content: body.content,
        });
        return json({ success: true, item });
      }

      case "memo.share_list": {
        const items = await listItems(admin, "memo_share", userId);
        return json({ success: true, items });
      }

      // ---- Memo reactions ----
      case "memo.react": {
        const item = await addItem(admin, "memo_reaction", userId, {
          memo_id: body.memo_id,
          reaction: body.reaction,
        });
        return json({ success: true, item });
      }

      // ---- OGP (memo) ----
      case "memo.ogp": {
        const item = await addItem(admin, "memo_ogp", userId, {
          url: body.url,
          title: body.title,
          description: body.description,
          image: body.image,
        });
        return json({ success: true, item });
      }

      // ---- OGP fetch (stateless) ----
      case "ogp.fetch": {
        if (!body.url) return json({ error: "url required" }, 400);
        let ogTitle = "";
        let ogDescription = "";
        let ogImage = "";
        try {
          const res = await fetch(body.url as string, {
            signal: AbortSignal.timeout(8000),
          });
          const html = await res.text();
          const titleMatch = html.match(
            /<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i,
          );
          const descMatch = html.match(
            /<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']/i,
          );
          const imgMatch = html.match(
            /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
          );
          const titleMatchAlt = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']/i,
          );
          const descMatchAlt = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:description["']/i,
          );
          const imgMatchAlt = html.match(
            /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
          );
          ogTitle = titleMatch?.[1] ?? titleMatchAlt?.[1] ?? "";
          ogDescription = descMatch?.[1] ?? descMatchAlt?.[1] ?? "";
          ogImage = imgMatch?.[1] ?? imgMatchAlt?.[1] ?? "";
        } catch {
          // fetch failed — return empty
        }
        return json({
          success: true,
          og: { title: ogTitle, description: ogDescription, image: ogImage },
        });
      }

      // ---- Note comments ----
      case "note.comment.list": {
        const items = await listItems(admin, "note_comment", userId);
        return json({ success: true, items });
      }

      case "note.comment.add": {
        const item = await addItem(admin, "note_comment", userId, {
          note_id: body.note_id,
          text: body.text,
        });
        return json({ success: true, item });
      }

      case "note.comment.delete": {
        await deleteItem(admin, "note_comment", userId, String(body.id));
        return json({ success: true });
      }

      // ---- Notifications ----
      case "notification.list": {
        const rawItems = await listItems(admin, "notification", userId, 50);
        // metadata をフラット化して旧 notification-center 互換フォーマットに変換
        const notifications = rawItems.map((row) => {
          const meta = (row.metadata as Record<string, unknown>) ?? {};
          return {
            id: row.id,
            title: meta["title"] ?? "",
            message: meta["message"] ?? "",
            type: meta["type"] ?? "info",
            is_read: !!(meta["read"] as boolean),
            created_at: row.created_at,
          };
        });
        const filter = (body.filter as string) ?? "all";
        const limit = Number(body.limit ?? 50);
        const filtered = filter === "unread"
          ? notifications.filter((n) => !n.is_read)
          : notifications;
        const result = filtered.slice(0, limit);
        const unreadCount = notifications.filter((n) => !n.is_read).length;
        return json({ success: true, notifications: result, unreadCount });
      }

      case "notification.create": {
        const item = await addItem(admin, "notification", userId, {
          title: body.title,
          message: body.message,
          type: body.type ?? "info",
          read: false,
        });
        return json({ success: true, item });
      }

      case "notification.mark_read": {
        if (!body.id) return json({ error: "id required" }, 400);
        const { data: existing, error: fetchErr } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("id", String(body.id))
          .eq("source", "notification")
          .single();
        if (fetchErr) return json({ error: fetchErr.message }, 400);
        const updatedMeta = { ...(existing?.metadata ?? {}), read: true };
        const { error: updateErr } = await admin
          .from("app_analytics")
          .update({ metadata: updatedMeta })
          .eq("id", String(body.id))
          .eq("source", "notification");
        if (updateErr) return json({ error: updateErr.message }, 400);
        return json({ success: true });
      }

      case "notification.mark_all": {
        // ユーザーの全通知を既読にする
        const { data: rows, error: listErr } = await admin
          .from("app_analytics")
          .select("id, metadata")
          .eq("source", "notification")
          .filter("metadata->>user_id", "eq", userId);
        if (listErr) return json({ error: listErr.message }, 400);
        for (const row of rows ?? []) {
          const meta = { ...(row.metadata as Record<string, unknown>), read: true };
          await admin.from("app_analytics").update({ metadata: meta }).eq("id", row.id);
        }
        return json({ success: true, updated: (rows ?? []).length });
      }

      // ---- User profile ----
      case "user.profile": {
        const { data } = await admin
          .from("app_analytics")
          .select("metadata")
          .eq("source", "user_profile")
          .filter("metadata->>user_id", "eq", userId)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        return json({ success: true, profile: data?.metadata ?? {} });
      }

      case "user.update": {
        const item = await addItem(admin, "user_profile", userId, {
          ...body,
          user_id: userId,
        });
        return json({ success: true, item });
      }

      // ---- Onboarding ----
      case "onboarding.get": {
        const items = await listItems(admin, "onboarding_step", userId, 20);
        return json({ success: true, items });
      }

      case "onboarding.complete": {
        const item = await addItem(admin, "onboarding_step", userId, {
          step: body.step,
          completed_at: new Date().toISOString(),
        });
        return json({ success: true, item });
      }

      // ---- Feature requests ----
      case "feature_request.list": {
        const items = await listItems(admin, "feature_request_user", userId);
        return json({ success: true, items });
      }

      case "feature_request.vote": {
        const item = await addItem(admin, "feature_request_vote", userId, {
          request_id: body.request_id,
          vote: body.vote ?? 1,
        });
        return json({ success: true, item });
      }

      // ---- User feedback ----
      case "feedback.submit": {
        const item = await addItem(admin, "user_feedback", userId, {
          message: body.message,
          category: body.category ?? "general",
          rating: body.rating,
        });
        return json({ success: true, item });
      }

      // ---- Notify feature (email via Resend) ----
      case "notify.feature": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        if (resendKey) {
          await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${resendKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: "noreply@jibun.app",
              to: body.email ?? "admin@jibun.app",
              subject: body.subject ?? "新機能リクエスト",
              html: body.html ?? body.message,
            }),
          });
        }
        return json({ success: true });
      }

      // ---- Personal dashboard ----
      case "personal.dashboard": {
        const stats = await listItems(admin, "personal_stat", userId, 10);
        return json({ success: true, stats });
      }

      // ---- Development achievements ----
      case "achievements.list": {
        const period = (body.period as string) ?? "";
        let query = admin
          .from("development_achievements")
          .select("*")
          .order("completed_at", { ascending: false });
        if (period === "今週の実績") {
          const weekAgo = new Date();
          weekAgo.setDate(weekAgo.getDate() - 7);
          query = query.gte("completed_at", weekAgo.toISOString());
        }
        const { data: ach } = await query.limit(20);
        return json({ success: true, achievements: ach ?? [] });
      }

      case "achievements.add": {
        if (!body.title) return json({ error: "title required" }, 400);
        const { data, error: insertErr } = await admin
          .from("development_achievements")
          .insert({ title: String(body.title), description: body.description ?? "", completed_at: new Date().toISOString() })
          .select()
          .single();
        if (insertErr) return json({ error: insertErr.message }, 400);
        return json({ success: true, achievement: data });
      }

      // ---- Analytics summary ----
      case "analytics.summary": {
        const items = await listItems(admin, "analytics_event", userId, 100);
        return json({ success: true, total: items.length, items });
      }

      // ---- System status ----
      case "system.status": {
        return json({
          success: true,
          status: "ok",
          timestamp: new Date().toISOString(),
          version: "1.0.0",
        });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
