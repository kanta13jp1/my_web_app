// Code Playground & Sandbox Edge Function
// コードプレイグラウンド (Claude Code/Codex/GitHub競合)
// - スニペット作成・保存
// - 言語別テンプレート
// - 実行ログ記録
// - 共有リンク
// - コレクション管理

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const LANGUAGES = [
  "javascript", "typescript", "python", "dart", "rust",
  "go", "java", "c", "cpp", "ruby",
  "php", "swift", "kotlin", "sql", "html",
  "css", "shell", "yaml", "json", "markdown",
];

const TEMPLATES: Record<string, { name: string; code: string }> = {
  javascript: { name: "Hello World (JS)", code: 'console.log("Hello, World!");' },
  typescript: { name: "Hello World (TS)", code: 'const greeting: string = "Hello, World!";\nconsole.log(greeting);' },
  python: { name: "Hello World (Python)", code: 'print("Hello, World!")' },
  dart: { name: "Hello World (Dart)", code: 'void main() {\n  print("Hello, World!");\n}' },
  rust: { name: "Hello World (Rust)", code: 'fn main() {\n    println!("Hello, World!");\n}' },
  go: { name: "Hello World (Go)", code: 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, World!")\n}' },
  html: { name: "Basic HTML", code: '<!DOCTYPE html>\n<html>\n<head><title>Hello</title></head>\n<body><h1>Hello, World!</h1></body>\n</html>' },
  sql: { name: "Basic Query", code: 'SELECT * FROM users WHERE active = true ORDER BY created_at DESC LIMIT 10;' },
};

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
      const snippetId = url.searchParams.get("snippet_id");
      const language = url.searchParams.get("language");

      if (view === "languages") {
        return new Response(JSON.stringify({ success: true, languages: LANGUAGES, templates: TEMPLATES }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "snippet" && snippetId) {
        const { data: snippet } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("source", "code_snippet").eq("metadata->>snippet_id", snippetId).maybeSingle();
        if (!snippet) return new Response(JSON.stringify({ success: false, error: "Snippet not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        return new Response(JSON.stringify({ success: true, snippet: { ...(snippet.metadata as Record<string, unknown>), createdAt: snippet.created_at } }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "collections") {
        const { data: collections } = await adminClient.from("app_analytics").select("metadata, created_at")
          .eq("user_id", user.id).eq("source", "code_collection")
          .order("created_at", { ascending: false });
        return new Response(JSON.stringify({ success: true, collections: (collections ?? []).map((c) => ({ ...(c.metadata as Record<string, unknown>), createdAt: c.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (view === "stats") {
        const { data: snippets } = await adminClient.from("app_analytics").select("metadata")
          .eq("user_id", user.id).eq("source", "code_snippet");
        const langCount: Record<string, number> = {};
        for (const s of snippets ?? []) {
          const lang = ((s.metadata as Record<string, unknown>).language as string) ?? "unknown";
          langCount[lang] = (langCount[lang] ?? 0) + 1;
        }
        const publicCount = (snippets ?? []).filter((s) => (s.metadata as Record<string, unknown>).is_public).length;
        return new Response(JSON.stringify({
          success: true, stats: {
            totalSnippets: (snippets ?? []).length, publicCount,
            languageBreakdown: Object.entries(langCount).sort(([, a], [, b]) => b - a).map(([lang, count]) => ({ language: lang, count })),
          },
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      // Default: user's snippets
      let query = adminClient.from("app_analytics").select("metadata, created_at")
        .eq("user_id", user.id).eq("source", "code_snippet")
        .order("created_at", { ascending: false }).limit(50);
      if (language) query = query.eq("metadata->>language", language);
      const { data: snippets } = await query;
      return new Response(JSON.stringify({ success: true, snippets: (snippets ?? []).map((s) => ({ ...(s.metadata as Record<string, unknown>), createdAt: s.created_at })) }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const { action } = body;

      if (action === "save_snippet") {
        const { title, code, language: lang, description, is_public, collection_id } = body;
        if (!title || !code || !lang) return new Response(JSON.stringify({ success: false, error: "title, code, and language required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const snippetId = crypto.randomUUID();
        const shareCode = is_public ? snippetId.substring(0, 8).toUpperCase() : null;
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "code_snippet",
          metadata: {
            snippet_id: snippetId, title, code, language: lang,
            description: description ?? "", is_public: is_public ?? false,
            share_code: shareCode, collection_id: collection_id ?? null,
            version: 1, fork_of: null,
          },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, snippetId, shareCode }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "create_collection") {
        const { name, description } = body;
        if (!name) return new Response(JSON.stringify({ success: false, error: "name required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const collectionId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "code_collection",
          metadata: { collection_id: collectionId, name, description: description ?? "", snippet_count: 0 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, collectionId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "fork_snippet") {
        const { snippet_id } = body;
        if (!snippet_id) return new Response(JSON.stringify({ success: false, error: "snippet_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const { data: original } = await adminClient.from("app_analytics").select("metadata")
          .eq("source", "code_snippet").eq("metadata->>snippet_id", snippet_id).maybeSingle();
        if (!original) return new Response(JSON.stringify({ success: false, error: "Snippet not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        const meta = original.metadata as Record<string, unknown>;
        const newId = crypto.randomUUID();
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "code_snippet",
          metadata: { ...meta, snippet_id: newId, title: `Fork of ${meta.title}`, fork_of: snippet_id, is_public: false, share_code: null, version: 1 },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true, snippetId: newId }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      if (action === "log_execution") {
        const { snippet_id, output, duration_ms, success: execSuccess } = body;
        if (!snippet_id) return new Response(JSON.stringify({ success: false, error: "snippet_id required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        await adminClient.from("app_analytics").insert({
          user_id: user.id, source: "code_execution_log",
          metadata: { snippet_id, output: output ?? "", duration_ms: duration_ms ?? 0, success: execSuccess ?? true },
          created_at: new Date().toISOString(),
        });
        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      return new Response(JSON.stringify({ success: false, error: "Unknown action" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err instanceof Error ? err.message : String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
