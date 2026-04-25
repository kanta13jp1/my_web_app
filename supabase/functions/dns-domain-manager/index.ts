// DNS Domain Manager Edge Function
// ドメイン・DNS管理 (Google Domains/Cloudflare/Amazon Route53競合)
// - ドメイン管理
// - DNSレコード設定
// - SSL証明書管理
// - ドメイン監視
// - WHOIS情報

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const RECORD_TYPES = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV", "CAA"];
const DOMAIN_STATUSES = ["active", "pending", "expired", "transferred", "locked"];
const SSL_STATUSES = ["valid", "expiring_soon", "expired", "none"];

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

      if (view === "config") return new Response(JSON.stringify({ success: true, recordTypes: RECORD_TYPES, domainStatuses: DOMAIN_STATUSES, sslStatuses: SSL_STATUSES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "domains") {
        const { data: domains } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "dns_domain").order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, domains: (domains ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "records") {
        const domainId = url.searchParams.get("domain_id");
        if (!domainId) return new Response(JSON.stringify({ success: false, error: "domain_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: records } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "dns_record").eq("metadata->>domain_id", domainId).order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, records: (records ?? []).map((r) => ({ ...(r.metadata as Record<string, unknown>), createdAt: r.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "ssl_status") {
        const { data: domains } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "dns_domain");
        const sslInfo = (domains ?? []).map((d) => {
          const m = d.metadata as Record<string, unknown>;
          const expiresAt = m.ssl_expires_at as string | null;
          let sslStatus = "none";
          if (expiresAt) {
            const daysUntilExpiry = (new Date(expiresAt).getTime() - Date.now()) / 86400000;
            if (daysUntilExpiry < 0) sslStatus = "expired";
            else if (daysUntilExpiry < 30) sslStatus = "expiring_soon";
            else sslStatus = "valid";
          }
          return { domain: m.domain, sslStatus, expiresAt };
        });
        return new Response(JSON.stringify({ success: true, ssl: sslInfo }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, recordTypes: RECORD_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "add_domain") {
        const { domain, registrar } = body;
        if (!domain) return new Response(JSON.stringify({ success: false, error: "domain required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const domainId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "dns_domain",
          metadata: { domain_id: domainId, domain, registrar: registrar ?? "", status: "active", ssl_expires_at: null, nameservers: [], auto_renew: true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, domainId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "add_record") {
        const { domain_id, record_type, name, value, ttl, priority } = body;
        if (!domain_id || !record_type || !name || !value) return new Response(JSON.stringify({ success: false, error: "domain_id, record_type, name, value required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const recordId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "dns_record",
          metadata: { record_id: recordId, domain_id, record_type, name, value, ttl: ttl ?? 3600, priority: priority ?? null },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, recordId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete_record") {
        const { record_id } = body;
        if (!record_id) return new Response(JSON.stringify({ success: false, error: "record_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "dns_record").eq("metadata->>record_id", record_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
