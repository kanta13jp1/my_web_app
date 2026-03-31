// Email Service Edge Function
// メール送信・テンプレート管理 (Gmail/Slack競合)
// - テンプレート管理
// - メール送信 (Resend API)
// - 送信履歴
// - スケジュール送信
//
// GET  → テンプレート一覧 / 送信履歴
// POST → メール送信 / テンプレート作成

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

const DEFAULT_TEMPLATES = [
  { id: "welcome", name: "ウェルカムメール", subject: "自分株式会社へようこそ！", body: "{{name}}さん、登録ありがとうございます！\n\nAI統合ライフマネジメントアプリ「自分株式会社」で、あなたの生産性を最大化しましょう。\n\nまずはホーム画面から機能をお試しください：\nhttps://my-web-app-b67f4.web.app/" },
  { id: "feature_update", name: "新機能お知らせ", subject: "【自分株式会社】新機能リリースのお知らせ", body: "{{name}}さん\n\n新機能「{{feature_name}}」をリリースしました！\n\n{{description}}\n\n詳しくはこちら：\nhttps://my-web-app-b67f4.web.app/" },
  { id: "streak_reminder", name: "ストリークリマインダー", subject: "ストリークが途切れそうです！", body: "{{name}}さん\n\n現在{{streak_days}}日連続ログイン中です。今日もログインしてストリークを維持しましょう！\n\nhttps://my-web-app-b67f4.web.app/" },
  { id: "weekly_digest", name: "週次ダイジェスト", subject: "【自分株式会社】今週のまとめ", body: "{{name}}さん\n\n今週の活動まとめです：\n\n・ノート作成数：{{notes_count}}\n・タスク完了数：{{tasks_count}}\n・ストリーク：{{streak_days}}日\n\n来週も頑張りましょう！" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Authorization required" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'templates' | 'history'

      if (view === "templates") {
        const { data: custom } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "email_template")
          .order("created_at", { ascending: false });

        return new Response(
          JSON.stringify({
            success: true,
            builtin: DEFAULT_TEMPLATES,
            custom: (custom ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "history") {
        const { data: history } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "email_sent")
          .order("created_at", { ascending: false })
          .limit(50);

        return new Response(
          JSON.stringify({
            success: true,
            history: (history ?? []).map((h) => ({ ...(h.metadata as Record<string, unknown>), sentAt: h.created_at })),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: true, templates: DEFAULT_TEMPLATES.length, endpoints: ["templates", "history", "send", "create_template"] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "send") {
        const { to, subject, body: emailBody, template_id, variables } = body;
        if (!to || (!emailBody && !template_id)) {
          return new Response(
            JSON.stringify({ success: false, error: "to and (body or template_id) required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        let finalSubject = subject ?? "";
        let finalBody = emailBody ?? "";

        if (template_id) {
          const tpl = DEFAULT_TEMPLATES.find((t) => t.id === template_id);
          if (tpl) {
            finalSubject = tpl.subject;
            finalBody = tpl.body;
          }
          if (variables && typeof variables === "object") {
            for (const [key, val] of Object.entries(variables)) {
              finalSubject = finalSubject.replace(new RegExp(`\\{\\{${key}\\}\\}`, "g"), String(val));
              finalBody = finalBody.replace(new RegExp(`\\{\\{${key}\\}\\}`, "g"), String(val));
            }
          }
        }

        let sent = false;
        let resendId = null;

        if (RESEND_API_KEY) {
          const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${RESEND_API_KEY}`,
            },
            body: JSON.stringify({
              from: "自分株式会社 <noreply@jibun-kaisha.com>",
              to: [to],
              subject: finalSubject,
              text: finalBody,
            }),
          });

          if (res.ok) {
            const data = await res.json();
            resendId = data.id;
            sent = true;
          }
        }

        // Log
        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "email_sent",
          metadata: { to, subject: finalSubject, template_id: template_id ?? null, sent, resendId },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, sent, resendId }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "create_template") {
        const { name, subject: tplSubject, body: tplBody } = body;
        if (!name || !tplSubject || !tplBody) {
          return new Response(
            JSON.stringify({ success: false, error: "name, subject, body required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "email_template",
          metadata: { template_id: crypto.randomUUID(), name, subject: tplSubject, body: tplBody },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, template: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("email-service error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
