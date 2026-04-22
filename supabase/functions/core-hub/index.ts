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
    const serviceRoleActions = new Set(["notify.feature_request"]);
    const bearer = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    const isServiceRole = SERVICE_ROLE_KEY !== "" && bearer === SERVICE_ROLE_KEY;
    let userId = "";
    if (!(serviceRoleActions.has(action) && isServiceRole)) {
      const authed = await getUserId(req);
      if (!authed) return json({ error: "Unauthorized" }, 401);
      userId = authed;
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
            link: meta["link"] ?? "",
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
        const dedupeKey = String(body.dedupeKey ?? body.dedupe_key ?? "")
          .trim();
        if (dedupeKey) {
          const { data: existing, error: existingErr } = await admin
            .from("hub_data")
            .select("id, metadata, created_at")
            .eq("source", "notification")
            .filter("metadata->>user_id", "eq", userId)
            .filter("metadata->>dedupe_key", "eq", dedupeKey)
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (existingErr) return json({ error: existingErr.message }, 400);
          if (existing) {
            return json({ success: true, item: existing, deduped: true });
          }
        }
        const item = await addItem(admin, "notification", userId, {
          title: body.title,
          message: body.message,
          type: body.type ?? "info",
          link: body.link ?? "",
          dedupe_key: dedupeKey || undefined,
          read: false,
        });
        return json({ success: true, item });
      }

      case "notification.mark_read": {
        if (!body.id) return json({ error: "id required" }, 400);
        const { data: existing, error: fetchErr } = await admin
          .from("hub_data")
          .select("metadata")
          .eq("id", String(body.id))
          .eq("source", "notification")
          .single();
        if (fetchErr) return json({ error: fetchErr.message }, 400);
        const updatedMeta = { ...(existing?.metadata ?? {}), read: true };
        const { error: updateErr } = await admin
          .from("hub_data")
          .update({ metadata: updatedMeta })
          .eq("id", String(body.id))
          .eq("source", "notification");
        if (updateErr) return json({ error: updateErr.message }, 400);
        return json({ success: true });
      }

      case "notification.mark_all": {
        // ユーザーの全通知を既読にする
        const { data: rows, error: listErr } = await admin
          .from("hub_data")
          .select("id, metadata")
          .eq("source", "notification")
          .filter("metadata->>user_id", "eq", userId);
        if (listErr) return json({ error: listErr.message }, 400);
        for (const row of rows ?? []) {
          const meta = { ...(row.metadata as Record<string, unknown>), read: true };
          await admin.from("hub_data").update({ metadata: meta }).eq("id", row.id);
        }
        return json({ success: true, updated: (rows ?? []).length });
      }

      // ---- User profile ----
      case "user.profile": {
        const { data } = await admin
          .from("hub_data")
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

      // ---- Notify feature request (feedback resolution email) ----
      case "notify.feature_request": {
        const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
        const fromEmail = Deno.env.get("FEEDBACK_FROM_EMAIL") ??
          "自分株式会社 <noreply@resend.dev>";
        if (resendKey === "") {
          return json({ error: "Missing RESEND_API_KEY" }, 500);
        }

        const featureRequestId = String(body.id ?? "").trim();
        const appFeedbackId = Number(body.appFeedbackId ?? 0) || null;
        const requestedStatus = String(body.status ?? "").trim();
        const markAsResolved = body.markAsResolved === true;
        const resolutionSummary = String(body.resolutionSummary ?? "").trim();
        const issueNumber = Number(body.issueNumber ?? 0) || null;
        const issueTitle = String(body.issueTitle ?? "").trim();
        let issueUrl = String(body.issueUrl ?? "").trim();
        const releaseTitle = String(body.releaseTitle ?? "").trim();
        const releaseUrl = String(body.releaseUrl ?? "").trim();

        let featureRequest: Record<string, unknown> | null = null;
        let appFeedback: Record<string, unknown> | null = null;

        if (featureRequestId !== "") {
          const { data, error } = await admin
            .from("feature_requests")
            .select("id, email, title, description, status, admin_reply")
            .eq("id", featureRequestId)
            .maybeSingle();
          if (error) throw new Error(error.message);
          featureRequest = data;
        }
        if (appFeedbackId !== null) {
          const { data, error } = await admin
            .from("app_feedback")
            .select("id, category, content, user_email, status, github_issue_number, github_issue_url")
            .eq("id", appFeedbackId)
            .maybeSingle();
          if (error) throw new Error(error.message);
          appFeedback = data;
          if (issueUrl === "") {
            issueUrl = String(data?.github_issue_url ?? "");
          }
        }

        if (!featureRequest && !appFeedback) {
          return json({ error: "No matching feedback record found" }, 404);
        }

        const frStatus = (featureRequest?.status as string | null)?.trim() ?? "";
        const fbStatus = (appFeedback?.status as string | null) ?? "";
        const finalStatus = requestedStatus !== ""
          ? requestedStatus
          : markAsResolved
          ? "done"
          : frStatus !== ""
          ? frStatus
          : fbStatus === "implemented"
          ? "done"
          : fbStatus === "reviewed"
          ? "in_progress"
          : "open";

        if (featureRequest) {
          const upd: Record<string, unknown> = {
            status: finalStatus,
            admin_replied_at: new Date().toISOString(),
          };
          if (resolutionSummary !== "") {
            upd.admin_reply = resolutionSummary;
          } else if (
            markAsResolved &&
            String(featureRequest.admin_reply ?? "").trim() === ""
          ) {
            upd.admin_reply = _buildDefaultResolutionSummary(issueNumber, releaseTitle, releaseUrl);
          }
          const { error } = await admin
            .from("feature_requests")
            .update(upd)
            .eq("id", featureRequest.id);
          if (error) throw new Error(error.message);
        }

        if (appFeedback) {
          const upd: Record<string, unknown> = {
            status: finalStatus === "done" ? "implemented" : "reviewed",
          };
          if (issueNumber !== null) upd.github_issue_number = issueNumber;
          if (issueUrl !== "") upd.github_issue_url = issueUrl;
          const { error } = await admin
            .from("app_feedback")
            .update(upd)
            .eq("id", appFeedback.id);
          if (error) throw new Error(error.message);
        }

        const title = String(featureRequest?.title ?? "").trim() ||
          _buildFallbackTitle(String(appFeedback?.content ?? ""));
        const recipient = String(featureRequest?.email ?? "").trim() ||
          String(appFeedback?.user_email ?? "").trim();
        if (recipient === "") {
          return json({ error: "No recipient email on feedback" }, 400);
        }

        const description = String(featureRequest?.description ?? appFeedback?.content ?? "");
        const finalSummary = resolutionSummary !== ""
          ? resolutionSummary
          : _buildDefaultResolutionSummary(issueNumber, releaseTitle, releaseUrl);
        const html = _buildNotificationEmailHtml({
          title,
          description,
          status: finalStatus,
          resolutionSummary: finalSummary,
          issueNumber,
          issueTitle,
          issueUrl,
          releaseTitle,
          releaseUrl,
        });
        const subject = finalStatus === "done"
          ? `【自分株式会社】「${title}」への対応が完了しました`
          : finalStatus === "in_progress"
          ? `【自分株式会社】「${title}」の対応を開始しました`
          : `【自分株式会社】「${title}」の対応状況を更新しました`;

        const resendRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: fromEmail,
            to: [recipient],
            subject,
            html,
          }),
        });
        if (!resendRes.ok) {
          const errBody = await resendRes.text();
          throw new Error(`Resend API error: ${errBody}`);
        }

        return json({
          success: true,
          emailSent: true,
          sentTo: recipient,
          status: finalStatus,
          featureRequestId: (featureRequest?.id as string | null) ?? null,
          appFeedbackId: (appFeedback?.id as number | null) ?? null,
          issueNumber,
        });
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

