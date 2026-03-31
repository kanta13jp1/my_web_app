// Template Library Edge Function
// テンプレートライブラリ (Notion競合)
// - ノート・プロジェクト・ワークフロー用テンプレート
// - カテゴリ別閲覧
// - テンプレートからの作成
// - ユーザーカスタムテンプレート
//
// GET  → テンプレート一覧 / カテゴリ / 詳細
// POST → テンプレート作成 / テンプレートから生成

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

const BUILTIN_TEMPLATES = [
  {
    id: "meeting_notes",
    name: "議事録",
    category: "business",
    description: "ミーティング議事録テンプレート",
    content: "# 議事録\n\n## 日時\n{{date}}\n\n## 参加者\n- \n\n## アジェンダ\n1. \n\n## 決定事項\n- \n\n## アクションアイテム\n- [ ] ",
    tags: ["ビジネス", "ミーティング"],
  },
  {
    id: "weekly_review",
    name: "週次振り返り",
    category: "productivity",
    description: "1週間の振り返りと来週の計画",
    content: "# 週次振り返り {{date}}\n\n## 今週の成果\n- \n\n## うまくいったこと\n- \n\n## 改善点\n- \n\n## 来週の目標\n1. \n2. \n3. ",
    tags: ["振り返り", "生産性"],
  },
  {
    id: "project_plan",
    name: "プロジェクト計画書",
    category: "project",
    description: "プロジェクトの計画書テンプレート",
    content: "# プロジェクト計画書\n\n## プロジェクト名\n\n## 目的\n\n## スコープ\n\n## マイルストーン\n| 日付 | 内容 | 担当 |\n|------|------|------|\n| | | |\n\n## リスク\n- \n\n## 成功基準\n- ",
    tags: ["プロジェクト", "計画"],
  },
  {
    id: "daily_journal",
    name: "日記",
    category: "personal",
    description: "毎日の日記テンプレート",
    content: "# {{date}} の日記\n\n## 今日の気分\n\n## 今日やったこと\n- \n\n## 感謝していること\n1. \n2. \n3. \n\n## 明日の予定\n- ",
    tags: ["日記", "個人"],
  },
  {
    id: "bug_report",
    name: "バグ報告",
    category: "development",
    description: "バグ報告テンプレート",
    content: "# バグ報告\n\n## 概要\n\n## 再現手順\n1. \n2. \n3. \n\n## 期待される動作\n\n## 実際の動作\n\n## 環境\n- OS: \n- ブラウザ: \n- バージョン: \n\n## スクリーンショット\n",
    tags: ["開発", "バグ"],
  },
  {
    id: "blog_draft",
    name: "ブログ記事下書き",
    category: "content",
    description: "技術ブログ記事テンプレート",
    content: "# タイトル\n\n## はじめに\n\n## 背景・課題\n\n## 解決方法\n\n### コード例\n```\n\n```\n\n## まとめ\n\n## 参考リンク\n- ",
    tags: ["ブログ", "コンテンツ"],
  },
  {
    id: "okr",
    name: "OKR",
    category: "business",
    description: "目標と主要成果のテンプレート",
    content: "# OKR ({{date}} Q)\n\n## Objective 1:\n- KR1: \n- KR2: \n- KR3: \n\n## Objective 2:\n- KR1: \n- KR2: \n- KR3: ",
    tags: ["OKR", "目標"],
  },
  {
    id: "retrospective",
    name: "KPT振り返り",
    category: "productivity",
    description: "Keep/Problem/Try フレームワーク",
    content: "# KPT振り返り {{date}}\n\n## Keep (続けること)\n- \n\n## Problem (問題点)\n- \n\n## Try (試すこと)\n- ",
    tags: ["振り返り", "KPT"],
  },
];

