import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authorizeAutomationActor } from "../_shared/automation-auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("FEEDBACK_FROM_EMAIL") ??
  "自分株式会社 <noreply@resend.dev>";
const APP_URL = "https://my-web-app-b67f4.web.app";

type FeatureRequestRow = {
  id: string;
  email?: string | null;
  title?: string | null;
  description?: string | null;
  status?: string | null;
  admin_reply?: string | null;
};

type AppFeedbackRow = {
  id: number;
  category?: string | null;
  content?: string | null;
  user_email?: string | null;
  status?: string | null;
  github_issue_number?: number | null;
  github_issue_url?: string | null;
};

type NotificationContext = {
  featureRequest: FeatureRequestRow | null;
  appFeedback: AppFeedbackRow | null;
  issueNumber: number | null;
  issueUrl: string;
};

// deno-lint-ignore no-explicit-any
type AdminClient = any;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      throw new Error("Method not allowed.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }
    if (RESEND_API_KEY === "") {
      throw new Error("Missing RESEND_API_KEY.");
    }

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await authorizeAutomationActor(admin, req);

    const body = (await req.json().catch(() => ({}))) as {
      id?: string;
      appFeedbackId?: number;
      issueNumber?: number;
      issueUrl?: string;
      issueTitle?: string;
      status?: string;
      resolutionSummary?: string;
      releaseTitle?: string;
      releaseUrl?: string;
      markAsResolved?: boolean;
    };

    const requestedStatus = String(body.status ?? "").trim();
    const markAsResolved = body.markAsResolved == true;
    const context = await resolveContext(admin, {
      featureRequestId: String(body.id ?? "").trim(),
      appFeedbackId: Number(body.appFeedbackId ?? 0) || null,
      issueNumber: Number(body.issueNumber ?? 0) || null,
      issueUrl: String(body.issueUrl ?? "").trim(),
    });

    if (context.featureRequest == null && context.appFeedback == null) {
      throw new Error("No matching feedback record was found.");
    }

    const finalStatus = resolveStatus(
      requestedStatus,
      markAsResolved,
      context.featureRequest?.status,
      context.appFeedback?.status,
    );
    const title = firstNonEmpty(
      context.featureRequest?.title,
      buildFallbackTitle(context.appFeedback?.content ?? ""),
    );
    const recipientEmail = firstNonEmpty(
      context.featureRequest?.email,
      context.appFeedback?.user_email,
    );

    if (recipientEmail == "") {
      throw new Error("No email address is associated with this feedback.");
    }

    const resolutionSummary = String(body.resolutionSummary ?? "").trim();
    const issueUrl = String(body.issueUrl ?? context.issueUrl).trim();
    const issueTitle = String(body.issueTitle ?? "").trim();
    const releaseTitle = String(body.releaseTitle ?? "").trim();
    const releaseUrl = String(body.releaseUrl ?? "").trim();

    if (context.featureRequest != null) {
      const updatePayload: Record<string, unknown> = {
        status: finalStatus,
        admin_replied_at: new Date().toISOString(),
      };
      if (resolutionSummary != "") {
        updatePayload.admin_reply = resolutionSummary;
      } else if (
        markAsResolved && (context.featureRequest.admin_reply ?? "").trim() == ""
      ) {
        updatePayload.admin_reply = buildDefaultResolutionSummary({
          issueNumber: context.issueNumber,
          releaseTitle,
          releaseUrl,
        });
      }

      const { error } = await admin
        .from("feature_requests")
        .update(updatePayload)
        .eq("id", context.featureRequest.id);
      if (error) throw error;
    }

    if (context.appFeedback != null) {
      const feedbackStatus = finalStatus == "done" ? "implemented" : "reviewed";
      const updatePayload: Record<string, unknown> = {
        status: feedbackStatus,
      };
      if (context.issueNumber != null) {
        updatePayload.github_issue_number = context.issueNumber;
      }
      if (issueUrl != "") {
        updatePayload.github_issue_url = issueUrl;
      }

      const { error } = await admin
        .from("app_feedback")
        .update(updatePayload)
        .eq("id", context.appFeedback.id);
      if (error) throw error;
    }

    const html = buildNotificationEmailHtml({
      title,
      description: context.featureRequest?.description ??
        context.appFeedback?.content ??
        "",
      status: finalStatus,
      resolutionSummary: resolutionSummary != ""
        ? resolutionSummary
        : buildDefaultResolutionSummary({
          issueNumber: context.issueNumber,
          releaseTitle,
          releaseUrl,
        }),
      issueNumber: context.issueNumber,
      issueTitle,
      issueUrl,
      releaseTitle,
      releaseUrl,
    });

    await sendEmail({
      to: recipientEmail,
      subject: buildEmailSubject(title, finalStatus),
      html,
    });

    return jsonResponse({
      success: true,
      emailSent: true,
      sentTo: recipientEmail,
      status: finalStatus,
      featureRequestId: context.featureRequest?.id ?? null,
      appFeedbackId: context.appFeedback?.id ?? null,
      issueNumber: context.issueNumber,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

async function resolveContext(
  admin: AdminClient,
  input: {
    featureRequestId: string;
    appFeedbackId: number | null;
    issueNumber: number | null;
    issueUrl: string;
  },
): Promise<NotificationContext> {
  let featureRequest: FeatureRequestRow | null = null;
  let appFeedback: AppFeedbackRow | null = null;
  let issueNumber = input.issueNumber;
  let issueUrl = input.issueUrl;

  if (input.featureRequestId != "") {
    const { data, error } = await admin
      .from("feature_requests")
      .select("id, email, title, description, status, admin_reply")
      .eq("id", input.featureRequestId)
      .maybeSingle();
    if (error) throw error;
    featureRequest = data;
  }

  if (input.appFeedbackId != null) {
    const { data, error } = await admin
      .from("app_feedback")
      .select(
        "id, category, content, user_email, status, github_issue_number, github_issue_url",
      )
      .eq("id", input.appFeedbackId)
      .maybeSingle();
    if (error) throw error;
    appFeedback = data;
    issueNumber ??= data?.github_issue_number ?? null;
    issueUrl ||= data?.github_issue_url ?? "";
  }

  if (featureRequest == null || appFeedback == null) {
    const tracked = await lookupTrackedIssue(admin, {
      featureRequestId: input.featureRequestId,
      appFeedbackId: input.appFeedbackId,
      issueNumber,
    });

    if (featureRequest == null && tracked.featureRequestId != "") {
      const { data, error } = await admin
        .from("feature_requests")
        .select("id, email, title, description, status, admin_reply")
        .eq("id", tracked.featureRequestId)
        .maybeSingle();
      if (error) throw error;
      featureRequest = data;
    }

    if (appFeedback == null && tracked.appFeedbackId != null) {
      const { data, error } = await admin
        .from("app_feedback")
        .select(
          "id, category, content, user_email, status, github_issue_number, github_issue_url",
        )
        .eq("id", tracked.appFeedbackId)
        .maybeSingle();
      if (error) throw error;
      appFeedback = data;
      issueNumber ??= data?.github_issue_number ?? null;
      issueUrl ||= data?.github_issue_url ?? "";
    }
  }

  if (appFeedback == null && issueNumber != null) {
    const { data, error } = await admin
      .from("app_feedback")
      .select(
        "id, category, content, user_email, status, github_issue_number, github_issue_url",
      )
      .eq("github_issue_number", issueNumber)
      .maybeSingle();
    if (error) throw error;
    appFeedback = data;
    issueUrl ||= data?.github_issue_url ?? "";
  }

  return {
    featureRequest,
    appFeedback,
    issueNumber,
    issueUrl,
  };
}

async function lookupTrackedIssue(
  admin: AdminClient,
  input: {
    featureRequestId: string;
    appFeedbackId: number | null;
    issueNumber: number | null;
  },
): Promise<{ featureRequestId: string; appFeedbackId: number | null }> {
  let query = admin
    .from("app_analytics")
    .select("metadata")
    .eq("source", "tracked_issue")
    .order("created_at", { ascending: false })
    .limit(1);

  if (input.featureRequestId != "") {
    query = query.eq("metadata->>feature_request_id", input.featureRequestId);
  } else if (input.appFeedbackId != null) {
    query = query.eq("metadata->>app_feedback_id", String(input.appFeedbackId));
  } else if (input.issueNumber != null) {
    query = query.eq("metadata->>issue_number", String(input.issueNumber));
  } else {
    return { featureRequestId: "", appFeedbackId: null };
  }

  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  const metadata = data?.metadata as Record<string, unknown> | undefined;
  const trackedFeatureRequestId = String(metadata?.feature_request_id ?? "");
  const trackedAppFeedbackId = Number(metadata?.app_feedback_id ?? 0) || null;

  return {
    featureRequestId: trackedFeatureRequestId,
    appFeedbackId: trackedAppFeedbackId,
  };
}

function resolveStatus(
  requestedStatus: string,
  markAsResolved: boolean,
  featureRequestStatus?: string | null,
  feedbackStatus?: string | null,
): string {
  if (requestedStatus != "") {
    return requestedStatus;
  }
  if (markAsResolved) {
    return "done";
  }
  if (featureRequestStatus != null && featureRequestStatus.trim() != "") {
    return featureRequestStatus;
  }
  if (feedbackStatus == "implemented") {
    return "done";
  }
  if (feedbackStatus == "reviewed") {
    return "in_progress";
  }
  return "open";
}

function buildFallbackTitle(content: string): string {
  const firstLine = content.split(/\r?\n/)[0].trim();
  if (firstLine == "") {
    return "ご意見・ご要望";
  }
  return firstLine.length > 72 ? `${firstLine.substring(0, 72)}...` : firstLine;
}

function buildEmailSubject(title: string, status: string): string {
  if (status == "done") {
    return `【自分株式会社】「${title}」への対応が完了しました`;
  }
  if (status == "in_progress") {
    return `【自分株式会社】「${title}」の対応を開始しました`;
  }
  return `【自分株式会社】「${title}」の対応状況を更新しました`;
}

function buildDefaultResolutionSummary(input: {
  issueNumber: number | null;
  releaseTitle: string;
  releaseUrl: string;
}): string {
  const parts: string[] = [];
  if (input.issueNumber != null) {
    parts.push(`GitHub Issue #${input.issueNumber} の対応を反映しました。`);
  } else {
    parts.push("ご要望への対応内容を反映しました。");
  }
  if (input.releaseTitle.trim() != "") {
    parts.push(`反映内容: ${input.releaseTitle}`);
  }
  if (input.releaseUrl.trim() != "") {
    parts.push(`詳細: ${input.releaseUrl}`);
  }
  return parts.join("\n");
}

function firstNonEmpty(...values: Array<string | null | undefined>): string {
  for (const value of values) {
    const normalized = value?.trim() ?? "";
    if (normalized != "") {
      return normalized;
    }
  }
  return "";
}

function buildNotificationEmailHtml(input: {
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
  const statusLabel = input.status == "done"
    ? "対応完了"
    : input.status == "in_progress"
    ? "対応中"
    : "更新";
  const issueBlock = input.issueNumber != null || input.issueUrl.trim() != ""
    ? `
      <div style="background:#eef2ff;border-radius:12px;padding:16px;margin-top:20px;">
        <div style="font-size:12px;color:#4f46e5;font-weight:700;">GitHub Issue</div>
        <div style="margin-top:6px;color:#111827;">
          ${input.issueNumber != null ? `#${input.issueNumber}` : ""} ${
      escapeHtml(
        input.issueTitle,
      )
    }
        </div>
        ${
      input.issueUrl.trim() != ""
        ? `<div style="margin-top:10px;"><a href="${input.issueUrl}" style="color:#4f46e5;text-decoration:none;font-weight:700;">Issue を見る</a></div>`
        : ""
    }
      </div>
    `
    : "";
  const releaseBlock = input.releaseTitle.trim() != "" ||
      input.releaseUrl.trim() != ""
    ? `
      <div style="background:#ecfdf5;border-radius:12px;padding:16px;margin-top:20px;">
        <div style="font-size:12px;color:#047857;font-weight:700;">リリース情報</div>
        <div style="margin-top:6px;color:#111827;">${escapeHtml(input.releaseTitle)}</div>
        ${
      input.releaseUrl.trim() != ""
        ? `<div style="margin-top:10px;"><a href="${input.releaseUrl}" style="color:#047857;text-decoration:none;font-weight:700;">変更内容を見る</a></div>`
        : ""
    }
      </div>
    `
    : "";

  return `<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:640px;margin:0 auto;padding:24px;color:#111827;">
  <div style="background:linear-gradient(135deg,#111827,#4f46e5);padding:24px;border-radius:16px;margin-bottom:24px;">
    <h1 style="margin:0;color:#ffffff;font-size:22px;">${statusLabel}のお知らせ</h1>
    <p style="margin:10px 0 0;color:#c7d2fe;line-height:1.7;">
      ご意見・ご要望に関する最新状況をお知らせします。
    </p>
  </div>

  <h2 style="font-size:18px;margin:0 0 12px;">${escapeHtml(input.title)}</h2>
  <div style="background:#f8fafc;border-radius:12px;padding:16px;line-height:1.8;">
    <div style="font-size:12px;color:#6b7280;">ご投稿内容</div>
    <div style="margin-top:8px;color:#374151;">${
    escapeHtml(input.description).replace(/\n/g, "<br>")
  }</div>
  </div>

  <div style="background:#fff7ed;border-radius:12px;padding:16px;margin-top:20px;">
    <div style="font-size:12px;color:#c2410c;font-weight:700;">対応内容</div>
    <div style="margin-top:8px;color:#374151;line-height:1.8;">${
    escapeHtml(input.resolutionSummary).replace(/\n/g, "<br>")
  }</div>
  </div>

  ${issueBlock}
  ${releaseBlock}

  <div style="margin-top:28px;text-align:center;">
    <a href="${APP_URL}" style="display:inline-block;background:#111827;color:#ffffff;padding:12px 24px;border-radius:10px;text-decoration:none;font-weight:700;">
      自分株式会社を開く
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
