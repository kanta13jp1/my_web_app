import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const GITHUB_PAT = Deno.env.get("GITHUB_PAT") ?? "";
const GITHUB_REPO = Deno.env.get("GITHUB_REPO") ?? "kanta13jp1/my_web_app";
const FROM_EMAIL = Deno.env.get("FEEDBACK_FROM_EMAIL") ??
  "自分株式会社 <noreply@resend.dev>";
const APP_URL = "https://my-web-app-b67f4.web.app";

type FeedbackCategory = "feature" | "bug" | "other";

type FeatureRequestRow = {
  id: string;
  email?: string | null;
  title?: string | null;
  description?: string | null;
  status?: string | null;
  votes?: number | null;
  created_at?: string | null;
};

type GitHubIssueResult = {
  number: number;
  url: string;
  title: string;
  labels: string[];
};

type AuthenticatedUser = {
  id: string;
  email: string;
};

// deno-lint-ignore no-explicit-any
type AdminClient = any;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (req.method === "GET") {
      return await handleGet(req, admin);
    }

    if (req.method === "POST") {
      return await handlePost(req, admin);
    }

    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("feature-request-manager error:", error);
    return jsonResponse({ success: false, error: message }, 500);
  }
});

async function handleGet(req: Request, admin: AdminClient): Promise<Response> {
  const url = new URL(req.url);
  const sort = url.searchParams.get("sort") ?? "votes";
  const status = url.searchParams.get("status");
  const limitParam = Number.parseInt(url.searchParams.get("limit") ?? "50", 10);
  const limit = Number.isFinite(limitParam)
    ? Math.min(Math.max(limitParam, 1), 100)
    : 50;
  const view = url.searchParams.get("view");

  if (view === "summary") {
    const { data, error } = await admin.from("feature_requests").select("status");
    if (error) throw error;

    const counts: Record<string, number> = {};
    for (const row of data ?? []) {
      const key = String(row.status ?? "unknown");
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return jsonResponse({
      success: true,
      summary: counts,
      total: (data ?? []).length,
    });
  }

  const orderField = sort === "newest" || sort === "oldest"
    ? "created_at"
    : "votes";
  const ascending = sort === "oldest";

  let query = admin
    .from("feature_requests")
    .select("*")
    .order(orderField, { ascending })
    .limit(limit);

  if (status) {
    query = query.eq("status", status);
  }

  const { data, error } = await query;
  if (error) throw error;

  return jsonResponse({
    success: true,
    requests: data ?? [],
  });
}

async function handlePost(req: Request, admin: AdminClient): Promise<Response> {
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const action = String(body.action ?? "");

  if (action === "submit_feedback_ticket") {
    return await submitFeedbackTicket(req, admin, body);
  }

  if (action === "create") {
    const user = await requireAuthenticatedUser(req);
    const title = String(body.title ?? "").trim();
    if (title === "") {
      return jsonResponse({ success: false, error: "title is required" }, 400);
    }

    const { data, error } = await admin
      .from("feature_requests")
      .insert({
        title,
        description: String(body.description ?? "").trim(),
        status: "open",
        votes: 1,
        user_id: user.id,
        email: user.email,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw error;
    return jsonResponse({ success: true, request: data }, 201);
  }

  if (action === "vote") {
    const requestId = String(body.request_id ?? "").trim();
    if (requestId === "") {
      return jsonResponse(
        { success: false, error: "request_id is required" },
        400,
      );
    }

    const { data: current, error: currentError } = await admin
      .from("feature_requests")
      .select("votes")
      .eq("id", requestId)
      .maybeSingle();

    if (currentError) throw currentError;
    if (!current) {
      return jsonResponse({ success: false, error: "Request not found" }, 404);
    }

    const nextVotes = Number(current.votes ?? 0) + 1;
    const { data, error } = await admin
      .from("feature_requests")
      .update({ votes: nextVotes })
      .eq("id", requestId)
      .select()
      .single();

    if (error) throw error;
    return jsonResponse({ success: true, request: data });
  }

  if (action === "update_status") {
    const requestId = String(body.request_id ?? "").trim();
    const nextStatus = String(body.status ?? "").trim();
    if (requestId === "" || nextStatus === "") {
      return jsonResponse(
        { success: false, error: "request_id and status are required" },
        400,
      );
    }

    const { data, error } = await admin
      .from("feature_requests")
      .update({ status: nextStatus })
      .eq("id", requestId)
      .select()
      .single();

    if (error) throw error;
    return jsonResponse({ success: true, request: data });
  }

  return jsonResponse({ success: false, error: "Unknown action" }, 400);
}

async function submitFeedbackTicket(
  req: Request,
  admin: AdminClient,
  body: Record<string, unknown>,
): Promise<Response> {
  const user = await requireAuthenticatedUser(req);
  const category = normalizeCategory(body.category);
  const content = String(body.content ?? "").trim();
  if (content.length < 5) {
    return jsonResponse(
      {
        success: false,
        error: "content must be at least 5 characters",
      },
      400,
    );
  }

  const title = buildFeedbackTitle(category, content);
  const warnings: string[] = [];

  const { data: appFeedback, error: appFeedbackError } = await admin
    .from("app_feedback")
    .insert({
      user_id: user.id,
      category,
      content,
      status: "new",
    })
    .select("id")
    .single();
  if (appFeedbackError) throw appFeedbackError;

  if (user.email !== "") {
    try {
      await admin
        .from("app_feedback")
        .update({ user_email: user.email })
        .eq("id", appFeedback.id);
    } catch (error) {
      console.warn("app_feedback user_email update failed:", error);
      warnings.push("feedback_email_persist_failed");
    }
  }

  const { data: featureRequest, error: featureRequestError } = await admin
    .from("feature_requests")
    .insert({
      user_id: user.id,
      email: user.email,
      title,
      description: content,
      votes: 1,
      status: "open",
    })
    .select("id, title, description, email, status, votes, created_at")
    .single();
  if (featureRequestError) throw featureRequestError;

  let githubIssue: GitHubIssueResult | null = null;
  if (GITHUB_PAT !== "") {
    try {
      githubIssue = await createGitHubIssueForFeedback({
        appFeedbackId: Number(appFeedback.id),
        category,
        content,
        featureRequest: featureRequest as FeatureRequestRow,
        user,
      });

      try {
        await admin
          .from("app_feedback")
          .update({
            github_issue_number: githubIssue.number,
            github_issue_url: githubIssue.url,
          })
          .eq("id", appFeedback.id);
      } catch (error) {
        console.warn("app_feedback github issue update failed:", error);
        warnings.push("feedback_issue_link_persist_failed");
      }

      try {
        await admin.from("app_analytics").insert({
          user_id: user.id,
          source: "tracked_issue",
          created_at: new Date().toISOString(),
          metadata: {
            issue_number: githubIssue.number,
            title: githubIssue.title,
            labels: githubIssue.labels,
            issue_url: githubIssue.url,
            priority: category === "bug" ? "high" : "medium",
            status: "open",
            tracked_at: new Date().toISOString(),
            feature_request_id: featureRequest.id,
            app_feedback_id: Number(appFeedback.id),
            submitter_email: user.email,
            submitter_user_id: user.id,
            origin: "feedback_form",
            category,
          },
        });
      } catch (error) {
        console.warn("tracked_issue analytics insert failed:", error);
        warnings.push("issue_tracking_log_failed");
      }
    } catch (error) {
      console.error("submit_feedback_ticket github issue error:", error);
      warnings.push("github_issue_creation_failed");
    }
  } else {
    warnings.push("github_pat_missing");
  }

  let thankYouEmailSent = false;
  if (RESEND_API_KEY !== "" && user.email !== "") {
    try {
      await sendEmail({
        to: user.email,
        subject: `【自分株式会社】投稿ありがとうございます: ${title}`,
        html: buildThankYouEmailHtml({
          content,
          featureRequestId: String(featureRequest.id),
          githubIssue,
          title,
        }),
      });
      thankYouEmailSent = true;
    } catch (error) {
      console.error("submit_feedback_ticket thank-you email error:", error);
      warnings.push("thank_you_email_failed");
    }
  } else {
    warnings.push("thank_you_email_skipped");
  }

  return jsonResponse({
    success: true,
    featureRequestId: featureRequest.id,
    appFeedbackId: appFeedback.id,
    githubIssueCreated: githubIssue !== null,
    githubIssueNumber: githubIssue?.number ?? null,
    githubIssueUrl: githubIssue?.url ?? null,
    thankYouEmailSent,
    warnings,
  }, 201);
}

async function requireAuthenticatedUser(req: Request): Promise<AuthenticatedUser> {
  const authHeader = req.headers.get("Authorization") ??
    req.headers.get("authorization") ??
    "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    throw new Error("Authorization required.");
  }
  if (SUPABASE_ANON_KEY === "") {
    throw new Error("Missing SUPABASE_ANON_KEY.");
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error) throw error;
  if (!data.user) throw new Error("Unauthorized");

  return {
    id: data.user.id,
    email: data.user.email?.trim() ?? "",
  };
}

function normalizeCategory(raw: unknown): FeedbackCategory {
  const value = String(raw ?? "").trim().toLowerCase();
  if (value === "feature" || value === "bug" || value === "other") {
    return value;
  }
  return "other";
}

function buildFeedbackTitle(category: FeedbackCategory, content: string): string {
  const prefix = category === "bug"
    ? "不具合報告"
    : category === "feature"
    ? "改善要望"
    : "ご意見";
  const firstLine = content.split(/\r?\n/)[0].trim();
  const compact = firstLine.replace(/\s+/g, " ");
  const trimmed = compact.length > 72 ? `${compact.slice(0, 72)}...` : compact;
  return `${prefix}: ${trimmed}`;
}

async function createGitHubIssueForFeedback(input: {
  appFeedbackId: number;
  category: FeedbackCategory;
  content: string;
  featureRequest: FeatureRequestRow;
  user: AuthenticatedUser;
}): Promise<GitHubIssueResult> {
  const labels = [
    "user-feedback",
    "claude-managed-agents",
    "github-issue-fix",
    input.category === "bug" ? "bug" : "enhancement",
  ];

  await ensureGitHubLabels(labels);

  const response = await fetch(
    `https://api.github.com/repos/${GITHUB_REPO}/issues`,
    {
      method: "POST",
      headers: {
        Authorization: `token ${GITHUB_PAT}`,
        Accept: "application/vnd.github+json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        title: input.featureRequest.title,
        body: buildGitHubIssueBody(input),
        labels,
      }),
    },
  );

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      `GitHub issue creation failed: ${JSON.stringify(payload)}`,
    );
  }

  return {
    number: Number(payload.number),
    url: String(payload.html_url ?? ""),
    title: String(payload.title ?? input.featureRequest.title ?? ""),
    labels,
  };
}

