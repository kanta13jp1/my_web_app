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

function textValue(value: unknown, maxLength = 4000): string {
  return String(value ?? "").trim().slice(0, maxLength);
}

function normalizePriority(value: unknown): "high" | "medium" | "low" {
  const priority = textValue(value, 20).toLowerCase();
  return priority === "high" || priority === "low" ? priority : "medium";
}

function estimateFeatureRequestHours(priority: "high" | "medium" | "low"): number {
  if (priority === "high") return 6;
  if (priority === "low") return 2;
  return 4;
}

async function getUserEmail(
  admin: SupabaseClient,
  userId: string,
): Promise<string> {
  try {
    const { data } = await admin.auth.admin.getUserById(userId);
    return data.user?.email ?? "";
  } catch {
    return "";
  }
}

function buildFeatureRequestBody(params: {
  title: string;
  description: string;
  expectedOutcome: string;
  category: string;
  priority: string;
  userId: string;
  userEmail: string;
  createdAt: string;
}): string {
  const lines = [
    "Home画面の追加要望フォームから登録されました。",
    "",
    "## 要望",
    params.description,
    "",
    "## 期待する成果",
    params.expectedOutcome || "未入力",
    "",
    "## 分類",
    `- カテゴリ: ${params.category}`,
    `- 優先度: ${params.priority}`,
    `- 登録者: ${params.userEmail || params.userId}`,
    `- 登録日時: ${params.createdAt}`,
    "",
    "## WBS連携",
    "このIssue作成後、同じ内容をWBSのユーザー要望タスクとして登録します。",
  ];
  return lines.join("\n");
}

async function createGitHubIssue(params: {
  title: string;
  body: string;
}): Promise<Record<string, unknown>> {
  const token = Deno.env.get("GITHUB_PAT") ??
    Deno.env.get("GITHUB_TOKEN") ??
    Deno.env.get("GH_TOKEN") ??
    "";
  const repo = Deno.env.get("GITHUB_REPO") ??
    Deno.env.get("GITHUB_REPOSITORY") ??
    "kanta13jp1/my_web_app";

  if (token === "" || repo === "") {
    return {
      skipped: true,
      error: "GitHub token or repository is not configured",
    };
  }

  const res = await fetch(`https://api.github.com/repos/${repo}/issues`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "jibun-app-feature-request-form",
    },
    body: JSON.stringify({
      title: `[追加要望] ${params.title}`,
      body: params.body,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      skipped: false,
      status: res.status,
      error: String((data as Record<string, unknown>).message ?? "GitHub API error"),
    };
  }
  const issue = data as Record<string, unknown>;
  return {
    number: issue.number,
    html_url: issue.html_url,
    title: issue.title,
  };
}

async function createFeatureRequestWbsTask(
  admin: SupabaseClient,
  params: {
    title: string;
    description: string;
    expectedOutcome: string;
    category: string;
    priority: "high" | "medium" | "low";
    issueUrl: string;
    issueNumber: number | null;
  },
): Promise<Record<string, unknown>> {
  const issueLine = params.issueUrl
    ? `GitHub Issue: ${params.issueUrl}`
    : "GitHub Issue: creation skipped or failed. Check core-hub response metadata.";
  const descriptionLines = [
    params.description,
    "",
    `カテゴリ: ${params.category}`,
    `期待する成果: ${params.expectedOutcome || "未入力"}`,
    issueLine,
  ];

  const { data, error } = await admin.from("wbs_tasks").insert({
    category: "ユーザー要望",
    category_icon: "REQ",
    category_order: 90,
    title: `[追加要望] ${params.title}`,
    description: descriptionLines.join("\n"),
    instance: "vscode",
    owner_instance: "vscode",
    status: "pending",
    progress: 0,
    milestone_code: "beta",
    priority: params.priority,
    remaining_work: issueLine,
    recovery_plan:
      "追加要望フォームから自動登録。Issue内容を確認し、優先度と担当をWBS上で調整する。",
    estimated_hours: estimateFeatureRequestHours(params.priority),
  }).select("id, title, status, owner_instance").single();
  if (error) {
    return { error: error.message };
  }
  return { ...data, github_issue_number: params.issueNumber };
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

      case "feature_request.submit": {
        const title = textValue(body.title, 120);
        const description = textValue(body.description, 4000);
        const expectedOutcome = textValue(
          body.expected_outcome ?? body.expectedOutcome,
          1000,
        );
        const category = textValue(body.category, 80) || "機能追加";
        const priority = normalizePriority(body.priority);
        if (title.length < 3) {
          return json({ error: "title must be at least 3 characters" }, 400);
        }
        if (description.length < 10) {
          return json({ error: "description must be at least 10 characters" }, 400);
        }

        const createdAt = new Date().toISOString();
        const userEmail = await getUserEmail(admin, userId);
        const issueBody = buildFeatureRequestBody({
          title,
          description,
          expectedOutcome,
          category,
          priority,
          userId,
          userEmail,
          createdAt,
        });
        const githubIssue = await createGitHubIssue({
          title,
          body: issueBody,
        });
        const issueUrl = textValue(githubIssue.html_url, 400);
        const issueNumber = Number(githubIssue.number ?? 0) || null;

        const wbsTask = await createFeatureRequestWbsTask(admin, {
          title,
          description,
          expectedOutcome,
          category,
          priority,
          issueUrl,
          issueNumber,
        });

        let publicFeatureRequest: Record<string, unknown> | null = null;
        let publicFeatureRequestError = "";
        const publicInsert = await admin.from("feature_requests").insert({
          user_id: userId,
          email: userEmail || null,
          title,
          description,
          votes: 1,
          status: "open",
        }).select("id, title, status").single();
        if (publicInsert.error) {
          const retry = await admin.from("feature_requests").insert({
            email: userEmail || null,
            title,
            description,
            votes: 1,
            status: "open",
          }).select("id, title, status").single();
          if (retry.error) {
            publicFeatureRequestError = retry.error.message;
          } else {
            publicFeatureRequest = retry.data;
          }
        } else {
          publicFeatureRequest = publicInsert.data;
        }

        let appFeedback: Record<string, unknown> | null = null;
        let appFeedbackError = "";
        const feedbackInsert = await admin.from("app_feedback").insert({
          user_id: userId,
          category: "feature",
          content: issueBody,
          status: "new",
          github_issue_number: issueNumber,
          github_issue_url: issueUrl || null,
          user_email: userEmail || null,
        }).select("id, status, github_issue_number, github_issue_url").single();
        if (feedbackInsert.error) {
          appFeedbackError = feedbackInsert.error.message;
        } else {
          appFeedback = feedbackInsert.data;
        }

        const item = await addItem(admin, "feature_request_user", userId, {
          title,
          description,
          expected_outcome: expectedOutcome,
          category,
          priority,
          status: "open",
          source: "home_feature_request_form",
          created_at: createdAt,
          github_issue: githubIssue,
          wbs_task: wbsTask,
          feature_request: publicFeatureRequest,
          feature_request_error: publicFeatureRequestError || undefined,
          app_feedback: appFeedback,
          app_feedback_error: appFeedbackError || undefined,
        });

        const issueCreated = issueUrl !== "";
        const wbsCreated = !("error" in wbsTask);
        return json({
          success: issueCreated && wbsCreated,
          partialSuccess: issueCreated || wbsCreated,
          item,
          githubIssue,
          wbsTask,
          featureRequest: publicFeatureRequest,
          featureRequestError: publicFeatureRequestError,
          appFeedback,
          appFeedbackError,
        });
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
