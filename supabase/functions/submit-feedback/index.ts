// submit-feedback Edge Function
// フィードバック投稿 → 確認メール送信 + GitHub Issue 登録
//
// POST / { category, content }           → 新規投稿
// POST /?action=notify { feedback_id }   → 実装完了通知メール

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
const GITHUB_REPO = "kanta13jp1/my_web_app";
const FROM_EMAIL = "自分株式会社 <noreply@resend.dev>";
const APP_URL = "https://my-web-app-b67f4.web.app";

// deno-lint-ignore no-explicit-any
type Json = any;

function jsonOk(body: Json) {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonErr(msg: string, status = 400) {
  return new Response(JSON.stringify({ success: false, error: msg }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonErr("Method not allowed", 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonErr("Authorization required", 401);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return jsonErr("Unauthorized", 401);

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const url = new URL(req.url);
    const action = url.searchParams.get("action");

    // ─── Action: notify-implemented ───────────────────────────────────────
    if (action === "notify") {
      const body = await req.json().catch(() => ({})) as { feedback_id?: number };
      const { feedback_id } = body;
      if (!feedback_id) return jsonErr("feedback_id is required");

      const { data: fb, error: fbErr } = await adminClient
        .from("app_feedback")
        .select("id, category, content, user_email, status, github_issue_url")
        .eq("id", feedback_id)
        .maybeSingle();
      if (fbErr) throw fbErr;
      if (!fb) return jsonErr("Feedback not found", 404);
      if (!fb.user_email) return jsonErr("No email on this feedback", 422);

      const html = buildResolvedEmail(fb.content, fb.github_issue_url);
      await sendEmail(fb.user_email, "【自分株式会社】ご意見・ご要望が対応されました ✅", html);
      return jsonOk({ success: true });
    }

    // ─── Action: submit (default) ─────────────────────────────────────────
    const body = await req.json().catch(() => ({})) as { category?: string; content?: string };
    const category = (body.category ?? "other").trim();
    const content = (body.content ?? "").trim();
    if (!content) return jsonErr("content is required");

    // ユーザーのメールアドレスを取得 (service_role でのみ可)
    const { data: adminUser } = await adminClient.auth.admin.getUserById(user.id);
    const userEmail = adminUser?.user?.email ?? null;

    // app_feedback に挿入
    const { data: inserted, error: insertErr } = await adminClient
      .from("app_feedback")
      .insert({ user_id: user.id, category, content, user_email: userEmail })
      .select("id")
      .single();
    if (insertErr) throw insertErr;
    const feedbackId: number = inserted.id;

    // GitHub Issue 作成
    let issueNumber: number | null = null;
    let issueUrl: string | null = null;
    if (GITHUB_PAT) {
      try {
        const categoryLabel = category === "feature" ? "enhancement" : category === "bug" ? "bug" : "feedback";
        const issueBody = [
          content,
          "",
          "---",
          `**カテゴリ**: ${categoryLabel}`,
          `**feedback_id**: ${feedbackId}`,
          `**投稿者**: ${userEmail ?? user.id}`,
          "",
          "*自動生成: submit-feedback Edge Function*",
        ].join("\n");

        const ghRes = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/issues`, {
          method: "POST",
          headers: {
            Authorization: `token ${GITHUB_PAT}`,
            Accept: "application/vnd.github.v3+json",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            title: `[ユーザー要望] ${content.slice(0, 80)}${content.length > 80 ? "…" : ""}`,
            body: issueBody,
            labels: [categoryLabel, "user-feedback"],
          }),
        });
        if (ghRes.ok) {
          const ghData = await ghRes.json() as { number: number; html_url: string };
          issueNumber = ghData.number;
          issueUrl = ghData.html_url;
          await adminClient
            .from("app_feedback")
            .update({ github_issue_number: issueNumber, github_issue_url: issueUrl })
            .eq("id", feedbackId);
        }
      } catch (_) {
        // GitHub Issue 作成失敗は致命的ではない
      }
    }

    // 確認メール送信
    if (userEmail && RESEND_API_KEY) {
      const html = buildConfirmationEmail(content, issueUrl);
      await sendEmail(userEmail, "【自分株式会社】フィードバックを受け取りました ありがとうございます！", html).catch(() => {});
    }

    return jsonOk({ success: true, feedbackId, issueNumber, issueUrl });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonErr(msg, 500);
  }
});

async function sendEmail(to: string, subject: string, html: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: FROM_EMAIL, to: [to], subject, html }),
  });
  if (!res.ok) {
    throw new Error(`Resend error: ${await res.text()}`);
  }
}

function buildConfirmationEmail(content: string, issueUrl: string | null): string {
  const issueSection = issueUrl
    ? `<p style="font-size:13px;color:#6b7280;">
        GitHub Issue として登録しました：
        <a href="${issueUrl}" style="color:#6366F1;">${issueUrl}</a>
      </p>`
    : "";
  return `<!DOCTYPE html>
<html lang="ja"><head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#1f2937;">
  <div style="background:linear-gradient(135deg,#f97316,#6366F1);padding:24px;border-radius:12px;text-align:center;margin-bottom:24px;">
    <h1 style="color:white;margin:0;font-size:20px;">自分株式会社</h1>
    <p style="color:#e0e7ff;margin:8px 0 0;">フィードバックを受け取りました</p>
  </div>
  <h2 style="font-size:18px;color:#111827;">ありがとうございます！</h2>
  <p style="color:#4b5563;line-height:1.7;">
    フィードバックを受け取りました。内容を確認し、対応が完了した際にご連絡します。
  </p>
  <div style="background:#f3f4f6;border-radius:8px;padding:16px;margin:20px 0;">
    <p style="margin:0;font-size:12px;color:#6b7280;">送信内容</p>
    <p style="margin:4px 0 0;color:#111827;font-size:14px;line-height:1.6;">${content.replace(/</g, "&lt;")}</p>
  </div>
  ${issueSection}
  <div style="text-align:center;margin:28px 0;">
    <a href="${APP_URL}" style="background:#6366F1;color:white;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:bold;">
      自分株式会社を開く
    </a>
  </div>
  <p style="font-size:12px;color:#9ca3af;margin-top:32px;">
    このメールはフィードバック送信後に自動で送信されています。
  </p>
</body></html>`;
}

function buildResolvedEmail(content: string, issueUrl: string | null): string {
  const issueSection = issueUrl
    ? `<p style="font-size:13px;color:#6b7280;">
        関連 Issue: <a href="${issueUrl}" style="color:#6366F1;">${issueUrl}</a>
      </p>`
    : "";
  return `<!DOCTYPE html>
<html lang="ja"><head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#1f2937;">
  <div style="background:linear-gradient(135deg,#10b981,#6366F1);padding:24px;border-radius:12px;text-align:center;margin-bottom:24px;">
    <h1 style="color:white;margin:0;font-size:20px;">自分株式会社</h1>
    <p style="color:#d1fae5;margin:8px 0 0;">ご要望が対応されました ✅</p>
  </div>
  <h2 style="font-size:18px;color:#111827;">お待たせしました！</h2>
  <p style="color:#4b5563;line-height:1.7;">
    いただいたフィードバックへの対応が完了しました。さっそくお試しください。
  </p>
  <div style="background:#f3f4f6;border-radius:8px;padding:16px;margin:20px 0;">
    <p style="margin:0;font-size:12px;color:#6b7280;">対応済みのご要望</p>
    <p style="margin:4px 0 0;color:#111827;font-size:14px;line-height:1.6;">${content.replace(/</g, "&lt;")}</p>
  </div>
  ${issueSection}
  <div style="text-align:center;margin:28px 0;">
    <a href="${APP_URL}" style="background:#10b981;color:white;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:bold;">
      新機能を確認する
    </a>
  </div>
  <p style="font-size:12px;color:#9ca3af;margin-top:32px;">
    このメールは対応完了時に自動で送信されています。
  </p>
</body></html>`;
}