async function ensureGitHubLabels(labels: string[]): Promise<void> {
  const definitions: Record<string, { color: string; description: string }> = {
    "user-feedback": {
      color: "6366F1",
      description: "Submitted from the in-app feedback form",
    },
    "claude-managed-agents": {
      color: "F59E0B",
      description: "Handled by Claude Managed Agents workflows and schedules",
    },
    "github-issue-fix": {
      color: "10B981",
      description: "Queued for the github-issue-fix schedule task",
    },
    "bug": {
      color: "DC2626",
      description: "Bug report from a user",
    },
    "enhancement": {
      color: "2563EB",
      description: "Feature request from a user",
    },
  };

  for (const label of labels) {
    const definition = definitions[label];
    if (!definition) continue;

    const response = await fetch(
      `https://api.github.com/repos/${GITHUB_REPO}/labels`,
      {
        method: "POST",
        headers: {
          Authorization: `token ${GITHUB_PAT}`,
          Accept: "application/vnd.github+json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name: label,
          color: definition.color,
          description: definition.description,
        }),
      },
    );

    if (response.ok || response.status === 422) {
      continue;
    }

    const payload = await response.text();
    throw new Error(`GitHub label setup failed for ${label}: ${payload}`);
  }
}

function buildGitHubIssueBody(input: {
  appFeedbackId: number;
  category: FeedbackCategory;
  content: string;
  featureRequest: FeatureRequestRow;
  user: AuthenticatedUser;
}): string {
  return [
    "## User Feedback",
    "",
    input.content,
    "",
    "## Metadata",
    `- Category: ${input.category}`,
    `- Feature Request ID: ${input.featureRequest.id}`,
    `- App Feedback ID: ${input.appFeedbackId}`,
    `- Submitter Email: ${input.user.email || "(none)"}`,
    `- Submitter User ID: ${input.user.id}`,
    "",
    "## Automation",
    "- Source: in-app feedback form",
    "- Queue: github-issue-fix schedule task",
    "- Managed By: Claude Managed Agents",
    "",
    `<!-- feature_request_id:${input.featureRequest.id} -->`,
    `<!-- app_feedback_id:${input.appFeedbackId} -->`,
    `<!-- submitter_email:${input.user.email || ""} -->`,
    `<!-- submitter_user_id:${input.user.id} -->`,
    `<!-- feedback_category:${input.category} -->`,
    "",
    `Submitted from ${APP_URL}/feedback`,
  ].join("\n");
}

