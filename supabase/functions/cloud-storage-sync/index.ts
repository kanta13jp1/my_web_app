// Cloud Storage Sync Edge Function
// クラウドストレージ同期 (Google Drive/Dropbox/OneDrive競合)
// - ファイル同期
// - バージョン管理
// - 共有リンク
// - フォルダ構造
// - 使用量追跡

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const FILE_TYPES = ["document", "spreadsheet", "presentation", "image", "video", "audio", "archive", "code", "other"];
const SYNC_STATUSES = ["synced", "pending", "conflict", "error"];
const SHARE_PERMISSIONS = ["view", "comment", "edit"];

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
      const folderId = url.searchParams.get("folder_id");

      if (view === "config") return new Response(JSON.stringify({ success: true, fileTypes: FILE_TYPES, syncStatuses: SYNC_STATUSES, sharePermissions: SHARE_PERMISSIONS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "files") {
        const parentId = folderId ?? "root";
        const { data: files } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "cloud_file").eq("metadata->>parent_id", parentId).order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, files: (files ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })), currentFolder: parentId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "storage") {
        const { data: allFiles } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "cloud_file");
        let totalSize = 0;
        const typeBreakdown: Record<string, { count: number; size: number }> = {};
        for (const f of allFiles ?? []) {
          const m = f.metadata as Record<string, unknown>;
          const size = (m.size_bytes as number) ?? 0;
          const type = (m.file_type as string) ?? "other";
          totalSize += size;
          if (!typeBreakdown[type]) typeBreakdown[type] = { count: 0, size: 0 };
          typeBreakdown[type].count++;
          typeBreakdown[type].size += size;
        }
        return new Response(JSON.stringify({
          success: true, storage: { totalFiles: (allFiles ?? []).length, totalSizeBytes: totalSize, totalSizeMB: Math.round(totalSize / 1024 / 1024 * 100) / 100, typeBreakdown },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "shared") {
        const { data: shared } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "cloud_share").eq("metadata->>shared_with", user.id).order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, sharedWithMe: (shared ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "recent") {
        const { data: recent } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "cloud_file").order("created_at", { ascending: false }).limit(20);
        return new Response(JSON.stringify({ success: true, recent: (recent ?? []).map((f) => ({ ...(f.metadata as Record<string, unknown>), createdAt: f.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, fileTypes: FILE_TYPES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "upload") {
        const { name, file_type, size_bytes, parent_id, content_hash } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const fileId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "cloud_file",
          metadata: { file_id: fileId, name, file_type: file_type ?? "other", size_bytes: size_bytes ?? 0, parent_id: parent_id ?? "root", content_hash: content_hash ?? null, is_folder: false, sync_status: "synced", version: 1 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, fileId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_folder") {
        const { name, parent_id } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const folderId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "cloud_file",
          metadata: { file_id: folderId, name, file_type: "folder", size_bytes: 0, parent_id: parent_id ?? "root", is_folder: true, sync_status: "synced" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, folderId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "share") {
        const { file_id, shared_with, permission } = body;
        if (!file_id || !shared_with) return new Response(JSON.stringify({ success: false, error: "file_id and shared_with required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const shareId = crypto.randomUUID();
        const shareLink = `share-${shareId.slice(0, 8)}`;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "cloud_share",
          metadata: { share_id: shareId, file_id, shared_by: user.id, shared_with, permission: permission ?? "view", share_link: shareLink },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, shareId, shareLink }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete") {
        const { file_id } = body;
        if (!file_id) return new Response(JSON.stringify({ success: false, error: "file_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "cloud_file").eq("metadata->>file_id", file_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) { return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
});