// ---- Helpers for notify.feature_request ----
function _escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function _buildFallbackTitle(content: string): string {
  const firstLine = content.split(/\r?\n/)[0].trim();
  if (firstLine === "") return "ご意見・ご要望";
  return firstLine.length > 72 ? `${firstLine.substring(0, 72)}...` : firstLine;
}

function _buildDefaultResolutionSummary(
  issueNumber: number | null,
  releaseTitle: string,
  releaseUrl: string,
): string {
  const parts: string[] = [];
  if (issueNumber !== null) {
    parts.push(`GitHub Issue #${issueNumber} の対応を反映しました。`);
  } else {
    parts.push("ご要望への対応内容を反映しました。");
  }
  if (releaseTitle.trim() !== "") parts.push(`反映内容: ${releaseTitle}`);
  if (releaseUrl.trim() !== "") parts.push(`詳細: ${releaseUrl}`);
  return parts.join("\n");
}

function _buildNotificationEmailHtml(input: {
  title: string;
  description: string;
  status: string;
  resolutionSummary: string;
  issueNumber: number | null;
  issueTitle: string;
  issueUrl: string;
  releaseTitle: string;
  releaseUrl: string;
}): string {
  const APP_URL = "https://my-web-app-b67f4.web.app";
  const statusLabel = input.status === "done"
    ? "対応完了"
    : input.status === "in_progress"
    ? "対応中"
    : "更新";
  const issueBlock = (input.issueNumber !== null || input.issueUrl.trim() !== "")
    ? `<div style="background:#eef2ff;border-radius:12px;padding:16px;margin-top:20px;"><div style="font-size:12px;color:#4f46e5;font-weight:700;">GitHub Issue</div><div style="margin-top:6px;color:#111827;">${
      input.issueNumber !== null ? `#${input.issueNumber}` : ""
    } ${_escapeHtml(input.issueTitle)}</div>${
      input.issueUrl.trim() !== ""
        ? `<div style="margin-top:10px;"><a href="${input.issueUrl}" style="color:#4f46e5;text-decoration:none;font-weight:700;">Issue を見る</a></div>`
        : ""
    }</div>`
    : "";
  const releaseBlock = (input.releaseTitle.trim() !== "" || input.releaseUrl.trim() !== "")
    ? `<div style="background:#ecfdf5;border-radius:12px;padding:16px;margin-top:20px;"><div style="font-size:12px;color:#047857;font-weight:700;">リリース情報</div><div style="margin-top:6px;color:#111827;">${
      _escapeHtml(input.releaseTitle)
    }</div>${
      input.releaseUrl.trim() !== ""
        ? `<div style="margin-top:10px;"><a href="${input.releaseUrl}" style="color:#047857;text-decoration:none;font-weight:700;">変更内容を見る</a></div>`
        : ""
    }</div>`
    : "";
  return `<!DOCTYPE html>
