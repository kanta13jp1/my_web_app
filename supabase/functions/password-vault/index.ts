// Password Vault Edge Function
// パスワード管理 (1Password/LastPass競合)
// - パスワード保存 (暗号化メタデータ)
// - カテゴリ管理
// - パスワード強度チェック
// - セキュリティ監査
// - 共有ボールト

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const ENTRY_CATEGORIES = ["login", "credit_card", "identity", "secure_note", "ssh_key", "api_key", "wifi", "license", "other"];

function checkPasswordStrength(password: string): { score: number; label: string; suggestions: string[] } {
  let score = 0;
  const suggestions: string[] = [];
  if (password.length >= 8) score++;
  else suggestions.push("8文字以上にしてください");
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
  else suggestions.push("大文字と小文字を混ぜてください");
  if (/\d/.test(password)) score++;
  else suggestions.push("数字を含めてください");
  if (/[!@#$%^&*()_+\-=[\]{};':"|,.<>?]/.test(password)) score++;
  else suggestions.push("記号を含めてください");
  if (/(.)\1{2,}/.test(password)) { score--; suggestions.push("同じ文字の連続を避けてください"); }

  const labels = ["非常に弱い", "弱い", "普通", "強い", "非常に強い", "最強"];
  const label = labels[Math.min(Math.max(score, 0), labels.length - 1)];
  return { score: Math.max(score, 0), label, suggestions };
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
      const category = url.searchParams.get("category");

      if (view === "categories") {
        return new Response(JSON.stringify({ success: true, categories: ENTRY_CATEGORIES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "audit") {
        const { data: entries } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vault_entry");
        const weak: string[] = [];
        const reused = new Map<string, string[]>();
        const old: string[] = [];
        const threeMonthsAgo = new Date(Date.now() - 90 * 86400000).toISOString();
        for (const e of entries ?? []) {
          const m = e.metadata as Record<string, unknown>;
          if (((m.strength_score as number) ?? 0) < 3) weak.push(m.title as string);
          const hash = (m.password_hash as string) ?? "";
          if (hash) {
            if (!reused.has(hash)) reused.set(hash, []);
            reused.get(hash)!.push(m.title as string);
          }
          if (((m.last_changed as string) ?? "") < threeMonthsAgo) old.push(m.title as string);
        }
        const reusedGroups = [...reused.entries()].filter(([, titles]) => titles.length > 1).map(([, titles]) => titles);
        return new Response(JSON.stringify({
          success: true, audit: {
            totalEntries: (entries ?? []).length, weakPasswords: weak, reusedPasswords: reusedGroups,
            oldPasswords: old, score: Math.max(0, 100 - weak.length * 10 - reusedGroups.length * 15 - old.length * 5),
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: entries } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "vault_entry");
        const catCount: Record<string, number> = {};
        let avgStrength = 0;
        for (const e of entries ?? []) {
          const m = e.metadata as Record<string, unknown>;
          const c = (m.category as string) ?? "other";
          catCount[c] = (catCount[c] ?? 0) + 1;
          avgStrength += ((m.strength_score as number) ?? 0);
        }
        avgStrength = (entries ?? []).length > 0 ? Math.round((avgStrength / (entries ?? []).length) * 10) / 10 : 0;
        return new Response(JSON.stringify({
          success: true, stats: { totalEntries: (entries ?? []).length, categoryBreakdown: catCount, avgStrength },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: list entries (without actual passwords)
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "vault_entry")
        .order("created_at", { ascending: false });
      if (category) query = query.eq("metadata->>category", category);
      const { data: entries } = await query;
      return new Response(JSON.stringify({
        success: true,
        entries: (entries ?? []).map((e) => {
          const m = { ...(e.metadata as Record<string, unknown>) };
          delete m.encrypted_password; // Never return encrypted password in list
          return { ...m, createdAt: e.created_at };
        }),
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "add_entry") {
        const { title, category: cat, username, encrypted_password, url: entryUrl, notes, tags } = body;
        if (!title) return new Response(JSON.stringify({ success: false, error: "title required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const entryId = crypto.randomUUID();
        // Simple hash for reuse detection (not actual password storage)
        const passwordHash = encrypted_password ? btoa(encrypted_password).substring(0, 16) : "";
        const strength = encrypted_password ? checkPasswordStrength(encrypted_password) : { score: 0, label: "なし", suggestions: [] };
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "vault_entry",
          metadata: {
            entry_id: entryId, title, category: cat ?? "login",
            username: username ?? "", encrypted_password: encrypted_password ?? "",
            password_hash: passwordHash, url: entryUrl ?? "", notes: notes ?? "",
            tags: tags ?? [], strength_score: strength.score, strength_label: strength.label,
            last_changed: new Date().toISOString(),
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, entryId, strength }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "check_strength") {
        const { password } = body;
        if (!password) return new Response(JSON.stringify({ success: false, error: "password required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, ...checkPasswordStrength(password) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "generate_password") {
        const { length: pwLen, include_uppercase, include_numbers, include_symbols } = body;
        const len = pwLen ?? 16;
        let chars = "abcdefghijklmnopqrstuvwxyz";
        if (include_uppercase !== false) chars += "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        if (include_numbers !== false) chars += "0123456789";
        if (include_symbols !== false) chars += "!@#$%^&*()_+-=[]{}|;:,.<>?";
        let password = "";
        const arr = new Uint8Array(len);
        crypto.getRandomValues(arr);
        for (let i = 0; i < len; i++) password += chars[arr[i] % chars.length];
        return new Response(JSON.stringify({ success: true, password, ...checkPasswordStrength(password) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "delete_entry") {
        const { entry_id } = body;
        if (!entry_id) return new Response(JSON.stringify({ success: false, error: "entry_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").delete()
          .eq("user_id", user.id).eq("source", "vault_entry").eq("metadata->>entry_id", entry_id);
        return new Response(JSON.stringify({ success: true, deleted: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
