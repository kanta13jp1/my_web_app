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
const FROM_EMAIL = "自分株式会社 <noreply@jibun-inc.app>";
const APP_URL = "https://my-web-app-b67f4.web.app";

interface SendWaitlistRequest {
  subject: string;
  bodyHtml: string;
  preview?: string;
}

interface WaitlistEntry {
  id: number;
  email: string;
}

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
      throw new Error(
        "RESEND_API_KEY is not set. Configure it in Supabase secrets.",
      );
    }

    // Require authenticated admin user
    const admin: AdminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await requireAdminUser(admin, req);

    const body = (await req.json().catch(() => ({}))) as SendWaitlistRequest;
    if (!body.subject || !body.bodyHtml) {
      throw new Error("subject and bodyHtml are required.");
    }

    // Fetch all waitlist emails
    const { data: waitlist, error: fetchError } = await admin
      .from("newsletter_waitlist")
      .select("id, email");
    if (fetchError) throw fetchError;

    const entries: WaitlistEntry[] = (waitlist as WaitlistEntry[]) ?? [];
    if (entries.length === 0) {
      return jsonResponse({ success: true, sent: 0, message: "No recipients." });
    }

    // Deduplicate emails
    const uniqueEmails = [...new Set(entries.map((e) => e.email.trim().toLowerCase()))].filter(
      (e) => e.includes("@"),
    );

    let sent = 0;
    const errors: string[] = [];

    for (const email of uniqueEmails) {
      try {
        const unsubscribeUrl = `${APP_URL}/unsubscribe?email=${encodeURIComponent(email)}`;
        const fullHtml = buildEmailHtml({
          bodyHtml: body.bodyHtml,
          unsubscribeUrl,
        });

        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${RESEND_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: FROM_EMAIL,
            to: email,
            subject: body.subject,
            html: fullHtml,
          }),
        });

        if (res.ok) {
          sent += 1;
        } else {
          const errBody = await res.text();
          errors.push(`${email}: ${res.status} ${errBody}`);
        }
      } catch (e) {
        errors.push(`${email}: ${String(e)}`);
      }
    }

    return jsonResponse({
      success: true,
      totalRecipients: uniqueEmails.length,
      sent,
      errors: errors.length > 0 ? errors : undefined,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 400);
  }
});

async function requireAdminUser(admin: AdminClient, req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (token === "") {
    throw new Error("Authorization token is required.");
  }
  const { data, error } = await admin.auth.getUser(token);
  if (error) throw error;
  if (!data.user) throw new Error("Authenticated user not found.");
  return data.user;
}

function buildEmailHtml({
  bodyHtml,
  unsubscribeUrl,
}: {
  bodyHtml: string;
  unsubscribeUrl: string;
}): string {
  return `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>自分株式会社からのお知らせ</title>
  <style>
    body { margin:0; padding:0; background:#f3f4f6; font-family:"Noto Sans JP",sans-serif; }
    .wrapper { max-width:600px; margin:32px auto; background:#fff; border-radius:16px; overflow:hidden; box-shadow:0 4px 24px rgba(0,0,0,.08); }
    .header { background:#3949ab; padding:28px 32px; }
    .header h1 { margin:0; color:#fff; font-size:22px; font-weight:700; }
    .header p { margin:6px 0 0; color:rgba(255,255,255,.8); font-size:13px; }
    .body { padding:28px 32px; color:#1f2937; line-height:1.75; font-size:15px; }
    .cta { display:inline-block; margin:20px 0; padding:14px 28px; background:#3949ab; color:#fff !important; border-radius:12px; text-decoration:none; font-weight:700; font-size:15px; }
    .footer { padding:20px 32px; border-top:1px solid #e5e7eb; font-size:12px; color:#9ca3af; }
    .footer a { color:#6b7280; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>自分株式会社</h1>
      <p>AI統合ライフマネジメントプラットフォーム</p>
    </div>
    <div class="body">
      ${bodyHtml}
      <p style="margin-top:24px;">
        <a class="cta" href="${APP_URL}">アプリを開く</a>
      </p>
    </div>
    <div class="footer">
      このメールは <a href="${APP_URL}">自分株式会社</a> のニュースレターウェイトリストに登録されたアドレスに送信しています。<br>
      <a href="${unsubscribeUrl}">配信停止はこちら</a>
    </div>
  </div>
</body>
</html>`;
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
