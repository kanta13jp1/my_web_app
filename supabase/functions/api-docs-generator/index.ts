// API Documentation Generator Edge Function
// APIドキュメント自動生成 (GitHub/Swagger競合)
// - エンドポイント登録
// - リクエスト/レスポンス例
// - 認証情報
// - バージョン管理
// - OpenAPI形式エクスポート

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const HTTP_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"];
const AUTH_TYPES = ["none", "bearer", "api_key", "basic", "oauth2"];
const PARAM_TYPES = ["string", "number", "boolean", "array", "object"];

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
      const apiId = url.searchParams.get("api_id");

      if (view === "constants") return new Response(JSON.stringify({ success: true, httpMethods: HTTP_METHODS, authTypes: AUTH_TYPES, paramTypes: PARAM_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "api" && apiId) {
        const { data: api } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "api_doc").eq("metadata->>api_id", apiId).maybeSingle();
        if (!api) return new Response(JSON.stringify({ success: false, error: "API not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: endpoints } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "api_endpoint").eq("metadata->>api_id", apiId)
          .order("created_at", { ascending: true });
        return new Response(JSON.stringify({
          success: true,
          api: { ...(api.metadata as Record<string, unknown>), createdAt: api.created_at },
          endpoints: (endpoints ?? []).map((e) => ({ ...(e.metadata as Record<string, unknown>), createdAt: e.created_at })),
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "openapi" && apiId) {
        const { data: api } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "api_doc").eq("metadata->>api_id", apiId).maybeSingle();
        const { data: endpoints } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "api_endpoint").eq("metadata->>api_id", apiId);
        if (!api) return new Response(JSON.stringify({ success: false, error: "API not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = api.metadata as Record<string, unknown>;
        const paths: Record<string, Record<string, unknown>> = {};
        for (const ep of endpoints ?? []) {
          const em = ep.metadata as Record<string, unknown>;
          const path = (em.path as string) ?? "/";
          const method = ((em.method as string) ?? "GET").toLowerCase();
          if (!paths[path]) paths[path] = {};
          paths[path][method] = {
            summary: em.summary ?? "", description: em.description ?? "",
            parameters: em.parameters ?? [], responses: em.responses ?? { "200": { description: "Success" } },
          };
        }
        const openapi = {
          openapi: "3.0.0",
          info: { title: meta.title ?? "API", version: (meta.version as string) ?? "1.0.0", description: meta.description ?? "" },
          servers: [{ url: (meta.base_url as string) ?? SUPABASE_URL }],
          paths,
        };
        return new Response(JSON.stringify({ success: true, openapi }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's APIs
      const { data: apis } = await adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "api_doc").order("created_at", { ascending: false });
      return new Response(JSON.stringify({ success: true, apis: (apis ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_api") {
        const { title, description, base_url, version, auth_type } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const aId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "api_doc",
          metadata: { api_id: aId, title, description: description ?? "", base_url: base_url ?? "", version: version ?? "1.0.0", auth_type: auth_type ?? "bearer" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, apiId: aId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_endpoint") {
        const { api_id, method, path, summary, description, parameters, request_body, responses } = body;
        if (!api_id || !path) return new Response(JSON.stringify({ success: false, error: "api_id and path required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const eId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "api_endpoint",
          metadata: {
            endpoint_id: eId, api_id, method: method ?? "GET", path,
            summary: summary ?? "", description: description ?? "",
            parameters: parameters ?? [], request_body: request_body ?? null,
            responses: responses ?? { "200": { description: "Success" } },
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, endpointId: eId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
