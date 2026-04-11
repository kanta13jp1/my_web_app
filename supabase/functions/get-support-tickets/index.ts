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
const ADMIN_EMAIL = Deno.env.get("ADMIN_EMAIL") ?? "";
const APP_URL = "https://my-web-app-b67f4.web.app";
const FROM_EMAIL = "自分株式会社 <noreply@resend.dev>";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

// -----------------------------------------------------------------------
// get-support-tickets
//
// GET  → returns open feature requests + FAQ list (for Claude Schedule cs-check)
// POST → reply/escalate a ticket (absorbed from reply-support-request)
//
// Auth: Bearer SERVICE_ROLE_KEY
// -----------------------------------------------------------------------

const FAQ: Array<{ q: string; a: string }> = [
  {
    q: "Notionからインポートする方法",
    a: "Notion のワークスペース設定 → 設定とメンバー → 設定 → コンテンツのエクスポート → 「すべてのワークスペースコンテンツ」を選択し「Markdown & CSV」形式でエクスポートしてください。ZIPを展開後、自分株式会社のインポート画面からMarkdownファイルをアップロードできます。",
  },
  {
    q: "Evernoteからインポートする方法",
    a: "Evernote でノートを選択 → ファイル → ノートのエクスポート → ENEX形式で保存し、自分株式会社のインポート画面からアップロードしてください。",
  },
  {
    q: "パスワードを忘れた / ログインできない",
    a: "ログイン画面の「パスワードを忘れた場合」からメールアドレスを入力すると、パスワード再設定メールが届きます。",
  },
  {
    q: "プロフィールを変更したい",
    a: "右上のアイコン → プロフィール設定 から表示名・自己紹介・アイコン画像を変更できます。",
  },
  {
    q: "データを削除したい / 退会したい",
    a: "アカウント削除は現在サポートへのお問い合わせが必要です。削除希望の旨をご連絡ください。対応いたします。",
  },
  {
    q: "AIタスク提案が表示されない",
    a: "ホーム画面を下に引っ張って更新するか、一度ログアウトして再ログインをお試しください。それでも解決しない場合はバグとして調査します。",
  },
  {
    q: "競合アプリとの違いを教えてほしい",
    a: "Notion・Evernote・MoneyForward・Slack・Amazon・Google・Microsoft・Discord・LINE・Facebook など21の競合SaaSの機能を1つに統合したAI統合プラットフォームです。https://my-web-app-b67f4.web.app/vs-notion などの比較ページもご覧ください。",
  },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "GET" && req.method !== "POST") {
      throw new Error("Method not allowed. Use GET or POST.");
    }
    if (SUPABASE_URL === "" || SERVICE_ROLE_KEY === "") {
      throw new Error("Missing Supabase runtime environment variables.");
    }

    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await authorizeAutomationActor(admin, req);

    // ---- POST: reply or escalate a ticket (absorbed from reply-support-request) ----
    if (req.method === "POST") {
      const body = (await req.json().catch(() => ({}))) as {
        id?: string;
        reply?: string;
        escalate?: boolean;
        newStatus?: string;
      };

      const { id, reply, escalate = false, newStatus } = body;
      if (!id) throw new Error("id is required.");
      if (!escalate && !reply) throw new Error("reply is required unless escalating.");

      const { data: ticket, error: fetchErr } = await admin
        .from("feature_requests")
        .select("id, title, description, email, status")
        .eq("id", id)
        .maybeSingle();

      if (fetchErr) throw fetchErr;
      if (!ticket) throw new Error("Feature request not found.");
      const resolvedStatus = newStatus ??
        (escalate ? "in_progress" : String(ticket.status ?? "open"));

      const updatePayload: Record<string, unknown> = {
        admin_replied_at: new Date().toISOString(),
        admin_reply: escalate
          ? "[エスカレーション済み: 担当者が対応します]"
          : reply,
        status: resolvedStatus,
      };

      const { error: updateErr } = await admin
        .from("feature_requests")
        .update(updatePayload)
        .eq("id", id);

      if (updateErr) throw updateErr;

      const email: string | null = ticket.email ?? null;
      const title: string = ticket.title ?? "(無題)";

      const shouldSendUserEmail =
        email !== null && email.trim() !== "" && !escalate && RESEND_API_KEY !== "";
      const shouldSendAdminEmail = RESEND_API_KEY !== "" && ADMIN_EMAIL !== "";

      const adminSubject = escalate
        ? `[要対応] エスカレーション: 「${title}」`
        : `[CS自動対応] 返信済み: 「${title}」`;
      const adminBodyHtml = escalate
        ? `<p>Claude が判断できなかったためエスカレーションされました。</p><p><b>チケット:</b> ${title}</p><p><a href="${APP_URL}">管理画面を確認</a></p>`
        : `<p>Claude が以下のチケットに自動返信しました。</p><p><b>チケット:</b> ${title}</p><p><b>返信内容:</b> ${(reply ?? "").replace(/\n/g, "<br>")}</p><p><a href="${APP_URL}">管理画面を確認</a></p>`;

      const [userEmailResp] = await Promise.all([
        shouldSendUserEmail
          ? fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${RESEND_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: FROM_EMAIL,
              to: [email as string],
              subject: `【自分株式会社】「${title}」へのご返信`,
              html: buildEmailHtml(title, reply ?? ""),
            }),
          })
          : Promise.resolve(null),
        shouldSendAdminEmail
          ? fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${RESEND_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: FROM_EMAIL,
              to: [ADMIN_EMAIL],
              subject: adminSubject,
              html: adminBodyHtml,
            }),
          }).catch(() => null)
          : Promise.resolve(null),
      ]);

      const emailSent = userEmailResp?.ok ?? false;

      return new Response(
        JSON.stringify({
          success: true,
          id,
          escalated: escalate,
          emailSent,
          status: resolvedStatus,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ---- GET: return open tickets + FAQ ----
    const { data: tickets, error } = await admin
      .from("feature_requests")
      .select(
        "id, title, description, email, votes, status, created_at, admin_reply",
      )
      .eq("status", "open")
      .is("admin_replied_at", null)
      .order("votes", { ascending: false })
      .limit(20);

    if (error) throw error;

    return new Response(
      JSON.stringify({
        success: true,
        tickets: tickets ?? [],
        faq: FAQ,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function buildEmailHtml(title: string, replyText: string): string {
  return `<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#1f2937;">
  <div style="background:linear-gradient(135deg,#3949AB,#6366F1);padding:24px;border-radius:12px;text-align:center;margin-bottom:24px;">
    <h1 style="color:white;margin:0;font-size:20px;">自分株式会社</h1>
    <p style="color:#c7d2fe;margin:8px 0 0;">サポートチームより</p>
  </div>
  <h2 style="font-size:18px;color:#111827;">「${title}」についてのご返信</h2>
  <div style="background:#f3f4f6;border-radius:8px;padding:16px;margin:20px 0;line-height:1.8;color:#374151;">
    ${replyText.replace(/\n/g, "<br>")}
  </div>
  <div style="text-align:center;margin:28px 0;">
    <a href="${APP_URL}/feature-requests"
       style="background:#3949AB;color:white;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:bold;">
      機能リクエストを確認する
    </a>
  </div>
  <p style="font-size:12px;color:#9ca3af;margin-top:32px;">
    このメールはご要望送信者にのみ送信されています。<br>
    <a href="${APP_URL}/feature-requests" style="color:#6366F1;">機能リクエスト一覧</a>
  </p>
</body>
</html>`;
}
