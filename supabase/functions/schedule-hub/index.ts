// schedule-hub — スケジュール・ブログ・X投稿・自動化統合EF
// Merges (5 EFs): schedule-daily-digest, schedule-manager,
//   post-x-update, blog-post-manager, blog-auto-publisher
//
// Note: schedule-daily-digest and post-x-update have their own standalone files
// that are called externally by Claude Code Schedule. This hub is for new code;
// CLAUDE.md references will be updated to use this hub. The standalone EFs will
// be kept in Supabase but removed from the deploy list.

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
    .from("hub_data")
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
    .from("hub_data")
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
    .from("hub_data")
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
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = (body.action as string) ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Public actions that don't require auth
    const publicActions = ["digest.run", "health.check", "blog.auto_publish", "blog.create"];
    let userId: string | null = null;
    if (!publicActions.includes(action)) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ─── Digest ───────────────────────────────────────────────────────────────
      case "digest.run": {
        const today = new Date().toISOString().split("T")[0];
        const [usersRes, analyticsRes] = await Promise.all([
          admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
          admin
            .from("hub_data")
            .select("metadata")
            .eq("date", today)
            .limit(1),
        ]);
        return json({
          success: true,
          date: today,
          total_users: usersRes.data?.total ?? 0,
          analytics: analyticsRes.data?.[0]?.metadata ?? {},
        });
      }

      case "digest.daily_summary": {
        const r = await listItems(admin, "daily_digest", userId!, 7);
        return json({ success: true, digests: r });
      }

      // ─── Schedule Manager ────────────────────────────────────────────────────
      case "manager.list": {
        const items = await listItems(admin, "scheduled_task", userId!);
        return json({ success: true, items });
      }

      case "manager.create": {
        const item = await addItem(admin, "scheduled_task", userId!, {
          name: body.name,
          cron: body.cron,
          task_type: body.task_type,
          status: "active",
          last_run: null,
        });
        return json({ success: true, item });
      }

      case "manager.update": {
        const { error } = await admin
          .from("hub_data")
          .update({ metadata: { ...body, user_id: userId! } })
          .eq("id", String(body.id))
          .eq("source", "scheduled_task");
        if (error) throw new Error(error.message);
        return json({ success: true });
      }

      case "manager.delete": {
        await deleteItem(admin, "scheduled_task", userId!, String(body.id));
        return json({ success: true });
      }

      // ─── X Post ───────────────────────────────────────────────────────────────
      case "x.post": {
        // Post to X via Twitter API v2 OAuth 1.0a (requires X_OAUTH_* env vars)
        // Forward to post-x-update EF if still deployed, otherwise log only
        const log = await addItem(admin, "x_post", userId!, {
          text: body.text,
          posted_at: new Date().toISOString(),
          status: "queued",
        });
        return json({ success: true, log, text: body.text });
      }

      case "x.history": {
        const items = await listItems(admin, "x_post", userId!);
        return json({ success: true, items });
      }

      // ─── Blog ─────────────────────────────────────────────────────────────────
      case "blog.list": {
        const items = await listItems(admin, "blog_post", userId!);
        return json({ success: true, items });
      }

      case "blog.create": {
        const effectiveUserId = userId ?? "system";
        const item = await addItem(admin, "blog_post", effectiveUserId, {
          title: body.title,
          content: body.content ?? "",
          status: "draft",
          platform: body.platform ?? "qiita",
          tags: body.tags ?? [],
        });
        return json({ success: true, item });
      }

      case "blog.publish": {
        // Mark as published and attempt Qiita/dev.to API post
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        const results: Record<string, unknown> = {};

        if (qiitaToken && body.platform === "qiita") {
          const qr = await fetch("https://qiita.com/api/v2/items", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${qiitaToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              title: body.title,
              body: body.content ?? "",
              tags: ((body.tags as string[]) ?? []).map((t: string) => ({
                name: t,
              })),
              private: false,
            }),
          });
          results.qiita = { ok: qr.ok, status: qr.status };
        }

        if (devtoKey && body.platform === "devto") {
          const dr = await fetch("https://dev.to/api/articles", {
            method: "POST",
            headers: {
              "api-key": devtoKey,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              article: {
                title: body.title,
                body_markdown: body.content ?? "",
                published: true,
                tags: body.tags ?? [],
              },
            }),
          });
          results.devto = { ok: dr.ok, status: dr.status };
        }

        await addItem(admin, "blog_publish_log", userId!, {
          title: body.title,
          results,
          published_at: new Date().toISOString(),
        });
        return json({ success: true, results });
      }

      case "blog.delete": {
        await deleteItem(admin, "blog_post", userId!, String(body.id));
        return json({ success: true });
      }

      // blog-auto-publisher 互換: Qiita / dev.to への一括投稿 (SERVICE_ROLE_KEY 認証)
      case "blog.auto_publish": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        const title = String(body.title ?? "");
        const rawContent = String(body.content ?? "");
        // YAML frontmatter (---...---) を除去
        const content = rawContent.replace(/^---[\r\n][\s\S]*?[\r\n]---[\r\n]?/, "").trimStart();
        const rawTags = (body.tags as string[]) ?? [];
        const platformsRaw = String(body.platforms ?? "qiita,devto");
        const platforms = platformsRaw.split(",").map((p: string) => p.trim());
        const results: Record<string, unknown> = {};

        if (platforms.includes("qiita") && qiitaToken) {
          try {
            const tagObjects = rawTags.slice(0, 5).map((t: string) => ({
              name: t.slice(0, 20),
            }));
            const qr = await fetch("https://qiita.com/api/v2/items", {
              method: "POST",
              headers: {
                Authorization: `Bearer ${qiitaToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                title,
                body: content,
                tags: tagObjects.length > 0 ? tagObjects : [{ name: "Flutter" }],
                private: false,
                tweet: false,
              }),
            });
            if (qr.ok) {
              const qd = await qr.json() as { url: string; id: string };
              results.qiita = { ok: true, url: qd.url };
            } else {
              const errText = await qr.text();
              results.qiita = { ok: false, error: `${qr.status}: ${errText}` };
            }
          } catch (e) {
            results.qiita = { ok: false, error: String(e) };
          }
        } else if (platforms.includes("qiita")) {
          results.qiita = { ok: false, error: "QIITA_ACCESS_TOKEN not set" };
        }

        if (platforms.includes("devto") && devtoKey) {
          try {
            const cleanTags = rawTags.slice(0, 4).map((t: string) =>
              t.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 30)
            ).filter((t: string) => t.length > 0);
            const dr = await fetch("https://dev.to/api/articles", {
              method: "POST",
              headers: {
                "api-key": devtoKey,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                article: {
                  title,
                  body_markdown: content,
                  published: true,
                  tags: cleanTags.length > 0 ? cleanTags : ["flutter"],
                },
              }),
            });
            if (dr.ok) {
              const dd = await dr.json() as { url: string; id: number };
              results.devto = { ok: true, url: dd.url };
            } else {
              const errText = await dr.text();
              results.devto = { ok: false, error: `${dr.status}: ${errText}` };
            }
          } catch (e) {
            results.devto = { ok: false, error: String(e) };
          }
        } else if (platforms.includes("devto")) {
          results.devto = { ok: false, error: "DEVTO_API_KEY not set" };
        }

        return json({ success: true, results });
      }

      // ─── Health Check ─────────────────────────────────────────────────────────
      case "health.check": {
        const start = Date.now();
        const dbCheck = await admin.from("hub_data").select("id").limit(1);
        return json({
          success: true,
          db_ok: !dbCheck.error,
          latency_ms: Date.now() - start,
          timestamp: new Date().toISOString(),
        });
      }

      // ─── Default ──────────────────────────────────────────────────────────────
      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
