// User Profile Manager Edge Function
// ユーザープロフィール管理 API
// - プロフィール完成度計算
// - プロフィール更新促進 (ナッジ)
// - 管理者向けユーザー一覧
//
// GET  → プロフィール取得 (自分 or 管理者が全員)
// POST → プロフィール更新
// PATCH → ナッジ送信 (管理者)

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

interface ProfileField {
  key: string;
  label: string;
  weight: number;
}

const PROFILE_FIELDS: ProfileField[] = [
  { key: "display_name", label: "表示名", weight: 20 },
  { key: "avatar_url", label: "アバター画像", weight: 15 },
  { key: "bio", label: "自己紹介", weight: 15 },
  { key: "company", label: "会社名", weight: 10 },
  { key: "website", label: "Webサイト", weight: 10 },
  { key: "skills", label: "スキル", weight: 15 },
  { key: "interests", label: "興味関心", weight: 15 },
];

// deno-lint-ignore no-explicit-any
function calculateCompleteness(profile: any): { percent: number; missingFields: string[] } {
  let totalWeight = 0;
  let completedWeight = 0;
  const missingFields: string[] = [];

  for (const field of PROFILE_FIELDS) {
    totalWeight += field.weight;
    const value = profile?.[field.key];
    const isEmpty = value === null || value === undefined || value === "" ||
      (Array.isArray(value) && value.length === 0);

    if (isEmpty) {
      missingFields.push(field.label);
    } else {
      completedWeight += field.weight;
    }
  }

  return {
    percent: totalWeight > 0 ? Math.round((completedWeight / totalWeight) * 100) : 0,
    missingFields,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");

    if (req.method === "GET") {
      const url = new URL(req.url);
      const mode = url.searchParams.get("mode"); // 'self' | 'admin'

      if (mode === "admin") {
        // 管理者: 全ユーザー一覧
        const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
          auth: { persistSession: false },
        });

        const { data: profiles, error } = await adminClient
          .from("user_profiles")
          .select("*")
          .order("created_at", { ascending: false });

        if (error) throw error;

        const enriched = (profiles ?? []).map((p: Record<string, unknown>) => ({
          ...p,
          completeness: calculateCompleteness(p),
        }));

        return new Response(
          JSON.stringify({ success: true, profiles: enriched, total: enriched.length }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // 自分のプロフィール
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

      const { data: profile, error } = await userClient
        .from("user_profiles")
        .select("*")
        .eq("user_id", user.id)
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({
          success: true,
          profile,
          completeness: calculateCompleteness(profile),
          fields: PROFILE_FIELDS,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      // プロフィール更新
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

      const body = await req.json().catch(() => ({}));
      const allowedFields = PROFILE_FIELDS.map((f) => f.key);
      const updates: Record<string, unknown> = {};
      for (const key of allowedFields) {
        if (key in body) updates[key] = body[key];
      }
      updates.updated_at = new Date().toISOString();

      const { data, error } = await userClient
        .from("user_profiles")
        .update(updates)
        .eq("user_id", user.id)
        .select()
        .single();

      if (error) throw error;

      return new Response(
        JSON.stringify({
          success: true,
          profile: data,
          completeness: calculateCompleteness(data),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("user-profile-manager error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