function buildThankYouEmailHtml(input: {
  content: string;
  featureRequestId: string;
  githubIssue: GitHubIssueResult | null;
  title: string;
}): string {
  const summary = input.content.length > 220
    ? `${input.content.slice(0, 220)}...`
    : input.content;
  const issueBlock = input.githubIssue
    ? `
      <div style="background:#eef2ff;border-radius:10px;padding:16px;margin:20px 0;">
        <div style="font-size:12px;color:#4f46e5;font-weight:700;">GitHub Issue</div>
        <div style="margin-top:6px;font-size:14px;color:#111827;">
          #${input.githubIssue.number} ${escapeHtml(input.githubIssue.title)}
        </div>
        <div style="margin-top:10px;">
          <a href="${input.githubIssue.url}" style="color:#4f46e5;text-decoration:none;font-weight:700;">
            Issue を見る
          </a>
        </div>
      </div>
    `
    : `
      <p style="color:#6b7280;line-height:1.7;">
        GitHub Issue への登録はバックグラウンドで処理中です。反映まで少しお待ちください。
      </p>
    `;

  return `<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:24px;color:#111827;">
  <div style="background:linear-gradient(135deg,#1f2937,#4f46e5);padding:24px;border-radius:16px;margin-bottom:24px;">
    <h1 style="margin:0;color:#ffffff;font-size:22px;">投稿ありがとうございます</h1>
    <p style="margin:10px 0 0;color:#c7d2fe;line-height:1.7;">
      ご意見・ご要望を受け付けました。内容を確認し、対応が始まったり完了したりしたらメールでお知らせします。
    </p>
  </div>

  <h2 style="font-size:18px;margin:0 0 12px;">受け付けた内容</h2>
  <div style="background:#f8fafc;border-radius:12px;padding:16px;line-height:1.8;">
    <div style="font-weight:700;">${escapeHtml(input.title)}</div>
    <div style="margin-top:8px;color:#374151;">${
    escapeHtml(summary).replace(/\n/g, "<br>")
  }</div>
  </div>

  ${issueBlock}

  <div style="background:#f9fafb;border-radius:12px;padding:16px;margin-top:20px;">
    <div style="font-size:12px;color:#6b7280;">Feature Request ID</div>
    <div style="margin-top:4px;font-family:monospace;color:#111827;">${
    escapeHtml(input.featureRequestId)
  }</div>
  </div>

  <div style="margin-top:28px;text-align:center;">
    <a href="${APP_URL}/feature-requests" style="display:inline-block;background:#111827;color:#ffffff;padding:12px 24px;border-radius:10px;text-decoration:none;font-weight:700;">
      機能リクエスト一覧を見る
    </a>
  </div>
</body>
</html>`;
}

async function sendEmail(input: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [input.to],
      subject: input.subject,
      html: input.html,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Resend API error: ${body}`);
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
