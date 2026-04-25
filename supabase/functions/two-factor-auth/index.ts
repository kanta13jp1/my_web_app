// Two-Factor Authentication Edge Function
// 二要素認証管理 (Google/Microsoft/GitHub競合)
// - TOTP設定・検証
// - バックアップコード生成
// - 認証ログ
// - デバイス管理
// - セキュリティ設定

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const AUTH_METHODS = ["totp", "sms", "email", "backup_code"];

function generateBackupCodes(count: number = 8): string[] {
  const codes: string[] = [];
  for (let i = 0; i < count; i++) {
    const arr = new Uint8Array(4);
    crypto.getRandomValues(arr);
    codes.push(Array.from(arr).map((b) => b.toString(16).padStart(2, "0")).join("").toUpperCase());
  }
  return codes;
}

function generateTOTPSecret(): string {
  const arr = new Uint8Array(20);
  crypto.getRandomValues(arr);
  const base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let secret = "";
  for (let i = 0; i < arr.length; i++) {
    secret += base32Chars[arr[i] % 32];
  }
  return secret;
}

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

      if (view === "methods") return new Response(JSON.stringify({ success: true, methods: AUTH_METHODS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

      if (view === "status") {
        const { data: settings } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "2fa_settings").maybeSingle();
        if (!settings) return new Response(JSON.stringify({ success: true, enabled: false, methods: [] }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = settings.metadata as Record<string, unknown>;
        return new Response(JSON.stringify({
          success: true, enabled: meta.enabled ?? false,
          methods: (meta.enabled_methods as string[]) ?? [],
          backupCodesRemaining: ((meta.backup_codes as string[]) ?? []).length,
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "devices") {
        const { data: devices } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "trusted_device")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, devices: (devices ?? []).map((d) => ({ ...(d.metadata as Record<string, unknown>), createdAt: d.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "auth_log") {
        const { data: logs } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "auth_log")
          .order("created_at", { ascending: false }).limit(50);
        return new Response(JSON.stringify({ success: true, logs: (logs ?? []).map((l) => ({ ...(l.metadata as Record<string, unknown>), createdAt: l.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: true, methods: AUTH_METHODS }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const { action } = body;

      if (action === "setup_totp") {
        const secret = generateTOTPSecret();
        const issuer = "JibunKaisha";
        const otpAuthUrl = `otpauth://totp/${issuer}:${user.email}?secret=${secret}&issuer=${issuer}&algorithm=SHA1&digits=6&period=30`;
        // Store pending setup
        await adminClient.from("app_analytics").upsert({
          user_id: user.id, source: "2fa_pending",
          metadata: { secret, method: "totp", setup_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        }, { onConflict: "user_id,source" }).eq("user_id", user.id).eq("source", "2fa_pending");
        return new Response(JSON.stringify({ success: true, secret, otpAuthUrl }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "enable") {
        const { method } = body;
        if (!method) return new Response(JSON.stringify({ success: false, error: "method required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const backupCodes = generateBackupCodes();
        const { data: existing } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "2fa_settings").maybeSingle();
        const currentMethods = existing ? ((existing.metadata as Record<string, unknown>).enabled_methods as string[]) ?? [] : [];
        if (!currentMethods.includes(method)) currentMethods.push(method);
        if (existing) {
          await adminClient.from("app_analytics").update({
            metadata: { ...(existing.metadata as Record<string, unknown>), enabled: true, enabled_methods: currentMethods, backup_codes: backupCodes },
          }).eq("user_id", user.id).eq("source", "2fa_settings");
        } else {
          await adminClient.from("app_analytics").insert({
            user_id: user.id, source: "2fa_settings",
            metadata: { enabled: true, enabled_methods: currentMethods, backup_codes: backupCodes },
            created_at: new Date().toISOString(),
          });
        }
        // Log
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auth_log",
          metadata: { action: "2fa_enabled", method, ip: req.headers.get("x-forwarded-for") ?? "unknown" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, enabled: true, backupCodes }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "disable") {
        await adminClient.from("app_analytics").update({
          metadata: { enabled: false, enabled_methods: [], backup_codes: [] },
        }).eq("user_id", user.id).eq("source", "2fa_settings");
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auth_log",
          metadata: { action: "2fa_disabled", ip: req.headers.get("x-forwarded-for") ?? "unknown" },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, disabled: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "verify_backup") {
        const { code } = body;
        if (!code) return new Response(JSON.stringify({ success: false, error: "code required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: settings } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "2fa_settings").maybeSingle();
        if (!settings) return new Response(JSON.stringify({ success: false, error: "2FA not enabled" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = settings.metadata as Record<string, unknown>;
        const codes = (meta.backup_codes as string[]) ?? [];
        if (!codes.includes(code)) return new Response(JSON.stringify({ success: false, error: "Invalid backup code" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        // Remove used code
        const remaining = codes.filter((c) => c !== code);
        await adminClient.from("app_analytics").update({
          metadata: { ...meta, backup_codes: remaining },
        }).eq("user_id", user.id).eq("source", "2fa_settings");
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "auth_log",
          metadata: { action: "backup_code_used", remaining: remaining.length },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, verified: true, remaining: remaining.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "trust_device") {
        const { device_name, device_type } = body;
        const deviceId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "trusted_device",
          metadata: { device_id: deviceId, device_name: device_name ?? "Unknown Device", device_type: device_type ?? "unknown", trusted_at: new Date().toISOString() },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, deviceId }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