<html lang="ja"><head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:24px;color:#111827;">
  <div style="background:linear-gradient(135deg,#111827,#4f46e5);padding:24px;border-radius:16px;margin-bottom:24px;">
    <h1 style="margin:0;color:#ffffff;font-size:22px;">${statusLabel}のお知らせ</h1>
    <p style="margin:10px 0 0;color:#c7d2fe;line-height:1.7;">ご意見・ご要望に関する最新状況をお知らせします。</p>
  </div>
  <h2 style="font-size:18px;margin:0 0 12px;">${_escapeHtml(input.title)}</h2>
  <div style="background:#f8fafc;border-radius:12px;padding:16px;line-height:1.8;">
    <div style="font-size:12px;color:#6b7280;">ご投稿内容</div>
    <div style="margin-top:8px;color:#374151;">${_escapeHtml(input.description).replace(/\n/g, "<br>")}</div>
  </div>
  <div style="background:#fff7ed;border-radius:12px;padding:16px;margin-top:20px;">
    <div style="font-size:12px;color:#c2410c;font-weight:700;">対応内容</div>
    <div style="margin-top:8px;color:#374151;line-height:1.8;">${
    _escapeHtml(input.resolutionSummary).replace(/\n/g, "<br>")
  }</div>
  </div>
  ${issueBlock}
  ${releaseBlock}
  <div style="margin-top:28px;text-align:center;">
    <a href="${APP_URL}" style="display:inline-block;background:#111827;color:#ffffff;padding:12px 24px;border-radius:10px;text-decoration:none;font-weight:700;">自分株式会社を開く</a>
  </div>
</body></html>`;
}