const CATEGORIES = [
  { key: "business", label: "ビジネス" },
  { key: "productivity", label: "生産性" },
  { key: "project", label: "プロジェクト" },
  { key: "personal", label: "個人" },
  { key: "development", label: "開発" },
  { key: "content", label: "コンテンツ" },
  { key: "custom", label: "カスタム" },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const authHeader = req.headers.get("Authorization");
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

    if (req.method === "GET") {
      const url = new URL(req.url);
      const view = url.searchParams.get("view"); // 'categories' | 'detail'
      const category = url.searchParams.get("category");
      const templateId = url.searchParams.get("template_id");

      if (view === "categories") {
        return new Response(
          JSON.stringify({ success: true, categories: CATEGORIES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (view === "detail" && templateId) {
        const builtin = BUILTIN_TEMPLATES.find((t) => t.id === templateId);
        if (builtin) {
          const content = builtin.content.replace(/\{\{date\}\}/g, new Date().toISOString().slice(0, 10));
          return new Response(
            JSON.stringify({ success: true, template: { ...builtin, content, source: "builtin" } }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Check user custom templates
        const { data: custom } = await adminClient
          .from("app_analytics")
          .select("metadata, created_at")
          .eq("user_id", user.id)
          .eq("source", "custom_template")
          .eq("metadata->>template_id", templateId)
          .maybeSingle();

        if (custom) {
          return new Response(
            JSON.stringify({ success: true, template: { ...(custom.metadata as Record<string, unknown>), createdAt: custom.created_at, source: "custom" } }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        return new Response(
          JSON.stringify({ success: false, error: "Template not found" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Template list (builtin + custom)
      let templates = [...BUILTIN_TEMPLATES.map((t) => ({ ...t, source: "builtin" as const }))];

      if (category) {
        templates = templates.filter((t) => t.category === category);
      }

      const { data: customTemplates } = await adminClient
        .from("app_analytics")
        .select("metadata, created_at")
        .eq("user_id", user.id)
        .eq("source", "custom_template")
        .order("created_at", { ascending: false });

      const customs = (customTemplates ?? [])
        .filter((c) => {
          if (!category) return true;
          return (c.metadata as Record<string, unknown>)?.category === category;
        })
        .map((c) => ({
          ...(c.metadata as Record<string, unknown>),
          source: "custom",
          createdAt: c.created_at,
        }));

      return new Response(
        JSON.stringify({
          success: true,
          templates: [...templates, ...customs],
          totalBuiltin: BUILTIN_TEMPLATES.length,
          totalCustom: (customTemplates ?? []).length,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "create_template") {
        const { name, category: cat, description, content, tags } = body;
        if (!name || !content) {
          return new Response(
            JSON.stringify({ success: false, error: "name and content required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        const templateId = crypto.randomUUID();
        const { data, error } = await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "custom_template",
          metadata: {
            template_id: templateId,
            name,
            category: cat ?? "custom",
            description: description ?? "",
            content,
            tags: tags ?? [],
          },
          created_at: new Date().toISOString(),
        }).select().single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, templateId, template: data }),
          { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      if (action === "use_template") {
        const { template_id } = body;
        if (!template_id) {
          return new Response(
            JSON.stringify({ success: false, error: "template_id required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Find template
        const builtin = BUILTIN_TEMPLATES.find((t) => t.id === template_id);
        let content: string;
        let name: string;

        if (builtin) {
          content = builtin.content.replace(/\{\{date\}\}/g, new Date().toISOString().slice(0, 10));
          name = builtin.name;
        } else {
          const { data: custom } = await adminClient
            .from("app_analytics")
            .select("metadata")
            .eq("user_id", user.id)
            .eq("source", "custom_template")
            .eq("metadata->>template_id", template_id)
            .maybeSingle();

          if (!custom) {
            return new Response(
              JSON.stringify({ success: false, error: "Template not found" }),
              { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
            );
          }

          const meta = custom.metadata as Record<string, unknown>;
          content = (meta?.content as string) ?? "";
          name = (meta?.name as string) ?? "無題";
        }

        // Log template usage
        await adminClient.from("app_analytics").insert({
          user_id: user.id,
          source: "template_usage",
          metadata: { template_id, name },
          created_at: new Date().toISOString(),
        });

        return new Response(
          JSON.stringify({ success: true, name, content }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("template-library error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
