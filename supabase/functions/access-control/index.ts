// Access Control & Permissions Edge Function
// アクセス制御・権限管理 (Google Workspace/Microsoft 365競合)
// - ロール管理
// - リソースアクセス制御
// - 権限グループ
// - アクセスログ
// - 招待管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const DEFAULT_ROLES = [
  { id: "owner", name: "オーナー", permissions: ["read", "write", "delete", "admin", "invite", "billing"] },
  { id: "admin", name: "管理者", permissions: ["read", "write", "delete", "admin", "invite"] },
  { id: "editor", name: "編集者", permissions: ["read", "write"] },
  { id: "viewer", name: "閲覧者", permissions: ["read"] },
  { id: "guest", name: "ゲスト", permissions: ["read"] },
];

const RESOURCE_TYPES = ["document", "folder", "project", "team", "workspace", "api_key"];
const PERMISSION_TYPES = ["read", "write", "delete", "admin", "invite", "billing", "export"];

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
      const resourceId = url.searchParams.get("resource_id");

      if (view === "roles") return new Response(JSON.stringify({ success: true, roles: DEFAULT_ROLES, resourceTypes: RESOURCE_TYPES, permissions: PERMISSION_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "my_permissions") {
        const { data: assignments } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "access_assignment").eq("metadata->>user_id", user.id)
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, assignments: (assignments ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "resource_access" && resourceId) {
        const { data: access } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "access_assignment").eq("metadata->>resource_id", resourceId);
        return new Response(JSON.stringify({ success: true, access: (access ?? []).map((a) => ({ ...(a.metadata as Record<string, unknown>), createdAt: a.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "invitations") {
        const { data: invites } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "access_invitation")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, invitations: (invites ?? []).map((i) => ({ ...(i.metadata as Record<string, unknown>), createdAt: i.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "access_log") {
        const { data: logs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "access_log").order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "check") {
        const rId = url.searchParams.get("resource_id");
        const permission = url.searchParams.get("permission");
        if (!rId || !permission) return new Response(JSON.stringify({ success: false, error: "resource_id and permission required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: assignment } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "access_assignment").eq("metadata->>user_id", user.id).eq("metadata->>resource_id", rId).maybeSingle();
        if (!assignment) return new Response(JSON.stringify({ success: true, allowed: false, reason: "No access assignment" }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = assignment.metadata as Record<string, unknown>;
        const roleId = (meta.role as string) ?? "guest";
        const role = DEFAULT_ROLES.find((r) => r.id === roleId);
        const allowed = role?.permissions.includes(permission) ?? false;
        return new Response(JSON.stringify({ success: true, allowed, role: roleId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, roles: DEFAULT_ROLES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "assign_role") {
        const { target_user_id, resource_id, resource_type, role } = body;
        if (!target_user_id || !resource_id || !role) return new Response(JSON.stringify({ success: false, error: "target_user_id, resource_id, and role required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const assignmentId = crypto.randomUUID();
        // Remove existing assignment
        await adminClient.from("app_analytics").delete()
          .eq("source", "access_assignment").eq("metadata->>user_id", target_user_id).eq("metadata->>resource_id", resource_id);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "access_assignment",
          metadata: {
            assignment_id: assignmentId, user_id: target_user_id,
            resource_id, resource_type: resource_type ?? "document",
            role, assigned_by: user.id,
          },
          created_at: new Date().toISOString(),
        });
        // Log
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "access_log",
          metadata: { action: "role_assigned", target_user_id, resource_id, role, assigned_by: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, assignmentId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "invite") {
        const { email, resource_id, resource_type, role } = body;
        if (!email || !resource_id) return new Response(JSON.stringify({ success: false, error: "email and resource_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const inviteId = crypto.randomUUID();
        const inviteCode = inviteId.substring(0, 8).toUpperCase();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "access_invitation",
          metadata: {
            invite_id: inviteId, email, resource_id,
            resource_type: resource_type ?? "document", role: role ?? "viewer",
            invite_code: inviteCode, status: "pending",
            invited_by: user.id, invited_by_email: user.email,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, inviteId, inviteCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "revoke") {
        const { target_user_id, resource_id } = body;
        if (!target_user_id || !resource_id) return new Response(JSON.stringify({ success: false, error: "target_user_id and resource_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("source", "access_assignment").eq("metadata->>user_id", target_user_id).eq("metadata->>resource_id", resource_id);
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "access_log",
          metadata: { action: "access_revoked", target_user_id, resource_id, revoked_by: user.id },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, revoked: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
