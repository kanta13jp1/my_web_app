// Form Builder Edge Function
// フォームビルダー (Google Forms/Microsoft Forms/Notion Forms競合)
// - 多種フィールドタイプ (テキスト/数値/選択/日付/ファイル/評価)
// - 条件分岐ロジック
// - 公開URL回答収集
// - 回答集計・分析
//
// GET  → フォーム一覧 / フォーム詳細 / 回答集計 / 公開フォーム
// POST → フォーム作成 / フィールド追加 / 回答送信 / 公開設定

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const FIELD_TYPES = [
  "short_text", "long_text", "number", "email", "url",
  "single_choice", "multi_choice", "dropdown",
  "date", "time", "datetime",
  "file_upload", "rating", "scale",
  "section_break", "description",
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
    const url = new URL(req.url);

    // Public form view (no auth required)
    if (req.method === "GET" && url.searchParams.get("view") === "public") {
      const formId = url.searchParams.get("form_id");
      if (!formId) {
        return new Response(JSON.stringify({ success: false, error: "form_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const { data: form } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("source", "form_builder").eq("metadata->>form_id", formId).eq("metadata->>is_public", "true").maybeSingle();
      if (!form) {
        return new Response(JSON.stringify({ success: false, error: "Form not found or not public" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      const meta = form.metadata as Record<string, unknown>;
      return new Response(JSON.stringify({
        success: true,
        form: { form_id: meta.form_id, title: meta.title, description: meta.description, fields: meta.fields, theme: meta.theme },
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Public form submission (no auth required for public forms)
    if (req.method === "POST") {
      const body = await req.json();
      if (body.action === "submit_public") {
        const { form_id, responses, respondent_email } = body;
        if (!form_id || !responses) {
          return new Response(JSON.stringify({ success: false, error: "form_id and responses required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        // Verify form is public
        const { data: form } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "form_builder").eq("metadata->>form_id", form_id).eq("metadata->>is_public", "true").maybeSingle();
        if (!form) {
          return new Response(JSON.stringify({ success: false, error: "Form not found or not public" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const formMeta = form.metadata as Record<string, unknown>;
        const responseId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: formMeta.owner_id as string, source: "form_response",
          metadata: { response_id: responseId, form_id, responses, respondent_email: respondent_email ?? null, submitted_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, responseId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
    }

    // Auth required for all other operations
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Authorization required" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "GET") {
      const view = url.searchParams.get("view");
      const formId = url.searchParams.get("form_id");

      if (view === "field_types") {
        return new Response(JSON.stringify({ success: true, fieldTypes: FIELD_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "detail" && formId) {
        const { data: form } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "form_builder").eq("metadata->>form_id", formId).maybeSingle();
        if (!form) {
          return new Response(JSON.stringify({ success: false, error: "Form not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        return new Response(JSON.stringify({ success: true, form: { ...(form.metadata as Record<string, unknown>), createdAt: form.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "responses" && formId) {
        const { data: responses } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "form_response").eq("metadata->>form_id", formId)
          .order("created_at", { ascending: false }).limit(200);
        return new Response(JSON.stringify({
          success: true,
          responses: (responses ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
          totalResponses: (responses ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "analytics" && formId) {
        const { data: responses } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "form_response").eq("metadata->>form_id", formId);
        const total = (responses ?? []).length;
        // Aggregate responses by field
        const fieldStats = new Map<string, Map<string, number>>();
        for (const r of responses ?? []) {
          const meta = r.metadata as Record<string, unknown>;
          const answers = (meta.responses as Record<string, unknown>) ?? {};
          for (const [field, val] of Object.entries(answers)) {
            if (!fieldStats.has(field)) fieldStats.set(field, new Map());
            const stats = fieldStats.get(field)!;
            const key = String(val);
            stats.set(key, (stats.get(key) ?? 0) + 1);
          }
        }
        const analytics: Record<string, Record<string, number>> = {};
        for (const [field, stats] of fieldStats) {
          analytics[field] = Object.fromEntries(stats);
        }
        return new Response(JSON.stringify({ success: true, totalResponses: total, analytics }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: form list
      const { data: forms } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "form_builder")
        .order("created_at", { ascending: false });
      return new Response(JSON.stringify({
        success: true,
        forms: (forms ?? []).map((f) => {
          const meta = f.metadata as Record<string, unknown>;
          return { form_id: meta.form_id, title: meta.title, is_public: meta.is_public, field_count: ((meta.fields as unknown[]) ?? []).length, createdAt: f.created_at };
        }),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_form") {
        const { title, description, fields, theme } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const formId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "form_builder",
          metadata: {
            form_id: formId, owner_id: user.id, title,
            description: description ?? null,
            fields: fields ?? [],
            is_public: false,
            theme: theme ?? { color: "#4F46E5" },
            accept_responses: true,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, formId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_field") {
        const { form_id, field_type, label, required, options, validation } = body;
        if (!form_id || !field_type || !label) {
          return new Response(JSON.stringify({ success: false, error: "form_id, field_type, label required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        if (!FIELD_TYPES.includes(field_type)) {
          return new Response(JSON.stringify({ success: false, error: "Invalid field_type" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "form_builder").eq("metadata->>form_id", form_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Form not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const fields = (meta.fields as Array<Record<string, unknown>>) ?? [];
        fields.push({
          field_id: crypto.randomUUID(), field_type, label,
          required: required ?? false,
          options: options ?? null,
          validation: validation ?? null,
          order: fields.length,
        });
        await adminClient.from("app_analytics").update({ metadata: { ...meta, fields } })
          .eq("user_id", user.id).eq("source", "form_builder").eq("metadata->>form_id", form_id);
        return new Response(JSON.stringify({ success: true, added: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "publish") {
        const { form_id, is_public } = body;
        if (!form_id) {
          return new Response(JSON.stringify({ success: false, error: "form_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "form_builder").eq("metadata->>form_id", form_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Form not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        await adminClient.from("app_analytics").update({ metadata: { ...meta, is_public: is_public ?? true } })
          .eq("user_id", user.id).eq("source", "form_builder").eq("metadata->>form_id", form_id);
        return new Response(JSON.stringify({ success: true, published: is_public ?? true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
