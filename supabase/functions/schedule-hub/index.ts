// schedule-hub — スケジュール・ブログ・X投稿・自動化統合EF
// Merges (6 EFs): schedule-daily-digest, schedule-manager, notification-center(reminders),
//   post-x-update, blog-post-manager, blog-auto-publisher
//
// Note: schedule-daily-digest and post-x-update have their own standalone files
// that are called externally by Claude Code Schedule. This hub is for new code;
// CLAUDE.md references will be updated to use this hub. The standalone EFs will
// be kept in Supabase but removed from the deploy list.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getXAccountHandle, isXConfigured, postTweet, uploadMediaFromUrl } from "../_shared/x-client.ts";

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
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = (body.action as string) ?? "";

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Public actions that don't require auth
    const publicActions = [
      "digest.run",
      "health.check",
      "blog.auto_publish",
      "blog.create",
      "reminders.study",
      "notion.sync_wbs",
      "notion.fix_wbs_all_instances",
      "wbs.unblock_dependents",
      "x.post_with_media",
    ];
    let userId: string | null = null;
    if (!publicActions.includes(action)) {
      userId = await getUserId(req);
      if (!userId) return json({ error: "Unauthorized" }, 401);
    }

    switch (action) {
      // ─── Digest ───────────────────────────────────────────────────────────────
      case "digest.run": {
        const today = new Date().toISOString().split("T")[0];
        const [usersRes, newFrRes, openFrRes, topFrRes, achievementsRes] = await Promise.all([
          admin.auth.admin.listUsers({ page: 1, perPage: 1 }),
          admin
            .from("feature_requests")
            .select("id, title, created_at")
            .gte("created_at", `${today}T00:00:00Z`)
            .order("created_at", { ascending: false })
            .limit(10),
          admin
            .from("feature_requests")
            .select("count", { count: "exact", head: true })
            .eq("status", "open"),
          admin
            .from("feature_requests")
            .select("title, votes")
            .eq("status", "open")
            .order("votes", { ascending: false })
            .limit(5),
          admin
            .from("development_achievements")
            .select("title, completed_at")
            .order("completed_at", { ascending: false })
            .limit(5),
        ]);
        return json({
          success: true,
          digest: {
            date: today,
            users: {
              total: ((usersRes.data as { total?: number } | null)?.total) ?? 0,
            },
            featureRequests: {
              newToday: newFrRes.data?.length ?? 0,
              openCount: openFrRes.count ?? 0,
              newTodayList: newFrRes.data ?? [],
              topOpen: topFrRes.data ?? [],
            },
            recentAchievements: achievementsRes.data ?? [],
          },
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
        const text = String(body.text ?? "").trim();
        const mediaUrl = String(body.mediaUrl ?? body.media_url ?? "").trim();
        const mediaType = String(body.mediaType ?? body.media_type ?? "").trim();
        const dryRun = body.dryRun === true;
        if (!text) return json({ success: false, error: "text required" }, 400);
        if (text.length > 280) {
          return json({
            success: false,
            error: "text exceeds 280 characters",
          }, 400);
        }

        const baseLog = {
          text,
          posted_at: new Date().toISOString(),
          source: body.source ?? "schedule-hub",
          media_url: mediaUrl || null,
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post", userId ?? "gha", {
            ...baseLog,
            status: dryRun ? "dry_run" : "credentials_missing",
          });
          return json({
            success: true,
            posted: false,
            dryRun,
            account: getXAccountHandle(),
            text,
            log,
            warning: dryRun ? undefined : "X API credentials are not configured in Supabase secrets.",
          });
        }

        const uploadedMedia = mediaUrl
          ? await uploadMediaFromUrl(mediaUrl, {
            mediaType: mediaType || undefined,
          })
          : null;
        const result = await postTweet({
          text,
          mediaIds: uploadedMedia ? [uploadedMedia.mediaId] : undefined,
        });
        const log = await addItem(admin, "x_post", userId!, {
          ...baseLog,
          status: "posted",
          tweet_id: result.tweetId,
          account: result.account,
          media_id: uploadedMedia?.mediaId ?? null,
          media_type: uploadedMedia?.mediaType ?? null,
        });
        return json({
          success: true,
          posted: true,
          text,
          tweetId: result.tweetId,
          account: result.account,
          log,
        });
      }

      case "x.history": {
        const items = await listItems(admin, "x_post", userId!);
        return json({ success: true, items });
      }

      case "x.post_with_media": {
        const text = String(body.text ?? "").trim();
        const mediaUrl = String(body.mediaUrl ?? "").trim();
        const dryRun = body.dryRun === true;
        if (!text) return json({ success: false, error: "text required" }, 400);
        if (text.length > 280) {
          return json({ success: false, error: "text exceeds 280 characters" }, 400);
        }
        if (!mediaUrl) return json({ success: false, error: "mediaUrl required" }, 400);

        const baseLog = {
          text,
          media_url: mediaUrl,
          posted_at: new Date().toISOString(),
          source: body.source ?? "schedule-hub",
        };

        if (dryRun || !isXConfigured()) {
          const log = await addItem(admin, "x_post", userId ?? "gha", {
            ...baseLog,
            status: dryRun ? "dry_run" : "credentials_missing",
          });
          return json({
            success: true,
            posted: false,
            dryRun,
            account: getXAccountHandle(),
            text,
            mediaUrl,
            log,
            warning: dryRun ? undefined : "X API credentials are not configured in Supabase secrets.",
          });
        }

        const mediaType = String(body.mediaType ?? "image/png");
        const mediaCategory = String(body.mediaCategory ?? "tweet_image");
        const uploadResult = await uploadMediaFromUrl(mediaUrl, { mediaType, mediaCategory });
        const result = await postTweet({ text, mediaIds: [uploadResult.mediaId] });
        const log = await addItem(admin, "x_post", userId ?? "gha", {
          ...baseLog,
          status: "posted",
          tweet_id: result.tweetId,
          account: result.account,
          media_id: uploadResult.mediaId,
        });
        return json({
          success: true,
          posted: true,
          text,
          mediaUrl,
          tweetId: result.tweetId,
          account: result.account,
          mediaId: uploadResult.mediaId,
          log,
        });
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
        const content = rawContent.replace(
          /^---[\r\n][\s\S]*?[\r\n]---[\r\n]?/,
          "",
        ).trimStart();
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
            const cleanTags = rawTags.slice(0, 4).map((t: string) => t.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 30)).filter((t: string) => t.length > 0);
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

      // ─── Blog Management: Qiita / dev.to ─────────────────────────────────────

      // blog.qiita_list — 自分の全記事一覧 (per_page最大100)
      case "blog.qiita_list": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const page = Number(body.page ?? 1);
        const perPage = Math.min(Number(body.per_page ?? 100), 100);
        const qr = await fetch(
          `https://qiita.com/api/v2/authenticated_user/items?page=${page}&per_page=${perPage}`,
          { headers: { Authorization: `Bearer ${qiitaToken}` } },
        );
        if (!qr.ok) {
          return json({ error: `Qiita ${qr.status}: ${await qr.text()}` }, 502);
        }
        const articles = await qr.json() as Array<{
          id: string;
          title: string;
          url: string;
          likes_count: number;
          comments_count: number;
          created_at: string;
          tags: Array<{ name: string }>;
        }>;
        return json({ success: true, articles, total: articles.length });
      }

      // blog.qiita_comments — 記事のコメント一覧
      case "blog.qiita_comments": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const qr = await fetch(
          `https://qiita.com/api/v2/items/${itemId}/comments`,
          { headers: { Authorization: `Bearer ${qiitaToken}` } },
        );
        if (!qr.ok) return json({ error: `Qiita ${qr.status}` }, 502);
        const comments = await qr.json() as Array<{
          id: string;
          body: string;
          rendered_body: string;
          created_at: string;
          user: { id: string; name: string; profile_image_url: string };
        }>;
        return json({ success: true, comments, item_id: itemId });
      }

      // blog.qiita_comment_post — コメントに返信 (Qiita では同記事へのコメント追加)
      case "blog.qiita_comment_post": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        const replyBody = String(body.body ?? "");
        if (!itemId || !replyBody) {
          return json({ error: "item_id and body required" }, 400);
        }
        const qr = await fetch("https://qiita.com/api/v2/comments", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${qiitaToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ item_id: itemId, body: replyBody }),
        });
        if (!qr.ok) {
          return json({ error: `Qiita ${qr.status}: ${await qr.text()}` }, 502);
        }
        const comment = await qr.json();
        return json({ success: true, comment });
      }

      // blog.qiita_likers — 記事にLGTMした人の一覧
      case "blog.qiita_likers": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const qr = await fetch(
          `https://qiita.com/api/v2/items/${itemId}/likes`,
          { headers: { Authorization: `Bearer ${qiitaToken}` } },
        );
        if (!qr.ok) return json({ error: `Qiita ${qr.status}` }, 502);
        const likers = await qr.json() as Array<
          { user: { id: string; name: string; profile_image_url: string } }
        >;
        return json({ success: true, likers, item_id: itemId });
      }

      // blog.qiita_follow — ユーザーをフォロー
      case "blog.qiita_follow": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const userId = String(body.user_id ?? "");
        if (!userId) return json({ error: "user_id required" }, 400);
        const qr = await fetch(
          `https://qiita.com/api/v2/users/${userId}/following`,
          {
            method: "PUT",
            headers: { Authorization: `Bearer ${qiitaToken}` },
          },
        );
        // 204 No Content = success
        const ok = qr.status === 204 || qr.ok;
        return json({ success: ok, status: qr.status, user_id: userId });
      }

      // blog.qiita_delete — 記事を削除
      case "blog.qiita_delete": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const qr = await fetch(
          `https://qiita.com/api/v2/items/${itemId}`,
          {
            method: "DELETE",
            headers: { Authorization: `Bearer ${qiitaToken}` },
          },
        );
        return json({
          success: qr.status === 204,
          status: qr.status,
          item_id: itemId,
        });
      }

      // blog.qiita_update — 記事を更新 (内容訂正)
      case "blog.qiita_update": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const itemId = String(body.item_id ?? "");
        if (!itemId) return json({ error: "item_id required" }, 400);
        const patchBody: Record<string, unknown> = {};
        if (body.title) patchBody.title = String(body.title);
        if (body.body) patchBody.body = String(body.body);
        if (body.tags) {
          patchBody.tags = (body.tags as string[]).map((t: string) => ({
            name: t,
          }));
        }
        const qr = await fetch(
          `https://qiita.com/api/v2/items/${itemId}`,
          {
            method: "PATCH",
            headers: {
              Authorization: `Bearer ${qiitaToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(patchBody),
          },
        );
        if (!qr.ok) {
          return json({ error: `Qiita ${qr.status}: ${await qr.text()}` }, 502);
        }
        const updated = await qr.json() as {
          id: string;
          url: string;
          title: string;
        };
        return json({
          success: true,
          item: { id: updated.id, url: updated.url, title: updated.title },
        });
      }

      // blog.devto_list — dev.to 全記事一覧
      case "blog.devto_list": {
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        if (!devtoKey) return json({ error: "DEVTO_API_KEY not set" }, 500);
        const page = Number(body.page ?? 1);
        const perPage = Math.min(Number(body.per_page ?? 100), 1000);
        const dr = await fetch(
          `https://dev.to/api/articles/me?page=${page}&per_page=${perPage}`,
          { headers: { "api-key": devtoKey } },
        );
        if (!dr.ok) {
          return json(
            { error: `dev.to ${dr.status}: ${await dr.text()}` },
            502,
          );
        }
        const articles = await dr.json() as Array<{
          id: number;
          title: string;
          url: string;
          public_reactions_count: number;
          comments_count: number;
          published_at: string;
          tag_list: string[];
        }>;
        return json({ success: true, articles, total: articles.length });
      }

      // blog.sync_engagement — Qiita 全記事の likes/comments/likers を DB に同期
      // body: { auto_reply?: bool, auto_follow?: bool, reply_template?: string }
      case "blog.sync_engagement": {
        const qiitaToken = Deno.env.get("QIITA_ACCESS_TOKEN") ?? "";
        if (!qiitaToken) {
          return json({ error: "QIITA_ACCESS_TOKEN not set" }, 500);
        }
        const autoReply = Boolean(body.auto_reply);
        const autoFollow = Boolean(body.auto_follow);
        const replyTemplate = String(
          body.reply_template ??
            "コメントありがとうございます！参考になれば幸いです。",
        );

        // 1. 全記事取得
        const articlesRes = await fetch(
          "https://qiita.com/api/v2/authenticated_user/items?page=1&per_page=100",
          { headers: { Authorization: `Bearer ${qiitaToken}` } },
        );
        if (!articlesRes.ok) {
          return json({ error: `Qiita list: ${articlesRes.status}` }, 502);
        }
        const articles = await articlesRes.json() as Array<{
          id: string;
          title: string;
          url: string;
          likes_count: number;
          comments_count: number;
          page_views_count: number;
        }>;

        // 2. blog_engagement に UPSERT
        const engRows = articles.map((a) => ({
          platform: "qiita",
          article_id: a.id,
          title: a.title,
          url: a.url,
          likes_count: a.likes_count,
          comments_count: a.comments_count,
          views_count: a.page_views_count ?? 0,
          updated_at: new Date().toISOString(),
        }));
        await admin.from("blog_engagement").upsert(engRows, {
          onConflict: "platform,article_id",
        });

        let totalComments = 0, repliedCount = 0;
        let totalLikers = 0, followedCount = 0;

        // 3. 各記事のコメント・ライカーを取得
        for (const article of articles) {
          // comments
          if (article.comments_count > 0) {
            const cr = await fetch(
              `https://qiita.com/api/v2/items/${article.id}/comments`,
              { headers: { Authorization: `Bearer ${qiitaToken}` } },
            );
            if (cr.ok) {
              const comments = await cr.json() as Array<{
                id: string;
                body: string;
                created_at: string;
                user: { id: string };
              }>;
              totalComments += comments.length;
              for (const c of comments) {
                // DB に upsert (既存は上書きしない → on conflict do nothing)
                const { data: existing } = await admin
                  .from("blog_comments")
                  .select("replied")
                  .eq("platform", "qiita")
                  .eq("comment_id", c.id)
                  .single();

                const alreadyReplied = (existing as { replied?: boolean } | null)?.replied === true;
                await admin.from("blog_comments").upsert({
                  platform: "qiita",
                  article_id: article.id,
                  comment_id: c.id,
                  author: c.user.id,
                  body: c.body.replace(/<[^>]+>/g, ""),
                  created_at: c.created_at,
                  fetched_at: new Date().toISOString(),
                  replied: alreadyReplied,
                }, {
                  onConflict: "platform,comment_id",
                  ignoreDuplicates: true,
                });

                // auto-reply
                if (autoReply && !alreadyReplied) {
                  const rr = await fetch("https://qiita.com/api/v2/comments", {
                    method: "POST",
                    headers: {
                      Authorization: `Bearer ${qiitaToken}`,
                      "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                      item_id: article.id,
                      body: replyTemplate,
                    }),
                  });
                  if (rr.ok) {
                    await admin.from("blog_comments")
                      .update({
                        replied: true,
                        reply_text: replyTemplate,
                        replied_at: new Date().toISOString(),
                      })
                      .eq("platform", "qiita")
                      .eq("comment_id", c.id);
                    repliedCount++;
                  }
                }
              }
            }
          }

          // likers (LGTM)
          if (article.likes_count > 0) {
            const lr = await fetch(
              `https://qiita.com/api/v2/items/${article.id}/likes`,
              { headers: { Authorization: `Bearer ${qiitaToken}` } },
            );
            if (lr.ok) {
              const likers = await lr.json() as Array<
                { user: { id: string; name: string } }
              >;
              totalLikers += likers.length;
              for (const liker of likers) {
                const uid = liker.user.id;
                const { data: existingLiker } = await admin
                  .from("blog_likers")
                  .select("followed")
                  .eq("article_id", article.id)
                  .eq("qiita_user_id", uid)
                  .single();

                const alreadyFollowed = (existingLiker as { followed?: boolean } | null)?.followed ===
                  true;
                await admin.from("blog_likers").upsert({
                  article_id: article.id,
                  qiita_user_id: uid,
                  username: liker.user.name,
                  followed: alreadyFollowed,
                  fetched_at: new Date().toISOString(),
                }, {
                  onConflict: "article_id,qiita_user_id",
                  ignoreDuplicates: true,
                });

                // auto-follow
                if (autoFollow && !alreadyFollowed) {
                  const fr = await fetch(
                    `https://qiita.com/api/v2/users/${uid}/following`,
                    {
                      method: "PUT",
                      headers: { Authorization: `Bearer ${qiitaToken}` },
                    },
                  );
                  if (fr.status === 204 || fr.ok) {
                    await admin.from("blog_likers")
                      .update({
                        followed: true,
                        followed_at: new Date().toISOString(),
                      })
                      .eq("article_id", article.id)
                      .eq("qiita_user_id", uid);
                    followedCount++;
                  }
                }
              }
            }
          }
        }

        return json({
          success: true,
          articles_synced: articles.length,
          total_comments: totalComments,
          replied: repliedCount,
          total_likers: totalLikers,
          followed: followedCount,
          auto_reply: autoReply,
          auto_follow: autoFollow,
        });
      }

      // blog.devto_delete — dev.to 記事を削除 (unpublish)
      case "blog.devto_delete": {
        const devtoKey = Deno.env.get("DEVTO_API_KEY") ?? "";
        if (!devtoKey) return json({ error: "DEVTO_API_KEY not set" }, 500);
        const articleId = Number(body.article_id);
        if (!articleId) return json({ error: "article_id required" }, 400);
        // dev.to は物理削除不可 → unpublish で対応
        const dr = await fetch(`https://dev.to/api/articles/${articleId}`, {
          method: "PUT",
          headers: { "api-key": devtoKey, "Content-Type": "application/json" },
          body: JSON.stringify({ article: { published: false } }),
        });
        return json({
          success: dr.ok,
          status: dr.status,
          article_id: articleId,
        });
      }

      // ─── Study Reminders (AI大学 学習リマインダー) ────────────────────────────
      case "reminders.study": {
        // service_role authorization check
        const authHeader = req.headers.get("Authorization");
        const svcToken = authHeader?.replace("Bearer ", "") ?? "";
        if (svcToken !== SERVICE_ROLE_KEY) {
          return json({ error: "Service role required" }, 403);
        }

        const minIdleDays = typeof body.min_idle_days === "number" ? Math.max(1, Math.min(30, body.min_idle_days as number)) : 3;
        const maxIdleDays = typeof body.max_idle_days === "number" ? Math.max(minIdleDays, Math.min(90, body.max_idle_days as number)) : 30;
        const dryRun = Boolean(body.dry_run);

        const nowJst = new Date(Date.now() + 9 * 60 * 60 * 1000);
        const todayStr = nowJst.toISOString().slice(0, 10);
        const minDate = new Date(nowJst.getTime() - maxIdleDays * 86_400_000)
          .toISOString().slice(0, 10);
        const maxDate = new Date(nowJst.getTime() - minIdleDays * 86_400_000)
          .toISOString().slice(0, 10);

        const { data: streakRows, error: streakErr } = await admin
          .from("ai_university_streaks")
          .select("user_id, current_streak, longest_streak, last_studied_date")
          .gte("last_studied_date", minDate)
          .lte("last_studied_date", maxDate);

        if (streakErr) throw streakErr;

        const candidates = streakRows ?? [];
        if (candidates.length === 0) {
          return json({
            success: true,
            eligible: 0,
            sent: 0,
            skipped_recently_reminded: 0,
            dry_run: dryRun,
            today: todayStr,
            window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
          });
        }

        const REMINDER_PREFIX = "[AI大学] 学習リマインダー";
        const reminderSinceIso = new Date(
          Date.now() - minIdleDays * 86_400_000,
        ).toISOString();

        const userIds = candidates.map((r) => (r as { user_id: string }).user_id);

        const { data: recentRows, error: recentErr } = await admin
          .from("app_notifications")
          .select("user_id")
          .in("user_id", userIds)
          .eq("type", "system")
          .ilike("title", `${REMINDER_PREFIX}%`)
          .gte("created_at", reminderSinceIso);

        if (recentErr) throw recentErr;

        const recentlyReminded = new Set<string>();
        for (const row of recentRows ?? []) {
          const uid = (row as { user_id: string | null }).user_id;
          if (typeof uid === "string") recentlyReminded.add(uid);
        }

        const targets = candidates.filter((r) => {
          const uid = (r as { user_id: string }).user_id;
          return !recentlyReminded.has(uid);
        });

        if (targets.length === 0 || dryRun) {
          return json({
            success: true,
            eligible: candidates.length,
            sent: 0,
            skipped_recently_reminded: recentlyReminded.size,
            targets: dryRun ? targets.length : undefined,
            dry_run: dryRun,
            today: todayStr,
            window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
          });
        }

        const createdAt = new Date().toISOString();
        const payload = targets.map((row) => {
          const r = row as {
            user_id: string;
            current_streak: number;
            longest_streak: number;
            last_studied_date: string;
          };
          const idleDays = Math.max(
            0,
            Math.floor(
              (Date.parse(todayStr) - Date.parse(r.last_studied_date)) /
                86_400_000,
            ),
          );
          const bestStreak = Math.max(r.current_streak, r.longest_streak);
          const title = `${REMINDER_PREFIX} — ${idleDays}日ぶりにAIを学ぼう`;
          const message = bestStreak > 1 ? `前回の学習から${idleDays}日経過。過去最長 ${bestStreak} 日連続を更新しよう！１分クイズでストリーク復活。` : `前回の学習から${idleDays}日経過。AI大学で１分クイズに挑戦して知識をアップデート。`;
          return {
            user_id: r.user_id,
            title,
            message,
            type: "system",
            link: "/ai-university",
            is_read: false,
            created_at: createdAt,
          };
        });

        const { error: insertErr } = await admin
          .from("app_notifications")
          .insert(payload);

        if (insertErr) throw insertErr;

        return json({
          success: true,
          eligible: candidates.length,
          sent: payload.length,
          skipped_recently_reminded: recentlyReminded.size,
          dry_run: false,
          today: todayStr,
          window: { min_idle_days: minIdleDays, max_idle_days: maxIdleDays },
        });
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

      // ─── Notion Sync (Multi-AI resilience / Win#132 part 6 · Backlog N2) ────
      // Win版#132 part 4 設計の N2 実装。Supabase wbs_tasks → Notion Database
      // upsert (last_edited 順で最新 500 件)。Anthropic outage 時もユーザーが
      // Notion mirror で WBS を閲覧できる = SPOF 解消。
      // Auth: service_role (public action / GHA cron から呼ぶ想定)
      // Secrets: NOTION_API_TOKEN / NOTION_WBS_DATABASE_ID
      case "notion.sync_wbs": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const dbId = Deno.env.get("NOTION_WBS_DATABASE_ID");
        if (!token || !dbId) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token ? "NOTION_API_TOKEN" : "NOTION_WBS_DATABASE_ID",
            },
            503,
          );
        }

        // Supabase 側から最新 WBS (last_edited 順 30 件) を取得
        // 30件 × ~150ms/task ≈ 4.5s sleep + HTTP = ~30s 合計 (Supabase 150s limit に余裕)
        // 毎時 cron で 30件ずつローリング sync → 141件 ≒ 5h で全件完了
        const limitN = Math.min(Math.max(Number(body.limit ?? 30), 1), 50);
        const offsetN = Math.max(Number(body.offset ?? 0), 0);
        const delayMs = Math.min(Math.max(Number(body.delay_ms ?? 750), 350), 2000);
        const rangeTo = offsetN + limitN - 1;
        const { data: tasks, error: fetchErr } = await admin
          .from("wbs_tasks")
          .select("id, title, instance, status, progress, end_date, updated_at")
          .order("updated_at", { ascending: false })
          .order("id", { ascending: true })
          .range(offsetN, rangeTo);

        if (fetchErr) {
          return json({
            success: false,
            error: `supabase_fetch_failed: ${fetchErr.message}`,
          }, 500);
        }

        // Notion Database に upsert 相当 (id で検索 → 存在すれば patch / 無ければ create)
        let created = 0;
        let updated = 0;
        let failed = 0;
        const errors: string[] = [];

        // Notion select property options (DB schema の options と一致必須)
        // mismatch 値は default にフォールバック (400 error 回避)
        // 2026-04-25 Win#132 part 16: 'all' 廃止 / 'codex' 追加
        // ('schedule' / 'gha' は CHECK 上は有効だが Notion options 未登録のため
        //  fallback で 'win' に振り分け)
        const VALID_INSTANCES = new Set([
          "vscode",
          "win",
          "ps1",
          "ps2",
          "ps3",
          "ps4",
          "ps5",
          "ps6",
          "web",
          "mobile",
          "schedule",
          "gha",
          "codex",
          "gemini",
          "co-pilot",
          "user",
        ]);
        const VALID_STATUSES = new Set([
          "pending",
          "in_progress",
          "completed",
          "blocked",
        ]);
        const normalizeInstance = (v: unknown): string => {
          const s = String(v ?? "win").trim();
          // alias: legacy 'all' は Codex に寄せ、実行系の schedule/gha は維持する
          if (s === "all") return "codex";
          if (s === "copilot" || s === "github-copilot") return "co-pilot";
          return VALID_INSTANCES.has(s) ? s : "win";
        };
        const normalizeStatus = (v: unknown): string => {
          const s = String(v ?? "pending").trim();
          // alias: Supabase 側が "in-progress" / "not_started" を使うケースを吸収
          if (s === "in-progress") return "in_progress";
          if (s === "not_started" || s === "draft") return "pending";
          if (s === "done") return "completed";
          return VALID_STATUSES.has(s) ? s : "pending";
        };

        for (const t of tasks ?? []) {
          // Notion DB 側: id = Title-type (内部 ID "title") / task_title = rich_text
          //
          // 重要: Notion は Title-type property の内部 ID を常に "title" に固定する
          // 仕様。user の DB で Title 名が "id" でも、内部 ID "title" と重複する
          // ため、rich_text property に "title" という名前を付けると
          // "title is expected to be title" validation_error が出る。
          // → rich_text property は task_title にリネーム済 (user 手動)。
          //
          // null 値の property は omit (Notion API は `{date: null}` を受けるが
          // 他の type では 400 になるため全て conditional 構築)
          const properties: Record<string, unknown> = {
            id: { title: [{ text: { content: String(t.id) } }] },
            task_title: {
              rich_text: [{ text: { content: String(t.title ?? "") } }],
            },
            instance: { select: { name: normalizeInstance(t.instance) } },
            status: { select: { name: normalizeStatus(t.status) } },
            progress: { number: Number(t.progress ?? 0) },
          };
          if (t.end_date) {
            properties.deadline = { date: { start: String(t.end_date) } };
          }
          if (t.updated_at) {
            properties.updated_at = { date: { start: String(t.updated_at) } };
          }

          try {
            // 既存 page を id (Title) で検索
            const queryResp = await fetch(
              `https://api.notion.com/v1/databases/${dbId}/query`,
              {
                method: "POST",
                headers: {
                  "Authorization": `Bearer ${token}`,
                  "Notion-Version": "2022-06-28",
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  filter: { property: "id", title: { equals: String(t.id) } },
                  page_size: 1,
                }),
              },
            );

            if (!queryResp.ok) {
              failed++;
              const eb = await queryResp.text().catch(() => "");
              errors.push(
                `query ${t.id}: HTTP ${queryResp.status} ${eb.slice(0, 150)}`,
              );
              continue;
            }

            const queryJson = await queryResp.json();
            const existingPageId = queryJson?.results?.[0]?.id;

            if (existingPageId) {
              // patch
              const patchResp = await fetch(
                `https://api.notion.com/v1/pages/${existingPageId}`,
                {
                  method: "PATCH",
                  headers: {
                    "Authorization": `Bearer ${token}`,
                    "Notion-Version": "2022-06-28",
                    "Content-Type": "application/json",
                  },
                  body: JSON.stringify({ properties }),
                },
              );
              if (patchResp.ok) updated++;
              else {
                failed++;
                const eb = await patchResp.text().catch(() => "");
                errors.push(
                  `patch ${t.id}: HTTP ${patchResp.status} ${eb.slice(0, 200)}`,
                );
              }
            } else {
              // create
              const createResp = await fetch(
                `https://api.notion.com/v1/pages`,
                {
                  method: "POST",
                  headers: {
                    "Authorization": `Bearer ${token}`,
                    "Notion-Version": "2022-06-28",
                    "Content-Type": "application/json",
                  },
                  body: JSON.stringify({
                    parent: { database_id: dbId },
                    properties,
                  }),
                },
              );
              if (createResp.ok) created++;
              else {
                failed++;
                const eb = await createResp.text().catch(() => "");
                errors.push(
                  `create ${t.id}: HTTP ${createResp.status} ${eb.slice(0, 200)}`,
                );
              }
            }

            // Notion rate limit 対策 (3 req/sec → 150ms interval = 6.7 req/sec で余裕)
            await new Promise((r) => setTimeout(r, delayMs));
          } catch (e) {
            failed++;
            errors.push(`${t.id}: ${String(e)}`);
          }
        }

        return json({
          success: failed === 0,
          total: tasks?.length ?? 0,
          limit: limitN,
          offset: offsetN,
          delay_ms: delayMs,
          created,
          updated,
          failed,
          errors: errors.slice(0, 10), // 最初の 10 件のみ返す
        });
      }

      // ─── Notion WBS Mirror Repair ───
      case "notion.fix_wbs_all_instances": {
        const token = Deno.env.get("NOTION_API_TOKEN");
        const dbId = Deno.env.get("NOTION_WBS_DATABASE_ID");
        if (!token || !dbId) {
          return json(
            {
              success: false,
              error: "notion_not_configured",
              missing: !token ? "NOTION_API_TOKEN" : "NOTION_WBS_DATABASE_ID",
            },
            503,
          );
        }

        const notionHeaders = {
          "Authorization": `Bearer ${token}`,
          "Notion-Version": "2022-06-28",
          "Content-Type": "application/json",
        };
        const validInstances = new Set([
          "codex",
          "gemini",
          "co-pilot",
          "vscode",
          "win",
          "ps1",
          "ps2",
          "ps3",
          "ps4",
          "ps5",
          "ps6",
          "web",
          "mobile",
          "schedule",
          "gha",
          "user",
        ]);
        const normalizeInstance = (v: unknown): string => {
          const s = String(v ?? "codex").trim();
          if (s === "all") return "codex";
          if (s === "copilot" || s === "github-copilot") return "co-pilot";
          return validInstances.has(s) ? s : "codex";
        };
        const normalizeStatus = (v: unknown): string => {
          const s = String(v ?? "pending").trim();
          if (s === "in-progress") return "in_progress";
          if (s === "not_started" || s === "draft") return "pending";
          if (s === "done") return "completed";
          return ["pending", "in_progress", "completed", "blocked"].includes(s)
            ? s
            : "pending";
        };

        const maxPages = Math.min(Math.max(Number(body.max_pages ?? 40), 1), 80);
        const pages: Record<string, unknown>[] = [];
        let cursor: string | null = null;
        for (let i = 0; i < 10; i++) {
          const pageSize = Math.min(maxPages - pages.length, 100);
          if (pageSize <= 0) break;
          const queryResp: Response = await fetch(
            `https://api.notion.com/v1/databases/${dbId}/query`,
            {
              method: "POST",
              headers: notionHeaders,
              body: JSON.stringify({
                filter: { property: "instance", select: { equals: "all" } },
                page_size: pageSize,
                ...(cursor ? { start_cursor: cursor } : {}),
              }),
            },
          );
          if (!queryResp.ok) {
            const text = await queryResp.text().catch(() => "");
            return json({
              success: false,
              error: `notion_query_failed: HTTP ${queryResp.status}`,
              details: text.slice(0, 300),
            }, 502);
          }
          const queryJson = await queryResp.json() as {
            results?: Record<string, unknown>[];
            has_more?: boolean;
            next_cursor?: string | null;
          };
          pages.push(...(queryJson.results ?? []));
          if (pages.length >= maxPages) break;
          if (!queryJson.has_more || !queryJson.next_cursor) break;
          cursor = queryJson.next_cursor;
        }

        const pageIdByTaskId = new Map<string, string>();
        for (const page of pages) {
          const props = (page.properties ?? {}) as Record<string, unknown>;
          const idProp = (props.id ?? {}) as Record<string, unknown>;
          const titleItems = (idProp.title ?? []) as Record<string, unknown>[];
          const taskId = String(
            titleItems[0]?.plain_text ??
              ((titleItems[0]?.text as Record<string, unknown> | undefined)?.content) ??
              "",
          ).trim();
          if (taskId && page.id) pageIdByTaskId.set(taskId, String(page.id));
        }

        const taskIds = Array.from(pageIdByTaskId.keys());
        const tasksById = new Map<string, Record<string, unknown>>();
        if (taskIds.length > 0) {
          const { data: tasks, error: tasksErr } = await admin
            .from("wbs_tasks")
            .select("id, title, instance, status, progress, end_date, updated_at")
            .in("id", taskIds);
          if (tasksErr) {
            return json({
              success: false,
              error: `supabase_fetch_failed: ${tasksErr.message}`,
            }, 500);
          }
          for (const task of tasks ?? []) {
            tasksById.set(String(task.id), task as Record<string, unknown>);
          }
        }

        let updated = 0;
        let missing = 0;
        let failed = 0;
        const errors: string[] = [];
        const delayMs = Math.min(Math.max(Number(body.delay_ms ?? 900), 500), 2500);

        for (const [taskId, pageId] of pageIdByTaskId.entries()) {
          const task = tasksById.get(taskId);
          if (!task) missing++;
          const properties: Record<string, unknown> = {
            instance: { select: { name: normalizeInstance(task?.instance ?? "codex") } },
          };
          if (task) {
            properties.task_title = {
              rich_text: [{ text: { content: String(task.title ?? "") } }],
            };
            properties.status = { select: { name: normalizeStatus(task.status) } };
            properties.progress = { number: Number(task.progress ?? 0) };
            if (task.end_date) {
              properties.deadline = { date: { start: String(task.end_date) } };
            }
            if (task.updated_at) {
              properties.updated_at = { date: { start: String(task.updated_at) } };
            }
          }

          const patchResp = await fetch(`https://api.notion.com/v1/pages/${pageId}`, {
            method: "PATCH",
            headers: notionHeaders,
            body: JSON.stringify({ properties }),
          });
          if (patchResp.ok) {
            updated++;
          } else {
            failed++;
            const text = await patchResp.text().catch(() => "");
            errors.push(`patch ${taskId}: HTTP ${patchResp.status} ${text.slice(0, 180)}`);
          }
          await new Promise((r) => setTimeout(r, delayMs));
        }

        const verifyResp = await fetch(
          `https://api.notion.com/v1/databases/${dbId}/query`,
          {
            method: "POST",
            headers: notionHeaders,
            body: JSON.stringify({
              filter: { property: "instance", select: { equals: "all" } },
              page_size: 1,
            }),
          },
        );
        let remainingAll: number | null = null;
        if (verifyResp.ok) {
          const verifyJson = await verifyResp.json();
          remainingAll = Number(verifyJson.results?.length ?? 0);
          if (verifyJson.has_more) remainingAll = -1;
        }

        return json({
          success: failed === 0,
          max_pages: maxPages,
          found_all_pages: pages.length,
          matched_task_ids: taskIds.length,
          updated,
          missing,
          failed,
          remaining_all_sample_count: remainingAll,
          errors: errors.slice(0, 10),
        });
      }

      // ─── WBS Unblock Dependents (Win版#132 part 12 / wbs-ai-review.yml 補完) ───
      // pending かつ depends_on の全要素が completed の task を in_progress に遷移。
      // Public action (GHA cron から呼ぶ) / service_role で raw SQL 相当の logic を実行。
      // 設計: docs/BUSINESS_WBS_AI_AUTOMATION.md (Phase 2 unblock loop)
      case "wbs.unblock_dependents": {
        // 全 pending task を fetch (depends_on を含む)
        const { data: pending, error: pendingErr } = await admin
          .from("wbs_tasks")
          .select("id, depends_on")
          .eq("status", "pending")
          .not("depends_on", "is", null);

        if (pendingErr) {
          return json({
            success: false,
            error: `fetch_pending_failed: ${pendingErr.message}`,
          }, 500);
        }

        // 全 completed task の id set を取得
        const { data: completed, error: completedErr } = await admin
          .from("wbs_tasks")
          .select("id")
          .eq("status", "completed");

        if (completedErr) {
          return json({
            success: false,
            error: `fetch_completed_failed: ${completedErr.message}`,
          }, 500);
        }

        const completedSet = new Set((completed ?? []).map((c) => c.id));

        // depends_on の全要素が completed の task を unblock
        const unblockable: string[] = [];
        for (const t of pending ?? []) {
          const deps = (t.depends_on ?? []) as string[];
          if (deps.length === 0) continue; // depends_on 空 = ここでは触らない
          const allCompleted = deps.every((d) => completedSet.has(d));
          if (allCompleted) unblockable.push(t.id);
        }

        // bulk update
        let unblocked = 0;
        if (unblockable.length > 0) {
          const { error: updErr } = await admin
            .from("wbs_tasks")
            .update({ status: "in_progress" })
            .in("id", unblockable);
          if (updErr) {
            return json({
              success: false,
              error: `update_failed: ${updErr.message}`,
            }, 500);
          }
          unblocked = unblockable.length;
        }

        return json({
          success: true,
          checked: pending?.length ?? 0,
          unblocked,
          ids: unblockable.slice(0, 20),
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
