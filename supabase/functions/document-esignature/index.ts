// Document E-Signature Edge Function
// 電子署名・契約管理 (DocuSign/Adobe Sign競合)
// - 署名リクエスト作成
// - 署名ステータス追跡
// - 監査証跡
// - テンプレート管理
// - 署名統計
//
// GET  → リクエスト一覧 / 監査ログ / テンプレート / 統計
// POST → 署名リクエスト / 署名完了 / テンプレート作成

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const SIGNATURE_STATUSES = ["draft", "sent", "viewed", "signed", "declined", "expired", "voided"];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
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
      const url = new URL(req.url);
      const view = url.searchParams.get("view");

      if (view === "statuses") {
        return new Response(JSON.stringify({ success: true, statuses: SIGNATURE_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "audit_log") {
        const requestId = url.searchParams.get("request_id");
        if (!requestId) {
          return new Response(JSON.stringify({ success: false, error: "request_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: logs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "esign_audit").eq("metadata->>request_id", requestId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          auditLog: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), timestamp: l.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "templates") {
        const { data: templates } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "esign_template")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({
          success: true,
          templates: (templates ?? []).map((t) => ({ ...(t.metadata as Record<string, unknown>), createdAt: t.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: requests } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "esign_request");
        let signed = 0, declined = 0, pending = 0;
        for (const r of requests ?? []) {
          const status = (r.metadata as Record<string, unknown>).status as string;
          if (status === "signed") signed++;
          else if (status === "declined") declined++;
          else if (["sent", "viewed"].includes(status)) pending++;
        }
        return new Response(JSON.stringify({
          success: true,
          stats: { total: (requests ?? []).length, signed, declined, pending, completionRate: (requests ?? []).length > 0 ? Math.round(signed / (requests ?? []).length * 100) : 0 },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: request list
      const status = url.searchParams.get("status");
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "esign_request")
        .order("created_at", { ascending: false });
      if (status) query = query.eq("metadata->>status", status);
      const { data: requests } = await query.limit(50);
      return new Response(JSON.stringify({
        success: true,
        requests: (requests ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "create_request") {
        const { document_title, signers, message, expires_at, template_id } = body;
        if (!document_title || !signers || signers.length === 0) {
          return new Response(JSON.stringify({ success: false, error: "document_title and signers required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const requestId = crypto.randomUUID();
        const signerList = signers.map((s: { name: string; email: string }) => ({
          signer_id: crypto.randomUUID(), name: s.name, email: s.email, status: "pending", signed_at: null,
        }));
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "esign_request",
          metadata: { request_id: requestId, document_title, signers: signerList, message: message ?? null, template_id: template_id ?? null, status: "sent", expires_at: expires_at ?? null },
          created_at: new Date().toISOString(),
        });
        // Audit log
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "esign_audit",
          metadata: { request_id: requestId, event: "request_created", actor: user.email, details: `署名リクエスト作成: ${document_title}` },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, requestId, signers: signerList }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "sign") {
        const { request_id, signer_id } = body;
        if (!request_id || !signer_id) {
          return new Response(JSON.stringify({ success: false, error: "request_id and signer_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "esign_request").eq("metadata->>request_id", request_id).maybeSingle();
        if (!existing) {
          return new Response(JSON.stringify({ success: false, error: "Request not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const meta = existing.metadata as Record<string, unknown>;
        const signers = (meta.signers as Array<Record<string, unknown>>) ?? [];
        const signer = signers.find((s) => s.signer_id === signer_id);
        if (!signer) {
          return new Response(JSON.stringify({ success: false, error: "Signer not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        signer.status = "signed";
        signer.signed_at = new Date().toISOString();
        const allSigned = signers.every((s) => s.status === "signed");
        const newStatus = allSigned ? "signed" : "sent";
        await adminClient.from("app_analytics").update({ metadata: { ...meta, signers, status: newStatus } })
          .eq("user_id", user.id).eq("source", "esign_request").eq("metadata->>request_id", request_id);
        // Audit log
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "esign_audit",
          metadata: { request_id, event: "signed", actor: signer.email, details: `${signer.name}が署名完了` },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, signed: true, allComplete: allSigned }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_template") {
        const { title, fields, default_message } = body;
        if (!title) {
          return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
        const templateId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "esign_template",
          metadata: { template_id: templateId, title, fields: fields ?? [], default_message: default_message ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, templateId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
