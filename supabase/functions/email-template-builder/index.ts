// Email Template Builder Edge Function
// メールテンプレートビルダー (Mailchimp/SendGrid競合)
// - テンプレート作成・管理
// - 変数置換
// - プレビュー
// - キャンペーン送信記録
// - 開封率・クリック率

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const TEMPLATE_CATEGORIES = ["welcome", "newsletter", "promotion", "notification", "transactional", "announcement", "survey", "other"];
const BUILTIN_TEMPLATES = [
  { id: "welcome_basic", name: "ウェルカムメール", category: "welcome", subject: "{{app_name}}へようこそ！", body: "こんにちは {{user_name}} さん、\n\n{{app_name}}へのご登録ありがとうございます。\n\nまずは以下の機能をお試しください：\n- メモ作成\n- AI アシスタント\n- タスク管理\n\n{{app_url}}" },
  { id: "newsletter_weekly", name: "週次ニュースレター", category: "newsletter", subject: "{{app_name}} 週次アップデート", body: "{{user_name}} さん、\n\n今週のアップデートをお届けします。\n\n{{content}}\n\nご質問はいつでもお気軽にどうぞ。" },
  { id: "promo_discount", name: "プロモーション", category: "promotion", subject: "【期間限定】{{discount}}%オフキャンペーン", body: "{{user_name}} さん、\n\n特別キャンペーンのお知らせです。\n\n{{content}}\n\nクーポンコード: {{coupon_code}}\n有効期限: {{expiry_date}}" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "categories") return new Response(JSON.stringify({ success: true, categories: TEMPLATE_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      if (view === "builtin") return new Response(JSON.stringify({ success: true, templates: BUILTIN_TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "campaigns") {
        const { data: campaigns } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "email_campaign").order("created_at", { ascending: false }).limit(30);
        return new Response(JSON.stringify({ success: true, campaigns: (campaigns ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: campaigns } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "email_campaign");
        let totalSent = 0, totalOpened = 0, totalClicked = 0;
        for (const c of campaigns ?? []) {
          const m = c.metadata as Record<string, unknown>;
          totalSent += ((m.sent_count as number) ?? 0);
          totalOpened += ((m.opened_count as number) ?? 0);
          totalClicked += ((m.clicked_count as number) ?? 0);
        }
        return new Response(JSON.stringify({
          success: true, stats: {
            totalCampaigns: (campaigns ?? []).length, totalSent, totalOpened, totalClicked,
            openRate: totalSent > 0 ? Math.round((totalOpened / totalSent) * 100) : 0,
            clickRate: totalSent > 0 ? Math.round((totalClicked / totalSent) * 100) : 0,
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's templates
      const { data: templates } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "email_template").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, templates: (templates ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_template") {
        const { name, category, subject, body: templateBody, variables } = body;
        if (!name || !subject || !templateBody) return new Response(JSON.stringify({ success: false, error: "name, subject, and body required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const templateId = crypto.randomUUID();
        // Auto-detect variables
        const detectedVars = [...new Set((templateBody + subject).match(/\{\{(\w+)\}\}/g)?.map((v: string) => v.slice(2, -2)) ?? [])];
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "email_template",
          metadata: { template_id: templateId, name, category: category ?? "other", subject, body: templateBody, variables: variables ?? detectedVars },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, templateId, detectedVariables: detectedVars }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "preview") {
        const { subject, body: templateBody, variables: vars } = body;
        if (!subject || !templateBody) return new Response(JSON.stringify({ success: false, error: "subject and body required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        let previewSubject = subject;
        let previewBody = templateBody;
        for (const [key, value] of Object.entries(vars ?? {})) {
          const regex = new RegExp(`\\{\\{${key}\\}\\}`, "g");
          previewSubject = previewSubject.replace(regex, String(value));
          previewBody = previewBody.replace(regex, String(value));
        }
        return new Response(JSON.stringify({ success: true, preview: { subject: previewSubject, body: previewBody } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "record_campaign") {
        const { template_id, name, sent_count, opened_count, clicked_count } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const campaignId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "email_campaign",
          metadata: {
            campaign_id: campaignId, template_id: template_id ?? null, name,
            sent_count: sent_count ?? 0, opened_count: opened_count ?? 0,
            clicked_count: clicked_count ?? 0, status: "sent",
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, campaignId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
