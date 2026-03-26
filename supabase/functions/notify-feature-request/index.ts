import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = "自分株式会社 <noreply@resend.dev>";
const APP_URL = "https://my-web-app-b67f4.web.app";

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

    // Require authenticated caller
    await requireAuthUser(admin, req);

    const body = (await req.json().catch(() => ({}))) as {
      id?: string;
      status?: string;
    };
    const { id, status } = body;
    if (!id) throw new Error("id is required.");
    if (!status) throw new Error("status is required.");

    // Fetch the feature request
    const { data: featureReq, error: fetchErr } = await admin
      .from("feature_requests")
      .select("id, title, description, email, status")
      .eq("id", id)
      .maybeSingle();

    if (fetchErr) throw fetchErr;
    if (!featureReq) throw new Error("Feature request not found.");

    const email: string | null = featureReq.email ?? null;
    if (!email || email.trim() === "") {
      return jsonResponse({
        success: false,
        error: "No email address on this feature request.",
      }, 400);
    }

    const title: string = featureReq.title ?? "(無題)";
    const statusLabel =
      status === "done" ? "実装完了 ✅" : "対応中 🔄";

    const subject = `【自分株式会社】ご要望「${title}」が${statusLabel}になりました`;
    const bodyHtml = `
<!DOCTYPE html>
<html lang="ja">
<head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#1f2937;">
  <div style="background:linear-gradient(135deg,#3949AB,#6366F1);padding:24px;border-radius:12px;text-align:center;margin-bottom:24px;">
    <h1 style="color:white;margin:0;font-size:20px;">自分株式会社</h1>
    <p style="color:#c7d2fe;margin:8px 0 0;">機能リクエスト更新のお知らせ</p>
  </div>
  <h2 style="font-size:18px;color:#111827;">「${title}」が${statusLabel}になりました</h2>
  <p style="color:#4b5563;line-height:1.7;">
    ${
      status === "done"
        ? "ご要望いただいていた機能が実装完了しました！さっそくお試しください。"
        : "ご要望いただいた機能の開発に着手しました。実装完了まで今しばらくお待ちください。"
    }
  </p>
  <div style="background:#f3f4f6;border-radius:8px;padding:16px;margin:20px 0;">
    <p style="margin:0;font-size:14px;color:#6b7280;">リクエスト内容</p>
    <p style="margin:4px 0 0;font-weight:bold;color:#111827;">${title}</p>
  </div>
  <div style="text-align:center;margin:28px 0;">
    <a href="${APP_URL}" style="background:#3949AB;color:white;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:bold;">
      自分株式会社を開く
    </a>
  </div>
  <p style="font-size:12px;color:#9ca3af;margin-top:32px;">
    このメールは機能リクエストの送信者にのみ送信されています。<br>
    配信停止は <a href="${APP_URL}/feature-requests" style="color:#6366F1;">こちら</a>
  </p>
</body>
</html>`;

    const resendResp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [email],
        subject,
        html: bodyHtml,
      }),
    });

    if (!resendResp.ok) {
      const errText = await resendResp.text();
      throw new Error(`Resend API error: ${errText}`);
    }

    return jsonResponse({ success: true, sentTo: email });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

async function requireAuthUser(admin: AdminClient, req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (token === "") throw new Error("Authorization token is required.");
  const { data, error } = await admin.auth.getUser(token);
  if (error) throw error;
  if (!data.user) throw new Error("Authenticated user not found.");
  return data.user;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
